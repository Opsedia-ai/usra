// Dr. Usra AI. POST { snapshot, locale?, request_id? } with the user's JWT.

import { intEnv, optionalEnv, requireEnv } from "../_shared/env.ts";
import { withHttp } from "../_shared/http.ts";
import { AnthropicProvider } from "../_shared/llm.ts";
import { requireUserId, SupabaseAiRunLogger, SupabaseCreditsStore } from "../_shared/supabase.ts";
import { createAiDoctorHandler } from "./handler.ts";

const handler = createAiDoctorHandler({
  getUserId: requireUserId,
  credits: new SupabaseCreditsStore(),
  runLog: new SupabaseAiRunLogger(),
  llm: new AnthropicProvider({
    apiKey: requireEnv("ANTHROPIC_API_KEY"),
    model: optionalEnv("AI_DOCTOR_MODEL", "claude-sonnet-5-5"),
    baseUrl: optionalEnv("ANTHROPIC_BASE_URL", "https://api.anthropic.com"),
  }),
  creditCost: intEnv("AI_DOCTOR_CREDIT_COST", 1),
  maxOutputTokens: intEnv("AI_DOCTOR_MAX_OUTPUT_TOKENS", 2000),
});

Deno.serve(withHttp(handler));
