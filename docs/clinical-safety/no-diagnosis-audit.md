# No-diagnosis audit

> Draft, 13 November 2026. Not reviewed by a doctor. The items under "For the doctor" wait for the clinical safety reviewer.

The founder's rule: Usra never presents a diagnosis. It may show a reference range or its source, and say "talk to the doctor". It must not say "you have X" or "this means X", and it must never give a dose. This audit checks every user-facing string against that rule (see the `usra-clinical-safety` skill, rule 1, and `references/samd-boundary.md`).

## What was checked

- All 1,371 keys in `app/lib/l10n/app_en.arb` and `app_ar.arb`. Both files have the same keys.
- Hard-coded text in `app/lib/**/*.dart`: rule data (vaccines, milestones, fever, pregnancy, growth, labs, follow-ups), the doctor summary PDF, the medicine scan, and Dr. Usra. The only Arabic in Dart files is keyword lists used for matching, and code comments. Neither is shown to the user.
- A word search of the English file for "you have", "this means", "diagnos", "underweight", "obese", "anaemia", "deficiency", "mg", "take N" and "give N". The hits are disclaimers ("not a diagnosis") or fields where the family records the doctor's diagnosis.

## Result

**No clear violations.** Nothing tells someone what condition they have, or what treatment or dose to take. Nothing was reworded. Four strings are borderline and are listed for the doctor below.

| Area | Keys and files checked | Verdict |
|---|---|---|
| Lab results, high and low | `labFlag*`, `labInfoNote`, `labScan*`, `labRangeLine`, `report*`; `lab_widgets.dart`, `doctor_summary.dart` | In the app: "Above / Below the lab's range" and "This isn't a diagnosis: ask your doctor what the results mean for you". The PDF is borderline (items 2 and 3). |
| Growth percentiles and alerts | `growth*`, `reportGrowthNote`; `growth_check.dart` | Fine. "Percentile N: outside the usual range. Talk to your pediatrician." No underweight, stunting or obesity wording. WHO source shown. |
| Development milestones | `dev*`, `milestone*` | Fine. "Talk to your pediatrician", with the CDC source. |
| Pregnancy | `pregnancy*`, `anc*`, `pregDanger*`, `bp*`; `pregnancy.dart`, `antenatal_schedule.dart` | Fine. Blood pressure says what to do ("call your doctor today", "go to the hospital now"), not what it means. `pregnancyBpSource` says "One reading isn't a diagnosis". `ancBloodCount` ("Blood count (anaemia check)") names what the test is for, not a finding. |
| Fever and sick days | `sickDay*`, `reading*`, `given*`, `nextDose*`, `warn*`; `fever.dart`, `next_dose.dart` | Fine. No medicine is named and no amount is suggested. The amount given is the family's own words. "Fever" labels a reading of 38 °C or more, not the person. `warnFooter` says "not a diagnosis". |
| Follow-up suggestions | `followUp*`, `fu*`, `condition*`; `conditions.dart`, `rules/*.dart` | `followUpsDisclaimer` says "not a diagnosis". Item 1 is borderline. |
| Medicine scan | `scanMedicine*`, `rx*`, `prescription*`; `scan_medicine_screen.dart`, `medicine_name_extractor.dart` | Fine. Reads only the name and strength, and asks the family to check them against the box. `prescriptionNoDoseAdvice`: "Usra never suggests or calculates a dose". `medicineMinHoursSuggest` offers only an interval quoted from the medicine's own instructions, and only if the family taps Use. |
| Dr. Usra | `drUsra*`, `tutorial*`; `dr_usra.dart` | Fine. Dr. Usra is an illustration and a guide to the app. There is no AI code, prompt or canned medical reply. He is never shown on emergency or warning screens. |
| Vaccines and the PDF reports | `vaccine*`, `personVaccine*`, `report*`; `egypt_vaccines.dart`, `doctor_summary.dart` | `reportSummaryDisclaimer`: "not a medical opinion". Item 4 is borderline. |
| Disclaimers | `aboutMedicalBody`, `notMedicalDevice`, `welcomeDisclaimer`, `consentPointDoctor` | Present in both languages. |

## For the doctor

These are borderline. None was changed: each needs a clinical decision, not a grammar fix.

1. **A condition said back as a fact** (`fuBecauseCondition` with `conditionDiabetes`, `conditionHypertension`, `conditionHeart`, `conditionHighCholesterol` and `conditionKidney`). AR "لأن عندها سكر" / "لأن عنده {condition}", EN "Because of {condition}". The app only repeats what the family typed in the conditions field. But the keyword match is broad (`conditions.dart`): "ضغط" counts as high blood pressure (low pressure and stress are excluded), "قلب" as heart disease, "دهون" as high cholesterol and "كلي" as kidney disease. So a conditions entry such as "خفقان في القلب" (palpitations) or "حصوة في الكلى" (a kidney stone) could become "عنده مرض في القلب" or "عنده مرض في الكلى", a condition nobody recorded. Options: narrow the keywords, or say "Because you recorded {condition}" / "علشان متسجّل {condition}".
2. **PDF lab flags** (`reportFlagHigh`, `reportFlagLow`). EN "High" / "Low", AR "عالي" / "واطي". The app says "Above / Below the lab's range"; the PDF uses the bare words. It is read by a doctor, and the lab's range is in the next column. Keep it, or use the in-app wording?
3. **PDF range column** (`reportColRange`). EN "Lab's range", AR "المعدل الطبيعي للمعمل" ("the lab's normal range"). The Arabic adds "normal", which the English and the in-app text avoid. Next to "عالي / واطي" it implies abnormal. Suggest "معدل المعمل", as in `labFlagHigh`.
4. **Catch-up vaccines "can be given now"** (`vaccineGivableNow`, `vaccineGivableNowHeading`, `vaccineGivableNowCount`). EN "Can be given now", AR "ممكن تتاخد دلوقتي". This is the schedule's minimum age and interval, but it reads as the app clearing a vaccine to be given. Compare `vaccineDoctorDecides`: "The doctor decides when they're given." Should it say "Due by the schedule; ask the doctor"?

Also worth a look, but not a diagnosis:

- `tutorialWelcomeTitle`: "Hi, I'm Dr. Usra" / "أهلاً، أنا دكتور أسرة". A mascot that calls itself a doctor may blur the "not a medical device" line for store review. It never gives advice.
- `bpHigh` / `bpVeryHigh`: thresholds of 140/90 and 160/110 with an action ("call your doctor today", "go to the hospital now"). These escalate, which the skill asks for. They are already on the doctor's list as warning text.

## How to keep it this way

- Run the word search above on every PR that adds medical text, and list the new keys in `docs/medical-review-changes.md`.
- Any new label for a result says where it sits against its reference ("above the lab's range"), never what it means.
