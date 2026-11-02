// RevenueCat webhook. Configure in RevenueCat: URL .../functions/v1/revenuecat-webhook,
// Authorization header = REVENUECAT_WEBHOOK_SECRET.

import { boolEnv, intEnv, optionalEnv, requireEnv } from "../_shared/env.ts";
import { withHttp } from "../_shared/http.ts";
import { getServiceClient } from "../_shared/supabase.ts";
import { createRevenueCatHandler, type PurchaseEventSink } from "./handler.ts";
import { parseCatalog } from "./mapping.ts";

const sink: PurchaseEventSink = {
  async apply(e) {
    const { data, error } = await getServiceClient().rpc("apply_purchase_event", {
      p_event_id: e.eventId,
      p_event_type: e.eventType,
      p_user: e.userId,
      p_event_at: e.eventAt,
      p_credit_delta: e.creditDelta,
      p_credit_kind: e.creditKind,
      p_entitlement: e.entitlement,
      p_entitlement_active: e.entitlementActive,
      p_expires_at: e.expiresAt,
      p_product_id: e.productId,
      p_store: e.store,
    });
    if (error) throw new Error(`apply_purchase_event failed: ${error.code}`);
    return data;
  },
};

const handler = createRevenueCatHandler({
  secret: requireEnv("REVENUECAT_WEBHOOK_SECRET"),
  catalog: parseCatalog({
    creditPacksJson: optionalEnv("REVENUECAT_CREDIT_PACKS", '{"usra_credits_5":5,"usra_credits_20":20}'),
    plusEntitlementId: optionalEnv("REVENUECAT_PLUS_ENTITLEMENT", "plus"),
    plusCreditsPerPeriod: intEnv("PLUS_CREDITS_PER_PERIOD", 10),
    allowSandbox: boolEnv("REVENUECAT_ALLOW_SANDBOX", false),
  }),
  sink,
});

Deno.serve(withHttp(handler));
