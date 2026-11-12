# Review checklist and geriatrician or GP questions

> Draft. Not reviewed by a doctor. A geriatrician or GP must sign off before this is relied on.

## Checklist for any PR an older person or their caregiver will use

**Medicines**
- [ ] No interaction, duplicate, dose, Beers or STOPP check, and no wording that implies one ("safe", "OK together", green tick).
- [ ] Dose text shown word for word; nothing computed except calendar days and the family's own hours field.
- [ ] Missed-dose text states the fact only; no "take it now", "skip" or "double".
- [ ] The person a dose is for is visible wherever Taken can be pressed (subject to discreet mode rules).

**Readings (when built)**
- [ ] One guideline only, named with its year, with a source link and "one reading doesn't diagnose anything".
- [ ] The doctor's own target, if typed, is used first.
- [ ] Plausibility checks with boundary tests (values in `readings.md`).
- [ ] No green "good" or "normal" label; red flags escalate to 123 or the doctor.
- [ ] No falls risk score.

**Accessibility**
- [ ] Tested at the largest system font and in Simple Mode; nothing cut off or overlapping.
- [ ] Contrast checked in light and dark; targets 48 dp (56 dp Simple Mode) or more.
- [ ] No swipe-only, drag-only or long-press-only action; no time limit.
- [ ] Screen-reader labels in Arabic and English.
- [ ] The main action is on the first screen; irreversible actions confirm and name what's lost.

**Wording and records**
- [ ] Arabic follows the person's sex; tested for a man and a woman.
- [ ] New medical text in `docs/medical-review-changes.md`; new hazard in `docs/clinical-safety/hazard-log.md`.
- [ ] Production impact verdict in the self-review (see `usra-clinical-safety`).

## Questions to send to the geriatrician or GP

**Medicines**
1. Is "Show this list to your doctor or pharmacist at every visit. Usra doesn't check medicines against each other." the right message, in Arabic too?
2. What should the missed-dose message say, given the app can't know the medicine? Is "check the leaflet or ask your pharmacist" enough?
3. Should the medicine list include a "reason for taking it" field to help a medication review?
4. Risk M2: please confirm or reject the same-ingredient line and the family-typed hours between doses.

**Blood pressure**
5. ESC 2024 or AHA/ACC 2025 for the reference categories shown in Egypt? Office or home thresholds for home readings?
6. Which very-high reading, with or without which symptoms, should say "call 123" and which "contact the doctor today"?
7. Should a low reading or dizziness on standing be flagged, and how?

**Blood sugar**
8. Without a doctor's target, should the app show anything other than the ADA hypoglycaemia levels (below 70, below 54 mg/dL)?
9. Which low or high readings should say "call 123" and which "contact the doctor now"? May the app tell a family to give sugar for a low, and in what words?
10. mg/dL only, or also mmol/L?

**Falls**
11. Is the falls log (date, where, injury, could they get up, lost consciousness) the right content for you?
12. After which kind of fall should the app say "call 123" rather than "tell your doctor"?

**Simple Mode and cognition**
13. Should Simple Mode keep an emergency button (open PRD question)?
14. Should Simple Mode show readings and their labels at all, or only record them?
15. Is a caregiver pressing Taken on the older person's behalf acceptable without recording who pressed it?

**Sign-off**
16. Please give your name, specialty and review date.
