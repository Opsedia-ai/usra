# Medical wording changed after the doctor's review

The founder reports that the doctor accepted the app's full wording on 7 November 2026. This list is the medical text added or changed afterwards, for the doctor to check. It covers PRs 51 to 57.

## Changed wording

| Where | Before | Now |
|---|---|---|
| Growth, value in range | المئين {percentile}: في المدى المعتاد للسن ده. | جوه المعدل المرجعي للسن ده (المئين {percentile}). |
| Growth, English | Percentile {percentile}: within the usual range for this age. | Within the reference range for this age (percentile {percentile}). |
| Pregnancy, danger sign | ورم في الوش أو الإيدين | تورّم في الوش أو الإيدين |
| Doctor summary, closing line | ملخص عملته العيلة بتطبيق أسرة من سجلاتها. للمعلومات بس: راجعوه على الروشتات والتقارير الأصلية. | ده ملخص من اللي العيلة سجلته بتطبيق أسرة، مش رأي طبي. راجعوه على الروشتات والتقارير الأصلية. |
| Doctor summary, English | A summary made by the family in the Usra app from their own records. Informational only: check against the original prescriptions and reports. | This summary is what the family recorded with the Usra app, not a medical opinion. Check it against the original prescriptions and reports. |

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

## Questions for the doctor

1. Growth now says "المعدل المرجعي" when a value is in range and "برّه المدى المعتاد" when it isn't. Should these use one term?
2. Pregnancy danger signs: the drawing also listed "الضغط ١٤٠/٩٠ أو أكتر", but the app doesn't, because warning signs were not to change without review. Should it be added?
3. Pregnancy shows an ambulance button inside danger signs. The drawing and PRD (F10) also ask for "call my doctor", which isn't built. Is the ambulance button right for all the listed signs?
4. Same-ingredient line and the suggested hours between doses (`docs/risks.md`, M2): please confirm these two by name.
5. Please give your name, specialty and review date. The PRD asks for both a paediatrician and an obstetrician.

## Changes to the rules, not the wording

- A vaccine's date can't be in the future, and a new vaccine's date can't be before birth.
- Only the 3rd, 50th and 97th growth curves are labelled. All five are still drawn.
- Done pregnancy checks fold away. Missed ones stay visible.
