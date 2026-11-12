# Blood pressure, blood sugar and falls

> Draft. Not reviewed by a doctor. A geriatrician or GP must sign off before this is relied on. None of this is built yet (outside pregnancy).

## Principles for any reading

1. **The person's own target comes first.** If the doctor gave a target ("keep it under 130/80", "fasting 90-150"), the family can type it and the app compares with that, labelled "Your doctor's target".
2. **Otherwise show one named guideline, as information:** "ESC 2024: 120-139/70-89 is called 'elevated' for office readings." Always with the guideline name and year, a "Source" link, and "One reading doesn't diagnose anything. Show your readings to your doctor."
3. **The geriatrician or GP picks the guideline** (ESC or AHA for blood pressure differ; see below). Ship only one.
4. **Red flags escalate,** everything else is neutral. No green "good", no "normal".
5. **Plausibility checks** catch typos before any label is shown (build-team proposals, no source; the doctor confirms):
   - Systolic 50-300, diastolic 20-200, systolic greater than diastolic; outside: refuse. Below 70 or above 220 systolic: "Is this right?"
   - Sugar 10-1000 mg/dL (0.6-55 mmol/L); outside: refuse. Below 40 or above 500 mg/dL: "Is this right?" Ask the unit once and remember it: Egypt uses mg/dL; a value under 35 is probably mmol/L.

## Blood pressure

| Guideline | Categories (adults, office readings) | Home readings | Status |
|---|---|---|---|
| ESC 2024 (McEvoy et al., Eur Heart J 2024;45:3912-4018) | Non-elevated < 120/70; elevated 120-139/70-89; hypertension ≥ 140/90 | Hypertension ≥ 135/85 | Citation and office values partly verified (search excerpts of the guideline and ESC press page); home value from national-society commentaries: **unverified** against the guideline text |
| AHA/ACC 2025 (Jones DW et al., published 14 Aug 2025, JACC doi:10.1016/j.jacc.2025.05.007, and Hypertension) | Normal < 120 and < 80; elevated 120-129 and < 80; stage 1 130-139 or 80-89; stage 2 ≥ 140 or ≥ 90. Severe hypertension > 180/120 | Not opened | Citation verified (ACC page, 2026-11-12); categories from search excerpts: **partly verified** |
| ESH 2023 | Not opened | Not opened | **Unverified** in this session |

The two families of guidelines differ: 130/82 is "elevated" under ESC and "stage 1 hypertension" under AHA/ACC. Showing both would confuse. Doctor question.

**Red flags** (wording for the doctor to approve):
- Very high reading (AHA/ACC: above 180/120) **with** chest pain, shortness of breath, back pain, weakness or numbness, change in vision or difficulty speaking: "Call an ambulance (123) now." The symptom list is from AHA patient material seen in search excerpts: **unverified** against the AHA page (it blocked automated reading).
- Very high reading without symptoms: "Measure again after 5 minutes of rest. If it's still this high, contact your doctor today." **Unverified**; the doctor sets it.
- Low reading with fainting or dizziness on standing: falls risk (NICE NG249 asks for a lying and standing blood pressure in a falls assessment). "Contact your doctor." Doctor sets the wording.

Pregnancy uses its own thresholds (WHO 140/90 and 160/110, `app/lib/features/pregnancy/pregnancy.dart`) and the obstetrician's review. Don't reuse them for older adults.

## Blood sugar

ADA Standards of Care in Diabetes 2026 (Diabetes Care 2026;49 Suppl 1).

- **Hypoglycaemia** (section 6): level 1 below 70 mg/dL (3.9 mmol/L) and at least 54; level 2 below 54 mg/dL (3.0 mmol/L), which needs immediate action. **Partly verified** (search excerpts of the 2026 chapter; full text blocked).
- **Older adults** (section 13, table 13.2, verified 2026-11-12): goals depend on health status, which the app can't judge:

  | Health status | Fasting or before meals | Bedtime |
  |---|---|---|
  | Healthy | 80-130 mg/dL | 80-180 mg/dL |
  | Complex or intermediate | 90-150 mg/dL | 100-180 mg/dL |
  | Very complex or poor health | 100-180 mg/dL | 110-200 mg/dL |

  So **the app must not pick a row.** It shows the doctor's target if typed, and otherwise only the hypoglycaemia line, with ADA named.
- ADA 13.14a-c: deintensify or simplify treatment to reduce hypoglycaemia risk in older adults. That's the doctor's decision; the app's part is a clear log of lows to show the doctor.

**Red flags** (doctor to approve): a reading below 54 mg/dL, or any low with confusion, drowsiness or a fit: "Call an ambulance (123) now" if the person can't swallow safely or isn't responding; otherwise "Contact your doctor now". **Unverified**: the split between 123 and the doctor needs the GP. Never tell the family what to eat or drink, or how much, without the doctor's approved text.

## Falls

NICE NG249, Falls: assessment and prevention in older people and in people 50 and over at higher risk (published 29 Apr 2025, verified 2026-11-12):

- 1.1.1: **don't use falls risk prediction tools** to predict a person's risk. So Usra must never show a "falls risk score".
- 1.1.2: ask people whether they've fallen in the last year. A simple log (date, time, where, injured?, could they get up alone?, lost consciousness?) gives the doctor exactly this.
- 1.1.3: a comprehensive falls assessment is offered to someone who fell in the last year and is living with frailty, was injured and needed treatment, lost consciousness, couldn't get up alone, or fell twice or more in a year.

What the app may do:
- After a logged fall that matches any 1.1.3 item: "Tell your doctor about this fall. Doctors can check what makes falls more likely." Show NICE as the source.
- After any fall with a head injury, loss of consciousness, or not being able to get up: escalation wording for the GP to set ("call 123" or "contact a doctor now"). **Unverified**: NICE NG249 covers assessment, not emergency triage.
- Put falls on the doctor summary.

Never say "low risk of falling", never score, never suggest exercises or stopping a medicine.
