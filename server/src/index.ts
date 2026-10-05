import type { Env } from "./env";
import { PROTOCOL_VERSION } from "./protocol/messages";
export { GameRoom } from "./game-room";

const ROOM_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const ROOM_CODE_PATTERN = /^[A-Z0-9]{6}$/;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/health") {
      return Response.json({
        status: "ok",
        service: "elshayeb-online",
        protocolVersion: PROTOCOL_VERSION,
      });
    }
    if (request.method === "POST" && url.pathname === "/room-code") {
      return Response.json({ roomCode: generateRoomCode() }, { status: 201 });
    }
    const match = url.pathname.match(/^\/rooms\/([^/]+)\/connect$/);
    if (match !== null) {
      const roomCode = match[1]?.toUpperCase();
      if (roomCode === undefined || !ROOM_CODE_PATTERN.test(roomCode)) {
        return Response.json({ error: "invalid_room_code" }, { status: 400 });
      }
      const id = env.GAME_ROOMS.idFromName(roomCode);
      return env.GAME_ROOMS.get(id).fetch(request);
    }
    return Response.json({ error: "not_found" }, { status: 404 });
  },
} satisfies ExportedHandler<Env>;

function generateRoomCode(): string {
  const values = new Uint32Array(6);
  crypto.getRandomValues(values);
  return Array.from(values, (value) => ROOM_CODE_ALPHABET[value % ROOM_CODE_ALPHABET.length]).join("");
}
