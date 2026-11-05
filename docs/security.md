# Usra security plan

Usra holds a family's health records: diagnoses, medicines, pregnancy, children,
insurance cards and photos of prescriptions. A leak can hurt people (stigma,
insurance, family conflict), and in Egypt, KSA and the UAE health data is
sensitive personal data with stricter rules. This plan says what we protect,
what is already in the code, what is missing, and when each gap must be
closed.

Status is checked against the code on 2026-11-05. Each work item is a card on
the [roadmap board](https://github.com/orgs/Opsedia-ai/projects/2) (Area
"Security").

## 1. Principles

1. **Local first.** In v1 health data never leaves the phone except as a
   backup file the user makes and keeps.
2. **The server never reads health data.** Cloud sync (v2) is end-to-end
   encrypted; the server stores ciphertext only. AI and cloud OCR see data in
   memory for one request, with consent, and never store or log it.
3. **Encrypt everything at rest**: the database, photos, backups, tokens and
   keys.
4. **Keys stay on the device** in Android Keystore / iOS Keychain, marked
   this-device-only, and are never put in backups or synced.
5. **Least data.** Collect only what a feature needs. No ads SDKs, no
   third-party analytics or crash tools that can see health data.
6. **Nothing sensitive in logs**, notifications, widgets or URLs.
7. **Secure by default, tested.** Each control has a test or a CI check, so it
   can't quietly regress.

## 2. What we protect, from whom

| Asset | Where |
| --- | --- |
| Health records (timeline, medicines, pregnancy, children, follow-ups) | Encrypted SQLite on the phone |
| Photos: insurance cards, prescriptions, reports, medicine boxes | App private folder |
| Database key, recovery key, device keys, auth session | Keystore / Keychain |
| Backup files | Wherever the user puts them (Drive, Files, WhatsApp) |
| Account data (phone number, country, devices), v2 ciphertext | Supabase |
| AI Doctor and cloud OCR requests | Edge function memory, the LLM/OCR provider |

| Threat | Example | Main defences |
| --- | --- | --- |
| Lost or stolen phone | Someone opens the app or copies its files | DB and file encryption, app lock, Keystore keys |
| Someone nearby / shoulder surfing | Family member sees a lock-screen notification or the widget | Private notifications, discreet mode, app lock |
| Malware or a rooted/jailbroken phone | Reads app files or screen | Encryption, FLAG_SECURE, root warning (we can't fully defend a compromised OS) |
| Leaked backup file | Backup shared to the wrong WhatsApp chat | Argon2id + XChaCha20-Poly1305, 100-bit recovery key |
| Network attacker | Café Wi-Fi | HTTPS only, no cleartext, E2EE |
| Server breach or rogue insider | Database dump | E2EE (ciphertext only), RLS, minimal account data, no secrets in code |
| Account takeover | SIM swap, OTP phishing | OTP rate limits, device approval for family keys, alerts on new devices |
| Abuse of paid APIs | Draining AI credits, OCR cost | Auth, credits ledger, rate limits, body size limits |
| Supply chain | Malicious package or GitHub Action | Pinned versions, Dependabot, review, pinned action SHAs |
| Our own mistakes | PHI in a log or crash report, a debug flag in release | Lint rules, release checks, code review, tests |

## 3. Already in place (verified in code)

- **Database**: SQLite3 Multiple Ciphers with a 256-bit random key from
  `Random.secure()`. The app refuses to start if the cipher build is missing
  (`EncryptionUnavailableError`). `app/lib/core/database/connection.dart`.
- **Key storage**: flutter_secure_storage (Keystore / Keychain), iOS
  `first_unlock_this_device`, so keys never move to another device.
- **Backups**: Argon2id (OWASP minimum, 19 MiB, 2 passes) from a ~100-bit
  recovery key, XChaCha20-Poly1305, versioned header, re-keyed SQLite
  snapshot, `quick_check` on restore. `app/lib/core/backup/`.
- **OS backup**: Android `allowBackup=false` plus data extraction rules that
  exclude everything; iOS photo folders excluded from iCloud backup.
- **App lock** (S2): optional 6-digit PIN (trivial ones refused), stored
  only as a salted Argon2id hash (19 MiB, 2 passes) in Keystore / Keychain
  this-device-only, checked in constant time. On Android the lock's storage
  uses `resetOnError: false`, so a Keystore error keeps the app locked
  instead of wiping the lock (fail closed); an unreadable lock is never
  written over and is read again on each try and on resume. Fingerprint or
  face through `local_auth`, biometrics only and, on Android, only with a
  strong (Class 3) sensor; Settings warns that anyone enrolled on the phone
  can open Usra. Wrong tries are counted before each check: after 5, a wait
  of 30 s doubling to at most an hour, which needs real time to pass in the
  running app (changing the phone's clock doesn't end it) and starts again
  in full after a restart. The background timeout (right away / 1 / 5 min)
  is measured with the wall clock, the app's own monotonic time and the
  phone's uptime (`elapsedRealtime` / `CLOCK_MONOTONIC`); any of them
  passing, or the clock going back, locks. The app is covered as soon as it
  starts to leave the screen until the lock has decided, using S3's native
  cover (`coverUntilReady` / `uncover`). Covers every page;
  notification / widget deep links wait until unlocked. Loosening a setting
  needs the PIN. No reset that skips the PIN: wipe app data and restore a
  backup with the recovery key (turning the lock on suggests a backup
  first). Emergency cards on the lock screen are opt-in per person.
  `app/lib/core/security/`, `app/lib/features/app_lock/`.
- **Notifications**: payloads hold only the medicine id, dose time and
  language; the text is rebuilt from the current settings each time a
  reminder is scheduled. Discreet notifications (default on, S4): "Time
  for a medicine", no person, medicine or instructions, and no Taken
  button (identical notifications could mark someone else's dose); a
  snooze set while the app is closed is always discreet. Switching it
  rewrites pending reminders, snoozes and notifications on screen.
  Lock screen: `NotificationVisibility.private` hides content only when
  the phone's lock-screen setting hides sensitive content (many phones
  show it by default), so with discreet off names can show there on
  Android; iOS hides previews when locked by default and shows generic
  text instead.
- **Doses (medical safety, Apple 1.4.2)**: the app records what the
  doctor wrote and never suggests or computes a dose. Dose text is saved
  word for word. Reminder-time shortcuts on a prescription ("3 times a
  day", "every 8 hours from 08:00") only lay times out on the clock; the
  interval is the one the person reads off the prescription, the times
  stay editable, and the form says to check them against it. The only
  arithmetic is calendar days (a course's last day, "day 3 of 7").
  Sick days (C8): the amount given is the family's own words, never
  filled in; "next dose allowed after" (and its optional reminder) is
  shown only when the saved medicine's own instructions state one
  minimum interval ("every 6 hours"), never for a range, two intervals or
  a typed medicine. Its reminder has no Taken button and, in discreet
  mode, reads "A reminder from Usra" with nothing named; its payload
  holds only the sick day and person ids. Fever warning signs are
  informational, cited and say to contact a doctor or call 123
  (`docs/research/fever-warning-signs.md`, needs medical review).
- **Widget**: first name and medicine name only, no strength or condition;
  in discreet mode "Dose due" with no name and no Taken button (a tap
  opens the app).
- **Screen privacy (S3)**: recent-apps card is blank on Android 13+
  (`setRecentsScreenshotEnabled(false)`) and shows the launch screen
  below 13 (a cover added on pause, skipped in split screen) and on iOS
  (cover while the scene is inactive). The cover can be held until the
  app lock is drawn (`coverUntilReady` / `uncover` on
  `usra/screen_privacy`). `FLAG_SECURE` on the recovery key and restore
  screens; optional "Block screenshots" for the whole app (Android).
- **Photos**: app private folder, never the gallery, EXIF not requested
  (`requestFullMetadata: false`). Each file encrypted with
  XChaCha20-Poly1305 under a random 256-bit photo key in the Keystore /
  Keychain (this device only), decrypted in memory to show, and only
  written out decrypted to a cache folder for the share sheet, cleared
  when the sheet returns; share_plus's own Android copies
  (`<cache>/share_plus/`) are cleared when Usra is back in front, before
  each share and on every start. Photos saved before this are encrypted in
  place in the background after start-up. A missing photo key is never
  replaced while encrypted photos exist: the app says photos can't be
  opened and a restore brings them back with a new key. Backups carry
  photos decrypted inside the backup's encryption and say how many they
  left out; a restore encrypts them for the new phone as it unpacks.
  Rolling the app back past this needs a forward fix (photos stay
  encrypted), so it ships with a staged rollout. `app/lib/core/files/`.
- **Clipboard and sharing (S7)**: the recovery key can only be copied
  with its own button (the digits aren't selectable). Android marks the
  clip sensitive (`EXTRA_IS_SENSITIVE`: hidden from the Android 13+
  "copied" preview and keyboard clipboard history) and clears it after
  60 s if it's still ours (by label and timestamp; checked when the app
  next has focus, since Android 10+ hides the clipboard from background
  apps; the pending clear is kept in private preferences, so it still
  happens after Android kills the app; Android 13+ also clears it after an
  hour). If the marked copy fails, nothing is copied and the screen says
  so (never a plain copy). iOS puts it on the
  pasteboard local-only (no Universal Clipboard) with a 60 s expiry. Sharing
  an insurance card, record or photo warns once that it leaves the app's
  protection, with "Don't ask again" (all shares go through
  `shareStoredPhotos`). `lib/core/security/sensitive_clipboard.dart`,
  `share_warning.dart`.
- **Rooted / jailbroken phone (S8)**: checked on the phone, nothing sent:
  Android `su` binaries (fixed paths and `PATH`), Magisk paths, test-keys
  builds; iOS Cydia/Sileo/Zebra, `/var/jb` and other jailbreak files, a
  write outside the sandbox, injected tweak loaders (skipped in the
  simulator). Warned once, in plain words, after the lock and the first-run
  tour; never blocks. No SDK: the open-source ones (RootBeer,
  DTTJailbreakDetection) add little over these checks and are barely
  maintained, the commercial RASP ones are heavy and report to their
  vendor, and for a warning a heuristic is enough (anyone can hide root
  from any of them). `lib/core/security/device_integrity.dart`.
- **iOS Data Protection (S9)**: photo folders are
  `NSFileProtectionComplete` (set on the folder, so new photos inherit it,
  and on existing files at each start and after a restore). The database
  folder and its small files are
  `NSFileProtectionCompleteUntilFirstUserAuthentication`, on purpose:
  Taken / Snooze on a reminder runs while the phone may be locked and
  writes the dose inbox file (`dose_actions.jsonl`) next to the database,
  and the database itself when the app is still running; iOS can also
  start the app in the background for that action, and a database that
  can't be opened at start-up would be treated as damaged and moved aside.
  Android keeps app data in credential-encrypted storage (like the iOS
  class above). Cost of `Complete` on photos: a backup, or the start-up
  migration that encrypts old photos, can't read photos if the phone
  locks part way (or iOS starts the app in the background while locked).
  The backup then fails with "try again" and the migration retries at the
  next start; nothing is lost. Notifications carry no photos and the widget
  reads only its App Group data, so neither is affected. iOS pickers and
  the camera leave plain copies in `tmp/`: each form deletes its own when
  it closes, anything a killed app left is cleared at the next start, and
  the wipe empties `tmp/` too. `lib/core/security/file_protection.dart`.
  Not yet checked on a device.
- **Delete all my data (S10)**: Settings › Delete all my data, after
  typing a word (and the PIN when the app lock is on): signs out of the
  account (best effort, cut off after 10 s; whatever it managed, the local
  session is then dropped with no network call and its auto-refresh
  stopped, before and again after the wipe, so a late refresh can't save
  it back), then
  deletes every Keystore / Keychain item (`usra.*`: database, photo,
  recovery and app-lock keys, account session and device keys), cancels
  every notification, empties the widget, deletes the private folder
  (database, photos, inbox, restore leftovers) and the cache (backup
  files, share copies), clears all settings, and starts again as on first
  run with new keys (if a new photo key can't be saved, photos are marked
  unavailable rather than sealed with the deleted one; if the app can't
  open again it says to close and reopen it). Keys go first, so a wipe cut short has already made
  the rest unreadable; a marker file makes the next start finish it (at
  most 3 tries). Optional "Erase after 10 wrong PINs" in the app-lock
  settings (off by default, warns before turning on, the PIN to turn
  off); with the waits after 5 wrong PINs, 10 takes at least a quarter of
  an hour. Backup files saved elsewhere are untouched and still restore.
  `lib/core/security/data_wipe.dart`.
- **Backup file hygiene (S11)**: the database snapshot for a backup is
  made with `VACUUM INTO`, which keeps the database's encryption, then
  re-keyed; it lives in a work folder deleted as soon as the backup is
  written (or fails). The backup file is deleted from the phone once the
  share sheet is done. Leftovers from a backup the app was killed while
  making, and a half-unpacked restore, are cleared at the next start. The
  recovery key is never written to any file, file name or share text, only
  to the Keystore / Keychain (tested). The recovery key screen warns it's
  the only way in.
- **Backend**: RLS on every table, API roles start with no privileges,
  credits through functions only with locking, idempotent purchase webhook
  with signature check, in-memory rate limiter, body size limits, AI/OCR
  inputs never stored (`supabase/README.md`).
- **Secrets**: `.env` and keys gitignored; only the URL and anon key are
  ever shared; service-role key lives in Supabase secrets.

## 4. Gaps and work plan

Priority: **P0** before the closed beta, **P1** before public launch, **P2**
with the cloud features (M6).

### App

| # | Item | Pri | Notes |
| --- | --- | --- | --- |
| S1 | **Encrypt photos at rest** | P0 | Done (see section 3); verify on a device with existing photos. Was the biggest gap: insurance cards and prescriptions were plain files. Encrypt each file with XChaCha20-Poly1305 using a file key kept in the Keystore (or derived from the DB key); decrypt into memory for display; migrate existing files; share decrypts to a temp file that is deleted after. |
| S2 | **App lock** | P0 | Optional PIN plus biometrics (`local_auth`), on by default from onboarding with skip. Re-lock after N minutes in the background. Simple Mode keeps it easy (biometrics first, big PIN pad). |
| S3 | **Screen privacy** | P0 | Blur the app in the recent-apps switcher (iOS snapshot cover, Android `FLAG_SECURE` or `setRecentsScreenshotEnabled(false)`). `FLAG_SECURE` on the recovery key, emergency card is exempt so it can be shown. |
| S4 | **Discreet mode** | P0 | Setting to show "Time for your medicine" instead of medicine/person names in notifications and the widget. Default on for the lock screen. |
| S5 | **No PHI in logs** | P0 | Replace `debugPrint` of exceptions with a logger that is silent in release and never prints record data. Lint/grep check in CI for `print(`/`debugPrint(` outside the logger. |
| S6 | **Release hardening** | P0 | R8/obfuscation with `--obfuscate --split-debug-info` (symbols kept privately), `debuggable=false`, no cleartext (`usesCleartextTraffic=false` + network security config), iOS ATS default. Android done in the M5 release PR (#19, `docs/release.md`); symbols must be archived per release. iOS ATS still to check when iOS is built. |
| S7 | **Clipboard and sharing** | P1 | Done (see section 3). Clear copied recovery key from the clipboard after 60 s; mark it sensitive on Android 13+. Warn before sharing an insurance card or record outside the app. |
| S8 | **Root / jailbreak and tamper signal** | P1 | Warning done (see section 3); Play Integrity / App Attest still to do. Warn the user (don't block: many budget phones in Egypt are rooted). Later, Play Integrity / App Attest for paid cloud APIs. |
| S9 | **iOS data protection** | P1 | Done in code (see section 3: photos Complete, database UntilFirstUserAuthentication because reminder actions write next to it while locked); verify on a device. `NSFileProtectionComplete` on the database and photo folders where background reminders allow it (reminders don't read the DB), otherwise `CompleteUntilFirstUserAuthentication`. Verify on device. |
| S10 | **Wipe** | P1 | Done (see section 3). "Delete all my data" in settings: DB, photos, keys, prefs, notifications, widget snapshot. Also wipe after too many wrong PINs (optional). |
| S11 | **Backup file hygiene** | P1 | Done (see section 3). Delete the plaintext staging snapshot right after encryption (check), warn that the recovery key is the only way in, never store the recovery key next to the backup. |

### Accounts and cloud (M6)

| # | Item | Pri | Notes |
| --- | --- | --- | --- |
| S12 | **Session and device keys in secure storage** | P2 | supabase_flutter defaults to SharedPreferences; use a secure-storage `LocalStorage`. Device keypair this-device-only. (Sent to the accounts PR.) |
| S13 | **OTP abuse controls** | P2 | Per-number and per-IP limits in the SMS hook, cooldown, block premium-rate destinations, generic errors (no account enumeration), alert on spikes (SMS pumping fraud). |
| S14 | **E2EE sync design review** | P2 | Design written for review: [`docs/sync-design.md`](sync-design.md). Family key per epoch (XChaCha20-Poly1305 records, a random key per file), wrapped to each device with HPKE (X25519); signed hash-chained family log for members, devices and key epochs; signed records; rotation when a member or device is removed; new devices approved from an existing phone (QR or comparison code) or with the recovery key, never by SMS alone. Needs the external crypto review (its section 18) before sync code. **Blocker before any sync code:** close the existing grant and RLS gaps listed as B0 in that doc (device keys overwritable and `devices` insert on all columns, push tokens writable for other devices, family delete from an SMS-only session, direct membership / invite / record writes, `families.created_by` cascade), each with a pgTAP test. |
| S15 | **Account takeover** | P2 | Notify all devices when a new device joins; new device sees no data until approved; SIM-swap note in the UI. |
| S16 | **AI and cloud OCR consent** | P2 | Explicit per-use consent, show exactly what is sent, strip names and IDs before sending, provider with zero data retention / no training (contract), never logged; region notes in the privacy policy. |
| S17 | **Backend hardening** | P2 | Rate limits in a shared store (the in-memory limiter resets per instance), JWT verification on every function, CORS locked to the app, Postgres backups encrypted, Supabase MFA on the dashboard for every admin, least-privilege service keys, audit log of admin actions, secrets rotation runbook. |
| S18 | **Certificate pinning** | P2 | Consider pinning the Supabase host's public key (with a backup pin) once the domain is final; weigh against outage risk. |

### Process and supply chain

| # | Item | Pri | Notes |
| --- | --- | --- | --- |
| S19 | **CI security checks** | P0 | Dependabot (pub, npm/deno, GitHub Actions), gitleaks secret scan on every PR, GitHub secret scanning and push protection on the repo, CodeQL where supported, pin Actions to commit SHAs. |
| S20 | **Security tests** | P0 | Tests that fail if: the DB opens without a key, a photo is written unencrypted, notifications show names in discreet mode, release manifest allows backup/cleartext. |
| S21 | **Repo and account hygiene** | P0 | 2FA required in the GitHub org, branch protection on main (PR + green CI), signed tags for releases, Play App Signing, upload key kept offline with a backup. |
| S22 | **Pre-launch review** | P1 | OWASP MASVS L1 (L2 for storage and crypto) self-assessment, then an external mobile pen test before public launch. |
| S23 | **Incident response** | P1 | Written runbook: who decides, how to rotate keys, how to notify users and regulators. Egypt PDPL requires notifying the Data Protection Center of a breach quickly (72 hours is the commonly cited limit; confirm in legal review); KSA PDPL and UAE PDPL have similar duties. |
| S24 | **Vulnerability disclosure** | P1 | `SECURITY.md` with a contact address and response times. |
| S25 | **Legal and compliance** | P1 | Egypt PDPL (health data is sensitive; licence/permit from the Data Protection Center may be needed), KSA PDPL and data residency, UAE PDPL and health data law (ICT Health Law). Founder task with a lawyer; links to the store/legal drafts. |

## 5. Rules for every PR

- No health data, phone numbers, tokens or keys in logs, errors, analytics,
  URLs, notifications or crash reports.
- New stored data: encrypted at rest and excluded from OS backup.
- New permission or network call: say why in the PR, update
  `docs/store/data-safety.md` and the privacy policy.
- Crypto only through `cryptography` / SQLite3MC with reviewed parameters; no
  home-made algorithms; randomness only from `Random.secure()`.
- New table in Supabase: RLS on, explicit grants, a pgTAP test that another
  user can't read it.
- The code review includes a security pass and a Production impact verdict.

## 6. Order of work

1. **Now (with M5):** S1 photo encryption, S2 app lock, S3 screen privacy,
   S4 discreet mode, S5 logging, S19–S21 CI and repo hygiene, S6 in the
   release PR, S20 tests alongside each.
2. **Before public launch:** S7–S11 (done, S9 and S8's attestation part
   pending as noted), S22 pen test, S23–S25.
3. **With cloud (M6):** S12–S18, starting with the E2EE design review (S14)
   and its B0 grant fixes
   before any sync code.
