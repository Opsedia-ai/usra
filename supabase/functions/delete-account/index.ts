// Delete account. POST { confirm: true } with the user's JWT.

import { withHttp } from "../_shared/http.ts";
import { getServiceClient, requireUserIdOrGone } from "../_shared/supabase.ts";
import { type AccountDeleter, createDeleteAccountHandler } from "./handler.ts";

const deleter: AccountDeleter = {
  async blockers(userId) {
    const { data, error } = await getServiceClient().rpc("account_deletion_blockers", { p_user: userId });
    if (error) throw new Error(`account_deletion_blockers failed: ${error.code}`);
    return Number(data ?? 0);
  },
  async deleteUser(userId) {
    const { error } = await getServiceClient().auth.admin.deleteUser(userId);
    if (!error) return true;
    if (error.status === 404) return false;
    throw new Error(`deleteUser failed: ${error.status ?? "unknown"}`);
  },
};

Deno.serve(withHttp(createDeleteAccountHandler({ getUserId: requireUserIdOrGone, deleter })));
