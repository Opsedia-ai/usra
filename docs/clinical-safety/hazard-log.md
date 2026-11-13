# Usra hazard log

Version 0.1 · 12 November 2026 · **Draft. Every entry is awaiting clinical review.**

No clinical safety reviewer has scored or approved this log. The severity, likelihood and residual risk below are the build team's proposals, made with the DCB0129 example scales and matrix in `.claude/skills/usra-clinical-safety/references/risk-process.md` (risk 1 acceptable, 5 unacceptable). Severity and likelihood are judged with the listed controls in place, so the residual risk is their product in the matrix; where a control is only proposed, both scores are given. The reviewer decides the real scores, and must sign each version before a release reaches families.

Built from `docs/risks.md` (the medical-safety items M1 to M11 and the data-loss items D1 to D11), the bugs found so far (B1 to B3), and gaps found while writing the clinical skills (N1 to N4). Keep the IDs; `docs/risks.md` stays the project-wide risk list and this log is its clinical view.

Clinical safety reviewer: **not named.** Approved by: **nobody yet.**

## Medical safety

| ID | Hazard | Cause | Effect | Severity | Likelihood | Controls | Residual risk | Owner | Status |
|---|---|---|---|---|---|---|---|---|---|
| HZ-M1 | Medical text reaches families unreviewed | The reviewing doctor's name, specialty and date aren't recorded; text changed after 7 Nov 2026 (PRs 51-71); no geriatrician or GP for older-adult content | Wrong or unclear guidance is acted on | Considerable | Medium | `docs/medical-review-changes.md` lists changes; PRs list new wording; content governance in `usra-clinical-safety` | 3 | Founder | Awaiting clinical review |
| HZ-M2 | Hours between doses or the same-ingredient line is wrong or read as dose advice | Family types the hours, or accepts a figure read from the instructions; another medicine with the same ingredient isn't noticed | Overdose or too-early dose, notably of paracetamol | Major | Low | Hours only from the family's own field; one-figure parse only, never ranges; "Check other medicines with the same ingredient"; no reminder without the field | 3 | Founder, doctor | Awaiting clinical review |
| HZ-M3 | False reassurance | A label such as "fine" or a green "good" colour; nothing matched on the warning card | A family delays care for a sick person | Major | Low | Banned words; standard closing line on warning cards; Home and Fever rebuilt. Growth in-range still uses `Severity.good` (green), see HZ-N3 | 3 | Doctor | Awaiting clinical review |
| HZ-M4 | A dose or record goes to the wrong person | Shared phone; several people's doses at the same time; discreet notifications hide names | Missed or double dose; wrong history shown to a doctor | Considerable | Low | Person shown in forms; discreet Taken only when no other dose is due within an hour | 2 | Build | Awaiting clinical review |
| HZ-M5 | A clustered discreet reminder offers only Snooze | Founder's choice: no Taken when other doses are close | Dose forgotten or marked late | Significant | Medium | Snooze; dose shows as missed on Home; to watch in the beta | 2 | Founder | Awaiting clinical review |
| HZ-M6 | Moving a record goes wrong | Moving a medicine to another person | Reminders or photos under the wrong person | Considerable | Low | Confirmation naming both people (being built) | 2 | Build | Awaiting clinical review |
| HZ-M7 | Photo reading misreads a medicine | On-device OCR of printed Latin; name or strength misread | Wrong medicine or strength in a reminder | Major | Low | Person must confirm every value; PR 12 needs re-checking | 3 | Build | Awaiting clinical review |
| HZ-M8 | Emergency card out of reach | A responder can't open Usra on a locked phone | Allergies or medicines unknown in an emergency | Considerable | Medium | Opt-in lock-screen card; advice to use the phone's Medical ID | 3 | Build | Awaiting clinical review |
| HZ-M9 | Wrong ambulance number or schedule outside Egypt | Saudi or Jordan settings used before they're wired and reviewed | Delayed emergency help; wrong vaccine dates | Major | Very low | Saudi Arabia and Jordan disabled | 2 | Build | Awaiting clinical review |
| HZ-M10 | A moved prescribed medicine loses its prescription and sick-day links | Moving one medicine out of a prescription | Incomplete history for the doctor | Significant | Low | Known; moving a whole prescription under discussion | 2 | Founder | Awaiting clinical review |
| HZ-M11 | Pregnancy danger signs offer only the ambulance, not "call my doctor" | A pregnancy has no link to a doctor | Over- or under-escalation for signs that need the obstetrician, not 123 | Considerable | Low | Ambulance button shown; question for the obstetrician | 2 | Doctor, Build | Awaiting clinical review |
| HZ-M12 | Vaccines recorded that the child never had | "Mark everything due so far as given" (founder's decision, 13 Nov 2026) ticks every dose due by the child's age, the optional paid ones too, ticked by default, each on its schedule day | Reminders stop for a dose never given; the doctor summary and vaccination record list it as given; a family may skip a private vaccine (rotavirus, PCV) the child needs | Considerable | Medium | Dialog states the child's age and the count; optional ones under one tick with "untick if she didn't have them"; "check the card first, the card and the child's doctor are the reference"; undo in the snack bar; any dose can be unticked later; never a dose whose day is after today | 3 | Founder, paediatrician | Awaiting clinical review |

## Data loss

Lost records harm care indirectly: the doctor loses allergies, medicines and vaccine history.

| ID | Hazard | Cause | Effect | Severity | Likelihood | Controls | Residual risk | Owner | Status |
|---|---|---|---|---|---|---|---|---|---|
| HZ-D1 | All records lost after a forgotten PIN | PIN set with no backup | Allergies, medicines and vaccines unknown | Significant | Low | PIN needs a backup first (merged); not tested on a real phone | 2 | Build | Awaiting clinical review |
| HZ-D2 | Backups can't be opened | Recovery key lost | As D1 | Significant | Medium | By design; plan asks people to type part of the key before the first upload | 2 | Build | Awaiting clinical review |
| HZ-D3 | Stuck on "unavailable" with a damaged database | Database damage | No access to records when needed | Significant | Low | Restore, support address and warned start-fresh (being built) | 2 | Build | Awaiting clinical review |
| HZ-D4 | Start-fresh wipes records by mistake | Tapped when a retry or restore would work | As D1 | Significant | Low | Warning naming what is lost | 2 | Build | Awaiting clinical review |
| HZ-D5 | Lost phone with no backup | No backup made | As D1 | Significant | Medium | Folder backup; monthly reminder; server backup planned | 2 | Build | Awaiting clinical review |
| HZ-D6 | A near-empty backup replaces a good one | Backup after data loss | A later restore brings back almost nothing | Significant | Low | Guard for folder backups; must also cover the server | 2 | Build | Awaiting clinical review |
| HZ-D7 | Records-only restore has missing photos | Restore of a records-only backup | Prescription or report photos missing | Minor | Medium | Planned | 2 | Build | Awaiting clinical review |
| HZ-D8 | People think photos are in the server backup | Records-only server backup | Photos lost with the phone | Minor | Medium | Screen must say so | 2 | Build | Awaiting clinical review |
| HZ-D9 | No server copy while the VPS is down | VPS failure | Recent records not recoverable for a while | Minor | Low | Phone holds the main copy; last upload date shown | 1 | Build | Awaiting clinical review |
| HZ-D10 | Damage deep in the database isn't caught | No full check at start (founder's decision) | App opens but data fails to load, no Restore screen | Significant | Very low | Accepted risk; revisit if seen in the beta | 1 | Founder | Awaiting clinical review |
| HZ-D11 | Restore saves a new key over an unreadable one | Replace-everything restore | Old data permanently unreadable if the restore was wrong | Significant | Low | Key saved only after the restored data opens; needs a real-phone test | 2 | Build | Awaiting clinical review |

## Bugs found so far

| ID | Hazard | Cause | Effect | Severity | Likelihood | Controls | Residual risk | Owner | Status |
|---|---|---|---|---|---|---|---|---|---|
| HZ-B1 | Wrong overdue count and next vaccine visit | A dose logged from an overdue card without a date was saved as given today; the catch-up plan then pushed later doses; the next-visit card labelled all doses with the first dose's age (founder's phone test, 12 Nov 2026, bug A) | A 2-year-old was shown 4-month doses due in December, with MMR 2 among them; a family could delay catch-up or think the child is up to date | Considerable | Low | Fixed in PR #66 (merged): undated doses take their schedule day, only the first missing dose is overdue, catch-up doses labelled, tests with a fixed clock. PR #68 (merged) shows optional doses. Records already saved with today's date stay wrong until edited | 2 | Build | Awaiting clinical review |
| HZ-B2 | Impossible growth values accepted | Growth entry accepts any positive number (`growth_check.dart`, `growth.dart`); no unit or plausibility check | A typo (300 cm, weight in grams) gets a percentile and "outside the usual range", or a real problem is hidden among bad data; wrong values reach the doctor summary | Significant | High | None yet. Proposed: refuse WHO-implausible z-scores (length ±6, weight -6/+5, head and BMI ±5, per WHO `anthro`), ask "Is this right?" beyond ±3, unit questions | 3 now, 2 with the proposed controls | Build | Awaiting clinical review |
| HZ-B3 | Danger signs in the wrong gender | Fever warning signs (`warnSign` in `app_ar.arb`) are masculine only, so a girl or a woman reads "نعسان", "سنه", "حرارته"; the pregnancy danger title "روحي المستشفى فورًا" is feminine even when a male user (the husband) reads it | Confusion about whom a sign applies to; loss of trust in urgent text | Minor | Very high | None yet. Proposed: `sex` select on every sign (the person's sex) and on addressed text (the user's sex), widget tests for both, doctor and Arabic-reader review | 3 now, 1 with the proposed controls | Build | Awaiting clinical review |

## Found while writing the clinical skills

| ID | Hazard | Cause | Effect | Severity | Likelihood | Controls | Residual risk | Owner | Status |
|---|---|---|---|---|---|---|---|---|---|
| HZ-N1 | Preterm babies compared with term norms | No corrected age, though PRD F9 asks for it | False "outside the range" or "talk to your pediatrician" on growth and milestones, or a real concern dismissed as prematurity | Significant | Medium | None. Proposed: corrected age, or a line saying the screen uses the birth date | 2 | Build, paediatrician | Awaiting clinical review |
| HZ-N2 | Fever list misses NICE high-risk signs | Warning list built from NHS, AAP and WHO; NICE NG143 red signs (weak, high-pitched or continuous cry; bulging fontanelle; grunting) and amber signs (rigors; swollen limb or joint, not using a limb) are missing | A parent isn't prompted to get urgent help | Major | Low | Closing line "even if nothing here matches"; proposed additions wait for the paediatrician | 3 | Paediatrician, Build | Awaiting clinical review |
| HZ-N3 | In-range growth shown as green "good" | `GrowthReading.severity` returns `Severity.good` | Read as "your child is fine" (see HZ-M3) | Significant | Medium | Wording says "within the reference range"; proposed neutral colour | 2 | Paediatrician, Build | Awaiting clinical review |
| HZ-N4 | One fever threshold for every thermometer site | 38 °C used for armpit, ear, forehead, mouth and rectal; NICE (axillary or tympanic under 5, not rectal or oral) and AAP (rectal for babies) disagree | A fever missed or over-called in a baby | Considerable | Low | Under-3-months armpit sign at 37.5 °C; note that armpit readings run lower | 2 | Paediatrician | Awaiting clinical review |

## Sign-off

| Version | Date | Clinical safety reviewer (name, registration) | Founder | Notes |
|---|---|---|---|---|
| 0.1 | 12 Nov 2026 | - | - | Initial draft from `docs/risks.md` and known bugs |
