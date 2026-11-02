// ai-doctor: verify user -> reserve credits -> call LLM -> validate -> commit
// or refund. The snapshot is held in memory for this request only; it is never
// stored or logged. Only token counts and the credit transaction are kept.

import { type Handler, HttpError, isRecord, json, readJson } from "../_shared/http.ts";
import { type LlmProvider, ProviderError } from "../_shared/llm.ts";
import { validate } from "../_shared/schema.ts";
import type { AiRunLogger, CreditsStore } from "../_shared/supabase.ts";
import { buildContent, type Locale, SYSTEM_PROMPT } from "./prompt.ts";
import { type AiDoctorReport, REPORT_SCHEMA } from "./report_schema.ts";
import { crossCheckReport, MAX_SNAPSHOT_BYTES, validateSnapshot } from "./snapshot.ts";

export type AiDoctorDeps = {
  getUserId: (req: Request) => Promise<string>;
  credits: CreditsStore;
  llm: LlmProvider;
  runLog: AiRunLogger;
  creditCost: number;
  maxOutputTokens: number;
  newId?: () => string;
};

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function createAiDoctorHandler(deps: AiDoctorDeps): Handler {
  const newId = deps.newId ?? (() => crypto.randomUUID());

  return async (req) => {
    const userId = await deps.getUserId(req);

    const body = await readJson(req, MAX_SNAPSHOT_BYTES + 4096);
    if (!isRecord(body)) throw new HttpError(400, "invalid_request");

    const locale: Locale = body.locale === "en" ? "en" : "ar";
    // The app sends a fresh request_id per run so a network retry can't charge twice.
    const requestId = body.request_id;
    if (requestId !== undefined && (typeof requestId !== "string" || !UUID_RE.test(requestId))) {
      throw new HttpError(400, "invalid_request", "request_id must be a UUID");
    }

    const { snapshot, issues } = validateSnapshot(body.snapshot);
    if (!snapshot) {
      throw new HttpError(400, "invalid_snapshot", "Snapshot failed checks", { issues });
    }

    const reservation = await deps.credits.reserve(userId, deps.creditCost, requestId ?? newId());
    if (!reservation.ok) {
      if (reservation.error === "duplicate_request") {
        throw new HttpError(409, "duplicate_request", "This request was already processed");
      }
      throw new HttpError(402, "insufficient_credits", "Not enough AI credits", {
        balance: reservation.balance,
        required: reservation.required ?? deps.creditCost,
      });
    }
    const reservationId = reservation.reservationId;
    const logBase = { userId, reservationId, provider: deps.llm.name, model: deps.llm.model };

    let result;
    try {
      result = await deps.llm.generateStructured({
        system: SYSTEM_PROMPT,
        content: buildContent(snapshot, locale),
        toolName: "report_findings",
        toolDescription: "Return the findings for this family snapshot.",
        schema: REPORT_SCHEMA,
        maxTokens: deps.maxOutputTokens,
      });
    } catch (err) {
      await deps.credits.refund(reservationId);
      await deps.runLog.log({ ...logBase, status: "provider_error" });
      if (err instanceof ProviderError) {
        throw new HttpError(502, "ai_unavailable", "The AI service is unavailable. No credits were used.");
      }
      throw err;
    }

    const usage = { model: result.model, inputTokens: result.inputTokens, outputTokens: result.outputTokens };
    const errors = validate(REPORT_SCHEMA, result.output);
    if (errors.length === 0) {
      errors.push(...crossCheckReport(result.output as AiDoctorReport, snapshot));
    }
    if (errors.length > 0) {
      await deps.credits.refund(reservationId);
      await deps.runLog.log({ ...logBase, ...usage, status: "invalid_output" });
      throw new HttpError(502, "ai_invalid_output", "The AI reply could not be checked. No credits were used.");
    }

    const committed = await deps.credits.commit(reservationId);
    await deps.runLog.log({ ...logBase, ...usage, status: "ok" });

    return json({
      report: result.output as AiDoctorReport,
      credits: { charged: deps.creditCost, balance: committed.balance },
      model: result.model,
    });
  };
}
