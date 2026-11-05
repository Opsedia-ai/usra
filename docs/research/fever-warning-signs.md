# Fever warning signs (C8)

> **Status: needs medical review.** This list was put together from the
> public sources below on 2026-11-05 by the development team, not by a
> doctor. A pediatrician (ideally one practising in Egypt) should check
> every line, the thresholds and the Arabic wording before release. Until
> then the card says it is for information only.

The sick-day page shows these signs for the person's age, with the ones
that what the family logged matches (a ticked symptom, a reading, how
long the fever has lasted) at the top. Every sign says to get help now:
the emergency ones say to call an ambulance (123 in Egypt, the number on
the emergency card) and the others to contact a doctor now. The card
always adds: "For information only, not a diagnosis. If you're worried,
contact a doctor or call 123, even if nothing here matches."

The app never suggests a medicine, an amount or a time. Code:
`app/lib/features/sick_days/fever.dart` (rules), texts in
`app/lib/l10n/app_*.arb` (`warnSign`).

## Sources

| Key | Source | URL |
| --- | --- | --- |
| NHS | NHS (UK), "High temperature (fever) in children" | https://www.nhs.uk/conditions/fever-in-children/ |
| NHS adults | NHS (UK), "High temperature (fever) in adults" | https://www.nhs.uk/conditions/fever-in-adults/ |
| AAP | American Academy of Pediatrics, healthychildren.org, "When to Call the Pediatrician: Fever" | https://www.healthychildren.org/English/health-issues/conditions/fever/Pages/When-to-Call-the-Pediatrician.aspx |
| WHO | WHO, Integrated Management of Childhood Illness (IMCI), module 1 "General danger signs for the sick child" | https://www.who.int/publications/i/item/9789241506823 |
| St Louis | St. Louis Children's Hospital, "Fever: how to take a temperature" (armpit, mouth, rectal, ear and forehead readings) | https://www.stlouischildrens.org/health-resources/symptom-checker/fever-how-take-temperature |
| Woman's | Woman's Hospital, "Newborn temperature and fever" (low temperature in a newborn) | https://www.womans.org/services/pregnancy-childbirth/new-parent/newborn/temp-fever |

Read on 2026-11-05. The NHS adults page only says to get urgent advice
when a high temperature isn't improving or is getting worse.

## Fever threshold

38.0 °C (100.4 °F) or higher counts as a fever (NHS, AAP). Readings are
kept as read, in °C or °F, with where they were taken (armpit, ear,
forehead, mouth, rectal), rounded to one decimal as a thermometer shows
them, so the number on screen and the "Fever" label always agree. Commas
(Latin `,` or Arabic `،`) and the Arabic decimal point `٫` are accepted.
Readings outside 30–43 °C are refused as likely typos; below 34 °C or
above 42 °C the form asks "Is this right?" before saving.

The fever label uses 38 °C for every site. Under 3 months, the card adds
"Armpit readings run lower. If your baby feels hot or seems unwell, call
the doctor even below 38 °C.", and an armpit reading of 37.5 °C or more
is a "contact a doctor now" sign (below).

## Call an ambulance (123) now

Shown for every age.

| Key | Sign | Sources | Matched from |
| --- | --- | --- | --- |
| breathing | Hard to breathe, breathing very fast or breathless | NHS, AAP, WHO | symptom "Hard to breathe" |
| seizure | A fit (seizure) | NHS, AAP, WHO (convulsions) | symptom "Fit (seizure)" |
| rashGlass | A rash that doesn't fade when you press a glass on it | NHS | symptom "Rash that doesn't fade under a glass" |
| drowsy | Very drowsy or hard to wake, or not responding as usual | NHS, AAP, WHO (lethargic or unconscious) | symptom "Very drowsy or hard to wake" |
| stiffNeck | A stiff neck, or light hurts the eyes | NHS, AAP | symptom "Stiff neck" |
| skinColour | Blue, grey, very pale or blotchy skin, lips or tongue, or unusually cold hands and feet | NHS | not matched |
| confused | Confused, or very agitated and won't stop crying | NHS | not matched |
| notDrinking | Not drinking, not feeding or breastfeeding, or not acting like themselves | NHS (999: "not interested in feeding"), WHO (unable to drink or breastfeed) | symptom "Eating or drinking less" |
| vomitsEverything | Vomits everything, or keeps vomiting | AAP (repeated vomiting), WHO (vomits everything) | not matched (the "Vomiting" symptom alone isn't a sign) |

Review question: NHS lists these under "call 999" for children. We show
them for adults too, as they are also signs of meningitis and sepsis in
adults (NHS meningitis and sepsis pages). Confirm.

## Contact a doctor now

| Key | Sign | Ages shown | Sources | Matched from |
| --- | --- | --- | --- | --- |
| under3Months | Under 3 months old with 38 °C (100.4 °F) or higher | under 3 months, unknown age | NHS, AAP | any reading ≥ 38 °C taken before 3 months of age |
| armpitUnder3Months | Under 3 months old with an armpit reading of 37.5 °C (99.5 °F) or higher | under 3 months, unknown age | AAP, St Louis | an armpit reading ≥ 37.5 °C before 3 months (**needs medical review**: AAP-based guidance uses 37.2 °C (99 °F) for an armpit fever) |
| lowUnder3Months | Under 3 months old with a temperature below 36 °C (96.8 °F) | under 3 months, unknown age | Woman's | any reading < 36 °C before 3 months (**needs medical review**: the right cut-off) |
| months3to6 | 3 to 6 months old with 39 °C (102.2 °F) or higher | 3–6 months, unknown age | NHS | any reading ≥ 39 °C taken at 3–6 months |
| longUnder2 | Under 2 with a fever for more than 24 hours | under 2, unknown age | AAP | fever duration > 24 h |
| longChild | 2 or older with a fever for more than 3 days | 2–17, unknown age | AAP | fever duration > 72 h |
| fiveDays | A fever that has lasted 5 days or more | children | NHS | fever duration ≥ 5 days |
| veryHigh | Above 40 °C (104 °F) more than once | children | AAP | two or more readings > 40 °C |
| notImproving | A high temperature that isn't getting better, or is getting worse | adults (18+), unknown age | NHS adults | not matched |
| dehydration | Signs of dehydration: fewer wet nappies or peeing less, no tears, sunken eyes, dry mouth | everyone | NHS, WHO | symptom "Fewer wet nappies, peeing less or no tears" |

Without a date of birth the card shows the signs of every age and a link
to add one ("Add a date of birth to see the signs for this age");
readings can't be matched to an age then.

"Fever duration" runs from the first reading at or above 38 °C to the
last one, or to now when the latest reading is still a fever and the sick
day hasn't been marked over. It only counts readings the family logged.

Review questions:
- "Not drinking / not feeding" and "vomits everything" were moved to "call
  123" (NHS 999 list, WHO IMCI general danger signs). Confirm.
- Armpit threshold for babies: 37.5 °C here; AAP-based guidance says
  37.2 °C (99 °F) armpit, 37.8 °C (100 °F) mouth, 38 °C rectal, ear and
  forehead, and recommends rectal readings for babies. Should the fever
  label itself depend on the site?
- Low temperature under 3 months: is 36 °C the right cut-off, and is it
  "contact a doctor now" or "call 123"?
- NHS 111 lists "other signs of illness, such as a rash, alongside a high
  temperature"; the plain "Rash" symptom isn't matched. Add it?
- AAP's durations (24 h under 2, 3 days from 2) are stricter than NHS's 5
  days; we show both. Is that confusing?
- Ages are counted in calendar months from the birth date, with no
  correction for prematurity.
- Is 18 the right age to switch to the adult list?
- Egypt: is 123 the right number to show everywhere, and should the card
  mention the poison centre for suspected medicine overdose?

## "N hours after this dose"

Not a warning sign, listed here for the medical review. A medicine can
carry "Minimum hours between doses", typed by the family from the label
or the doctor (whole or decimal hours, 0.5 to 72). When a medicine given
in a sick day is one of the person's saved medicines and that field is
set, the entry keeps those hours as they were when it was saved, and the
page shows "6 hours after this dose: 14:00" with "Check other medicines
with the same ingredient before giving another dose", plus "Remind me at
that time". Without the field: no time, no reminder, and a pointer to the
medicine's page. A later dose of the same medicine without a reminder
cancels an earlier one's.

The medicine form may offer a figure read from the instructions ("The
instructions say “كل ٦ ساعات”. Use 6 hours?"), only when there is exactly
one hour figure after "every", "each", "q" or "كل" (or before "apart"),
decimals read in full (6.5 stays 6.5). Ranges ("every 4-6 hours", "every
4 hrs to 6 hrs"), alternatives ("كل ٦ ساعات أو ٨ ساعات") and limits ("up
to 3 times every 24 hours", "max", "مرات") give none. It fills the field
only when the family taps Use. Code: `app/lib/features/medicines/min_hours.dart`,
`app/lib/features/sick_days/next_dose.dart`.
