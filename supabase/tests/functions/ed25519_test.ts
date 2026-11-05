// Strict Ed25519 (docs/sync-design.md, sections 5 and 16): known-answer tests
// from RFC 8032, Wycheproof and "Taming the many EdDSAs". The Dart verifier on
// the phones and the Python cross-check tool must give the same answer for
// every vector.

import { assert, assertEquals } from "jsr:@std/assert@1";
import { isCanonicalScalar, isStrictPoint, verifyStrict } from "../../functions/_shared/ed25519.ts";
import rfc8032 from "./vectors/rfc8032_ed25519.json" with { type: "json" };
import wycheproof from "./vectors/wycheproof_ed25519.json" with { type: "json" };
import speccheck from "./vectors/speccheck_ed25519.json" with { type: "json" };

const hex = (s: string) => Uint8Array.from(s.match(/../g) ?? [], (x) => parseInt(x, 16));

async function webcryptoOnly(pk: Uint8Array, msg: Uint8Array, sig: Uint8Array): Promise<boolean> {
  try {
    const key = await crypto.subtle.importKey("raw", new Uint8Array(pk), { name: "Ed25519" }, false, ["verify"]);
    return await crypto.subtle.verify({ name: "Ed25519" }, key, new Uint8Array(sig), new Uint8Array(msg));
  } catch {
    return false;
  }
}

Deno.test("ed25519: RFC 8032 section 7.1 vectors verify, and signing reproduces them", async () => {
  for (const t of rfc8032.tests) {
    const pub = hex(t.public), msg = hex(t.message), sig = hex(t.signature);
    assert(await verifyStrict(pub, msg, sig), `TEST ${t.name}`);

    const b64url = (b: Uint8Array) =>
      btoa(String.fromCharCode(...b)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
    const key = await crypto.subtle.importKey(
      "jwk",
      { kty: "OKP", crv: "Ed25519", d: b64url(hex(t.secret)), x: b64url(pub) },
      { name: "Ed25519" },
      false,
      ["sign"],
    );
    assertEquals(new Uint8Array(await crypto.subtle.sign({ name: "Ed25519" }, key, msg)), sig, `TEST ${t.name} sign`);

    // Any flipped bit in the key, message or signature fails.
    const bad = sig.slice();
    bad[10] ^= 1;
    assert(!await verifyStrict(pub, msg, bad), `TEST ${t.name} flipped signature`);
    assert(!await verifyStrict(pub, Uint8Array.from([...msg, 0]), sig), `TEST ${t.name} longer message`);
  }
});

// Wycheproof marks two groups "acceptable" (either answer is allowed). Our
// policy pins them: small-order public keys are rejected; mixed-order keys go
// by the cofactorless equation, which accepts these 21 signatures.
const ACCEPTED_MIXED_ORDER = Array.from({ length: 21 }, (_, i) => 160 + i);

Deno.test("ed25519: every Wycheproof vector gives the pinned answer", async () => {
  assertEquals(wycheproof.tests.length, 210);
  const wrong: number[] = [];
  for (const t of wycheproof.tests) {
    const expected = t.result === "valid"
      ? true
      : t.result === "invalid"
      ? false
      : t.flags.includes("SmallOrderPublicKey")
      ? false
      : ACCEPTED_MIXED_ORDER.includes(t.tcId);
    if (await verifyStrict(hex(t.pk), hex(t.msg), hex(t.sig)) !== expected) wrong.push(t.tcId);
  }
  assertEquals(wrong, []);
});

Deno.test("ed25519: small-order keys that WebCrypto alone accepts are rejected", async () => {
  const smallOrder = wycheproof.tests.filter((t) => t.flags.includes("SmallOrderPublicKey"));
  assertEquals(smallOrder.length, 8);
  for (const t of smallOrder) {
    assert(await webcryptoOnly(hex(t.pk), hex(t.msg), hex(t.sig)), `tcId ${t.tcId}: WebCrypto accepts`);
    assert(!await verifyStrict(hex(t.pk), hex(t.msg), hex(t.sig)), `tcId ${t.tcId}: strict rejects`);
  }
});

// "Taming the many EdDSAs" (Chalkias, Garillot, Nikolaenko), cases 0–11. Under
// our rules only case 3 (mixed-order A and R that pass both the cofactored and
// the cofactorless equation) verifies: 0–2 have small-order A or R, 4–5 pass
// only the cofactored equation, 6–7 have S >= L, 8–11 non-canonical R or A.
Deno.test("ed25519: speccheck cases 0-11 follow the strict rules", async () => {
  const results: boolean[] = [];
  for (const c of speccheck.cases) {
    results.push(await verifyStrict(hex(c.pub_key), hex(c.message), hex(c.signature)));
  }
  assertEquals(results, [false, false, false, true, false, false, false, false, false, false, false, false]);
});

Deno.test("ed25519: point and scalar checks", () => {
  const L = hex("edd3f55c1a631258d69cf7a2def9de1400000000000000000000000000000010");
  assert(!isCanonicalScalar(L), "S = L");
  const lMinus1 = L.slice();
  lMinus1[0] -= 1;
  assert(isCanonicalScalar(lMinus1), "S = L - 1");

  const identity = hex("0100000000000000000000000000000000000000000000000000000000000000");
  assert(!isStrictPoint(identity), "identity");
  const identityNegZero = identity.slice();
  identityNegZero[31] |= 0x80;
  assert(!isStrictPoint(identityNegZero), "identity with the sign bit set");
  // y = p + 2: not canonical (and not small order).
  assert(!isStrictPoint(hex("efffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f")));
  assert(isStrictPoint(hex(rfc8032.tests[0].public)), "an ordinary key");
  assert(!isStrictPoint(new Uint8Array(31)), "wrong length");
});

Deno.test("ed25519: wrong lengths are rejected without throwing", async () => {
  const t = rfc8032.tests[0];
  assert(!await verifyStrict(hex(t.public).subarray(0, 31), hex(t.message), hex(t.signature)));
  assert(!await verifyStrict(hex(t.public), hex(t.message), hex(t.signature).subarray(0, 63)));
});
