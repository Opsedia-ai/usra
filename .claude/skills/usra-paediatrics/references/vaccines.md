# Vaccines and catch-up

> Draft. Not reviewed by a doctor. A paediatrician must sign off before this is relied on.

The schedule itself, its sources and its disagreements live in `docs/research/egypt-vaccine-schedule.md` (researched 2026-11-04). Don't copy it here; change that file and the code together. Code: `app/lib/features/children/egypt_vaccines.dart`, sources shown in the app from `egypt_vaccine_sources.dart`.

## What the schedule is built on

| Part | Source (see `sources.md`) | Status |
|---|---|---|
| Government route, birth to 18 months | Egypt MoHP, read through WHO/UNICEF WUENIC 2025 revision and dated Egyptian press reports | From the research doc, checked 2026-11-04. The MoHP has no single online schedule page we could read |
| Private hexavalent route | VACSERA announcement (Youm7, 21 Jun 2026) | From the research doc, checked 2026-11-04 |
| Minimum intervals and catch-up | US CDC catch-up schedule (addendum 2 Jul 2025), CDC PCV job aid (Jan 2025) | From the research doc, checked 2026-11-04 |
| Rotavirus age limits | WHO GACVS (2009), Rotarix label | From the research doc. Product labels not opened: **unverified** |

## How overdue and catch-up must look

These rules came out of the founder's phone test on 12 Nov 2026 (bugs A and B, PRs #66 and #68). Keep them.

1. **A dose logged without a date is dated on its schedule day,** never today, and the sheet says so: "This is the date on the schedule. Change it if it was given on another day." Dating it today pushes every later dose by the minimum interval and makes the count wrong (hazard H-B1).
2. **Only the first missing dose of a series is overdue.** Later doses of that series are "catch-up · due {date}", worked out from the minimum interval after the dose before. Don't count them as overdue on Home, on the person page or in the overdue count.
3. **A dose past its upper age limit is never overdue.** Rotavirus after 14 weeks 6 days (dose 1) or 24 weeks (last Rotarix dose) shows "Past the age limit: ask your doctor". It gets no reminder and isn't counted.
4. **A dose that's no longer needed says so** ("Not needed at this age", PCV for a late starter). Never show it as missed.
5. **Optional vaccines are never due or overdue unless the family follows them.** Show their dates as information, in a neutral colour.
6. **School doses are reminders, not due dates.** MenA+C in grade 1 of each school stage, DT in primary school (grade unconfirmed).
7. **Bulk "mark everything as given" needs a confirmation** that names the count and the age range, says the dates are schedule dates, says to check the card first, and offers undo (PR #71).
8. **Every catch-up screen ends with** "The health-office card and your child's doctor are the reference."

## Plausibility checks for vaccine dates

- A dose date can't be in the future, or before birth (already built).
- A dose can't be dated before its minimum age or minimum interval without a "Is this right?" question. **Not built.** Ask the paediatrician whether the app should accept such a record silently (a real early dose happens) or ask.

## Never

- Never say a child "is protected" or "is fully vaccinated". Say "{done} of {total} doses recorded".
- Never advise on a missed dose beyond "ask your doctor or the health office". The catch-up plan is information, not instruction.
- Never schedule a vaccine the MoHP doesn't give for free as if it were required.
