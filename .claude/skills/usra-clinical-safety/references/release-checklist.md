# Release checklist and clinical safety reviewer questions

> Draft. A clinical safety reviewer must agree this before it is relied on.

Use for every build that reaches families: closed beta (TestFlight, Play internal testing) and store releases. Copy into `docs/clinical-safety/safety-case-<version>.md`.

## Clinical safety

- [ ] Clinical safety reviewer named (name, registration, specialty) and has read this version's changes.
- [ ] Hazard log re-scored for this version; no risk 4 or 5 without an accepted control; every risk 3 accepted in writing.
- [ ] Safety case report written and signed (reviewer and founder, with dates).
- [ ] Incidents since the last release reviewed and closed or carried into the hazard log.

## Medical content

- [ ] Every medical string changed since the last approval is in `docs/medical-review-changes.md` and approved by the right specialist (paediatrician, obstetrician, geriatrician or GP), in Arabic and English, in both sexes where it varies.
- [ ] Sources over 12 months old re-checked; no "unverified" statement shipped without the doctor's explicit approval.
- [ ] The "not a medical device" line is in the app (About) and in both store descriptions, with Google Play's exact wording.

## Behaviour on real phones

- [ ] Reminders ring on time after reboot, on at least one Xiaomi, Oppo or Samsung phone and an iPhone (risks T1, T2).
- [ ] Emergency call buttons dial 123 (risk T5); the lock-screen emergency card opens.
- [ ] VoiceOver and TalkBack read the warning cards and the Taken button in Arabic and English (risk T5).
- [ ] A fresh install and a restore from backup on another phone work (risks T3, T4).
- [ ] Largest font and Simple Mode: nothing cut off on warning cards and reminders.

## Calculations

- [ ] All medical calculation tests pass, including boundary tests (`calculations.md`).
- [ ] Plausibility checks exist for every typed medical number in the release, or the gap is in the hazard log with a control.

## Privacy and stores

- [ ] Apple privacy label, Play Data safety form and the privacy policy match the code.
- [ ] Health apps declaration complete in Play Console.
- [ ] No health data in iCloud, logs, notifications (discreet mode), widget or URLs.
- [ ] The lawyer's answers recorded before any real family signs in (risk L1).

## Questions for the clinical safety reviewer

1. Will you act as Usra's clinical safety reviewer (in the DCB0129 sense)? What registration should we record?
2. Do you agree with the process in `risk-process.md`, including the DCB0129 example severity, likelihood and risk scales?
3. Please score every hazard in `docs/clinical-safety/hazard-log.md`. Which are acceptable for a 50-family closed beta, and which must be fixed first?
4. Is a written safety case needed before the closed beta, or is a signed hazard log enough for 50 invited families?
5. Which of the grey features in `samd-boundary.md` (vaccine schedule by age, growth percentiles, fever signs matched to readings) worry you most, and what wording keeps them informational?
6. Is the two-level escalation (123 now, or a doctor now) right, and who decides the level for each sign?
7. Is the incident process workable, and how fast must a risk-4 fix reach families?
8. Should the doctor who reviewed the wording on 7 Nov 2026 be asked to re-review everything changed since (PRs 51 to 71)?
9. Which specialties are missing? We have a paediatrician and an obstetrician planned; older-adult content has no reviewer.
