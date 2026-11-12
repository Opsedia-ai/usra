---
name: usra-older-adults
description: Medical and design guardrails for Usra features used by or for grandparents and adults over 65 - medicine lists for the doctor (never interaction checks), reminders and Simple Mode, blood pressure, blood sugar and falls logging with named reference ranges, accessibility and cognitive load. Use before designing, building or reviewing anything an older person or their caregiver sees, and when preparing questions for the geriatrician or GP.
---

> **Draft. Not reviewed by a doctor. A paediatrician (skill 1), a geriatrician or GP (skill 2), and a clinical safety reviewer (skill 3) must review and sign off before this is relied on.**

# Usra for older adults

This skill guides whoever builds or reviews Usra. It is not medical advice for families. Usra keeps the list, rings on time and shows the source. The doctor and the pharmacist make every decision. Read `usra-clinical-safety` too.

## The rules

1. **A clear list for the doctor, never a check.** Usra shows every current medicine as the family typed it, with dose text word for word, for whom, since when and who prescribed it. It never checks combinations, duplicates, doses, kidney or age suitability (Apple 1.4.2; the PRD; an interaction checker would make Usra a medical device, see `usra-clinical-safety`). Wording in `references/medicines-and-reminders.md`.
2. **Reminders that can't be misread.** Who, what and when on every reminder; Taken is easy to undo; a missed dose never tells anyone to double up or "take it now".
3. **Readings are information with a source,** not a verdict. A blood-pressure or sugar reading can show where it sits against a named guideline, with the guideline's name and year, and "one reading doesn't diagnose anything". The doctor's own target, if the family enters it, comes first. See `references/readings.md`.
4. **Escalate red flags in two levels:** "Call an ambulance (123) now" or "Contact a doctor now". No "you're fine".
5. **Nothing depends on memory.** One main action per screen, big text and targets, no swipe-only or long-press-only actions, no time limits, undo instead of "are you sure" where it's safe. See `references/accessibility.md`.
6. **Respect the person.** Address the older person directly, by their sex (PRD F22). Simple Mode is offered at 65, never forced; the person can leave it (PRD F21).

## Which reference to open

| Feature | Read |
|---|---|
| Medicine list, doctor summary, reminders, missed doses, caregiver on the same phone | `references/medicines-and-reminders.md` |
| Blood pressure, blood sugar, falls | `references/readings.md` |
| Simple Mode, text size, contrast, taps, steps | `references/accessibility.md` |
| Reviewing a PR, or asking the doctor | `references/checklist-and-questions.md` |
| Where every figure comes from | `references/sources.md` |

## What exists today

- Simple Mode: big buttons for My medicines, Call my doctor, My family and Emergency card, text 1.3x the phone's size, 64 dp targets (`app/lib/core/design/theme.dart`).
- Medicines with reminders, Taken / Snooze, discreet mode, a doctor summary PDF, lab results flagged only from the lab's printed range.
- **Not built:** a vitals record (blood pressure, sugar, pulse) outside pregnancy, and falls logging. The Add sheet says vitals have no form yet. Build them only with this skill and the doctor's approval of the text.
