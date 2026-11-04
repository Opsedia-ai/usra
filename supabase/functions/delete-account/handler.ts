// delete-account: in-app "Delete account". Removes the caller's auth user;
// accounts, devices, push tokens, credits, family memberships and the
// families they created (with their ciphertext) all go with it through
// `on delete cascade`. Health records on the phone are not touched (they
// never left it).

import { type Handler, HttpError, isRecord, json, readJson } from "../_shared/http.ts";

export interface AccountDeleter {
  /** Families the user created that have other members (see the migration). */
  blockers(userId: string): Promise<number>;
  /** Deletes the auth user. Resolves false if there was no such user. */
  deleteUser(userId: string): Promise<boolean>;
}

export type DeleteAccountDeps = {
  /** The caller's user id; null when the token is genuine but the user is already deleted. */
  getUserId: (req: Request) => Promise<string | null>;
  deleter: AccountDeleter;
};

export function createDeleteAccountHandler(deps: DeleteAccountDeps): Handler {
  return async (req) => {
    const userId = await deps.getUserId(req);

    const body = await readJson(req, 1024);
    // An explicit flag, so a stray call with a valid token can't delete anyone.
    if (!isRecord(body) || body.confirm !== true) {
      throw new HttpError(400, "confirmation_required", "Send { confirm: true } to delete the account");
    }

    // A retry after the response to a successful delete was lost.
    if (userId === null) return json({ status: "not_found" });

    let deleted: boolean;
    try {
      // Deleting would take other members' shared records with it. Until
      // ownership can be handed over (v2 sync), refuse.
      if (await deps.deleter.blockers(userId) > 0) {
        throw new HttpError(409, "family_has_members", "A family you created has other members");
      }
      deleted = await deps.deleter.deleteUser(userId);
    } catch (err) {
      if (err instanceof HttpError) throw err;
      console.error("delete_account_failed", err instanceof Error ? err.name : typeof err);
      throw new HttpError(502, "delete_failed", "The account could not be deleted, try again");
    }
    return json({ status: deleted ? "deleted" : "not_found" });
  };
}
