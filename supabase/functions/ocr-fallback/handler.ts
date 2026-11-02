// ocr-fallback: the last step of the phone's OCR pipeline, for Arabic and
// handwriting that ML Kit can't read. Runs only after the user taps
// "Improve with cloud". The image is never stored or logged.

import { type Handler, HttpError, isRecord, json, readJson } from "../_shared/http.ts";
import { ProviderError } from "../_shared/llm.ts";
import type { SlidingWindowLimiter } from "../_shared/rate_limit.ts";
import { validate } from "../_shared/schema.ts";
import type { OcrQuota } from "../_shared/supabase.ts";
import { checkImage, MAX_IMAGE_BYTES } from "./image.ts";
import { type MedicationReader, normaliseOcrOutput, OCR_SCHEMA, toDrafts } from "./medication_reader.ts";

export type OcrDeps = {
  getUserId: (req: Request) => Promise<string>;
  burstLimiter: SlidingWindowLimiter;
  quota: OcrQuota;
  reader: MedicationReader;
};

export function createOcrHandler(deps: OcrDeps): Handler {
  return async (req) => {
    const userId = await deps.getUserId(req);

    const burst = deps.burstLimiter.check(userId);
    if (!burst.allowed) {
      throw new HttpError(429, "rate_limited", "Too many requests, try again shortly", {
        retry_after_seconds: burst.retryAfterSeconds,
      });
    }

    const body = await readJson(req, Math.ceil(MAX_IMAGE_BYTES / 3) * 4 + 2048);
    if (!isRecord(body)) throw new HttpError(400, "invalid_request");
    if (body.consent !== true) {
      throw new HttpError(400, "consent_required", "The user must agree to cloud reading first");
    }
    const image = checkImage(body.image_base64, body.media_type);

    const quota = await deps.quota.consume(userId);
    if (!quota.allowed) {
      throw new HttpError(429, "quota_exceeded", "Monthly cloud reading limit reached", {
        limit: quota.limit,
        resets_at: quota.resetsAt,
      });
    }

    let raw;
    try {
      raw = await deps.reader.read(image);
    } catch (err) {
      if (err instanceof ProviderError) {
        throw new HttpError(502, "ocr_unavailable", "Cloud reading is unavailable, please type it in");
      }
      throw err;
    }

    const output = normaliseOcrOutput(raw.output);
    if (validate(OCR_SCHEMA, output).length > 0) {
      throw new HttpError(502, "ocr_invalid_output", "Cloud reading failed, please type it in");
    }

    return json({
      medications: toDrafts(output as { medications: Array<Record<string, unknown>> }),
      quota: { used: quota.used, limit: quota.limit },
    });
  };
}
