// Cloud OCR fallback. POST { image_base64, media_type?, consent: true } with the user's JWT.

import { intEnv, optionalEnv, requireEnv } from "../_shared/env.ts";
import { withHttp } from "../_shared/http.ts";
import { AnthropicProvider } from "../_shared/llm.ts";
import { SlidingWindowLimiter } from "../_shared/rate_limit.ts";
import { requireUserId, SupabaseOcrQuota } from "../_shared/supabase.ts";
import { createOcrHandler } from "./handler.ts";
import { LlmMedicationReader } from "./medication_reader.ts";

const handler = createOcrHandler({
  getUserId: requireUserId,
  burstLimiter: new SlidingWindowLimiter(intEnv("OCR_BURST_PER_MINUTE", 5), 60_000),
  quota: new SupabaseOcrQuota(intEnv("OCR_MONTHLY_LIMIT", 20), intEnv("OCR_QUOTA_WINDOW_DAYS", 30)),
  reader: new LlmMedicationReader(
    new AnthropicProvider({
      apiKey: requireEnv("ANTHROPIC_API_KEY"),
      model: optionalEnv("OCR_MODEL", "claude-haiku-5-5"),
      baseUrl: optionalEnv("ANTHROPIC_BASE_URL", "https://api.anthropic.com"),
      timeoutMs: 30_000,
    }),
  ),
});

Deno.serve(withHttp(handler));
