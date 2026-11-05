// The sync Edge Functions with a fake store and real Ed25519 keys: the exact
// bytes each signature covers, strict parsing, and what reaches the database.

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import { bytesToBase64 } from "../../functions/_shared/crypto.ts";
import { type Handler, HttpError, withHttp } from "../../functions/_shared/http.ts";
import {
  approveDeviceMessage,
  bindSessionMessage,
  byteaParam,
  type ChallengePurpose,
  dbErrorToHttp,
  headMessage,
  label,
  logEntryMessage,
  type Session,
  sessionFromRequest,
  type SyncStore,
  uuidBytes,
} from "../../functions/_shared/sync.ts";
import {
  createAppendFamilyLogHandler,
  createApproveDeviceHandler,
  createBindDeviceHandler,
  createPublishHeadHandler,
  createRecoverDeviceHandler,
  entryType,
} from "../../functions/_shared/sync_handlers.ts";

const USER = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const SESSION = "5a000000-0000-4000-8000-0000000000a1";
const PHONE = "da000000-0000-4000-8000-0000000000a1";
const NEW_PHONE = "da000000-0000-4000-8000-0000000000a2";
const RECOVERY = "da000000-0000-4000-8000-0000000000ff";
const FAMILY = "f0000000-0000-4000-8000-00000000000f";

type KeyPair = { pub: Uint8Array; sign: (msg: Uint8Array) => Promise<Uint8Array> };

async function keyPair(): Promise<KeyPair> {
  const k = await crypto.subtle.generateKey({ name: "Ed25519" }, true, ["sign", "verify"]) as CryptoKeyPair;
  return {
    pub: new Uint8Array(await crypto.subtle.exportKey("raw", k.publicKey)),
    sign: async (msg) =>
      new Uint8Array(await crypto.subtle.sign({ name: "Ed25519" }, k.privateKey, new Uint8Array(msg))),
  };
}

const b64 = (b: Uint8Array) => bytesToBase64(b);
const b64url = (b: Uint8Array) => b64(b).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const utf8 = (s: string) => new TextEncoder().encode(s);
const nonce = Uint8Array.from({ length: 32 }, (_, i) => i + 1);

class FakeStore implements SyncStore {
  calls: { fn: string; args: unknown[] }[] = [];
  taken: { purpose: ChallengePurpose; deviceId: string }[] = [];
  appendResult: Record<string, unknown> = { ok: true, seq: 1 };
  boundDevice: { deviceId: string; sig: Uint8Array } | null;

  constructor(
    readonly keys: { phone: KeyPair; newPhone: KeyPair; recovery: KeyPair; newPhoneKx: Uint8Array },
    opts: { badChallenge?: boolean; noBoundDevice?: boolean } = {},
  ) {
    this.badChallenge = opts.badChallenge ?? false;
    this.boundDevice = opts.noBoundDevice ? null : { deviceId: PHONE, sig: keys.phone.pub };
  }
  private badChallenge: boolean;

  takeChallenge(_s: Session, purpose: ChallengePurpose, deviceId: string, n: Uint8Array) {
    if (this.badChallenge || n.some((b, i) => b !== nonce[i])) {
      return Promise.reject(new HttpError(403, "bad_challenge"));
    }
    this.taken.push({ purpose, deviceId });
    const device = deviceId === PHONE
      ? { id: PHONE, kx: new Uint8Array(32).fill(9), sig: this.keys.phone.pub }
      : { id: NEW_PHONE, kx: this.keys.newPhoneKx, sig: this.keys.newPhone.pub };
    const signer = purpose === "bind"
      ? { id: device.id, sig: device.sig }
      : purpose === "approve"
      ? { id: PHONE, sig: this.keys.phone.pub }
      : { id: RECOVERY, sig: this.keys.recovery.pub };
    return Promise.resolve({ device, signer });
  }
  bindDevice(_s: Session, deviceId: string, enroll: boolean) {
    this.calls.push({ fn: "bind", args: [deviceId, enroll] });
    return Promise.resolve({ device_id: deviceId, status: "approved" });
  }
  approveDevice(_s: Session, deviceId: string, pairingId: string | null, bundle: Uint8Array | null, signerId: string) {
    this.calls.push({ fn: "approve", args: [deviceId, pairingId, bundle?.length ?? null, signerId] });
    return Promise.resolve({ device_id: deviceId, status: "approved" });
  }
  recoverDevice(_s: Session, deviceId: string) {
    this.calls.push({ fn: "recover", args: [deviceId] });
    return Promise.resolve({ device_id: deviceId, status: "approved" });
  }
  deviceSigningKey(deviceId: string) {
    return Promise.resolve(
      deviceId === PHONE ? this.keys.phone.pub : deviceId === RECOVERY ? this.keys.recovery.pub : null,
    );
  }
  appendFamilyLog(args: Parameters<SyncStore["appendFamilyLog"]>[0]) {
    this.calls.push({ fn: "append", args: [args.familyId, args.seq, args.history?.length ?? null, args.wraps] });
    return Promise.resolve(this.appendResult);
  }
  sessionDevice() {
    return Promise.resolve(this.boundDevice);
  }
  publishHead(_s: Session, familyId: string, beacon: Uint8Array) {
    this.calls.push({ fn: "head", args: [familyId, beacon.length] });
    return Promise.resolve({ ok: true });
  }
}

async function setup(opts: { badChallenge?: boolean; noBoundDevice?: boolean } = {}) {
  const keys = {
    phone: await keyPair(),
    newPhone: await keyPair(),
    recovery: await keyPair(),
    newPhoneKx: new Uint8Array(32).fill(7),
  };
  const store = new FakeStore(keys, opts);
  const deps = { getSession: () => Promise.resolve({ userId: USER, sessionId: SESSION }), store };
  const post = (handler: Handler, body: unknown) =>
    withHttp(handler)(
      new Request("http://local/fn", {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: "Bearer t" },
        body: JSON.stringify(body),
      }),
    );
  return { keys, store, deps, post };
}

async function expectError(res: Response, status: number, code: string) {
  assertEquals(res.status, status);
  assertEquals((await res.json()).error.code, code);
}

// --- Signed message layouts -------------------------------------------------------

Deno.test("sync: labels end with a 0x00 byte and messages have fixed layouts", () => {
  assertEquals(label("usra/v1/head"), Uint8Array.from([...utf8("usra/v1/head"), 0]));
  assertEquals(Array.from(uuidBytes(USER), (b) => b.toString(16)).join(""), "aaaaaaaaaaaa4aaa8aaaaaaaaaaaaaaa");

  const bind = bindSessionMessage(SESSION, nonce);
  assertEquals(bind.length, "usra/v1/bind-session".length + 1 + 16 + 32);
  assertEquals(bind.subarray(21, 37), uuidBytes(SESSION));

  const kx = new Uint8Array(32).fill(1), sig = new Uint8Array(32).fill(2);
  const approve = approveDeviceMessage(USER, NEW_PHONE, kx, sig, nonce);
  assertEquals(approve.length, "usra/v1/approve-device".length + 1 + 16 + 16 + 32 + 32 + 32);
  assertEquals(approve.subarray(approve.length - 32), nonce);

  assertEquals(logEntryMessage(utf8("{}")), Uint8Array.from([...utf8("usra/v1/log-entry"), 0, ...utf8("{}")]));
  assertEquals(headMessage(utf8("{}")).length, "usra/v1/head".length + 1 + 2);
  assertEquals(byteaParam(Uint8Array.from([0, 255])), "\\x00ff");
});

// --- Sessions ------------------------------------------------------------------------------

function jwt(claims: Record<string, unknown>): string {
  return `e30.${b64url(utf8(JSON.stringify(claims)))}.sig`;
}

Deno.test("sync: the session id comes from a verified token of the same user", async () => {
  const req = (token: string) => new Request("http://local", { headers: { Authorization: `Bearer ${token}` } });
  const ok = await sessionFromRequest(req(jwt({ sub: USER, session_id: SESSION })), () => Promise.resolve(USER));
  assertEquals(ok, { userId: USER, sessionId: SESSION });

  for (
    const [token, verified] of [
      [jwt({ sub: USER, session_id: SESSION }), null], // Auth refused the token
      [jwt({ sub: "someone-else", session_id: SESSION }), USER], // another user's claims
      [jwt({ sub: USER }), USER], // no session id
      [jwt({ sub: USER, session_id: "NOT-A-UUID" }), USER],
      ["garbage", USER],
    ] as const
  ) {
    const err = await assertRejects(() => sessionFromRequest(req(token), () => Promise.resolve(verified)), HttpError);
    assertEquals(err.status, 401);
  }
  const missing = await assertRejects(
    () => sessionFromRequest(new Request("http://local"), () => Promise.resolve(USER)),
    HttpError,
  );
  assertEquals(missing.status, 401);
});

Deno.test("sync: database errors map to their own names only", () => {
  const forbidden = dbErrorToHttp({ code: "42501", message: "approved_device_required" }, "fn");
  assertEquals([forbidden.status, forbidden.code], [403, "approved_device_required"]);
  assertEquals(dbErrorToHttp({ code: "54000", message: "too_many_recovery_tries" }, "fn").status, 429);
  const leaky = dbErrorToHttp({ code: "22023", message: "invalid input: secret stuff" }, "fn");
  assertEquals([leaky.status, leaky.code], [400, "rejected"]);
  const unknown = dbErrorToHttp({ code: "XX000", message: "boom" }, "fn");
  assertEquals([unknown.status, unknown.code], [500, "internal_error"]);
});

// --- bind-device ---------------------------------------------------------------------------

Deno.test("bind-device: binds the session when the device signs this session and nonce", async () => {
  const { keys, store, deps, post } = await setup();
  const signature = await keys.phone.sign(bindSessionMessage(SESSION, nonce));
  const res = await post(createBindDeviceHandler(deps), {
    device_id: PHONE,
    nonce: b64(nonce),
    signature: b64(signature),
    enroll: true,
  });
  assertEquals(res.status, 200);
  assertEquals(store.taken, [{ purpose: "bind", deviceId: PHONE }]);
  assertEquals(store.calls, [{ fn: "bind", args: [PHONE, true] }]);
});

Deno.test("bind-device: a signature over another session, or by another key, is refused", async () => {
  const { keys, store, deps, post } = await setup();
  const otherSession = await keys.phone.sign(bindSessionMessage("5a000000-0000-4000-8000-0000000000a9", nonce));
  const otherKey = await keys.newPhone.sign(bindSessionMessage(SESSION, nonce));
  for (const signature of [otherSession, otherKey]) {
    const res = await post(createBindDeviceHandler(deps), {
      device_id: PHONE,
      nonce: b64(nonce),
      signature: b64(signature),
    });
    await expectError(res, 403, "bad_signature");
  }
  assertEquals(store.calls, []);
});

Deno.test("bind-device: a used or foreign nonce is refused before any signature check", async () => {
  const { keys, store, deps, post } = await setup({ badChallenge: true });
  const res = await post(createBindDeviceHandler(deps), {
    device_id: PHONE,
    nonce: b64(nonce),
    signature: b64(await keys.phone.sign(bindSessionMessage(SESSION, nonce))),
  });
  await expectError(res, 403, "bad_challenge");
  assertEquals(store.calls, []);
});

Deno.test("bind-device: malformed requests", async () => {
  const { deps, post } = await setup();
  const handler = createBindDeviceHandler(deps);
  const good = { device_id: PHONE, nonce: b64(nonce), signature: b64(new Uint8Array(64)) };
  for (
    const body of [
      { ...good, device_id: PHONE.toUpperCase() },
      { ...good, nonce: b64(nonce.subarray(1)) },
      { ...good, signature: "not base64!" },
      { ...good, enroll: "yes" },
      [good],
    ]
  ) {
    await expectError(await post(handler, body), 400, "invalid_request");
  }
});

// --- approve-device and recover-device -----------------------------------------------------

Deno.test("approve-device: the approving phone signs the new phone's keys and the nonce", async () => {
  const { keys, store, deps, post } = await setup();
  const message = approveDeviceMessage(USER, NEW_PHONE, keys.newPhoneKx, keys.newPhone.pub, nonce);
  const res = await post(createApproveDeviceHandler(deps), {
    device_id: NEW_PHONE,
    nonce: b64(nonce),
    signature: b64(await keys.phone.sign(message)),
    pairing_id: "9a000000-0000-4000-8000-000000000001",
    bundle: b64(new Uint8Array(500)),
  });
  assertEquals(res.status, 200);
  assertEquals(store.calls, [{ fn: "approve", args: [NEW_PHONE, "9a000000-0000-4000-8000-000000000001", 500, PHONE] }]);
});

Deno.test("approve-device: the new phone cannot approve itself, nor a swapped key", async () => {
  const { keys, store, deps, post } = await setup();
  const message = approveDeviceMessage(USER, NEW_PHONE, keys.newPhoneKx, keys.newPhone.pub, nonce);
  const swapped = approveDeviceMessage(USER, NEW_PHONE, new Uint8Array(32), keys.newPhone.pub, nonce);
  for (const signature of [await keys.newPhone.sign(message), await keys.phone.sign(swapped)]) {
    const res = await post(createApproveDeviceHandler(deps), {
      device_id: NEW_PHONE,
      nonce: b64(nonce),
      signature: b64(signature),
    });
    await expectError(res, 403, "bad_signature");
  }
  const big = await post(createApproveDeviceHandler(deps), {
    device_id: NEW_PHONE,
    nonce: b64(nonce),
    signature: b64(await keys.phone.sign(message)),
    bundle: b64(new Uint8Array(65537)),
  });
  await expectError(big, 400, "invalid_request");
  assertEquals(store.calls, []);
});

Deno.test("recover-device: only the recovery device's key approves", async () => {
  const { keys, store, deps, post } = await setup();
  const message = approveDeviceMessage(USER, NEW_PHONE, keys.newPhoneKx, keys.newPhone.pub, nonce);
  const own = await post(createRecoverDeviceHandler(deps), {
    device_id: NEW_PHONE,
    nonce: b64(nonce),
    signature: b64(await keys.newPhone.sign(message)),
  });
  await expectError(own, 403, "bad_signature");
  const res = await post(createRecoverDeviceHandler(deps), {
    device_id: NEW_PHONE,
    nonce: b64(nonce),
    signature: b64(await keys.recovery.sign(message)),
  });
  assertEquals(res.status, 200);
  assertEquals(store.taken.map((t) => t.purpose), ["recover", "recover"]);
  assertEquals(store.calls, [{ fn: "recover", args: [NEW_PHONE] }]);
});

// --- append-family-log -------------------------------------------------------------------------

function genesis(extra: Record<string, unknown> = {}) {
  return {
    v: 1,
    family: FAMILY,
    seq: 1,
    prev: null,
    type: "genesis",
    by: PHONE,
    at: "019300f8a1b20003",
    user: USER,
    devices: [],
    key_version: 1,
    kc: b64url(new Uint8Array(32)),
    ...extra,
  };
}

async function appendBody(signer: KeyPair, entryText: string, extra: Record<string, unknown> = {}) {
  const entry = utf8(entryText);
  return {
    family_id: FAMILY,
    seq: 1,
    prev_hash: null,
    entry: b64(entry),
    signature: b64(await signer.sign(logEntryMessage(entry))),
    ...extra,
  };
}

Deno.test("append-family-log: a signed genesis goes to the database", async () => {
  const { keys, store, deps, post } = await setup();
  const res = await post(createAppendFamilyLogHandler(deps), await appendBody(keys.phone, JSON.stringify(genesis())));
  assertEquals(res.status, 200);
  assertEquals(store.calls, [{ fn: "append", args: [FAMILY, 1, null, null] }]);
});

Deno.test("append-family-log: entries signed by the recovery device verify with its key", async () => {
  const { keys, store, deps, post } = await setup();
  const entry = JSON.stringify(genesis({ by: RECOVERY }));
  const res = await post(createAppendFamilyLogHandler(deps), await appendBody(keys.recovery, entry));
  assertEquals(res.status, 200);
  assertEquals(store.calls.length, 1);
});

Deno.test("append-family-log: the signature covers the exact bytes", async () => {
  const { keys, store, deps, post } = await setup();
  const body = await appendBody(keys.phone, JSON.stringify(genesis()));
  // Same JSON value, different bytes (a space): the signature no longer matches.
  body.entry = b64(utf8(JSON.stringify(genesis()).replace(":1,", ": 1,")));
  await expectError(await post(createAppendFamilyLogHandler(deps), body), 403, "bad_signature");
  // Signed by another device than "by".
  const other = await appendBody(keys.newPhone, JSON.stringify(genesis()));
  await expectError(await post(createAppendFamilyLogHandler(deps), other), 403, "bad_signature");
  assertEquals(store.calls, []);
});

Deno.test("append-family-log: strict JSON and exact fields before any signature check", async () => {
  const { keys, store, deps, post } = await setup();
  const handler = createAppendFamilyLogHandler(deps);
  const text = JSON.stringify(genesis());
  const cases: [string, number, string][] = [
    [text.replace('"type":"genesis"', '"type":"genesis","type":"genesis"'), 400, "bad_entry"],
    [JSON.stringify(genesis({ extra: 1 })), 400, "bad_entry_fields"],
    [JSON.stringify(genesis({ type: "make_owner" })), 400, "bad_entry_fields"],
    [JSON.stringify(genesis({ seq: 2 })), 400, "entry_mismatch"],
    [JSON.stringify(genesis({ family: "f0000000-0000-4000-8000-0000000000ff" })), 400, "entry_mismatch"],
    [JSON.stringify(genesis({ by: "unknown" })), 400, "entry_mismatch"],
    [JSON.stringify(genesis({ by: NEW_PHONE })), 403, "unknown_signer"],
    [JSON.stringify(genesis({ key_version: 1.5 })), 400, "bad_entry"],
  ];
  for (const [entry, status, code] of cases) {
    await expectError(await post(handler, await appendBody(keys.phone, entry)), status, code);
  }
  assertEquals(store.calls, []);
});

Deno.test("append-family-log: a cared-for member carries a profile, nobody else", () => {
  const base = {
    v: 1,
    family: FAMILY,
    seq: 2,
    prev: "x",
    type: "add_member",
    by: PHONE,
    at: "0",
    user: USER,
    devices: [],
    invite: "i",
    mac: "m",
  };
  assertEquals(entryType({ ...base, role: "cared_for", profile: "p" }), "add_member");
  assertEquals(entryType({ ...base, role: "viewer", profile: "p" }), null);
  assertEquals(entryType({ ...base, role: "cared_for" }), null);
  assertEquals(entryType({ ...base, role: "viewer" }), "add_member");
});

Deno.test("append-family-log: rotate_key ships history and wraps, other entries neither", async () => {
  const { keys, store, deps, post } = await setup();
  const handler = createAppendFamilyLogHandler(deps);
  const rotate = JSON.stringify({
    v: 1,
    family: FAMILY,
    seq: 2,
    prev: b64url(new Uint8Array(32)),
    type: "rotate_key",
    by: PHONE,
    at: "019300f8a1b20003",
    key_version: 2,
    kc: "k",
    history: "h",
    recipients: "r",
  });
  const wraps = [{ recipient: PHONE, enc: "", ct: "", sig: "" }];
  const prev = { seq: 2, prev_hash: b64(new Uint8Array(32)) };
  await expectError(await post(handler, await appendBody(keys.phone, rotate, prev)), 400, "bad_rotation");
  await expectError(
    await post(
      handler,
      await appendBody(keys.phone, JSON.stringify(genesis()), { history: b64(new Uint8Array(72)), wraps }),
    ),
    400,
    "bad_rotation",
  );
  await expectError(
    await post(
      handler,
      await appendBody(keys.phone, JSON.stringify(genesis()), { wraps }),
    ),
    400,
    "bad_rotation",
  );
  const ok = await post(
    handler,
    await appendBody(keys.phone, rotate, { ...prev, history: b64(new Uint8Array(72)), wraps }),
  );
  assertEquals(ok.status, 200);
  assertEquals(store.calls, [{ fn: "append", args: [FAMILY, 2, 72, wraps] }]);
});

Deno.test("append-family-log: prev_hash is null exactly for seq 1, and a stale head is 409", async () => {
  const { keys, store, deps, post } = await setup();
  const handler = createAppendFamilyLogHandler(deps);
  const text = JSON.stringify(genesis());
  await expectError(
    await post(handler, await appendBody(keys.phone, text, { prev_hash: b64(new Uint8Array(32)) })),
    400,
    "invalid_request",
  );
  store.appendResult = { ok: false, error: "head_mismatch", head_seq: 4, head_hash: "abc" };
  const res = await post(handler, await appendBody(keys.phone, text));
  assertEquals(res.status, 409);
  assertEquals((await res.json()).head_seq, 4);
});

// --- publish-head ----------------------------------------------------------------------------------

function beacon(extra: Record<string, unknown> = {}) {
  return JSON.stringify({
    v: 1,
    family: FAMILY,
    device: PHONE,
    seq: 3,
    h: b64url(new Uint8Array(32)),
    at: "019300f8a1b20003",
    ...extra,
  });
}

async function headBody(signer: KeyPair, text: string) {
  const bytes = utf8(text);
  return { family_id: FAMILY, beacon: b64(bytes), signature: b64(await signer.sign(headMessage(bytes))) };
}

Deno.test("publish-head: the session's phone publishes its signed beacon", async () => {
  const { keys, store, deps, post } = await setup();
  const res = await post(createPublishHeadHandler(deps), await headBody(keys.phone, beacon()));
  assertEquals(res.status, 200);
  assertEquals(store.calls, [{ fn: "head", args: [FAMILY, utf8(beacon()).length] }]);
});

Deno.test("publish-head: another device's beacon, extra fields or a bad signature are refused", async () => {
  const { keys, store, deps, post } = await setup();
  const handler = createPublishHeadHandler(deps);
  await expectError(await post(handler, await headBody(keys.phone, beacon({ device: NEW_PHONE }))), 400, "bad_beacon");
  await expectError(await post(handler, await headBody(keys.phone, beacon({ x: 1 }))), 400, "bad_beacon");
  await expectError(await post(handler, await headBody(keys.newPhone, beacon())), 403, "bad_signature");
  assertEquals(store.calls, []);
});

Deno.test("publish-head: an SMS-only session has no device to publish for", async () => {
  const { keys, store, deps, post } = await setup({ noBoundDevice: true });
  await expectError(
    await post(createPublishHeadHandler(deps), await headBody(keys.phone, beacon())),
    403,
    "approved_device_required",
  );
  assert(store.calls.length === 0);
});
