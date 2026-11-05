# Competitor review: Jojo – Child Health Records

Checked on 2026-11-04. Sources:
[App Store (Egypt)](https://apps.apple.com/eg/app/jojo-child-health-records/id6824950489),
[website](https://jojohealth.app), [privacy policy](https://jojohealth.app/privacy/).

## The app

- **Jojo: Child Health Records** ("Vaccines, medicines & labs"), by Ahmed
  Musallam, an independent developer in Cairo. iOS only (iOS 18+); the privacy
  policy mentions Android but there is no Play listing yet.
- Released 30 Oct 2026; v1.2 on 4 Nov 2026. 2 ratings (5.0), no written
  reviews yet.
- Arabic and English. Listed in Egypt, KSA, UAE, Jordan, Kuwait, Qatar, Oman,
  Bahrain, Lebanon, Morocco.
- Free, no ads, no purchases. The site says "free for the first 100
  families", so a paid plan is likely.
- No account; data on the phone; backup through the phone's own iCloud or
  Google backup; opt-in anonymous analytics (PostHog EU).

It is aimed at the same people as Usra (Egyptian parents who want records on
the phone, in Arabic, without an account), but is narrower: vaccines,
medicines and lab results for children.

## What Jojo has

- **Vaccines:** Egypt MoH / VACSERA schedule with required and optional
  vaccines (PCV, rotavirus) and the hexavalent route; overdue flags; one-tap
  "given"; tick what was already given when adding a child; a "12/12 required
  done" counter with filters; a Home card counting days to the next vaccine
  visit; notes per vaccine. Other countries: manual entry.
- **Medicines:** a prescription with doctor, diagnosis and several medicines
  (dose, frequency, duration); today's doses on Home with check boxes and "day
  3 of 7". Push reminders not stated.
- **Lab results:** photo or PDF of a lab report read on the device; values with
  the printed reference range and Low/High flags; low-confidence values
  highlighted for checking; original kept.
- **OCR:** vaccination cards, prescriptions and lab reports, confirmed before
  saving.
- **Fever log** (privacy policy only, may not be released): temperatures,
  medicine given, a reminder, and a lock-screen status with the child's name
  and temperature.
- Several children (and adults), one timeline, age in years and months,
  delete all data.

Not found: growth charts, milestones, feeding/sleep/diaper log, pregnancy,
check-up schedules, emergency card, reminders with actions, PDF export,
sharing with a caregiver, app lock.

## Side by side

| | Jojo | Usra |
| --- | --- | --- |
| Egypt vaccine schedule | Required + optional, hexavalent route | Required (MoHP) only |
| Tick off given vaccines at setup | Yes | No |
| Next-vaccine countdown on Home | Yes | Follow-up card, less visible |
| Vaccine certificate / PDF | No | No |
| Growth (WHO) | No | Weight, height; head not charted |
| Milestones (CDC) | No | Yes |
| Feeds / sleep / diapers | No | Yes (under 1) |
| Fever log | Maybe | No |
| Medicines | Prescription with several medicines, day N of M | One medicine at a time, **reminders with Taken/Snooze**, widget |
| Lab results | OCR, ranges, flags | One value typed by hand |
| OCR | Lab reports, vaccine cards, prescriptions | Medicine box name only |
| Pregnancy | No | Yes |
| Check-ups and screenings | No | Yes (AAP for children, adult screenings) |
| Emergency card | No | Yes |
| Backup | Phone backup only | Encrypted file with recovery key, any platform |
| Security | iOS data protection | Encrypted DB and photos, app lock (in review), discreet mode |
| Android | Not yet | Yes |
| Elders, insurance, spending, doctors | No | Yes |

## Proposals

Ordered by value to Egyptian parents and how directly they answer Jojo. Every
medical schedule must cite its source and be checked against the current
MoHP schedule before release; nothing here calculates doses (Apple 1.4.2).

| # | Proposal | Why | Size |
| --- | --- | --- | --- |
| C1 | **Full Egypt vaccine schedule**: optional/private vaccines (PCV, rotavirus, varicella, hepatitis A, MenACWY, flu…) and a choice of government (penta + IPV) or private (hexavalent) route per child; source and date shown | Jojo's main strength; families on the private route see wrong "missing" doses today | M |
| C2 | **Vaccine setup and progress**: when adding a child, tick vaccines already given (with optional dates); a counter "10/12 required done", filters, notes per dose | Fast start for a child who isn't a newborn | S |
| C3 | **Next vaccine on Home** with a countdown and **vaccine reminders** (a week before and on the day, discreet text) | Jojo shows it; we can go further with real reminders | S |
| C4 | **Vaccination record PDF** to share with school, nursery or a doctor (WhatsApp), Arabic and English | Neither app has it; parents are often asked for it | M |
| C5 | **Prescription entry**: one prescription with doctor, diagnosis and several medicines, each with dose, times and duration ("day 3 of 7"), creating the reminders in one go | Common case after a paediatric visit; today it's one medicine at a time | M |
| C6 | **Document OCR** on the device: prescriptions (pre-fill C5), vaccination cards (pre-fill C2), lab reports (C7); confirm screen with unsure values highlighted; original photo kept encrypted | Jojo's second strength; we already ship ML Kit | L |
| C7 | **Structured lab results**: several tests per report with value, unit, the lab's printed range and a High/Low flag; trend chart per test | Our lab record is one value typed by hand | M |
| C8 | **Fever and sick-day log**: temperature readings, medicine given and when (no dose advice), a "next dose allowed after" reminder only from the user's own prescription, age-based warning signs with sources (e.g. fever under 3 months → see a doctor) | Very common need; Jojo is preparing it | M |
| C9 | **Head circumference chart** (WHO 0–5 years) next to weight and height | We record it but don't chart it | S |
| C10 | **Child summary for the doctor**: one-page PDF (growth, vaccines, allergies, medicines, recent visits) | Builds on C4; useful at every visit | M |

Positioning (store texts and marketing):
- Say what Usra does that Jojo doesn't: reminders that ring, growth and
  milestones, the whole family including grandparents and pregnancy,
  encrypted backup you can move to a new phone, and Android.
- Like Jojo, say "no account needed" in the first screenshot.

Suggested order: C1 + C2 + C3 together (one vaccine release; built in Nov 2026, schedule research in `egypt-vaccine-schedule.md`), then C5 + C9,
then C6 + C7 (C7 and the lab-report part of C6 built in Nov 2026: `app/lib/features/labs/`;
prescription and vaccination-card OCR still to do), then C4 + C10, then C8.
