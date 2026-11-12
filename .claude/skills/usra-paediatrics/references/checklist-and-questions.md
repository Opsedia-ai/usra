# Review checklist and paediatrician questions

> Draft. Not reviewed by a doctor. A paediatrician must sign off before this is relied on.

## Checklist for any child-related PR

Copy into the PR description and tick each line, or say why it doesn't apply.

**Content**
- [ ] Every medical statement has a primary source shown in the app (name and date) and listed in `sources.md` with its URL and the date checked.
- [ ] Anything without a verified source is marked "unverified" in the PR and listed for the paediatrician.
- [ ] New or changed medical text is added to `docs/medical-review-changes.md`.
- [ ] No banned words (`wording.md`), in Arabic or English.
- [ ] No dose, medicine name suggestion, food amount or supplement.
- [ ] Every warning ends in "call 123 now" or "contact a doctor now", plus the standard closing line.

**Age and sex**
- [ ] Tested at the age edges: birth day, 3 months, 6 months, 24 months, 60 months, 5th and 6th birthday, 18th birthday, and a child with no birth date.
- [ ] Under-3-months fever is handled on its own path.
- [ ] Every Arabic string about the child follows the child's sex; tested with a girl and a boy.
- [ ] A preterm baby: the screen says it uses the birth date (until corrected age exists).

**Numbers**
- [ ] Every typed number has a plausibility check (refuse, or "Is this right?"), with boundary tests.
- [ ] Calculations are tested against the reference table (WHO, CDC), not against our own code's output.
- [ ] Units: °C and °F, kg and g, cm and m are handled or questioned.

**Vaccines**
- [ ] Only the first missing dose of a series counts as overdue; catch-up doses and doses past an age limit don't.
- [ ] A dose without a typed date is dated on its schedule day, and the sheet says so.
- [ ] "The card and the doctor are the reference" is on screen.

**Safety records**
- [ ] New hazard? Add it to `docs/clinical-safety/hazard-log.md` as "awaiting clinical review".
- [ ] Production impact verdict in the self-review comment (see `usra-clinical-safety`).

## Questions to send to the paediatrician

Send with `docs/medical-review-changes.md` and the open questions in `docs/research/egypt-vaccine-schedule.md` and `docs/research/fever-warning-signs.md`.

**Growth**
1. Should the edge of the range be the 3rd/97th percentile (current) or z = ±2 (WHO's prevalence cut-off)? One term or two?
2. Should an in-range value be shown in a neutral colour rather than green?
3. Are WHO's implausibility limits (length z ±6, weight z -6/+5, head and BMI z ±5) right for refusing a value as a typo? Where should "Is this right?" start: z = ±3?
4. How much may height go down between two measurements before the app asks "Is this right?"
5. Should the app ask whether a child under 2 was measured lying down or standing (WHO's 0.7 cm adjustment)?
6. Do you want growth charts for 5-18 years (WHO 2007 reference: BMI-for-age, height-for-age)?
7. Corrected age for preterm babies: until what age, and for which screens (growth, milestones, vaccines use birth date)?

**Fever**
8. NICE red signs missing from the app: weak, high-pitched or continuous cry; bulging fontanelle; grunting. Amber: rigors; swelling of a limb or joint, or not using a limb. Add them? Which level (123 or doctor now)?
9. Under 3 months with 38 °C or more: "contact a doctor now" or "call 123"?
10. Which thermometer site should the app suggest by age in Egypt? NICE says axillary or tympanic and not rectal or oral under 5; AAP prefers rectal for babies. Should the fever label depend on the site?
11. The questions already listed in `docs/research/fever-warning-signs.md` (armpit threshold, low temperature cut-off, plain rash, AAP vs NHS durations, adult list from 18, 123 and the poison centre).

**Milestones**
12. May we add: "If your child stops doing something they used to do, talk to the doctor soon"?
13. Should a parent be able to flag "I'm worried" without any milestone missing?

**Vaccines**
14. The open items in `docs/research/egypt-vaccine-schedule.md` ("Needs medical review before release"), including OPV on the hexavalent route and the catch-up simplifications.
15. Should a dose dated before its minimum age or interval be accepted silently, or should the app ask "Is this right?"

**Wording**
16. Please check every child warning sign in both sexes once H-B3 is fixed.
17. Please give your name, specialty and review date, so the sign-off can be recorded (risk M1).
