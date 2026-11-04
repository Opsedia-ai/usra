# Usra family sync: end-to-end encryption design and threat review (S14)

Status: **design for review**, 2026-11-05. No sync code may be merged before
this design has been reviewed (security plan S14) and the open questions in
section 18 are answered by an external cryptography reviewer.

This document says how a family shares health records across phones through
Supabase without the server ever being able to read them. It replaces the
short sync notes in the technical design (`docs/pdf/04-technical-design.pdf`,
"Sync rules") and in `supabase/README.md`; section 19 lists what changes
from those notes.

Words: **must** is a rule the code and tests enforce; **should** is the
default unless a reviewer finds a reason not to.

## Contents

1. Summary
2. Goals and non-goals
3. Actors and roles
4. What the server sees and doesn't
5. Building blocks
6. Keys
7. The family log (signed membership)
8. Device enrolment and account safety
9. Joining a family
10. Removing members and devices, key rotation
11. Recovery
12. Sync protocol
13. Metadata, logging and server backups
14. Threat model
15. Libraries
16. Test plan
17. Phased rollout
18. Open questions for the external reviewer
19. Changes to earlier notes
20. Backend follow-ups (board cards)

## 1. Summary

- Every family has a random 256-bit **family key**, versioned by **epoch**
  (`key_version`). Records are encrypted with XChaCha20-Poly1305 under a key
  derived from it. Each photo or file has its own random key, kept inside the
  encrypted attachment record.
- The family key is **wrapped to every device** of every member with HPKE
  (RFC 9180, X25519 + HKDF-SHA256 + ChaCha20-Poly1305), and each wrap is
  signed by the device that made it.
- Every device has an **X25519** key (already in the app) and a new
  **Ed25519** signing key. Membership, devices and key changes are entries in
  a **signed, hash-chained family log** that every phone verifies. The
  server stores the log but cannot forge, reorder or quietly drop entries
  without the phones noticing (up to the limits in section 14).
- Records are **signed** by the device that wrote them, inside the
  encryption, so a viewer who knows the family key still can't forge a
  guardian's edit, and the server learns nothing about who wrote what.
- **OTP alone never gives data access.** A newly signed-in phone is a
  *pending* device until an existing phone approves it (QR, or a 6-digit
  comparison code) or the person types their **recovery key**. Postgres
  row-level security checks that the session belongs to an approved device,
  not only that the user is a family member.
- The existing **recovery key** (the 36-digit paper key used for backups)
  also derives a **recovery device**: an offline key pair that receives every
  family key, so a person who loses every phone can get back in.
- Removing a member or device **rotates** the family key. The removed party
  keeps what they already had on their phone and can't read anything written
  after the rotation.
- Sync pushes encrypted records to `e2ee_records` with **compare-and-set** on
  a server revision and merges **per field** with **hybrid logical clocks**
  carried inside the signed ciphertext. Deletes are signed tombstones.
- The server sees ids, padded sizes, times, key versions, membership and the
  device list; it never sees record types, names, values or file contents.

## 2. Goals and non-goals

### Goals

1. **Confidentiality from the server.** Neither Opsedia, Supabase, a
   hosting provider, an insider nor someone with a database dump can read
   health data, profile names, record types or attachments.
2. **Integrity from the server.** The server can't change, invent, move or
   attribute records, and can't add a member or device to a family, without
   the phones rejecting it.
3. **Family sharing with roles**: owner, guardian, cared-for and viewer, as
   in the existing `family_members` table.
4. **Several phones per person**, and moving to a new phone.
5. **Recovery** after losing every phone, with the recovery key.
6. **Account takeover resistance.** A SIM swap or a phished SMS code gives
   no health data and can't lock the real person out silently.
7. **Offline first.** The phone's database stays the source of truth; sync
   is a background job that can be off for weeks.
8. **Budget phones.** Works on a 2 GB RAM Android phone on a slow
   connection; no step needs more than a few seconds of CPU.
9. **Reviewable.** Standard primitives, test vectors, small number of
   constructions; nothing home-made where a standard exists.

### Non-goals (v2.0)

- **Per-profile privacy inside a family.** Everyone in a family can read
  every record of that family. A cared-for adult who wants something private
  keeps it outside the family (or in a later "private scope", section 18,
  Q9). The app must say this plainly when someone is invited.
- **Hiding the social graph from the server.** The server knows which
  accounts (phone numbers) share a family; row-level security needs it.
- **Hiding that someone uses Usra, or when.** Request times and sizes are
  visible to the server and to Google (push).
- **Protecting against a compromised phone OS or a malicious app build**
  (S8, S19 cover what we can).
- **Clawing back data from a removed member's phone.**
- **Readable cloud data** (clinic partners, Phase 3): a separate,
  in-region design after legal review.
- **Web or desktop clients.** The design doesn't rule them out (a browser
  would be one more device), but key storage there is not covered.
- **Post-quantum security** in v2.0 (section 18, Q6).

## 3. Actors and roles

| Actor | What it is |
| --- | --- |
| **Account** | A Supabase Auth user, signed in with a phone number + SMS code. Holds no health data. |
| **Device** | One install of the app signed in to one account. Has its own X25519 and Ed25519 key pairs in secure storage (Keystore / Keychain, this device only). |
| **Recovery device** | Not a phone: a key pair derived from the account's recovery key. Receives family keys like a phone; used only to enrol a new phone. |
| **Family** | A shared space of records. Has a family log, a family key per epoch, and members. A person using sync alone has a family of one. |
| **Member** | An account in a family, with one role. |
| **Profile** | A person the records are about (a child, a grandparent). A profile is a record, not an account; most profiles never sign in. |
| **Server** | Supabase: Auth, Postgres, Storage, Edge Functions. Trusted to run the service, not trusted with data. |

| Role | Read | Write records | Change membership | Notes |
| --- | --- | --- | --- | --- |
| `owner` | all | all | add, remove, change role, transfer ownership | One per family in v2.0 (section 18, Q8) |
| `guardian` | all | all | no | Parent, adult child caring for a parent |
| `cared_for` | all | Phase 2: only dose logs for the profile linked to them | no | An elderly parent with their own phone |
| `viewer` | all | no | no | A relative who follows along; the Phase 1 caregiver |

Any member may leave a family, manage their own devices, and rotate the
family key (rotation gives no new access; section 10).

## 4. What the server sees and doesn't

| The server sees | The server never sees |
| --- | --- |
| Phone numbers, account ids, country, locale | Profile names, birth dates, any health data |
| Devices: platform, app version, public keys, approval state, created / last seen times | Device names or models (not stored) |
| Push tokens; when it sends a push | Push content beyond "sync" or a fixed security alert text |
| Families, who is a member of which, roles, when they joined or left | The family's name (kept in an encrypted record) |
| The family log: member and device public keys, roles, key versions, signatures, times | Anything about records in the log |
| Per record: family id, record id (UUID v7, so its creation time), key version, a hybrid-clock time, server revision, padded ciphertext size, update and delete times | Record type, profile, field names or values, which device or person wrote it |
| Per attachment: blob id, number of chunks, padded size, upload time | File name, type, content, which record uses it |
| Wrapped family keys and who they are wrapped to | The family keys |
| Recovery: a salt, KDF settings and the recovery device's public keys | The recovery key |
| IP addresses and request times (gateway logs) | Request bodies (not logged) |

What a database dump reveals is therefore: who uses Usra, who shares a
family with whom, how many records and photos a family has and roughly how
big they are, and when they write. Section 13 reduces this where it is cheap;
section 14 lists what is left.

## 5. Building blocks

### Primitives

| Use | Primitive | Why |
| --- | --- | --- |
| Record and blob encryption | XChaCha20-Poly1305 (IETF), random 24-byte nonce | Already used for backups and photos; random nonces are safe at any volume |
| Key wrapping to a device | HPKE base mode, `DHKEM(X25519, HKDF-SHA256)`, `HKDF-SHA256`, `ChaCha20Poly1305` (RFC 9180 suite 0x0020/0x0001/0x0003) | Standard, has test vectors, uses the existing X25519 device key |
| Pairing bundle | HPKE **PSK** mode, same suite | The pairing secret from the QR authenticates the sender |
| Signatures | Ed25519 (RFC 8032), "pure" mode | Small, fast, deterministic |
| Hash, chain, commitments | SHA-256 | Available everywhere (Dart, Postgres, Deno) |
| Key derivation | HKDF-SHA256 (RFC 5869) | |
| Recovery key stretching | Argon2id, same cost as backups (19 MiB, 2 passes, 1 lane) | Already used; the key has ~100 bits, so stretching is a margin, not the defence |
| Randomness | `Random.secure()` only | Security plan rule |

### Encodings

- Signed objects (log entries, record bodies, approvals) are **UTF-8 JSON
  byte strings that are signed and stored as bytes**. A reader verifies the
  signature over the exact bytes and only then parses them. Nobody
  re-serialises before verifying, so no canonical-JSON scheme is needed.
  Binary values inside JSON are base64url without padding.
- Fixed headers (record AAD, HPKE `info`) are binary with fixed-width fields,
  so they can't be ambiguous.
- Ids are UUIDs as 16 raw bytes in binary headers and as lowercase strings in
  JSON.

### Domain separation

Every signature, HKDF output and HPKE `info` starts with its own label, so a
value made for one purpose can never be accepted for another:

| Label | Used for |
| --- | --- |
| `usra/v1/record-key` | HKDF info: family key → record key |
| `usra/v1/key-history` | HKDF info: family key → key that encrypts the previous epoch's key |
| `usra/v1/key-commit` | HKDF info: family key → public commitment in the log |
| `usra/v1/wrap` | HPKE info prefix for family key wraps |
| `usra/v1/pair` | HPKE info for the pairing bundle |
| `usra/v1/pair-sas` | Hash input for the 6-digit comparison code |
| `usra/v1/record-sig` | Signature over a record |
| `usra/v1/log-entry` | Signature over a family log entry |
| `usra/v1/approve-device` | Signature by the approving device, checked by the server |
| `usra/v1/bind-session` | Signature that binds an auth session to a device |
| `usra/v1/recovery/kx`, `usra/v1/recovery/sign` | HKDF info: recovery seed → recovery device keys |
| `usra/v1/invite-lookup`, `usra/v1/invite-mac` | Invite secret → lookup hash, MAC key |
| `usra/v1/blob` | AAD prefix for attachment chunks |

## 6. Keys

### Key list

| Key | Made by | Lives | Leaves the phone as |
| --- | --- | --- | --- |
| Device key exchange (X25519) `dkx` | Each device, per account (exists: `DeviceIdentityStore`) | Secure storage, this device only | Public key in `devices.public_key` and the family log |
| Device signing (Ed25519) `dsig` | Each device, per account (new) | Secure storage, this device only | Public key in `devices.signing_public_key` and the family log |
| Recovery key | The app, for backups (exists: `RecoveryKey`) | Paper; secure storage on the phone | Never |
| Recovery device keys `rkx`, `rsig` | Derived from the recovery key | Re-derived only when needed, wiped after | Public keys in `account_recovery` and the family log |
| Family key `FK_v` (256 bits, epoch v) | A member's device, at family creation and at each rotation | Secure storage, this device only, per family and epoch | Wrapped with HPKE to each device |
| Record key `RK_v` | `HKDF(FK_v, salt = family_id, info = "usra/v1/record-key")` | Memory only | Never |
| History key `HK_v` | `HKDF(FK_v, salt = family_id, info = "usra/v1/key-history")` | Memory only | Never |
| Key commitment `KC_v` | `HKDF(FK_v, salt = family_id, info = "usra/v1/key-commit")`, 32 bytes | Public, in the log | In the clear |
| File key `BK` (256 bits) | Per attachment, at upload | Inside the encrypted attachment record | Never in the clear |

Family keys are **not** put in the database file and are **not** included in
backups (security plan principle 4). A restored backup on a new phone holds
records but no family keys; the phone has to be enrolled (section 8) to sync.

### Why one key per family epoch, not one key per record

Per-record keys would only help if a member could be given some records and
not others, which v2.0 doesn't do (section 2). They would add a wrapped key
to every record and make rotation no cheaper: a removed member already knew
every record key of their time. Attachments are the exception: a file key
per attachment means a large file is encrypted once, never re-encrypted on
rotation, and could later be shared on its own (for example with a clinic)
by sharing one key.

### Epochs and key history

`key_version` is the epoch number, starting at 1. Each rotation (section 10)
creates `FK_{v+1}` and stores, on the server:

```
history[v+1] = XChaCha20-Poly1305(key = HK_{v+1}, nonce = random 24 bytes,
                                  aad = "usra/v1/key-history" || family_id || u32(v+1),
                                  plaintext = FK_v)
```

So a device holding the current key can walk back to every earlier key, and
a new member or a new phone only needs the current epoch wrapped to it to
read the family's whole history. A removed member keeps the epochs they
had and gets none of the later ones.

### Wraps

A wrap gives `FK_v` to one device (or the recovery device):

```
info = "usra/v1/wrap" || family_id (16) || u32(v) || recipient_device_id (16)
(enc, ct) = HPKE.SealBase(pkR = recipient dkx, info, aad = "", pt = FK_v)
wrap_sig  = Ed25519(sender dsig, "usra/v1/wrap" || info || enc || ct)
```

A recipient accepts a wrap only if:

1. the signature is by a device that the family log says was current when
   epoch v was created (or, for a re-wrap, is current now), and
2. `HKDF(FK_v, family_id, "usra/v1/key-commit")` equals `KC_v` in the log's
   `rotate_key` (or `genesis`) entry for epoch v.

Check 2 is what stops the server from wrapping a key of its own choosing:
without it a phone could be tricked into encrypting new records under a key
the server knows. HPKE base mode doesn't authenticate the sender, which is
why both checks are needed.

Only the current epoch is wrapped to new devices. Old epochs come from the
history chain.

### Recovery device

```
seed = Argon2id(password = the 36 recovery digits (ASCII),
                salt = account_recovery.salt (16 random bytes, stored on the server),
                m = 19 MiB, t = 2, p = 1, length = 32)
rkx  = X25519 private key from HKDF(seed, info = "usra/v1/recovery/kx")
rsig = Ed25519 seed from HKDF(seed, info = "usra/v1/recovery/sign")
```

The salt is separate from every backup file's salt, so the backup file keys
and the recovery device are unrelated outputs of the same paper key. The
recovery device is listed in the family log as a device of kind `recovery`,
so every rotation wraps the new key to it automatically; nothing has to be
"escrowed" again after a rotation.

If the person makes a **new recovery key** in the app, the phone revokes the
old recovery device, adds the new one, and rotates the family key (the old
paper might be the reason).

## 7. The family log (signed membership)

Membership, devices and key epochs are not trusted from the server's tables.
They come from an append-only, hash-chained log per family that every phone
replays and checks. The server's `family_members` and `devices` tables are
kept in step with the log (by the Edge Function that appends entries) and
are used only for row-level security, which is defence in depth.

### Entry format

```
entry_bytes = UTF-8 JSON {
  "v": 1,
  "family": "<family_id>",
  "seq": n,                         // 1 for genesis, then +1
  "prev": "<base64url hash of entry n-1>" | null,
  "type": "<one of the types below>",
  "by": "<device_id of the signer>",
  "at": <hybrid clock, section 12>,
  ... type-specific fields
}
sig  = Ed25519(dsig of "by", "usra/v1/log-entry" || entry_bytes)
hash = SHA-256(entry_bytes || sig)
```

A device record inside an entry is
`{ "id", "user", "kind": "phone" | "recovery", "kx": <32 bytes>, "sig": <32 bytes> }`.

### Entry types and who may write them

Authorisation is checked against the state after entry n-1.

| Type | Fields | Signed by |
| --- | --- | --- |
| `genesis` | creator user id, creator's devices (phone + recovery), `key_version: 1`, `KC_1` | A device of the creator, who becomes owner |
| `add_member` | user id, role (not owner), their devices, invite id, invite MAC (section 9) | The owner |
| `change_role` | user id, new role (not owner) | The owner |
| `transfer_owner` | user id (an existing member; the old owner becomes guardian) | The owner |
| `remove_member` | user id, reason `removed` / `left` / `account_deleted` / `reset` | `removed`: the owner; `left`: a device of that member; `account_deleted` and `reset`: any member, only when the server reports the account deleted or reset (shown in the family's activity) |
| `add_device` | user id, device | A current device of the same user, including their recovery device |
| `revoke_device` | user id, device id | A current device of the same user, or the owner |
| `rotate_key` | new `key_version`, `KC_{v+1}`, SHA-256 of the sorted recipient device ids | A current device of any active member |

Rules every phone checks while replaying:

- `seq` increases by one and `prev` matches; the signer is a current
  (non-revoked) device of an active member and is allowed to write that type.
- After any `remove_member` or `revoke_device`, no record may be written
  until a `rotate_key` follows (section 10). Any member's phone that is
  online performs the rotation.
- A `rotate_key`'s recipient hash must match the set of current devices of
  active members (phones and recovery devices) at that point.
- The owner can't remove themselves; they transfer ownership first.

### Anchors: how a phone knows it has the real log

- **New member:** the invite QR carries the family's genesis hash
  (section 9), so the server can't hand them a fake family.
- **New phone of an existing member:** the approving phone sends the current
  log head inside the authenticated pairing bundle (section 8).
- **Every phone** stores the highest `(seq, hash)` it has verified and
  rejects a log that is shorter or different at that point (rollback, fork).
- **Every record** carries, inside its signed body, the writer's log head
  `(seq, hash)`. A reader that finds a head that isn't on its own chain shows
  a "family security check failed" warning and stops syncing that family.
- **Safety code.** Family settings show a 12-digit code derived from the
  log hash at a given `seq`; two members can compare it in person (like
  Signal safety numbers) to detect a fork the server keeps apart.

### Appending

Phones append through the `append-family-log` Edge Function, which checks
the same rules (signature with WebCrypto Ed25519, authorisation, `seq`, `prev`)
and, in one transaction, inserts the entry and updates `family_members`,
`devices` and `families.current_key_version`. Two phones racing to append get
a unique-key conflict on `(family_id, seq)`; the loser refetches, re-checks
and retries. The server's checks only keep honest-server state tidy; the
phones' checks are the ones that matter.

## 8. Device enrolment and account safety

### Device states (server side)

`devices.status` is `pending`, `approved` or `revoked`. A device is created
`pending` when it registers its public keys after sign-in.

**Session binding.** After sign-in, the phone calls `bind-device` with
`Ed25519(dsig, "usra/v1/bind-session" || session_id || server_nonce)`. The
function checks the signature against the device's registered key and
stores `(session_id → device_id)` in `device_sessions`. Row-level security on
every sync table calls `private.device_ok()`, which is true only if the
JWT's `session_id` is bound to an **approved** device of `auth.uid()`. A
session that only proved an SMS code therefore reads and writes nothing in
`e2ee_records`, `family_log`, wraps or blobs.

**First device.** An account's very first device approves itself and
creates the person's family (genesis), adding its recovery device at the same
time. `accounts.sync_enrolled_at` is set then. From that moment on, **a new
device can never self-approve**, even if every device row is later deleted
(today sign-out deletes the device row; without this rule, signing out of the
last phone would let an SMS code alone start over).

Enabling sync requires a recovery key the person has written down: the app
asks them to type two of its groups back before turning sync on.

### Way 1: approve from an existing phone with a QR code (default)

1. New phone N signs in with SMS, makes its keys, registers as `pending`, and
   shows a QR code: `usra:pair:v1:` + base64url(`device_id_N || dkx_N ||
   dsig_N || s`), where `s` is 32 random bytes.
2. The person opens Settings → Devices → "Add a phone" on an approved phone
   E and scans it. E now has N's keys over the camera, which the server can't
   touch.
3. E signs an approval
   `Ed25519(dsig_E, "usra/v1/approve-device" || user_id || device_id_N || dkx_N || dsig_N)`
   and sends it to `approve-device`, which checks that the caller's session is
   bound to E, that E is approved and belongs to the same user, and that the
   signature verifies; then it sets N to `approved`.
4. For each family the person is in, E appends `add_device(N)` and wraps the
   current family key to N.
5. E sends N a **pairing bundle** with HPKE PSK mode
   (`psk = s`, `psk_id = "usra-pair-v1"`, `info = "usra/v1/pair"`): the list
   of families and each family's current log head. Only someone who saw the
   QR knows `s`, so N knows the bundle comes from the phone that scanned it.
6. N binds its session, downloads the logs, checks them against the heads
   in the bundle, unwraps the family keys, checks their commitments, and
   starts its first full sync.

### Way 2: approve with a comparison code (both phones at hand, QR can't be scanned)

A commit-then-reveal comparison, as in Bluetooth numeric comparison, relayed
through `pairing_sessions` (10-minute lifetime):

1. N posts its public keys and `C = SHA-256(n_N || dkx_N || dsig_N)` with a
   random 32-byte `n_N`.
2. E (notified by push) fetches them and posts its own device id and random
   `n_E`.
3. N reveals `n_N`; E checks it against `C`.
4. Both show `SAS = first 32 bits of SHA-256("usra/v1/pair-sas" || dkx_N ||
   dsig_N || dkx_E || dsig_E || n_N || n_E)` mod 10^6, as 6 digits. The person
   taps "They match" on **both** phones.
5. Then steps 3–6 of way 1, with the bundle sealed in HPKE base mode to N
   and signed by `dsig_E` (whose key N now trusts through the code).

Because N committed before seeing `n_E`, a server in the middle gets one
guess in a million per attempt. A pairing session dies after one mismatch,
and an account gets at most 3 sessions per hour.

The screen must say: "Only approve a phone that is in your hand right now.
Usra will never call you or message you to ask for this code." A caller who
talks someone into approving is still a risk (section 14).

### Way 3: the recovery key

1. N signs in with SMS, registers as `pending`, and the person types the
   recovery key (checked locally with its check digits first).
2. N fetches `account_recovery.salt` and KDF settings (allowed for a pending
   device; 5 tries per account per day), derives the recovery device keys, and
   proves them by signing a server challenge with `rsig`. `recover-device`
   checks the signature against `account_recovery.recovery_signing_public_key`
   and approves N.
3. N, acting as the recovery device, appends `add_device(N)` to each family
   log (signed with `rsig`), unwraps each family key from the recovery
   device's wrap, re-wraps it to itself, and wipes `rkx`/`rsig` from memory.
4. Every other device of the account and the family owner are notified.

### Account reset (lost every phone and the recovery key)

Signing in with SMS on an account that has no approved device left (or whose
person says they lost them) offers **account reset**:

- It takes **7 days**. During that time every approved device of the account
  gets a push and an in-app banner with "This isn't me" (cancels the reset,
  needs an approved device).
- After 7 days the server revokes all of the account's devices and recovery
  device, marks its memberships `reset`, and sets `families.rotation_pending`.
  The new phone becomes the account's first device again, with a new
  recovery key, but it is **not** in any family.
- Other members see "Mona reset her account". The first of their phones
  online appends `remove_member` with reason `reset` and rotates the key; the
  owner can then re-invite her (section 9), and the key history gives her
  the family's full history again.
- If the person who reset was the family's only owner, see section 11.

A SIM-swapper can start a reset, but the real person is warned on every
phone for a week and can cancel it.

### What an SMS code alone can do

| Action | With SMS only (pending device) | Needs an approved device |
| --- | --- | --- |
| Read or write records, logs, wraps, blobs | no | yes |
| Register a pending device, push token | yes | |
| Try the recovery key | yes (rate-limited) | |
| Start an account reset (7-day wait) | yes | cancel it |
| Delete or revoke **other** devices | no | yes |
| Leave a family, accept an invite | no | yes |
| Delete the account | no (change to `delete-account`, B10) | yes |
| Change country or locale | yes (harmless) | |

### Notifications

Every approved device of the account gets a push with fixed text (no names,
no health data) when: a phone asks to join; a phone is approved or revoked;
the recovery key is used; an account reset starts. Family members see quieter
activity entries ("Ahmed added a phone", "the family key was renewed"). The
Devices screen lists every device with platform and the date it was added, and
"Remove" on each.

## 9. Joining a family

The existing invite table and `accept_family_invite` stay, with one change:
the server must never see the invite secret.

1. The owner's phone makes `invite_secret` (32 random bytes) and stores
   `code_hash = hex(SHA-256("usra/v1/invite-lookup" || invite_secret))` in
   `family_invites`. The QR (or link) carries `invite_id`, `invite_secret`,
   the family id and the family's **genesis hash**.
2. The invitee, on an approved device, calls `accept_family_invite` with the
   **lookup hash**, not the secret (today the function takes the code and
   hashes it on the server; B9 changes this). The server records them as a
   **pending** member (`family_members.status = 'pending'`); RLS gives pending
   members nothing.
3. The invitee's phone posts its user id and device public keys (phones
   and recovery device) with
   `mac = HMAC-SHA256(HKDF(invite_secret, info = "usra/v1/invite-mac"), user_id || devices)`.
4. When the owner's phone is next online it checks the MAC, appends
   `add_member` (with the MAC, so the entry shows it was earned with that
   invite), wraps the current family key to the invitee's devices, and the
   server marks the member active.
5. The invitee's phone downloads the log, checks that `seq 1` hashes to the
   genesis hash from the QR, replays it, unwraps the key, and syncs.

A leaked invite link can be used once and only until it expires (7 days);
the owner sees who joined before anything is shared and can cancel. The app
should show the invitee's phone number (from the server, for the owner to
recognise) and ask "Is this Mona?" before step 4.

## 10. Removing members and devices, key rotation

### When the key rotates

- A member is removed, leaves, deletes their account, or resets it.
- A device or recovery device is revoked (lost phone, sign-out, new
  recovery key).
- By hand: "Renew family key" in family settings (suspected compromise).

The app keeps the recovery key in the phone's secure storage (for backups),
so **removing a lost or stolen phone also replaces the recovery key**: the
remaining phone shows a new one to write down, revokes the old recovery
device and adds the new one in the same rotation. If the last phone is the
one lost, the person does this right after recovering with the old key.

Not on: adding a member or device (they get the current key; history is
theirs anyway once they are in, by design).

### How

Any active member's phone that sees a pending rotation (a `remove_member` or
`revoke_device` not yet followed by `rotate_key`, or
`families.rotation_pending`) does it before its next record write:

1. Make `FK_{v+1}`; compute `KC_{v+1}` and `history[v+1]`.
2. Wrap `FK_{v+1}` to every current device of every active member, including
   recovery devices.
3. Call `rotate_family_key` with the `rotate_key` log entry, the history
   blob and all wraps; the server stores them in one transaction and sets
   `families.current_key_version = v+1`.

From then on the server rejects record writes with an older `key_version`
(honest-server check), and phones never encrypt with anything but the
current epoch (the real check). Old records are **not** re-encrypted: they
are re-encrypted only when someone next edits them. Re-encrypting everything
would not take back what the removed member could already read.

Revoked devices lose access on the server at once (RLS) and their wraps are
deleted. A revoked phone that comes online finds its session refused and
**wipes the family's synced data and keys** from itself (best effort: only an
honest, unmodified app does this).

### What a removed member keeps

- Everything their phone had synced and decrypted before the removal, in
  their local database (encrypted on their phone, readable by them).
- The family keys of the epochs they were in. With those they could read the
  family's older ciphertext if they ever got hold of it (for example from a
  server breach). They cannot read anything written under a later epoch.
- They lose server access at once, so they can't download anything new.

The app tells the owner this when they remove someone.

## 11. Recovery

| Situation | What happens |
| --- | --- |
| New phone, old phone at hand | Way 1 (QR). Full access in a minute. |
| New phone, old phone at hand but the QR won't scan (broken camera) | Way 2 (comparison code). |
| New phone, old phone elsewhere | Way 3 (recovery key), or wait until both phones are together. Never way 2 over the phone: reading the code to someone is exactly what an attacker asks for. |
| Lost every phone, has the recovery key | Way 3. Full access, including every family's history. Lost phones are then revoked from the new one. |
| Lost every phone and the recovery key, others in the family, not the owner | Account reset (7 days) and the owner re-invites. Full history comes back with the key history. |
| Lost every phone and the recovery key, was the only owner of a family with other members | Account reset. The family is frozen: members keep reading what is synced and nobody can change membership. In v2.0 a guardian can start a new family and copy the records across on their phone (re-encrypted under the new family). Section 18, Q8 proposes co-owners to avoid this. |
| Lost every phone and the recovery key, alone | The synced data is gone for good: nobody, including us, can decrypt it. Account reset deletes the ciphertext. A local backup file needs the same recovery key. The app says this when sync is turned on. |
| Restored a backup file on a new phone | Records come back locally; to sync, the phone is enrolled (way 1–3) and does a full sync, merging by the per-field clocks the backup carries (section 12). |

## 12. Sync protocol

### Units

Every row of a synced local table (`profiles`, `medical_events`, `doctors`,
`insurance_cards`, `attachments`, `medicines`, `dose_schedules`, `dose_logs`,
and later tables) is one record, with its existing UUID v7 id as
`record_id`. Each column is a field. `medical_events.data_json` is merged
by its top-level keys, each as a field.

### Hybrid logical clock (HLC)

A 64-bit value: 48 bits of Unix milliseconds and a 16-bit counter.
Each phone keeps `hlc_last`. On a local write:
`hlc = max(hlc_last + 1, now_ms << 16)`; on reading a remote record with clock
`r`: `hlc_last = max(hlc_last, r)`, but a remote clock more than 10 minutes
ahead of the server's `Date` header (as seen by this phone) does not move
`hlc_last` (a phone with a wrong clock can't drag everyone into the future).
Phones whose own clock differs from the server's by more than 10 minutes use
the server-corrected time and show a gentle "your phone's time is wrong"
note.

### Record envelope

```
header (AAD, 49 bytes, also stored as columns):
  "USR1" | u8 format = 1 | family_id (16) | record_id (16) | u32 key_version | u64 hlc

body (UTF-8 JSON, signed):
{
  "t": "medicine",                     // record type: only inside the ciphertext
  "by": "<device_id>",
  "log": { "seq": 42, "h": "<log head hash>" },
  "f": {                               // fields: [value, hlc]
    "name": ["Panadol 500", 1730800000000123],
    "profile_id": ["018f…", 1730700000000001],
    "_deleted": [false, 1730700000000001]
  }
}

plaintext = sig (64) | u32 body_length | body | zero padding
sig       = Ed25519(dsig, "usra/v1/record-sig" || header || body)
stored    = nonce (24) | XChaCha20-Poly1305(RK_v, nonce, aad = header, plaintext)
```

Padding: the plaintext is padded to the next power of two, at least 256
bytes and at most 64 KiB. The server checks that `octet_length(ciphertext) − 40`
is one of those sizes, so a buggy client can't leak exact sizes. Anything
bigger than 64 KiB goes into an attachment blob.

The header binds the ciphertext to its family, record, epoch and clock, so
the server can't move a record to another id or family or replay it under
another clock. The signature is inside the encryption, so the server doesn't
learn who wrote what. A reader rejects a record unless: the AEAD opens; the
signature verifies with the `dsig` of `by`; `by` was a current device of a
member whose role may write this record type at log head `log`; `log` is
on the reader's chain; and `key_version` is the epoch in force at `log`.

### Merge

Per field, the value with the higher `hlc` wins; on equal `hlc`, the value
whose JSON encoding is larger (bytewise) wins. This is commutative,
associative and idempotent, so every phone reaches the same state whatever
order changes arrive in. The record's header `hlc` is the largest field
`hlc`. Replaying an older version changes nothing.

Dose logs and other history rows are written once and never edited, so they
never conflict.

### Deletes and tombstones

Deleting sets `_deleted = true` with a new `hlc` and **drops every other
field's value** before upload (the tombstone body keeps only `_deleted`).
Once `_deleted` is true, writers drop any other field values that arrive
from a concurrent edit; the record stays deleted unless someone restores it
from their phone's local trash (`_deleted = false` with a newer `hlc` and the
values). The writer also sets the row's `deleted_at` as a plain hint for the
server's cleanup below, but readers trust only the signed `_deleted` field: a row with
`deleted_at` and no valid signed tombstone is treated as tampering, not a
delete.

Tombstones are kept on the server for 1 year, then the row is removed. A
phone that has not synced for more than a year does a **full resync**: it
lists every live record id, and for records it has locally that are neither
on the server nor newer than a year it asks the person whether to upload or
remove them.

### Push

The outbox (`OutboxEntries`, already in the schema) holds which rows changed.
The sync worker, for each family:

1. Takes up to 100 changed records (at most 2 MiB), builds each one's merged
   body from local values and per-field clocks, signs, pads and encrypts it.
2. Calls `push_e2ee_records(family_id, [{record_id, key_version, hlc,
   ciphertext, expected_revision}])`. The function, for each record, checks
   `device_ok()`, role, `key_version = current_key_version`, the padded size,
   and that the `hlc` wall time is not more than 10 minutes in the future
   (honest-server sanity check; old clocks are normal for offline edits), then
   writes only if the stored `revision` equals `expected_revision` (0 for a
   new record) and bumps `revision`.
3. Records that fail with `revision_conflict` come back with the current row;
   the worker merges and retries (at most 5 times, then it backs off).
   `stale_key` makes the worker fetch the new wraps and retry.
4. Outbox entries are removed only after the server confirms.

Compare-and-set makes sure a write never overwrites a version the writer
hasn't merged; the HLC merge decides what the merged values are.

### Pull

The existing `pull_e2ee_changes(family, after_txid, after_record, limit)`
stays: commit-safe paging by transaction id (500 per page, at most 1000), so
a slow transaction can never land behind a cursor. A pull returns
`revision`, `key_version`, `hlc`, `ciphertext`, `deleted_at`. The phone
verifies, merges into the local tables in one transaction, updates its local
clocks and stores the cursor. The family log (`seq > n`) and wraps for this
device are pulled first, so new epochs are known before records using them.

New phones and full resyncs page through everything; the first sync of a big
family is resumable by the same cursor.

A data-only push ("sync", collapse key per family, at most one per minute per
family) tells other phones to pull. No push contains ids or content.

### Attachments

- An attachment's file is encrypted with its own random `BK` in chunks of 256
  KiB, like the backup format: the 24-byte nonce is a 16-byte random prefix,
  a u32 chunk number and a u32 last-chunk flag; AAD =
  `"usra/v1/blob" || family_id || blob_id || u32 chunk_count`. Reordering,
  dropping, truncating or swapping chunks fails.
- The file is padded with Padmé (leaks at most O(log log n) bits of its size)
  before chunking; at most 25 MiB per file in v2.0.
- Chunks go to the private Storage bucket `e2ee-blobs` at
  `<family_id>/<blob_id>/<chunk>` with a random UUID v4 `blob_id`; RLS on
  `storage.objects` uses the same membership and `device_ok()` checks.
- The `attachments` record holds, inside its ciphertext: `blob_id`, `BK`,
  chunk count, plaintext length, SHA-256 of the plaintext, media type, and the
  same for a small encrypted thumbnail. The server can't tell which record uses
  which blob.
- Upload the blob first, then the record; a reader that finds the record
  before the blob retries later. Deleting an attachment record deletes its
  blob objects (by the deleting phone). A weekly job on the owner's phone
  removes blobs no live record mentions. Deleting a family or account must
  delete its Storage objects explicitly: they are not covered by `on delete
  cascade` (B8).
- Photos are downloaded on demand (when opened), not with the first sync, to
  save data on budget plans; insurance cards and emergency-card photos are
  fetched eagerly.

### Size and rate limits

| Limit | Value (v2.0) |
| --- | --- |
| Record ciphertext | 256 B – 64 KiB plaintext, power of two, + 40 B |
| Push batch | 100 records, 2 MiB |
| Pull page | 500 (max 1000) |
| Attachment | 25 MiB padded; chunk 256 KiB |
| Family storage | Free and Plus quotas: product decision (section 18, Q11) |
| Record writes | 60 requests/min per device; 20,000 records/day per family |
| Blob upload | 1 GiB/day per family |
| Pairing sessions | 3/hour per account; one comparison try each |
| Recovery tries | 5/day per account, each notified |
| Invites | 20/day per family; 10 accept tries/hour per user |
| Log appends | 60/hour per family |

All limits live in the shared store from S17 (not the per-instance limiter).

### Offline

Everything works without a network: writes go to the local tables and the
outbox with a new HLC. When the phone comes back:

- it pulls the log first; if it was revoked, it wipes the family's data;
- if the family key rotated, it unwraps the new epoch; outbox records are
  encrypted only at push time, so they go up under the new epoch;
- it pulls, merges, and pushes with compare-and-set.

Weeks offline are fine; more than a year means a full resync (tombstones).

### Local schema notes (app, not part of this PR)

- `sync_records(entity, entity_id, family_id, revision, field_hlcs JSON,
  dirty)`: per-field clocks and the last server revision. Included in backups
  (not secret), so a restored phone merges correctly.
- `sync_cursors(family_id, after_txid, after_record)`: not in backups.
- `family_log_entries(family_id, seq, hash, entry_bytes, sig)`: verified log.
- `hlc_state`: `hlc_last`.
- Family keys and the device signing key: secure storage, this device only,
  under `usra.account.<userId>.` so the existing sign-out and first-run wipes
  remove them.
- Each profile belongs to at most one family; the app keeps unsynced
  profiles (sync off) out of every family.

## 13. Metadata, logging and server backups

### Less metadata

- No record type, profile, name or field name outside the ciphertext.
- Records padded to powers of two; files padded with Padmé.
- The family's display name and member display names are encrypted records
  ("family_info", "member_info"), not server columns.
- No device names; only platform and app version.
- Blob ids are random v4 UUIDs; record ids remain UUID v7 (they already
  are) and so reveal when a record was created, not when the event happened.
- **Write timing.** Dose logs uploaded the moment "Taken" is tapped would
  show the server a medicine schedule. Dose logs and other routine writes
  should be uploaded in batches at jittered times (for example the next sync
  window after 10–40 minutes), except when caregiver alerts (Phase 2) need
  them sooner. Section 18, Q10.
- Push messages are data-only "sync" with a family-level collapse key, rate
  limited, so Google sees little more than "this phone uses Usra".

### Logging rules (server)

- Never log request or response bodies, ciphertext, wraps, signatures,
  public keys, invite codes or hashes, phone numbers, or OTPs.
- Edge Functions log a request id, function name, outcome code and timing.
  User and family ids only where needed to debug, and only in logs kept 14
  days or less.
- Postgres: `log_statement = 'none'`, `log_parameter_max_length = 0` and
  `log_parameter_max_length_on_error = 0` so bound values (ciphertext, ids) are
  never written to the server log; `pg_stat_statements` only stores
  normalised queries.
- Gateway (Kong / Cloudflare) access logs: path and status, no query
  strings with ids; kept ≤ 30 days.
- No third-party log or error service receives anything from sync
  endpoints.

### Server database backups

- Daily backups and point-in-time recovery hold ciphertext, wraps and
  metadata. They are as unreadable as the live database but expose the same
  metadata, so: encrypted at rest (S17), access limited to two named admins
  with MFA, retention ≤ 30 days.
- Deleted rows (account deletion, removed families) live on in backups until
  they age out. The privacy policy must say "deleted within 30 days from
  backups".
- A restore from backup is a **rollback** from the phones' point of view: they
  will see revisions and log heads older than their own. Restores must be
  followed by the phones re-pushing (the outbox is kept until confirmed; a
  phone that sees the server behind its log head re-uploads its own log
  entries and records). The incident runbook (S23) must cover this.

## 14. Threat model

| Threat | Example | Mitigations | What is left |
| --- | --- | --- | --- |
| **Server breach** (database dump, stolen backup) | An attacker copies Postgres and Storage | Only ciphertext, wraps and public keys stored; record and file keys never leave phones unwrapped; recovery key is ~100 bits behind Argon2id; padding; no names or types | Metadata (section 4): phone numbers, who shares a family, record counts and times. Breach notice duties still apply (S23). Harvest-now-decrypt-later if X25519 is broken some day (Q6) |
| **Malicious server or insider** (actively lies) | Serves fake records, fake members, its own key | AEAD with keys the server lacks; records and log signed; key commitments in the log; anchors (QR genesis hash, pairing bundle); phones check roles themselves | It can refuse service, delete data, withhold new records, or show one member an older version of a record they haven't seen yet. A fork (different logs to different members) is caught when a record or safety code crosses the fork, not before |
| **Key substitution at enrolment** | Server swaps the new phone's public key | QR carries keys directly; comparison code with commitment; signed approvals | Person approves without comparing (UI must make comparing the only path) |
| **SIM swap / OTP phishing** | Attacker gets the SMS code | Pending devices can read and write nothing; approval only from a phone, comparison code, or recovery key; `sync_enrolled_at` stops self-approval; pushes to every phone; account delete and device removal need an approved device; reset takes 7 days and can be cancelled | Attacker with SMS **and** the paper recovery key gets everything. Social engineering ("read me the code") — mitigated by UI text only |
| **Stolen or lost phone** | Thief has the phone | DB and photos encrypted, app lock (S2), keys in Keystore / Keychain; remove the phone from another phone → revoke, rotate, new recovery key (the phone stored the old one), server access ends; the phone wipes family data if it reconnects | Whatever the thief can read on an unlocked phone before revocation. Remote wipe only works if the phone goes online with the honest app |
| **Rogue member** | A relative copies data or vandalises it | Roles: viewers and cared-for can't write (signatures + server RLS); removal rotates the key; activity shows who added members and devices | Every member reads everything (by design). A guardian can overwrite or delete records (the server keeps only the latest version; Q7 proposes version history). A removed member keeps what they had, and with the server's help could still inject an edit backdated to before their removal (signed under an old log head and epoch) |
| **Replay** | Server or network replays an old version or request | TLS; per-field HLC merge ignores older versions; header binds record id, family, epoch and clock; wrap `info` binds family, epoch and device; log `seq`/`prev`; single-use server nonces for session binding and recovery; pairing sessions single-use with 10-minute life | — |
| **Rollback** | Server returns an older log or older records, or is restored from backup | Phones keep their highest verified log head and refuse anything shorter or different; records merge by HLC so old versions don't win | A phone that never saw a newer version can be shown an older one. A brand-new phone trusts the head its approver gave it |
| **Fork** | Server keeps two members on different membership histories | Writer's log head inside every signed record; safety code comparison; append races resolved by unique `(family_id, seq)` on an honest server | Undetected until views cross |
| **Cut-and-paste** | Server moves a ciphertext to another record or family | Family id, record id, key version and clock in the AAD and the signature | — |
| **Forged deletes** | Server sets `deleted_at` or drops ciphertext | Readers only honour signed tombstones | Server can still drop rows outright (a denial of service, visible as missing records) |
| **Account reset abuse** | Attacker resets the real person's account | 7-day wait, push and banner on every phone, cancel from any phone | Someone who has lost access to all their phones can't cancel |
| **Weak clocks** | Phone clock set far ahead to make edits win | Remote clocks over 10 min ahead don't move local clocks; server refuses writes with clocks over 10 min in the future | A rogue writer with a correct-looking clock still wins LWW against older edits (normal) |
| **Malicious invite** | Attacker sends a link to a fake "family" | Invite carries the genesis hash; the app shows the inviter's family and phone number before joining | A person who joins the wrong family on purpose |
| **Coercion inside a family** | A cared-for adult pressured to share | Leaving a family is always possible (needs only their own phone); the app explains that everyone in a family sees everything | Per-profile privacy is a non-goal in v2.0 (Q9) |
| **Push and network observers** | Google (FCM), mobile operator | Data-only pushes without content; TLS; batched writes | Timing of app use |
| **Side channels on the phone** | Timing attacks on pure-Dart crypto | Attacks need code on the phone, which already defeats us (non-goal) | Pure-Dart implementations are not guaranteed constant-time (Q2) |

## 15. Libraries

**App (Dart).** Keep the `cryptography` package (already a dependency, used
for backups, photos and the device key). It has X25519, Ed25519,
XChaCha20-Poly1305, ChaCha20-Poly1305, HKDF, SHA-256, HMAC and Argon2id in
pure Dart, plus `cryptography_flutter` for platform-accelerated ciphers where
available. HPKE is not in the package; we implement RFC 9180 base and PSK
mode for the one suite we use (about 150 lines on top of the package's
primitives) and gate it on the RFC 9180 test vectors for that suite.

All sync crypto sits behind one interface in `app/lib/core/crypto/` so it
can be swapped for **libsodium** (through `sodium_libs`, which ships
prebuilt libsodium for Android and iOS) without touching sync code.
libsodium would give constant-time code and audited `crypto_sign`,
`crypto_aead_xchacha20poly1305_ietf` and `crypto_secretstream`, at the cost of
a native dependency (APK size, another supply-chain entry). Recommendation:
start with `cryptography` for consistency with the existing backup and photo
code and measured speed on a budget phone, and let the reviewer decide (Q2).

Performance targets on a Galaxy A0x-class phone: record encrypt + sign under
2 ms; first sync of 5,000 records under 60 s; Argon2id (19 MiB) once per
recovery, about a second. These are measured in Phase 0 before any UI.

**Server (Deno Edge Functions).** WebCrypto `Ed25519` verify (supported in
Deno) for `approve-device`, `bind-device`, `recover-device` and
`append-family-log`; `crypto.subtle.digest('SHA-256')`. No decryption ever
happens on the server, so no AEAD or HPKE code is deployed there.

## 16. Test plan

**Known-answer tests (must pass in CI before any sync code merges).**

- RFC 9180 test vectors for `DHKEM(X25519, HKDF-SHA256), HKDF-SHA256,
  ChaCha20Poly1305`, base and PSK modes.
- RFC 8032 Ed25519 vectors; RFC 7748 X25519 vectors; XChaCha20-Poly1305
  vectors from draft-irtf-cfrg-xchacha; RFC 5869 HKDF vectors.
- **Usra vectors**: fixed keys, nonces and inputs → exact bytes for a wrap,
  a record envelope, a tombstone, a log entry and chain hash, a key history
  blob, an attachment with 3 chunks, the recovery device keys from a fixed
  recovery key and salt, a comparison code. Stored as JSON in
  `app/test/crypto/vectors/` and **checked by a second implementation**
  (a small Python script using PyNaCl and `cryptography`, in `tools/`), so a
  bug in our Dart code can't also be in the expected values.

**Property tests (Dart, random seeds, thousands of runs).**

- Merge is commutative, associative and idempotent; N phones applying the
  same set of changes in any order and with any duplicates end identical.
- Replaying any older version never changes state.
- A delete plus concurrent edits ends deleted unless a newer restore exists.
- Flipping any bit of a header, nonce, ciphertext, signature, wrap or log
  entry makes it rejected.
- Log replay: random valid histories are accepted; forks, gaps, wrong
  `prev`, unauthorised authors (viewer adds member, device of another user
  revokes, guardian changes a role) and missing rotations are rejected.
- After removing a member at a random point, nothing written later decrypts
  with any key that member held.

**Database tests (pgTAP).**

- A session not bound to an approved device reads and writes nothing in every
  sync table and the blob bucket, even as the family owner.
- Viewers and cared-for can't write records (Phase 1: only the owner can);
  pending and removed members read nothing; revoked devices lose access.
- `push_e2ee_records`: compare-and-set, stale key, size buckets, clock bounds.
- `accept_family_invite` only with the lookup hash; one use; expiry.
- `delete-account` and device removal refused for SMS-only sessions.
- Family or account deletion removes Storage objects.

**Integration.**

- Two emulators and the local Supabase stack: enrol by QR (with a scripted
  camera) and by comparison code; edit the same record offline on both;
  remove a member; rotate; check the removed member's app can't read new
  records; restore a server backup and check phones re-push.
- Fuzzing of envelope and log parsers (malformed JSON, huge lengths).
- A budget-phone benchmark run before Phase 1.

**Review.** External cryptography review of this design (questions in
section 18) before Phase 1 code, and of the implementation before Phase 1
reaches users; included in the S22 pen test scope.

## 17. Phased rollout

| Phase | Who can do what | Gate |
| --- | --- | --- |
| **0. Foundations** (no user-visible change) | Crypto core, vectors, backend tables and functions (B1–B13) behind a server flag; internal builds only | This design reviewed; test vectors pass; benchmark on a budget phone |
| **1. Caregiver view (read-only)** | The owner's phones write (multi-device for the owner); everyone else joins as a read-only member (viewer). Records and attachments sync; phones sync down. Feature flag, closed beta in Egypt first | External review answered; implementation reviewed; legal gate for health data on the server (S25); privacy policy and data safety form updated |
| **2. Shared care** | Guardians write (per-field merge); cared-for writes dose logs for their own profile; caregiver alerts when a dose is missed | Phase 1 has run a month with no integrity warnings; version history decision (Q7) |
| **3. Later** | Per-profile private scopes (Q9), co-owners (Q8), post-quantum wraps (Q6), web view | Separate design notes |

Phase 1 limits risk: one writer account means few conflicts, and a bug in
merge or signatures can only lose the owner's own recent edits, which are
still on the owner's phone.

Kill switch: a server flag stops all sync pushes and pulls without touching
local data; turning sync off on a phone keeps its records.

## 18. Open questions for the external reviewer

1. **HPKE in pure Dart.** Is a small RFC 9180 implementation on
   `cryptography`, gated by the RFC vectors, acceptable, or should wraps use
   libsodium `crypto_box_seal` (with our own sender signature) instead?
2. **Pure Dart vs libsodium.** Is the lack of constant-time guarantees in
   pure-Dart X25519 / Ed25519 / Poly1305 acceptable for a phone app whose
   threat model excludes local code execution?
3. **Key commitment.** XChaCha20-Poly1305 isn't key-committing. We rely on
   the inner Ed25519 signature and on keys being random (no partitioning
   oracle). Is a committing construction (e.g. adding an HMAC of the key over
   the header) worth it?
4. **Signing inside the encryption.** Sign-then-encrypt hides authorship from
   the server. Is binding the header into both the AAD and the signature
   enough to prevent surreptitious forwarding between families (a member of
   two families re-encrypting a signed body for the other)?
5. **Recovery device from a 100-bit key** with Argon2id at 19 MiB and a
   server-held salt. Enough, given the salt and public keys are exposed in a
   breach? Should the recovery device keys use a higher Argon2 cost than
   backups?
6. **Post-quantum.** Wraps sit on the server for years (harvest now, decrypt
   later). Should v2.0 already use a hybrid KEM (X25519 + ML-KEM-768, e.g.
   X-Wing in HPKE) for wraps, given Dart library maturity? Records are
   symmetric and need no change.
7. **Version history.** Should the server keep the last few ciphertext
   versions of each record (for undoing a rogue guardian or a sync bug), and
   for how long, given it adds metadata?
8. **Co-owners.** Allow two owners per family (both may change membership)
   to avoid frozen families? What should the log rules be when owners
   disagree (concurrent remove of each other)?
9. **Private scopes.** Per-profile keys (a scope key wrapped to the members
   allowed to see one profile), for example for a cared-for adult's private
   records. Does the epoch / history / commitment design extend cleanly?
10. **Timing metadata.** How much batching and jitter for dose-log uploads is
    enough to hide medicine schedules, and is it worth the delay for caregiver
    alerts?
11. **Quotas.** Family storage quota (free vs Plus) and per-file size limits:
    product decisions that affect padding cost.
12. **Fork detection.** Is the writer's log head inside records, plus a manual
    safety code, enough, or should phones also gossip signed log heads to each
    other through the server on every sync?
13. **Account reset delay.** Is 7 days right for the region (people
    sometimes change SIM cards and phones at the same time)?
14. **The server checks.** Are there server-side checks here that create a
    false sense of security, or that a reviewer would expect and are missing?

## 19. Changes to earlier notes

| Earlier note | Now | Why |
| --- | --- | --- |
| Records encrypted with the family key using AES-256-GCM (technical design, `20261102000003_e2ee_records.sql` comment, backend README) | XChaCha20-Poly1305 with a key derived from the family key | Random 24-byte nonces have no message-count limit for a long-lived shared key; same AEAD as backups and photos |
| Conflicts: last writer wins per record by server time | Per-field LWW by hybrid logical clocks inside the signed ciphertext, plus compare-and-set on a server revision | Server time would let a malicious server pick winners; per-record LWW loses concurrent edits to different fields |
| `e2ee_records.ciphertext` up to 2 MiB | Up to 64 KiB, power-of-two padded; larger data in encrypted Storage blobs | Size metadata; photos don't belong in rows |
| `accept_family_invite(p_code)` sends the code | Sends a lookup hash; the secret proves the invitee to the owner's phone | The server must not be able to join with an invite it relays |
| Any member's session can read ciphertext; members delete their own devices freely | Only sessions bound to approved devices; removing other devices needs an approved device | OTP alone must never give data access |
| Membership only in `family_members` | Signed family log is the source of truth; tables mirror it | The server must not be able to add members |
| "Removing a member rotates the key" | Removing members or devices, leaving, account deletion or reset, and a new recovery key all rotate; any member can rotate | Covers lost phones and members who can't be reached |

`docs/security.md` S14 points here. The backend README and the migration
comments are updated by the backend follow-ups when the schema changes land.

## 20. Backend follow-ups (board cards)

Each item gets pgTAP tests (another user and an SMS-only session can't read or
write) per the security plan's PR rules. SQL below is a sketch, not a
migration.

| # | Change | Card |
| --- | --- | --- |
| B1 | `devices`: add `signing_public_key bytea` (32 bytes), `status` (`pending` / `approved` / `revoked`), `approved_at`, `approved_by_device`, `revoked_at`; status changes only through functions; delete only of the session's own device, or of others from an approved device; with sync on, sign-out revokes instead of deleting; `accounts.sync_enrolled_at` | Sync backend: device approval and session binding |
| B2 | `device_sessions(session_id, device_id, user_id, bound_at)`; `bind-device` function (Ed25519 challenge); `private.device_ok()`; unbind on sign-out | Sync backend: device approval and session binding |
| B3 | `approve-device` and `recover-device` functions; `account_recovery(user_id, salt, kdf, recovery_kx_public_key, recovery_signing_public_key)`; `account_resets` with a 7-day `pg_cron` job and cancel | Sync backend: device approval and session binding |
| B4 | `pairing_sessions` relay for the comparison code (commit, reveal, 10-minute TTL, one try, cleanup job) | Sync backend: device approval and session binding |
| B5 | `family_log(family_id, seq, prev_hash, entry bytea, sig bytea, hash, created_at)` with unique `(family_id, seq)`; `append-family-log` function that verifies and mirrors into `family_members` / `devices`; drop the direct `update (role)` grant; `family_members.status` (`pending` / `active` / `reset`); ownership transfer; leave family through the log; lifts the `409 family_has_members` guard once hand-over exists | Sync backend: signed family log, invites and key wraps |
| B6 | `family_key_wraps(family_id, key_version, recipient_device_id, enc, ct, sender_device_id, sig)`; `family_key_history(family_id, key_version, ciphertext)`; `families.current_key_version`, `families.rotation_pending`; `rotate_family_key` RPC (one transaction); delete wraps of revoked devices | Sync backend: signed family log, invites and key wraps |
| B7 | `e2ee_records`: add `revision bigint`, `hlc bigint`, `format smallint`; size check (power of two + 40, ≤ 64 KiB + 40); `push_e2ee_records` batch RPC with compare-and-set, stale-key and clock checks; `pull_e2ee_changes` returns `revision` and `hlc`; RLS through `device_ok()` and role (Phase 1: owner only writes); tombstone purge after 1 year | Sync backend: encrypted record push/pull and limits |
| B8 | Storage bucket `e2ee-blobs` (private), RLS on `storage.objects` by path family id + `device_ok()`; size limit; quota per family; delete objects when a family or account is deleted | Sync backend: encrypted attachment storage |
| B9 | `accept_family_invite` takes the lookup hash; invitee key + MAC upload; pending until `add_member` | Sync backend: signed family log, invites and key wraps |
| B10 | `delete-account`, leaving a family and removing other devices require an approved-device session | Sync backend: account takeover protections and notifications |
| B11 | `notify` function: FCM data pushes for sync tickles (rate-limited, collapse key) and fixed-text security alerts (new device, approval, recovery used, reset started) | Sync backend: account takeover protections and notifications |
| B12 | Rate limits in a shared store for every sync endpoint, pairing, recovery, invites (with S17) | Sync backend: encrypted record push/pull and limits |
| B13 | Logging settings (section 13), backup retention ≤ 30 days, restore runbook (rollback handling) in S23 | Sync backend: logging, backups and retention |

Plus one card for the external review: **"Sync: external crypto review of
the E2EE design"** (section 18).

### SQL sketches

```sql
-- B1/B2: only sessions bound to an approved device count.
alter table public.devices
  add column signing_public_key bytea check (signing_public_key is null or octet_length(signing_public_key) = 32),
  add column status text not null default 'pending'
    check (status in ('pending', 'approved', 'revoked')),
  add column approved_at timestamptz,
  add column revoked_at timestamptz;

create table public.device_sessions (
  session_id uuid primary key,
  device_id  uuid not null references public.devices (id) on delete cascade,
  user_id    uuid not null references public.accounts (id) on delete cascade,
  bound_at   timestamptz not null default now()
);

create or replace function private.device_ok()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.device_sessions s
    join public.devices d on d.id = s.device_id
    where s.session_id = ((select auth.jwt()) ->> 'session_id')::uuid
      and s.user_id = (select auth.uid())
      and d.user_id = (select auth.uid())
      and d.status = 'approved');
$$;

-- B7: reads need an approved device and an active membership.
drop policy e2ee_select_member on public.e2ee_records;
create policy e2ee_select_member on public.e2ee_records
  for select to authenticated
  using (private.device_ok() and private.family_role(family_id) is not null);
-- (family_role() must also require family_members.status = 'active', B5.)

-- B5: the log.
create table public.family_log (
  family_id  uuid not null references public.families (id) on delete cascade,
  seq        integer not null check (seq > 0),
  prev_hash  bytea check (octet_length(prev_hash) = 32),
  entry      bytea not null check (octet_length(entry) <= 16384),
  sig        bytea not null check (octet_length(sig) = 64),
  hash       bytea not null check (octet_length(hash) = 32),
  created_at timestamptz not null default now(),
  primary key (family_id, seq)
);
-- Inserted only by append-family-log (service role); members select with device_ok().

-- B7: power-of-two padded ciphertext (40 = nonce 24 + tag 16).
alter table public.e2ee_records
  add column revision bigint not null default 1,
  add column hlc bigint,
  add constraint e2ee_padded check (
    ciphertext is null or (
      octet_length(ciphertext) - 40 between 256 and 65536
      and ((octet_length(ciphertext) - 40) & (octet_length(ciphertext) - 41)) = 0));
```
