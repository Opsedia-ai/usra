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

## Full feature comparison (5 Nov 2026)

Jojo v1.2 (store listing, release notes, website, privacy policy; it was #2 in
Egypt's Top Free Medical apps that day) against Usra's `main` plus open PRs.
Hands-on screenshots of Jojo are still to be added: iPhone Mirroring needs
iCloud on the Mac.

✅ has it · ◐ partly · — no · PR = built, in review

| Area | Feature | Jojo | Usra |
| --- | --- | --- | --- |
| **Family** | Several children | ✅ | ✅ |
| | Adults and grandparents | ✅ | ✅ |
| | Simple Mode for elders (big controls) | — | ✅ |
| | Guided tutorial (Dr. Usra) | — | ✅ |
| **Vaccines** | Egypt MoHP/VACSERA schedule, required + optional | ✅ | ✅ |
| | Government vs private (hexavalent) route | ✅ | ✅ |
| | Tick vaccines already given when adding a child | ✅ | ✅ |
| | Next vaccines on Home | ✅ | ✅ (countdown) |
| | "Date passed but not recorded" wording | ✅ | ✅ (overdue / too late, ask the doctor) |
| | Vaccine reminders (week before, on the day) | — | ✅ |
| | Age limits and minimum gaps (rotavirus, catch-up) | ? | ✅ |
| | Notes per dose | ✅ | ✅ |
| | Read a vaccination card from a photo | ✅ | PR #12 |
| | Vaccination record PDF to share | — | ✅ |
| | Other countries: record vaccines by hand | ✅ | ✅ |
| **Medicines** | Prescription with doctor, diagnosis, several medicines | ✅ | ✅ |
| | Dose, how often, how long; "day 3 of 7" | ✅ | ✅ |
| | Today's doses on Home, tick when given | ✅ | ✅ |
| | Reminders that ring, with Taken/Snooze | — (not stated) | ✅ |
| | Home-screen widget | — | ✅ (Android; iOS PR #10) |
| | Discreet notifications (no names) | — | ✅ |
| | Medicine box photo → name | — | ✅ |
| | Read a prescription from a photo | ✅ | PR #12 |
| | "Every N hours" schedules, as-needed medicines | ◐ | ✅ |
| **Labs** | Lab report from photo **or PDF**, read on the phone | ✅ | ✅ (photo reading; PDF attached, not read) |
| | Values with the lab's printed range, High/Low | ✅ | ✅ |
| | Unsure values highlighted, confirm before saving | ✅ | ✅ (every row must be confirmed) |
| | Trend chart per test | — | ✅ |
| **Sick days** | Fever log, medicine given, reminder | ✅ (v1.3) | ✅ |
| | Lock-screen live status with child's name | ◐ | — (by choice: privacy) |
| | Age-based warning signs with sources | — | ✅ |
| **Growth** | WHO weight, height, head circumference | — | ✅ |
| | CDC milestones | — | ✅ |
| | Infant feeds / sleep / diapers | — | ✅ |
| **Other care** | Pregnancy mode | — | ✅ |
| | Check-up and screening follow-ups (children and adults) | — | ✅ |
| | Emergency card | — | ✅ |
| | Doctors directory with call/WhatsApp | — | ✅ |
| | Insurance cards | — | ✅ |
| | Spending dashboard | — | ✅ |
| | Doctor summary PDF | — | ✅ |
| | Timeline of all records | ✅ | ✅ |
| **Privacy and security** | No account needed | ✅ | ✅ (account optional) |
| | Data only on the phone | ✅ | ✅ |
| | Encrypted database and photos | iOS data protection | ✅ SQLCipher + XChaCha20 |
| | App lock (PIN, Face ID) | — | ✅ |
| | Recents/screenshot privacy | — | ✅ |
| | Delete all data | ✅ | ✅ (also erase after 10 wrong PINs, opt-in) |
| | Analytics | Opt-in, anonymous (PostHog EU) | None |
| **Backup** | Moves to a new phone automatically | ✅ (iCloud / computer backup) | — (manual encrypted file + monthly reminder) |
| | Encrypted, cross-platform (iPhone ↔ Android) | — | ✅ |
| **Platforms** | iPhone | ✅ (iOS 18+) | ✅ (built, not yet on a device) |
| | Android | — | ✅ |
| **Languages** | Arabic and English | ✅ | ✅ (Egyptian Arabic first) |
| **Price** | | Free ("first 100 families") | Free |

**Where Jojo is still ahead:**

1. **Backup without effort.** Jojo's data moves to a new iPhone with the
   normal iCloud backup. Usra deliberately keeps health data out of iCloud
   (Apple 5.1.3, our privacy promise) and asks the family to save an
   encrypted file.
2. **Reading PDFs.** Jojo reads lab PDFs; Usra attaches PDFs but only reads
   photos.
3. **Focus.** Three things done simply. Usra does much more, which is
   harder to make feel calm; the UX audit (separate PR) checks this.

Proposals that follow from this:

| # | Proposal | Size |
| --- | --- | --- |
| C11 | **Automatic encrypted backup**: optional weekly backup of the encrypted file to a folder the user picks once (iCloud Drive, Google Drive or Files), still unreadable without the recovery key; shows "last backup" on Home | M |
| C12 | **Read lab PDFs**: extract text from text-based PDFs on the device (fall back to rendering a page to an image for the existing reader) | S |
| C13 | **Calm Home for parents**: a child-focused Home (next vaccine, today's doses, last fever) that hides adult features until used; follow the UX audit's findings | M |
| C14 | **Store page**: lead with "no account, stays on your phone", then reminders that ring, growth and milestones, the whole family, Android | S |

## Hands-on: Jojo 1.3 (5 Nov 2026)

From screenshots of the installed app (version 1.3, build 17, newer than the
1.2 store listing above). Changes the comparison in four places:

- **Fever is released.** The "+" button offers Vaccine, Medicine, Lab report
  and **Fever**; Records has a Fevers tab. Mark Jojo's fever log as ✅.
- **A paid plan exists.** Settings shows "Founding member: Premium is free for
  you, for life". Early users get Premium free; later users will likely pay.
  The welcome screen says "Free for every child in your family".
- **Vaccine schedule differs from ours** (needs a doctor's or current MoHP
  check before we change anything):
  - Jojo lists **hexavalent as required** at 2, 4 and 6 months with polio, and
    no separate pentavalent or IPV. Our research
    (`egypt-vaccine-schedule.md`) found hexavalent is **not** in the free
    public schedule as of 4 Nov 2026 and models it as a private route.
  - Jojo offers **meningitis (optional) at 9 months**; we start MenACWY at
    12 months. Some MenACWY vaccines are licensed from 9 months.
  - Matches: birth BCG + hepatitis B + polio; PCV and rotavirus optional at
    2 and 4 months, PCV at 6; polio at 9 months; MMR + polio at 12 months.
- **"Where" on each vaccine:** government health unit or private, plus vaccine
  search and an optional card photo.

**How it feels** (useful for the UX audit and C13):

| Moment | Jojo |
| --- | --- |
| Welcome | One card with a countdown ("58 days until her 6-month vaccines") and "Your child's health, calmly kept." |
| Onboarding | 5 steps: your name; one child (name, date of birth, illustrated girl/boy avatar, colour); "What has she already had?" grouped by age with **Tick all** per group, optional vaccines labelled, dates optional |
| Home | Greeting by name; one vaccine card (due today, next visit date, required chips solid, optional dashed, "Mark what she's already had"); empty state with three big rows: Vaccine, Medicine, Lab report |
| Navigation | Floating 4-tab bar (Home, Records, Vaccines, Settings) + a large "+" that adds anything from any tab; child switcher pill on every tab |
| Adding | Bottom sheets with the person picker in the header; "Type it in" first, photo second |
| Records | One screen, tabs Medicines / Labs / Vaccines / Fevers, search |
| Vaccines | "0/10 required doses done" with one line of explanation and a link; All / Required / Optional; timeline by age with dates; English and Arabic names on the same chip |
| Look | Warm off-white, one accent colour, very large titles, few elements per screen |

**What to take from it:** the one-tap "+" for every record type, "Tick all"
per age group, bilingual vaccine names on one chip, the "Where" field, and a
first screen that shows the next thing to do. **What not to copy:** analytics
by default (Jojo asks; we don't collect any), and health data in iCloud.

New proposals: **C15** global "+" add button and Records tabs per type (S);
**C16** "Where given" on vaccines (S); **C17** resolve the hexavalent and
meningitis questions with a doctor and update the schedule source (S, founder
+ app).

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

Suggested order: C1 + C2 + C3 together (one vaccine release; built in Nov 2026, schedule research in `egypt-vaccine-schedule.md`), then C5 + C9 (built in Nov 2026),
then C6 + C7 (built in Nov 2026: lab reports in `app/lib/features/labs/`, prescriptions in
`app/lib/features/medicines/prescription_parser.dart`, vaccination cards in
`app/lib/features/children/vaccine_card_parser.dart`; the on-device reader is Latin script only,
so Arabic text isn't read yet), then C4 + C10, then C8 (built in Nov 2026; warning signs in `fever-warning-signs.md`, needs medical review).
