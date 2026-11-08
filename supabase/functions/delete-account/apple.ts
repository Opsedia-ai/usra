// Revokes Sign in with Apple when an account is deleted, as Apple requires
// (App Store guideline 5.1.1(v), TN3194). Native sign-in leaves us no Apple
// token to keep, so the app asks Apple for a fresh authorization code at
// deletion; this swaps it for a token and revokes that. Apple's refresh token
// is used for a moment and never stored.

import { base64ToBytes, bytesToBase64 } from "../_shared/crypto.ts";

export type AppleRevokeConfig = {
  /** The app's bundle id: what the native code was issued to. */
  clientId: string;
  teamId: string;
  keyId: string;
  /** The Sign in with Apple key (.p8), in PEM; `\n` may be escaped. */
  privateKey: string;
};

const APPLE = "https://appleid.apple.com";
const TIMEOUT_MS = 10_000;

function base64url(bytes: Uint8Array): string {
  return bytesToBase64(bytes).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

const text = new TextEncoder();
const encodeJson = (value: unknown) => base64url(text.encode(JSON.stringify(value)));

/** Apple's client secret: a short-lived ES256 JWT signed with the .p8 key. */
export async function appleClientSecret(config: AppleRevokeConfig, now = Date.now()): Promise<string> {
  const pem = config.privateKey.replaceAll("\\n", "\n")
    .replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  const key = await crypto.subtle.importKey(
    "pkcs8",
    base64ToBytes(pem) as BufferSource,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const iat = Math.floor(now / 1000);
  const unsigned = `${encodeJson({ alg: "ES256", kid: config.keyId, typ: "JWT" })}.${
    encodeJson({
      iss: config.teamId,
      iat,
      // Five minutes is plenty: one is made for each deletion.
      exp: iat + 300,
      aud: APPLE,
      sub: config.clientId,
    })
  }`;
  const signature = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, text.encode(unsigned));
  return `${unsigned}.${base64url(new Uint8Array(signature))}`;
}

/** A failure with a fixed code, safe to log: never a token or Apple's answer. */
export class AppleRevokeError extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}

/** Makes the revoker. Every failure it throws on purpose is an [AppleRevokeError]. */
export function createAppleRevoker(
  config: AppleRevokeConfig,
  fetchFn: typeof fetch = fetch,
): (authorizationCode: string) => Promise<void> {
  const post = (path: string, form: Record<string, string>) =>
    fetchFn(`${APPLE}${path}`, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams(form),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });

  return async (authorizationCode) => {
    const client = { client_id: config.clientId, client_secret: await appleClientSecret(config) };
    const exchanged = await post("/auth/token", {
      ...client,
      code: authorizationCode,
      grant_type: "authorization_code",
    });
    if (!exchanged.ok) throw new AppleRevokeError(`token_http_${exchanged.status}`);
    const tokens = await exchanged.json().catch(() => {
      throw new AppleRevokeError("token_bad_response");
    });
    const [token, hint] = tokens.refresh_token
      ? [tokens.refresh_token, "refresh_token"]
      : [tokens.access_token, "access_token"];
    if (typeof token !== "string") throw new AppleRevokeError("token_missing");
    const revoked = await post("/auth/revoke", { ...client, token, token_type_hint: hint });
    if (!revoked.ok) throw new AppleRevokeError(`revoke_http_${revoked.status}`);
  };
}

/** The revoker, or undefined when the Apple key isn't set up on this project. */
export function appleRevokerFromEnv(
  env: (name: string) => string | undefined = (name) => Deno.env.get(name),
): ((authorizationCode: string) => Promise<void>) | undefined {
  const [teamId, keyId, privateKey] = [env("APPLE_TEAM_ID"), env("APPLE_KEY_ID"), env("APPLE_PRIVATE_KEY")];
  if (!teamId || !keyId || !privateKey) return undefined;
  return createAppleRevoker({ clientId: env("APPLE_CLIENT_ID") || "com.opsedia.usra", teamId, keyId, privateKey });
}
