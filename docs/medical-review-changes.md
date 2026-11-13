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

## Questions for the doctor

1. Growth now says "المعدل المرجعي" when a value is in range and "برّه المدى المعتاد" when it isn't. Should these use one term?
2. Pregnancy danger signs: the drawing also listed "الضغط ١٤٠/٩٠ أو أكتر", but the app doesn't, because warning signs were not to change without review. Should it be added?
3. Pregnancy shows an ambulance button inside danger signs. The drawing and PRD (F10) also ask for "call my doctor", which isn't built. Is the ambulance button right for all the listed signs?
4. Same-ingredient line and the suggested hours between doses (`docs/risks.md`, M2): please confirm these two by name.
5. Please give your name, specialty and review date. The PRD asks for both a paediatrician and an obstetrician.

6. The Arabic doctor report now shows weights, percentiles and page numbers in Arabic-Indic digits, while lab values stay Latin to match the lab's paper. Is that acceptable for a doctor reading it?
7. Sick day (bug 15): the card now shows the highest reading, and the fever as the times of its first and last readings instead of "٤ ساعات". The warning signs for a long fever ("more than 24 hours", "more than 3 days", "5 days or more") still count from the first fever reading to the last, or to now while the latest reading is a fever, as before. Is showing the times, not a duration, right for parents?

## Changes to the rules, not the wording

- A vaccine's date can't be in the future, and a new vaccine's date can't be before birth.
- Only the 3rd, 50th and 97th growth curves are labelled. All five are still drawn.
- Done pregnancy checks fold away. Missed ones stay visible.
