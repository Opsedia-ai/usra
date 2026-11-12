# Medical calculations

> Draft. A clinical safety reviewer must agree this before it is relied on.

Usra's medical calculations today: vaccine due dates, intervals and age limits (`children/egypt_vaccines.dart`), WHO growth z-scores and percentiles (`children/growth.dart`), fever matching by age and duration (`sick_days/fever.dart`), pregnancy weeks and due date (`pregnancy/pregnancy.dart`), pregnancy blood pressure levels, lab High/Low from the printed range (`labs/lab_report.dart`), and the family's own hours between doses (`sick_days/next_dose.dart`).

## Rules

1. **Test against the published table, not against our own output.** Expected values in a test come from the source (WHO LMS table or WHO's published percentile table, the MoHP schedule, CDC catch-up table), typed in by hand with the source and row in a comment. A test that snapshots what the code returns proves nothing.
2. **Cross-check with an independent tool where one exists.** For growth, compare a sample of z-scores with WHO's own `anthro` package (R) or WHO Anthro; record the sample and tool version in the test file.
3. **Boundaries are mandatory.** For every threshold test just below, at and just above it, with the inclusive or exclusive side stated in the test name. Typical ones:
   - Ages: day of birth, 6 weeks, 14 weeks 6 days and 15 weeks, 24 weeks, 3 months, 6 months, 24 months (length to height), 60 months, 5th, 6th and 18th birthday; 29 Feb births; month ends (31st); clock changes.
   - Temperatures: 37.4/37.5, 37.9/38.0, 38.9/39.0, 40.0/40.1, and the plausibility limits; °F equivalents.
   - Growth: z exactly at ±3, ±5, ±6 and WHO's +5 for weight-for-age.
   - Durations: 24 h, 72 h, 5 days of fever.
   - Vaccines: dose exactly at the minimum interval, one day before; route switch; late starter.
4. **Plausibility checks on every typed medical number:** refuse what can't be true, ask "Is this right?" for what is very unlikely, and test both. Prefer published limits (e.g. WHO's implausible z-score flags, see `usra-paediatrics/references/growth.md`); where none exist, write "build-team proposal, no source" next to the limit and ask the doctor.
5. **Units are explicit.** Store the unit with the value (°C or °F, kg, cm, mg/dL or mmol/L); convert once, in one place, with tests; show what was typed.
6. **Dates are calendar dates.** Use day-level UTC arithmetic for ages (as `growth.dart` does) and an injectable clock (`todayProvider`) so tests can fix "today".
7. **Rounding is stated.** Round only for display, the way the source does (thermometers to 0.1 °C; percentiles to whole numbers with "<1" and ">99").
8. **No calculation without a source line on screen.**
9. **A calculation change is a medical change:** hazard log, `docs/medical-review-changes.md` if the shown text or result changes, Production impact at least MEDIUM.

## Known gaps (in the hazard log)

- Growth accepts any positive number (H-B2).
- No corrected age for preterm babies (H-N1).
- Doses logged without a date were dated today, which broke overdue counts and the catch-up plan (H-B1, fixed in PR #66; keep its tests).
- Growth tests should be checked against WHO's own tables or `anthro`, not only against the app's LMS interpolation. Not confirmed in this review.
