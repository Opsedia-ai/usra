# Decisions log

All decisions as of 2 Nov 2026, kept as history. Details and sources are in the PDFs in `docs/pdf/`. Rows marked "Replaced" no longer apply. `docs/prd-v1.md` and `docs/product-definition.md` win wherever they differ.

| Area | Decision | Why / notes |
| --- | --- | --- |
| Product | One app for the whole family: profiles, visits, doctors, medicines, scans, labs, vaccines, surgeries (incl. filmed or not, hospital, cost), insurance cards | Original brief |
| Insurance | Unlimited named policies per person (Neqaba, Work 1, Work 2…), card photos, share by WhatsApp with a watermark | User request |
| Reminders | One generic reminder engine (what, who, when, how), alarms, escalation to caregivers | Generalised, per brief |
| Follow-ups | Automatic follow-up suggestions from the case recorded and the person's age; user accepts, edits or dismisses | User request |
| Children | Infant Mode: WHO growth z-scores (On track / Watch / Check with doctor), milestones, vaccines, infant log, fever log | User request |
| Pregnancy | Pregnancy Mode: due date, week-by-week checks, danger signs, baby profile at birth | User request |
| Elderly | Simple Mode (Arabic, big buttons, voice), caregiver missed-dose alerts, elder tutorial | User request. **Partly replaced 7 Nov 2026:** no voice in v1, and caregiver alerts are v2 (they need sync) |
| Doctors | Directory with phone numbers, call/WhatsApp, hospitals with emergency numbers | User request |
| Business model | Free app. Later: clinic partnerships (sponsored listings, appointment reminders, doctor advice), AI Doctor credits + Usra Plus subscription | User changed from $1 one-time to free. **Replaced 7 Nov 2026:** founding members, then a 1-year pass or Lifetime (see below) |
| Ads | Only labelled, contextual sponsored listings (city + specialty). Never targeted using health data | Apple 5.1.3, Google Play user data policy |
| First market | Egypt (57.2% out-of-pocket health spending, 2023), then KSA as a Sehhaty complement, then UAE | MENA research. **Replaced 7 Nov 2026:** Egypt, then Saudi Arabia and Jordan, UAE later (see below) |
| Mobile framework | Flutter (Android + iOS from one codebase). React Native only if the founding developer is React/TS-first | Technical design comparison |
| Backend | Supabase: Auth (Google and Apple), Postgres + RLS, Edge Functions (Deno/TS), Storage | User's recommendation |
| Data location | Health data on the phone (SQLCipher) in v1. v2 sync is end-to-end encrypted. Readable cloud data only on self-hosted Supabase in-region | Supabase Cloud has no Middle East region; Egypt/KSA/UAE data rules |
| Backups | Encrypted file in the user's own place, at no cost to us: a folder they choose, or sent where they like (Google Drive through the share sheet). No backup on our servers in v1. Never iCloud | Founder decision 2026-11-06. Apple guideline 5.1.3 forbids health data in iCloud. The Android folder picker doesn't appear to offer Drive, and no broad Drive permission is asked for |
| OCR | Barcode → ML Kit on-device text → drug-list matching → cloud fallback (with consent) for Arabic and handwriting | ML Kit cannot read Arabic. **Partly replaced 7 Nov 2026:** no cloud fallback in v1 (see below) |
| AI Doctor | Rules on the phone first; LLM via Edge Function on a de-identified snapshot the user previews; findings in severity colours; never diagnoses | User request; safety and regulation |
| AI regulatory gate | Off in KSA until reviewed (SFDA MDS-G27); in Egypt only after PDPL transfer licence or an in-region model | MENA research |
| Dose calculator | Off on iOS unless from an approved entity | Apple guideline 1.4.2 |
| App Store | Publish as Opsedia (organisation account, D-U-N-S), not an individual | Apple guideline 5.1.1(ix) |
| iOS alarms | AlarmKit on iOS 26+; Time Sensitive notifications on older iOS | iOS limits |
| Desktop | Not in v1. Web clinic portal in Phase 3; optional web/desktop family view after sync | Discussion |
| Data use | Level 1 (anonymous product analytics, no health data) at launch; opt-in aggregates later; never sell data | Store policies, trust. **Replaced 7 Nov 2026:** no analytics at launch (see below) |
| Colours | Nile blue brand (#1F5FA8) on a soft blue-white background, warm sand accent | User chose scheme 1. **Replaced 6 Nov 2026:** Twilight palette, see `docs/product-definition.md` |
| Severity scale | Blue info · green good · yellow heads-up · orange act soon · red urgent | User asked for intuitive colours |
| Character | Dr. Usra (دكتور أسرة): blue house-shaped character with a heart; 5 poses | User approved the design and chose the name |
| App name | Usra (أسرة). Avoid Salamtak (an active Kuwaiti medical app), Sehhaty, Sahatna, Malaffi, Riayati, Wasfaty, Sijilli | Name checks |

## v1 decisions (6 Nov 2026)

| Area | Decision | Why / notes |
| --- | --- | --- |
| Cost | Everything free for the first 5,000 users; every feature gets a cost check (`CLAUDE.md`) | Founder rule. **Changed 7 Nov 2026:** the free goal is about what users get; fixed running cost is approved (see below) |
| Login | Google and Apple sign-in only. No SMS verification | One code each for 5,000 users is about 1,980 dollars at Twilio's Egypt price |
| Backup | Encrypted file in the user's own folder, automatic (C11). Nothing on our servers. Not iCloud | Free for us; Apple 5.1.3 |
| Sync | No family sync in v1, and no photo sync. Backend sync work is paused | 1 GB of free files fills at about 170 users with 20 photos each |
| AI | Dr. Usra AI is off in v1 and shown as coming soon | About 130 dollars a month at 5,000 users, on stated assumptions |
| Cloud photo reading | Off in v1. On-device reading only | Costs per photo, and the photo would leave the phone |
| Purchases | Nothing to buy in v1, so no RevenueCat | Only needed for AI credits. **Replaced:** 1-year pass and Lifetime through RevenueCat (`docs/prd-v1.md`, F24) |

## Founder decisions (7 Nov 2026)

The full list is in `docs/prd-v1.md`, under "Decided on 7 November 2026". These rows replace older ones above.

| Area | Decision | Why / notes |
| --- | --- | --- |
| Cost | The free goal is about what users get. Approved fixed running cost: Supabase Pro, Apple and Google accounts. Any other paid use still needs asking | Replaces "first 5,000 users" as a rule about our cost |
| Supabase | Pro (about $25 a month) from the moment real member numbers exist. Until then nothing runs | Member numbers can't be recreated, and Free has no backups |
| Login | No real family signs in until an Egyptian lawyer has answered five questions (`docs/login-setup.md`, step 6). The beta runs without login unless that answer arrives first | An account row is personal data on a server outside Egypt |
| Legal review | Egypt, Saudi Arabia, Jordan. UAE is off the list for launch | Jordan research is under way separately |
| Markets | Beta and first public launch in Egypt only; Saudi Arabia and Jordan once a local doctor has reviewed their schedules; UAE later | Replaces "then KSA... then UAE" |
| Business model | First 5,000 signed-in users to save a record are founding members, free for life; after that a 1-year pass or Lifetime, sold through the stores | Replaces "AI Doctor credits + Usra Plus". How Dr. Usra AI is paid for is still to decide |
| Seats | Assigned when a signed-in user saves their first record, not at sign-up. First-use date saved on the phone and in the backup. Beta accounts don't count unless the founder says otherwise | Stops idle sign-ups taking seats; helps with fair cases |
| Trial or pass ends | People can still read, export, back up and delete records and use the emergency card, and reminders keep ringing. Only adding new records stops | Nobody is locked out of their records |
| Data use | No analytics, ads or tracking SDKs in v1 | Replaces Level 1 analytics at launch. Metrics come from beta interviews, an opt-in survey and store statistics (PRD) |
| OCR | v1 reads printed Latin text on the phone only; Arabic and handwriting aren't read in v1. Cloud reading is v2 or later | Replaces the cloud fallback for v1 (`app/lib/core/ocr/ocr_service.dart`) |
| Simple Mode | Three big buttons (PRD F21), no voice in v1. Caregiver alerts are v2 | Replaces voice and caregiver alerts for v1 |
| Home and navigation | Home shows the family; one person on their own page. No tab bar: three round buttons (Medicines, a large Add, Records), with More and Emergency at the top of Home | Variation B |
| Addressing the user | The user's sex from "About you" sets all text addressed to them; text about a family member uses that member's sex | Covers all Arabic wording |
| Discreet mode | On by default, with neutral text plus a Taken button on notification and widget | `docs/security.md` records a risk to solve when this is built |
| Backup wording | Automatic backup goes to "a folder you choose". Drive stays available manually through the share sheet | Don't promise Drive until tested on a real phone |

## Open questions

The current list is in `docs/prd-v1.md`, under "Still open".

- [ ] Founding developer: Flutter confirmed?
- [ ] LLM provider and region for AI Doctor
- [x] ~~AI credit and Usra Plus prices per market~~ Replaced by the 1-year pass and Lifetime prices in the PRD
- [ ] Cloud and region for self-hosted Supabase later
- [ ] Source and licence of the Egyptian drug list
- [ ] Trademark, store-name and domain checks for "Usra"
