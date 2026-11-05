// Handlers of the sync Edge Functions. Each checks a strict Ed25519 signature
// over a server nonce or a signed log object, then calls one service-role
// database function that re-checks who the caller is (docs/sync-design.md,
// sections 7–8). None logs bodies, keys, signatures or ids.

import { type Handler, HttpError, json, readJson } from "./http.ts";
import { verifyStrict } from "./ed25519.ts";
import { isJsonObject, type JsonValue, parseStrictJson, StrictJsonError } from "./strict_json.ts";
import {
  approveDeviceMessage,
  bindSessionMessage,
  decodeBase64Field,
  headMessage,
  isUuid,
  logEntryMessage,
  requireBody,
  requireUuidField,
  type Session,
  type SyncStore,
} from "./sync.ts";

export type SyncDeps = {
  /** The caller's verified user id and Auth session id. */
  getSession: (req: Request) => Promise<Session>;
  store: SyncStore;
};

function badSignature(): HttpError {
  return new HttpError(403, "bad_signature", "The signature does not verify");
}

/**
 * bind-device: binds this Auth session to a phone that proves its key, the
 * phone's own after sign-in or, after a lost session, the existing device row
 * (re-registration). `enroll: true` also self-approves the account's very
 * first device. POST { device_id, nonce, signature, enroll? }.
 */
export function createBindDeviceHandler(deps: SyncDeps): Handler {
  return async (req) => {
    const session = await deps.getSession(req);
    const body = requireBody(await readJson(req, 2048));
    const deviceId = requireUuidField(body, "device_id");
    const nonce = decodeBase64Field(body, "nonce", { bytes: 32 })!;
    const signature = decodeBase64Field(body, "signature", { bytes: 64 })!;
    if (body.enroll !== undefined && typeof body.enroll !== "boolean") {
      throw new HttpError(400, "invalid_request", "enroll must be a boolean");
    }
    const keys = await deps.store.takeChallenge(session, "bind", deviceId, nonce);
    if (!await verifyStrict(keys.signer.sig, bindSessionMessage(session.sessionId, nonce), signature)) {
      throw badSignature();
    }
    return json(await deps.store.bindDevice(session, deviceId, body.enroll === true));
  };
}

/**
 * approve-device: an approved phone (this session) approves a pending phone of
 * the same account after scanning its QR code (way 1) or comparing codes (way 2,
 * with `pairing_id`), and leaves the HPKE pairing bundle for it.
 * POST { device_id, nonce, signature, pairing_id?, bundle? }.
 */
export function createApproveDeviceHandler(deps: SyncDeps): Handler {
  return async (req) => {
    const session = await deps.getSession(req);
    const body = requireBody(await readJson(req, 96 * 1024));
    const deviceId = requireUuidField(body, "device_id");
    const nonce = decodeBase64Field(body, "nonce", { bytes: 32 })!;
    const signature = decodeBase64Field(body, "signature", { bytes: 64 })!;
    const pairingId = body.pairing_id === undefined || body.pairing_id === null
      ? null
      : requireUuidField(body, "pairing_id");
    const bundle = decodeBase64Field(body, "bundle", { optional: true, maxBytes: 65536 });
    if (bundle !== null && bundle.length === 0) throw new HttpError(400, "invalid_request", "bundle is empty");

    const keys = await deps.store.takeChallenge(session, "approve", deviceId, nonce);
    const message = approveDeviceMessage(session.userId, deviceId, keys.device.kx, keys.device.sig, nonce);
    if (!await verifyStrict(keys.signer.sig, message, signature)) throw badSignature();
    return json(await deps.store.approveDevice(session, deviceId, pairingId, bundle, keys.signer.id));
  };
}

/**
 * recover-device: a pending phone proves the recovery device's key (derived from
 * the recovery key) by signing the approve-device message for itself (way 3).
 * POST { device_id, nonce, signature }.
 */
export function createRecoverDeviceHandler(deps: SyncDeps): Handler {
  return async (req) => {
    const session = await deps.getSession(req);
    const body = requireBody(await readJson(req, 2048));
    const deviceId = requireUuidField(body, "device_id");
    const nonce = decodeBase64Field(body, "nonce", { bytes: 32 })!;
    const signature = decodeBase64Field(body, "signature", { bytes: 64 })!;

    const keys = await deps.store.takeChallenge(session, "recover", deviceId, nonce);
    const message = approveDeviceMessage(session.userId, deviceId, keys.device.kx, keys.device.sig, nonce);
    if (!await verifyStrict(keys.signer.sig, message, signature)) throw badSignature();
    return json(await deps.store.recoverDevice(session, deviceId));
  };
}

// The top-level keys of each log entry type (section 7). Unknown keys are refused.
const COMMON_KEYS = ["at", "by", "family", "prev", "seq", "type", "v"];
const ENTRY_KEYS: Record<string, string[]> = {
  genesis: ["devices", "kc", "key_version", "user"],
  add_member: ["devices", "invite", "mac", "role", "user"],
  change_role: ["role", "user"],
  transfer_owner: ["user"],
  remove_member: ["reason", "user"],
  add_device: ["device", "user"],
  revoke_device: ["device", "user"],
  rotate_key: ["history", "kc", "key_version", "recipients"],
};

/** The entry's type if its top-level keys are exactly those of the type, else null. */
export function entryType(entry: { [key: string]: JsonValue }): string | null {
  const type = entry.type;
  if (typeof type !== "string" || !Object.hasOwn(ENTRY_KEYS, type)) return null;
  const expected = [...COMMON_KEYS, ...ENTRY_KEYS[type]];
  if ((type === "add_member" || type === "change_role") && entry.role === "cared_for") expected.push("profile");
  const keys = Object.keys(entry).sort();
  expected.sort();
  return keys.length === expected.length && keys.every((k, i) => k === expected[i]) ? type : null;
}

function parseSigned(bytes: Uint8Array, maxBytes: number): { [key: string]: JsonValue } {
  try {
    const value = parseStrictJson(bytes, { maxBytes, maxDepth: 8 });
    if (isJsonObject(value)) return value;
  } catch (err) {
    if (!(err instanceof StrictJsonError)) throw err;
    throw new HttpError(400, "bad_entry", `Not strict JSON: ${err.reason}`);
  }
  throw new HttpError(400, "bad_entry", "Not a JSON object");
}

/**
 * append-family-log: appends one signed entry on top of the family log head
 * (compare-and-set). rotate_key also carries the history blob and every wrap of
 * the new epoch. POST { family_id, seq, prev_hash, entry, signature, history?,
 * wraps? }. A stale head answers 409 with the server's head.
 */
export function createAppendFamilyLogHandler(deps: SyncDeps): Handler {
  return async (req) => {
    const session = await deps.getSession(req);
    const body = requireBody(await readJson(req, 512 * 1024));
    const familyId = requireUuidField(body, "family_id");
    const seq = body.seq;
    if (typeof seq !== "number" || !Number.isSafeInteger(seq) || seq < 1 || seq > 2 ** 31 - 1) {
      throw new HttpError(400, "invalid_request", "seq must be a positive integer");
    }
    const prevHash = decodeBase64Field(body, "prev_hash", { bytes: 32, optional: true });
    if ((seq === 1) !== (prevHash === null)) {
      throw new HttpError(400, "invalid_request", "prev_hash is null exactly for seq 1");
    }
    const entryBytes = decodeBase64Field(body, "entry", { maxBytes: 16384 })!;
    const signature = decodeBase64Field(body, "signature", { bytes: 64 })!;
    const history = decodeBase64Field(body, "history", { bytes: 72, optional: true });
    const wraps = body.wraps === undefined || body.wraps === null ? null : body.wraps;
    if (wraps !== null && (!Array.isArray(wraps) || wraps.length === 0 || wraps.length > 1000)) {
      throw new HttpError(400, "invalid_request", "wraps must be a non-empty array");
    }

    const entry = parseSigned(entryBytes, 16384);
    const type = entryType(entry);
    if (type === null) throw new HttpError(400, "bad_entry_fields", "Unknown entry type or fields");
    if (entry.family !== familyId || entry.seq !== seq || !isUuid(entry.by)) {
      throw new HttpError(400, "entry_mismatch", "The entry does not match the request");
    }
    if (type === "rotate_key" ? history === null || wraps === null : history !== null || wraps !== null) {
      throw new HttpError(400, "bad_rotation", "rotate_key needs history and wraps, other entries neither");
    }

    const key = await deps.store.deviceSigningKey(entry.by);
    if (key === null) throw new HttpError(403, "unknown_signer", "The signing device is unknown");
    if (!await verifyStrict(key, logEntryMessage(entryBytes), signature)) throw badSignature();

    const result = await deps.store.appendFamilyLog({
      session,
      familyId,
      seq,
      prevHash,
      entry: entryBytes,
      sig: signature,
      history,
      wraps: wraps as unknown[] | null,
    });
    return json(result, result.ok === false ? 409 : 200);
  };
}

const BEACON_KEYS = ["at", "device", "family", "h", "seq", "v"];

/**
 * publish-head: stores this phone's signed head beacon for a family (newest
 * only). POST { family_id, beacon, signature }.
 */
export function createPublishHeadHandler(deps: SyncDeps): Handler {
  return async (req) => {
    const session = await deps.getSession(req);
    const body = requireBody(await readJson(req, 4096));
    const familyId = requireUuidField(body, "family_id");
    const beaconBytes = decodeBase64Field(body, "beacon", { maxBytes: 1024 })!;
    const signature = decodeBase64Field(body, "signature", { bytes: 64 })!;

    const beacon = parseSigned(beaconBytes, 1024);
    const keys = Object.keys(beacon).sort();
    if (keys.length !== BEACON_KEYS.length || keys.some((k, i) => k !== BEACON_KEYS[i])) {
      throw new HttpError(400, "bad_beacon", "Unexpected beacon fields");
    }
    const device = await deps.store.sessionDevice(session);
    if (device === null) throw new HttpError(403, "approved_device_required");
    if (beacon.family !== familyId || beacon.device !== device.deviceId) {
      throw new HttpError(400, "bad_beacon", "The beacon is for another family or device");
    }
    if (!await verifyStrict(device.sig, headMessage(beaconBytes), signature)) throw badSignature();

    const result = await deps.store.publishHead(session, familyId, beaconBytes, signature);
    return json(result, result.ok === false ? 409 : 200);
  };
}
