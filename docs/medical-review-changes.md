# Medical wording changed after the doctor's review

The founder reports that the doctor accepted the app's full wording on 7 November 2026. This list is the medical text added or changed afterwards, for the doctor to check. It covers PRs 51 to 61.

## Changed wording

| Where | Before | Now |
|---|---|---|
| Growth, value in range | المئين {percentile}: في المدى المعتاد للسن ده. | جوه المعدل المرجعي للسن ده (المئين {percentile}). |
| Growth, English | Percentile {percentile}: within the usual range for this age. | Within the reference range for this age (percentile {percentile}). |
| Pregnancy, danger sign | ورم في الوش أو الإيدين | تورّم في الوش أو الإيدين |
| Doctor summary, closing line | ملخص عملته العيلة بتطبيق أسرة من سجلاتها. للمعلومات بس: راجعوه على الروشتات والتقارير الأصلية. | ده ملخص من اللي العيلة سجلته بتطبيق أسرة، مش رأي طبي. راجعوه على الروشتات والتقارير الأصلية. |
| Doctor summary, English | A summary made by the family in the Usra app from their own records. Informational only: check against the original prescriptions and reports. | This summary is what the family recorded with the Usra app, not a medical opinion. Check it against the original prescriptions and reports. |

| Pregnancy, week count in English | Showed the Arabic text by mistake | {weeks} weeks, {days} days (under a week: Less than a week, {days} days) |
| Pregnancy, week count in Arabic | =0{0 يوم} | =0{٠ يوم} (digit only) |
| Egypt hexavalent vaccine hint | عند شهرين و4 و6 شهور | عند شهرين و٤ و٦ شهور (digit only) |
| Pregnancy, weight line | kg | كجم |
| Sick day, under the chart (bug 15) | سخونية متسجلة: ٤ ساعات (the time from the first fever reading to the last, or to now while the latest is a fever) | سخونية متسجلة من ٨:٠٠ ص لـ ١٢:٠٠ م (first and last fever readings, as times; one reading: سخونية متسجلة: ٨:٠٠ ص) |
| Sick day, English (bug 15) | Fever logged: 4 hours | Fever readings from 8:00 AM to 12:00 PM |

## New wording

| Screen | Text |
|---|---|
| Vaccines | {done} من {total} جرعة اتاخدت |
| Vaccines | اتاخدت كلها · آخرها {date} |
| Vaccines | {dose} · متأخر |
| Growth | المعدل المرجعي |
| Growth | آخر قياس {date} |
| Growth | برّه المدى المعتاد |
| Pregnancy | سجّلي زيارة أو تحليل |
| Pregnancy | الأدوية والمكمّلات النهارده |
| Pregnancy | مفيش حاجة متسجلة للنهارده. |
| Pregnancy | ضيفي دوا أو مكمّل |
| Doctor summary | ده ملخص من اللي العيلة سجلته، مش رأي طبي. |
| Simple Mode | الدوا الجاي |
| Simple Mode | وبعده: {medicine} الساعة {time} |
| Simple Mode | وبعده: {medicine} لـ{name} الساعة {time} |
| Simple Mode | مفيش جرعات فاضلة النهارده. |
| Sick day (bug 15) | أعلى قراءة: ٣٩٫١° · ١٢:٠٠ م (the highest reading of the sick day, shown when there are two or more) |
| Sick day, English (bug 15) | Highest reading: 39.1° · 12:00 PM |
| Consent (first run) | أسرة مش بتشخّص ولا بتعالج. الرأي دايماً للدكتور. (Usra doesn't diagnose or treat. Always check with a doctor.) |

## Danger signs, symptoms and milestones by sex (item I)

Grammar only: the feminine and neutral forms must say exactly what the boy's form says. Please check each one, with the Arabic reader. The full table, with every string for a girl, a boy and a person whose sex isn't recorded, is in `docs/arabic-review.md` under "Text that follows the person's sex (item I)". That's 13 danger signs, 3 symptoms and 48 milestones.

## Mark everything due so far as given (founder's decision, 13 Nov 2026)

What the button does now: one tap, after a confirmation, records every vaccine dose due by the child's age today as given, each on the day the schedule would have given it (never after today). It covers the required doses and every optional vaccine in the app's list (pneumococcal, rotavirus, chickenpox, hepatitis A, meningococcal, flu), whether or not the family chose it before. The optional ones are ticked by default, under one tick the parent can clear. The optional vaccines marked are added to the child's plan. Undo removes the records and puts the plan back.

The doses are worked out as if each came on time: from birth forward, a dose counts once its day has come, by the existing rules on that day. So rotavirus counts for a 2-year-old (dose 1 at 2 months and dose 2 at 4 months are within its upper age), and so do all four PCV doses. A dose whose day is after today never counts.

| Where | Before | Now |
|---|---|---|
| Dialog, count | {count} جرعة إجبارية لحد سن ١٨ شهر هيتعلّم عليها إنها اتاخدت، كل واحدة في ميعادها على الجدول، مش النهارده. راجع كارت التطعيم الأول: الكارت ودكتور الطفل هما المرجع. تقدر ترجع فيها، أو تشيل العلامة من أي جرعة بعدين. | عندها سنتين دلوقتي. {count} جرعة إجبارية لحد السن ده هيتعلّم عليها إنها اتاخدت، كل واحدة في ميعادها على الجدول، مش النهارده. (the card sentence unchanged, now its own line) |
| Dialog, optional | ومعاها الاختياري اللي ماشيين عليه ({count}) — unticked, only vaccines already chosen | ومعاها الاختيارية اللي ميعادها جه لحد السن ده، كل واحدة في ميعادها: {names} ({count} جرعة) — ticked, every optional vaccine |
| Dialog, optional (new) | — | الاختيارية هي التطعيمات الخاصة اللي بفلوس. شيل العلامة لو ماخدتهاش. |
| English | {count} required doses up to 18 months will be marked as given… | She is 2 years now. {count} required doses due up to this age will be marked as given, each on its date on the schedule, not today. Also the optional ones due by this age, each on its date: {names} ({count} doses). The optional ones are the private, paid vaccines. Untick if she didn't have them. |

### For the doctor

1. Pre-ticking the optional (paid) vaccines may record doses a child never had, if the parent doesn't untick them. The reminders for those doses then stop, and the doctor summary and the vaccination record list them as given. This is the founder's decision for simplicity; the dialog says to check the card first and to untick if she didn't have them, and it can be undone. Is that acceptable, or should optional vaccines start unticked? (Hazard HZ-M12.)
2. Rotavirus for a child now past its upper age (from about 6 months) is recorded as given at 2 and 4 months when the optional ones stay ticked. Is that right, given that a missed rotavirus dose can't be caught up anyway?
3. The button now shows whenever even one dose due so far is unrecorded, required or optional. A family that skipped the paid vaccines will keep seeing it. Is that acceptable?

## Questions for the doctor

1. Growth now says "المعدل المرجعي" when a value is in range and "برّه المدى المعتاد" when it isn't. Should these use one term?
2. Pregnancy danger signs: the drawing also listed "الضغط ١٤٠/٩٠ أو أكتر", but the app doesn't, because warning signs were not to change without review. Should it be added?
3. Pregnancy shows an ambulance button inside danger signs. The drawing and PRD (F10) also ask for "call my doctor", which isn't built. Is the ambulance button right for all the listed signs?
4. Same-ingredient line and the suggested hours between doses (`docs/risks.md`, M2): please confirm these two by name.
5. Please give your name, specialty and review date. The PRD asks for both a paediatrician and an obstetrician.

6. The Arabic doctor report now shows weights, percentiles and page numbers in Arabic-Indic digits, while lab values stay Latin to match the lab's paper. Is that acceptable for a doctor reading it?
7. Sick day (bug 15): the card now shows the highest reading, and the fever as the times of its first and last readings instead of "٤ ساعات". The warning signs for a long fever ("more than 24 hours", "more than 3 days", "5 days or more") still count from the first fever reading to the last, or to now while the latest reading is a fever, as before. Is showing the times, not a duration, right for parents?
8. Item I: is the neutral wording for a person whose sex isn't recorded right? For example "السن أقل من ٣ شهور والحرارة ٣٨ °م", "نعاس شديد أو صعوبة في الصحيان، أو مفيش رد زي العادة", and "مفيش شرب أو مفيش رضاعة، أو مش زي العادة خالص" for "مش بيشرب أو مش بيرضع". Milestones keep the boy's wording in that case.

## Changes to the rules, not the wording

- A vaccine's date can't be in the future, and a new vaccine's date can't be before birth.
- Only the 3rd, 50th and 97th growth curves are labelled. All five are still drawn.
- Done pregnancy checks fold away. Missed ones stay visible.

## Follow-up sources by age (end-to-end test #6, 13 Nov 2026)

The yearly dental check-up applies from the first birthday to everyone. Its source line read "AAPD 2024 (children); WHO oral health" for adults too, so an adult was shown a children's guideline. Now, for the same rule and the same 12-month interval:

- Under 18: "AAPD 2024 (children); WHO oral health" (unchanged).
- 18 and over: "NICE CG19 (dental recall, adults); WHO oral health". NICE CG19 sets adult recall intervals between 3 and 24 months by the dentist's judgement, and yearly sits inside that. Source status: partly verified (from the guideline's published recommendation, not re-read for this change).

No interval, age or wording changed.

Questions for the doctor:

1. Is NICE CG19 the right adult source for a yearly dental check-up, or would you rather cite something else, such as an Egyptian or WHO source?
2. Other rules checked for the same age mistake. Nothing was changed; please confirm:
   - Diabetic eye exam (`screening.eyeExam`) applies from birth to anyone with diabetes and cites ADA Standards of Care 2025 §12, the adult section. ADA §14 (children and adolescents) starts the first eye exam at age 11 or puberty, after 3 to 5 years of diabetes. Should a child with diabetes see this follow-up, and with which source?
   - HbA1c, lipid profile and kidney check (`chronic.*`) have no age limits and cite adult ADA sections, KDIGO and WHO HEARTS. Do they apply to children with these conditions as written?
   - Blood pressure (from 18, USPSTF adults), diabetes screening (35–70), breast (women 40–74) and colorectal (45–75) screening are adult-only and cite adult sources. These look right.

## Milestone wording that addressed the reader as a man (end-to-end test #11, 13 Nov 2026)

- 18 months, thinking: "بيقلدك وانت بتعمل شغل البيت، زي الكنس" (girl: "بتقلدك…") is now "بيقلد شغل البيت اللي بتعملوه، زي الكنس" (girl: "بتقلد…"). The meaning is the same as CDC's "Copies you doing chores, like sweeping": "you" is now plural, so it fits a mother or a father. The English is unchanged.
- The milestones intro now follows the reader's sex and the child's ("علّمي على اللي بنتك بتعمله…"). It's not medical text, but it's on the same screen.

Questions for the doctor:
1. Is "بيقلد شغل البيت اللي بتعملوه" faithful to the CDC milestone?
2. Two more milestones address the parent as a man: 2 months "بيتابعك بعينه وانت بتتحرك" and 4 months "بيثبّت راسه لوحده وانت شايله". Should they be reworded the same way, or follow the reader's sex?
