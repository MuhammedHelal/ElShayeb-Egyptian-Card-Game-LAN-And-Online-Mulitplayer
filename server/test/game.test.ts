import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { drawCard, startGame } from "../src/domain/game.ts";
import {
  createLobby,
  createRoomView,
  joinLobby,
  setPlayerConnection,
  type RoomState,
} from "../src/domain/lobby.ts";

describe("authoritative game rules", () => {
  it("allows only the creator to start and deals the 49-card Shayeb deck", () => {
    const room = twoPlayerLobby();
    const rejected = startGame(room, "guest", "three", () => 0.25);
    assert.equal(rejected.ok, false);
    if (!rejected.ok) assert.equal(rejected.code, "not_room_creator");

    const started = startGame(room, "host", "three", () => 0.25);
    assert.equal(started.ok, true);
    if (!started.ok) return;
    assert.notEqual(started.state.phase, "lobby");
    const remainingKings = started.state.players
      .flatMap((player) => player.hand)
      .filter((card) => card.rank === 13);
    assert.equal(remainingKings.length, 1);
    assert.equal(started.state.stateVersion, room.stateVersion + 1);
  });

  it("validates turn and target on the server, removes a pair, and scores the round", () => {
    const state = controlledPlayingState();
    const rejected = drawCard(state, "guest", "host", 0, "now", () => 0);
    assert.equal(rejected.ok, false);
    if (!rejected.ok) assert.equal(rejected.code, "not_your_turn");

    const result = drawCard(state, "host", "guest", 0, "now", () => 0);
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.state.phase, "round_end");
    assert.equal(result.state.players[0]?.status, "finished");
    assert.equal(result.state.players[0]?.score, 100);
    assert.equal(result.state.players[1]?.status, "shayeb");
    assert.equal(result.state.players[1]?.score, -50);
  });

  it("never exposes an opponent hand or another player's drawn card", () => {
    const result = drawCard(controlledPlayingState(), "host", "guest", 0, "now", () => 0);
    assert.equal(result.ok, true);
    if (!result.ok) return;
    const hostView = createRoomView(result.state, "host");
    const guestView = createRoomView(result.state, "guest");
    assert.ok(Array.isArray(hostView.players[0]?.hand));
    assert.equal(hostView.players[1]?.hand, undefined);
    assert.equal(guestView.players[0]?.hand, undefined);
    assert.ok(Array.isArray(guestView.players[1]?.hand));
    assert.notEqual(hostView.lastAction?.drawnCard, undefined);
    assert.equal(guestView.lastAction?.drawnCard, undefined);
  });

  it("pauses a two-player game on the disconnected player's turn", () => {
    const updated = setPlayerConnection(
      controlledPlayingState(),
      "host",
      false,
      "later",
    );
    assert.equal(updated.currentPlayerIndex, 0);
    assert.equal(updated.players[0]?.connected, false);
  });

  it("preserves a disconnected current player's turn when other opponents remain", () => {
    const room = twoPlayerLobby();
    const joined = joinLobby(room, "third", "Third", "c", "three");
    assert.equal(joined.ok, true);
    if (!joined.ok) return;
    const playing: RoomState = {
      ...joined.state,
      phase: "playing",
      currentPlayerIndex: 0,
      players: joined.state.players.map((player, index) => ({
        ...player,
        hand: [{ id: `card_${index}`, suit: "hearts", rank: index + 1 }],
      })),
    };

    const disconnected = setPlayerConnection(playing, "host", false, "later");

    assert.equal(disconnected.currentPlayerIndex, 0);

    const reconnected = setPlayerConnection(disconnected, "host", true, "latest");

    assert.equal(reconnected.currentPlayerIndex, 0);
    assert.equal(reconnected.players[0]?.connected, true);
  });

  it("does not allow drawing cards from a disconnected player", () => {
    const disconnected = setPlayerConnection(
      controlledPlayingState(),
      "guest",
      false,
      "later",
    );

    const result = drawCard(disconnected, "host", "guest", 0, "now", () => 0);

    assert.equal(result.ok, false);
    if (!result.ok) assert.equal(result.code, "invalid_draw_target");
  });

  it("does not start while a seated player is disconnected", () => {
    const disconnected = setPlayerConnection(
      twoPlayerLobby(),
      "guest",
      false,
      "later",
    );
    const result = startGame(disconnected, "host", "now", () => 0);
    assert.equal(result.ok, false);
    if (!result.ok) assert.equal(result.code, "not_enough_players");
  });
});

function twoPlayerLobby(): RoomState {
  const created = createLobby("ABC123", "host", "Host", "a", "one");
  assert.equal(created.ok, true);
  if (!created.ok) throw new Error("test setup failed");
  const joined = joinLobby(created.state, "guest", "Guest", "b", "two");
  assert.equal(joined.ok, true);
  if (!joined.ok) throw new Error("test setup failed");
  return joined.state;
}

function controlledPlayingState(): RoomState {
  const room = twoPlayerLobby();
  return {
    ...room,
    phase: "playing",
    currentPlayerIndex: 0,
    players: [
      {
        ...room.players[0]!,
        hand: [{ id: "hearts_5", suit: "hearts", rank: 5 }],
      },
      {
        ...room.players[1]!,
        hand: [
          { id: "clubs_5", suit: "clubs", rank: 5 },
          { id: "spades_13", suit: "spades", rank: 13 },
        ],
      },
    ],
  };
}
