// Shared pieces of the sync Edge Functions (docs/sync-design.md, sections 7–8):
// the exact bytes each signature covers, request decoding, the caller's Auth
// session, and the database calls (service role) they end in.
//
// Binary values in request and response bodies are standard base64; inside
// signed JSON (log entries, beacons) they are unpadded base64url.

import { HttpError, isRecord } from "./http.ts";
import { base64ToBytes } from "./crypto.ts";

// --- Signed messages ---------------------------------------------------------------

const encoder = new TextEncoder();

/** A domain-separation label followed by a 0x00 byte (section 5). */
export function label(name: string): Uint8Array {
  return concatBytes(encoder.encode(name), new Uint8Array([0]));
}

export function concatBytes(...parts: Uint8Array[]): Uint8Array {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let offset = 0;
  for (const part of parts) {
    out.set(part, offset);
    offset += part.length;
  }
  return out;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export function isUuid(value: unknown): value is string {
  return typeof value === "string" && UUID.test(value);
}

/** A lowercase UUID string as its 16 raw bytes. */
export function uuidBytes(id: string): Uint8Array {
  if (!isUuid(id)) throw new Error("not a uuid");
  const hex = id.replaceAll("-", "");
  return Uint8Array.from({ length: 16 }, (_, i) => parseInt(hex.slice(i * 2, i * 2 + 2), 16));
}

/** "usra/v1/bind-session" || 0x00 || session_id (16) || nonce (32) */
export function bindSessionMessage(sessionId: string, nonce: Uint8Array): Uint8Array {
  return concatBytes(label("usra/v1/bind-session"), uuidBytes(sessionId), nonce);
}

/** "usra/v1/approve-device" || 0x00 || user_id (16) || device_id (16) || dkx (32) || dsig (32) || nonce (32) */
export function approveDeviceMessage(
  userId: string,
  deviceId: string,
  kx: Uint8Array,
  sig: Uint8Array,
  nonce: Uint8Array,
): Uint8Array {
  return concatBytes(label("usra/v1/approve-device"), uuidBytes(userId), uuidBytes(deviceId), kx, sig, nonce);
}

/** "usra/v1/log-entry" || 0x00 || entry_bytes */
export function logEntryMessage(entry: Uint8Array): Uint8Array {
  return concatBytes(label("usra/v1/log-entry"), entry);
}

/** "usra/v1/head" || 0x00 || beacon_bytes */
export function headMessage(beacon: Uint8Array): Uint8Array {
  return concatBytes(label("usra/v1/head"), beacon);
}

// --- Request decoding -----------------------------------------------------------------

/** Strict standard base64 (padding required, no whitespace); `bytes` = exact length if given. */
export function decodeBase64Field(
  body: Record<string, unknown>,
  field: string,
  opts: { bytes?: number; maxBytes?: number; optional?: boolean } = {},
): Uint8Array | null {
  const value = body[field];
  if (value === undefined || value === null) {
    if (opts.optional) return null;
    throw new HttpError(400, "invalid_request", `${field} is required`);
  }
  if (typeof value !== "string" || value.length % 4 !== 0 || !/^[A-Za-z0-9+/]*={0,2}$/.test(value)) {
    throw new HttpError(400, "invalid_request", `${field} must be base64`);
  }
  let bytes: Uint8Array;
  try {
    bytes = base64ToBytes(value);
  } catch {
    throw new HttpError(400, "invalid_request", `${field} must be base64`);
  }
  if (opts.bytes !== undefined && bytes.length !== opts.bytes) {
    throw new HttpError(400, "invalid_request", `${field} must be ${opts.bytes} bytes`);
  }
  if (opts.maxBytes !== undefined && bytes.length > opts.maxBytes) {
    throw new HttpError(400, "invalid_request", `${field} is too large`);
  }
  return bytes;
}

export function requireUuidField(body: Record<string, unknown>, field: string): string {
  const value = body[field];
  if (!isUuid(value)) throw new HttpError(400, "invalid_request", `${field} must be a lowercase uuid`);
  return value;
}

export function requireBody(value: unknown): Record<string, unknown> {
  if (!isRecord(value)) throw new HttpError(400, "invalid_request", "Expected a JSON object");
  return value;
}

// --- The caller's session ----------------------------------------------------------------

export type Session = { userId: string; sessionId: string };

/**
 * The verified user id and the JWT's `session_id` claim. `verifyUser` checks the
 * token with Auth (signature, expiry, user still there); only then is the
 * payload read for the session id, which must belong to the same user.
 */
export async function sessionFromRequest(
  req: Request,
  verifyUser: (token: string) => Promise<string | null>,
): Promise<Session> {
  const header = req.headers.get("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (!token) throw new HttpError(401, "unauthorized", "Missing bearer token");
  const userId = await verifyUser(token);
  if (!userId) throw new HttpError(401, "unauthorized", "Invalid or expired session");

  let claims: unknown;
  try {
    const payload = token.split(".")[1] ?? "";
    const b64 = payload.replaceAll("-", "+").replaceAll("_", "/");
    claims = JSON.parse(new TextDecoder().decode(base64ToBytes(b64 + "=".repeat((4 - b64.length % 4) % 4))));
  } catch {
    throw new HttpError(401, "unauthorized", "Invalid session");
  }
  if (!isRecord(claims) || claims.sub !== userId || !isUuid(claims.session_id)) {
    throw new HttpError(401, "unauthorized", "Invalid session");
  }
  return { userId, sessionId: claims.session_id };
}

// --- Database (service role) -------------------------------------------------------------

export type ChallengePurpose = "bind" | "approve" | "recover";

export type ChallengeKeys = {
  device: { id: string; kx: Uint8Array; sig: Uint8Array };
  signer: { id: string; sig: Uint8Array };
};

export type AppendArgs = {
  session: Session;
  familyId: string;
  seq: number;
  prevHash: Uint8Array | null;
  entry: Uint8Array;
  sig: Uint8Array;
  history: Uint8Array | null;
  wraps: unknown[] | null;
};

export interface SyncStore {
  /** Uses up a nonce issued to this session for this purpose and device. */
  takeChallenge(
    session: Session,
    purpose: ChallengePurpose,
    deviceId: string,
    nonce: Uint8Array,
  ): Promise<ChallengeKeys>;
  bindDevice(session: Session, deviceId: string, enroll: boolean): Promise<Record<string, unknown>>;
  approveDevice(
    session: Session,
    deviceId: string,
    pairingId: string | null,
    bundle: Uint8Array | null,
  ): Promise<Record<string, unknown>>;
  recoverDevice(session: Session, deviceId: string): Promise<Record<string, unknown>>;
  /** Ed25519 key of any device, or null if there is no such device. */
  deviceSigningKey(deviceId: string): Promise<Uint8Array | null>;
  appendFamilyLog(args: AppendArgs): Promise<Record<string, unknown>>;
  /** The approved phone bound to this session and its signing key, or null. */
  sessionDevice(session: Session): Promise<{ deviceId: string; sig: Uint8Array } | null>;
  publishHead(
    session: Session,
    familyId: string,
    beacon: Uint8Array,
    sig: Uint8Array,
  ): Promise<Record<string, unknown>>;
}

/** A Postgres error raised by the sync functions, as `{ code: sqlstate, message }`. */
export type DbError = { code?: string; message?: string };

const STATUS_BY_SQLSTATE: Record<string, number> = {
  "42501": 403, // forbidden, approved_device_required, bad_challenge, ...
  "P0002": 404, // unknown_device, unknown_family, pairing_unavailable, ...
  "22023": 400, // bad_entry, entry_mismatch, ...
  "22P02": 400, // a malformed uuid or number inside JSON
  "23502": 400,
  "23514": 400, // a check constraint (sizes, key lengths)
  "23505": 409, // already_member, already_in_family, a concurrent append
  "54000": 429, // rate limits
};

/**
 * Turns a database error into an HTTP error. Only the function's own error
 * names (snake_case words) reach the client; anything else is a 500.
 */
export function dbErrorToHttp(error: DbError, fn: string): HttpError {
  const status = error.code ? STATUS_BY_SQLSTATE[error.code] : undefined;
  if (status === undefined) {
    console.error("sync_db_error", fn, error.code ?? "unknown");
    return new HttpError(500, "internal_error", "Something went wrong");
  }
  const named = /^[a-z_]{3,40}$/.test(error.message ?? "") ? error.message! : "rejected";
  return new HttpError(status, named);
}

/** bytea parameter for PostgREST: "\x" + hex. */
export function byteaParam(bytes: Uint8Array | null): string | null {
  if (bytes === null) return null;
  return "\\x" + Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

export function base64Field(value: unknown, what: string): Uint8Array {
  if (typeof value !== "string") throw new Error(`${what} missing`);
  return base64ToBytes(value);
}
