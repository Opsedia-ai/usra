# Decisions log

All decisions as of 2 Nov 2026. Details and sources are in the PDFs in `docs/pdf/`.

| Area | Decision | Why / notes |
| --- | --- | --- |
| Product | One app for the whole family: profiles, visits, doctors, medicines, scans, labs, vaccines, surgeries (incl. filmed or not, hospital, cost), insurance cards | Original brief |
| Insurance | Unlimited named policies per person (Neqaba, Work 1, Work 2…), card photos, share by WhatsApp with a watermark | User request |
| Reminders | One generic reminder engine (what, who, when, how), alarms, escalation to caregivers | Generalised, per brief |
| Follow-ups | Automatic follow-up suggestions from the case recorded and the person's age; user accepts, edits or dismisses | User request |
| Children | Infant Mode: WHO growth z-scores (On track / Watch / Check with doctor), milestones, vaccines, infant log, fever log | User request |
| Pregnancy | Pregnancy Mode: due date, week-by-week checks, danger signs, baby profile at birth | User request |
| Elderly | Simple Mode (Arabic, big buttons, voice), caregiver missed-dose alerts, elder tutorial | User request |
| Doctors | Directory with phone numbers, call/WhatsApp, hospitals with emergency numbers | User request |
| Business model | Free app. Later: clinic partnerships (sponsored listings, appointment reminders, doctor advice), AI Doctor credits + Usra Plus subscription | User changed from $1 one-time to free |
| Ads | Only labelled, contextual sponsored listings (city + specialty). Never targeted using health data | Apple 5.1.3, Google Play user data policy |
| First market | Egypt (57.2% out-of-pocket health spending, 2023), then KSA as a Sehhaty complement, then UAE | MENA research |
| Mobile framework | Flutter (Android + iOS from one codebase). React Native only if the founding developer is React/TS-first | Technical design comparison |
| Sign-in | Optional account with Google and Apple only, native ID tokens. No SMS. Decided 2026-11-06 | SMS costs about $1,980 per 5,000 users at Twilio's Egypt price; the free-for-5,000 rule; Apple guideline 4.8 |
| Backend | Supabase: Auth (Google and Apple), Postgres + RLS, Edge Functions (Deno/TS), Storage | User's recommendation |
| Data location | Health data on the phone (SQLCipher) in v1. v2 sync is end-to-end encrypted. Readable cloud data only on self-hosted Supabase in-region | Supabase Cloud has no Middle East region; Egypt/KSA/UAE data rules |
| Backups | Encrypted file to the user's own Google Drive. Never iCloud | Apple guideline 5.1.3 forbids health data in iCloud |
| OCR | Barcode → ML Kit on-device text → drug-list matching → cloud fallback (with consent) for Arabic and handwriting | ML Kit cannot read Arabic |
| AI Doctor | Rules on the phone first; LLM via Edge Function on a de-identified snapshot the user previews; findings in severity colours; never diagnoses | User request; safety and regulation |
| AI regulatory gate | Off in KSA until reviewed (SFDA MDS-G27); in Egypt only after PDPL transfer licence or an in-region model | MENA research |
| Dose calculator | Off on iOS unless from an approved entity | Apple guideline 1.4.2 |
| App Store | Publish as Opsedia (organisation account, D-U-N-S), not an individual | Apple guideline 5.1.1(ix) |
| iOS alarms | AlarmKit on iOS 26+; Time Sensitive notifications on older iOS | iOS limits |
| Desktop | Not in v1. Web clinic portal in Phase 3; optional web/desktop family view after sync | Discussion |
| Data use | Level 1 (anonymous product analytics, no health data) at launch; opt-in aggregates later; never sell data | Store policies, trust |
| Colours | Nile blue brand (#1F5FA8) on a soft blue-white background, warm sand accent | User chose scheme 1 |
| Severity scale | Blue info · green good · yellow heads-up · orange act soon · red urgent | User asked for intuitive colours |
| Character | Dr. Usra (دكتور أسرة): blue house-shaped character with a heart; 5 poses | User approved the design and chose the name |
| App name | Usra (أسرة). Avoid Salamtak (an active Kuwaiti medical app), Sehhaty, Sahatna, Malaffi, Riayati, Wasfaty, Sijilli | Name checks |

## Open questions

- [ ] Founding developer: Flutter confirmed?
- [ ] LLM provider and region for AI Doctor
- [ ] AI credit and Usra Plus prices per market
- [ ] Cloud and region for self-hosted Supabase later
- [ ] Source and licence of the Egyptian drug list
- [ ] Trademark, store-name and domain checks for "Usra"
