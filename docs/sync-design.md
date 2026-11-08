# Usra family sync: end-to-end encryption design and threat review (S14)

Status: **design for review**, 2026-11-05, revised 2026-11-06 after the
crypto and threat review on PR #3 (findings H1–H4, M1–M11 and the low items
are folded in; section 21 maps each finding to its change). No sync code may
be merged before this design has been reviewed by an external cryptography
reviewer (security plan S14), the open questions in section 18 are answered,
and the backend blockers in section 20 (B0) are closed.

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
21. Review findings and where they are addressed

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
  server stores the log but cannot forge or reorder entries. It *can*
  withhold entries; signed **head beacons** that every device publishes make
  withholding visible, and a phone stops writing when it can't see other
  members' recent heads (section 7). Section 14 lists what is left.
- Records are **signed** by the device that wrote them, inside the
  encryption, so a viewer who knows the family key still can't forge a
  guardian's edit. Authorship is hidden from a database dump, not from the
  live server, which knows which signed-in device uploaded each version.
- **Signing in alone never gives data access.** A newly signed-in phone is a
  *pending* device until an existing phone approves it (QR, or a 6-digit
  comparison code) or the person types their **recovery key**. Postgres
  row-level security checks that the session belongs to an approved device,
  not only that the user is a family member.
- The existing **recovery key** (the 36-digit paper key used for backups)
  also derives a **recovery device**: an offline key pair that receives every
  family key, so a person who loses every phone can get back in.
- Removing a member or device **rotates** the family key. The removed party
  keeps what they already had on their phone and can't read anything written
  after the rotation **by a writer who has seen the rotation**. A server that
  hides the rotation from a phone could make that phone keep writing under
  the old key; head beacons and the write-stop rule in section 7 limit this.
- Sync pushes encrypted records to `e2ee_records` with **compare-and-set** on
  a server revision and merges **per field, or per group of fields that
  belong together**, with **hybrid logical clocks** carried only inside the
  signed ciphertext. Readers reject clocks a removed writer or an old epoch
  can't honestly have. Deletes are signed tombstones.
- The server sees random sync ids, padded sizes, upload times, key versions,
  membership and the device list; it never sees record types, names, values,
  file contents or when an edit was made (only when it was uploaded).

## 2. Goals and non-goals

### Goals

1. **Confidentiality from the server.** Neither Opsedia, Supabase, a
   hosting provider, an insider nor someone with a database dump can read
   health data, profile names, record types or attachments.
2. **Integrity from the server.** The server can't change, invent, move or
   attribute records, and can't add a member or device to a family, without
   the phones rejecting it. It can withhold data (section 14), and it can
   *report* that an account was deleted or reset, which a person must
   confirm before anyone is removed (section 7).
3. **Family sharing with roles**: owner, guardian, cared-for and viewer, as
   in the existing `family_members` table.
4. **Several phones per person**, and moving to a new phone.
5. **Recovery** after losing every phone, with the recovery key.
6. **Account takeover resistance.** A stolen Google or Apple account gives
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
  accounts (email addresses) share a family; row-level security needs it.
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
| **Account** | A Supabase Auth user, signed in with Google or Apple. Holds no health data. |
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
| Email addresses, names and profile photo links from Google, account ids, locale | Profile names, birth dates, any health data |
| Devices: platform, app version, public keys, approval state, created / last seen times | Device names or models (not stored) |
| Push tokens; when it sends a push | Push content beyond "sync" or a fixed security alert text |
| Families, who is a member of which, roles, when they joined or left | The family's name (kept in an encrypted record) |
| The family log: member and device public keys, roles, key versions, signatures, times | Anything about records in the log |
| Per record: family id, a random sync id (UUID v4, not the local UUID v7), key version, server revision, padded ciphertext size, upload and delete-hint times | Record type, profile, field names or values, when the edit was made (the clock is only inside the ciphertext) |
| Which signed-in device uploaded each version (live server and request logs) | Who wrote a record, from a database dump alone (the signer is only inside the ciphertext) |
| Per attachment: blob id, number of chunks, padded size, upload time | File name, type, content, which record uses it |
| Wrapped family keys and who they are wrapped to | The family keys |
| Recovery: a salt, KDF settings and the recovery device's public keys | The recovery key |
| IP addresses and request times (gateway logs) | Request bodies (not logged) |

What a database dump reveals is therefore: who uses Usra, who shares a
family with whom, how many records and photos a family has and roughly how
big they are, and when they upload. Section 13 reduces this where it is
cheap; section 14 lists what is left.

## 5. Building blocks

### Primitives

| Use | Primitive | Why |
| --- | --- | --- |
| Record and blob encryption | XChaCha20-Poly1305 (IETF), random 24-byte nonce | Already used for backups and photos; random nonces are safe at any volume |
| Key wrapping to a device | HPKE base mode, `DHKEM(X25519, HKDF-SHA256)`, `HKDF-SHA256`, `ChaCha20Poly1305` (RFC 9180 suite 0x0020/0x0001/0x0003) | Standard, has test vectors, uses the existing X25519 device key |
| Pairing bundle | HPKE **PSK** mode, same suite | The pairing secret from the QR authenticates the sender |
| Signatures | Ed25519 (RFC 8032), "pure" mode, **strict verification** everywhere: `S < L`, canonical `A` and `R` encodings, small-order `A` and `R` rejected, cofactorless equation | Small, fast, deterministic; strict rules so the phones, the server and the test tools accept exactly the same signatures |
| Hash, chain, commitments | SHA-256 | Available everywhere (Dart, Postgres, Deno) |
| Key derivation | HKDF-SHA256 (RFC 5869) | |
| Recovery key stretching | Argon2id, same cost as backups (19 MiB, 2 passes, 1 lane) | Already used; the key has ~99.7 bits, so stretching is a margin, not the defence (raising the cost adds nothing that matters) |
| Randomness | `Random.secure()` only | Security plan rule |

### Encodings

- Signed objects (log entries, record bodies, approvals, head beacons) are
  **UTF-8 JSON byte strings that are signed and stored as bytes**. A reader
  verifies the signature over the exact bytes and only then parses them.
  Nobody re-serialises before verifying, so no canonical-JSON scheme is
  needed. Binary values inside JSON are base64url without padding.
- Parsing is **strict** on the phones and the server alike: invalid UTF-8,
  duplicate keys, unknown top-level keys in log entries, more than 8 levels
  of nesting or more than the object's size limit are rejected, never
  "last key wins". The server mirrors membership from the same strict parse
  the phones use, so they can't disagree about a `role` or `by`.
- **Clocks and other 64-bit values are strings** in JSON (16 lowercase hex
  digits for HLCs), because a 64-bit HLC is above 2^53 and JavaScript or
  Deno would round it as a number.
- Fixed headers (record AAD, HPKE `info`) are binary with fixed-width fields,
  so they can't be ambiguous.
- Ids are UUIDs as 16 raw bytes in binary headers and as lowercase strings in
  JSON.

### Domain separation

Every signature, HKDF output, Argon2 input and HPKE `info` starts with its
own label **followed by a 0x00 byte** (so no label is a prefix of another,
for example `usra/v1/pair` and `usra/v1/pair-sas`), and a value made for one
purpose can never be accepted for another:

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
| `usra/v1/head` | Signature over a head beacon (section 7) |
| `usra/v1/recovery-device` | Argon2id input prefix for the recovery device |
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

Walking back is checked at every step: each recovered `FK_v` must match
`KC_v` from the log, and the `rotate_key` entry for epoch v+1 commits to
`SHA-256(history[v+1])`, so the server can't swap a history blob either.

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
seed = Argon2id(password = "usra/v1/recovery-device" || 0x00 || the 36 recovery digits (ASCII),
                salt = account_recovery.salt (16 random bytes, stored on the server),
                m = 19 MiB, t = 2, p = 1, length = 32)
rkx  = X25519 private key from HKDF(seed, info = "usra/v1/recovery/kx")
rsig = Ed25519 seed from HKDF(seed, info = "usra/v1/recovery/sign")
```

The labelled input (backups use their own `usra-recovery-key:` prefix) and
the separate salt keep the backup file keys and the recovery device
unrelated outputs of the same paper key. The phone accepts KDF settings from
the server only within the same bounds as `BackupKdf.isReasonable` (at most
256 MiB, 10 passes, 8 lanes), so a hostile server can't run a 2 GB phone out
of memory. After deriving, the phone checks that the public keys of `rkx`
and `rsig` equal the recovery device **in the family log**; the server's
`account_recovery` copy is only for the server's own gate. The
recovery device is listed in the family log as a device of kind `recovery`,
so every rotation wraps the new key to it automatically; nothing has to be
"escrowed" again after a rotation.

If the person makes a **new recovery key** in the app, the phone revokes the
old recovery device, adds the new one, and rotates the family key (the old
paper might be the reason). Backup files made before that still open only
with the old key: the app says "keep the old paper for backups made before
<date>", and offers to make a fresh backup with the new key.

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
sig  = Ed25519(dsig of "by", "usra/v1/log-entry" || 0x00 || entry_bytes)
hash = SHA-256(entry_bytes)
```

The chain hash covers `entry_bytes` only (which already hold `seq` and
`prev`), not the signature, so a re-encoded signature can't make a second
entry with a different hash. Entries are at most 16 KiB.

A device record inside an entry is
`{ "id", "user", "kind": "phone" | "recovery", "kx": <32 bytes>, "sig": <32 bytes> }`.
Device ids are never reused, and `revoked` is final: a revoked device can't
be added again (it enrols as a new device with new keys).

### Entry types and who may write them

Authorisation is checked against the state after entry n-1.

| Type | Fields | Signed by |
| --- | --- | --- |
| `genesis` | creator user id, creator's devices (phone + recovery), `key_version: 1`, `KC_1` | A device of the creator, who becomes owner |
| `add_member` | user id, role (not owner), their devices, invite id, invite MAC (section 9), and for `cared_for` the profile id they are linked to | The owner |
| `change_role` | user id, new role (not owner), linked profile id for `cared_for` | The owner |
| `transfer_owner` | user id (an existing member; the old owner becomes guardian) | The owner |
| `remove_member` | user id, reason `removed` / `left` / `account_deleted` / `reset` | `removed`: the owner; `left`: a device of that member; `account_deleted` and `reset`: any member, but **only after a person confirms** it on their phone ("Mona's account was reset. Remove her from the family?"). The server's report is never acted on automatically |
| `add_device` | user id, device | A current device of the same user, including their recovery device |
| `revoke_device` | user id, device id | A current device of the same user, or the owner |
| `rotate_key` | new `key_version`, `KC_{v+1}`, `SHA-256(history[v+1])`, SHA-256 of the sorted recipient device ids | A current device of any active member |

Rules every phone checks while replaying:

- `seq` increases by one and `prev` matches; the signer is a current
  (non-revoked) device of an active member and is allowed to write that type.
- After any `remove_member` or `revoke_device`, no record may be written
  until a `rotate_key` follows (section 10). Any member's phone that is
  online performs the rotation.
- A `rotate_key`'s recipient hash must match the set of current devices of
  active members (phones and recovery devices) at that point.
- The owner can't remove themselves; they transfer ownership first.
- A second validly signed entry at a `seq` the phone already has (for
  example the losing side of two phones appending at once, or two concurrent
  `rotate_key` entries) is treated as a **fork**, not quietly dropped: the
  phone shows the security warning until the family settles on one chain
  (the loser's phone re-appends its change on top of the winner).

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
- **Member list.** The app always shows who is in the family; a person who
  removed someone and still sees them listed knows something is wrong.

### Head beacons (required)

Every device publishes, on every sync, a signed beacon for each family:

```
beacon_bytes = UTF-8 JSON { "v": 1, "family", "device", "seq", "h": <head hash>, "at": <HLC string> }
beacon_sig   = Ed25519(dsig, "usra/v1/head" || 0x00 || beacon_bytes)
```

stored one row per device in `family_heads` (newest only, published through
the `publish-head` Edge Function, which checks the signature). Phones read all
beacons of the family on every sync and check them:

- A beacon whose `(seq, h)` is not on the phone's chain, at a `seq` the phone
  has, is a **fork**: warning, stop syncing that family.
- A beacon with a higher `seq` than the phone can download is **withholding**:
  warning, stop writing.
- **Write stop.** If the newest beacon from *every* device of some other
  active member is older than 7 days, the phone warns ("Ahmed's phone hasn't
  been seen for a week") and **does not write** to that family until a fresh
  beacon arrives or two members compare safety codes in person. This is what
  stops a server from keeping one phone on a head from before a removal (the
  phone would keep encrypting under a key the removed member holds): the
  honest members' fresh beacons either arrive, showing the newer head, or are
  missing, which stops the phone writing.
- A **recovered phone** (way 3) has no anchor of its own, so it is
  **read-only** until it has a beacon signed after the recovery started by a
  current device of another active member, or a safety-code check, and after
  the person has confirmed the member list it shows ("Is this everyone who
  should be in your family?").

What this doesn't cover: if the only other active member at the stale head is
the colluding removed member, their own fresh beacons satisfy the rule. The
member list (which still shows them) is then the only signal. Section 14
lists this.

### Appending

Phones append through the `append-family-log` Edge Function, which checks
the same rules (strict JSON, signature with WebCrypto Ed25519 plus the strict
checks of section 5, authorisation, `seq`, `prev`) and, in one transaction,
inserts the entry and updates `family_members`, `family_devices` (the current
devices of each member), `devices` and `families.current_key_version`; a
`rotate_key` request also carries the history blob and every wrap of the new
epoch (section 10). Numbers in log entries are plain integers. The exact field
names per type are listed in `supabase/README.md`. Two phones racing to append get
a unique-key conflict on `(family_id, seq)`; the loser refetches, re-checks
and retries. The server's checks only keep honest-server state tidy; the
phones' checks are the ones that matter.

## 8. Device enrolment and account safety

### Device states (server side)

`devices.status` is `pending`, `approved` or `revoked`. A device is created
`pending` when it registers its public keys after sign-in.

**Session binding.** After sign-in, the phone calls `bind-device` with
`Ed25519(dsig, "usra/v1/bind-session" || 0x00 || session_id (16 bytes) || server_nonce (32 bytes))`.
The function checks the signature against the device's registered key and
stores `(session_id → device_id)` in `device_sessions`. A phone has one live
session: binding a new one unbinds the older ones. So after a **lost
session** (refresh token revoked or expired) the app signs in again and binds
its existing device row by proving its key; it registers a new device only
when that row is gone or revoked. Public keys alone never identify a device
(they are public). Row-level security on
every sync table calls `private.device_ok()`, which is true only if the
JWT's `session_id` is bound to an **approved** device of `auth.uid()`. A
session that has only signed in therefore reads and writes nothing in
`e2ee_records`, `family_log`, wraps or blobs.

**First device.** An account's very first device approves itself and
creates the person's family (genesis), adding its recovery device at the same
time. `accounts.sync_enrolled_at` is set then. From that moment on, **a new
device can never self-approve**, even if every device row is later deleted
(sign-out used to delete the device row and now revokes it; without this rule, signing out of the
last phone would let a Google or Apple sign-in alone start over).

Enabling sync requires a recovery key the person has written down: the app
asks them to type two of its groups back before turning sync on.

### Way 1: approve from an existing phone with a QR code (default)

1. New phone N signs in, makes its keys, registers as `pending`, and
   shows a QR code: `usra:pair:v1:` + base64url(`device_id_N || dkx_N ||
   dsig_N || s`), where `s` is 32 random bytes. The screen says not to share
   a screenshot of the code.
2. The person opens Settings → Devices → "Add a phone" on an approved phone
   E and scans it **with the in-app camera** (no importing an image, so a
   screenshot sent by an attacker with "scan this to verify your account"
   can't be used from the gallery). E shows what it is about to approve
   ("Android phone, asked to join 2 minutes ago. Is this phone in your hand
   now?") and needs a tap. E now has N's keys over the camera, which the
   server can't touch.
3. E signs an approval
   `Ed25519(dsig_E, "usra/v1/approve-device" || 0x00 || user_id || device_id_N || dkx_N || dsig_N || server_nonce)`
   over a single-use server nonce and sends it to `approve-device`, which
   checks that the caller's session is bound to E, that E is approved and
   belongs to the same user, that N is `pending` (never `revoked`, which is
   final), and that the signature verifies; then it sets N to `approved`.
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
2. E (notified by push) fetches them and posts its device id, its public
   keys `dkx_E` and `dsig_E`, and random `n_E`. (After joining, N also
   checks that these keys are E's in the verified family log.)
3. N reveals `n_N`; E checks it against `C`.
4. Both show `SAS = first 32 bits of SHA-256("usra/v1/pair-sas" || dkx_N ||
   dsig_N || dkx_E || dsig_E || n_N || n_E)` mod 10^6, as 6 digits. The person
   taps "They match" on **both** phones.
5. Then steps 3–6 of way 1, with the bundle sealed in HPKE base mode to N
   and signed by `dsig_E` (whose key N now trusts through the code).

Because N committed before seeing `n_E`, a server in the middle gets one
guess in a million per attempt. A pairing session dies after one mismatch,
a cancel or a timeout. The server allows at most 3 sessions per hour, and
because the server is the attacker in this scenario, **each phone also counts
attempts itself**: E refuses more than 3 comparison sessions a day and then
only offers way 1 or way 3.

The screen must say: "Only approve a phone that is in your hand right now.
Usra will never call you or message you to ask for this code." A caller who
talks someone into approving is still a risk (section 14).

### Way 3: the recovery key

1. N signs in, registers as `pending`, and the person types the
   recovery key (checked locally with its check digits first).
2. N fetches `account_recovery.salt` and KDF settings (allowed for a pending
   device; 5 tries per account per day), derives the recovery device keys, and
   proves them by signing a server challenge with `rsig`: the same
   `"usra/v1/approve-device"` message as way 1, step 3, over N's keys and the
   nonce, so the recovery device "approves" N. `recover-device` checks the
   signature against the recovery device's key (a `devices` row of kind
   `recovery`, named in `account_recovery`) and approves N.
3. N downloads each family log, checks that the derived recovery public keys
   are the current recovery device of this user **in the log** (not just in
   `account_recovery`), then, acting as the recovery device, appends
   `add_device(N)` (signed with `rsig`), unwraps each family key from the
   recovery device's wrap, re-wraps it to itself, and wipes `rkx`/`rsig`
   from memory. N stays **read-only** until the head-beacon check in
   section 7 passes.
4. Every other device of the account and the family owner are notified.

### Account reset (lost every phone and the recovery key)

Signing in on an account that has no approved device left (or whose
person says they lost them) offers **account reset**:

- It takes **7 days**. During that time every approved device of the account
  gets a push and an in-app banner with "This isn't me" (cancels the reset,
  needs an approved device **enrolled more than 7 days before the reset
  started**, so a device an attacker just added can't cancel the real
  person's reset). Phones also check `account_resets` on every launch, so a
  push the attacker redirected or dropped can't hide a reset.
- After 7 days the server revokes all of the account's devices and recovery
  device, marks its memberships `reset`, and sets `families.rotation_pending`.
  The new phone becomes the account's first device again, with a new
  recovery key, but it is **not** in any family.
- Other members see "Mona reset her account" and are asked to confirm her
  removal; the confirming phone appends `remove_member` with reason `reset`
  and rotates the key. The owner can then re-invite her, **in person only**
  (section 9), and the key history gives her the family's full history
  again.
- If the person who reset was the family's only owner, see section 11.

An account thief can start a reset, but the real person is warned on every
phone for a week and can cancel it.

**Race after an unclaimed reset.** If the phone that started a completed reset
is revoked or doesn't enrol within 72 hours, the account (now not enrolled)
may start a new reset. Two phones can race for it, for example the real
person's new phone and an account thief's. The first `start_account_reset` opens
the reset, and that phone is the only one that may enrol when it completes;
any other phone gets `reset_in_progress` and is not joined in. There is no
approved phone left to cancel it, so an account thief who wins this race holds the
account after 7 days, exactly as with a reset on an account that has no older
phone (section 14). What protects the person is what protects any reset: the
7-day wait, the reset check on every launch of their phones, and support. The
loser can start a new reset only once this one completes and is itself
unclaimed.

An account thief who strikes **before** the person ever turns on sync can make
the account's first device and genesis. The real person then finds their
account already enrolled and must use an account reset. If the attacker's
device was enrolled more than 7 days before the reset began, it can cancel
the reset. The Devices screen shows each device's enrolment date and the
reset screen says when the account was first enrolled, so the person can
see it and contact support; section 14 lists this as residual.

### What signing in alone can do

| Action | Signed in only (pending device) | Needs an approved device |
| --- | --- | --- |
| Read or write records, logs, wraps, blobs | no | yes |
| Register a pending device, push token | yes | |
| Try the recovery key | yes (rate-limited) | |
| Start an account reset (7-day wait) | yes | cancel it |
| Delete or revoke **other** devices | no | yes |
| Leave a family, accept an invite | no | yes |
| Delete the account or a family | no (B0.4, B10) | yes |
| Change a device's keys, mark a device approved, touch another device's push token | no, ever (B0.1–B0.3) | only through functions |
| Change locale | yes (harmless) | |

### Signing in, and getting back in

Sign-in is Google or Apple only (native ID tokens through Supabase Auth; the
phone and email providers are off). So:

- **Getting back into the account is Google's or Apple's job.** There's no
  code we can resend and no support route that signs someone in. Someone locked
  out of their Google or Apple account is locked out of Usra's account until
  they recover it. Their records are still on their phones.
- **Taking over the account means taking over theirs,** usually by phishing or
  a stolen mailbox. An old phone number passing to a new owner is no longer a
  way in. Everything above still applies: the thief gets a pending device.
- **One verified email, one account.** Supabase links Google and Apple sign-ins
  that share a verified email, so someone who controls that mailbox's Google
  account also reaches the account first made with Apple. It's still only a
  pending device. Apple's Hide My Email gives a relay address, and so a separate
  account with no link to the first.

### Notifications

Every approved device of the account gets a push with fixed text (no names,
no health data) when: a phone asks to join; a phone is approved or revoked;
the recovery key is used; an account reset starts. Push tokens can only be
written for the session's own device (B0), so an sign-in-only session can't
redirect or delete the real phones' tokens. Family members see quieter
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
   hashes it on the server; B9 changes this). The server records the invite
   as accepted by them; until the owner's `add_member` they have no
   `family_members` row, so RLS gives them nothing. (`family_members.status`
   is `active` or `reset`.)
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
shows the invitee's email (from the server, for the owner to recognise) and
asks "Is this Mona?" before step 4. The email is only a hint: it is exactly
what someone who stole the Google or Apple account controls, and with Apple's
Hide My Email it's a relay address the owner won't recognise. So:

- Inviting someone whose account was **reset** (or who left after a reset)
  must use the QR code **in person**; the app doesn't offer a link, and shows
  "account reset N days ago" next to them.
- For other invites the app recommends the QR in person and labels links
  "only send to a chat you're sure is theirs".

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
  server breach). They cannot read anything written under a later epoch,
  as long as the writer had seen the rotation (head beacons, section 7).
- They lose server access at once, so they can't download anything new.

The app tells the owner this when they remove someone.

## 11. Recovery

| Situation | What happens |
| --- | --- |
| New phone, old phone at hand | Way 1 (QR). Full access in a minute. |
| New phone, old phone at hand but the QR won't scan (broken camera) | Way 2 (comparison code). |
| Phone recovered with way 3 | Read-only until a fresh beacon from another member or a safety-code check, and the person confirms the member list (section 7). |
| New phone, old phone elsewhere | Way 3 (recovery key), or wait until both phones are together. Never way 2 over the phone: reading the code to someone is exactly what an attacker asks for. |
| Lost every phone, has the recovery key | Way 3. Full access, including every family's history. Lost phones are then revoked from the new one. |
| Lost every phone and the recovery key, others in the family, not the owner | Account reset (7 days) and the owner re-invites in person. Full history comes back with the key history. |
| Lost every phone and the recovery key, was the only owner of a family with other members | Account reset. The family is frozen: members keep reading what is synced and nobody can change membership. In v2.0 a guardian can start a new family and copy the records across on their phone (re-encrypted under the new family). Section 18, Q8 proposes co-owners to avoid this. |
| Lost every phone and the recovery key, alone | The synced data is gone for good: nobody, including us, can decrypt it. Account reset deletes the ciphertext. A local backup file needs the same recovery key. The app says this when sync is turned on. |
| Restored a backup file on a new phone | Records come back locally; to sync, the phone is enrolled (way 1–3) and does a full sync, merging by the per-group clocks the backup carries (section 12). |

## 12. Sync protocol

### Units

Every row of a synced local table (`profiles`, `medical_events`, `doctors`,
`insurance_cards`, `attachments`, `medicines`, `dose_schedules`, `dose_logs`,
and later tables) is one record. Its columns are merged in groups (see
Merge below); `medical_events.data_json` is merged by its top-level keys.

### Sync ids

On the server a record is known by a **random sync id** (UUID v4), not by
its local UUID v7 id, which would tell the server when the record was made
(for a dose log, the moment "Taken" was tapped). The phone that first
uploads a record picks the sync id; the local id is inside the ciphertext
(`"id"`), and every phone maps the two in `sync_records`. A record only
reaches another phone through sync, so the mapping travels with it.

### Hybrid logical clock (HLC)

A 64-bit value: 48 bits of Unix milliseconds and a 16-bit counter, written in
JSON as 16 lowercase hex digits. Each phone keeps `hlc_last`. On a local
write: `hlc = max(hlc_last + 1, now_ms << 16)`; on applying a remote field
with clock `r`: `hlc_last = max(hlc_last, r)`.

The clock lives **only inside the signed, encrypted body**. It is not in the
header or in any server column, so the server learns upload times but not
edit times, and it can't check clocks (any server-side clock check would be
honest-server-only anyway). The readers' rules below are the real checks.

A phone uses its own clock. It may compare it with the server's `Date`
header to show "your phone's time is wrong", but never uses the server's
time to accept or reject anything (the server could lie).

### Record envelope

```
header (AAD, 42 bytes, rebuilt by the reader, never parsed from the row):
  "USR1" 0x00 | u8 format = 1 | family_id (16) | sync_id (16) | u32 key_version

body (UTF-8 JSON, signed, strict parse):
{
  "id": "<local record id>",
  "t": "medicine",                      // record type: only inside the ciphertext
  "by": "<device_id>",
  "log": { "seq": 42, "h": "<log head hash>" },
  "hlc": "019300f8a1b20003",            // must equal the largest clock below
  "g": {                                // merge groups: [values, hlc]
    "dose": [{ "amount": "500", "unit": "mg", "route": "oral" }, "019300f8a1b20003"],
    "name": [{ "name": "Panadol" }, "0192ff10c4000001"],
    "_deleted": [false, "0192ff10c4000001"]
  }
}

plaintext = sig (64) | u32 body_length | body | zero padding
sig       = Ed25519(dsig, "usra/v1/record-sig" || 0x00 || header || body)
stored    = nonce (24) | XChaCha20-Poly1305(RK_v, nonce, aad = header, plaintext)
```

The reader **rebuilds** the header from its own context (the family it is
syncing, the row's sync id and `key_version`) instead of trusting anything
in the row, so a ciphertext moved to another family or sync id fails.

Padding: the plaintext is padded to the next power of two, at least 256
bytes and at most 64 KiB. The server checks that `octet_length(ciphertext) − 40`
is one of those sizes, so a buggy client can't leak exact sizes. Anything
bigger than 64 KiB goes into an attachment blob.

### Reader rules

A reader applies a record only if all of these hold (each is a property test,
section 16):

1. The AEAD opens with the header the reader rebuilt, and the body parses
   strictly.
2. The signature verifies (strict Ed25519) with the `dsig` of `by`.
3. `log` is on the reader's chain, `by` was a current device of a member
   whose role may write this record type at `log` (for `cared_for`: only
   dose logs of the profile linked to them in the log), and `key_version`
   is the epoch in force at `log`.
4. `hlc` equals the largest group clock in the body.
5. **Revoked or removed writers.** If `by`'s device was revoked, or its
   member removed, at log entry `s`, every group clock must be at most
   `at(s)` + 10 minutes. A removed member still holds their signing key and
   old family keys; without this rule they could, with the server's help,
   sign an edit under an old head with a current clock and win every merge.
6. **Old epochs.** If `key_version < v` for some epoch v the reader knows,
   every group clock must be at most `at(rotate_key v)` + 10 minutes. Honest
   phones only ever encrypt under the current epoch (outbox records are
   encrypted at push time), so a newer edit under an older key is forged.
7. **Future clocks.** A group whose clock is more than 10 minutes ahead of
   the reader's own clock is **held**, not applied, and looked at again
   later; it neither changes the record nor moves `hlc_last`. This stops a
   wrong or hostile clock from winning forever.

A record that fails 1–6 is dropped and the family shows the security
warning; failing 7 only delays it.

### Merge

Fields are merged in **groups**, each with one clock. A group is either a
single field or a set of fields that only make sense together, defined per
record type in code with the record type's schema:

| Record type | Groups taken as a whole |
| --- | --- |
| `medicines` | amount + unit + form + route; frequency + times + duration; name + strength |
| `dose_schedules` | the whole schedule (times, interval, days, start, end) |
| `insurance_cards` | the whole card (insurer, number, holder, validity) |
| `profiles` | each field on its own (name, birth date, blood type, allergies, conditions) |
| `medical_events` | type + occurred_at; each top-level `data_json` key on its own unless the record type groups keys (for example a lab result's value + unit + reference range) |

Per group, the value with the higher clock wins; on an equal clock, the
value whose JSON encoding is larger (bytewise) wins. This is commutative,
associative and idempotent, so every phone reaches the same state whatever
order changes arrive in. Replaying an older version changes nothing.

**Conflict flag.** When a merge replaces a group that the local phone had
also changed since the last sync (two people edited the same medicine's dose
at once), the phone keeps the winner but marks the record "changed by two
people, please check" and shows both values. Clinical groups (medicines,
schedules, allergies, lab values) never merge silently.

Dose logs and other history rows are written once and never edited, so they
never conflict.

### Deletes and tombstones

Deleting sets `_deleted = true` with a new clock and **drops every other
group's value** before upload (the tombstone body keeps only `_deleted`).
Once `_deleted` is true, writers drop any other values that arrive from a
concurrent edit; the record stays deleted unless someone restores it from
their phone's local trash (`_deleted = false` with a newer clock and the
values). The writer also sets the row's `deleted_at` as a plain hint for the
server's cleanup below, but readers trust only the signed `_deleted` group.
`ciphertext` is **required** on every row, tombstones included (B7), so
there is no unsigned way to "delete".

If the server **drops** a tombstone, phones that missed the delete keep the
record (for example a stopped medicine or a corrected allergy), and nothing
looks missing. Head beacons don't catch this. Two partial defences: phones
that see a record disappear from a full resync while they still hold it ask
the person rather than silently keeping it; and signed per-family state
digests are an open question (section 18, Q15).

Tombstones are kept on the server for 1 year, then the row is removed. A
phone that has not synced for more than a year does a **full resync**: it
lists every live sync id, and for records it has locally that are neither
on the server nor newer than a year it asks the person whether to upload or
remove them.

### Push

The outbox (`OutboxEntries`, already in the schema) holds which rows changed.
The sync worker, for each family:

1. Takes up to 100 changed records (at most 2 MiB), builds each one's merged
   body from local values and per-group clocks, signs, pads and encrypts it
   under the **current** epoch.
2. Calls `push_e2ee_records(family_id, [{sync_id, key_version, ciphertext,
   deleted_hint, expected_revision}])`, the **only** way to write
   `e2ee_records` (direct grants are revoked, B0). The function, for each
   record, checks `device_ok()`, role, `key_version = current_key_version`
   and the padded size, then writes only if the stored `revision` equals
   `expected_revision` (0 for a new record) and bumps `revision`. These are
   honest-server checks; the reader rules above are the real ones.
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
`sync_id`, `revision`, `key_version`, `ciphertext`, `deleted_at`. The phone
verifies, merges into the local tables in one transaction, updates its local
clocks and stores the cursor. The family log (`seq > n`), head beacons and
wraps for this device are pulled first, so new epochs are known before
records using them and a withholding server is noticed before writing.

New phones and full resyncs page through everything; the first sync of a big
family is resumable by the same cursor.

A data-only push ("sync", with an opaque collapse key that is not the family
id, at most one per minute per family) tells other phones to pull. No push
contains ids or content.

### Attachments

- An attachment's file is encrypted with its own random `BK` in chunks of 256
  KiB, like the backup format: the 24-byte nonce is a 16-byte random prefix,
  a u32 chunk number and a u32 last-chunk flag; AAD =
  `"usra/v1/blob" || 0x00 || family_id || blob_id || u32 chunk_count`.
  Reordering, dropping, truncating or swapping chunks fails. The nonce
  prefix is stored in the attachment record next to `BK` (not in the clear).
- The file is padded with Padmé (leaks at most O(log log n) bits of its size)
  before chunking; at most 25 MiB per file in v2.0.
- Chunks go to the private Storage bucket `e2ee-blobs` at
  `<family_id>/<blob_id>/<chunk>` with a random UUID v4 `blob_id`; RLS on
  `storage.objects` uses the same membership and `device_ok()` checks.
- The `attachments` record holds, inside its ciphertext: `blob_id`, `BK`,
  nonce prefix, chunk count, plaintext length, SHA-256 of the plaintext,
  media type, and the same for a small encrypted thumbnail, which is a
  separate blob with **its own** key and prefix. The server can't tell which
  record uses which blob.
- Upload the blob first, then the record; a reader that finds the record
  before the blob retries later. Deleting an attachment record deletes its
  blob objects (by the deleting phone). A weekly job on the owner's phone
  removes blobs no live record mentions, but only **after a complete,
  verified pull with no withholding warning**, and only for blobs unreferenced
  for at least 30 days, so a server that hides records can't trick it into
  deleting live photos. Only writer roles may delete blob objects (RLS).
  Deleting a family or account must delete its Storage objects explicitly:
  they are not covered by `on delete cascade` (B8).
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

- `sync_records(entity, entity_id, family_id, sync_id, revision, group_hlcs
  JSON, held JSON, dirty, conflict)`: the server's random id, per-group
  clocks, groups held for future clocks, the last server revision and the
  conflict flag. Included in backups
  (not secret), so a restored phone merges correctly.
- `sync_cursors(family_id, after_txid, after_record)`: not in backups.
- `family_log_entries(family_id, seq, hash, entry_bytes, sig)`: verified log;
  `family_head_beacons(family_id, device_id, seq, hash, at)`: newest beacon
  seen per device.
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
- Blob ids and sync ids are random v4 UUIDs. Local UUID v7 ids and edit
  clocks stay inside the ciphertext, so the server sees when something was
  uploaded, not when it was made or edited.
- **Write timing.** Dose logs uploaded the moment "Taken" is tapped would
  show the server a medicine schedule. Dose logs and other routine writes
  should be uploaded in batches at jittered times (for example the next sync
  window after 10–40 minutes), except when caregiver alerts (Phase 2) need
  them sooner. Since the clock and the local id are inside the ciphertext,
  batching now actually hides the tap time. Section 18, Q10.
- Push messages are data-only "sync" with an opaque collapse key, rate
  limited, so Google sees little more than "this phone uses Usra".

### Logging rules (server)

- Never log request or response bodies, ciphertext, wraps, signatures,
  public keys, invite codes or hashes, email addresses, names, or Google and Apple tokens.
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
- A restore from backup is a **rollback** from the phones' point of view, and
  it would also bring back `devices.status = 'approved'` for phones revoked
  after the backup point (stolen ones included). The restore runbook (S23,
  B13) therefore:
  1. keeps sync **closed** (kill switch) after the restore;
  2. lets phones upload the verified log suffix they hold beyond the
     restored head, including entries signed by others, plus the wraps and
     history blobs for later epochs (any phone may upload them; the server
     verifies signatures as in `append-family-log`);
  3. **rebuilds** `family_members`, `devices.status`, `families.current_key_version`
     and the wraps table from the log, not from the restored tables;
  4. reopens sync, after which phones re-push records the server is missing
     (the outbox is kept until confirmed, and a phone that sees the server
     behind its log head re-uploads its own records).

## 14. Threat model

| Threat | Example | Mitigations | What is left |
| --- | --- | --- | --- |
| **Server breach** (database dump, stolen backup) | An attacker copies Postgres and Storage | Only ciphertext, wraps and public keys stored; record and file keys never leave phones unwrapped; recovery key is ~100 bits behind Argon2id; padding; random sync ids; no names, types or edit times | Metadata (section 4): email addresses, who shares a family, record counts and upload times. Breach notice duties still apply (S23). Harvest-now-decrypt-later if X25519 is broken some day (Q6) |
| **Malicious server or insider** (actively lies) | Serves fake records, fake members, its own key | AEAD with keys the server lacks; records and log signed (strict Ed25519, strict JSON); key and history commitments in the log; anchors (QR genesis hash, pairing bundle); phones check roles and clocks themselves; head beacons | It can refuse service, delete data, withhold new records or tombstones, or show one member an older version of a record they haven't seen yet. **It can keep a phone on an old log head**, so that phone would encrypt new writes under a key a removed member holds; the write-stop rule (section 7) limits this to 7 days and to families where every other member's beacon is withheld, and does not catch it if the only other member at that head is the colluding removed member (the member list still shows them) |
| **Server-reported removals** | Server claims an account was deleted or reset | Removal needs a person to confirm on their phone; shown in activity | The server can still trick a person into confirming, or keep asking |
| **Key substitution at enrolment** | Server swaps the new phone's public key | QR carries keys directly, scanned in-app only; comparison code with commitment and phone-side attempt counters; signed approvals with server nonces | Person approves without comparing (UI must make comparing the only path) |
| **Stolen Google or Apple account** | Attacker signs in as the person | Pending devices can read and write nothing; approval only from a phone, comparison code, or recovery key; `sync_enrolled_at` stops self-approval; device keys immutable and push tokens bound to their own device (B0); pushes to every phone plus a reset check on every launch; account delete, family delete and device removal need an approved device; reset takes 7 days and can be cancelled only by a device older than the reset by 7 days; re-invites after a reset only in person | Attacker with SMS **and** the paper recovery key gets everything. Social engineering ("read me the code", "scan this screenshot") is mitigated by UI only. An account thief who enrols the account **before** the person ever turns on sync controls it until the person resets, and can cancel the reset if their device is old enough |
| **Stolen or lost phone** | Thief has the phone | DB and photos encrypted, app lock (S2), keys in Keystore / Keychain; remove the phone from another phone → revoke, rotate, new recovery key (the phone stored the old one), server access ends; the phone wipes family data if it reconnects | Whatever the thief can read on an unlocked phone before revocation. Remote wipe only works if the phone goes online with the honest app |
| **Rogue member** | A relative copies data or vandalises it | Roles: viewers and cared-for can't write (signatures + server RLS); removal rotates the key; reader rules 5–6 reject edits a removed member signs with clocks after their removal or under an old epoch; clinical conflicts are flagged, not silent; activity shows who added members and devices | Every member reads everything (by design). A guardian can overwrite or delete records (the server keeps only the latest version; Q7 proposes version history). A removed member keeps what they had, and with the server's help could still inject an edit dated (by its clock) before their removal, which only wins against older values |
| **Replay** | Server or network replays an old version or request | TLS; group-clock merge ignores older versions; header rebuilt by the reader binds sync id, family and epoch; wrap `info` binds family, epoch and device; log `seq`/`prev`; single-use server nonces for session binding, approvals and recovery; pairing sessions single-use with 10-minute life | — |
| **Rollback** | Server returns an older log or older records, or is restored from backup | Phones keep their highest verified log head and refuse anything shorter or different; head beacons show newer heads; records merge by clock so old versions don't win; restore runbook rebuilds state from the log | A phone that never saw a newer version can be shown an older one. A brand-new phone trusts the head its approver gave it; a recovered phone is read-only until beacons or a safety code confirm its head |
| **Fork** | Server keeps two members on different membership histories, or keeps both sides of an append race | Writer's log head inside every signed record; head beacons; a second valid entry at a known `seq` is a fork; safety code comparison | Undetected until a beacon, record or safety code crosses the fork |
| **Cut-and-paste** | Server moves a ciphertext to another record or family | The reader rebuilds the header (family id, sync id, key version) from its own context; the header is in the AAD and the signature | — |
| **Dropped deletes** | Server drops a tombstone, or sets `deleted_at` without one | Readers only honour signed tombstones; `ciphertext` is required on every row; a record missing from a full resync is shown to the person | A dropped tombstone is invisible: phones that missed the delete keep the record (a stopped medicine stays listed). Signed state digests (Q15) would catch it |
| **Account reset abuse** | Attacker resets the real person's account | 7-day wait, push and banner on every phone, reset check on every launch, cancel from any phone older than 7 days | Someone who has lost access to all their phones can't cancel |
| **Weak or hostile clocks** | Phone clock set far ahead to make edits win | Groups more than 10 min ahead of the reader's own clock are held, not applied; header clock must equal the largest group clock; server time never used to accept anything | A rogue writer with a correct-looking clock still wins LWW against older edits (normal) |
| **Malicious invite** | Attacker sends a link to a fake "family" | Invite carries the genesis hash; the app shows the inviter's family and email before joining | A person who joins the wrong family on purpose |
| **Coercion inside a family** | A cared-for adult pressured to share | Leaving a family is always possible (needs only their own phone); the app explains that everyone in a family sees everything | Per-profile privacy is a non-goal in v2.0 (Q9) |
| **Push and network observers** | Google (FCM), mobile operator | Data-only pushes without content, opaque collapse key; TLS; batched writes | Timing of app use |
| **No forward secrecy** | One device's keys leak later | Rotation on every removal | By design, the current family key opens the family's whole history through the key chain, and the recovery key plus a server dump opens every family the person is in. Old epochs are not deleted |
| **Side channels on the phone** | Timing attacks on pure-Dart crypto | Attacks need code on the phone, which already defeats us (non-goal) | Pure-Dart implementations are not guaranteed constant-time (Q2) |

## 15. Libraries

**App (Dart).** Keep the `cryptography` package (already a dependency, used
for backups, photos and the device key). It has X25519, Ed25519,
XChaCha20-Poly1305, ChaCha20-Poly1305, HKDF, SHA-256, HMAC and Argon2id in
pure Dart, plus `cryptography_flutter` for platform-accelerated ciphers where
available. HPKE is not in the package; we implement RFC 9180 base and PSK
mode for the one suite we use (about 150 lines on top of the package's
primitives) and gate it on the RFC 9180 test vectors for that suite
(appendix A.2 has base and PSK vectors for exactly this suite). The
package's `Hkdf` does extract and expand in one call, so HPKE's
`LabeledExtract` / `LabeledExpand` are built from `Hmac` directly.
`cryptography_flutter` does not speed up X25519 or Ed25519 on Android, so
those run in pure Dart.

Ed25519 verification must be **strict** (section 5). If the package's
verifier is more lenient (non-canonical `S`, small-order points), sync code
wraps it with the extra checks, and the same checks are applied in the Deno
functions and the Python cross-check tool.

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
recovery, which in pure Dart may take well over a second (it already runs for
backups; measure it and show progress). These are measured in Phase 0 before
any UI.

**Server (Deno Edge Functions).** WebCrypto `Ed25519` verify (supported in
Deno) for `approve-device`, `bind-device`, `recover-device` and
`append-family-log`; `crypto.subtle.digest('SHA-256')`. No decryption ever
happens on the server, so no AEAD or HPKE code is deployed there.

## 16. Test plan

**Known-answer tests (must pass in CI before any sync code merges).**

- RFC 9180 test vectors for `DHKEM(X25519, HKDF-SHA256), HKDF-SHA256,
  ChaCha20Poly1305`, base and PSK modes.
- RFC 8032 Ed25519 vectors, plus **Wycheproof** Ed25519 vectors and the
  "Taming the many EdDSAs" edge cases (non-canonical `S`, `A`, `R`,
  small-order points), run against **all three** verifiers: Dart on the
  phone, Deno WebCrypto in the functions, and the Python tool. All three
  must give the same answer for every vector.
- RFC 7748 X25519 vectors; XChaCha20-Poly1305 vectors from
  draft-irtf-cfrg-xchacha; RFC 5869 HKDF vectors.
- **Usra vectors**: fixed keys, nonces and inputs → exact bytes for a wrap,
  a record envelope, a tombstone, a log entry and chain hash, a key history
  blob, an attachment with 3 chunks, the recovery device keys from a fixed
  recovery key and salt, a comparison code, a head beacon. Stored as JSON in
  `app/test/crypto/vectors/` and **checked by a second implementation**
  (a small Python script using PyNaCl, `cryptography` and an independent HPKE
  library such as `pyhpke`, since PyNaCl has no HPKE, in `tools/`), so a bug
  in our Dart code can't also be in the expected values.
- Strict JSON: duplicate keys, invalid UTF-8, deep nesting and oversized
  objects are rejected by the Dart and Deno parsers alike; HLC strings
  round-trip exactly.

**Property tests (Dart, random seeds, thousands of runs).**

- Merge is commutative, associative and idempotent; N phones applying the
  same set of changes in any order and with any duplicates end identical.
- Groups merge whole: no merged record ever holds a combination of a group's
  fields that no single writer wrote; concurrent changes to a clinical group
  set the conflict flag.
- Reader rules 4–7: records whose header clock isn't the largest group clock,
  edits by a revoked or removed writer with clocks after `at(s)` + 10 min,
  edits under an old epoch with clocks after its rotation + 10 min, are
  rejected; groups more than 10 min ahead are held and applied once the
  reader's clock catches up.
- Replaying any older version never changes state.
- A delete plus concurrent edits ends deleted unless a newer restore exists.
- Flipping any bit of a header, nonce, ciphertext, signature, wrap or log
  entry makes it rejected.
- Log replay: random valid histories are accepted; forks, gaps, wrong
  `prev`, unauthorised authors (viewer adds member, device of another user
  revokes, guardian changes a role) and missing rotations are rejected.
- After removing a member at a random point, nothing written later by a
  phone that has seen the removal decrypts with any key that member held.
- Head beacons: a simulated server that withholds the removal from one phone
  either shows the newer head (via honest beacons) or makes that phone stop
  writing within 7 days; forks and withheld entries raise the warning; a
  recovered phone stays read-only until a fresh beacon or safety code.
- Key history: a swapped history blob or a recovered key that doesn't match
  `KC_v` is rejected.

**Database tests (pgTAP).**

- A session not bound to an approved device reads and writes nothing in every
  sync table and the blob bucket, even as the family owner.
- B0, one test each: an sign-in-only session can't change any device's keys, can't
  insert a device with `status = 'approved'`, can't write or delete push
  tokens of another device, can't delete a family, can't insert, update or
  delete `family_members` or `family_invites` directly, can't write
  `e2ee_records` except through `push_e2ee_records`; deleting the family's
  creator after an ownership transfer doesn't delete the family.
- Viewers and cared-for can't write records (Phase 1: only the owner can);
  pending and removed members read nothing; revoked devices lose access.
- `push_e2ee_records`: compare-and-set, stale key, size buckets, clock bounds.
- `accept_family_invite` only with the lookup hash; one use; expiry.
- `delete-account` and device removal refused for sign-in-only sessions.
- Family or account deletion removes Storage objects.

**Integration.**

- Two emulators and the local Supabase stack: enrol by QR (with a scripted
  camera) and by comparison code; edit the same record offline on both;
  remove a member; rotate; check the removed member's app can't read new
  records; restore a server backup and check that a phone revoked after the
  backup point stays revoked once the log is re-uploaded, and that phones
  re-push.
- Fuzzing of envelope and log parsers (malformed JSON, huge lengths).
- A budget-phone benchmark run before Phase 1.

**Review.** External cryptography review of this design (questions in
section 18) before Phase 1 code, and of the implementation before Phase 1
reaches users; included in the S22 pen test scope.

## 17. Phased rollout

| Phase | Who can do what | Gate |
| --- | --- | --- |
| **0. Foundations** (no user-visible change) | Crypto core, vectors, backend tables and functions (B1–B13) behind a server flag; internal builds only | B0 closed; this design reviewed; test vectors pass; benchmark on a budget phone |
| **1. Caregiver view (read-only)** | The owner's phones write (multi-device for the owner); everyone else joins as a read-only member (viewer). Records and attachments sync; phones sync down. Feature flag, closed beta in Egypt first | External review answered; implementation reviewed; legal gate for health data on the server (S25); privacy policy and data safety form updated |
| **2. Shared care** | Guardians write (group merge); cared-for writes dose logs for their own profile; caregiver alerts when a dose is missed | Phase 1 has run a month with no integrity warnings; version history decision (Q7) |
| **3. Later** | Per-profile private scopes (Q9), co-owners (Q8), post-quantum wraps (Q6), web view | Separate design notes |

Phase 1 limits risk: one writer account means few conflicts. A bug in merge
or signatures can still make the owner's two phones overwrite each other's
recent edits, but those edits are still on the phone that made them, and
clinical conflicts are flagged rather than merged silently.

Kill switch: a server flag stops all sync pushes and pulls without touching
local data; turning sync off on a phone keeps its records.

## 18. Open questions for the external reviewer

1. **HPKE in pure Dart.** Is a small RFC 9180 implementation on
   `cryptography`, gated by the RFC vectors, acceptable, or should wraps use
   libsodium `crypto_box_seal` (with our own sender signature) instead?
2. **Pure Dart vs libsodium.** Is the lack of constant-time guarantees in
   pure-Dart X25519 / Ed25519 / Poly1305 acceptable for a phone app whose
   threat model excludes local code execution?
3. **Key commitment.** *Answered in the PR #3 review:* a committing AEAD is
   not needed: one key per header epoch, the signature sits inside, and blobs
   carry a SHA-256 of the plaintext.
4. **Signing inside the encryption.** *Answered:* binding the header into
   both the AAD and the signature is enough, provided verifiers **rebuild**
   the header from their own context rather than parsing it from the row
   (now a reader rule, section 12).
5. **Recovery device from a 100-bit key.** *Answered:* 30 random digits is
   about 99.7 bits, so Argon2 cost adds nothing that matters; keep 19 MiB and
   bound the server-supplied settings (section 6).
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
12. **Fork detection.** *Answered:* not enough; signed head beacons on every
    sync and the write-stop rule are now required (section 7). Open: is 7
    days the right staleness bound for families where some members rarely
    open the app?
13. **Account reset delay.** Is 7 days right for the region (people
    sometimes lose their phone and their Google or Apple password at the same time)?
14. **The server checks.** Are there server-side checks here that create a
    false sense of security, or that a reviewer would expect and are missing?
    (The PR #3 review found the existing grant gaps now listed as B0.)
15. **State digests.** Should each writer publish, with its head beacon, a
    signed digest over `(sync_id, hlc)` of the family's records, so phones
    can detect withheld rows and dropped tombstones? Digests only compare
    between phones at the same state, so how should they be scoped
    (per epoch, per month of uploads)?

## 19. Changes to earlier notes

| Earlier note | Now | Why |
| --- | --- | --- |
| Records encrypted with the family key using AES-256-GCM (technical design, `20261102000003_e2ee_records.sql` comment, backend README) | XChaCha20-Poly1305 with a key derived from the family key | Random 24-byte nonces have no message-count limit for a long-lived shared key; same AEAD as backups and photos |
| Conflicts: last writer wins per record by server time | LWW per merge group by hybrid logical clocks inside the signed ciphertext, with conflict flags for clinical groups, plus compare-and-set on a server revision | Server time would let a malicious server pick winners; per-record LWW loses concurrent edits to different fields; per-field LWW would mix coupled clinical fields |
| `e2ee_records.ciphertext` up to 2 MiB | Up to 64 KiB, power-of-two padded; larger data in encrypted Storage blobs | Size metadata; photos don't belong in rows |
| `accept_family_invite(p_code)` sends the code | Sends a lookup hash; the secret proves the invitee to the owner's phone | The server must not be able to join with an invite it relays |
| Any member's session can read ciphertext; members delete their own devices freely | Only sessions bound to approved devices; removing other devices needs an approved device | Signing in alone must never give data access |
| Membership only in `family_members` | Signed family log is the source of truth; tables mirror it | The server must not be able to add members |
| "Removing a member rotates the key" | Removing members or devices, leaving, account deletion or reset, and a new recovery key all rotate; any member can rotate | Covers lost phones and members who can't be reached |
| Server-visible `record_id` is the local UUID v7; `updated_at` is the conflict clock | Random v4 sync id on the server; edit clocks only inside the ciphertext | UUID v7 and clocks told the server when each record was made and edited |
| `families.created_by … on delete cascade`; deletion blockers keyed on the creator | `on delete set null`; blockers and family deletion keyed on the owner role | After an ownership transfer, deleting the creator's account must not delete everyone's records |

`docs/security.md` S14 points here. The backend README and the migration
comments are updated by the backend follow-ups when the schema changes land.

## 20. Backend follow-ups (board cards)

Each item gets pgTAP tests (another user and an sign-in-only session can't read or
write) per the security plan's PR rules. SQL below is a sketch, not a
migration.

**B0 closes holes in grants that exist today** (`20261102000001`,
`20261102000003`, `20261102000005`). It is a **blocker before any sync code**
(also listed in `docs/security.md`), because B1's approved-device model is
only as strong as these grants:

| # | Today | Change (pgTAP test for each) |
| --- | --- | --- |
| B0.1 | `devices`: `grant update (app_version, public_key, last_seen_at)` with `devices_update_own`, so an sign-in-only session can overwrite the keys of the user's **approved** device and then bind its own session to it | Keys are immutable once set: revoke column update on `public_key` (and never grant it on `signing_public_key`); a trigger rejects any change to a non-null key |
| B0.2 | `devices`: `grant insert` on all columns | Insert only `(platform, app_version, public_key, signing_public_key)`; `status`, `approved_*`, `revoked_at` only through functions; ids server-generated |
| B0.3 | `push_tokens`: insert, update and delete cover every device of the user | Writes only for the device bound to the session (`device_sessions`), or, before binding, only for a device row the session created; the app also checks `account_resets` on every launch |
| B0.4 | `families_delete_owner`: the owner's sign-in-only session can delete the family, cascading every member's ciphertext | Family deletion only through a function that requires `device_ok()` and the owner role; no direct `delete` grant |
| B0.5 | `family_members`: direct `delete` and `update (role)`; `family_invites`: direct insert and delete | Revoke direct writes; membership changes only through `append-family-log`, invites through functions that require `device_ok()` |
| B0.6 | `e2ee_records`: direct `insert` and `update (key_version, ciphertext, deleted_at)` | Revoke; every write through `push_e2ee_records` (compare-and-set) |
| B0.7 | `families.created_by … on delete cascade`, and `account_deletion_blockers` keyed on the creator | `on delete set null`; blockers and family deletion keyed on the owner role, so an ownership transfer protects the family |

| # | Change | Card |
| --- | --- | --- |
| B0 | The B0.1–B0.7 grant fixes above | Sync backend: close existing grant and RLS gaps (blocker before sync code) |
| B1 | `devices`: add `signing_public_key bytea` (32 bytes, immutable), `status` (`pending` / `approved` / `revoked`, `revoked` final, ids never reused), `approved_at`, `approved_by_device`, `revoked_at`; status changes only through functions; delete only of the session's own device, or of others from an approved device; with sync on, sign-out revokes instead of deleting; `accounts.sync_enrolled_at` | Sync backend: device approval and session binding |
| B2 | `device_sessions(session_id, device_id, user_id, bound_at)`; `bind-device` function (Ed25519 challenge); `private.device_ok()`; unbind on sign-out | Sync backend: device approval and session binding |
| B3 | `approve-device` and `recover-device` functions with single-use server nonces; `account_recovery(user_id, salt, kdf, recovery_kx_public_key, recovery_signing_public_key)`; `account_resets` with a 7-day `pg_cron` job and cancel only from a device enrolled 7+ days before the reset; readable by the account's sessions so the app checks it on launch | Sync backend: device approval and session binding |
| B4 | `pairing_sessions` relay for the comparison code (commit, reveal, 10-minute TTL, one try, cleanup job) | Sync backend: device approval and session binding |
| B5 | `family_log(family_id, seq, prev_hash, entry bytea, sig bytea, hash, created_at)` with unique `(family_id, seq)`, `hash = sha256(entry)`; `append-family-log` function that verifies (strict Ed25519, strict JSON) and mirrors into `family_members` / `devices`; `family_heads` beacon table (one row per device, signature checked, newest only); drop the direct `update (role)` grant; `family_members.status` (`pending` / `active` / `reset`); ownership transfer; leave family through the log; lifts the `409 family_has_members` guard once hand-over exists | Sync backend: signed family log, invites and key wraps |
| B6 | `family_key_wraps(family_id, key_version, recipient_device_id, enc, ct, sender_device_id, sig)`; `family_key_history(family_id, key_version, ciphertext)` (its hash committed in `rotate_key`); `families.current_key_version`, `families.rotation_pending`; `rotate_family_key` RPC (one transaction); delete wraps of revoked devices | Sync backend: signed family log, invites and key wraps |
| B7 | `e2ee_records`: `record_id` becomes the random sync id (v4); add `revision bigint`, `format smallint`; no clock column; `ciphertext` `NOT NULL` (drop `e2ee_tombstone`'s null case); size check (power of two + 40, ≤ 64 KiB + 40); `push_e2ee_records` batch RPC with compare-and-set and stale-key checks, the only write path; `pull_e2ee_changes` returns `revision`; RLS through `device_ok()` and role (Phase 1: owner only writes); tombstone purge after 1 year | Sync backend: encrypted record push/pull and limits |
| B8 | Storage bucket `e2ee-blobs` (private), RLS on `storage.objects` by path family id + `device_ok()`, delete for writer roles only; size limit; quota per family; delete objects when a family or account is deleted | Sync backend: encrypted attachment storage |
| B9 | `accept_family_invite` takes the lookup hash; invitee key + MAC upload; pending until `add_member` | Sync backend: signed family log, invites and key wraps |
| B10 | `delete-account`, deleting a family, leaving a family and removing other devices require an approved-device session | Sync backend: account takeover protections and notifications |
| B11 | `notify` function: FCM data pushes for sync tickles (rate-limited, opaque collapse key) and fixed-text security alerts (new device, approval, recovery used, reset started) | Sync backend: account takeover protections and notifications |
| B12 | Rate limits in a shared store for every sync endpoint, pairing, recovery, invites (with S17) | Sync backend: encrypted record push/pull and limits |
| B13 | Logging settings (section 13), backup retention ≤ 30 days, restore runbook in S23: sync closed, log suffix re-uploaded, tables rebuilt from the log (section 13) | Sync backend: logging, backups and retention |

B0 has its own card, marked as a blocker. Plus one card for the external review: **"Sync: external crypto review of
the E2EE design"** (section 18).

### Implemented so far

- **B0**: `20261105000001_sync_blockers_b0.sql`.
- **B1–B4, B5, B6, B9**: `20261105000002_sync_log_devices.sql` and the Edge
  Functions `bind-device`, `approve-device`, `recover-device`,
  `append-family-log` and `publish-head` (contracts in `supabase/README.md`).
  Choices made while building them:
  - Server nonces are single-use rows in `device_challenges`, bound to the
    user, the Auth session, the purpose and the device, valid 5 minutes.
  - The recovery device is a `devices` row of kind `recovery` (no platform,
    never a session), so log entries it signs are checked like any other.
  - Per-family device state (`family_devices`) mirrors the log's current
    devices: wraps and beacons hang off it, and records, wraps, epochs and
    beacons need a session whose phone is in it. An owner's `revoke_device`
    of another member's phone therefore cuts that phone's access to the
    family at once (the open item from B0).
  - The `rotate_key` entry names its fields `key_version`, `kc`, `history`
    (SHA-256 of the history blob) and `recipients` (SHA-256 of the
    concatenated 16-byte ids of every current device, sorted bytewise).
  - The server also checks the comparison-code commitment on reveal
    (honest-server only; E checks it too).
  - Account reset: the phone that started the reset is the one that stays and
    the only one that may enrol first afterwards; cancelling needs an approved
    phone whose approval is 7+ days older than the reset.
  - A session acts only for its bound phone, or (unbound) for a never-bound
    pending phone it registered. Revoking a phone or re-binding it ends the
    old Auth sessions on the server. Approved and recovery devices are revoked,
    never deleted (B10's "revoke instead of delete", brought forward), and the
    app's sign-out revokes.
  - `family_devices` is an exact mirror of each family's log. An account-wide
    revocation only marks the device revoked; the family's rotation is
    refused until its log has the `revoke_device` entry, so the server's
    recipient set and the phones' never disagree. Revoked markers stay, so a
    device revoked in a family can't be added back.
  - Recovery tries are counted per phone (5 a day), not per account, so an
    sign-in-only session can't use up the real phone's tries.
  - After a completed reset the starting phone has 72 hours to enrol. If it
    is revoked or doesn't, the account may start a new reset (full 7-day
    wait), so a lost or signed-out phone never locks the account out.
  - A person whose only phone in a family was revoked (sign-out, theft) gets
    back in through way 3: the recovered phone appends `revoke_device` for
    the old phone and `add_device` for itself, both signed by the recovery
    device, which is a current device of that person in the log (section 7,
    "including their recovery device"), and then rotates. This also keeps an
    owner's family from freezing after the owner signs out of their only
    phone. No change to the log rules was needed.
  - Revoked device rows are purged after 90 days unless a family log lists
    them; a rotation asks for a deleted member's `remove_member` entry first
    (`member_removal_pending`) instead of failing on the recipient set.
- Still to build: B7's tombstone purge, B8, B10–B13.

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
revoke execute on function private.device_ok() from public, anon;
grant execute on function private.device_ok() to authenticated;

-- B0.1/B0.2: keys immutable, status only through functions.
revoke update on public.devices from authenticated;
grant update (app_version, last_seen_at) on public.devices to authenticated;
revoke insert on public.devices from authenticated;
grant insert (platform, app_version, public_key, signing_public_key) on public.devices to authenticated;

create or replace function private.devices_keys_immutable()
returns trigger language plpgsql set search_path = '' as $$
begin
  if (old.public_key is not null and new.public_key is distinct from old.public_key)
     or (old.signing_public_key is not null
         and new.signing_public_key is distinct from old.signing_public_key) then
    raise exception 'device_keys_immutable' using errcode = '42501';
  end if;
  return new;
end;
$$;
create trigger devices_keys_immutable before update on public.devices
  for each row execute function private.devices_keys_immutable();

-- B0.3: push tokens only for the session's own device.
drop policy push_tokens_delete_own on public.push_tokens;
create policy push_tokens_delete_own on public.push_tokens
  for delete to authenticated
  using (user_id = (select auth.uid()) and device_id = private.session_device());
-- (same shape for insert and update; private.session_device() returns the
--  device bound to the JWT's session_id, or the pending device this session
--  registered.)

-- B0.4–B0.6: no direct membership, family or record writes.
drop policy families_delete_owner on public.families;
revoke delete on public.families from authenticated;
revoke delete, update on public.family_members from authenticated;
revoke insert, delete on public.family_invites from authenticated;
revoke insert, update on public.e2ee_records from authenticated;

-- B0.7: an ownership transfer protects the family.
alter table public.families drop constraint families_created_by_fkey,
  alter column created_by drop not null,
  add constraint families_created_by_fkey foreign key (created_by)
    references public.accounts (id) on delete set null;

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
  check ((seq = 1) = (prev_hash is null)),
  entry      bytea not null check (octet_length(entry) <= 16384),
  sig        bytea not null check (octet_length(sig) = 64),
  hash       bytea not null check (octet_length(hash) = 32),  -- sha256(entry)
  created_at timestamptz not null default now(),
  primary key (family_id, seq)
);

create table public.family_heads (
  family_id  uuid not null references public.families (id) on delete cascade,
  device_id  uuid not null references public.devices (id) on delete cascade,
  beacon     bytea not null check (octet_length(beacon) <= 1024),
  sig        bytea not null check (octet_length(sig) = 64),
  updated_at timestamptz not null default now(),
  primary key (family_id, device_id)
);
-- Inserted only by append-family-log (service role); members select with device_ok().

-- B7: power-of-two padded ciphertext (40 = nonce 24 + tag 16).
-- record_id now holds the random sync id; ciphertext is required (signed tombstones).
alter table public.e2ee_records
  add column revision bigint not null default 1,
  alter column ciphertext set not null,
  drop constraint e2ee_tombstone,
  add constraint e2ee_padded check (
    octet_length(ciphertext) - 40 between 256 and 65536
    and ((octet_length(ciphertext) - 40) & (octet_length(ciphertext) - 41)) = 0);
```

## 21. Review findings and where they are addressed

From the crypto and threat review posted on PR #3 (2026-11-06).

| Finding | Change |
| --- | --- |
| **H1** removed member + server inject winning edits; header vs field clocks | §12 reader rules 4–7: body `hlc` = largest group clock; clocks after a writer's revocation or removal + 10 min rejected; clocks after an epoch's rotation + 10 min rejected; groups > 10 min ahead of the reader's own clock held; server time never trusted; property tests in §16 |
| **H2** "can't read after rotation" overstated; recovered phone has no anchor | Wording in §1, §2, §10, §14; head beacons required (§7) with fork/withholding detection and a 7-day write stop; recovered phone read-only until a fresh beacon or safety code and member-list confirmation (§7, §8 way 3, §11); residual stated in §14 |
| **H3** existing RLS / grant holes | New B0.1–B0.7 (§20) with SQL sketches and one pgTAP test each (§16): immutable device keys, restricted `devices` insert columns, push tokens only for the session's own device plus a reset check on launch, no direct family delete / membership / invite / record writes, `created_by` without cascade. Board card "Sync backend: close existing grant and RLS gaps", and listed in `docs/security.md` as a blocker before sync code |
| **H4** metadata contradictions | Clock only inside the ciphertext (§12, §4); random v4 sync ids on the server (§12, B7); authorship claim reworded to "hidden from a dump, not from the live server" (§1, §4) |
| **M1** per-field LWW splits coupled clinical fields | Merge groups per record type and a conflict flag for clinical groups (§12 Merge); property test (§16) |
| **M2** `transfer_owner` vs `created_by` cascade | B0.7: `on delete set null`, blockers and deletion keyed on the owner role (§19, §20) |
| **M3** Ed25519 differences; chain hash covers the signature | `hash = SHA-256(entry_bytes)` (§7); strict RFC 8032 verification everywhere (§5, §15); Wycheproof and "Taming the many EdDSAs" vectors run against Dart, Deno and Python (§16) |
| **M4** JSON ambiguity, HLC precision | Strict parser (no duplicate keys, size and depth caps) on phones and server; HLCs as 16-hex-digit strings; example fixed (§5, §12) |
| **M5** Stolen-account paths | Re-invite after a reset only in person, with a "reset N days ago" badge (§9); reset cancel only from a device enrolled 7+ days earlier; enrolment dates shown; pre-enrolment takeover listed as residual (§8, §14) |
| **M6** server can trigger removals | `account_deleted` / `reset` removals need a person to confirm (§7, §8); listed as a server power in §14 |
| **M7** pairing details | In-app camera only, approval prompt, screenshot warning (way 1); E posts `dkx_E`/`dsig_E` in step 2, N rechecks them in the log; phone-side attempt counters; abort on cancel or timeout (way 2) |
| **M8** recovery device | Derived keys checked against the log (§6, way 3); server KDF settings bounded like `BackupKdf.isReasonable`; labelled Argon2 input; Q5 answered; old backups and the old paper key (§6) |
| **M9** server backup restore re-approves revoked phones | Restore runbook: sync closed, log suffix + wraps + history re-uploaded by phones, tables rebuilt from the log (§13, B13); integration test (§16) |
| **M10** dropped tombstones | `ciphertext` `NOT NULL` (B7); §12 and §14 say plainly a dropped delete is invisible; state digests as Q15 |
| **M11** key history and attachments | Each recovered `FK_v` checked against `KC_v`; `rotate_key` commits to `SHA-256(history[v+1])` (§6, §7); blob GC only after a complete verified pull with a 30-day grace, delete RLS for writers only; nonce prefix stored in the record; thumbnail has its own key (§12, B8) |
| Low: concurrent appends | A second valid entry at a known `seq` is a fork (§7) |
| Low: approval replay | Server nonce in the approval signature; `revoked` final; device ids never reused (§7, §8, B1, B3) |
| Low: labels | Every label ends with `0x00` (§5) |
| Low: Q3, Q4 | Answered in §18; header rebuilt by the reader (§12) |
| Low: cared-for link | The profile link is in the owner-signed `add_member` / `change_role` entry (§7) and enforced by reader rule 3 |
| Low: SQL sketch | `grant execute` on `device_ok()`, `(seq = 1) = (prev_hash is null)`, opaque collapse key (§12, §13, §20) |
| Low: forward secrecy | New §14 row |
| Low: libraries | HPKE from `Hmac`-built labelled extract/expand, RFC 9180 A.2 vectors, `pyhpke` for the cross-check, pure-Dart X25519/Ed25519 and Argon2 timing (§15, §16) |
| Low: §17 wording | Phase 1 text corrected for an owner with two phones |
