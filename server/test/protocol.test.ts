import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { MAX_MESSAGE_BYTES, parseClientMessage } from "../src/protocol/messages.ts";

describe("client protocol", () => {
  it("parses a lobby join command", () => {
    const result = parseClientMessage(JSON.stringify({
      protocolVersion: 2,
      type: "join_room",
      actionId: "join-0001",
      payload: { name: "Guest", avatarId: "default" },
    }));
    assert.equal(result.ok, true);
  });

  it("rejects an unsupported protocol version", () => {
    const result = parseClientMessage(JSON.stringify({
      protocolVersion: 1,
      type: "ping",
      actionId: "ping-0001",
      payload: {},
    }));
    assert.equal(result.ok, false);
    if (!result.ok) assert.equal(result.code, "unsupported_protocol");
  });

  it("rejects oversized messages", () => {
    const result = parseClientMessage("x".repeat(MAX_MESSAGE_BYTES + 1));
    assert.equal(result.ok, false);
    if (!result.ok) assert.equal(result.code, "message_too_large");
  });

  it("parses an authoritative draw command without accepting a drawer identity", () => {
    const result = parseClientMessage(JSON.stringify({
      protocolVersion: 2,
      type: "draw_card",
      actionId: "draw-0001",
      expectedStateVersion: 4,
      payload: { targetUserId: "user-2", cardIndex: 3 },
    }));
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.message.type, "draw_card");
    assert.equal("drawerUserId" in result.message.payload, false);
  });

  it("rejects a negative draw position", () => {
    const result = parseClientMessage(JSON.stringify({
      protocolVersion: 2,
      type: "draw_card",
      actionId: "draw-0002",
      payload: { targetUserId: "user-2", cardIndex: -1 },
    }));
    assert.equal(result.ok, false);
    if (!result.ok) assert.equal(result.code, "invalid_draw");
  });
});
