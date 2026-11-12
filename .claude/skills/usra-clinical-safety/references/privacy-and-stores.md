# Health-data privacy and store rules

> Draft. Not legal advice. The Egyptian lawyer must confirm the PDPL points. Details of how Usra stores data are in `docs/security.md`.

## Apple App Review Guidelines (last updated 16 Oct 2026, checked 2026-11-12)

- **1.4.1:** medical apps that could give inaccurate information, or could be used to diagnose or treat, get greater scrutiny. Apps must disclose data and methodology for accuracy claims, and **should remind users to check with a doctor** before making medical decisions. Apps may not claim to measure blood pressure, temperature, blood glucose or oxygen with the phone's sensors alone.
- **1.4.2:** drug dosage calculators must come from a drug manufacturer, hospital, university, insurer, pharmacy or other approved entity, or be FDA-approved (or equivalent). Usra is none of these: **no dose calculation of any kind.**
- **5.1.3(i):** health data may not be used or shared for advertising, marketing or data mining. **5.1.3(ii):** apps may not store personal health information in iCloud. Usra keeps health data out of iCloud and iCloud device backup (risk S3: widget with no names; OS backup excluded).
- **5.1.1(v):** account sign-in rules (risk S1) and in-app account deletion (risk S5).

## Google Play, Health Content and Services (checked 2026-11-12)

- Every developer completes the **Health apps declaration** in Play Console (App content).
- A privacy policy link in Play Console **and** in the app, on a public, non-geofenced web page (not a PDF), covering personal and sensitive data.
- Health and medical apps that aren't regulated devices must put this in the store description: **"not a medical device and does not diagnose, treat, cure, or prevent any medical condition"**, and remind users to consult a healthcare professional.
- The Data safety form must match what the code does.

## Egypt: Personal Data Protection Law 151 of 2020

Found via law-firm summaries on 2026-11-12, **partly verified, not read in the Official Gazette:**

- Health data is **sensitive personal data**, and **all data about children is sensitive**.
- The executive regulations were issued in November 2025 (reported as Ministerial Decree 816 of 2025; one source says 81), with a **one-year compliance period**, which ends around **November 2026**.
- Most controllers and processors need a **licence or permit from the Personal Data Protection Centre**; transfers outside Egypt need their own licence or permit.

Usra keeps health data on the phone, which limits exposure, but the account (name, email in Supabase Frankfurt) and any server backup are processing and transfer. This is already the lawyer's question (risks L1, L2; `docs/login-setup.md` step 6). **Add the children's-data and licensing points to that question now**, because the compliance period is ending.

## Rules for builders

1. Health data stays on the phone, encrypted (SQLCipher-family database, encrypted photos), out of OS backups and iCloud.
2. Nothing sensitive in logs, notifications, the widget, URLs, crash reports or analytics (no analytics SDK in v1).
3. Discreet mode on by default: neutral reminder text.
4. Sharing (PDF, WhatsApp, insurance card) is always started by the user, shows what will be shared, and carries the watermark or the "made by the family" line.
5. Delete all data and delete account are in the app.
6. Any new data leaving the phone needs: a cost check (`usra-cost-check`), a privacy-text update, a Data safety and privacy-label update, and the lawyer's answer for Egypt.
7. Children's records get no weaker protection than adults'.
