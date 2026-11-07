# Usra — PRD v1

Nov 6, 2026 · @Aya Nasser · Updated Nov 7, 2026 with the founder's decisions (table under Open questions)

## Overview and goals

Usra v1 is a free, offline-first Flutter app for Android and iOS that keeps every family member's health file on the phone, reminds the family on time and never sends health data to a server. Closed beta with 50 families on 31 December 2026. Beta and first public launch in Egypt only; Saudi Arabia and Jordan follow; UAE later.

### Goals for v1

1. A family can set up themselves and one member, with current medicines, in one short sitting.
2. Reminders ring on time on budget Android phones and on iPhone.
3. Families trust it with their data: health data never leaves the phone, encrypted, backups in a folder they choose.
4. It feels calm: one main action per screen, Arabic first, usable by grandparents.

### Success metrics

| Metric | Definition | Role |
| --- | --- | --- |
| Weekly active families | Installs where someone opened Usra and logged or confirmed something in the last 7 days | North star |
| Doses confirmed | Share of medicine reminders marked Taken | Health of reminders |
| Families with a backup | Share of installs with a backup made in the last 30 days | Trust and safety |
| Crash-free sessions | From the stores' own crash reports | Quality |
| Store rating | Average rating on Google Play and the App Store | Word of mouth |

v1 has no analytics SDK, so these come from beta interviews, an opt-in in-app survey and store statistics. Target: 2,500 weekly active families three months after public launch.

## Scope

v1 keeps all health data on the phone. The only server use is sign-in, the founding-member count and subscriptions; Usra never stores health data, photos or backups on its own servers. No real family signs in until an Egyptian lawyer has answered (see Compliance), and no server runs until real member numbers exist.

| In v1 | Shown as "coming soon" | v2 and later | Out of v1 |
| --- | --- | --- | --- |
| Sign in with Google or Apple (no SMS), once an Egyptian lawyer has answered | Dr. Usra AI | End-to-end encrypted family sync (records only, no photos) | SMS / phone-number login |
| Country chosen first: Egypt at beta and first public launch; Saudi Arabia and Jordan after | | Caregiver missed-dose alerts | Backups or photos on Usra's servers |
| Founding members: first 5,000 signed-in users to save a record, free for life | | Multi-device and change phone | Photo sync |
| Subscription for everyone after 5,000, behind a remote switch | | Cloud photo reading (Arabic, handwriting) | Dose calculator |
| Promo codes (store offer codes) | | Clinic portal and verified records | Health data in iCloud |
| Family profiles with sex and date of birth | | Sponsored listings (labelled) | Ads targeted by health data, selling data |
| Records: visits, labs, scans, surgeries, admissions, vaccines, vitals, allergies, conditions | | | Desktop app |
| Medicines, reminders with Taken/Snooze, home-screen widget | | | |
| Vaccine schedule per country (government and private routes for Egypt) | | | |
| Growth (WHO), milestones (CDC), infant log | | | |
| Pregnancy Mode | | | |
| Sick-day fever log with cited warning signs | | | |
| Lab reports read on the phone, trend charts | | | |
| Doctors and hospitals directory, call/WhatsApp | | | |
| Insurance cards, WhatsApp share with watermark | | | |
| Spending dashboard | | | |
| Automatic follow-up suggestions | | | |
| Emergency card, doctor summary and vaccine PDFs | | | |
| Encrypted backup: manual file and automatic weekly backup to a folder you choose | | | |
| App lock, discreet mode, delete all data and account | | | |
| Simple Mode for elders | | | |

## Personas and user stories

v1 serves the whole family equally; the personas and their modes are defined in the [Product Definition](product-definition.md). The stories below are the ones v1 must pass in the closed beta.

| # | As a… | I want to… | So that… | Priority |
| --- | --- | --- | --- | --- |
| U1 | Family organiser | add myself and a family member with name, sex and date of birth | each person has their own file | Must |
| U2 | Family organiser | see the family on Home and open anyone in one tap | I see everyone at a glance and each person on their own page | Must |
| U3 | Parent | see my child's next vaccine and tick vaccines already given | I never miss a dose | Must |
| U4 | Parent | log my child's weight and height and see if growth is on track | I know when to ask the doctor | Must |
| U5 | Parent | log a fever and see the warning signs for my child's age | I know when to get help now | Must |
| U6 | Anyone | add a prescription with several medicines and get reminders | doses happen on time | Must |
| U7 | Anyone | mark a dose Taken from the notification or widget | I don't need to open the app | Must |
| U8 | Pregnant woman | enter my last period and see my week and next checks | I follow the pregnancy schedule | Must |
| U9 | Family organiser | keep each person's insurance cards and send one on WhatsApp | the receptionist gets it at once | Must |
| U10 | Family organiser | photograph a lab report and have the values read | I don't type every number | Should |
| U11 | Elder | see today's pills in big type and press "I took it" | I manage on my own | Must |
| U12 | Family organiser | make an encrypted backup and restore it on a new phone | a lost phone doesn't lose our history | Must |
| U13 | Family organiser | see what we spent on health this month, by person | I can plan the budget | Should |
| U14 | Anyone | share a one-page summary with a doctor | the doctor sees my history in a minute | Should |
| U15 | Caregiver | get an alert when my father misses a dose | I can call him | v2 (needs sync) |

## Information architecture

A bottom bar holds the main screens: Home, Medicines, Add, Records and More. Home shows the family, each person has their own page, and Add adds any record from anywhere. This follows the enhanced design the founder accepted on 7 November 2026 (`design/app-screens/enhanced-sample`, `design/app-screens/merged-review.md`).

Vaccines, growth and pregnancy appear inside that person's page and Records only when they apply (a child, a female profile with an active pregnancy). In Simple Mode the tabs are replaced by three big buttons.

More also holds Account and subscription, Redeem code, and a Dr. Usra AI card marked "Coming soon".

## Core flows

### First run

1. Welcome with Dr. Usra and the promise: "Your family's health stays on this phone." A restore entry for a family that already has a backup.
2. Language (Arabic or English), then country: Egypt at beta and first public launch, with Saudi Arabia and Jordan added after. The country sets the vaccine schedule, emergency number and currency.
3. About you: name, sex and date of birth. The sex chosen here sets all text addressed to the user. No sign-in needed yet.
4. Land on Home.

The rest moved out of the first run to shorten it, and is offered from Home as optional cards, each asking for its permission when it's needed:

- One family member: name, sex, date of birth, relationship.
- For a child: tick vaccines already given, grouped by age, with Tick all per group; in Egypt, choose the government or private (hexavalent) route.
- App lock: PIN or fingerprint.
- Notifications permission, then Android battery-saver guide on brands that kill alarms.
- Backup, and the emergency card.
- Once login is on, "Save your free-for-life spot": sign in with Google or Apple (fills your name); a founding-member number is assigned when you then save your first record, while spots last.

### Add a record

1. Tap Add in the bottom bar. The sheet's header shows whose record it is, and it can be changed there.
2. Pick a type: Visit, Medicine, Vaccine, Lab, Scan, Fever, Insurance card, more.
3. Choose "Type it in" or "Take a photo". A photo is read on the phone; unsure values are highlighted.
4. Confirm, save. Usra may suggest follow-ups; the user accepts, edits or dismisses.

### Medicine reminder

1. Add a medicine (or a prescription with several).
2. Copy the dose text as written; pick times from the prescription ("3 times a day" lays times out, all editable).
3. Set duration ("day 3 of 7") and stock for refill reminders.
4. At the time: notification with neutral text, Taken and Snooze 10 min (discreet mode, on by default). The widget also shows neutral text and Taken.
5. The answer is logged for the adherence view.

### Backup and restore

1. More › Backup shows the recovery key once; the user copies or writes it down.
2. Usra builds an encrypted file and opens the share sheet (Google Drive, Files, WhatsApp to self).
3. Optional automatic weekly backup of the same encrypted file to a folder you choose, picked once (never iCloud; Google Drive isn't promised here until tested on a real phone, and stays available manually through the share sheet); otherwise a monthly reminder; "Last backup" shows on Home.
4. On a new phone: Restore from file › enter recovery key › records and photos return.

## Functional requirements

| ID | Module | Requirement (v1) |
| --- | --- | --- |
| F1 | Profiles | Name, sex (male/female, required), date of birth, relationship, blood type, allergies, conditions, avatar coloured by sex. Unlimited free profiles. |
| F2 | Navigation | Bottom bar: Home, Medicines, Add, Records, More. One tap on a person on Home opens their page; "Add person" is on Home. |
| F3 | Home and person page | Home shows the family and what needs doing today: due doses with one-tap Taken, open follow-ups, active sick day, last backup. One person on their own page: due doses, next vaccine with countdown, open follow-ups, active sick day. |
| F4 | Records | One timeline per person, filter by type, doctor, year; search across names, diagnoses and text read from photos. |
| F5 | Record types | Visit, medicine, prescription, vaccine, lab (several tests, printed range, High/Low), scan, surgery (hospital, filmed yes/no, cost), admission, vitals, allergy, condition. Each can hold photos, doctor, place, cost. |
| F6 | Medicines | Dose text saved word for word; times, every N hours, as needed; course length; stock and refill reminder. Never suggests or computes a dose. |
| F7 | Reminders | Local notifications with Taken / Snooze / Skip; full-screen alarm option; re-armed after reboot; widget on Android and iOS; AlarmKit on iOS 26+. |
| F8 | Vaccines | Schedule of the chosen country: Egypt (MoHP, government or private hexavalent route); Saudi Arabia and Jordan once they launch; other countries record vaccines by hand; optional vaccines on request, catch-up intervals, age limits, reminders a week before and on the day, vaccination PDF. Sources shown. |
| F9 | Children | WHO growth (weight, length/height, head, BMI) with On track / Watch / Check with doctor, CDC milestones, feeds/sleep/diapers under 1, corrected age for preterm babies. Uses the profile's sex. |
| F10 | Pregnancy | Female profiles only. Due date from last period or dating scan, week-by-week checks, danger signs with a "Call my doctor" button, baby profile at birth. Private by default. |
| F11 | Sick days | Temperature log (°C/°F, site), symptoms, medicine given in the family's own words, age-based warning signs with sources, "N hours after this dose" only from the family's own field. |
| F12 | Follow-ups | Rules file on the phone suggests follow-ups from the record, age and sex; user accepts, edits or dismisses. |
| F13 | Doctors and hospitals | Directory with phone, WhatsApp, address, hours, fee; one-tap call or WhatsApp; hospitals with emergency numbers. |
| F14 | Insurance | Unlimited named policies per person, front/back photos, member number copy, validity and renewal reminder; share to WhatsApp with a dated watermark. |
| F15 | Spending | Every cost feeds one ledger; totals by week, month, year, person, category; covered vs out of pocket; family currency. |
| F16 | Emergency card | Blood type, allergies, conditions, current medicines, contacts; opt-in per person on the lock screen; SOS call to the chosen country's ambulance (123 Egypt, 997 Saudi Arabia, 911 Jordan). |
| F17 | Reports | Doctor summary PDF and vaccination PDF made on the phone, sections chosen by the user. |
| F18 | Scan | Medicine box barcode then on-device text reading (ML Kit), matched to a drug list; lab reports and prescriptions read on the phone. |
| F19 | Backup | Encrypted file (Argon2id + XChaCha20-Poly1305) with a recovery key; restore across Android and iPhone; optional automatic weekly backup to a folder you choose (C11), "Last backup" on Home; Google Drive manually through the share sheet. Nothing is stored by Usra. |
| F20 | Security | App lock (PIN, biometrics), discreet mode (default on: neutral text plus Taken), screen privacy, delete all my data, root/jailbreak warning. |
| F21 | Simple Mode | Three big buttons: My medicines today, Call my caregiver/doctor, Scan. Suggested when an owner profile is 65+; the user decides and can switch any time. |
| F22 | Language | Egyptian Arabic (default) and English; Arabic or Latin digits; Hijri and Gregorian dates. Text addressed to the user follows the sex given in "About you"; text about a family member follows that member's sex. |
| F23 | Account | No real family signs in until an Egyptian lawyer has answered (see Compliance). Then: optional sign-in with Google or Apple through Supabase Auth (Frankfurt region) (Sign in with Apple required on iOS when Google is offered). Stores only name, email, country, member number and subscription status; no health data. Delete account in the app. Offered by a "Save your free-for-life spot" card after the first person is added; required only to subscribe or redeem a code. |
| F24 | Founding members and subscription | A signed-in user gets a member number when they save their first record, not at sign-up. Numbers 1 to 5,000, one pool across all countries, are founding members, free for life. From number 5,001 adding new records needs a 1-year pass (499 EGP, 99.99 SAR, 11 JOD; pay once, no auto-renewal) or Lifetime (1,249 EGP, 249.99 SAR, 37.99 JOD; pay once), sold through Google Play Billing and Apple in-app purchase via RevenueCat, after a 14-day free trial. When a trial or pass ends, people can still read, export, back up and delete their records and use the emergency card, and medicine reminders keep ringing; only adding new records stops. The trial and the pass end date are tracked on the account in Supabase; on iOS the trial is a free in-app item, as Apple asks for non-subscription apps. The limit and an on/off switch live in a remote config table, changeable without an app update. |
| F25 | Promo codes | Google Play promo codes and Apple offer codes (check that Apple offers them for one-time purchases) for the 1-year pass and Lifetime, created in the store consoles and tracked in RevenueCat; free time can also be granted to a signed-in account from the RevenueCat dashboard. A "Redeem code" row in More. |
| F26 | Dr. Usra AI | Off in v1. A "Coming soon" card in More with Dr. Usra; no network call, no purchase. |

### Vaccine schedules by country

Researched 6 Nov 2026; every schedule needs a local doctor's review before release.

| Country | Official source | Confidence | What differs from Egypt |
| --- | --- | --- | --- |
| Egypt | MoHP schedule, VACSERA for the private hexavalent route | High (in the app already) | — |
| Saudi Arabia | MOH National Immunization Schedule (Dec 2019 PDF), read through the SFDA Basic Vaccination Schedule (Aug 2022) | High to 18 months; medium for the 11, 12 and 18-year doses | BCG at 6 months, not birth (skipped if missed by 12 months); PCV and 3-dose rotavirus at 2, 4, 6 months; MenACWY at 9 and 12 months; varicella and hepatitis A from 18 months; HPV for girls at 11 and 12 years |
| Jordan | MOH national programme PDF (out of date, 2010 era) plus dated MOH announcements: hepatitis A (2020), PCV13 (Sep 2025), varicella (May 2026) | Medium; low for hepatitis A ages and rotavirus dose count | 6-in-1 vaccine at 2, 3 and 4 months; PCV13 at 2, 4, 12 months and varicella at 12 months for children born from 1 Jan 2025; Td and OPV at school |

Jordan's two low-confidence doses ship marked "check with your doctor".

## Design requirements

The app must feel calm and minimal in both light and dark mode, follow the Twilight palette and two-font system in the [Product Definition](product-definition.md), and work right-to-left first.

- **Design system first.** Colour tokens (light and dark), type scale, spacing in steps of 8, corner radius, buttons, cards, chips, inputs, bottom sheets, the bottom bar and the Add button, built as Flutter ThemeData and ThemeExtension before any screen.
- **Light and dark.** Follows the phone's setting, with a manual override in More. Every colour comes from a token; no screen hard-codes a colour.
- **Fonts.** Baloo Bhaijaan 2 for titles, Dr. Usra and the tour; IBM Plex Sans Arabic for body text, medicine names, doses, dates and numbers. Both bundled as assets.
- **Person colour.** Avatar tinted soft blue for males and orchid for females, always with name and avatar shape.
- **Severity colours** (info, good, heads-up, act soon, urgent) are separate from brand colours and always paired with an icon and words.
- **RTL.** Layouts mirror for Arabic; numbers, units and medicine names in Latin stay left-to-right inside Arabic lines.
- One main action per screen; empty states show Dr. Usra and the first thing to add.
- **Accessibility.** Body 16 px, Simple Mode 20 px, both scale with the phone's font size; touch targets 48 dp, 56 dp in Simple Mode; contrast 4.5:1 for text; no swipe-only or long-press-only actions; screen-reader labels in Arabic and English.
- **Gendered Arabic copy.** Text addressed to the user uses the sex from "About you"; text about a family member uses that member's sex (خدته / خدتها).
- **Design before code.** Each screen is mocked up and approved, then built one screen per prompt with its mock-up attached.

## Non-functional requirements

| Area | Requirement |
| --- | --- |
| Platforms | Flutter, one codebase. Android minSdk 24, targetSdk 36; iOS build in CI, signed and tested on a device before beta. |
| Offline | Every v1 feature works with no internet. |
| Storage | Encrypted SQLite (SQLite3 Multiple Ciphers via Drift), 256-bit key in Keystore/Keychain; photos encrypted with XChaCha20-Poly1305; images compressed to WebP. |
| Privacy | No account, no analytics, ads or tracking SDKs; nothing sensitive in logs, notifications, widget or URLs. OS backup off (Android) and excluded (iOS). |
| Reliability | Reminders fire on the minute after reboot and on battery-saving Android brands (Xiaomi, Oppo, Samsung); database migrations safe to repeat; fix forward, never roll back. |
| Performance | Light on budget Android phones and limited data; small app size. |
| Release hardening | R8 and obfuscation, no cleartext HTTP, debug symbols kept privately per release. |
| Quality gates | CI runs tests and security checks (Dependabot, gitleaks, pinned Actions); security tests fail if the database opens without a key or a photo is written unencrypted. |
| Backend | Supabase: Auth (Google, Apple), Postgres with row-level security for accounts, member numbers, remote config and subscription status; one Edge Function, revenuecat-webhook, switched on with the paywall. No health data, photos or backups. Removed from v1: send-sms-hook, ai-doctor, ocr-fallback. |
| Running cost | Supabase Pro about $25 a month up to 100,000 monthly active users, from the moment real member numbers exist, because they can't be recreated and Free has no backups (until then nothing runs); RevenueCat free up to $2,500 monthly tracked revenue, then 1%; Apple $99 a year, Google Play $25 once. |

## Compliance and medical safety

Usra is not a medical device: it records, reminds and cites, and every medical screen ends with "ask your doctor" or "call 123".

- **No dose advice (Apple 1.4.2).** Dose text is saved as written; the only arithmetic is calendar days.
- **Cited content.** Vaccine schedule (Egypt MoHP, VACSERA), growth (WHO), milestones (CDC), fever signs (NHS, AAP, WHO) show their source in the app.
- **Medical review before public launch:** the Egypt vaccine schedule and catch-up rules, fever warning signs and thresholds, and pregnancy danger signs, by a paediatrician and an obstetrician practising in Egypt.
- **Store rules:** no health data in iCloud (Apple 5.1.3), in-app delete all data, privacy label and Play Data safety form match the code, health apps declaration, "not a medical device" line in the app and store pages.
- **Data protection law:** Egypt PDPL (Law 151 of 2020), KSA PDPL and Jordan's data protection law reviewed by a lawyer before launch in each country. UAE is off the list for launch; privacy policy and terms in Arabic and English (drafts exist).
- **Login gate:** no real family signs in until an Egyptian lawyer has answered the questions in `docs/login-setup.md`, step 6.
- **Publisher:** Opsedia organisation account on both stores.

Accounts in v1 change three things:

- **Sign-in review risk.** Apple asks apps without significant account-based features to work without a login. Usra's account carries the founding membership and subscription across Android and iPhone, promo codes and the profile name. So sign-in stays optional until the paywall, where it ties the subscription to the account.
- **Sign in with Apple** must be offered on iOS whenever Google sign-in is, and the account must be deletable inside the app.
- **Privacy texts** (policy, Play Data safety, Apple privacy label) must add name, email and user ID, collected for the account only.

## Release plan

The closed beta reaches 50 families on 31 December 2026, on Android and iOS; public launch waits for medical, legal and security review.

| Step | When | What happens | Gate to the next step |
| --- | --- | --- | --- |
| 1 · Design system and mock-ups | Before beta | Tokens, fonts, components, every v1 screen mocked up in light and dark, Arabic and English | All core screens approved |
| 2 · Closed beta | December 2026 | Google Play internal testing and iOS TestFlight with invited Egyptian families, with no sign-in unless the lawyer's answer arrives first | Reminders reliable on test phones; no data-loss bugs |
| 3 · First public launch, Egypt only | After the reviews | Store listings in Arabic and English, free | Medical review, legal review, external pen test (OWASP MASVS) done |
| 4 · v2 cloud | Later | Accounts, end-to-end encrypted sync, caregiver alerts | External crypto review of the sync design |
| 5 · Partners and more countries | Later | Clinic portal; Saudi Arabia and Jordan listings, then UAE | First pilot clinic; those countries' vaccine schedules |

## Open questions

Decided on 7 November 2026 (where these differ from the 6 November table or older text, these win):

| Topic | Decision |
| --- | --- |
| Supabase | Pro (about $25 a month) from the moment real member numbers exist, because they can't be recreated and Free has no backups. Until then nothing runs |
| Login | No real family signs in until an Egyptian lawyer has answered |
| Legal review list | Egypt, Saudi Arabia, Jordan |
| Launch order | Beta and first public launch in Egypt only, then Saudi Arabia and Jordan. UAE later |
| Seats | A founding seat is taken when a signed-in user saves their first record, not at sign-up |
| When a trial or pass ends | People can still read, export, back up and delete their records and use the emergency card, and medicine reminders keep ringing. Only adding new records stops |
| Discreet mode | Stays on by default, with neutral text plus Taken. `docs/security.md` says when Taken shows |
| How the app addresses the user | By the sex asked in "About you". Text about a family member uses that member's sex |
| Backup wording | Automatic backup goes to "a folder you choose". Don't promise Google Drive until tested on a real phone; Drive stays available manually through the share sheet |
| Design | The enhanced design is accepted (`design/app-screens/enhanced-sample`, `design/app-screens/merged-review.md`) |
| Navigation | Bottom bar: Home, Medicines, Add, Records, More |
| First run | Shorter: language and country, about you, then Home. The rest becomes optional cards on Home |

Decided on 6 November 2026:

| Topic | Decision |
| --- | --- |
| Login | Optional; a "Save your free-for-life spot" card after the first person; required to subscribe or redeem a code |
| Founding members | First 5,000 accounts, one pool across all countries, free for life. How a seat is taken changed on 7 November |
| Plans | 1-year pass (no auto-renewal) and Lifetime, both one payment; 14-day free trial; no monthly plan; store billing only (no card, Fawry or Paymob for unlocking the app) |
| Prices | 1-year pass 499 EGP · 99.99 SAR · 11 JOD; Lifetime 1,249 EGP · 249.99 SAR · 37.99 JOD |
| Today | One person at a time; no all-family view. Replaced on 7 November: Home shows the family |
| Beta | 31 December 2026, 50 families |
| Target | 2,500 weekly active families three months after public launch |
| Medical review | Doctors Aya knows: a pediatrician and an obstetrician |
| Medicine list | Official registries: Egyptian Drug Authority, SFDA, JFDA |
| Accounts region | Supabase Frankfurt (EU) |
| Website | usra.opsedia.ai for privacy policy, terms and support |
| Trademark | Aya searches Egypt, Saudi Arabia, Jordan and both stores; a lawyer files in Egypt |
| Jordan schedule | Two unconfirmed doses ship marked "check with your doctor" |
| Dr. Usra | New character generated with Nano Banana, then added to the design system |

Still open:

- [ ] Names of the pediatrician and obstetrician, and review dates before 31 December
- [ ] Terms of use of the EDA, SFDA and JFDA drug lists
- [ ] Trademark search results
- [ ] Legal check that storing name and email in Frankfurt is fine under Egypt's PDPL
- [ ] Dr. Usra artwork, 5 poses
- [ ] The Egyptian lawyer's answers on login (`docs/login-setup.md`, step 6)
- [ ] Dialect for Saudi Arabia and Jordan
- [ ] Who reviews the Saudi and Jordan vaccine schedules
- [ ] Whether Simple Mode keeps an emergency button
- [ ] Lifetime price ratio in JOD: 3.45x the 1-year pass, against 2.5x in EGP and SAR
- [ ] RevenueCat and iOS 16.3 for one-time code redemption, against the app's target of iOS 15.5
- [ ] What happens to a seat when an account is deleted
- [ ] When someone who saved records first and signs in later takes their seat, since they've already saved their first record
- [ ] What shows the paywall, and starts the 14-day trial, for someone who never signs in once seats run out
- [ ] Whether F23's list of what an account stores should match the privacy draft, which also lists language, device information, profile photo link and account ID
- [ ] How paywall checks behave with no internet
