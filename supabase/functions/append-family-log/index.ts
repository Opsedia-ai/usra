// append-family-log: see _shared/sync_handlers.ts and docs/sync-design.md (sections 7–8).

import { withHttp } from "../_shared/http.ts";
import { createAppendFamilyLogHandler } from "../_shared/sync_handlers.ts";
import { sessionFromRequest } from "../_shared/sync.ts";
import { SupabaseSyncStore, verifyUserToken } from "../_shared/sync_store.ts";

Deno.serve(withHttp(createAppendFamilyLogHandler({
  getSession: (req) => sessionFromRequest(req, verifyUserToken),
  store: new SupabaseSyncStore(),
})));
