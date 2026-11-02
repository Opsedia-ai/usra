// ai-doctor: verify user -> reserve credits -> call LLM -> validate -> commit
// or refund. The snapshot is held in memory for this request only; it is never
// stored or logged. Only token counts and the credit transaction are kept.

import { type Handler, HttpError, isRecord, json, readJson } from "../_shared/http.ts";
import { type LlmProvider, ProviderError } from "../_shared/llm.ts";
import { validate } from "../_shared/schema.ts";
import type { AiRunLog, AiRunLogger, CreditsStore } from "../_shared/supabase.ts";
import { buildContent, type Locale, SYSTEM_PROMPT } from "./prompt.ts";
import { type AiDoctorReport, REPORT_SCHEMA } from "./report_schema.ts";
import { crossCheckReport, MAX_SNAPSHOT_BYTES, type Snapshot, validateSnapshot } from "./snapshot.ts";

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

type Usage = { model: string; inputTokens: number; outputTokens: number };

export function createAiDoctorHandler(deps: AiDoctorDeps): Handler {
  const newId = deps.newId ?? (() => crypto.randomUUID());

  /** Calls the model and checks the reply; throws HttpError on failure. */
  async function analyse(
    snapshot: Snapshot,
    locale: Locale,
    log: (status: AiRunLog["status"], usage?: Usage) => Promise<void>,
    onFailure: () => Promise<void>,
  ): Promise<{ report: AiDoctorReport; usage: Usage }> {
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
      await onFailure();
      await log("provider_error");
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
      await onFailure();
      await log("invalid_output", usage);
      throw new HttpError(502, "ai_invalid_output", "The AI reply could not be checked. No credits were used.");
    }
    return { report: result.output as AiDoctorReport, usage };
  }

  /** Settles a reservation without letting a database error hide the real outcome. */
  async function settle(kind: "commit" | "refund", reservationId: string): Promise<number | null> {
    try {
      const result = kind === "commit"
        ? await deps.credits.commit(reservationId)
        : await deps.credits.refund(reservationId);
      return result.balance;
    } catch (err) {
      // An unsettled hold is released by the scheduled expiry job.
      console.error("credit_settle_failed", kind, err instanceof Error ? err.name : typeof err);
      return null;
    }
  }

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

    if (!reservation.ok && reservation.error === "duplicate_request" && typeof requestId === "string") {
      // A retry of a request we already charged for (e.g. the reply was lost on
      // the network): run it again for free instead of losing what was paid for.
      const status = await deps.credits.status(userId, requestId);
      if (status === "commit") {
        const logBase = { userId, reservationId: requestId, provider: deps.llm.name, model: deps.llm.model };
        const log = (status: AiRunLog["status"], usage?: Usage) =>
          deps.runLog.log({ ...logBase, ...usage, status: status === "ok" ? "free_retry" : status });
        const { report, usage } = await analyse(snapshot, locale, log, () => Promise.resolve());
        await log("ok", usage);
        return json({ report, credits: { charged: 0, balance: reservation.balance }, model: usage.model });
      }
      if (status === "reserved") {
        throw new HttpError(409, "in_progress", "This analysis is still running. Try again in a moment.");
      }
      throw new HttpError(409, "duplicate_request", "Use a new request_id for a new analysis");
    }

    if (!reservation.ok) {
      if (reservation.error === "duplicate_request") {
        throw new HttpError(409, "duplicate_request", "Use a new request_id for a new analysis");
      }
      throw new HttpError(402, "insufficient_credits", "Not enough AI credits", {
        balance: reservation.balance,
        required: reservation.required ?? deps.creditCost,
      });
    }

    const reservationId = reservation.reservationId;
    const logBase = { userId, reservationId, provider: deps.llm.name, model: deps.llm.model };
    const log = (status: AiRunLog["status"], usage?: Usage) => deps.runLog.log({ ...logBase, ...usage, status });

    const { report, usage } = await analyse(snapshot, locale, log, async () => {
      await settle("refund", reservationId);
    });

    const balance = await settle("commit", reservationId);
    await log(balance === null ? "commit_failed" : "ok", usage);

    return json({
      report,
      credits: { charged: deps.creditCost, balance },
      model: usage.model,
    });
  };
}
