import { applyRoundScores, removePairs } from "./round-rules.ts";

export const MAX_PLAYERS = 6;

export type RoomPhase = "lobby" | "playing" | "round_end";
export type PlayerStatus = "playing" | "finished" | "shayeb";

export interface GameCard {
  readonly id: string;
  readonly suit: "hearts" | "diamonds" | "clubs" | "spades";
  readonly rank: number;
}

export interface PlayerProfile {
  readonly userId: string;
  readonly name: string;
  readonly avatarId: string;
  readonly connected: boolean;
  readonly disconnectedAt?: string | undefined;
  readonly hand: readonly GameCard[];
  readonly score: number;
  readonly status: PlayerStatus;
  readonly finishPosition: number;
}

export interface GameActionSummary {
  readonly type:
    | "game_started"
    | "card_drawn"
    | "hand_shuffled"
    | "round_started"
    | "player_left";
  readonly actorUserId: string;
  readonly actorName?: string | undefined;
  readonly targetUserId?: string | undefined;
  readonly madePair?: boolean | undefined;
  readonly drawnCard?: GameCard | undefined;
}

export interface RoomState {
  readonly roomCode: string;
  readonly creatorUserId: string;
  readonly phase: RoomPhase;
  readonly stateVersion: number;
  readonly players: readonly PlayerProfile[];
  readonly currentPlayerIndex: number;
  readonly roundNumber: number;
  readonly nextFinishPosition: number;
  readonly lastAction?: GameActionSummary | undefined;
  readonly createdAt: string;
  readonly updatedAt: string;
}

export interface PlayerView extends Omit<PlayerProfile, "hand" | "disconnectedAt"> {
  readonly cardCount: number;
  readonly hand?: readonly GameCard[] | undefined;
}

export interface RoomView {
  readonly roomCode: string;
  readonly phase: RoomPhase;
  readonly stateVersion: number;
  readonly localUserId: string;
  readonly canStart: boolean;
  readonly canStartNewRound: boolean;
  readonly currentPlayerUserId?: string | undefined;
  readonly drawFromUserId?: string | undefined;
  readonly roundNumber: number;
  readonly lastAction?: GameActionSummary | undefined;
  readonly players: readonly PlayerView[];
}

export type LobbyResult =
  | { readonly ok: true; readonly state: RoomState }
  | { readonly ok: false; readonly code: LobbyErrorCode; readonly message: string };

export type LeaveRoomResult =
  | { readonly ok: true; readonly state: RoomState | null }
  | { readonly ok: false; readonly code: "player_not_found"; readonly message: string };

export type LobbyErrorCode =
  | "room_already_exists"
  | "room_not_found"
  | "room_full"
  | "game_in_progress"
  | "invalid_player_name";

export function createLobby(
  roomCode: string,
  userId: string,
  name: string,
  avatarId: string,
  now: string,
): LobbyResult {
  const normalizedName = normalizePlayerName(name);
  if (normalizedName === null) return invalidPlayerName();
  return {
    ok: true,
    state: {
      roomCode,
      creatorUserId: userId,
      phase: "lobby",
      stateVersion: 1,
      players: [createPlayer(userId, normalizedName, avatarId)],
      currentPlayerIndex: 0,
      roundNumber: 1,
      nextFinishPosition: 1,
      createdAt: now,
      updatedAt: now,
    },
  };
}

export function joinLobby(
  state: RoomState | null,
  userId: string,
  name: string,
  avatarId: string,
  now: string,
): LobbyResult {
  if (state === null) {
    return { ok: false, code: "room_not_found", message: "Room does not exist." };
  }
  const normalizedName = normalizePlayerName(name);
  if (normalizedName === null) return invalidPlayerName();
  const existingIndex = state.players.findIndex((player) => player.userId === userId);
  if (existingIndex >= 0) {
    return {
      ok: true,
      state: incrementState(
        state,
        state.players.map((player, index) =>
          index === existingIndex
            ? {
                ...player,
                name: normalizedName,
                avatarId,
                connected: true,
                disconnectedAt: undefined,
              }
            : player,
        ),
        now,
      ),
    };
  }
  if (state.phase !== "lobby") {
    return {
      ok: false,
      code: "game_in_progress",
      message: "The game has already started.",
    };
  }
  if (state.players.length >= MAX_PLAYERS) {
    return { ok: false, code: "room_full", message: "Room is full." };
  }
  return {
    ok: true,
    state: incrementState(
      state,
      [...state.players, createPlayer(userId, normalizedName, avatarId)],
      now,
    ),
  };
}

export function setPlayerConnection(
  state: RoomState,
  userId: string,
  connected: boolean,
  now: string,
): RoomState {
  const player = state.players.find((candidate) => candidate.userId === userId);
  if (player === undefined || player.connected === connected) return state;
  const updated = incrementState(
    state,
    state.players.map((candidate) =>
      candidate.userId === userId
        ? {
            ...candidate,
            connected,
            disconnectedAt: connected ? undefined : now,
          }
        : candidate,
    ),
    now,
  );
  return updated;
}

export function leaveRoom(
  state: RoomState,
  userId: string,
  now: string,
): LeaveRoomResult {
  const leavingIndex = state.players.findIndex((player) => player.userId === userId);
  if (leavingIndex < 0) {
    return {
      ok: false,
      code: "player_not_found",
      message: "Player is not in this room.",
    };
  }
  const leavingPlayer = state.players[leavingIndex]!;

  const remainingPlayers = state.players.filter((player) => player.userId !== userId);
  if (remainingPlayers.length === 0) return { ok: true, state: null };

  const nextCreatorUserId = state.creatorUserId === userId
    ? (remainingPlayers.find((player) => player.connected) ?? remainingPlayers[0]!).userId
    : state.creatorUserId;

  if (state.phase === "playing") {
    return {
      ok: true,
      state: removePlayerFromActiveRound(
        state,
        leavingPlayer,
        leavingIndex,
        remainingPlayers,
        nextCreatorUserId,
        now,
      ),
    };
  }

  const returnToLobby = remainingPlayers.length < 2;
  const players = returnToLobby
    ? remainingPlayers.map(resetPlayerForLobby)
    : remainingPlayers;
  const previousCurrentUserId = state.players[state.currentPlayerIndex]?.userId;
  const retainedCurrentIndex = players.findIndex(
    (player) => player.userId === previousCurrentUserId,
  );

  return {
    ok: true,
    state: {
      ...state,
      creatorUserId: nextCreatorUserId,
      phase: returnToLobby ? "lobby" : state.phase,
      players,
      currentPlayerIndex: returnToLobby
        ? 0
        : retainedCurrentIndex >= 0
          ? retainedCurrentIndex
          : Math.min(leavingIndex, players.length - 1),
      nextFinishPosition: returnToLobby ? 1 : state.nextFinishPosition,
      lastAction: {
        type: "player_left",
        actorUserId: leavingPlayer.userId,
        actorName: leavingPlayer.name,
      },
      stateVersion: state.stateVersion + 1,
      updatedAt: now,
    },
  };
}

function removePlayerFromActiveRound(
  state: RoomState,
  leavingPlayer: PlayerProfile,
  leavingIndex: number,
  remainingPlayers: readonly PlayerProfile[],
  creatorUserId: string,
  now: string,
): RoomState {
  const recipientIds = remainingPlayers
    .filter((player) => player.status === "playing" && player.connected)
    .map((player) => player.userId);
  const redistributedHands = new Map(
    remainingPlayers.map((player) => [player.userId, [...player.hand]]),
  );
  if (recipientIds.length > 0) {
    leavingPlayer.hand.forEach((card, index) => {
      redistributedHands.get(recipientIds[index % recipientIds.length]!)!.push(card);
    });
  }

  let nextFinishPosition = state.nextFinishPosition;
  let players = remainingPlayers.map((player): PlayerProfile => {
    if (!recipientIds.includes(player.userId)) return player;
    const hand = removePairs(redistributedHands.get(player.userId)!);
    if (hand.length === 0) {
      return {
        ...player,
        hand,
        status: "finished",
        finishPosition: nextFinishPosition++,
      };
    }
    return { ...player, hand };
  });

  const activePlayers = players.filter(
    (player) => player.status === "playing" && player.connected,
  );
  let phase: RoomPhase = "playing";
  if (activePlayers.length <= 1) {
    const shayeb = activePlayers[0];
    if (shayeb !== undefined) {
      players = players.map((player) =>
        player.userId === shayeb.userId
          ? { ...player, status: "shayeb" as const, finishPosition: nextFinishPosition }
          : player,
      );
    }
    players = applyRoundScores(players);
    phase = "round_end";
  }

  const previousCurrentUserId = state.players[state.currentPlayerIndex]?.userId;
  const retainedCurrentIndex = players.findIndex(
    (player) =>
      player.userId === previousCurrentUserId &&
      player.status === "playing" &&
      player.connected,
  );
  const currentPlayerIndex = phase === "playing"
    ? retainedCurrentIndex >= 0
      ? retainedCurrentIndex
      : findActivePlayerIndex(players, leavingIndex % players.length)
    : Math.min(leavingIndex, players.length - 1);

  return {
    ...state,
    creatorUserId,
    phase,
    players,
    currentPlayerIndex,
    nextFinishPosition,
    lastAction: {
      type: "player_left",
      actorUserId: leavingPlayer.userId,
      actorName: leavingPlayer.name,
    },
    stateVersion: state.stateVersion + 1,
    updatedAt: now,
  };
}

function resetPlayerForLobby(player: PlayerProfile): PlayerProfile {
  return {
    ...player,
    hand: [],
    status: "playing",
    finishPosition: 0,
  };
}

function findActivePlayerIndex(
  players: readonly PlayerProfile[],
  startIndex: number,
): number {
  for (let offset = 0; offset < players.length; offset += 1) {
    const index = (startIndex + offset) % players.length;
    const player = players[index];
    if (player?.status === "playing" && player.connected) return index;
  }
  return 0;
}

export function expireDisconnectedPlayers(
  state: RoomState,
  disconnectedBeforeOrAt: number,
  now: string,
): RoomState | null {
  const expiredUserIds = state.players
    .filter((player) =>
      !player.connected &&
      player.disconnectedAt !== undefined &&
      Date.parse(player.disconnectedAt) <= disconnectedBeforeOrAt,
    )
    .map((player) => player.userId);
  let current: RoomState | null = state;
  for (const userId of expiredUserIds) {
    if (current === null) break;
    const result = leaveRoom(current, userId, now);
    if (result.ok) current = result.state;
  }
  return current;
}

export function createRoomView(state: RoomState, localUserId: string): RoomView {
  const currentPlayer = state.players[state.currentPlayerIndex];
  const drawFrom = findDrawTarget(state);
  return {
    roomCode: state.roomCode,
    phase: state.phase,
    stateVersion: state.stateVersion,
    localUserId,
    canStart:
      state.phase === "lobby" &&
      state.creatorUserId === localUserId &&
      state.players.length >= 2 &&
      state.players.every((player) => player.connected),
    canStartNewRound:
      state.phase === "round_end" &&
      state.creatorUserId === localUserId &&
      state.players.length >= 2 &&
      state.players.every((player) => player.connected),
    currentPlayerUserId: currentPlayer?.userId,
    drawFromUserId: drawFrom?.userId,
    roundNumber: state.roundNumber,
    lastAction: redactLastAction(state.lastAction, localUserId),
    players: state.players.map((player) => ({
      userId: player.userId,
      name: player.name,
      avatarId: player.avatarId,
      connected: player.connected,
      score: player.score,
      status: player.status,
      finishPosition: player.finishPosition,
      cardCount: player.hand.length,
      ...(player.userId === localUserId ? { hand: player.hand } : {}),
    })),
  };
}

export const createLobbyView = createRoomView;

export function findDrawTarget(state: RoomState): PlayerProfile | undefined {
  if (state.players.length < 2) return undefined;
  const currentPlayer = state.players[state.currentPlayerIndex];
  let index = (state.currentPlayerIndex - 1 + state.players.length) % state.players.length;
  for (let attempt = 0; attempt < state.players.length; attempt += 1) {
    const player = state.players[index];
    if (player?.userId !== currentPlayer?.userId &&
        player?.status === "playing" &&
        player.connected &&
        player.hand.length > 0) return player;
    index = (index - 1 + state.players.length) % state.players.length;
  }
  return undefined;
}

export function normalizeStoredRoom(value: unknown): RoomState | null {
  if (!isRecord(value) ||
      typeof value.roomCode !== "string" ||
      typeof value.creatorUserId !== "string" ||
      !Array.isArray(value.players) ||
      typeof value.stateVersion !== "number") {
    return null;
  }
  const players = value.players.flatMap((raw): PlayerProfile[] => {
    if (!isRecord(raw) ||
        typeof raw.userId !== "string" ||
        typeof raw.name !== "string" ||
        typeof raw.avatarId !== "string" ||
        (raw.disconnectedAt !== undefined && !isTimestamp(raw.disconnectedAt))) return [];
    if (raw.hand !== undefined &&
        (!Array.isArray(raw.hand) || !raw.hand.every(isGameCard))) return [];
    return [{
      userId: raw.userId,
      name: raw.name,
      avatarId: raw.avatarId,
      connected: raw.connected === true,
      disconnectedAt: raw.connected === true
        ? undefined
        : typeof raw.disconnectedAt === "string"
          ? raw.disconnectedAt
          : typeof value.updatedAt === "string"
            ? value.updatedAt
            : new Date().toISOString(),
      hand: Array.isArray(raw.hand) ? raw.hand : [],
      score: typeof raw.score === "number" ? raw.score : 0,
      status: isPlayerStatus(raw.status) ? raw.status : "playing",
      finishPosition: typeof raw.finishPosition === "number" ? raw.finishPosition : 0,
    }];
  });
  if (players.length !== value.players.length) return null;
  if (value.phase !== undefined && !isRoomPhase(value.phase)) return null;
  if (value.currentPlayerIndex !== undefined &&
      (!Number.isInteger(value.currentPlayerIndex) ||
        Number(value.currentPlayerIndex) < 0 ||
        Number(value.currentPlayerIndex) >= players.length)) return null;
  if (value.roundNumber !== undefined &&
      (!Number.isInteger(value.roundNumber) || Number(value.roundNumber) < 1)) return null;
  if (value.nextFinishPosition !== undefined &&
      (!Number.isInteger(value.nextFinishPosition) ||
        Number(value.nextFinishPosition) < 1)) return null;
  if (value.lastAction !== undefined && !isGameAction(value.lastAction)) return null;
  return {
    roomCode: value.roomCode,
    creatorUserId: value.creatorUserId,
    phase: isRoomPhase(value.phase) ? value.phase : "lobby",
    stateVersion: value.stateVersion,
    players,
    currentPlayerIndex:
      typeof value.currentPlayerIndex === "number" ? value.currentPlayerIndex : 0,
    roundNumber: typeof value.roundNumber === "number" ? value.roundNumber : 1,
    nextFinishPosition:
      typeof value.nextFinishPosition === "number" ? value.nextFinishPosition : 1,
    lastAction: isGameAction(value.lastAction) ? value.lastAction : undefined,
    createdAt: typeof value.createdAt === "string" ? value.createdAt : new Date().toISOString(),
    updatedAt: typeof value.updatedAt === "string" ? value.updatedAt : new Date().toISOString(),
  };
}

function createPlayer(userId: string, name: string, avatarId: string): PlayerProfile {
  return {
    userId,
    name,
    avatarId,
    connected: true,
    hand: [],
    score: 0,
    status: "playing",
    finishPosition: 0,
  };
}

function incrementState(
  state: RoomState,
  players: readonly PlayerProfile[],
  now: string,
): RoomState {
  return { ...state, stateVersion: state.stateVersion + 1, players, updatedAt: now };
}

function invalidPlayerName(): LobbyResult {
  return {
    ok: false,
    code: "invalid_player_name",
    message: "Player name must contain between 1 and 24 visible characters.",
  };
}

function normalizePlayerName(name: string): string | null {
  const normalized = name.trim().replace(/\s+/g, " ");
  return normalized.length === 0 || normalized.length > 24 ? null : normalized;
}

function redactLastAction(
  action: GameActionSummary | undefined,
  localUserId: string,
): GameActionSummary | undefined {
  if (action === undefined || action.actorUserId === localUserId) return action;
  const { drawnCard: _, ...publicAction } = action;
  return publicAction;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isGameCard(value: unknown): value is GameCard {
  return isRecord(value) &&
    typeof value.id === "string" &&
    ["hearts", "diamonds", "clubs", "spades"].includes(String(value.suit)) &&
    typeof value.rank === "number" && value.rank >= 1 && value.rank <= 13;
}

function isPlayerStatus(value: unknown): value is PlayerStatus {
  return value === "playing" || value === "finished" || value === "shayeb";
}

function isRoomPhase(value: unknown): value is RoomPhase {
  return value === "lobby" || value === "playing" || value === "round_end";
}

function isTimestamp(value: unknown): value is string {
  return typeof value === "string" && Number.isFinite(Date.parse(value));
}

function isGameAction(value: unknown): value is GameActionSummary {
  return isRecord(value) &&
    ["game_started", "card_drawn", "hand_shuffled", "round_started", "player_left"].includes(
      String(value.type),
    ) &&
    typeof value.actorUserId === "string" &&
    (value.actorName === undefined || typeof value.actorName === "string") &&
    (value.targetUserId === undefined || typeof value.targetUserId === "string") &&
    (value.madePair === undefined || typeof value.madePair === "boolean") &&
    (value.drawnCard === undefined || isGameCard(value.drawnCard));
}
