# Usra Variation B: merged review

Merged on 7 Nov 2026 from my review and the three reviews you pasted. Each point was checked against the screens, the PRD or the app code where possible. Medical and Arabic wording still needs a doctor and a native reader.

## P0: fix before building

### Safety
1. Don't let Home or Fever falsely reassure. Home says Youssef "كله تمام" while Fever says he's sick. Fever shows green "مفيش سخونية" at 37.6° under the arm. A doctor sets the wording.
2. Separate what the family recorded from what the app concludes. "الوزن ماشي كويس" is too definite. Use "جوه المعدل المرجعي" with the source.
3. Show source, country, schedule version and date on Vaccines, Growth, Fever and Pregnancy. Vaccines and Pregnancy show none today.
4. Add undo, Skip, Snooze, early dose and a missed-dose state. There is no undo today, so a wrong tap could lead to a missed or double dose.
5. Prevent wrong-person records. Add sheet with Laila selected opens "دوا جديد لجدو". Show the person in every form with a way to change it, name them on Save and in the confirmation, and allow moving a record later.
6. A scan never creates a reminder until the person confirms name and strength. Highlight unsure values.
7. Remove dose hints unless the family entered them, and get the same-ingredient line reviewed. No dose checker, duplicate-ingredient checker or maximum-dose field in v1.

### Trust and data
8. A forgotten PIN with no backup loses everything (confirmed in app code). Protect ticks the lock by default and never creates a PIN. Use the phone's own lock as fallback, or require a recovery key first.
9. Welcome needs "عندي نسخة احتياطية" for restore. In the beta, sign-in stays hidden until the lawyer answers.
10. Fix promises that aren't true: photo reading (v1 reads printed Latin only), "بنفس الحساب" (suggests sync), "free for life" opening a screen saying spots are gone.
11. Add a plain privacy page to the canvas (it exists in the app): what is encrypted, can we see it, what backup includes, what happens if the PIN is forgotten, what delete does to backups.
12. Warn before sending an insurance card by WhatsApp and preview the watermark.
13. Emergency "lock screen" means Usra's own lock screen in code, so a responder can't reach it on a locked phone. Rename it, confirm before turning it on, and guide people to the phone's Medical ID or a widget.

### Works on real phones
14. Home breaks at 130% and 200% text and at 360 px wide. Use a scrolling layout with no fixed positions, safe areas and keyboard handling. Test at 320, 375, 390 and 430 px.
15. Show member numbers left to right. Today "١٢٣٤ ٥٦٧٨" appears with its groups swapped.
16. Label main navigation. Medicines, Records and Emergency are icons only, with a hamburger for the rest.
17. Fix contrast: "كله تمام" 3.48:1 and 4.24:1 at 13 px, and "١ من ٢" on Pregnancy 4.24:1. Use `#14532D` or ink.
18. Doses and warnings at 16 px or more. 25% of text styles are under 14 px; dose lines and pregnancy danger signs are 13 px; growth axis is 11 px.
19. Tap targets at 48 px: "غيّري" 25×19, legal links 18 tall, paywall links 37, Fever links 29 and 40, "فكّريني" 41, doctor call buttons 40 to 44 wide.

## P1: before beta

### Flow
20. Shorten onboarding: language and country, about you, then Home. Family, vaccines, reminders, backup and emergency card become optional cards on Home. Ask for each permission when it's needed.
21. Person is the hub: medicines, vaccines, visits, growth, documents, insurance, allergies, follow-ups, doctor summary. Show the name once.
22. Split More into clear groups, with chevrons on links. Add account and delete account. Move backup status to Home.
23. Link Pregnancy from "أنا". Make Add its main button, put the red call inside danger signs, and change "ورم" to "تورّم". Let each supplement be ticked.
24. Simple Mode: protected exit, several doses, no doses left, confirmation, box photo. Decide how one phone or two phones work, since there's no sync.
25. Add one-tap Taken on Home, and remove the repeated dose. "دوا السكر" and "حباية بيضا" can't be built because the form doesn't collect them.
26. Different urgency levels on Home. Add sick-day status, follow-ups and the last-backup line (F3).
27. Records: add an Add button, "الكل", expandable rows, thumbnails, correct and delete. Medicines: filter by person.
28. Vaccines: log an overdue dose from its card. Show the schedule name. Ask your paediatrician about the government/private toggle and the word "إجباري".
29. Add Sheet: add surgery, admission, vitals, allergy and condition, and move the scan to the top of the vaccine form.
30. Emergency: one-tap family call, critical information first, neutral wording, Latin medicine names and an English view. Remove the QR code from v1.
31. Fever: one calm screen, a real ambulance button, a doctor button, one time direction, a labelled 38° line, symptoms. Define how fever duration is counted.
32. Paywall: state trial end date, what happens afterwards, that records stay, and what Lifetime includes. Remove the plan choice from starting a trial. Read prices from the store. Avoid urgency language.
33. Insurance: put copy and share on the active card, and add cards to Person.

### Forms and wording
34. Fix `text-align: left` in About you, Add person and Add medicine.
35. Give dose times their own row, use a proper date picker, validate dates, and make "تخطي" say what it skips.
36. Neutral wording before the sex question. Add "مراتي" beside "جوزي". Use one verb for doses ("اتاخد").
37. Replace Doctors placeholders with an empty state, and keep red for emergencies only.
38. "صباح الخير" appears at 1:45 PM. Fix "كارت/كروت الطوارئ" and mixed digits.

### Missing screens
39. Backup and recovery key, restore, PIN and lock screen, privacy page, family list, adult Person, labs and trends, multi-medicine prescription, visit and scan forms, scan review, insurance and doctor forms, follow-ups, notifications, widget, doctor summary, male-user wording.
40. Empty, error, loading and success states, and a state sheet for every control.
41. Dark mode for all screens, and English beyond the 2 checks.

## P2: polish

42. Pebbles for people only (plus Dr. Usra's backdrop). Cards at one 24 px radius, instead of 48 uneven ones.
43. Reduce to the design tokens: 7 text sizes (now 20), 4 corner values (now 41), 2 shadows (now 16).
44. One colour, one meaning. Keep most cards white and show status with chips, fewer pastels per screen.
45. Numbers in IBM Plex and Baloo for titles, as the Product Definition says.
46. Spending: bars instead of bubbles, with currency.
47. Growth: remove repeated values, add measurement history, larger axis, optional percentiles under "التفاصيل".
48. Vaccines: replace the 18 dots with a bar, or group them by age.
49. Welcome: one aura behind Dr. Usra, and one language choice.

## Rejected

| Suggestion | Why |
|---|---|
| Replace Home pebbles with a bento grid | Removes the one memorable thing. Use a flowing two-column layout |
| Five tabs with "أفراد العيلة" | Home already shows the family |
| Slide to confirm the ambulance call | Hard for shaky hands. From memory the phone already confirms; test this |
| Dr. Usra on Fever, disclaimers or Growth | The Product Definition bars him from warning screens, and celebrating a health status can mislead |
| Dose check, duplicate check, maximum dose | PRD and Apple 1.4.2, and drug-list licences are still open |
| "أفضل عدم الإجابة" for sex in v1 | Needed for WHO tables and Arabic grammar |
| Audit history, last-updated everywhere | Too much for a phone-only family app |
| Dashed border and grey subtitle fail contrast | Measured 3.34:1 and 5.56:1, both pass |
| `/_blob` paths broken, `100dvh` and `<span>` fixes | Canvas and web details. The app is Flutter |
| UAE and Gulf countries, iCloud backup | Against the PRD and Apple 5.1.3 |
| Coloured left-border cards | Template look, awkward in RTL |
| Add sheet tiles too small | 68×62 px, only labels need to grow |
| Pinch-to-zoom on charts | Tap a point instead |
| Redaction tools for cards | Warning and watermark first |
| Modern Standard Arabic mode | Plan neutral Arabic when Saudi Arabia and Jordan launch |

## Decisions needed

1. Home: pebbles in a flowing layout (recommended) or bento grid.
2. Person colours: by sex (Product Definition) or neutral per person (recommended).
3. Dr. Usra card items: recommended 1, 2, 4, 5.
4. Shorter onboarding and three labelled buttons instead of five tabs (both recommended). These change the PRD.
5. An Android phone to test Drive backup.
