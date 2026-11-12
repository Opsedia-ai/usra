---
name: usra-paediatrics
description: Medical guardrails for any Usra feature about children from birth to 18 - vaccines and catch-up, WHO growth charts and typo checks, fever and warning signs, development milestones, and the Arabic wording for a boy or a girl. Use before designing, building or reviewing anything a parent sees about a child, and when preparing questions for the paediatrician.
---

> **Draft. Not reviewed by a doctor. A paediatrician (skill 1), a geriatrician or GP (skill 2), and a clinical safety reviewer (skill 3) must review and sign off before this is relied on.**

# Usra paediatrics

This skill guides whoever builds or reviews Usra. It is not medical advice for families. Usra records, reminds and cites. It never diagnoses, never says a child is "fine", and never suggests a medicine or a dose (Apple 1.4.2, PRD "Compliance and medical safety").

Read `usra-clinical-safety` too: every medical string goes through its content governance and hazard log.

## The rules

1. **Every medical statement has a source in the app.** Show its name and date where the family sees the statement. Sources are in `references/sources.md`. If you can't find a primary source, don't ship the statement; write "unverified" in the PR and ask the paediatrician.
2. **Never reassure.** No "normal", "fine", "healthy", "nothing to worry about", "طبيعي", "سليم", "مفيش قلق". Say where the value sits against a named reference ("within the WHO reference range for this age") and always leave the door open: "If you're worried, contact the doctor or call 123."
3. **Escalate clearly, in two levels only:** "Call an ambulance (123) now" or "Contact a doctor now". Never "monitor at home" as the only advice. See `usra-clinical-safety` for the pattern.
4. **Never compute or suggest a dose,** not even paracetamol by weight. The only medicine arithmetic is the family's own "hours between doses" (risk M2).
5. **Text follows the child's sex** in Arabic, and the reader's sex when it addresses the user. Test both. See `references/wording.md`.
6. **Catch typing mistakes before they become medical advice.** Every number a parent types (weight, height, head, temperature, date) gets a plausibility check: refuse what can't be true, ask "Is this right?" for what is very unlikely. See `references/growth.md`.
7. **The card and the doctor are the reference.** For vaccines, the child's health-office card and the child's doctor outrank the app. Say so wherever a date is assumed.

## Which reference to open

| Feature | Read |
|---|---|
| Vaccine schedule, overdue, catch-up | `references/vaccines.md`, then `docs/research/egypt-vaccine-schedule.md` |
| Weight, height, head, BMI | `references/growth.md` |
| Fever, sick days, warning signs | `references/fever.md`, then `docs/research/fever-warning-signs.md` |
| Development milestones | `references/milestones.md` |
| Any parent-facing text | `references/wording.md` |
| Reviewing a PR, or asking the doctor | `references/checklist-and-questions.md` |

## Ages Usra must handle

- **Under 3 months:** any fever of 38 °C or more is high risk (NICE NG143 1.2.12). Never let this case fall through a generic path.
- **Under 5:** WHO Child Growth Standards (0-60 months), the MoHP schedule (birth to 18 months), CDC milestones (2 months to 5 years). The app follows children on these screens until their 5th or 6th birthday.
- **5 to 18:** no growth chart in v1 (WHO 2007 reference exists, see `references/growth.md`), school doses shown as reminders only, adult fever list from 18 (an open question for the doctor).
- **Preterm babies:** the PRD (F9) asks for corrected age. The app doesn't do it yet (hazard H-N1). Until it does, growth and milestone screens for a baby born early must say they use the birth date.

## Before you merge

Run `references/checklist-and-questions.md`. Add any new medical text to `docs/medical-review-changes.md`, and any new hazard to `docs/clinical-safety/hazard-log.md`.
