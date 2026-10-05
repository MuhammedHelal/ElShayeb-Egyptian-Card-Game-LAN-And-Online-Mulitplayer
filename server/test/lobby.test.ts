import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  createLobby,
  createRoomView,
  expireDisconnectedPlayers,
  joinLobby,
  leaveRoom,
  MAX_PLAYERS,
  normalizeStoredRoom,
  setPlayerConnection,
} from "../src/domain/lobby.ts";

describe("lobby rules", () => {
  it("creates a persisted lobby owned by the authenticated user", () => {
    const result = createLobby("ABC123", "user-1", " Ashraf ", "default", "now");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.state.creatorUserId, "user-1");
    assert.equal(result.state.players[0]?.name, "Ashraf");
  });

  it("reconnects an existing player without duplicating the seat", () => {
    const created = createLobby("ABC123", "user-1", "Host", "a", "one");
    assert.equal(created.ok, true);
    if (!created.ok) return;
    const joined = joinLobby(created.state, "user-1", "Host 2", "b", "two");
    assert.equal(joined.ok, true);
    if (!joined.ok) return;
    assert.equal(joined.state.players.length, 1);
    assert.equal(joined.state.players[0]?.name, "Host 2");
  });

  it("rejects a seventh player", () => {
    let result = createLobby("ABC123", "user-0", "Player 0", "a", "zero");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    let state = result.state;
    for (let index = 1; index < MAX_PLAYERS; index += 1) {
      const joined = joinLobby(state, `user-${index}`, `Player ${index}`, "a", `${index}`);
      assert.equal(joined.ok, true);
      if (!joined.ok) return;
      state = joined.state;
    }
    const rejected = joinLobby(state, "user-6", "Player 6", "a", "six");
    assert.deepEqual(rejected, { ok: false, code: "room_full", message: "Room is full." });
  });

  it("releases a lobby seat so another player can join", () => {
    let result = createLobby("ABC123", "user-0", "Player 0", "a", "zero");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    let state = result.state;
    for (let index = 1; index < MAX_PLAYERS; index += 1) {
      const joined = joinLobby(state, `user-${index}`, `Player ${index}`, "a", `${index}`);
      assert.equal(joined.ok, true);
      if (!joined.ok) return;
      state = joined.state;
    }

    const left = leaveRoom(state, "user-5", "left");
    assert.equal(left.ok, true);
    if (!left.ok || left.state === null) return;
    const replacement = joinLobby(left.state, "user-6", "Player 6", "a", "joined");
    assert.equal(replacement.ok, true);
    if (!replacement.ok) return;
    assert.equal(replacement.state.players.length, MAX_PLAYERS);
    assert.equal(replacement.state.players.some((player) => player.userId === "user-5"), false);
  });

  it("transfers ownership when the creator explicitly leaves", () => {
    const created = createLobby("ABC123", "host", "Host", "a", "one");
    assert.equal(created.ok, true);
    if (!created.ok) return;
    const second = joinLobby(created.state, "guest-1", "Guest 1", "b", "two");
    assert.equal(second.ok, true);
    if (!second.ok) return;
    const third = joinLobby(second.state, "guest-2", "Guest 2", "c", "three");
    assert.equal(third.ok, true);
    if (!third.ok) return;

    const left = leaveRoom(third.state, "host", "four");
    assert.equal(left.ok, true);
    if (!left.ok || left.state === null) return;
    assert.equal(left.state.creatorUserId, "guest-1");
    assert.equal(createRoomView(left.state, "guest-1").canStart, true);
  });

  it("deletes an empty room after its final player leaves", () => {
    const created = createLobby("ABC123", "host", "Host", "a", "one");
    assert.equal(created.ok, true);
    if (!created.ok) return;
    const left = leaveRoom(created.state, "host", "two");
    assert.deepEqual(left, { ok: true, state: null });
  });

  it("keeps an active round running and redistributes cards when a player leaves", () => {
    const created = createLobby("ABC123", "host", "Host", "a", "one");
    assert.equal(created.ok, true);
    if (!created.ok) return;
    const second = joinLobby(created.state, "guest-1", "Guest 1", "b", "two");
    assert.equal(second.ok, true);
    if (!second.ok) return;
    const third = joinLobby(second.state, "guest-2", "Guest 2", "c", "three");
    assert.equal(third.ok, true);
    if (!third.ok) return;
    const playing = {
      ...third.state,
      phase: "playing" as const,
      currentPlayerIndex: 1,
      players: third.state.players.map((player, index) => ({
        ...player,
        hand: [{
          id: `${player.userId}-card`,
          suit: "hearts" as const,
          rank: index + 1,
        }],
      })),
    };

    const left = leaveRoom(playing, "guest-1", "four");
    assert.equal(left.ok, true);
    if (!left.ok || left.state === null) return;
    assert.equal(left.state.phase, "playing");
    assert.equal(left.state.currentPlayerIndex, 1);
    assert.equal(left.state.players.length, 2);
    assert.equal(left.state.players.some((player) => player.userId === "guest-1"), false);
    assert.equal(
      left.state.players.reduce((count, player) => count + player.hand.length, 0),
      3,
    );
    assert.deepEqual(left.state.lastAction, {
      type: "player_left",
      actorUserId: "guest-1",
      actorName: "Guest 1",
    });
  });

  it("removes pairs created while redistributing a leaving player's cards", () => {
    const created = createLobby("ABC123", "host", "Host", "a", "one");
    assert.equal(created.ok, true);
    if (!created.ok) return;
    const second = joinLobby(created.state, "guest-1", "Guest 1", "b", "two");
    assert.equal(second.ok, true);
    if (!second.ok) return;
    const third = joinLobby(second.state, "guest-2", "Guest 2", "c", "three");
    assert.equal(third.ok, true);
    if (!third.ok) return;
    const playing = {
      ...third.state,
      phase: "playing" as const,
      players: [
        { ...third.state.players[0]!, hand: [{ id: "h5", suit: "hearts" as const, rank: 5 }] },
        { ...third.state.players[1]!, hand: [{ id: "c5", suit: "clubs" as const, rank: 5 }] },
        { ...third.state.players[2]!, hand: [{ id: "s13", suit: "spades" as const, rank: 13 }] },
      ],
    };

    const left = leaveRoom(playing, "guest-1", "four");

    assert.equal(left.ok, true);
    if (!left.ok || left.state === null) return;
    assert.equal(left.state.players[0]?.hand.length, 0);
    assert.equal(left.state.players[0]?.status, "finished");
    assert.equal(left.state.phase, "round_end");
  });

  it("ends a two-player round without ejecting the remaining player", () => {
    const created = createLobby("ABC123", "host", "Host", "a", "one");
    assert.equal(created.ok, true);
    if (!created.ok) return;
    const joined = joinLobby(created.state, "guest", "Guest", "b", "two");
    assert.equal(joined.ok, true);
    if (!joined.ok) return;
    const playing = {
      ...joined.state,
      phase: "playing" as const,
      players: [
        { ...joined.state.players[0]!, hand: [{ id: "h1", suit: "hearts" as const, rank: 1 }] },
        { ...joined.state.players[1]!, hand: [{ id: "s13", suit: "spades" as const, rank: 13 }] },
      ],
    };

    const left = leaveRoom(playing, "guest", "three");

    assert.equal(left.ok, true);
    if (!left.ok || left.state === null) return;
    assert.equal(left.state.phase, "round_end");
    assert.equal(left.state.players.length, 1);
    assert.equal(left.state.players[0]?.userId, "host");
    assert.equal(left.state.players[0]?.status, "shayeb");
  });

  it("allows only the creator to start a lobby with at least two players", async () => {
    const { createLobbyView } = await import("../src/domain/lobby.ts");
    const created = createLobby("ABC123", "user-1", "Host", "a", "one");
    assert.equal(created.ok, true);
    if (!created.ok) return;
    const joined = joinLobby(created.state, "user-2", "Guest", "b", "two");
    assert.equal(joined.ok, true);
    if (!joined.ok) return;
    assert.equal(createLobbyView(joined.state, "user-1").canStart, true);
    assert.equal(createLobbyView(joined.state, "user-2").canStart, false);
  });

  it("does not allow the creator to start with a disconnected opponent", () => {
    const created = createLobby("ABC123", "host", "Host", "a", "one");
    assert.equal(created.ok, true);
    if (!created.ok) return;
    const joined = joinLobby(created.state, "guest", "Guest", "b", "two");
    assert.equal(joined.ok, true);
    if (!joined.ok) return;
    const disconnected = setPlayerConnection(joined.state, "guest", false, "three");
    assert.equal(createRoomView(disconnected, "host").canStart, false);
  });

  it("preserves the current player's turn across a disconnect and reconnect", () => {
    const created = createLobby("ABC123", "host", "Host", "a", "one");
    assert.equal(created.ok, true);
    if (!created.ok) return;
    const second = joinLobby(created.state, "guest-1", "Guest 1", "b", "two");
    assert.equal(second.ok, true);
    if (!second.ok) return;
    const third = joinLobby(second.state, "guest-2", "Guest 2", "c", "three");
    assert.equal(third.ok, true);
    if (!third.ok) return;
    const playing = {
      ...third.state,
      phase: "playing" as const,
      currentPlayerIndex: 1,
    };

    const disconnected = setPlayerConnection(playing, "guest-1", false, "four");
    assert.equal(disconnected.currentPlayerIndex, 1);
    assert.equal(createRoomView(disconnected, "host").currentPlayerUserId, "guest-1");

    const reconnected = setPlayerConnection(disconnected, "guest-1", true, "five");
    assert.equal(reconnected.currentPlayerIndex, 1);
    assert.equal(createRoomView(reconnected, "guest-1").currentPlayerUserId, "guest-1");
  });

  it("expires an abandoned disconnected seat after its reconnect grace period", () => {
    const created = createLobby("ABC123", "host", "Host", "a", "2026-01-01T00:00:00Z");
    assert.equal(created.ok, true);
    if (!created.ok) return;
    const joined = joinLobby(
      created.state,
      "guest",
      "Guest",
      "b",
      "2026-01-01T00:00:01Z",
    );
    assert.equal(joined.ok, true);
    if (!joined.ok) return;
    const disconnected = setPlayerConnection(
      joined.state,
      "guest",
      false,
      "2026-01-01T00:00:02Z",
    );

    const retained = expireDisconnectedPlayers(
      disconnected,
      Date.parse("2026-01-01T00:00:01Z"),
      "2026-01-01T00:01:00Z",
    );
    assert.equal(retained?.players.length, 2);
    const expired = expireDisconnectedPlayers(
      disconnected,
      Date.parse("2026-01-01T00:00:02Z"),
      "2026-01-01T00:05:02Z",
    );
    assert.equal(expired?.players.length, 1);
    assert.equal(expired?.players[0]?.userId, "host");
  });

  it("migrates legacy lobby storage but rejects corrupted game cards", () => {
    const legacy = {
      roomCode: "ABC123",
      creatorUserId: "user-1",
      phase: "lobby",
      stateVersion: 1,
      players: [{
        userId: "user-1",
        name: "Host",
        avatarId: "a",
        connected: true,
      }],
      createdAt: "one",
      updatedAt: "one",
    };
    assert.notEqual(normalizeStoredRoom(legacy), null);
    assert.equal(
      normalizeStoredRoom({
        ...legacy,
        players: [{ ...legacy.players[0], hand: [{ rank: "five" }] }],
      }),
      null,
    );
  });
});
