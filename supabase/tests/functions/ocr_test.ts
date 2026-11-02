import { assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1";
import { bytesToBase64 } from "../../functions/_shared/crypto.ts";
import { HttpError } from "../../functions/_shared/http.ts";
import { SlidingWindowLimiter } from "../../functions/_shared/rate_limit.ts";
import type { QuotaResult } from "../../functions/_shared/supabase.ts";
import { createOcrHandler } from "../../functions/ocr-fallback/handler.ts";
import { checkImage, MAX_IMAGE_BYTES } from "../../functions/ocr-fallback/image.ts";
import type { MedicationReader } from "../../functions/ocr-fallback/medication_reader.ts";

const jpeg = (size = 64) => {
  const b = new Uint8Array(size);
  b.set([0xff, 0xd8, 0xff, 0xe0]);
  return bytesToBase64(b);
};

Deno.test("image check: accepts JPEG/PNG/WebP by magic bytes", () => {
  assertEquals(checkImage(jpeg(), "image/jpeg").mediaType, "image/jpeg");
  const png = bytesToBase64(new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
  assertEquals(checkImage(png, undefined).mediaType, "image/png");
  const webp = bytesToBase64(new TextEncoder().encode("RIFF\0\0\0\0WEBPVP8 "));
  assertEquals(checkImage(webp, "image/webp").mediaType, "image/webp");
});

Deno.test("image check: rejects bad base64, other formats, mismatched type and large images", () => {
  const code = (fn: () => unknown) => {
    try {
      fn();
    } catch (e) {
      return (e as HttpError).code;
    }
    return "ok";
  };
  assertEquals(code(() => checkImage("@@@", undefined)), "invalid_image");
  assertEquals(code(() => checkImage(btoa("GIF89a......"), undefined)), "unsupported_image");
  assertEquals(code(() => checkImage(jpeg(), "image/png")), "invalid_image");
  assertEquals(code(() => checkImage(jpeg(MAX_IMAGE_BYTES + 1), undefined)), "image_too_large");
  assertThrows(() => checkImage(undefined, undefined), HttpError);
});

function setup(readerOutput: unknown, quota: QuotaResult = { allowed: true, used: 1, limit: 20 }) {
  let reads = 0;
  const reader: MedicationReader = {
    name: "fake",
    read: () => {
      reads++;
      return Promise.resolve({ output: readerOutput, inputTokens: 1, outputTokens: 1 });
    },
  };
  const handler = createOcrHandler({
    getUserId: () => Promise.resolve("user-1"),
    burstLimiter: new SlidingWindowLimiter(2, 60_000),
    quota: { consume: () => Promise.resolve(quota) },
    reader,
  });
  return { handler, reads: () => reads };
}

const post = (body: unknown) => new Request("http://local/ocr", { method: "POST", body: JSON.stringify(body) });

Deno.test("ocr: returns cleaned medication drafts", async () => {
  const { handler } = setup({
    medications: [{
      name: " Augmentin ",
      strength: "1 g",
      dose: "1 tablet",
      frequency: "every 12 hours",
      duration: null,
      confidence: 0.873,
    }],
  });
  const res = await handler(post({ image_base64: jpeg(), media_type: "image/jpeg", consent: true }));
  assertEquals(res.status, 200);
  assertEquals(await res.json(), {
    medications: [{
      name: "Augmentin",
      strength: "1 g",
      dose: "1 tablet",
      frequency: "every 12 hours",
      duration: null,
      confidence: 0.87,
    }],
    quota: { used: 1, limit: 20 },
  });
});

Deno.test("ocr: consent is required before anything is read", async () => {
  const { handler, reads } = setup({ medications: [] });
  const err = await assertRejects(() => handler(post({ image_base64: jpeg() })), HttpError);
  assertEquals(err.code, "consent_required");
  assertEquals(reads(), 0);
});

Deno.test("ocr: monthly quota and burst limit return 429", async () => {
  const q = setup({ medications: [] }, { allowed: false, used: 20, limit: 20, resetsAt: "2026-12-01T00:00:00Z" });
  const err = await assertRejects(() => q.handler(post({ image_base64: jpeg(), consent: true })), HttpError);
  assertEquals([err.status, err.code], [429, "quota_exceeded"]);

  const b = setup({ medications: [] });
  await b.handler(post({ image_base64: jpeg(), consent: true }));
  await b.handler(post({ image_base64: jpeg(), consent: true }));
  const burst = await assertRejects(() => b.handler(post({ image_base64: jpeg(), consent: true })), HttpError);
  assertEquals(burst.code, "rate_limited");
});

Deno.test("ocr: provider output that breaks the schema is a 502", async () => {
  const { handler } = setup({ medications: [{ name: "X", confidence: 7 }] });
  const err = await assertRejects(() => handler(post({ image_base64: jpeg(), consent: true })), HttpError);
  assertEquals([err.status, err.code], [502, "ocr_invalid_output"]);
});
