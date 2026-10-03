export const PROTOCOL_VERSION = 1;
export const MAX_MESSAGE_BYTES = 32 * 1024;

export interface PlayerIdentityPayload {
  readonly name: string;
  readonly avatarId: string;
}

export type ClientMessage =
  | {
      readonly protocolVersion: 1;
      readonly type: "authenticate";
      readonly actionId: string;
      readonly payload: { readonly accessToken: string };
    }
  | {
      readonly protocolVersion: 1;
      readonly type: "create_room";
      readonly actionId: string;
      readonly expectedStateVersion?: number;
      readonly payload: PlayerIdentityPayload;
    }
  | {
      readonly protocolVersion: 1;
      readonly type: "join_room";
      readonly actionId: string;
      readonly expectedStateVersion?: number;
      readonly payload: PlayerIdentityPayload;
    }
  | {
      readonly protocolVersion: 1;
      readonly type: "resume_room";
      readonly actionId: string;
      readonly expectedStateVersion?: number;
      readonly payload: PlayerIdentityPayload;
    }
  | {
      readonly protocolVersion: 1;
      readonly type: "leave_room" | "ping";
      readonly actionId: string;
      readonly expectedStateVersion?: number;
      readonly payload: Record<string, never>;
    };

export interface ServerMessage {
  readonly protocolVersion: 1;
  readonly type: string;
  readonly actionId?: string | undefined;
  readonly stateVersion?: number | undefined;
  readonly payload: unknown;
}

export type ProtocolParseResult =
  | { readonly ok: true; readonly message: ClientMessage }
  | { readonly ok: false; readonly code: string; readonly message: string };

const supportedTypes = new Set([
  "authenticate", "create_room", "join_room", "resume_room", "leave_room", "ping",
]);

export function parseClientMessage(raw: string | ArrayBuffer): ProtocolParseResult {
  const text = typeof raw === "string" ? raw : new TextDecoder().decode(raw);
  if (new TextEncoder().encode(text).byteLength > MAX_MESSAGE_BYTES) {
    return { ok: false, code: "message_too_large", message: "Message exceeds 32 KiB." };
  }
  let value: unknown;
  try { value = JSON.parse(text); } catch {
    return { ok: false, code: "invalid_json", message: "Message is not valid JSON." };
  }
  if (!isRecord(value)) {
    return { ok: false, code: "invalid_message", message: "Message must be an object." };
  }
  if (value.protocolVersion !== PROTOCOL_VERSION) {
    return { ok: false, code: "unsupported_protocol", message: "Unsupported protocol version." };
  }
  if (typeof value.type !== "string" || !supportedTypes.has(value.type)) {
    return { ok: false, code: "unsupported_message", message: "Unsupported message type." };
  }
  if (typeof value.actionId !== "string" || value.actionId.length < 8 || value.actionId.length > 128) {
    return { ok: false, code: "invalid_action_id", message: "A valid actionId is required." };
  }
  if (!isRecord(value.payload)) {
    return { ok: false, code: "invalid_payload", message: "Payload must be an object." };
  }
  if (value.type === "authenticate" &&
      (typeof value.payload.accessToken !== "string" || value.payload.accessToken.length < 20)) {
    return { ok: false, code: "invalid_token", message: "An access token is required." };
  }
  if (["create_room", "join_room", "resume_room"].includes(value.type) &&
      (typeof value.payload.name !== "string" || typeof value.payload.avatarId !== "string")) {
    return { ok: false, code: "invalid_player", message: "Player name and avatar are required." };
  }
  return { ok: true, message: value as ClientMessage };
}

export function encodeServerMessage(message: ServerMessage): string {
  return JSON.stringify(message);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
