# Security policy

Usra (أسرة) keeps a family's medical records. We take reports about its
security seriously and thank everyone who reports responsibly.

## Reporting a vulnerability

Please report privately. Do **not** open a public issue or pull request.

Use GitHub's private vulnerability reporting: open the
[Security tab](https://github.com/Opsedia-ai/usra/security)
of this repository and choose **Report a vulnerability**
([direct link](https://github.com/Opsedia-ai/usra/security/advisories/new)).
Only the maintainers see the report.

Include what you found, how to reproduce it (steps, app version, device and
OS), and the impact you think it has. English or Arabic is fine.

Please do not access, change or keep other people's data, do not test against
accounts that are not yours, and give us time to fix the issue before you
talk about it publicly.

## What we commit to

| Step | Time |
| --- | --- |
| Acknowledge your report | within 3 working days |
| First assessment and severity | within 10 working days |
| Fix for critical and high severity | within 30 days, sooner where we can |
| Fix for medium and low severity | in a following release |

We keep you updated until the issue is closed, and credit you in the release
notes if you would like.

## In scope

- The Usra mobile app (Android and iOS) built from `app/`.
- The Usra backend in `supabase/`: database policies (row-level security),
  edge functions, authentication and SMS sign-in.
- The encrypted backup format and restore.
- This repository's CI configuration and any secrets it exposes.

Examples: reading another family's records, getting health data off a locked
phone or out of a backup without the password, bypassing the database or
photo encryption, health data in logs, notifications or crash reports.

## Out of scope

- Attacks that need a rooted or jailbroken phone that is already unlocked, or
  physical access to an unlocked phone with the app open.
- Denial of service, spam and volumetric attacks.
- Social engineering of Opsedia staff or users.
- Issues in third-party services (Supabase, Google, Apple, RevenueCat, SMS
  providers) that are not caused by how Usra uses them; report those to the
  vendor.
- Missing best-practice headers or settings with no shown impact.

## Supported versions

Only the latest release in the app stores receives security fixes.

See [docs/security.md](docs/security.md) for the threat model and the
controls in place.
