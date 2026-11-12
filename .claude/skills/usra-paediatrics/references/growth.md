# Growth

> Draft. Not reviewed by a doctor. A paediatrician must sign off before this is relied on.

Code: `app/lib/features/children/growth.dart`, `growth_check.dart`, `who_growth_data.dart`.

## Which tables

| Age | Reference | Indicators | Status |
|---|---|---|---|
| 0-60 months | WHO Child Growth Standards (2006; head circumference 2007) | weight-for-age, length/height-for-age, head circumference-for-age, BMI-for-age, weight-for-length/height | Verified 2026-11-12 (WHO page, `anthro` package) |
| 61-228 months (5-19 years) | WHO Growth Reference 2007 | BMI-for-age, height-for-age, weight-for-age (5-10 years only) | Verified 2026-11-12 (WHO page). **Not in the app.** Weight-for-age stops at 10 years |

- Use the child's sex from the profile. Never guess it.
- **Length or height:** WHO tables use recumbent length under 24 months and standing height from 24 months. When the measurement type is known and doesn't match the age, WHO's `anthro` software adds 0.7 cm (standing height under 24 months) or subtracts 0.7 cm (length from 24 months). The app currently switches tables at 24 months but doesn't ask how the child was measured. Ask the paediatrician whether to ask.
- **Age:** WHO's month is 30.4375 days. The app already uses it.

## Percentiles or z-scores

- **Show percentiles to families** ("percentile 15"), with the reference named. z-scores are for the doctor's report and for checks in code.
- The app labels the 3rd and 97th percentiles as the edge of the reference range (z ≈ ±1.88). WHO's prevalence indicators (stunting, wasting, overweight) use z-score cut-offs of -2, -3 and +2 (the `anthro` package's prevalence code uses -2 and +2; the full WHO definitions weren't opened in this session: **unverified**). **Which cut-off Usra should show is a paediatrician question.** Until answered, keep the current wording: "Within the reference range for this age (percentile {p})" or "Outside the usual range. Talk to your pediatrician."
- **One measurement is never a verdict.** Crossing percentile lines between visits matters more than one value. The app doesn't detect crossing yet; don't add it without the paediatrician.
- **Don't colour an in-range value green "good".** `GrowthReading.severity` returns `Severity.good` today, which reads as reassurance (risk M3). Prefer the neutral info colour. Paediatrician question.

## Plausibility checks (catching typing mistakes)

The app accepts any positive number today (hazard H-B2: a height of 300 cm or a weight of 90 kg for a baby is saved and plotted). Add two layers:

1. **Refuse values WHO flags as biologically implausible.** WHO's official `anthro` package (v1.1.0, maintained by WHO, CRAN 2026-01-29) flags a z-score as implausible when:

   | Indicator | Flag when |
   |---|---|
   | Length/height-for-age | z < -6 or z > +6 |
   | Weight-for-age | z < -6 or z > +5 |
   | Weight-for-length/height | z < -5 or z > +5 |
   | BMI-for-age | z < -5 or z > +5 |
   | Head circumference-for-age | z < -5 or z > +5 |

   Wording: "This number looks unlikely for a child of {age}. Check the unit and the value." Offer to edit; don't save silently.

2. **Ask "Is this right?" between z = ±3 and the flag limits,** and when a new height is more than a little lower than the last one. The ±3 step and the "lower height" margin are **build-team proposals with no source**; the paediatrician sets them.

Also check units: a weight typed in grams ("3500") or a height in metres ("0.75") should get the unit question, not a percentile.

Test these with the boundary cases in `usra-clinical-safety/references/calculations.md`: exactly at each flag limit, just inside, just outside, at 0, 24 and 60 months, for both sexes.

## Never

- Never say "underweight", "overweight", "stunted", "obese" or "short" to a family. Those are diagnoses.
- Never suggest food amounts, formula volumes or supplements.
- Never compare a child with a sibling.
