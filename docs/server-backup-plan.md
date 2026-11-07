# Server backup plan

Status: planned on 7 November 2026, not built. It changes the PRD rule that Usra never stores backups on its own servers.

## Goal

A family that loses a phone can get their records back, even if they never set up a backup folder. The server holds only a file it can't read.

## What people get

- An opt-in choice on the Backup screen: "Keep an encrypted copy on Usra's server". It needs sign-in and a saved recovery key.
- A weekly automatic upload, using the existing backup schedule.
- On a new phone: sign in, tap Restore, type the recovery key.
- Records only. Photos stay in the folder backup, and the screen says so.

Folder and share-sheet backups stay as they are. They're free and they're the only backups with photos.

## Gates before any real family's backup is uploaded

1. **Lawyer's answer.** The founder has received an answer. Its text needs adding to `docs/login-setup.md`, and it must cover these points, which go beyond the original login questions:
   - Is an encrypted health backup that we can't read still sensitive personal data for us?
   - Does it need a licence or a cross-border permit, and which data centre locations are acceptable?
   - What consent wording does it need?
   - How long may we keep it after an account is deleted or goes inactive?
2. **Data centre.** Check Hostinger's location list before buying. Its plan page doesn't list them.
3. **Hostinger backup retention.** Find out how long its weekly backups keep deleted files, because deleted accounts stay in them until they roll off. The privacy policy must state that period.
4. **Real backup sizes.** Measure records-only backups with demo families before fixing the per-account limit.

## How it works

```
Phone: records-only backup -> encrypted with the recovery key -> upload with sign-in token
VPS:   checks the token -> stores the file under the account ID -> keeps the last 2
```

### On the phone

- `BackupService` gains a records-only mode that packs no photo folders.
- Encryption stays as it is: Argon2id and XChaCha20-Poly1305 from the 100-bit recovery key. The key never leaves the phone.
- The first upload asks the person to type one group of the recovery key, to show it's really written down. Losing the key loses the server copy, and we can't help.
- A restore must handle records whose photos aren't in the backup: show that a photo is missing, and don't fail.
- The existing guard for a backup that suddenly holds far less applies here too, so a near-empty backup can't push out a good one.

### On the server

A small service in this repo under `server/`, behind Caddy for HTTPS:

| Call | What it does |
|---|---|
| `PUT /v1/backup` | Stores a new file, checks its hash, then replaces the older of the two kept |
| `GET /v1/backup` | Lists the kept backups' dates and sizes |
| `GET /v1/backup/{id}` | Downloads one |
| `DELETE /v1/backup` | Deletes all of this account's backups |

- It verifies Supabase sign-in tokens and takes the account ID only from the token.
- Limits: a size per account (starting at 25 MB, to confirm from the measurement) and a few uploads a day per account.
- Logs hold no names, emails or file contents.
- Accounts, seats and subscriptions stay on Supabase Pro. Member numbers can't wait for a weekly restore.

### Deleting

- Turning the option off deletes the server copies.
- The `delete-account` function also deletes them, using a secret kept in Supabase secrets. The account isn't reported as deleted until that succeeds.
- "Delete all my data" on the phone asks separately about the server copy.

## Running the server

- SSH keys only, a firewall allowing only web and SSH, automatic security updates.
- Disk encryption doesn't replace the phone-side encryption, which is what protects the data.
- An alert at 60% and 80% disk use, and when the service stops responding.
- A restore drill before launch and every 3 months, using test accounts.

If the VPS is lost, phones still hold the main copy, so people are only exposed if they lose their phone during the outage. The screen shows the date of the last successful upload, so a failure can't stay hidden.

## Cost check: COSTS MONEY, founder approved the VPS

| | 5,000 users | 50,000 users |
|---|---|---|
| Assumption | 6 MB each, last 2 kept, weekly upload (estimate, to be measured) | Same |
| Disk | 60 GB of 100 GB, so TIGHT (over 60% once the system is counted) | 600 GB, doesn't fit |
| Bandwidth | About 120 GB a month of 8 TB | About 1.2 TB a month |
| Cost | KVM 2: $8.79 a month for 24 months ($210.96 upfront), then $14.99 | A bigger plan or separate storage, to price then |

Not everyone will opt in, so real use should be lower. If disk gets tight, keep only the latest backup: that halves it.

## What has to change in the words

- Welcome's "Your family's health stays on this phone", `docs/prd-v1.md` and `docs/product-definition.md`: true unless the person opts in. New wording goes to the Arabic reader.
- Privacy policy, terms, `docs/security.md`, `docs/store/data-safety.md`, Google Play's Data safety form and Apple's privacy label must declare the encrypted backup. Apple 5.1.3 only bars health data in iCloud, so an own server is allowed if declared.
- App Review notes can list this as an account feature, which supports required sign-in (Apple 5.1.1(v)).

## Build order

1. Gates: lawyer's text, data centre, retention, measured sizes.
2. Records-only backup and restore with missing photos, in the app. Useful even without the server.
3. The server, with tests, deployed to a test VPS using test accounts only.
4. App upload, automatic weekly upload, list and restore, depending on required sign-in.
5. Deleting, including `delete-account`.
6. Legal and store wording.
7. Real-phone test: back up on one phone, restore on another, Android and iPhone, then the restore drill.

## Still to decide

- How long an inactive account's backup stays. Suggested: warn and delete after 12 months without sign-in, if the lawyer agrees.
- Whether it's offered on first backup or only on the Backup screen. Suggested: both, always opt-in.
