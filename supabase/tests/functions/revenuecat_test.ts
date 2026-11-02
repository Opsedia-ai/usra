import { assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1";
import { HttpError } from "../../functions/_shared/http.ts";
import { createRevenueCatHandler, isAuthorized } from "../../functions/revenuecat-webhook/handler.ts";
import {
  type Catalog,
  type MappedEvent,
  mapRevenueCatEvent,
  parseCatalog,
  type RevenueCatEvent,
} from "../../functions/revenuecat-webhook/mapping.ts";

const USER = "8a7f1c2e-1111-4222-8333-944455556666";
const catalog: Catalog = {
  creditPacks: { usra_credits_5: 5, usra_credits_20: 20 },
  plusEntitlementId: "plus",
  plusCreditsPerPeriod: 10,
  allowSandbox: false,
};

const event = (over: Partial<RevenueCatEvent>): RevenueCatEvent => ({
  id: "evt_1",
  type: "INITIAL_PURCHASE",
  app_user_id: USER,
  event_timestamp_ms: Date.UTC(2026, 10, 2),
  environment: "PRODUCTION",
  store: "PLAY_STORE",
  ...over,
});

const applied = (e: RevenueCatEvent) => {
  const r = mapRevenueCatEvent(e, catalog);
  if (r.kind !== "apply") throw new Error(`expected apply, got ${r.reason}`);
  return r.event;
};

Deno.test("credit pack purchase grants its credits", () => {
  const e = applied(event({ type: "NON_RENEWING_PURCHASE", product_id: "usra_credits_20" }));
  assertEquals([e.creditDelta, e.creditKind, e.entitlement], [20, "purchase", null]);
  assertEquals(e.eventAt, "2026-11-02T00:00:00.000Z");
});

Deno.test("Usra Plus purchase and renewal activate plus and grant monthly credits", () => {
  const expiry = Date.UTC(2026, 11, 2);
  for (const type of ["INITIAL_PURCHASE", "RENEWAL"]) {
    const e = applied(
      event({ type, product_id: "usra_plus_monthly", entitlement_ids: ["plus"], expiration_at_ms: expiry }),
    );
    assertEquals(e.entitlement, "plus");
    assertEquals(e.entitlementActive, true);
    assertEquals(e.expiresAt, "2026-12-02T00:00:00.000Z");
    assertEquals([e.creditDelta, e.creditKind], [10, "subscription_grant"]);
  }
});

Deno.test("expiration deactivates plus without touching credits", () => {
  const e = applied(event({ type: "EXPIRATION", entitlement_ids: ["plus"] }));
  assertEquals([e.entitlementActive, e.creditDelta, e.creditKind], [false, 0, null]);
});

Deno.test("cancellation only turns off auto-renew; a refund revokes", () => {
  assertEquals(
    mapRevenueCatEvent(
      event({ type: "CANCELLATION", entitlement_ids: ["plus"], cancel_reason: "UNSUBSCRIBE" }),
      catalog,
    ),
    { kind: "ignore", reason: "auto_renew_off" },
  );
  const refundPlus = applied(
    event({ type: "CANCELLATION", entitlement_ids: ["plus"], cancel_reason: "CUSTOMER_SUPPORT" }),
  );
  assertEquals(refundPlus.entitlementActive, false);
  const refundPack = applied(
    event({ type: "CANCELLATION", product_id: "usra_credits_5", cancel_reason: "CUSTOMER_SUPPORT" }),
  );
  assertEquals([refundPack.creditDelta, refundPack.creditKind], [-5, "store_refund"]);
});

Deno.test("uncancellation, product change and extension keep plus active", () => {
  for (const type of ["UNCANCELLATION", "PRODUCT_CHANGE", "SUBSCRIPTION_EXTENDED"]) {
    assertEquals(applied(event({ type, entitlement_ids: ["plus"] })).entitlementActive, true);
  }
});

Deno.test("ignored events: test, sandbox, unknown product, anonymous user, other types", () => {
  const reason = (e: RevenueCatEvent, c = catalog) => {
    const r = mapRevenueCatEvent(e, c);
    return r.kind === "ignore" ? r.reason : "applied";
  };
  assertEquals(reason(event({ type: "TEST" })), "test_event");
  assertEquals(reason(event({ environment: "SANDBOX", product_id: "usra_credits_5" })), "sandbox_disabled");
  assertEquals(
    reason(event({ environment: "SANDBOX", product_id: "usra_credits_5" }), { ...catalog, allowSandbox: true }),
    "applied",
  );
  assertEquals(reason(event({ product_id: "something_else" })), "unknown_product");
  assertEquals(
    reason(event({ app_user_id: "$RCAnonymousID:abc", product_id: "usra_credits_5" })),
    "no_supabase_user_id",
  );
  assertEquals(reason(event({ type: "BILLING_ISSUE", entitlement_ids: ["plus"] })), "unhandled_type:BILLING_ISSUE");
});

Deno.test("a Supabase user id found in aliases is used", () => {
  const e = applied(
    event({ app_user_id: "$RCAnonymousID:abc", aliases: ["$RCAnonymousID:abc", USER], product_id: "usra_credits_5" }),
  );
  assertEquals(e.userId, USER);
});

Deno.test("catalog parsing rejects bad config", () => {
  const base = { plusEntitlementId: "plus", plusCreditsPerPeriod: 10, allowSandbox: false };
  assertEquals(parseCatalog({ ...base, creditPacksJson: '{"a":5}' }).creditPacks, { a: 5 });
  assertThrows(() => parseCatalog({ ...base, creditPacksJson: '{"a":-1}' }));
  assertThrows(() => parseCatalog({ ...base, creditPacksJson: "[5]" }));
});

// --- handler -----------------------------------------------------------------

Deno.test("webhook auth accepts the raw secret or Bearer secret only", () => {
  assertEquals(isAuthorized("s3cret", "s3cret"), true);
  assertEquals(isAuthorized("Bearer s3cret", "s3cret"), true);
  assertEquals(isAuthorized("s3cret2", "s3cret"), false);
  assertEquals(isAuthorized(null, "s3cret"), false);
  assertEquals(isAuthorized("", ""), false);
});

Deno.test("webhook handler: rejects bad auth, applies once, reports duplicates", async () => {
  const seen = new Set<string>();
  const applied: MappedEvent[] = [];
  const handler = createRevenueCatHandler({
    secret: "s3cret",
    catalog,
    sink: {
      apply(e) {
        if (seen.has(e.eventId)) return Promise.resolve({ applied: false, duplicate: true });
        seen.add(e.eventId);
        applied.push(e);
        return Promise.resolve({ applied: true });
      },
    },
  });
  const req = (auth: string) =>
    new Request("http://local/rc", {
      method: "POST",
      headers: { Authorization: auth },
      body: JSON.stringify({ api_version: "1.0", event: event({ product_id: "usra_credits_5" }) }),
    });

  const err = await assertRejects(() => handler(req("wrong")), HttpError);
  assertEquals(err.status, 401);

  assertEquals(await (await handler(req("Bearer s3cret"))).json(), { status: "applied" });
  assertEquals(await (await handler(req("Bearer s3cret"))).json(), { status: "duplicate" });
  assertEquals(applied.length, 1);
});
