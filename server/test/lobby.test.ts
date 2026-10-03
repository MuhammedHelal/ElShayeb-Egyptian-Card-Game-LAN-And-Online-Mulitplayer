import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { createLobby, joinLobby, MAX_PLAYERS } from "../src/domain/lobby.ts";

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
});
