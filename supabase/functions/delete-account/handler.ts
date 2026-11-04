// delete-account: in-app "Delete account". Removes the caller's auth user;
// accounts, devices, push tokens, credits, families they created and their
// ciphertext all go with it through `on delete cascade`. Health records on
// the phone are not touched (they never left it).

import { type Handler, HttpError, isRecord, json, readJson } from "../_shared/http.ts";

export interface AccountDeleter {
  /** Deletes the auth user. Resolves false if there was no such user. */
  deleteUser(userId: string): Promise<boolean>;
}

export type DeleteAccountDeps = {
  getUserId: (req: Request) => Promise<string>;
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

    let deleted: boolean;
    try {
      deleted = await deps.deleter.deleteUser(userId);
    } catch (err) {
      console.error("delete_account_failed", err instanceof Error ? err.name : typeof err);
      throw new HttpError(502, "delete_failed", "The account could not be deleted, try again");
    }
    return json({ status: deleted ? "deleted" : "not_found" });
  };
}
