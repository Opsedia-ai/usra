# The "not a medical device" boundary

> Draft. Not legal advice. A regulatory lawyer or consultant must confirm Usra's status in each market; the clinical safety reviewer should agree the feature list.

Usra's intended purpose, as it should be written in the store listing and privacy texts: **"Usra helps a family keep their own health records, reminders and appointments on their phone, and shows published schedules and guidance with their sources. It does not diagnose, treat or give medical advice."**

The intended purpose is what regulators look at. A feature, a store screenshot or a marketing line can change it.

## The three regimes

### EU: MDR 2017/745 and MDCG 2019-11 rev.1 (June 2025)

Checked 2026-11-12 (MDCG PDF, decision steps and Rule 11).

- **Decision step 3:** software that does no more than **storage, archival, communication, simple search or lossless compression** isn't a medical device software (MDSW) on that basis. Step 4: software that isn't for the benefit of individual patients (population data, generic pathways, literature) isn't either.
- **Rule 11a:** MDSW that provides information used to take decisions with diagnostic or therapeutic purposes is **class IIa**; IIb if a wrong decision could cause serious deterioration or surgery; III if it could cause death or irreversible deterioration. 11b: monitoring physiological processes. 11c: everything else, class I.
- The guidance names apps that calculate an anticoagulant dose, or fertility status, as MDSW.
- A proposed revision of Rule 11 (Dec 2025) was reported; not checked: **unverified**.

### US: FDA

- **Policy for Device Software Functions and Mobile Medical Applications** (examples page current as of 29 Sep 2022, checked 2026-11-12): FDA intends to exercise enforcement discretion for software that keeps track of medications and gives user-configured reminders, and for historical trending of vital signs; software that gives patients simple tools to organise and record their health information is listed as not a device function (guidance PDF seen via search excerpt: **partly verified**).
- **General Wellness: Policy for Low Risk Devices** (final guidance, January 2026, docket FDA-2014-N-1039, checked 2026-11-12): covers wellness-only products. From an FDA town hall (11 Feb 2026, via search, **partly verified**): wellness notifications shouldn't name a disease, call outputs abnormal, or include clinical thresholds.
- Clinical decision support guidance (2022): not opened, **unverified**.

### Egypt: Egyptian Drug Authority (EDA)

- Medical devices must be registered with the EDA before sale, and EDA documents define devices to include software. EDA's UDI guidance has SaMD-specific requirements. Found via search on 2026-11-12; **no EDA SaMD qualification guideline was found, so the Egyptian position is unverified.** Ask an Egyptian regulatory lawyer, together with the PDPL questions.
- Saudi Arabia's SFDA has its own guidance (MDS-G027, already in `docs/decisions.md` for the AI feature). Check before the Saudi launch.

## Feature test

| Feature | Likely side of the line | Why |
|---|---|---|
| Records, photos, PDFs of what the family typed | Not a device | Storage, archival, communication |
| Reminders the family sets, Taken / Snooze | Not a device (EU); enforcement discretion (FDA) | User-configured reminders |
| Charts of the family's own readings over time | Not a device, if no interpretation | Trending only |
| Published schedule (MoHP vaccines) shown by the child's age | Grey: arguably generic information applied to one child. Keep it as "the published schedule" with the source, and "the card and the doctor are the reference" | Individual-patient benefit is arguable |
| Growth percentile against WHO tables | Grey. Show the position against a cited reference; no diagnosis words, no advice | Calculation for an individual |
| Fever warning signs matched to the logged temperature and age | Grey. Present as published guidance with sources; always escalate to a person, never "no need to see a doctor" | Information that feeds a decision |
| **Dose calculator** (by weight or age) | **Device** (MDCG names one); Apple 1.4.2 | Therapy decision |
| **Interaction, duplicate or "safe together" checker** | **Device** | Therapy decision |
| **Symptom checker or triage that says what's wrong or "it's not serious"** | **Device** | Diagnosis |
| **Risk scores** (falls, heart, diabetes) | **Device** | Diagnosis or prevention by analysis |
| **AI that interprets results or suggests diagnoses** (Dr. Usra AI) | **Device**, unless limited to explaining text with no individual advice | Off in v1 (PRD F26); risk P10 |
| Reading a value from a photo (OCR) | Not a device while the family confirms each value | Data entry |

## How to stay on the right side

- Show, cite and refer; don't interpret. "Within the WHO reference range (percentile 40). Source: WHO 2006." is information; "Your child is growing well" is a claim.
- Never compute a dose. The only medicine arithmetic is calendar days and the family's own hours.
- Every grey feature ends with a person: "ask your doctor", "call 123".
- Keep the "not a medical device" line in the app and both store listings (Google Play requires the exact disclaimer, see `privacy-and-stores.md`).
- Store screenshots and marketing must not claim more ("detects", "diagnoses", "keeps your child safe").
- Any feature in the bold rows needs the founder, a regulatory opinion and a new hazard analysis first. Don't build it.
