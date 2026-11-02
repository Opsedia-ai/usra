// Standard Webhooks signature check (https://www.standardwebhooks.com), used
// by Supabase Auth hooks. Signed content is "{webhook-id}.{webhook-timestamp}.{body}",
// HMAC-SHA256 with the base64 secret after the "v1,whsec_" prefix.

import { base64ToBytes, hmacSha256Base64, timingSafeEqual } from "./crypto.ts";

export const DEFAULT_TOLERANCE_SECONDS = 5 * 60;

export class WebhookVerificationError extends Error {}

function secretBytes(secret: string): Uint8Array {
  const raw = secret.replace(/^v1,/, "").replace(/^whsec_/, "");
  try {
    return base64ToBytes(raw);
  } catch {
    throw new WebhookVerificationError("bad_secret_format");
  }
}

export async function signPayload(secret: string, id: string, timestamp: number, body: string): Promise<string> {
  return `v1,${await hmacSha256Base64(secretBytes(secret), `${id}.${timestamp}.${body}`)}`;
}

/**
 * Throws WebhookVerificationError unless one of the signatures in
 * `webhook-signature` matches and the timestamp is recent.
 */
export async function verifyWebhook(
  secret: string,
  headers: Headers,
  body: string,
  nowSeconds = Math.floor(Date.now() / 1000),
  toleranceSeconds = DEFAULT_TOLERANCE_SECONDS,
): Promise<void> {
  const id = headers.get("webhook-id");
  const ts = headers.get("webhook-timestamp");
  const sigHeader = headers.get("webhook-signature");
  if (!id || !ts || !sigHeader) throw new WebhookVerificationError("missing_headers");

  const timestamp = Number.parseInt(ts, 10);
  if (!Number.isFinite(timestamp) || Math.abs(nowSeconds - timestamp) > toleranceSeconds) {
    throw new WebhookVerificationError("timestamp_out_of_range");
  }

  const expected = await signPayload(secret, id, timestamp, body);
  const ok = sigHeader.split(" ").some((sig) => timingSafeEqual(sig, expected));
  if (!ok) throw new WebhookVerificationError("bad_signature");
}
