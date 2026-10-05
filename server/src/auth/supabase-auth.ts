import type { Env } from "../env";

interface SupabaseUser {
  readonly id: string;
}

export type AuthResult =
  | { readonly ok: true; readonly user: SupabaseUser }
  | { readonly ok: false; readonly message: string };

export async function verifySupabaseAccessToken(
  accessToken: string,
  env: Env,
): Promise<AuthResult> {
  let response: Response;
  try {
    response = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, {
      headers: {
        apikey: env.SUPABASE_PUBLISHABLE_KEY,
        Authorization: `Bearer ${accessToken}`,
      },
    });
  } catch {
    return { ok: false, message: "Authentication service is unavailable." };
  }

  if (!response.ok) {
    return { ok: false, message: "Supabase session is invalid or expired." };
  }
  const value: unknown = await response.json();
  if (!isRecord(value) || typeof value.id !== "string" || value.id.length === 0) {
    return { ok: false, message: "Authentication response is invalid." };
  }
  return { ok: true, user: { id: value.id } };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
