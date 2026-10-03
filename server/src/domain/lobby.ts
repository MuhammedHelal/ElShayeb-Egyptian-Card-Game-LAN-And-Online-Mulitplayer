export const MAX_PLAYERS = 6;

export interface PlayerProfile {
  readonly userId: string;
  readonly name: string;
  readonly avatarId: string;
  readonly connected: boolean;
}

export interface LobbyState {
  readonly roomCode: string;
  readonly creatorUserId: string;
  readonly phase: "lobby";
  readonly stateVersion: number;
  readonly players: readonly PlayerProfile[];
  readonly createdAt: string;
  readonly updatedAt: string;
}

export interface LobbyView {
  readonly roomCode: string;
  readonly phase: "lobby";
  readonly stateVersion: number;
  readonly localUserId: string;
  readonly canStart: boolean;
  readonly players: readonly PlayerProfile[];
}

export type LobbyResult =
  | { readonly ok: true; readonly state: LobbyState }
  | { readonly ok: false; readonly code: LobbyErrorCode; readonly message: string };

export type LobbyErrorCode =
  | "room_already_exists"
  | "room_not_found"
  | "room_full"
  | "invalid_player_name";

export function createLobby(
  roomCode: string,
  userId: string,
  name: string,
  avatarId: string,
  now: string,
): LobbyResult {
  const normalizedName = normalizePlayerName(name);
  if (normalizedName === null) {
    return {
      ok: false,
      code: "invalid_player_name",
      message: "Player name must contain between 1 and 24 visible characters.",
    };
  }
  return {
    ok: true,
    state: {
      roomCode,
      creatorUserId: userId,
      phase: "lobby",
      stateVersion: 1,
      players: [{ userId, name: normalizedName, avatarId, connected: true }],
      createdAt: now,
      updatedAt: now,
    },
  };
}

export function joinLobby(
  state: LobbyState | null,
  userId: string,
  name: string,
  avatarId: string,
  now: string,
): LobbyResult {
  if (state === null) {
    return { ok: false, code: "room_not_found", message: "Room does not exist." };
  }
  const normalizedName = normalizePlayerName(name);
  if (normalizedName === null) {
    return {
      ok: false,
      code: "invalid_player_name",
      message: "Player name must contain between 1 and 24 visible characters.",
    };
  }
  const existingIndex = state.players.findIndex((player) => player.userId === userId);
  if (existingIndex >= 0) {
    return {
      ok: true,
      state: incrementState(
        state,
        state.players.map((player, index) =>
          index === existingIndex
            ? { ...player, name: normalizedName, avatarId, connected: true }
            : player,
        ),
        now,
      ),
    };
  }
  if (state.players.length >= MAX_PLAYERS) {
    return { ok: false, code: "room_full", message: "Room is full." };
  }
  return {
    ok: true,
    state: incrementState(
      state,
      [...state.players, { userId, name: normalizedName, avatarId, connected: true }],
      now,
    ),
  };
}

export function setPlayerConnection(
  state: LobbyState,
  userId: string,
  connected: boolean,
  now: string,
): LobbyState {
  const player = state.players.find((candidate) => candidate.userId === userId);
  if (player === undefined || player.connected === connected) return state;
  return incrementState(
    state,
    state.players.map((candidate) =>
      candidate.userId === userId ? { ...candidate, connected } : candidate,
    ),
    now,
  );
}

export function createLobbyView(state: LobbyState, localUserId: string): LobbyView {
  return {
    roomCode: state.roomCode,
    phase: state.phase,
    stateVersion: state.stateVersion,
    localUserId,
    canStart: state.creatorUserId === localUserId && state.players.length >= 2,
    players: state.players,
  };
}

function incrementState(
  state: LobbyState,
  players: readonly PlayerProfile[],
  now: string,
): LobbyState {
  return { ...state, stateVersion: state.stateVersion + 1, players, updatedAt: now };
}

function normalizePlayerName(name: string): string | null {
  const normalized = name.trim().replace(/\s+/g, " ");
  return normalized.length === 0 || normalized.length > 24 ? null : normalized;
}
