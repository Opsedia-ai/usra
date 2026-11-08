// approve-device: see _shared/sync_handlers.ts and docs/sync-design.md (sections 7–8).

import { withHttp } from "../_shared/http.ts";
import { createApproveDeviceHandler } from "../_shared/sync_handlers.ts";
import { sessionFromRequest } from "../_shared/sync.ts";
import { SupabaseSyncStore, verifyUserToken } from "../_shared/sync_store.ts";

Deno.serve(withHttp(createApproveDeviceHandler({
  getSession: (req) => sessionFromRequest(req, verifyUserToken),
  store: new SupabaseSyncStore(),
})));
