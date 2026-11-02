// Checks the uploaded image before it goes anywhere. The phone crops,
// compresses (~150 KB) and strips metadata first.

import { base64ToBytes } from "../_shared/crypto.ts";
import { HttpError } from "../_shared/http.ts";

export const MAX_IMAGE_BYTES = 300 * 1024;

export const MEDIA_TYPES = ["image/jpeg", "image/png", "image/webp"] as const;
export type MediaType = typeof MEDIA_TYPES[number];

function sniff(bytes: Uint8Array): MediaType | undefined {
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return "image/jpeg";
  if (bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47) return "image/png";
  const riff = String.fromCharCode(...bytes.slice(0, 4));
  const webp = String.fromCharCode(...bytes.slice(8, 12));
  if (riff === "RIFF" && webp === "WEBP") return "image/webp";
  return undefined;
}

export type CheckedImage = { base64: string; mediaType: MediaType; bytes: number };

export function checkImage(base64: unknown, declaredType: unknown): CheckedImage {
  if (typeof base64 !== "string" || base64.length === 0) {
    throw new HttpError(400, "invalid_image", "image_base64 is required");
  }
  // Base64 is ~4/3 the size of the bytes; reject early before decoding.
  if (base64.length > Math.ceil(MAX_IMAGE_BYTES / 3) * 4 + 4) {
    throw new HttpError(413, "image_too_large", `Image must be at most ${MAX_IMAGE_BYTES / 1024} KB`);
  }
  let bytes: Uint8Array;
  try {
    bytes = base64ToBytes(base64);
  } catch {
    throw new HttpError(400, "invalid_image", "image_base64 is not valid base64");
  }
  if (bytes.byteLength > MAX_IMAGE_BYTES) {
    throw new HttpError(413, "image_too_large", `Image must be at most ${MAX_IMAGE_BYTES / 1024} KB`);
  }
  const actual = sniff(bytes);
  if (!actual) throw new HttpError(415, "unsupported_image", "Use JPEG, PNG or WebP");
  if (declaredType !== undefined && declaredType !== actual) {
    throw new HttpError(400, "invalid_image", "media_type does not match the image");
  }
  return { base64, mediaType: actual, bytes: bytes.byteLength };
}
