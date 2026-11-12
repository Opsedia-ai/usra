# Test report: a 2-year-old girl, 12 November 2026

The founder installed the app on her iPhone and added her daughter Gamila, born 12 Nov 2024, who is 2 today. This report covers:

- what she found
- what was reproduced and fixed
- a full walk through the app for the same child with a fixed clock
- scores out of 5 for ease of use, speed, correctness, safety wording and accessibility

Each score has two columns. **Before** is the app as the founder tested it. **After** assumes the open fix PRs are merged.

Nothing here was measured on a real phone. The founder's phone and simulator walkthroughs are the only device evidence.

## How it was tested

- **Fixed clock.** 12 Nov 2026 at 10:00. Every expected value was worked out by hand or from a published source, never by calling the app's own calculation.
- **Tests:**
  - `app/test/widget/vaccines_two_year_old_test.dart` covers the vaccine bugs A to D and F.
  - `app/test/widget/two_year_old_full_test.dart`, `two_year_old_more_test.dart` and `app/test/core/two_year_old_backup_test.dart` are the full walk.
  - Smaller tests were added with each fix PR.
- **Known bugs.** A test that meets a known bug asserts today's behaviour and is marked `// BUG:`, so the suite stays green. Each fix PR updates its own.
- **Not driven.** Date pickers in the walk are closed with the chosen date rather than tapped through.

## PRs

| PR | What | State |
|---|---|---|
| [#66](https://github.com/Opsedia-ai/usra/pull/66) | A: undated past doses dated on the schedule; catch-up doses shown as such | Merged |
| [#68](https://github.com/Opsedia-ai/usra/pull/68) | B: optional vaccines always shown, with dates and state | Merged |
| [#69](https://github.com/Opsedia-ai/usra/pull/69) | C: the given/not-given switch, and the wording audit fixes | Merged |
| [#70](https://github.com/Opsedia-ai/usra/pull/70) | CI: don't fail analyze on Flutter 3.50's material.dart deprecation | Merged |
| [#67](https://github.com/Opsedia-ai/usra/pull/67) | CI: pin Flutter 3.47.9 | Closed, replaced by #70 |
| [#73](https://github.com/Opsedia-ai/usra/pull/73) | E: dates typed in Arabic are read, never dropped | Merged |
| [#71](https://github.com/Opsedia-ai/usra/pull/71) | D: mark everything due so far as given | Merged |
| [#74](https://github.com/Opsedia-ai/usra/pull/74) | F: everything missing shown apart from what can be given now | Merged |
| [#76](https://github.com/Opsedia-ai/usra/pull/76) | G: growth chart labels on their own curve | Merged |
| [#77](https://github.com/Opsedia-ai/usra/pull/77) | J and K: relationship sets the sex; birth-date picker opens near the right year | Merged |
| [#80](https://github.com/Opsedia-ai/usra/pull/80) | Fix of #77: tapping أنثى after "بنتي" kept clearing the sex | Merged |
| [#78](https://github.com/Opsedia-ai/usra/pull/78) | H: ask before saving an impossible growth value; readable axis | Open, see the final report |
| This PR | The full-app tests and this report | Open |

## Scores

1 is unusable and 5 is right with nothing to fix.

### Ease of use

| Area | Before | After | Evidence |
|---|---|---|---|
| Taps to common tasks | 3 | 4 | See "Taps to common tasks" below for the counts. A 2-year-old's birth date took 21 taps in the calendar before K; with K it opens on today. Typing a date didn't work in Arabic before E. |
| Clarity of Arabic | 2 | 3 | Before: the switch said "اتاخدت" when off (C); doses were masculine (اتاخد, متأخر, معاده); "التنبيهات مقفولة" showed while reminders were on; there were masculine imperatives (اختار تاريخ, اسأل الدكتور). Fixed in #69, #73 and #74. Still open: danger signs and milestones are masculine for a girl (I), and the general disclaimers still use the imperative. |
| Errors that block | 1 | 4 | Before: a typed birth date was silently dropped (E); for an older child the vaccine checklist never offered the 4, 6, 9 and 18-month doses (A); a past dose logged from its card was dated today, which corrupted the schedule (A). All three are fixed. Still open: a medicine started mid-day shows that morning's dose as missed (bug 12). |
| Findability | 4 | 4 | Every task in the walk was reachable from Home or her page in one or two taps. "Mark everything due so far" is on the Vaccines page and in the setup (D). |
| Consistency with the accepted design | 3 | 3 | Provisional: not compared visually with the E- screens; this rests on widget tests only. The new controls reuse the existing cards, chips, outlined buttons and snack bars. |

### Response time

| Area | Score | Evidence |
|---|---|---|
| Main screens' first frame and data | 4 (test environment only) | Widget tests with software rendering and an in-memory database: cold start to Home 301 ms; her page 73 ms; Vaccines 78 ms; Growth 81 ms; Medicines Today 45 ms; Records 78 ms; Sick day 206 ms. |

**Real-device timing was not measured.** To check it on her iPhone:

1. Run `flutter run --profile` from `app/` with the phone connected.
2. Open each screen in turn.
3. Read the frame times in DevTools (Performance), or turn on the performance overlay with `P` in the terminal.

Frames over 16 ms show as red bars. The first open after install is the slowest and worth timing with a stopwatch: tap Home to her page, and her page to Vaccines.

### Correctness

| Area | Before | After | Evidence |
|---|---|---|---|
| Calculations | 2 | 4 | Vaccine dates and the next visit were wrong for an older child (A, F). Every other calculation matched the hand values; see "Calculations checked". Still open: the mid-day medicine start (bug 12), and the sick day doesn't show the highest reading (bug 15). |
| Safety wording | 3 | 4 | Due dates now say "catch-up" or "overdue", never "at 4 months" for a 2-year-old. Optional vaccines say "اختياري". Growth uses reference wording ("جوه المعدل المرجعي") with its WHO source. Still open: masculine danger signs for a girl (I), and the fever-duration label (bug 15). |
| Accessibility | 3 | 3 | Text at 2×, 320 px wide: no overflow, nothing under 14 px. Contrast passes on 7 screens. Android tap targets pass. `labeledTapTargetGuideline` fails on all 7, from the full-screen `DismissKeyboard` gesture detector and some 48×48 round icon buttons whose label sits outside the tap node (bug 16). |

## Calculations checked

| What | Expected (how) | App | Result |
|---|---|---|---|
| Age on her page | 12 Nov 2024 to 12 Nov 2026 = 24 months, 0 days | سنتين · بنتك | Pass |
| Age the day before | 23 completed months | ٢٣ شهر | Pass |
| Vaccine due dates, required | MoHP ages from the birth date: 2 months = 12 Jan 2025 … 18 months = 12 May 2026 | All 18 match after #66 | Pass |
| OPV 2 catch-up | 28 days after OPV 1 given today = 10 Dec 2026 | ١٠ ديسمبر ٢٠٢٦, "جرعات تعويضية" | Pass after #66 (before: "عند ٤ شهور") |
| Overdue / missing | 7 can be given today; 18 missing | ٧ جرعات متأخرة → after #74: ١٨ جرعة ناقصة · ممكن تتاخد دلوقتي: ٧ | Pass after #74 |
| Weight 12.0 kg | WHO girls LMS interpolated at 23.98 months (−0.2940, 11.4741, 0.12390): z = +0.36, 64th | ٦٤ | Pass |
| Length 86.0 cm | WHO girls length-for-age (1, 86.4006, 0.03734): z = −0.12, 45th | ٤٥ | Pass |
| Head 47.0 cm | WHO girls (1, 47.1798, 0.02957): z = −0.13, 45th | ٤٥ | Pass |
| Fever span | Fever readings 08:00 (38.5) and 12:00 (39.1); 18:00 is 37.8 | ٤ ساعات | Pass (see bug 15 on the label) |
| Doses of a 5-day, twice-daily course | 5 × 2 = 10; day 1 of 5 on 12 Nov; ends after 16 Nov | 10, اليوم ١ من ٥, خلص on 17 Nov | Pass |
| Missed dose | 20:00 dose; missed strictly after 1 h | 21:00 not missed, 21:01 missed | Pass |
| Spending | 300 + 85 = 385 in November | ٣٨٥ | Pass |
| Insurance expiry | Yesterday expired; today to +30 days expires soon; +31 days valid | as expected | Pass |
| Pregnancy, LMP 1 Jun 2026 | 164 days = 23 weeks 3 days | ٢٣ أسبوع و٣ أيام | Pass |
| Pregnancy for her | not offered to a 2-year-old | not offered | Pass |
| Backup and restore | every row of every table identical | identical | Pass |

The WHO values come from WHO's own tables, as packaged in pygrowup, and match the app's tables for girls at 23 and 24 months.

## Taps to common tasks

| Task | Taps |
|---|---|
| First run to Home | 7 |
| Add a person, skipping vaccines | 8 (21 before K, picking a 2-year-old's date in the calendar) |
| Log a vaccine dose from her page | 4 |
| Add a growth measurement (3 values) | 5 |
| Start a sick day and add a temperature | 5 |
| Add a twice-daily medicine with a last day | 7 |
| Mark a dose taken | 1 |
| Record a visit with a cost | 4 |
| Add an insurance card | 5 |

Tapping into each text field counts as a tap; typing doesn't.

## Bugs

Severity:

- **Critical:** wrong medical information or data loss.
- **High:** blocks a common task or misleads.
- **Medium** and **Low** as usual.

| # | Bug | Severity | State |
|---|---|---|---|
| A | For a 2-year-old, doses logged from the overdue cards were saved as given today. Dose 2 of each then fell due in 28 days, under "عند ٤ شهور", with MMR 2 among them. The checklist never offered the 4, 6, 9 and 18-month doses. | Critical | Fixed, #66 |
| B | Optional vaccines showed "مش في خطتك" with no dates or state | High | Fixed, #68 |
| C | The dose sheet's switch said "اتاخدت" when off | High | Fixed, #69 |
| D | No quick way to mark an older child's past doses | Feature | Built, #71 |
| E | A date typed in Arabic was silently dropped, in About you and every date field | High | Fixed, #73 |
| F | Only 7 of 18 missing doses were shown | High | Fixed, #74 |
| G | Growth chart labels sat one curve off ("٥٠" by the 85th) | High | Fixed, #76 |
| H | Impossible growth values (896 cm) saved without question; the axis became unreadable | Medium | Fixed, #78 |
| I | Text about a family member is masculine for a girl: danger signs ("نفسه", "عينه", "عادته", "سنه … وحرارته"), symptoms, and all CDC milestones ("بيضحك…") | Medium | Not fixed, see below |
| J | "بنتي" didn't select أنثى | Low | Fixed, #77. Its regression (tapping أنثى again cleared the sex) is fixed in #80 |
| K | The birth-date picker opened at January 1990 | Medium | Fixed, #77 |
| 12 | A medicine added at 10:00 with an 08:00 time shows that morning's dose as missed ("فاتت") | High | Not fixed. Proposal: skip times before the medicine was created on its first day, in `plannedDoses` (`lib/features/medicines/dose_schedule.dart`) and `isDoseMissed`. |
| 13 | Several screens read the phone clock (`DateTime.now()`) instead of `clockProvider`: insurance expiry, spending period, the vaccine date picker, growth age, the record form's default date, the profile picker's last date, and the dose log time. Around midnight they can disagree with the rest of the app, and they can't be tested on a fixed date. | Medium | Not fixed. Proposal: read `clockProvider` everywhere. |
| 14 | Growth asks for height without asking whether she was measured lying or standing. At exactly 24 months the app uses the length table (correct by WHO's age-in-days rule), but a child measured standing reads 45th instead of 54th. | Low | Not fixed. Proposal: ask how she was measured, or note it under the result. |
| 15 | The sick day doesn't show the highest reading (39.1 is only in the closed list). "سخونية متسجلة: ٤ ساعات" is the span between fever readings, not how long the fever lasted. | Medium | Not fixed. Proposal: a "أعلى قراءة" line, and "من ٨:٠٠ لـ ١٢:٠٠". |
| 16 | Screen readers: `labeledTapTargetGuideline` fails on 7 screens. The full-screen `DismissKeyboard` `GestureDetector` is an unlabeled tap node, and `UsraRoundIconButton` labels sit outside the tap node. | Medium | Not fixed. Proposal: `excludeFromSemantics: true` on the detector; merge the button's semantics. |
| 17 | No cost field for a pharmacy or medicine purchase | Low (feature) | Not fixed |
| 18 | At exactly 5, the Vaccines page is hidden ("for under-fives"), so "mark everything" isn't there for a 5-year-old, the founder's example | Question | Founder decision |
| 19 | CI: Flutter 3.50 (stable from 12 Nov) deprecates `material.dart`, and `flutter analyze` failed every PR | High (CI) | Worked around for `analyze` in #70. Main's release builds still fail on Flutter 3.50: the Android release bundle needs Android Gradle Plugin 9.1.1 (the app has 9.1.0). Proposal: pin Flutter in CI as in the closed #67, or bump the Android Gradle Plugin. Moving to `material_ui` is still to do. |
| 20 | CI: the iOS build fails its Podfile.lock check because CocoaPods now computes different checksums for AppAuth 3.0.0, GoogleSignIn 10.1.0 and GTMAppAuth 6.0.0. The versions are the same. | High (CI) | Not fixed. A person should check why the podspecs changed before the lock file is updated. |
| 21 | In this repo a failing widget test can hang `flutter test` instead of failing at `--timeout` | Low (tooling) | Not fixed. It showed up several times in this work; run with `-r expanded` into a log to see the failure. |

### I: how big the job is

Member-directed medical text is fixed in the masculine in three ICU strings:

- `warnSign`: 20 danger signs, about 12 of them gendered
- `symptomName`: 4 gendered of 17
- `milestone`: 40 CDC milestones, all masculine ("بيضحك", "بيقول", "بيرفع راسه")

`sickDayPersonUnwell` and `statusSickFemale` already take the person's sex, so the pattern exists. The fix is mechanical: add a `sex` select to the three strings and pass `person.sex` at their three call sites. That's about 56 feminine phrases to write. Every one is medical text, so each needs the doctor's review before shipping. I didn't change it, because these are medical strings and the founder asked for it to be fixed only if it's mechanical and safe. It's mechanical, but not safe without that review. Estimated at half a day plus the review.

## Wording changed in this cycle (for the Arabic reader and the doctor)

| Key | Old | New | PR |
|---|---|---|---|
| `vaccineCatchUp` | (new) | جرعة تعويضية · ميعادها {date} | #66 |
| `vaccineNextCatchUp` | (new) | جرعات تعويضية (فات سنّها) | #66 |
| `vaccineCatchUpShort` | (new) | تعويضية | #66 |
| `vaccineDateAssumed` | (new) | ده ميعادها على الجدول. غيّره لو اتاخدت في يوم تاني. | #66 |
| `vaccineOptionalWasDue` | (new) | اختياري · كان ميعادها {date} | #68 |
| `vaccineNotFollowed` | مش في خطتك | (removed) | #68 |
| `vaccineDoseNotGiven` | (new) | ماتاخدتش | #69 |
| `prescriptionStopped` | (new) | متوقفة | #69 |
| `sickDayOngoing`, `sickDayReopen` | لسه تعبان | لسه تعبانة / لسه تعبان, by sex | #69 |
| `reminderExactOffTitle` | (new; showed "التنبيهات مقفولة") | التنبيهات ممكن تتأخر | #69 |
| `vaccineDone` | اتاخد {date} | اتاخدت {date} | #69 |
| `vaccineOverdue` | متأخر من {date} | متأخرة من {date} | #69 |
| `vaccineDue` | معاده {date} | ميعادها {date} | #69 |
| `vaccineChoiceOverdue` | {dose} · متأخر | {dose} · متأخرة | #69 |
| `fieldFilmed` | اتصورت فيديو | اتصورت فيديو؟ | #69 |
| `pickDate` | اختار تاريخ | اختيار التاريخ | #73 |
| `vaccineMarkPast…` (7 keys) | (new) | See #71 | #71 |
| `vaccineMissingCount`, `vaccineGivableNow` | (new) | {n} جرعة ناقصة · ممكن تتاخد دلوقتي: {n} | #74 |
| `personVaccineWasDue` | … اسأل الدكتور إمتى تتاخد. | … الدكتور يحدد إمتى تتاخد. | #74 |
| `vaccineTooLate` | فات السن المسموح: اسأل الدكتور | فات السن المسموح: الرأي للدكتور | #74 |
| `reportTooLate`, `reportTooLateLabel` | اسأل الدكتور | الرأي للدكتور | #74 |
| `growthImplausible…` (4 keys) | (new) | متأكد/ة من الرقم؟ … | #78 |

The audit's debatable items were listed in #69 and not changed:

- `profileSimpleMode`: masculine on a switch
- `lockEmergencyFor`: reads as a statement
- `followUpDue` / `followUpOverdue` "معاده" and `ancDone` "اتعمل": masculine for mixed items
- `rxTimesChecked`: a tooltip that announces a fact before it's true
- `settingsBlockScreenshotsHint`: states the "on" behaviour while off
- the Today screen: "فاتت" next to "اتاخد"
- the general disclaimers "اسأل دكتورك…": imperative

## Questions for the doctor

1. Should the hepatitis B birth dose and OPV 0 still show as overdue for a 2-year-old, or do they lapse after the newborn period while the series continues?
2. BCG for a 2-year-old who never had it: still due, or "ask the doctor"?
3. Is catch-up spacing, with the next dose 28 days after the previous one counted from today, what families should see?
4. Is "جرعة تعويضية" the right word for a dose the child is past the age of?
5. For an optional vaccine the family doesn't follow, past its upper age (rotavirus): is "فات السن المسموح: الرأي للدكتور" appropriate?
6. Are WHO's implausible-value flags (weight z below −6 or above 5, height beyond ±6, head beyond ±5) the right cut-offs for a typing check?
7. Please review all the medical wording in the table above, and the I job, before it's written.

## Questions for the founder

1. Reminders are still only sent for optional vaccines the family follows. Keep it that way?
2. Should "mark everything due so far" offer optional vaccines at all? Today it's an unticked box in the confirmation.
3. At exactly 5 years, the Vaccines page is hidden. Should it stay open for a 5-year-old, so past doses can be recorded?
4. The CocoaPods checksum change for three Google and OpenID pods (bug 20): who checks it before the lock file is updated?
5. The move to `material_ui` (bug 19): when?
6. Your existing records for Gamila were saved dated 12 Nov 2026. They stay as they are. Correct them by opening each dose and changing its date, or untick and re-tick them in the setup.
