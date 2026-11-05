// delete-account: in-app "Delete account". Removes the caller's auth user;
// accounts, devices, push tokens, credits and family memberships go with it
// through `on delete cascade`, and a family left with no members is removed
// with its ciphertext. A family the user created but no longer owns stays.
// Health records on the phone are not touched (they never left it).

import { type Handler, HttpError, isRecord, json, readJson } from "../_shared/http.ts";

export interface AccountDeleter {
  /** Families the user owns that have other members (see the migrations). */
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
      // The owner of a family with other members must hand ownership over
      // first (a signed transfer_owner entry in the family log).
      if (await deps.deleter.blockers(userId) > 0) {
        throw new HttpError(409, "family_has_members", "A family you own has other members");
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
