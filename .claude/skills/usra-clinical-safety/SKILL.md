---
name: usra-clinical-safety
description: Clinical safety process for building Usra - hazard log and sign-off modelled on NHS DCB0129, governance of medical text, the "not a medical device" boundary (EU MDR, FDA, Egyptian Drug Authority), testing medical calculations, red-flag escalation, handling a reported medical error, health-data privacy and store rules (Apple 1.4 and 5.1.3, Google Play health apps), and the release checklist. Use for any change that touches medical text, a medical number or calculation, reminders, warnings, health-data storage or sharing, and before every release.
---

> **Draft. Not reviewed by a doctor. A paediatrician (skill 1), a geriatrician or GP (skill 2), and a clinical safety reviewer (skill 3) must review and sign off before this is relied on.**

# Usra clinical safety

This skill is for whoever builds, reviews or releases Usra. It sets how we keep the app from harming a family. It is not medical advice. Child and older-adult content rules are in `usra-paediatrics` and `usra-older-adults`.

## The five rules

1. **Usra records, reminds and cites. It doesn't diagnose, treat, dose or check.** Anything past that line can make it a medical device. Before adding a feature, run `references/samd-boundary.md`.
2. **Every medical string is sourced, versioned and approved by a doctor,** and goes back to the doctor when it changes (`references/content-governance.md`, `docs/medical-review-changes.md`).
3. **Every hazard is in the hazard log** (`docs/clinical-safety/hazard-log.md`) with its controls, and a named clinical safety reviewer signs it off before a release (`references/risk-process.md`).
4. **Every medical number is checked:** against the published reference table, at its boundaries, and for plausibility when typed (`references/calculations.md`).
5. **When in doubt, escalate, never reassure:** "Call 123 now" or "Contact a doctor now" (`references/escalation-and-incidents.md`).

## What to open

| Task | Read |
|---|---|
| New feature, or a change to medical behaviour | `references/samd-boundary.md`, then `references/risk-process.md` |
| Adding or changing medical text | `references/content-governance.md` |
| A calculation, threshold, schedule or chart | `references/calculations.md` |
| A warning, red flag or emergency button | `references/escalation-and-incidents.md` |
| A family reports a wrong medical result | `references/escalation-and-incidents.md`, "Incidents" |
| Storage, backup, sharing, notifications, store forms | `references/privacy-and-stores.md` |
| Preparing a beta or store release | `references/release-checklist.md` |
| Where a rule comes from | `references/sources.md` |

## Every PR

The self-review comment has a "Production impact" section ending in **NONE / LOW / MEDIUM / HIGH** with one line of justification. For a medical change also state:

- Hazards touched (IDs from the hazard log), new hazards added.
- Medical text added or changed, and whether it's in `docs/medical-review-changes.md`.
- Sources added, with their status (verified, partly verified, unverified).
- Whether the change needs the clinical safety reviewer before release.

Any PR that adds or changes medical text, a threshold, a schedule, a warning or a calculation is **at least MEDIUM** until a doctor has approved it.
