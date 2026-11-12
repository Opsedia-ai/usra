# Medicines and reminders

> Draft. Not reviewed by a doctor. A geriatrician or GP must sign off before this is relied on. Arabic drafts need the Arabic reader.

## Polypharmacy: why a list and never a check

- Older adults often take many medicines. WHO calls polypharmacy a medication-safety priority and says appropriateness, judged in a medication review, matters more than the count (WHO, Medication safety in polypharmacy, 2019).
- The tools clinicians use for that review, the AGS Beers Criteria (2023) and STOPP/START v3 (2023), are written for prescribers and need diagnoses, kidney function and clinical judgement the app doesn't have. NICE NG249 (2025) asks clinicians to consider a structured medication review after a fall.
- Usra's job is to make that review easy: a complete, current, legible list the person can show at every visit.
- **Usra never checks** interactions, duplicates, doses, Beers or STOPP items, or "same ingredient" (beyond the existing family-typed hours line, risk M2). Doing so is dose advice (Apple 1.4.2) and would bring Usra under medical device rules (`usra-clinical-safety/references/samd-boundary.md`). A wrong "no interaction found" is false reassurance.

### Wording

| Where | English | Arabic draft (needs the reader) |
|---|---|---|
| Top of the medicine list | Show this list to your doctor or pharmacist at every visit. | ورّي القايمة دي لدكتورك أو الصيدلي في كل زيارة. |
| Under it, once | Usra keeps the list. It doesn't check medicines against each other. Ask your doctor or pharmacist before starting or stopping one. | أسرة بتحفظ القايمة بس، ومش بتراجع الأدوية مع بعض. اسأل دكتورك أو الصيدلي قبل ما تبدأ أو توقف أي دوا. |
| Doctor summary PDF | Medicines as recorded by the family, with the dose text as written. Check against the original prescriptions. | (existing closing line in `docs/medical-review-changes.md`) |

Never write "safe together", "no interactions", "OK to take", or show a green tick on a medicine list.

### What the list must show

Name and strength as typed, dose text word for word, times, for whom, start date, course length or "ongoing", prescriber if known, stopped medicines in a separate section with the stop date. Include as-needed and over-the-counter medicines and supplements the family adds; offer "Add a medicine you buy without a prescription".

## Reminders for older users

| Need | Rule |
|---|---|
| Who and what | Every reminder and the widget say who it's for unless discreet mode hides names; discreet Taken shows only when no other dose is due within an hour (risk M4, `docs/security.md`) |
| Confirmation | Taken is one tap and shows "Marked as taken at 08:05 · Undo" for long enough to read. Prefer undo over a second question: fewer steps, same safety |
| Snooze | 10 minutes, labelled with the new time |
| Missed dose | Neutral and factual, never an instruction. See below |
| Repeats | A reminder that isn't answered repeats a limited number of times, then shows as missed on Home. The count is a design decision, not a medical one |
| Large text | Notification text is short enough to read at the largest system font |
| Sound and vibration | Allow the full-screen alarm option for people who don't notice notifications (PRD F7) |

### Missed-dose wording

- **Write:** "The 8:00 dose of {medicine} isn't marked as taken." / "جرعة ٨:٠٠ من {medicine} متعلّمش عليها إنها اتاخدت." and, once: "If you're not sure what to do, check the leaflet or ask your pharmacist or doctor."
- **Never write:** "Take it now", "Skip it", "Take two next time", "It's too late", or anything that depends on the medicine. Advice on a missed dose differs between medicines and is dose advice.
- Never mark a dose as taken automatically.

## A caregiver on the same phone

Usra assumes (a design assumption, not a sourced fact) that an older person is often helped by a relative on the same phone. Until v2 sync (caregiver alerts, PRD U15):

- The person a reminder is for is always visible to whoever holds the phone (subject to discreet mode).
- Taken records the time it was pressed. If the app ever records who pressed it, say so in the privacy texts.
- "Call my doctor" and "Call my caregiver" are one tap in Simple Mode (PRD F21); the number comes from the person's record.
- Don't add anything that reports on the older person to someone else without their knowledge.
