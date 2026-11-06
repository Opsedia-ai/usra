# Usra backend (Supabase)

Supabase project for the Usra app: Auth (Google and Apple sign-in, no SMS),
Postgres with row-level security, and Edge Functions (Deno / TypeScript).

**What the cloud holds:** accounts, devices and push tokens, entitlements, AI
credits, usage counters, and (from v2 sync) end-to-end-encrypted ciphertext.
**What it never holds:** readable health data. Health records live on the
phone (SQLCipher) in v1. The AI Doctor snapshot and OCR images exist only in
memory for one request and are never stored or logged.

Supabase Cloud has no Middle East region. Nothing here depends on Supabase
Cloud features, so the same migrations and functions can run on a self-hosted
Supabase in Egypt, KSA or the UAE later.

## Layout

```
supabase/
  config.toml                 local stack config (Google and Apple sign-in, function JWT settings)
  migrations/                 SQL schema + RLS, applied in order
  functions/
    _shared/                  CORS/JSON errors, env, auth, Supabase stores, LLM provider,
                              JSON-schema validator, rate limiter
    ai-doctor/                Dr. Usra AI: credits + LLM + schema-checked findings
    ocr-fallback/             cloud reading of medicine photos (Arabic, handwriting)
    revenuecat-webhook/       purchases -> credits_ledger / entitlements
    delete-account/           in-app "Delete account": removes the auth user, everything cascades
    bind-device/              sync: bind an Auth session to a phone that proves its key
    approve-device/           sync: an approved phone approves a new one (QR or comparison code)
    recover-device/           sync: approve a new phone with the recovery device's key
    append-family-log/        sync: append a signed entry to a family log
    publish-head/             sync: publish a signed head beacon
  tests/
    functions/                Deno unit tests (no network, no database)
    database/                 pgTAP tests, run with `supabase test db`
  deno.json                   test / check / lint / fmt tasks
  .env.example                every env var, placeholders only
```

## Database

| Table | Holds | Who can read | Who can write |
| --- | --- | --- | --- |
| `accounts` | 1:1 with `auth.users`: country, locale | own row | own `country`, `locale` |
| `devices` | `kind` phone / recovery, platform, app version, X25519 + Ed25519 public keys (immutable), `status` pending / approved / revoked, the session that registered it, when a session was first bound | own | insert phones (keys, platform, version); update `app_version`, `last_seen_at` of this session's own device; delete only pending phones (approved, revoked and recovery devices are revoked, never deleted, except with the account); `revoke_own_device()` for sign-out. Status only through the device functions below |
| `device_sessions` | Auth session id → phone (one live session per phone) | nobody | service role (`bind-device`) |
| `device_challenges` | single-use server nonces (purpose, user, session, device, 5 minutes) | nobody | `issue_device_challenge()`; used up by the sync functions |
| `account_recovery` | recovery salt, Argon2id settings (bounded), recovery device | own (sign-in-only sessions too) | `set_account_recovery()` (approved device) |
| `pairing_sessions` | comparison-code relay: commitment, nonces, status, 10 minutes | the new phone's session; the account's approved phones | `pairing_start` / `respond` / `reveal` / `cancel` |
| `pairing_bundles` | the HPKE pairing bundle left for a newly approved phone | that phone's session | `approve-device`; the phone deletes it |
| `account_resets` | 7-day account resets: started, cancelled, completed | own (every session, checked on launch) | `start_account_reset()`, `cancel_account_reset()`; completed by `sync_housekeeping()` |
| `push_tokens` | FCM tokens | this session's own device | this session's own device only |
| `entitlements` | Usra Plus status and expiry | own | service role (webhook) |
| `credits_ledger` | append-only AI credit movements | own | service role, through functions only |
| `purchase_events` | processed RevenueCat event ids (idempotency) | nobody | service role |
| `families` | creator (null once deleted), current key version, rotation pending | members on an approved device | create: a genesis log entry; delete: `delete_family()` (owner, approved device) |
| `family_members` | membership, roles (owner, guardian, cared_for, viewer; one owner), `status` active / reset | members on an approved device | only through the family log |
| `family_devices` | exact mirror of the devices each family's log lists, with a `revoked_seq` marker once its `revoke_device` entry lands | members on an approved device | only through the family log |
| `family_invites` | role, invite lookup hash, expiry, accepted / used / revoked, the invitee's device records and MAC | owner on an approved device | `create_family_invite()`, `revoke_family_invite()`, `accept_family_invite()` |
| `family_log` | signed, hash-chained membership log (`hash = sha256(entry)`) | members on an approved device | `append-family-log` (compare-and-set on the head) |
| `family_epochs` | per key version: commitment `KC_v`, history blob, log seq | current devices of the family | only through `rotate_key` / genesis |
| `family_key_wraps` | HPKE wraps of the family key, per device per epoch, signed by the sender | the recipient phone (and its account's recovery device's wraps) | `put_family_key_wraps()`; all of an epoch with `rotate_key`; the recipient phone deletes its own |
| `family_heads` | newest signed head beacon per device | current devices of the family | `publish-head` |
| `e2ee_records` | `family_id`, random v4 `sync_id`, `revision`, `key_version`, padded `ciphertext` (required), `deleted_at` | current devices of the family | `push_e2ee_records()` only (owner, guardian) |
| `ai_runs` | model, token counts, status per AI run | own | service role |
| `ocr_requests` | one row per cloud OCR call (timestamp only) | own | service role |

Every table has RLS on. The API roles start with no privileges on new tables
(see the top of the first migration); each table grants only what it needs.

### Credits

- Balance = `sum(delta)` over `credits_ledger`. `credit_balance()` returns your
  own balance (any user's for the service role).
- An AI run is `reserve_credits` (−n) → `commit_credits` (0) or
  `refund_credits` (+n). Each reservation settles exactly once (unique index).
- Every function that can lower a balance locks the user's `accounts` row
  first, so concurrent runs are serialised. A constraint trigger rejects any
  insert that would leave the balance below zero.
- The ledger cannot be updated or deleted, except by the cascade when the
  account itself is deleted (in-app "Delete account and all data").
- `reserve_credits`, `commit_credits`, `refund_credits`, `apply_purchase_event`,
  `consume_ocr_quota` and `expire_stale_reservations` can only be called by
  the service role (the Edge Functions).
- If a function dies between reserve and settle, `expire_stale_reservations()`
  refunds the credits. Schedule it with pg_cron, for example every 5 minutes:
  `select cron.schedule('expire-reservations', '*/5 * * * *', 'select public.expire_stale_reservations()');`

### End-to-end-encrypted sync (v2): what the database enforces today

The design is [`docs/sync-design.md`](../docs/sync-design.md). Migration
`20261105000001_sync_blockers_b0.sql` closes its B0 blockers;
`20261105000002_sync_log_devices.sql` adds device approval, session binding,
recovery and account reset (B1–B4) and the signed family log, invites, key
wraps and rotation (B5, B6, B9). Every function that trusts an Ed25519
signature is service-role only and is called by its Edge Function after a
strict check; the function then re-checks the caller's user and Auth session
against `device_sessions` itself.

- **Approved-device sessions.** A JWT counts for sync only when its
  `session_id` is bound to an approved phone of the user
  (`private.device_ok()`). A family's records, wraps, epochs and beacons also
  need that phone to be a current device of the family, of an active member
  (`private.family_device_ok()`). A session that has only signed in reads
  and writes none of it, and can't create, accept or revoke invites, push,
  append, wrap, publish beacons or approve devices.
- **Server nonces.** `issue_device_challenge(purpose, device)` returns 32
  random bytes (base64), single-use, bound to the user, the Auth session, the
  purpose and the device, valid 5 minutes; 20 per session per hour.
  `bind`: any session, for its own phone. `approve`: from an approved phone,
  for a pending phone of the account. `recover`: from the session that
  registered (or is bound to) the pending phone; 5 per phone per day (per
  phone, so a sign-in-only session can't use up the real phone's tries; a guess
  at a ~100-bit recovery key gains nothing anyway).
- **A session's own device.** A bound session acts only for the phone it is
  bound to. A session not bound acts only for a pending phone it registered
  that was never bound. A session that lost its binding (its phone revoked, or
  re-bound to a newer session) acts for nothing, and the server ends it
  (`auth.sessions` and its refresh tokens), so a stolen phone's leftover
  session can't delete or touch anything. A new phone therefore binds its
  session while still pending, before it is approved and reads its pairing
  bundle.
- **Binding and re-registration** (`bind-device`). The phone signs
  `"usra/v1/bind-session" || 0x00 || session_id (16) || nonce (32)`. Binding a
  session unbinds the phone's older sessions, so after a lost session the app
  binds its existing device row again instead of registering a new one.
  `enroll: true` lets the account's very first phone approve itself (once
  ever, `accounts.sync_enrolled_at`; after a completed reset, only the phone
  that started it, within 72 hours). Recovery devices never get a session.
- **Revoking.** Approved and recovery devices are never deleted while the
  account exists (a trigger answers `revoke_instead`). Sign-out with sync calls
  `revoke_own_device(device)`. Revoking ends the device's Auth sessions, drops
  its push tokens, wraps and beacons, and flags a rotation in every family
  whose log lists it; each family's list changes only when its log gets the
  `revoke_device` entry, and a rotation is refused (`revoked_device_listed`)
  until then. A person whose last phone in a family was revoked gets back in
  with the recovery key: the recovered phone appends `revoke_device` for the
  old phone and `add_device` for itself, both signed by the recovery device
  (a current device of theirs in that family), then rotates. Revoked rows are
  purged by housekeeping after 90 days unless a family log lists them.
- **Approving** (`approve-device`, ways 1 and 2). The approving phone signs
  `"usra/v1/approve-device" || 0x00 || user_id || device_id || dkx || dsig ||
  nonce` over the keys the server holds for the new phone. With a comparison
  code, `pairing_start(device, commitment)` (new phone, 3 per account per
  hour), `pairing_respond(id, n_E)` (approved phone), `pairing_reveal(id,
  n_N)` (new phone; the server checks `SHA-256(n_N || dkx || dsig)` against the
  commitment, and a wrong reveal ends the session) and then `approve-device`
  with `pairing_id`. The optional `bundle` waits in `pairing_bundles` for the
  new phone's session. Revoked is final; device ids are never reused.
- **Recovery** (`recover-device`, way 3). `set_account_recovery(salt, kdf,
  kx, sig)` from an approved phone (3 a day) creates the recovery device (a
  `devices` row of kind `recovery`, approved by that phone, registered by no
  session) and revokes the previous one, which flags a key rotation. A pending phone reads the salt and KDF settings,
  derives the keys and signs the same approve-device message with the
  recovery device's key. In the log it then appends `add_device` for itself,
  signed by the recovery device, and reads the recovery device's wrap.
- **Account reset.** `start_account_reset(pending phone)` from any session of
  an enrolled account; `cancel_account_reset(id)` only from an approved phone
  approved 7+ days before the reset began. After 7 days `sync_housekeeping()`
  revokes every device of the account except the phone that started it
  (recovery device included), forgets the recovery settings, marks the
  memberships `reset`, flags rotations and lets the account enrol again. If
  that phone signs out (is revoked) or doesn't enrol within 72 hours, the
  account may start a new reset, again with the full 7-day wait, so it is
  never locked out and the delay is never shortened. While that new reset is
  open, any other phone gets `reset_in_progress` (only the phone that started
  it may enrol).
- **Family log** (`append-family-log`). The function strict-parses the entry
  (valid UTF-8, no duplicate keys, depth ≤ 8, integers only, ≤ 16 KiB, exactly
  the fields of its type) and checks
  `Ed25519("usra/v1/log-entry" || 0x00 || entry)` with the key of its `by`
  device, which must be the caller's phone or the caller's recovery device.
  Before locking the family or answering with its head, the signer's account
  must be an active member (`signer_not_member`, the same answer as for a
  family that doesn't exist).
  `append_family_log` repeats the strict parse and appends only on top of the
  current head (`head_mismatch` with the server's head otherwise). The signer
  must be a current device of the family, of an active member. A genesis
  creates the family, lists the creator's approved devices (recovery device
  included) and `KC_1`. Entry fields, by type: `genesis` (`user`, `devices`,
  `key_version`, `kc`), `add_member` (`user`, `role`, `devices`, `invite`,
  `mac`, and `profile` for `cared_for`), `change_role` (`user`, `role`,
  `profile`?), `transfer_owner` (`user`), `remove_member` (`user`, `reason`;
  `account_deleted` only for an account that is gone and that this log added),
  `add_device` (`user`, `device` record), `revoke_device` (`user`, `device`
  id), `rotate_key` (`key_version`, `kc`, `history`, `recipients`). A device
  record is `{ id, user, kind, kx, sig }` and must match an approved `devices`
  row.
- **Joining.** The owner's phone stores `code_hash = hex(SHA-256(
  "usra/v1/invite-lookup" || 0x00 || secret))`. The invitee, on an approved
  phone, calls `accept_family_invite(lookup_hash, devices, mac)`; the server
  never sees the secret. Ten tries per hour (failed ones count). The owner
  lists accepted invites with the invitee's email and last reset
  (`pending_family_invites`) and appends `add_member` naming the invite, with
  the same MAC and devices; each invite is used once. Revoked invites are kept
  and count towards the 20-a-day limit.
- **Removing.** `remove_member`: `removed` by the owner, `left` by the member,
  `account_deleted` once the account is gone, `reset` by any member once the
  reset completed; never the owner. `revoke_device` of one's own device is
  final everywhere; the owner's revocation of another member's device is final
  in that family (a revoked marker stays, so it can't be added back). Either
  drops its wraps and beacons there and flags a rotation.
- **Keys.** `put_family_key_wraps(family, key_version, wraps)` stores wraps of
  the current epoch for devices of the family (existing wraps are kept; a
  phone may delete its own wrap, for example one it can't open).
  `rotate_key` must ship the 72-byte history blob (the entry's `history` is its
  SHA-256) and one wrap for every current device of every active member (the
  entry's `recipients` is SHA-256 of their sorted 16-byte ids); epoch, history
  and wraps are stored in the same transaction and older wraps are dropped.
  While a member whose account was deleted is still in the log, a rotation
  answers `member_removal_pending` (append `remove_member` with
  `account_deleted` first).
- **Head beacons** (`publish-head`). The phone signs
  `"usra/v1/head" || 0x00 || beacon` where the beacon is
  `{ v, family, device, seq, h, at }` for itself and a `(seq, hash)` on the
  log; older beacons never replace newer ones.
- **Records.** `push_e2ee_records(family, log_seq, records)` takes up to 100
  records (2 MiB) as `{ sync_id, key_version, ciphertext (base64), deleted,
  expected_revision }`, from a current device of the family. The batch is
  refused unless `log_seq` is the log head (`stale_log`) and no rotation is
  pending (`rotation_pending`). Each record must use the current key version
  (`stale_key`) and the revision the writer merged, 0 for new
  (`revision_conflict`, with the current row). Ciphertext is padded plaintext
  of 256 B–64 KiB (power of two) + 40 bytes; sync ids are random UUID v4.
  `pull_e2ee_changes(family, after_txid, after_sync, limit)` pages by
  transaction id.
- **Deleting.** `delete_family()` needs the owner role and an approved
  device. Deleting an account clears `families.created_by` instead of
  cascading; a family left with no members is removed with its ciphertext.
- **Housekeeping.** `sync_housekeeping()` (pg_cron, every 15 minutes)
  completes due resets and purges old nonces, pairing state, attempt counters
  and pending phones nobody approved within a week.

## Edge Functions

All functions answer JSON errors as `{ "error": { "code", "message", ... } }`
and never echo request bodies or log health data, emails, names or tokens.

| Function | Auth | Request | Response |
| --- | --- | --- | --- |
| `ai-doctor` | user JWT | `{ snapshot, locale?: "ar"\|"en", request_id?: uuid }` | `{ report: { findings[], urgent, disclaimer }, credits: { charged, balance }, model }` |
| `ocr-fallback` | user JWT | `{ image_base64, media_type?, consent: true }` (≤ 300 KB, JPEG/PNG/WebP) | `{ medications: [{ name, strength, dose, frequency, duration, confidence }], quota }` |
| `delete-account` | user JWT | `{ confirm: true, apple_authorization_code? }` | `{ status: "deleted" \| "not_found" }`; `400 confirmation_required / invalid_apple_code`, `409 family_has_members`, `502 delete_failed` |
| `revenuecat-webhook` | `Authorization` = shared secret | RevenueCat webhook body | `{ status: "applied" \| "duplicate" \| "ignored" }` |
| `bind-device` | user JWT | `{ device_id, nonce, signature, enroll? }` | `{ device_id, status }` |
| `approve-device` | user JWT (approved phone) | `{ device_id, nonce, signature, pairing_id?, bundle? }` | `{ device_id, status, approved_by }` |
| `recover-device` | user JWT (the new phone's session) | `{ device_id, nonce, signature }` | `{ device_id, status, approved_by }` |
| `append-family-log` | user JWT (approved phone) | `{ family_id, seq, prev_hash, entry, signature, history?, wraps? }` | `{ ok, seq, hash }`; `409 { ok: false, error: "head_mismatch", head_seq, head_hash }` |
| `publish-head` | user JWT (approved phone) | `{ family_id, beacon, signature }` | `{ ok, seq }`; `409 stale_beacon / not_on_log` |

The sync functions take binary values as standard base64 (signed JSON inside
uses base64url) and verify Ed25519 strictly (`_shared/ed25519.ts`: S < L,
canonical A and R, small-order A and R rejected, cofactorless), with RFC 8032,
Wycheproof and "Taming the many EdDSAs" vectors in
`tests/functions/ed25519_test.ts`. The handlers are tested with a fake
store (`tests/functions/sync_test.ts`); an end-to-end test through PostgREST
needs the full local stack (`supabase start` and `functions serve`), which CI
doesn't run yet. A wrong signature is `403 bad_signature`;
an unknown signing device answers the same; a used, expired or foreign
nonce `403 bad_challenge`; database refusals come back as their own names (`403 approved_device_required`, `409 already_member`,
`429 too_many_recovery_tries`, ...).

### ai-doctor

1. Verifies the user's JWT.
2. Checks the snapshot is de-identified (no identifying keys, no member
   names, nothing that looks like a phone, ID or email; ≤ 64 KB). This backs
   up the app, which builds the snapshot and shows the user a preview.
3. Reserves `AI_DOCTOR_CREDIT_COST` credits. Errors: `402 insufficient_credits`,
   and `409 duplicate_request` if `request_id` was already used.
4. Calls the LLM through `LlmProvider` (default `AnthropicProvider`, model
   from `AI_DOCTOR_MODEL`) with the fixed safety prompt in `prompt.ts`, forcing
   a single `report_findings` tool call whose input schema is the report schema.
5. Validates the reply against `REPORT_SCHEMA` (severity
   `blue|green|yellow|orange|red`) and checks each finding names a member
   from the snapshot.
6. Commits the credits on success; refunds on provider error (`502 ai_unavailable`)
   or invalid output (`502 ai_invalid_output`). Logs token counts and status to
   `ai_runs`, never the snapshot or the reply.

### ocr-fallback

Runs only after the user taps "Improve with cloud" (`consent: true`). Checks
size and magic bytes, applies a per-instance burst limit
(`OCR_BURST_PER_MINUTE`) and the durable quota in Postgres (`OCR_MONTHLY_LIMIT`
per `OCR_QUOTA_WINDOW_DAYS`), then asks the vision model (`MedicationReader`,
default Claude via `OCR_MODEL`) for structured JSON. Missing fields come back
as `null`. The image is never stored. The phone runs the result through drug
matching and the user confirms before anything is saved.

### delete-account

Deletes the caller's own `auth.users` row with the service role (the user id
comes from the JWT, never the body). `accounts`, `devices`, `push_tokens`,
the credits ledger and their family memberships go with it through
`on delete cascade`; a family left with no members goes too, with its
ciphertext. A family they created but handed over stays
(`tests/database/account_deletion.test.sql`). The app then wipes its session
and device key pair. Records on the phone are untouched.

- **Sign in with Apple:** Apple requires its tokens to be revoked when an account
  is deleted. Native sign-in leaves no Apple token to keep, so the iPhone app opens
  Apple's sheet again and sends the fresh code as `apple_authorization_code`. The
  function swaps it for a token and revokes that (`apple.ts`, with `APPLE_TEAM_ID`,
  `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`), then deletes the user. Nothing from Apple is
  stored. A failure here is logged as a fixed code and never stops the deletion, as
  Apple's TN3194 asks. Closing the sheet in the app cancels the deletion.
- **Retry-safe:** if the delete went through but the response was lost, the
  retry's token is still genuine but its user is gone; Auth says
  `user_not_found` and the function answers `200 { status: "not_found" }`.
- **Shared families are protected:** while the user owns a family that has
  other members, the function refuses with `409 family_has_members`
  (`account_deletion_blockers()`, keyed on the owner role). The owner hands
  over first (a signed `transfer_owner` log entry). B10 will also require an
  approved-device session here.
  The database enforces the same rule for any delete of the owner's account
  (a trigger refuses to drop an owner's membership while others remain).

### revenuecat-webhook

The app must set RevenueCat's `app_user_id` to the Supabase user id. Mapping
(`mapping.ts`):

| Event | Effect |
| --- | --- |
| `INITIAL_PURCHASE` / `NON_RENEWING_PURCHASE` of a credit pack | `+credits` (`purchase`) |
| `INITIAL_PURCHASE` / `RENEWAL` with the Plus entitlement | Plus active until expiry, `+PLUS_CREDITS_PER_PERIOD` (`subscription_grant`) |
| `UNCANCELLATION`, `PRODUCT_CHANGE`, `SUBSCRIPTION_EXTENDED` | Plus active, new expiry |
| `CANCELLATION` (auto-renew off) | ignored: access lasts until `EXPIRATION` |
| `CANCELLATION` with `cancel_reason = CUSTOMER_SUPPORT` (refund) | credit pack: take back up to the remaining balance; Plus: inactive |
| `EXPIRATION` | Plus inactive |
| `TEST`, `BILLING_ISSUE`, `TRANSFER`, sandbox (unless `REVENUECAT_ALLOW_SANDBOX`), unknown products, anonymous users | ignored with a reason (200, so RevenueCat doesn't retry) |

Each event id is applied at most once (`purchase_events`). Older events never
overwrite a newer entitlement state. Database errors return 500 so RevenueCat
retries.

## Running locally

Tools: [Supabase CLI](https://supabase.com/docs/guides/local-development) (`brew install supabase/tap/supabase`),
Deno 2 (`brew install deno`), and Docker for the local stack.

```bash
cd supabase
cp .env.example .env              # used by config.toml (Google and Apple client IDs)
cp .env.example functions/.env    # used by the functions
# fill in real values; both files are git-ignored

supabase start                    # Postgres, Auth, API, Studio (needs Docker)
supabase db reset                 # apply migrations
supabase test db                  # pgTAP tests in tests/database
supabase functions serve          # serve all functions with hot reload
```

Unit tests and checks need only Deno (no Docker, no network once cached):

```bash
cd supabase
deno task test     # deno test --allow-env tests/functions/
deno task check    # type-check every function and test
deno task lint
deno task fmt
```

Example call once the stack is running:

```bash
curl -X POST http://127.0.0.1:54321/functions/v1/ai-doctor \
  -H "Authorization: Bearer $USER_JWT" -H "Content-Type: application/json" \
  -d '{"locale":"en","snapshot":{"members":[{"id":"P1","age":67,"sex":"male"}]}}'
```

## Deploying

```bash
supabase link --project-ref <ref>
supabase db push
supabase secrets set --env-file ./functions/.env
supabase functions deploy ai-doctor ocr-fallback delete-account
supabase functions deploy bind-device approve-device recover-device append-family-log publish-head
supabase functions deploy revenuecat-webhook --no-verify-jwt
```

Then follow [`docs/login-setup.md`](../docs/login-setup.md) for Google and Apple,
and in RevenueCat set the webhook URL and the Authorization header to
`REVENUECAT_WEBHOOK_SECRET`.

## The app

Accounts are optional and off unless the app is built with the project's
URL and anon key (never the service-role key):

```bash
flutter run --dart-define=SUPABASE_URL=https://<ref>.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon key>
```

The URL must be `https://` (anything else counts as not configured, so
the local `http://127.0.0.1` stack can't be used from the app).
Without them the account entry in Settings is hidden and the account route
redirects to Settings, and the app makes no network calls for accounts. With them, Supabase starts only when the account
screen is opened. Sign-in is Google or Apple, through the phone's own sheet and
`signInWithIdToken` (no web redirect; each button also needs its client IDs, see
[`docs/login-setup.md`](../docs/login-setup.md)). On sign-in the app sets
`accounts.locale` (it follows later language changes; `accounts.country` stays
empty, since neither provider says where someone lives) and adds its `devices` row with an X25519 public key. The key pair is per
account and its private half stays in the phone's secure storage (iOS
this-device-only, Android backups off), ready for wrapping the family key in
v2 sync. The session and Auth's PKCE items are in secure storage too. Sign-out
revokes the device row through `revoke_own_device` (best effort; revoked is final, so signing in again registers a new device) and wipes the session and that
account's key pair; delete-account does the same after the server delete.
Both wait for any device setup still running after sign-in. iOS keeps Keychain
items after the app is deleted, so on the first run of an install the app
wipes any `usra.account.*` secure-storage keys left by an earlier install
(the database and recovery keys are outside that prefix).

## Founder setup checklist (hosted project)

`config.toml` only configures the local stack. Set the same in the hosted
project's dashboard before shipping a build with accounts:

- [ ] Google and Apple on, Phone and Email off: every step is in [`docs/login-setup.md`](../docs/login-setup.md).
- [ ] `APPLE_TEAM_ID`, `APPLE_KEY_ID` and `APPLE_PRIVATE_KEY` set as secrets, so deleting an account revokes Sign in with Apple.
- [ ] Share only the project URL (`https://`) and the anon key with the app build; never the service-role key.
- [ ] `supabase functions deploy delete-account` before shipping a build with accounts.

## Regulatory gates (from the technical design)

The AI Doctor and cloud OCR send data to a model hosted outside the region.
Before turning them on: keep AI Doctor off in KSA until SFDA review (MDS-G27);
in Egypt get the PDPL cross-border licence or use an in-region model endpoint
(swap the `LlmProvider` implementation and `ANTHROPIC_BASE_URL` / model env vars).

## Follow-ups

- Server-side country gate for AI Doctor (e.g. block `accounts.country = 'SA'`).
- v2 sync still to build (sync design section 20): attachment blobs (B8), approved-device checks on `delete-account` and
  sign-out revoking instead of deleting (B10), push notifications (B11), the shared rate-limit store and kill switch
  (B12), logging and restore runbook (B13), tombstone purge (B7).
- `pg_cron` job for `expire_stale_reservations()`.
- A Google Cloud Vision `MedicationReader` if it reads Arabic prescriptions better.
