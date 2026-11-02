// revenuecat-webhook: RevenueCat -> credits_ledger / entitlements.
// Auth: RevenueCat sends the Authorization header value configured in its
// dashboard; we compare it to REVENUECAT_WEBHOOK_SECRET in constant time.
// Idempotent: apply_purchase_event records each event id once.

import { timingSafeEqual } from "../_shared/crypto.ts";
import { type Handler, HttpError, isRecord, json, readJson } from "../_shared/http.ts";
import { type Catalog, type MappedEvent, mapRevenueCatEvent, type RevenueCatEvent } from "./mapping.ts";

export interface PurchaseEventSink {
  apply(event: MappedEvent): Promise<{ applied: boolean; duplicate?: boolean; error?: string }>;
}

export type WebhookDeps = { secret: string; catalog: Catalog; sink: PurchaseEventSink };

export function isAuthorized(header: string | null, secret: string): boolean {
  if (!header || !secret) return false;
  const value = header.startsWith("Bearer ") ? header.slice(7) : header;
  return timingSafeEqual(value, secret);
}

export function createRevenueCatHandler(deps: WebhookDeps): Handler {
  return async (req) => {
    if (!isAuthorized(req.headers.get("Authorization"), deps.secret)) {
      throw new HttpError(401, "unauthorized");
    }

    const body = await readJson(req, 64 * 1024);
    if (!isRecord(body) || !isRecord(body.event)) throw new HttpError(400, "invalid_event");

    const mapped = mapRevenueCatEvent(body.event as RevenueCatEvent, deps.catalog);
    if (mapped.kind === "ignore") {
      // 200 so RevenueCat does not retry events we deliberately skip.
      return json({ status: "ignored", reason: mapped.reason });
    }

    // A database error throws -> 500 -> RevenueCat retries; the event id keeps it idempotent.
    const result = await deps.sink.apply(mapped.event);
    if (result.duplicate) return json({ status: "duplicate" });
    if (!result.applied) return json({ status: "ignored", reason: result.error ?? "not_applied" });
    return json({ status: "applied" });
  };
}
