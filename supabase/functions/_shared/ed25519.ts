// Strict Ed25519 verification (docs/sync-design.md, section 5): RFC 8032
// "pure" Ed25519 with S < L, canonical encodings of A and R, small-order A
// and R rejected, and the cofactorless equation (WebCrypto). The phones and the
// Python cross-check tool apply the same rules, so all three accept exactly the
// same signatures (tests/functions/ed25519_test.ts runs RFC 8032, Wycheproof and
// "Taming the many EdDSAs" vectors).

const P = (1n << 255n) - 19n;
const L = (1n << 252n) + 27742317777372353535851937790883648493n;

// Encodings of the 8 points of small order, with the sign bit (top bit of the
// last byte) cleared, including the non-canonical y = p and y = p + 1 (the same
// list libsodium uses for has_small_order).
const SMALL_ORDER = [
  "0000000000000000000000000000000000000000000000000000000000000000", // y = 0, order 4
  "0100000000000000000000000000000000000000000000000000000000000000", // y = 1, identity
  "26e8958fc2b227b045c3f489f2ef98f0d5dfac05d3c63339b13802886d53fc05", // order 8
  "c7176a703d4dd84fba3c0b760d10670f2a2053fa2c39ccc64ec7fd7792ac037a", // order 8
  "ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f", // y = p - 1, order 2
  "edffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f", // y = p
  "eeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f", // y = p + 1
];

function littleEndian(bytes: Uint8Array): bigint {
  let n = 0n;
  for (let i = bytes.length - 1; i >= 0; i--) n = (n << 8n) | BigInt(bytes[i]);
  return n;
}

function hex(bytes: Uint8Array): string {
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

/** A point encoding is canonical (y < p) and not of small order. */
export function isStrictPoint(encoded: Uint8Array): boolean {
  if (encoded.length !== 32) return false;
  const masked = encoded.slice();
  masked[31] &= 0x7f;
  if (littleEndian(masked) >= P) return false;
  return !SMALL_ORDER.includes(hex(masked));
}

/** S < L (no malleable signatures). */
export function isCanonicalScalar(s: Uint8Array): boolean {
  return s.length === 32 && littleEndian(s) < L;
}

/** Verifies an Ed25519 signature with the strict rules above. Never throws. */
export async function verifyStrict(
  publicKey: Uint8Array,
  message: Uint8Array,
  signature: Uint8Array,
): Promise<boolean> {
  if (publicKey.length !== 32 || signature.length !== 64) return false;
  if (!isStrictPoint(publicKey) || !isStrictPoint(signature.subarray(0, 32))) return false;
  if (!isCanonicalScalar(signature.subarray(32))) return false;
  try {
    // Copies, so WebCrypto gets plain ArrayBuffer-backed views.
    const key = await crypto.subtle.importKey("raw", new Uint8Array(publicKey), { name: "Ed25519" }, false, [
      "verify",
    ]);
    return await crypto.subtle.verify({ name: "Ed25519" }, key, new Uint8Array(signature), new Uint8Array(message));
  } catch {
    return false;
  }
}
