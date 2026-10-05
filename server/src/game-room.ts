import { DurableObject } from "cloudflare:workers";

import { verifySupabaseAccessToken } from "./auth/supabase-auth";
import {
  drawCard,
  shuffleHand,
  startGame,
  startNewRound,
  type GameResult,
} from "./domain/game";
import {
  createLobby,
  createRoomView,
  expireDisconnectedPlayers,
  joinLobby,
  leaveRoom as leaveRoomState,
  normalizeStoredRoom,
  setPlayerConnection,
  type RoomState,
} from "./domain/lobby";
import type { Env } from "./env";
import {
  PROTOCOL_VERSION,
  encodeServerMessage,
  parseClientMessage,
  type ClientMessage,
  type ServerMessage,
} from "./protocol/messages";

interface SocketSession { readonly userId: string; }

const ROOM_STORAGE_KEY = "room";
const ROOM_CODE_PATTERN = /^[A-Z0-9]{6}$/;
const DISCONNECTED_SEAT_TTL_MS = 5 * 60 * 1000;

export class GameRoom extends DurableObject<Env> {
  private room: RoomState | null = null;
  private commandQueue: Promise<void> = Promise.resolve();

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    ctx.blockConcurrencyWhile(async () => {
      this.room = normalizeStoredRoom(await ctx.storage.get<unknown>(ROOM_STORAGE_KEY));
    });
  }

  override async fetch(request: Request): Promise<Response> {
    const roomCode = roomCodeFromRequest(request);
    if (roomCode === null) return jsonResponse({ error: "invalid_room_code" }, 400);
    if (request.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
      return jsonResponse({ error: "websocket_upgrade_required" }, 426);
    }
    const pair = new WebSocketPair();
    const client = pair[0];
    const server = pair[1];
    this.ctx.acceptWebSocket(server, [roomCode]);
    this.send(server, {
      protocolVersion: PROTOCOL_VERSION,
      type: "connection_ready",
      payload: { roomCode, authenticationRequired: true },
    });
    return new Response(null, { status: 101, webSocket: client });
  }

  override webSocketMessage(socket: WebSocket, raw: string | ArrayBuffer): void {
    this.commandQueue = this.commandQueue
      .then(() => this.handleMessage(socket, raw))
      .catch((error: unknown) => {
        console.error("GameRoom command failed", error);
        this.sendError(socket, "server_error", "The server could not process the command.");
      });
  }

  override webSocketClose(socket: WebSocket): void {
    this.commandQueue = this.commandQueue
      .then(async () => {
        const session = socket.deserializeAttachment() as SocketSession | null;
        if (session === null || this.room === null) return;
        const hasAnotherSocket = this.ctx.getWebSockets().some((candidate) => {
          if (candidate === socket) return false;
          const other = candidate.deserializeAttachment() as SocketSession | null;
          return other?.userId === session.userId;
        });
        if (hasAnotherSocket) return;
        const isPlaying = this.room.phase === "playing";
        const isSeated = this.room.players.some(
          (player) => player.userId === session.userId,
        );
        if (!isSeated) return;
        if (isPlaying) {
          const result = leaveRoomState(
            this.room,
            session.userId,
            new Date().toISOString(),
          );
          if (!result.ok) return;
          this.room = result.state;
        } else {
          this.room = setPlayerConnection(
            this.room,
            session.userId,
            false,
            new Date().toISOString(),
          );
        }
        if (this.room === null) {
          await this.ctx.storage.deleteAll();
          return;
        }
        await this.persistAndBroadcast();
      })
      .catch((error: unknown) => console.error("Disconnect update failed", error));
  }

  override webSocketError(socket: WebSocket): void {
    socket.close(1011, "WebSocket error");
  }

  override async alarm(): Promise<void> {
    if (this.room === null) return;
    const now = new Date();
    const updated = expireDisconnectedPlayers(
      this.room,
      now.getTime() - DISCONNECTED_SEAT_TTL_MS,
      now.toISOString(),
    );
    if (updated === null) {
      this.room = null;
      await this.ctx.storage.deleteAll();
      return;
    }
    if (updated !== this.room) {
      this.room = updated;
      await this.ctx.storage.put(ROOM_STORAGE_KEY, this.room);
      for (const socket of this.ctx.getWebSockets()) this.sendRoomSnapshot(socket);
    }
    await this.scheduleDisconnectExpiry();
  }

  private async handleMessage(socket: WebSocket, raw: string | ArrayBuffer): Promise<void> {
    const parsed = parseClientMessage(raw);
    if (!parsed.ok) {
      this.sendError(socket, parsed.code, parsed.message);
      return;
    }
    const message = parsed.message;
    const session = socket.deserializeAttachment() as SocketSession | null;
    if (message.type === "authenticate") {
      await this.authenticate(socket, message);
      return;
    }
    if (session === null) {
      this.sendError(
        socket,
        "authentication_required",
        "Authenticate before sending room commands.",
        message.actionId,
      );
      return;
    }
    if (message.type !== "ping" &&
        await this.isProcessedAction(session.userId, message.actionId)) {
      this.sendRoomSnapshot(socket, message.actionId);
      return;
    }
    switch (message.type) {
      case "create_room":
        await this.createRoom(socket, session, message);
        return;
      case "join_room":
      case "resume_room":
        await this.joinRoom(socket, session, message);
        return;
      case "leave_room":
        await this.leaveRoom(socket, session, message.actionId);
        return;
      case "start_game":
        await this.runGameCommand(
          socket,
          session,
          message,
          (room) => startGame(room, session.userId, new Date().toISOString()),
        );
        return;
      case "draw_card":
        await this.runGameCommand(
          socket,
          session,
          message,
          (room) => drawCard(
            room,
            session.userId,
            message.payload.targetUserId,
            message.payload.cardIndex,
            new Date().toISOString(),
          ),
        );
        return;
      case "shuffle_hand":
        await this.runGameCommand(
          socket,
          session,
          message,
          (room) => shuffleHand(room, session.userId, new Date().toISOString()),
        );
        return;
      case "start_new_round":
        await this.runGameCommand(
          socket,
          session,
          message,
          (room) => startNewRound(room, session.userId, new Date().toISOString()),
        );
        return;
      case "ping":
        this.send(socket, {
          protocolVersion: PROTOCOL_VERSION,
          type: "pong",
          actionId: message.actionId,
          stateVersion: this.room?.stateVersion,
          payload: { serverTime: new Date().toISOString() },
        });
        return;
    }
  }

  private async authenticate(
    socket: WebSocket,
    message: Extract<ClientMessage, { type: "authenticate" }>,
  ): Promise<void> {
    if (socket.deserializeAttachment() !== null) {
      this.sendError(socket, "already_authenticated", "This connection is already authenticated.", message.actionId);
      return;
    }
    const result = await verifySupabaseAccessToken(message.payload.accessToken, this.env);
    if (!result.ok) {
      this.sendError(socket, "authentication_failed", result.message, message.actionId);
      socket.close(4001, "Authentication failed");
      return;
    }
    socket.serializeAttachment({ userId: result.user.id } satisfies SocketSession);
    this.send(socket, {
      protocolVersion: PROTOCOL_VERSION,
      type: "authenticated",
      actionId: message.actionId,
      payload: { userId: result.user.id },
    });
  }

  private async createRoom(
    socket: WebSocket,
    session: SocketSession,
    message: Extract<ClientMessage, { type: "create_room" }>,
  ): Promise<void> {
    if (this.room !== null) {
      this.sendError(socket, "room_already_exists", "Room already exists.", message.actionId);
      return;
    }
    const result = createLobby(
      this.roomCode(socket),
      session.userId,
      message.payload.name,
      message.payload.avatarId,
      new Date().toISOString(),
    );
    if (!result.ok) {
      this.sendError(socket, result.code, result.message, message.actionId);
      return;
    }
    this.room = result.state;
    await this.persistAndBroadcast(message.actionId, session.userId);
  }

  private async joinRoom(
    socket: WebSocket,
    session: SocketSession,
    message: Extract<ClientMessage, { type: "join_room" | "resume_room" }>,
  ): Promise<void> {
    if (message.expectedStateVersion !== undefined && this.room !== null &&
        message.expectedStateVersion > this.room.stateVersion) {
      this.sendError(socket, "invalid_state_version", "Client state version is ahead of the server.", message.actionId);
      return;
    }
    const result = joinLobby(
      this.room,
      session.userId,
      message.payload.name,
      message.payload.avatarId,
      new Date().toISOString(),
    );
    if (!result.ok) {
      this.sendError(socket, result.code, result.message, message.actionId);
      return;
    }
    this.room = result.state;
    await this.persistAndBroadcast(message.actionId, session.userId);
  }

  private async leaveRoom(
    socket: WebSocket,
    session: SocketSession,
    actionId: string,
  ): Promise<void> {
    if (this.room === null) {
      this.sendError(socket, "room_not_found", "Room does not exist.", actionId);
      return;
    }
    const result = leaveRoomState(this.room, session.userId, new Date().toISOString());
    if (!result.ok) {
      this.sendError(socket, result.code, result.message, actionId);
      return;
    }
    this.room = result.state;
    if (this.room === null) {
      await this.ctx.storage.deleteAll();
    } else {
      await this.ctx.storage.put({
        [ROOM_STORAGE_KEY]: this.room,
        [actionStorageKey(session.userId, actionId)]: true,
      });
    }
    this.send(socket, {
      protocolVersion: PROTOCOL_VERSION,
      type: "left_room",
      actionId,
      stateVersion: this.room?.stateVersion,
      payload: {},
    });
    if (this.room !== null) {
      for (const candidate of this.ctx.getWebSockets()) {
        if (candidate === socket) continue;
        this.sendRoomSnapshot(candidate);
      }
      await this.scheduleDisconnectExpiry();
    }
  }

  private async runGameCommand(
    socket: WebSocket,
    session: SocketSession,
    message: Extract<
      ClientMessage,
      { type: "start_game" | "draw_card" | "shuffle_hand" | "start_new_round" }
    >,
    command: (room: RoomState) => GameResult,
  ): Promise<void> {
    if (this.room === null) {
      this.sendError(socket, "room_not_found", "Room does not exist.", message.actionId);
      return;
    }
    if (message.expectedStateVersion !== undefined &&
        message.expectedStateVersion !== this.room.stateVersion) {
      this.sendError(
        socket,
        "stale_state",
        "The room changed before this action arrived. Use the latest snapshot.",
        message.actionId,
      );
      return;
    }
    const result = command(this.room);
    if (!result.ok) {
      this.sendError(socket, result.code, result.message, message.actionId);
      return;
    }
    this.room = result.state;
    await this.persistAndBroadcast(message.actionId, session.userId);
  }

  private async persistAndBroadcast(actionId?: string, userId?: string): Promise<void> {
    if (this.room === null) return;
    const writes: Record<string, unknown> = { [ROOM_STORAGE_KEY]: this.room };
    if (actionId !== undefined && userId !== undefined) {
      writes[actionStorageKey(userId, actionId)] = true;
    }
    await this.ctx.storage.put(writes);
    await this.scheduleDisconnectExpiry();
    for (const socket of this.ctx.getWebSockets()) {
      if (socket.deserializeAttachment() === null) continue;
      this.sendRoomSnapshot(socket, actionId);
    }
  }

  private sendRoomSnapshot(socket: WebSocket, actionId?: string): void {
    if (this.room === null) return;
    const session = socket.deserializeAttachment() as SocketSession | null;
    if (session === null ||
        !this.room.players.some((player) => player.userId === session.userId)) return;
    this.send(socket, {
      protocolVersion: PROTOCOL_VERSION,
      type: "room_snapshot",
      actionId,
      stateVersion: this.room.stateVersion,
      payload: createRoomView(this.room, session.userId),
    });
  }

  private async isProcessedAction(userId: string, actionId: string): Promise<boolean> {
    return (await this.ctx.storage.get<boolean>(actionStorageKey(userId, actionId))) === true;
  }

  private async scheduleDisconnectExpiry(): Promise<void> {
    if (this.room === null) return;
    const expirations = this.room.players.flatMap((player) =>
      !player.connected && player.disconnectedAt !== undefined
        ? [Date.parse(player.disconnectedAt) + DISCONNECTED_SEAT_TTL_MS]
        : [],
    );
    if (expirations.length === 0) {
      await this.ctx.storage.deleteAlarm();
      return;
    }
    await this.ctx.storage.setAlarm(Math.min(...expirations));
  }

  private roomCode(socket: WebSocket): string {
    const roomCode = this.ctx.getTags(socket)[0];
    if (roomCode === undefined || !ROOM_CODE_PATTERN.test(roomCode)) {
      throw new Error("Socket has no valid room code tag.");
    }
    return roomCode;
  }

  private send(socket: WebSocket, message: ServerMessage): void {
    socket.send(encodeServerMessage(message));
  }

  private sendError(socket: WebSocket, code: string, message: string, actionId?: string): void {
    this.send(socket, {
      protocolVersion: PROTOCOL_VERSION,
      type: "error",
      actionId,
      stateVersion: this.room?.stateVersion,
      payload: { code, message },
    });
  }
}

function roomCodeFromRequest(request: Request): string | null {
  const parts = new URL(request.url).pathname.split("/").filter(Boolean);
  if (parts.length !== 3 || parts[0] !== "rooms" || parts[2] !== "connect") return null;
  const roomCode = parts[1]?.toUpperCase();
  return roomCode !== undefined && ROOM_CODE_PATTERN.test(roomCode) ? roomCode : null;
}

function jsonResponse(body: unknown, status = 200): Response {
  return Response.json(body, { status });
}

function actionStorageKey(userId: string, actionId: string): string {
  return `action:${userId}:${actionId}`;
}
