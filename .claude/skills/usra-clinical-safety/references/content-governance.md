# Medical content governance

> Draft. A clinical safety reviewer must agree this before it is relied on.

## What counts as medical text

Any string a family could act on for health: warning signs, thresholds, schedules and their notes, growth and reading labels, milestone text, reminder and missed-dose text, pregnancy checks and danger signs, the doctor summary's notes, disclaimers, emergency text, and the sources line itself. When unsure, treat it as medical.

## The rules

1. **Sourced.** Every medical statement points to a primary source (WHO, NICE, AAP, CDC, Egypt MoHP, ADA, ESC, AHA, AGS or another peak body) recorded with its URL, version or date, and the date it was checked. Use the skill's `sources.md` or the feature's `docs/research/*.md`. A news article may confirm what the MoHP did, but say so.
2. **Unverified is written down.** If a source can't be opened or doesn't say it, mark the statement "unverified" and list it for the doctor. Never make up a source, a page number or a threshold.
3. **Shown to the family.** The app shows the source name and year next to the statement, or one tap away.
4. **Versioned.** Medical text lives in the ARB files and the feature's data file; git is the version history. Rule data (schedules, thresholds) carries the source date in code comments.
5. **Doctor-approved.** A named doctor of the right specialty approves the exact Arabic and English text before release. The approval is recorded (name, specialty, date, what was approved) in `docs/medical-review-changes.md` or the safety case.
6. **Re-reviewed on any change.** Any change after approval, even "only grammar" or digits, goes on the list in `docs/medical-review-changes.md` (table: where, before, now) with a question if needed, and back to the doctor. That file covers PRs 51-61 today; keep adding.
7. **Both languages, both sexes.** Arabic and English are reviewed together. Arabic text that changes with the person's sex is reviewed in each form.
8. **Re-checked on a schedule.** Sources over 12 months old are re-checked before the next release that relies on them, and on any known new version (e.g. a new ADA Standards each January, a new MoHP schedule).

## In a PR that changes medical text

- Add the before and after to `docs/medical-review-changes.md`.
- List the keys in the PR description, as PRs #66-#71 do ("New wording (for the Arabic reader and the doctor)").
- Raise the Production impact to at least MEDIUM.
- Don't merge a change to a warning sign's meaning (as opposed to grammar) without the doctor's answer; grammar-only fixes may merge and go on the review list.

## Status today

- The founder reports a doctor accepted the full wording on 7 Nov 2026, but the name, specialty and date aren't recorded (risk M1). Until they are, no text counts as approved.
- No geriatrician or GP is planned for older-adult content.
- Medical text changed after 7 Nov is listed in `docs/medical-review-changes.md`; PRs #66-#71 added more vaccine and wording strings that need adding there.
