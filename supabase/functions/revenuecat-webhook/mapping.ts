// Maps RevenueCat webhook events to ledger and entitlement changes.
// Pure function: no I/O, so every event type is unit-tested.
// RevenueCat's app_user_id must be set to the Supabase user id by the app.

export type RevenueCatEvent = {
  id: string;
  type: string;
  app_user_id?: string;
  original_app_user_id?: string;
  aliases?: string[];
  product_id?: string;
  entitlement_ids?: string[] | null;
  event_timestamp_ms?: number;
  purchased_at_ms?: number;
  expiration_at_ms?: number | null;
  environment?: "SANDBOX" | "PRODUCTION";
  store?: string;
  cancel_reason?: string;
};

export type Catalog = {
  /** Consumable product id -> credits it grants, e.g. { usra_credits_5: 5 } */
  creditPacks: Record<string, number>;
  /** RevenueCat entitlement id that means Usra Plus */
  plusEntitlementId: string;
  /** Credits granted on each Usra Plus purchase or renewal */
  plusCreditsPerPeriod: number;
  allowSandbox: boolean;
};

export type MappedEvent = {
  eventId: string;
  eventType: string;
  userId: string;
  eventAt: string;
  creditDelta: number;
  creditKind: "purchase" | "subscription_grant" | "store_refund" | null;
  entitlement: "plus" | null;
  entitlementActive: boolean | null;
  expiresAt: string | null;
  productId: string | null;
  store: string | null;
};

export type MapResult =
  | { kind: "apply"; event: MappedEvent }
  | { kind: "ignore"; reason: string };

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function pickUserId(e: RevenueCatEvent): string | undefined {
  return [e.app_user_id, e.original_app_user_id, ...(e.aliases ?? [])]
    .find((id): id is string => typeof id === "string" && UUID_RE.test(id));
}

const iso = (ms: number | null | undefined) => (typeof ms === "number" ? new Date(ms).toISOString() : null);

export function mapRevenueCatEvent(e: RevenueCatEvent, catalog: Catalog): MapResult {
  if (!e || typeof e.id !== "string" || typeof e.type !== "string") {
    return { kind: "ignore", reason: "malformed_event" };
  }
  if (e.type === "TEST") return { kind: "ignore", reason: "test_event" };
  if (e.environment === "SANDBOX" && !catalog.allowSandbox) {
    return { kind: "ignore", reason: "sandbox_disabled" };
  }

  const userId = pickUserId(e);
  if (!userId) return { kind: "ignore", reason: "no_supabase_user_id" };

  const productId = e.product_id ?? null;
  const packCredits = productId ? catalog.creditPacks[productId] : undefined;
  const isPlus = (e.entitlement_ids ?? []).includes(catalog.plusEntitlementId);
  const isRefund = e.cancel_reason === "CUSTOMER_SUPPORT";

  const base: MappedEvent = {
    eventId: e.id,
    eventType: e.type,
    userId,
    eventAt: iso(e.event_timestamp_ms ?? e.purchased_at_ms) ?? new Date().toISOString(),
    creditDelta: 0,
    creditKind: null,
    entitlement: null,
    entitlementActive: null,
    expiresAt: null,
    productId,
    store: e.store ?? null,
  };
  const plus = (active: boolean): MappedEvent => ({
    ...base,
    entitlement: "plus",
    entitlementActive: active,
    expiresAt: iso(e.expiration_at_ms),
  });

  switch (e.type) {
    case "NON_RENEWING_PURCHASE":
    case "INITIAL_PURCHASE":
      if (packCredits !== undefined) {
        return { kind: "apply", event: { ...base, creditDelta: packCredits, creditKind: "purchase" } };
      }
      if (isPlus) {
        return {
          kind: "apply",
          event: { ...plus(true), creditDelta: catalog.plusCreditsPerPeriod, creditKind: "subscription_grant" },
        };
      }
      return { kind: "ignore", reason: "unknown_product" };

    case "RENEWAL":
      if (!isPlus) return { kind: "ignore", reason: "unknown_product" };
      return {
        kind: "apply",
        event: { ...plus(true), creditDelta: catalog.plusCreditsPerPeriod, creditKind: "subscription_grant" },
      };

    case "UNCANCELLATION":
    case "PRODUCT_CHANGE":
    case "SUBSCRIPTION_EXTENDED":
      return isPlus ? { kind: "apply", event: plus(true) } : { kind: "ignore", reason: "unknown_product" };

    case "CANCELLATION":
      // A plain cancellation only turns off auto-renew: access lasts until EXPIRATION.
      if (!isRefund) return { kind: "ignore", reason: "auto_renew_off" };
      if (packCredits !== undefined) {
        return { kind: "apply", event: { ...base, creditDelta: -packCredits, creditKind: "store_refund" } };
      }
      return isPlus ? { kind: "apply", event: plus(false) } : { kind: "ignore", reason: "unknown_product" };

    case "EXPIRATION":
      return isPlus ? { kind: "apply", event: plus(false) } : { kind: "ignore", reason: "unknown_product" };

    default:
      // BILLING_ISSUE (grace period), SUBSCRIPTION_PAUSED, TRANSFER, etc.
      return { kind: "ignore", reason: `unhandled_type:${e.type}` };
  }
}

export function parseCatalog(env: {
  creditPacksJson: string;
  plusEntitlementId: string;
  plusCreditsPerPeriod: number;
  allowSandbox: boolean;
}): Catalog {
  const packs = JSON.parse(env.creditPacksJson) as unknown;
  if (typeof packs !== "object" || packs === null || Array.isArray(packs)) {
    throw new Error("REVENUECAT_CREDIT_PACKS must be a JSON object");
  }
  for (const [id, n] of Object.entries(packs)) {
    if (!Number.isInteger(n) || (n as number) <= 0) throw new Error(`Bad credit amount for ${id}`);
  }
  return {
    creditPacks: packs as Record<string, number>,
    plusEntitlementId: env.plusEntitlementId,
    plusCreditsPerPeriod: env.plusCreditsPerPeriod,
    allowSandbox: env.allowSandbox,
  };
}
