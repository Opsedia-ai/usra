# Sources for usra-clinical-safety

Status meanings are the same as in `usra-paediatrics/references/sources.md`: Verified, Partly verified, Unverified.

| # | Source | Version or date | URL | Checked | Status | Used for |
|---|---|---|---|---|---|---|
| C1 | NHS Digital, DCB0129 Clinical Risk Management: its Application in the Manufacture of Health IT Systems, specification | v4.2, Amd 24/2018, released 7 Jun 2018; page last edited 21 Jul 2025; under review | https://digital.nhs.uk/data-and-information/information-standards/governance/latest-activity/standards-and-collections/dcb0129-clinical-risk-management-its-application-in-the-manufacture-of-health-it-systems (read through a mirror of the same page and its PDFs) | 2026-11-12 | Verified (CSO, hazard log, safety case requirements) | Process, roles |
| C2 | DCB0129 implementation guidance | v3.2, 2 May 2018 | Same page, "Implementation Guidance" PDF | 2026-11-12 | Verified (tables 7-10) | Severity, likelihood, risk matrix |
| C3 | MDCG 2019-11 rev.1, Qualification and classification of software, Regulation (EU) 2017/745 and 2017/746 | June 2025 | https://health.ec.europa.eu/medical-devices-sector/new-regulations/guidance-mdcg-endorsed-documents-and-other-guidance_en | 2026-11-12 | Verified (decision steps 3-4, Rule 11 sub-rules, dose-calculator example) | SaMD boundary, EU |
| C4 | Proposed revision of MDR Rule 11 | Reported Dec 2025 | - | - | **Unverified** | Watch item |
| C5 | FDA, Examples of software functions for which the FDA will exercise enforcement discretion | Content current as of 29 Sep 2022 | https://www.fda.gov/medical-devices/device-software-functions-including-mobile-medical-applications/examples-software-functions-which-fda-will-exercise-enforcement-discretion | 2026-11-12 | Verified (medication reminders, vital-sign trending) | SaMD boundary, US |
| C6 | FDA, Policy for Device Software Functions and Mobile Medical Applications | Sep 2022 | https://www.fda.gov/media/80958/download | 2026-11-12 | Partly verified (search excerpt: "simple tools to organize and record their health information") | Personal health records |
| C7 | FDA, General Wellness: Policy for Low Risk Devices | Final, January 2026, docket FDA-2014-N-1039 | https://www.fda.gov/regulatory-information/search-fda-guidance-documents/general-wellness-policy-low-risk-devices | 2026-11-12 | Verified (date, status); town-hall points partly verified | Wellness boundary |
| C8 | Egyptian Drug Authority, medical device registration and UDI guidance | 2026 documents found via search | https://www.edaegypt.gov.eg | 2026-11-12 | **Unverified** for SaMD qualification (no EDA software guideline found) | Egypt boundary |
| C9 | Apple, App Review Guidelines | Last updated 16 Oct 2026 | https://developer.apple.com/app-store/review/guidelines/ | 2026-11-12 | Verified (1.4.1, 1.4.2, 5.1.3) | Store rules |
| C10 | Google Play Console Help, Health Content and Services | Page current on check date | https://support.google.com/googleplay/android-developer/answer/16679511 | 2026-11-12 | Verified (declaration, privacy policy, disclaimer wording) | Store rules |
| C11 | Egypt Personal Data Protection Law 151 of 2020 and its executive regulations | Regulations reported issued Nov 2025 (Decree 816 of 2025, one source says 81) | Law-firm summaries, e.g. https://cms.law/en/are/legal-updates/egypt-s-pdpl-executive-regulations-issued-one-year-compliance-countdown-begins | 2026-11-12 | Partly verified (secondary sources only) | Privacy, licensing |
| C12 | Usra PRD v1, decisions, risks, security | 7 Nov 2026 | `docs/prd-v1.md`, `docs/decisions.md`, `docs/risks.md`, `docs/security.md` | 2026-11-12 | Repo | Scope, controls |

ISO 14971 (risk management for medical devices), IEC 62304 (software life cycle) and IEC 82304-1 (health software) are the device-industry equivalents of this process. They weren't opened (paid standards): **unverified** here, and only needed if Usra ever becomes a device.
