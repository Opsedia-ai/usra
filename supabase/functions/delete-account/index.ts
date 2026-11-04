// Delete account. POST { confirm: true } with the user's JWT.

import { withHttp } from "../_shared/http.ts";
import { getServiceClient, requireUserId } from "../_shared/supabase.ts";
import { type AccountDeleter, createDeleteAccountHandler } from "./handler.ts";

const deleter: AccountDeleter = {
  async deleteUser(userId) {
    const { error } = await getServiceClient().auth.admin.deleteUser(userId);
    if (!error) return true;
    if (error.status === 404) return false;
    throw new Error(`deleteUser failed: ${error.status ?? "unknown"}`);
  },
};

Deno.serve(withHttp(createDeleteAccountHandler({ getUserId: requireUserId, deleter })));
