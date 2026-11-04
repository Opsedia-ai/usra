# Usra backend (Supabase)

Supabase project for the Usra app: Auth (phone OTP through our own SMS hook),
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
  config.toml                 local stack config (SMS hook, function JWT settings)
  migrations/                 SQL schema + RLS, applied in order
  functions/
    _shared/                  CORS/JSON errors, env, auth, Supabase stores, LLM provider,
                              JSON-schema validator, rate limiter, webhook signatures
    ai-doctor/                Dr. Usra AI: credits + LLM + schema-checked findings
    ocr-fallback/             cloud reading of medicine photos (Arabic, handwriting)
    revenuecat-webhook/       purchases -> credits_ledger / entitlements
    delete-account/           in-app "Delete account": removes the auth user, everything cascades
    send-sms-hook/            Supabase Auth Send SMS hook (Unifonic or Twilio)
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
| `devices` | platform, app version, device public key (for wrapping the family key) | own | own |
| `push_tokens` | FCM tokens | own | own |
| `entitlements` | Usra Plus status and expiry | own | service role (webhook) |
| `credits_ledger` | append-only AI credit movements | own | service role, through functions only |
| `purchase_events` | processed RevenueCat event ids (idempotency) | nobody | service role |
| `families`, `family_members` | membership and roles (owner, guardian, cared_for, viewer) | members | owner |
| `e2ee_records` | `family_id`, `record_id`, `key_version`, `ciphertext`, `updated_at`, `deleted_at` | members | owner, guardian |
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

### End-to-end-encrypted records (v2 sync)

The phone encrypts each record with the family key (AES-256-GCM) before
upload. The server sees ids, a key version, timestamps and ciphertext only,
not even the record type. `updated_at` is set by the server, so conflicts are
last writer wins on server time. Deletes are soft (`deleted_at`, ciphertext
may be dropped). Wrapping the family key per device and rotating it when a
member leaves is still to be designed (see Follow-ups).

## Edge Functions

All functions answer JSON errors as `{ "error": { "code", "message", ... } }`
and never echo request bodies or log health data, phone numbers or codes.

| Function | Auth | Request | Response |
| --- | --- | --- | --- |
| `ai-doctor` | user JWT | `{ snapshot, locale?: "ar"\|"en", request_id?: uuid }` | `{ report: { findings[], urgent, disclaimer }, credits: { charged, balance }, model }` |
| `ocr-fallback` | user JWT | `{ image_base64, media_type?, consent: true }` (≤ 300 KB, JPEG/PNG/WebP) | `{ medications: [{ name, strength, dose, frequency, duration, confidence }], quota }` |
| `delete-account` | user JWT | `{ confirm: true }` | `{ status: "deleted" \| "not_found" }`; `400 confirmation_required`, `502 delete_failed` |
| `revenuecat-webhook` | `Authorization` = shared secret | RevenueCat webhook body | `{ status: "applied" \| "duplicate" \| "ignored" }` |
| `send-sms-hook` | Standard Webhooks signature | Supabase Auth hook payload | `{}` or `{ error: { http_code, message } }` |

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
the credits ledger, families they created and those families' ciphertext all
go with it through `on delete cascade` (`tests/database/account_deletion.test.sql`).
The app then forgets its device key pair. Records on the phone are untouched.

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

### send-sms-hook

Verifies the Standard Webhooks signature (`webhook-id`, `webhook-timestamp`,
`webhook-signature`, 5-minute tolerance) against `SEND_SMS_HOOK_SECRETS`, then
sends a bilingual OTP text through `SmsProvider`: `UnifonicProvider` (default)
or `TwilioProvider`, chosen by `SMS_PROVIDER`. Add a provider by implementing
`send(toE164, body)`.

## Running locally

Tools: [Supabase CLI](https://supabase.com/docs/guides/local-development) (`brew install supabase/tap/supabase`),
Deno 2 (`brew install deno`), and Docker for the local stack.

```bash
cd supabase
cp .env.example .env              # used by config.toml (SEND_SMS_HOOK_SECRETS)
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
supabase functions deploy revenuecat-webhook send-sms-hook --no-verify-jwt
```

Then, in the dashboard: Auth → Hooks → Send SMS → HTTPS → the
`send-sms-hook` URL (copy the generated secret into `SEND_SMS_HOOK_SECRETS`),
and in RevenueCat set the webhook URL and the Authorization header to
`REVENUECAT_WEBHOOK_SECRET`.

## The app

Accounts are optional and off unless the app is built with the project's
URL and anon key (never the service-role key):

```bash
flutter run --dart-define=SUPABASE_URL=https://<ref>.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon key>
```

The URL must be `https://` (anything else counts as not configured).
Without them the account entry in Settings is hidden and the account route
redirects to Settings, and the app makes no network calls for accounts. With them, Supabase starts only when the account
screen is opened. Sign-in is phone + SMS code; on sign-in the app sets
`accounts.country` / `locale` (the locale follows later language changes)
and adds its `devices` row with an X25519 public key. The key pair is per
account and its private half stays in the phone's secure storage (iOS
this-device-only, Android backups off), ready for wrapping the family key in
v2 sync. The session and Auth's PKCE items are in secure storage too. Sign-out
deletes the device row (best effort) and wipes the session and that
account's key pair; delete-account does the same after the server delete.

## Regulatory gates (from the technical design)

The AI Doctor and cloud OCR send data to a model hosted outside the region.
Before turning them on: keep AI Doctor off in KSA until SFDA review (MDS-G27);
in Egypt get the PDPL cross-border licence or use an in-region model endpoint
(swap the `LlmProvider` implementation and `ANTHROPIC_BASE_URL` / model env vars).

## Follow-ups

- Server-side country gate for AI Doctor (e.g. block `accounts.country = 'SA'`).
- Family key wrapping per device, invites and key rotation for v2 sync.
- `pg_cron` job for `expire_stale_reservations()`.
- A Google Cloud Vision `MedicationReader` if it reads Arabic prescriptions better.
