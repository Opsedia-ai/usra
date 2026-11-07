# Family Medical History App — Product Proposal

Nov 2, 2026 · @Aya Nasser

> **Note, 7 Nov 2026:** this is the original proposal, kept as history. [`prd-v1.md`](prd-v1.md) and [`product-definition.md`](product-definition.md) override it wherever they differ. For example: only the first 5,000 founding members are free for life; v1 has no dose calculator, family linking, caregiver alerts or cloud OCR; and the launch order is Egypt, then Saudi Arabia and Jordan, with UAE later.

## Executive summary

Build an offline-first mobile app that keeps one family's whole medical history in one place. It covers visits, doctors, insurance cards, medications, scans, vaccinations (تطعيمات) and surgeries, plus reminders and a spending dashboard. It launches **free**; revenue comes later from **partnerships with hospitals and clinics** that send verified records to their patients. Running cost stays near zero because data and OCR live on the phone by default.

**Who it is for**

- Expecting mothers, and parents tracking their children's growth, development, vaccinations and fevers
- Adults caring for elderly parents with many daily pills and specialists
- Anyone who wants to know "what did we spend on health this month/year?"

**Three design principles**

1. **Phone-first, cloud-optional.** Records, images and OCR run on the device. Cloud backup and family sync are optional, so a free app stays almost free to run.
2. **Generalized building blocks.** One *Event* model (visit, scan, surgery, vaccine, lab) and one *Reminder* engine power every feature, so new types need no new screens.
3. **Built for grandparents.** Large type, voice input, big buttons, and a caregiver who can manage things remotely.

## App name

Recommended name: **Usra (أسرة, "family")**. It is the same word in Egyptian and Gulf Arabic, it is short and easy for English speakers, and it says exactly who the app is for. Arabic tagline: **ملف صحة العيلة** in Egypt, **ملف صحة الأسرة** in the Gulf ("the family's health file").

| Name | Arabic | Meaning | Why it fits | Watch out for |
| --- | --- | --- | --- | --- |
| **Usra** (recommended) | أسرة | Family | One word for all three markets; names the core idea (the whole family) | Egyptians say "Osra": pick one Latin spelling and own both domains. No health app by this name turned up in a quick search |
| Daftari | دفتري | My notebook | Recalls the paper notebook parents already keep for vaccines and prescriptions; warm and simple | Generic word; harder to trademark |
| Amanah | أمانة | Trust; something kept safe for someone | Signals privacy, the app's main promise | Widely used by banks and charities |
| Sanad | سند | Support; someone to lean on | Fits caring for elderly parents | Name already used by other services in the region; confusion risk |
| Usrati | أسرتي | My family | More personal variant of Usra | Longer; common in other brands |

**Avoid** names close to existing health platforms, which would confuse users and invite trademark disputes: Sehhaty / Sehaty (KSA), Sahatna, Malaffi, Riayati (UAE), Wasfaty (KSA e-prescriptions), Altibbi, Sihtak. Also **Sijilli**: AUB already runs a personal health record by that name.

**Before choosing**: trademark searches in Egypt, KSA and UAE; App Store and Google Play name availability; .com plus local domains (.eg, .sa, .ae); social handles; and a short test with older users to check it is easy to say and remember.

## MENA market: what families need

The strongest need is in countries where families **pay a large share of health costs themselves** and records stay **on paper, scattered across private clinics**. Egypt is the clearest example. In Saudi Arabia, the government's [Sehhaty](https://moh.gov.sa/en/eServices/Sehhaty/Pages/default.aspx) app already covers vaccination records, dependents, pregnancy follow-up and appointments. There, this app should **complement** Sehhaty rather than compete with it.

**What families in the region need, and the feature that answers it**

| Need in MENA | Why it matters there | Feature in this app |
| --- | --- | --- |
| Track out-of-pocket spending | Families often pay doctors, scans and medicines directly; in Egypt 57.2% of health spending was out of pocket in 2023 (World Bank) | Spending dashboard per member and family; receipt photos |
| One record across many private clinics | People see several private doctors and specialists with no shared file | Timeline per person, doctor cards, share summary with any doctor |
| Keep paper safe | Prescriptions, scans and vaccination cards are on paper and get lost | Photo + OCR of every paper; searchable |
| Several insurance cards | Syndicate (نقابة), employer, private, government cover in one family | Unlimited named policies, WhatsApp card sharing |
| WhatsApp-first communication | Clinics and receptionists commonly work over WhatsApp | Share card, prescription, or report to WhatsApp in one tap |
| Arabic, right-to-left, dialect-friendly | Many older users read Arabic only | Arabic-first UI, voice input, text-to-speech |
| Extended families and elderly care | Adult children often manage parents' medicines and visits | Guardian roles, missed-dose alerts to caregivers, Simple Mode |
| Child vaccination schedules | National schedules differ by country | Built-in schedule per country, auto-reminders from date of birth |
| Pregnancy and young children | High birth rates in several MENA countries; many visits and scans to track | Pregnancy Mode, Infant Mode with WHO growth checks |
| Medicine brand confusion | The same active ingredient is sold under many local brands | Drug list per country, duplicate-ingredient warning |
| Low cost, low data use | Price-sensitive users, older Android phones, limited mobile data | Free, offline-first, small app size, images compressed |
| Ramadan and prayer times | Fasting changes when medicines are taken | Ramadan mode: reschedule doses to suhoor and iftar (with doctor's advice) |

**Market by market (first look)**

| Market | What exists | Opportunity for this app |
| --- | --- | --- |
| Egypt | No national consumer family-health app in wide use; many private clinics; syndicate and employer insurance | Highest need: costs, paper records, multiple insurance cards. **Recommended first market.** |
| Saudi Arabia | [Sehhaty](https://moh.gov.sa/en/eServices/Sehhaty/Pages/default.aspx) (MOH): dependents, children's vaccination records, pregnancy follow-up, appointments, medicine list | Complement: private-sector visits, costs, insurance cards, scans, elderly caregiving. Consider importing from Sehhaty later if allowed. |
| UAE | Health information exchanges (Malaffi in Abu Dhabi, NABIDH in Dubai) connect providers; Abu Dhabi's Sahatna app shows families their own and dependents' records; insurance is mandatory | Family cost tracking, multiple policies, expatriate families' records from home countries |
| Jordan, Morocco, others | Mixed public/private systems | Same core needs as Egypt; add per-country vaccine schedules and drug lists |

*The Saudi entries come from the Ministry of Health's own pages ([Sehhaty services](https://moh.gov.sa/en/eServices/Sehhaty/Pages/default.aspx), [vaccination follow-up guide](https://www.moh.gov.sa/en/eServices/cards/Documents/Vaccination-Follow-up-EN.pdf)). The research tab has sourced figures, competitors and regulations for all five markets.*

Full sourced research: MENA research

## Family accounts and linking

One **Family** owns many **Profiles**. A profile has no login and costs nothing. A profile becomes a paid **Member** only when that person wants to sign in and control their own data.

| Concept | What it is | Login? | Cost |
| --- | --- | --- | --- |
| Family | The shared space: profiles, doctors, hospitals, spending | — | Free |
| Managed profile | A child or elderly parent whose records someone else keeps | No | Free, unlimited |
| Member | An adult who signs in on their own phone | Yes | Free (for now) |
| Guardian | A member with edit rights over other profiles | Yes | Included in Member |
| Viewer | Read-only access, e.g. a sibling or a family doctor | Yes (link/QR) | Free |

**How linking works**

- A parent creates profiles for each child and elderly parent. All of them sit under the parent's account at no cost.
- To give a teenager or grandparent their own login, the guardian sends an invite (QR code or SMS link). That person accepts it and signs in on their own phone.
- Permissions are set per profile: **Owner**, **Guardian (edit)**, **Viewer (read)**, or **Emergency only**.
- When a child turns 18, ownership can be handed over to them with full history.
- Two parents can co-guard the same children; both see the same records and get the same reminders.
- Sensitive categories (e.g. mental health, reproductive health) can be marked private so guardians cannot see them.

## Medical records modules

Every record is a **Medical Event** on a person's timeline. Each event can have photos/PDFs, a doctor, a place, a cost, and follow-up reminders. Type-specific fields are added on top.

| Module | Key fields | Attachments | Feeds spending? |
| --- | --- | --- | --- |
| Doctor visit | Date/time, doctor, clinic, reason, diagnosis, notes, fee, paid by (cash/insurance), next visit date | Prescription photo, report | Yes (fee) |
| Doctor card | Name, specialty, clinic(s), phone, WhatsApp, address/map, working hours, typical fee, rating, notes | Business-card photo (OCR fills fields) | — |
| Medication | Name, active ingredient, strength, form, dose, schedule, start/end, prescribed by, reason, stock left, price per box | Box photo, pill photo, prescription | Yes (purchases) |
| Scan / imaging | Type (X-ray, MRI, CT, ultrasound), body part, centre, result summary, cost | Images, PDF report, DICOM link | Yes |
| Lab test | Test name, values + units, normal range, lab, cost | Result PDF/photo | Yes |
| Vaccination (تطعيم) | Vaccine, dose number, date given, place, batch no., next due date, side effects | Vaccination-card photo | Yes |
| Surgery | Procedure, date, hospital, surgeon, anaesthesia type, days admitted, filmed (yes/no + where the video is), total cost, insurance covered, recovery notes | Video link/file, discharge report, photos | Yes |
| Hospital admission | Hospital, ward, admit/discharge dates, reason, cost | Discharge summary | Yes |
| Symptom / vital log | Temperature, BP, sugar, weight, SpO2, time, notes | Optional photo | — |
| Allergy & condition | Allergy or chronic condition, severity, since when | — | — |

**Children extras**

- Preloaded national vaccination schedule per country (e.g. Egypt, KSA, UAE), so due dates are created automatically from the date of birth.
- Growth chart: height, weight, head circumference vs. WHO percentiles.
- Fever log with dose calculator by weight (paracetamol/ibuprofen), clearly labelled as guidance only.

**Cross-cutting features**

- **Timeline view** per person and for the whole family, filterable by type, doctor, or year.
- **Search** across names, diagnoses, and OCR text from every image.
- **Emergency card**: blood type, allergies, chronic conditions, current meds, emergency contacts. Shown on the lock screen and exportable as a QR code.
- **Share with a doctor**: a PDF summary or a time-limited link for one visit.
- **Hospitals directory** shared across the family, linked from surgeries and admissions.

## Infant and child development

The app asks for the child's age, sex, weight, length/height and head size. It compares them with the **WHO Child Growth Standards** and gives one clear answer: **On track**, **Watch and re-measure**, or **Check with your doctor**. All the math runs offline on the phone from bundled WHO tables, so it costs nothing.

**Infant Mode unlocks automatically** when a profile is under 2 years old (extended features up to 5 years):

- Growth charts: weight, length/height, head circumference, BMI, with percentile curves
- Developmental milestones checklist by age (social, language, movement, thinking)
- Feeding log (breast, bottle, solids), sleep, diapers, teething
- Vaccination schedule auto-created from date of birth
- Fever log with age-based alerts
- **Corrected age** for babies born before 37 weeks, used for growth and milestones until age 2

**How the check works**

1. Parent enters a measurement (or scans it from the clinic's growth card).
2. The app looks up the WHO L, M, S values for that exact age and sex.
3. It computes the z-score (how many standard deviations from the median):

```latex
z = \frac{(X / M)^{L} - 1}{L \cdot S}
```

4. It converts z to a percentile, checks the trend against earlier measurements, and shows the result.

| Measure | On track (green) | Watch (yellow) | Check with doctor (red) |
| --- | --- | --- | --- |
| Weight-for-age | z between −2 and +2 | Falls across 2 major percentile lines since last check | z below −2 (underweight) or below −3 (severe) |
| Length/height-for-age | z between −2 and +2 | Growth slowing on the curve | z below −2 (stunting) |
| Weight-for-length / BMI-for-age | z between −2 and +1 | z above +1 (risk of overweight, under 5) | z above +2 (overweight) or below −2 (wasting) |
| Head circumference | z between −2 and +2 | Crossing percentile lines quickly | z below −2 or above +2 |
| Newborn weight | Back to birth weight by about 2 weeks | Slow regain | Lost more than 10% of birth weight |
| Milestones | All expected milestones for age | One milestone late | Several missed, or a skill that was there is lost |

**Urgent alerts (always "see a doctor now")**: fever of 38°C or more under 3 months old; signs of dehydration; difficulty breathing; unusual drowsiness.

**Data sources to bundle**: WHO Child Growth Standards (0–5 years) and WHO Growth Reference (5–19 years); CDC "Learn the Signs. Act Early." milestones (or the local ministry's equivalent). The app never diagnoses; it tells parents when to ask a doctor and builds a growth report to show at the visit.

## Pregnancy and maternal care

A **Pregnancy Mode** on a woman's profile tracks the whole journey, from the first positive test to the 6-week postpartum check. Once she enters the first day of her last period (or the dating-scan date), the app calculates the due date (LMP + 280 days) and the current week. It then creates every check below as a reminder.

&#91;embedded content: pregnancy checks by week · typical schedule\]

Exact weeks vary by country and doctor; the doctor can move any of them.

| Area | What the app tracks |
| --- | --- |
| Visits | Antenatal visits (WHO recommends at least 8 contacts), doctor, hospital chosen for delivery, fees |
| Scans | Every ultrasound with images/video, estimated fetal weight, notes; a "baby album" view |
| Labs | Blood group + Rh, haemoglobin, sugar/glucose test, urine, thyroid, infection screening |
| Vitals | Weight gain vs. a healthy range for her pre-pregnancy BMI; blood pressure; blood sugar if diabetic |
| Medicines & supplements | Folic acid, iron, calcium, vitamin D with reminders; **pregnancy warning** when a new medicine is added ("Ask your doctor before taking this in pregnancy") |
| Vaccines | Tdap, flu, anti-D if Rh negative |
| Baby movement | Kick counter and contraction timer in the third trimester |
| History | Previous pregnancies, miscarriages, C-sections, complications: the summary doctors always ask for |
| Costs | All visits, scans, delivery and hospital stay feed the spending dashboard and insurance policy |

**Danger signs: one big red button "Call my doctor"**, shown on every pregnancy screen:

- Vaginal bleeding or fluid leaking
- Severe headache, blurred vision, or sudden swelling of face/hands
- Blood pressure of 140/90 or higher
- Fever, or severe abdominal pain
- Baby moving less than usual

**After birth**

- One tap creates the **baby's profile** with birth date, weight, length, head size and delivery type. Infant Mode and the vaccine schedule start right away.
- Postpartum check reminders, breastfeeding log, and an optional mood check (the Edinburgh Postnatal Depression Scale) with a prompt to talk to a doctor if the score is high.

**Privacy**: pregnancy data is a private category by default. She chooses who sees it (husband, mother, doctor).

## Insurance cards

Each person can hold **any number of insurance policies**, each with a name they choose, such as "Neqaba", "Work 1", "Work 2", or "Dad's private". Each policy keeps a photo of the card's front and back, so it is always on hand at the clinic or pharmacy.

| Field | Notes |
| --- | --- |
| Custom name | Free text: Neqaba, Work 1, Work 2, anything |
| Card photos | Front + back screenshots/photos; OCR fills member ID and provider |
| Provider / company | e.g. the syndicate, employer insurer, private insurer |
| Member / policy number | Copyable with one tap |
| Plan / class | e.g. Gold, Class A |
| Coverage % and co-pay | Per category if needed: visits, meds, scans, surgery |
| Network | Hospitals, clinics, pharmacies that accept it (links to the shared directories) |
| Valid from / to | **Renewal reminder** created automatically before expiry |
| Hotline / approvals number | One-tap call |
| Primary policy | Mark which card to use first |
| Status | Active / expired |

**How it ties into the rest of the app**

- Any expense (visit, medicine, scan, surgery) can be marked **paid by** a specific policy, with the covered vs. out-of-pocket amounts.
- The spending dashboard can then show **spend per policy** ("Work 1 covered 4,200 EGP this year; we paid 1,100").
- Claims tracker (optional): submitted → approved → reimbursed, with receipt photos attached.
- **Wallet view**: swipe through all the family's cards full-screen at the reception desk; works offline.
- Cards can also be shared with a guardian or shown on the emergency card.

**Share my card via WhatsApp**

One tap on **Share** builds a clean image or PDF of the chosen card and opens WhatsApp, so the patient can send it straight to a hospital receptionist or a doctor's office.

- **What gets sent**: card front + back, patient name, member/policy number, and validity date. Optionally the national ID, chosen per share.
- **Also shareable the same way**: emergency card, visit summary, prescription, lab result, vaccination record, or a growth report.
- **Watermark** on every shared image: "Shared on \<date> for \<clinic name>", to limit misuse.
- **Link option**: instead of an image, send a time-limited link (expires in 24 h) that the receptionist opens in a browser. Only possible when cloud sync is on.
- **Cost: free.** The app uses the phone's normal share sheet into WhatsApp (also Telegram, email, SMS). No paid WhatsApp Business API is needed.
- Every share is logged in the profile's history: what, when, and to which app.

## Reminders and alarms

One generic **Reminder** object covers pills, vaccines, follow-up visits, fever checks, refills and anything else. It is made of four parts, so new reminder types need no new code.

| Part | Options |
| --- | --- |
| What | Free text + optional link to a medication, vaccine, doctor, or event |
| Who | One or more profiles; notify the person, their guardian(s), or both |
| When | Once · every N hours (e.g. fever check every 4 h) · daily at set times · specific weekdays · every N days/weeks/months · for X days or until a date · relative to an event ("2 weeks after surgery", "vaccine due at 6 months old") |
| How | Silent notification · normal · **alarm-style full-screen** (for pills and elderly) · repeat until confirmed · escalate to caregiver if missed after N minutes |

**Ready-made templates** (one tap, then edit)

- Take medicine (from a prescription, auto-created after OCR)
- Next vaccination dose (auto from the national schedule)
- Fever check every 4 hours for 3 days
- Follow-up visit with Dr X in 2 weeks
- Refill: "5 pills left" based on stock and dose
- Measure blood pressure / sugar daily
- Post-surgery: dressing change, stitches removal

**Confirmation actions on the notification:** Taken · Snooze 10 min · Skip (with reason). Each answer is logged, giving an **adherence report** per person (e.g. "Dad took 92% of doses this month").

**Technical note:** reminders are scheduled **locally on the phone** (Android AlarmManager / iOS local notifications). They work offline and cost nothing to send. A guardian's phone gets missed-dose alerts through free push notifications (Firebase Cloud Messaging).

## Automatic follow-ups

The app **suggests follow-ups automatically** from two things it already knows: the **case** just recorded (a visit, diagnosis, medicine, surgery, lab result, pregnancy) and the person's **age and sex**. The user taps **Accept**, edits the timing, or dismisses. The doctor's own instructions always replace the app's defaults.

**How it works**

1. A record is saved, a birthday passes, or a pregnancy week starts.
2. A local **care-plan rule** matches it (rule = trigger + conditions + follow-up items).
3. The app proposes a **follow-up plan**: reminders, measurements to log, a checklist, or a doctor visit, each with a date.
4. Once accepted, the plan runs on the Reminder engine and shows on the person's timeline as "Follow-up for: \<case>".
5. If a follow-up is missed, it escalates to the guardian (for children and elderly profiles).

**Examples by case** (default timings are typical and adjustable)

| Case recorded | Follow-up the app proposes |
| --- | --- |
| Child with fever | Temperature check every 4 h; "see a doctor" alert if fever lasts more than 3 days or the child is under 3 months |
| Antibiotic course | Dose reminders until the course ends; "finished the course?" check on the last day |
| New long-term medicine | Refill reminder from stock; side-effects check-in after 2 weeks; follow-up visit reminder |
| Surgery | Wound/dressing reminders, stitches-removal date, post-op visit, "upload the discharge report" task |
| Abnormal lab result | "Repeat this test" reminder at the interval the doctor sets; result compared with the last one |
| Chronic condition (diabetes, blood pressure) | Regular readings to log, periodic lab tests, regular doctor visits; trend shown on the dashboard |
| Fracture / cast | Follow-up X-ray and cast-removal visit |
| Pregnancy | The full week-by-week schedule (see Pregnancy section) |
| Doctor visit with "come back in 2 weeks" | Follow-up visit reminder with the doctor's card attached |

**Examples by age**

| Age group | Follow-ups created automatically |
| --- | --- |
| Newborn to 2 years | Vaccines from the national schedule, growth measurements at each well-baby visit, milestone checks |
| 2–18 years | Yearly growth check, remaining vaccines, vision and dental check reminders |
| Adults | Periodic checks per local guidelines: blood pressure, blood sugar, cholesterol, dental |
| Women | Pregnancy Mode when activated; screening reminders by age per local guidelines |
| 65+ | Yearly flu vaccine, medication review with the doctor, blood pressure and sugar logs; Simple Mode suggested |

**Where the rules come from**: a small rules file bundled in the app (works offline, free), built from WHO and national ministry guidelines per country. It can be updated without an app release. Rules are labelled as **reminders, not medical advice**. Partner clinics (Phase 3) can later send their own follow-up plans for their patients.

## Spending dashboards

Every event with a cost feeds one **Expense ledger**. Dashboards are views over that ledger, per member and for the whole family, by week, month, or year.

**What the dashboard shows**

- Total spent this week / month / year, and the change vs. the previous period
- Split by category: doctor fees, medication, scans, labs, vaccines, surgery, hospital stays
- Split by family member (stacked bar), so you see who costs the most and why
- Top doctors and pharmacies by spend
- Out-of-pocket vs. insurance-covered amounts
- Recurring monthly medication cost (e.g. "Mum's chronic meds = 850 EGP / month")
- Forecast: next month's expected cost from active prescriptions and scheduled visits

**Useful extras**

- Multi-currency with a family default currency (EGP, SAR, AED, USD…)
- Receipt photo on every expense; OCR reads the total
- Export to CSV/PDF for insurance claims or tax
- Optional monthly budget with an alert when it is exceeded

All charts are computed on the phone from local data, so dashboards need no server.

## OCR for prescriptions and medicine boxes

Recommendation: run free **on-device OCR first**, match the text against a local drug database, and use a paid cloud call **only** for handwritten prescriptions the phone can't read. This keeps OCR cost close to $0 for most users. Hosting your own OCR model on a server is the most expensive option, because it needs a server running 24/7.

| Option | Where it runs | Good at | Weak at | Cost (approx.) |
| --- | --- | --- | --- | --- |
| Google ML Kit Text Recognition | On device (Android + iOS) | Printed English text on boxes and printed prescriptions | Handwriting; Arabic script not in the standard model | Free |
| ML Kit Barcode scanning | On device | Box barcode → exact product lookup | Needs a barcode → drug table | Free |
| Apple Vision (iOS) | On device | Printed text, several languages incl. Arabic on recent iOS | iOS only | Free |
| Google Lens (hand-off) | Google's app | Very good recognition, handwriting | No API: user must copy/share text back into the app; clunky for elderly | Free |
| Google Cloud Vision (document text) | Cloud | Handwriting, Arabic + English | Needs internet; sends a medical image to the cloud | \~1,000 images/month free, then \~$1.50 per 1,000 |
| Small multimodal LLM (e.g. Gemini Flash or Claude Haiku) | Cloud | Reading messy prescriptions and returning structured JSON (name, dose, frequency) | Needs internet + privacy consent | Fractions of a cent per image |
| Self-hosted model (PaddleOCR / TrOCR) | Your server | Full control | Server cost every month even with no users; you maintain it | \~$5–40 / month minimum |

**Suggested pipeline**

1. User taps **Scan** and points the camera at a box or prescription.
2. Phone tries the **barcode** first; if found, look it up in the drug table. Done.
3. Otherwise, **ML Kit / Apple Vision** reads the text on the device.
4. The text is **fuzzy-matched** against a bundled drug list (e.g. the national drug registry for Egypt/KSA plus common international names). Matches show as suggestions: "Did you mean *Augmentin 1g*?"
5. If confidence is low (handwriting), offer **"Improve with cloud"**. With the user's consent, send the image to Cloud Vision or a small LLM, which returns name, dose and frequency.
6. User confirms. The app creates the medication record **and** its pill reminders in one step.

**About Google Lens:** apps can't call Lens directly to get text back. You can open it, but the user has to copy the result and return. That is acceptable as a free fallback for tech-savvy users, but not as the main flow, especially for elderly users.

**Cost control for the cloud step:** limit it to e.g. 20 cloud scans per member per month, cache results, and resize images before upload. At \~$0.002 per scan, 20 scans cost $0.04 per member per month at most; most users will use far fewer.

*Prices are approximate from general knowledge and should be checked against current Google/Anthropic pricing before launch.*

## Elderly-friendly design

Older users get a separate **Simple Mode** with three big buttons, voice everywhere, and a caregiver who can do the setup remotely. The full app stays available to younger family members.

**Simple Mode home screen:** three large buttons only.

- **My medicines today**, shown with pill photos, not just names, and a big "I took it" button
- **Call my caregiver / doctor**, one tap
- **Scan a medicine or paper**

**Accessibility rules**

- Minimum 18–20 pt text, follows the phone's font size, high-contrast theme
- Touch targets at least 56 dp; no swipe-only or long-press-only actions
- Arabic-first, full right-to-left layout, plus English
- **Voice input** for notes and search; **text-to-speech** reads reminders aloud ("It's 9 PM, take one blue Concor pill")
- Pills identified by **photo + colour + shape**, not only by name
- Undo on every action; nothing is deleted without a clear confirm

**Caregiver support**

- A son or daughter manages the parent's profile from their own phone: adds meds, sets reminders, uploads reports
- **Missed-dose escalation**: if the parent doesn't confirm within 30 min, the caregiver gets a push alert
- Weekly adherence summary to the caregiver
- **Refill alerts** go to whoever buys the medicine

**Safety**

- Drug-interaction warning when a new medicine is added (from an offline interaction table, labelled as guidance, not medical advice)
- Duplicate-medicine warning (same active ingredient, two brand names), a common issue with multiple specialists
- Emergency card on the lock screen for paramedics

## Architecture and tech stack

The app is **offline-first**: the phone does the storage, OCR, reminders, and charts. The cloud is used only for opt-in backup/sync, handwriting OCR, and push alerts to caregivers. That is how the app can stay free.

&#91;embedded content: architecture · phone vs. optional cloud\]

Only the four arrows send data off the phone, and each one is opt-in or free.

| Layer | Recommended choice | Why |
| --- | --- | --- |
| Mobile app | Flutter (Android + iOS from one codebase) | One team, strong Arabic RTL support, good camera/ML plugins |
| Local storage | SQLite (Drift) + SQLCipher encryption; images compressed to WebP | Fast, offline, encrypted at rest |
| On-device OCR | Google ML Kit (Android/iOS), Apple Vision (iOS), ML Kit Barcode | Free, private, no server |
| Backup | Export to the user's **own Google Drive as an encrypted file** (default; not iCloud, which Apple's guideline 5.1.3 forbids for health data); Supabase storage as an option | User's storage costs you nothing |
| Family sync | Supabase (Postgres + Auth + row-level security) or Firebase | Generous free tier, sync only metadata + thumbnails |
| Push | Firebase Cloud Messaging | Free |
| Payments | Google Play Billing + StoreKit, optionally via RevenueCat | Handles receipts and restore across devices |
| Crash reports | Firebase Crashlytics | Free |

**Estimated running cost:** $0/month on free tiers for the first few thousand users, then about $25/month (Supabase Pro) as sync grows. Store developer fees: $25 once (Google Play) and $99/year (Apple). *Approximate figures from general knowledge; confirm before launch.*

## Business model: free now, partnerships next

The app launches **free for everyone**: unlimited profiles, members, records, and on-device OCR. Revenue comes later from **partnerships with hospitals, medical centres, and clinics (عيادات)**, which get a verified way to share data with their patients. Because storage and OCR run on the phone, a free app costs about $0–25 a month to run at the start.

**Phase 1: free app (now)**

- No paywall, no ads at launch (labelled clinic listings come with Phase 2). All features open, including family linking and caregiver alerts.
- An encrypted backup file in the user's own Google Drive keeps hosting cost near zero.
- Cloud OCR (handwriting) is capped per user per month to protect the budget.
- Goal: grow families and trust before charging anyone.

**Phase 2: provider partnerships**

Partners get a simple **web portal** (no app needed at the clinic). With the patient's consent, they can:

| Partner capability | What happens in the family's app | Value to the partner |
| --- | --- | --- |
| Send visit summaries, prescriptions, lab and scan results | Arrives as a verified record ("From Clinic X") on the right profile; meds + reminders created automatically | Fewer printouts, fewer "what did the doctor say?" calls |
| Create or claim patient profiles | The clinic registers a newborn or a new patient; the family accepts and the profile joins their account | Faster onboarding; patient stays connected to the clinic |
| Book follow-ups and vaccination dates | A reminder appears with the clinic's address and phone | Fewer no-shows |
| View a patient's shared history (time-limited, patient-approved) | Patient taps "Share with Dr X for 24 h" | Better consultation, no repeated tests |
| Publish fees and accepted insurance | Shows in the doctor card and insurance network | Visibility to families nearby |

**Rules for partner access**

- **The patient (or guardian) owns the data.** A partner sees nothing without an explicit, revocable consent per profile.
- Partner-sent records are labelled as verified and can't be edited by the family; family notes sit beside them.
- Every partner view is logged and visible to the family.

**Clinic partnerships: ads, doctor recommendations, appointment reminders**

Clinics and medical offices can pay for three things. All three are allowed by the stores **if ads are never targeted using a person's health data**. Apple bans using health data for advertising or marketing (guideline 5.1.3). So ads are matched to what the user is doing at that moment (city, specialty searched), never to their diagnoses, medicines or pregnancy.

| Partner product | How it works for the family | How the clinic pays | Rules that keep it trusted |
| --- | --- | --- | --- |
| **Sponsored listings** | In the doctor/clinic directory and "Find a doctor" search, a partner can appear at the top for its city and specialty, marked **Sponsored** | Monthly fee per branch, or per profile view / booking | Always labelled; max 1–2 per screen; **never on health records, reminders, emergency or pregnancy screens**; no pop-ups; targeting only by city + specialty the user chose; one switch to hide sponsored items |
| **Doctor recommendations** | (a) The patient's own doctor sends advice, instructions or a care plan into the app after a visit ("rest 3 days, repeat test in 1 month"), which becomes follow-up reminders. (b) A "Recommended doctors" list based on ratings from verified visits | Included in the partner subscription | Recommendations ranked by verified ratings and distance, **not by payment**; paid placement only in the separate Sponsored slot; doctors can only message their own patients, with consent |
| **Appointment reminders** | The clinic books the next visit in its portal; the patient gets a kind reminder: "Your follow-up with Dr Ahmed is on Sunday 10:00. Tap to confirm, reschedule, or get directions" | Push notifications: included. SMS/WhatsApp to patients without the app: paid per message by the clinic | Patient can mute a clinic; confirm/cancel goes straight back to the clinic, reducing no-shows |

**Local rules to check before selling ads**: advertising medical services and doctors is regulated in the region (e.g. health-ad approvals in KSA, medical syndicate ethics rules in Egypt). Ad wording and who may advertise need legal review per country before launch.

**Possible revenue options later** (pick after Phase 2 traction)

| Option | Who pays | Notes |
| --- | --- | --- |
| Partner subscription | Clinic / hospital, monthly per branch | Main recommended path; families stay free |
| Per-record or per-booking fee | Partner | Simple for small clinics |
| Sponsored listings (clinic ads) | Clinic / doctor, monthly or per view/booking | Labelled, contextual only (city + specialty); never targeted by health data |
| Appointment reminders by SMS/WhatsApp | Clinic, per message | Push reminders free; paid only for patients without the app |
| Cloud Plus (hosted backup + sync with photos) | Family, small yearly fee | Optional; free tier unchanged |
| One-time member fee ($1, Trio $2…) | Family | Kept as a fallback if partnerships are slow |

**Running cost while free (approximate):** $25 once for Google Play, $99/year for Apple, and $0–25/month for Supabase/Firebase until roughly tens of thousands of active families.

## Privacy, security and compliance

Medical data is the most sensitive data a family has, so the default is **nothing leaves the phone unless the user says so**. That also simplifies compliance, because a local-only app processes far less personal data on its servers.

- **Encryption**: database encrypted at rest (SQLCipher); app lock with PIN / fingerprint / Face ID; backups encrypted before upload.
- **Consent per action**: cloud OCR, family sync, and partner sharing each ask separately and can be turned off.
- **Granular sharing**: per profile and per category; time-limited share links; private categories hidden from guardians.
- **Audit log**: who viewed or edited what, including partner clinics.
- **Data rights**: export everything (PDF + ZIP) and delete the account and cloud copies at any time.
- **Hosting region**: keep cloud data in a region acceptable for the target markets.
- **Laws to review before launch**: all five target markets treat health data as sensitive. Cloud features trigger licences (Egypt, Morocco) or in-country hosting (UAE, likely KSA), and dose/interaction features may count as medical devices in KSA. See the MENA research tab. Partner integrations will need a data-processing agreement per partner.
- **Not a medical device**: dose calculators, interaction warnings, and OCR suggestions are labelled as guidance; the user always confirms.

*Legal points are general; a local lawyer should confirm them before partner launch.*

## Using the data: rules, cost and store approval

You can learn from the data, **but only with opt-in consent, de-identified, kept in-country, and never sold or used to target ads**. Done that way, neither Apple nor Google will reject the app. What gets health apps rejected or removed is undisclosed collection, ads use, selling data, iCloud storage of health data, or a missing in-app account deletion.

**What the stores require**

| Rule | Apple App Store | Google Play |
| --- | --- | --- |
| Ads, marketing, data mining | Health data may not be used or disclosed for advertising, marketing or data mining, except to improve health management or for health research with permission ([5.1.3 i](https://developer.apple.com/app-store/review/guidelines/)) | Health Connect data is personal and sensitive data with extra limits ([Health apps policy](https://support.google.com/googleplay/android-developer/answer/16679511?hl=en)) |
| Selling data | Data may only be shared with third parties to improve the app or serve ads ([5.1.2 i](https://developer.apple.com/app-store/review/guidelines/)); health data never for ads | **"Not sell personal and sensitive user data"** ([User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en)) |
| Where data lives | **Personal health information may not be stored in iCloud** (5.1.3 ii) | — |
| Consent | Research needs participant (or parent) consent **and approval from an independent ethics board** (5.1.3 iii–iv) | An in-app disclosure right before the consent request; nothing collected before consent |
| Account deletion | In-app account deletion required (5.1.1 v) | Deleting the account must delete its data |
| Declarations | Privacy "nutrition" label must match what you collect | Health apps declaration form, Data safety form, privacy policy; "not a medical device" disclaimer + "consult a healthcare professional" unless approved as a device |

**Five levels of data use, from safest to not allowed**

| Level | What you collect | Consent | Store and legal risk | Rough running cost |
| --- | --- | --- | --- | --- |
| 0. Nothing | All data stays on the phone | — | Lowest | $0 |
| 1. Product analytics | Screens used, crashes, feature use; **no health data, no names** | Disclosed in the privacy policy and store forms | Low | $0 on Firebase / PostHog free tiers |
| 2. On-device aggregates | The phone computes counts (e.g. "uses 3+ chronic meds", "has an active pregnancy") and sends only totals, no IDs; groups under a minimum size dropped | Opt-in toggle | Low | \~$0–25/month (small database) |
| 3. De-identified research dataset | Records without names/IDs, pseudonymised, stored **in-country**, encrypted | Explicit research consent per person (parent for children) + ethics board approval | Medium: needs DPIA, DPO, Egypt PDPC licence, local hosting | Servers small; main cost is legal and compliance work |
| 4. Selling or sharing with pharma, insurers, advertisers | — | — | **Not allowed**: Google bans sale; Apple bans health data for ads/data mining; breaks user trust | — |

**Recommended path**

1. Launch with **Level 1** only. Put "Your health data stays on your phone" on the store page and the first screen: trust is the product.
2. Add **Level 2** with an opt-in "Help improve the app" toggle once there are users; it already answers most questions (which features help, which conditions are common).
3. Consider **Level 3** only with a partner (a university or ministry), an ethics board approval, and legal sign-off. Use it to publish health insights or improve OCR and reminders, never to sell data.
4. Partners (clinics) receive a patient's data only when that patient shares it, record by record.

**Checklist before any data leaves the phone**: privacy policy in Arabic + English · store privacy label and Data safety form · per-feature consent screens · data protection impact assessment · data protection officer · Egypt PDPC licence and in-country hosting where required · encryption in transit and at rest · retention limit and deletion · penetration test.

*Store rules quoted from Apple's and Google's policy pages as of November 2026; costs are rough estimates.*

## Roadmap and open decisions

Ship a free, phone-only MVP first. Add family sync and caregiver features next, then pilot the partner portal with one or two clinics before charging anyone.

&#91;embedded content: roadmap · 4 phases, 3 gates\]

Each phase starts only when the gate above it is met; durations depend on team size and are not set yet.

**Feature plan by phase** (Android + iOS together from Phase 1)

| Feature | What it does | Phase | Why it matters |
| --- | --- | --- | --- |
| Backup, restore and recovery | Encrypted backup file to the user's Google Drive (both platforms) or a local file; restore on a new phone with a recovery key | 1 | Offline-first means a lost phone = lost history without it. Apple forbids personal health data in iCloud (guideline 5.1.3) |
| Reliable alarms on all Android brands | Guides the user to allow exact alarms and turn off battery saving for the app (Xiaomi, Oppo, Samsung…) | 1 | Budget Android phones common in Egypt often kill reminders |
| Home-screen widget: "Today's medicines" | Shows next doses with a "Taken" button, on Android and iOS | 1 | Elderly users see doses without opening the app |
| Family health summary PDF | One tap before a visit: conditions, allergies, current meds, recent results, last visits | 1 | Saves the doctor's first 10 minutes of questions |
| Bulk import of old paper files | Photograph a stack of old prescriptions and reports; OCR sorts them by person and date | 1 | Families start with years of paper |
| Emergency SOS | One tap calls the ambulance (Egypt 123, KSA 997, UAE 998) and sends location + emergency card to family | 1 | Critical for elderly and children |
| Account and data deletion in the app | Deletes the account and all cloud copies | 1 | Required by both Apple and Google |
| Hijri + Gregorian dates, Arabic numerals | User picks calendar and digits | 1 | Expected in KSA and by older users |
| Home medicine cabinet | Stock at home, expiry dates, "expires next month" alerts | 2 | Avoids expired or duplicate medicines |
| Import vitals from Health Connect / Apple Health and wearables | Steps, heart rate, BP, glucose, weight, SpO2 into the person's log | 2 | Less typing; better trends. Data read this way may never be used for ads |
| WhatsApp or SMS reminders for elderly without smartphones | Dose and visit reminders sent to a basic phone, paid per message, opt-in by the guardian | 2 | Reaches grandparents with feature phones; via an SMS/WhatsApp provider (e.g. Unifonic, Twilio) |
| Lab result trends | Charts each test over time with its normal range | 2 | Shows doctor and family whether things improve |
| Visit prep and doctor's voice note | Question list before the visit; record the doctor's instructions (with the doctor's consent) | 2 | Elderly patients forget instructions |
| Change phone / multi-device | Same account on two phones, or a phone and a tablet | 2 | Families replace phones often |
| Medicine price comparison across pharmacies | Compares price, availability, delivery fee and cheaper generics | 3 | Needs pharmacy partners' data; in regulated-price markets the value is mostly availability and generics |
| Clinical module | Dose calculator, interaction warnings, growth flags | 3 | May count as a medical device in KSA (SFDA MDS-G27): ship after regulatory review, behind a switch |

**Open decisions**

- [ ] First market: Egypt, KSA, or both? (Sets language defaults, vaccine schedules, drug list)
- [x] Platforms: Android + iOS together (decided)
- [ ] Flutter vs. React Native
- [ ] Which drug database to bundle, and how to keep it updated
- [ ] App name: Usra recommended; run trademark and store-name checks
- [ ] First pilot clinic or hospital
