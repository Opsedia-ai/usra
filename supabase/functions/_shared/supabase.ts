// Supabase clients and the database-backed stores the functions use.
// The service-role key stays inside Edge Functions; it is never sent to apps.

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.49.4";
import { requireEnv } from "./env.ts";
import { HttpError } from "./http.ts";

let serviceClient: SupabaseClient | undefined;

export function getServiceClient(): SupabaseClient {
  serviceClient ??= createClient(requireEnv("SUPABASE_URL"), requireEnv("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return serviceClient;
}

/** Returns the id of the user whose JWT is in the Authorization header. */
export async function requireUserId(req: Request): Promise<string> {
  const header = req.headers.get("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (!token) throw new HttpError(401, "unauthorized", "Missing bearer token");

  const { data, error } = await getServiceClient().auth.getUser(token);
  if (error || !data.user) throw new HttpError(401, "unauthorized", "Invalid or expired session");
  return data.user.id;
}

// --- Credits -----------------------------------------------------------------

export type ReserveResult =
  | { ok: true; reservationId: string; balance: number }
  | { ok: false; error: "insufficient_credits" | "duplicate_request"; balance: number; required?: number };

export type ReservationStatus = "reserved" | "commit" | "refund" | "unknown";

export interface CreditsStore {
  reserve(userId: string, amount: number, reservationId: string): Promise<ReserveResult>;
  /** Where a reservation stands, for this user only ("unknown" for anyone else's). */
  status(userId: string, reservationId: string): Promise<ReservationStatus>;
  commit(reservationId: string): Promise<{ ok: boolean; balance: number }>;
  refund(reservationId: string): Promise<{ ok: boolean; balance: number }>;
}

export class SupabaseCreditsStore implements CreditsStore {
  constructor(private readonly db: SupabaseClient = getServiceClient()) {}

  async reserve(userId: string, amount: number, reservationId: string): Promise<ReserveResult> {
    const { data, error } = await this.db.rpc("reserve_credits", {
      p_user: userId,
      p_amount: amount,
      p_reservation_id: reservationId,
      p_source: "ai-doctor",
    });
    if (error) throw new Error(`reserve_credits failed: ${error.code}`);
    return data.ok
      ? { ok: true, reservationId: data.reservation_id, balance: data.balance }
      : { ok: false, error: data.error, balance: data.balance, required: data.required };
  }

  async status(userId: string, reservationId: string): Promise<ReservationStatus> {
    const { data, error } = await this.db.rpc("reservation_status", {
      p_user: userId,
      p_reservation_id: reservationId,
    });
    if (error) throw new Error(`reservation_status failed: ${error.code}`);
    return data as ReservationStatus;
  }

  async commit(reservationId: string) {
    return await this.settle("commit_credits", reservationId);
  }

  async refund(reservationId: string) {
    return await this.settle("refund_credits", reservationId);
  }

  private async settle(fn: string, reservationId: string) {
    const { data, error } = await this.db.rpc(fn, { p_reservation_id: reservationId });
    if (error) throw new Error(`${fn} failed: ${error.code}`);
    return { ok: Boolean(data.ok), balance: Number(data.balance ?? 0) };
  }
}

// --- AI run log (token counts and status only) -----------------------------------

export type AiRunLog = {
  userId: string;
  reservationId: string;
  provider: string;
  model: string;
  inputTokens?: number;
  outputTokens?: number;
  status: "ok" | "provider_error" | "invalid_output" | "commit_failed" | "free_retry";
};

export interface AiRunLogger {
  log(run: AiRunLog): Promise<void>;
}

export class SupabaseAiRunLogger implements AiRunLogger {
  constructor(private readonly db: SupabaseClient = getServiceClient()) {}

  async log(run: AiRunLog): Promise<void> {
    const { error } = await this.db.from("ai_runs").insert({
      user_id: run.userId,
      reservation_id: run.reservationId,
      provider: run.provider,
      model: run.model,
      input_tokens: run.inputTokens ?? null,
      output_tokens: run.outputTokens ?? null,
      status: run.status,
    });
    // Logging must never fail the user's run.
    if (error) console.error("ai_run_log_failed", error.code);
  }
}

// --- OCR quota ---------------------------------------------------------------------

export type QuotaResult = {
  allowed: boolean;
  used: number;
  limit: number;
  /** "burst": too many in the last minute; "quota": monthly limit reached */
  reason?: "burst" | "quota";
  resetsAt?: string;
  /** Id of the counted request, to give the slot back if the read fails. */
  requestId?: number;
};

export interface OcrQuota {
  consume(userId: string): Promise<QuotaResult>;
  release(userId: string, requestId: number): Promise<void>;
}

export class SupabaseOcrQuota implements OcrQuota {
  constructor(
    private readonly limit: number,
    private readonly windowDays: number,
    private readonly burstPerMinute: number,
    private readonly db: SupabaseClient = getServiceClient(),
  ) {}

  async consume(userId: string): Promise<QuotaResult> {
    const { data, error } = await this.db.rpc("consume_ocr_quota", {
      p_user: userId,
      p_limit: this.limit,
      p_window: `${this.windowDays} days`,
      p_burst: this.burstPerMinute,
      p_burst_window: "1 minute",
    });
    if (error) throw new Error(`consume_ocr_quota failed: ${error.code}`);
    return {
      allowed: data.allowed,
      used: data.used,
      limit: data.limit,
      reason: data.reason,
      resetsAt: data.resets_at,
      requestId: data.request_id,
    };
  }

  async release(userId: string, requestId: number): Promise<void> {
    const { error } = await this.db.rpc("release_ocr_quota", { p_user: userId, p_request_id: requestId });
    if (error) throw new Error(`release_ocr_quota failed: ${error.code}`);
  }
}
