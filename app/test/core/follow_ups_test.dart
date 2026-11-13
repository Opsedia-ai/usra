import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/design/tokens.dart';
import 'package:usra/core/follow_ups/follow_up.dart';
import 'package:usra/core/modules/module_registry.dart';
import 'package:usra/features/children/vaccine_follow_up.dart';
import 'package:usra/features/follow_ups/conditions.dart';
import 'package:usra/features/follow_ups/dismissals.dart';
import 'package:usra/features/follow_ups/rules/record_rules.dart';
import 'package:usra/features/follow_ups/rules/screening_rules.dart';
import 'package:usra/l10n/app_localizations.dart';
import 'package:usra/modules.dart';

final today = DateTime(2026, 11, 3);

Profile person({
  DateTime? birth,
  String? sex,
  String? conditions,
  String id = 'p1',
}) => Profile(
  id: id,
  displayName: 'منى',
  birthDate: birth,
  sex: sex,
  simpleMode: false,
  conditions: conditions,
  updatedAt: today,
);

var _ids = 0;

MedicalEvent record(
  String type,
  DateTime on,
  Map<String, Object?> data, {
  String? doctorId,
  DateTime? deletedAt,
}) => MedicalEvent(
  id: 'e${_ids++}',
  profileId: 'p1',
  type: type,
  occurredAt: on,
  doctorId: doctorId,
  dataJson: jsonEncode(data),
  updatedAt: on,
  deletedAt: deletedAt,
);

List<FollowUp> run(
  FollowUpRule rule,
  Profile profile, [
  List<MedicalEvent> events = const [],
  DateTime? on,
]) => rule.evaluate(FollowUpSubject(profile, events), on ?? today);

/// A person born on [today] minus [years] years (plus [days] days older).
DateTime aged(int years, {int days = 0}) =>
    DateTime(today.year - years, today.month, today.day - days);

void main() {
  group('FollowUp', () {
    FollowUp due(DateTime on, {int grace = 0}) => FollowUp(
      ruleId: 'r',
      profileId: 'p1',
      dueOn: on,
      title: (_) => '',
      reason: (_) => '',
      graceDays: grace,
    );

    test(
      'overdue acts soon, within two weeks is a heads-up, later is info',
      () {
        expect(due(DateTime(2026, 11, 2)).severityOn(today), Severity.actSoon);
        expect(due(today).severityOn(today), Severity.headsUp);
        expect(due(DateTime(2026, 11, 17)).severityOn(today), Severity.headsUp);
        expect(due(DateTime(2026, 11, 18)).severityOn(today), Severity.info);
      },
    );

    test('grace days delay "overdue"', () {
      final f = due(DateTime(2026, 10, 10), grace: 30);
      expect(f.severityOn(today), Severity.headsUp);
      expect(f.severityOn(DateTime(2026, 11, 10)), Severity.actSoon);
    });

    test('the cycle key changes with the due date', () {
      expect(due(DateTime(2026, 12, 1, 15)).cycleKey, 'p1|r|2026-12-01');
      expect(
        due(DateTime(2027, 6, 1)).cycleKey,
        isNot(due(DateTime(2026, 12, 1)).cycleKey),
      );
    });

    test('every module rule has a unique id', () {
      final ids = ModuleRegistry(appModules).followUpRules.map((r) => r.id);
      expect(ids.toSet().length, ids.length);
      expect(ids, containsAll(['visit', 'screening.breast', 'vaccines.egypt']));
    });
  });

  group('conditions', () {
    test('Arabic and English keywords', () {
      expect(conditionsIn('سكر من النوع التاني، ضغط عالي'), {
        Condition.diabetes,
        Condition.hypertension,
      });
      expect(conditionsIn('Type 2 Diabetes, high cholesterol'), {
        Condition.diabetes,
        Condition.highCholesterol,
      });
      expect(conditionsIn('عملية قلب مفتوح'), {Condition.heart});
      expect(conditionsIn('مرض السكّري'), {Condition.diabetes});
      expect(conditionsIn('فشل كلوي مزمن'), {Condition.kidney});
      expect(conditionsIn('CKD stage 3'), {Condition.kidney});
    });

    test('no false matches', () {
      expect(conditionsIn(null), isEmpty);
      expect(conditionsIn('ضغط واطي'), isEmpty);
      expect(conditionsIn('ضغط نفسي من الشغل'), isEmpty);
      expect(conditionsIn('heartburn'), isEmpty);
      expect(mentionsAny('دكتور معين', ['عين']), isFalse);
      expect(mentionsAny('كشف العين', ['عين']), isTrue);
    });
  });

  group('NextVisitRule', () {
    const rule = NextVisitRule();

    test('the next visit a doctor set', () {
      final visit = record('visit', DateTime(2026, 10, 1), {
        'doctorName': 'د. سامي',
        'nextVisit': '2026-11-10',
      });
      final [f] = run(rule, person(), [visit]);
      expect(f.dueOn, DateTime.utc(2026, 11, 10));
      expect(f.ruleId, 'visit.${visit.id}');
      expect(f.recordType, 'visit');
      expect(f.severityOn(today), Severity.headsUp);
    });

    test('closed by a later visit to the same doctor only', () {
      final events = [
        record('visit', DateTime(2026, 9, 1), {
          'doctorName': 'د. سامي',
          'nextVisit': '2026-10-01',
        }),
        record('visit', DateTime(2026, 10, 2), {'doctorName': 'د. سامي'}),
        record('visit', DateTime(2026, 9, 5), {
          'doctorName': 'Dr. Nada',
          'nextVisit': '2026-10-20',
        }),
        record('visit', DateTime(2026, 10, 1), {'doctorName': 'د. سامي'}),
      ];
      final [f] = run(rule, person(), events);
      expect(f.dueOn, DateTime.utc(2026, 10, 20));
      expect(f.severityOn(today), Severity.actSoon);
    });

    test('a linked doctor and the same name typed are the same doctor', () {
      final events = [
        record('visit', DateTime(2026, 9, 1), {
          'doctorName': 'د. سامي',
          'nextVisit': '2026-10-01',
        }, doctorId: 'd1'),
        record('visit', DateTime(2026, 10, 1), {'doctorName': 'د.  سامي'}),
      ];
      expect(run(rule, person(), events), isEmpty);
    });

    test('ignores stale, deleted and malformed dates', () {
      expect(
        run(rule, person(), [
          record('visit', DateTime(2025, 1, 1), {'nextVisit': '2025-02-01'}),
          record('visit', DateTime(2026, 10, 1), {
            'nextVisit': '2026-12-01',
          }, deletedAt: today),
          record('visit', DateTime(2026, 10, 1), {'nextVisit': 'soon'}),
          record('visit', DateTime(2026, 10, 1), {'nextVisit': 5}),
        ]),
        isEmpty,
      );
    });
  });

  group('VaccineNextDueRule', () {
    const rule = VaccineNextDueRule();

    test('the next dose, closed by a later dose of the same vaccine', () {
      final flu = record('vaccine', DateTime(2025, 11, 1), {
        'vaccine': 'Flu',
        'nextDue': '2026-11-01',
      });
      final [f] = run(rule, person(), [flu]);
      expect(f.dueOn, DateTime.utc(2026, 11, 1));
      expect(f.recordType, 'vaccine');
      expect(
        run(rule, person(), [
          flu,
          record('vaccine', DateTime(2026, 10, 25), {'vaccine': 'flu'}),
        ]),
        isEmpty,
      );
    });
  });

  group('chronic labs', () {
    test('HbA1c six months after the last one with diabetes', () {
      final diabetic = person(conditions: 'سكر', sex: 'female');
      final [f] = run(const Hba1cRule(), diabetic, [
        record('lab', DateTime(2026, 2, 10), {'test': 'السكر التراكمي'}),
        record('lab', DateTime(2026, 5, 10), {'test': 'HbA1c', 'value': 7.1}),
        record('lab', DateTime(2026, 6, 10), {'test': 'CBC'}),
      ]);
      expect(f.dueOn, DateTime.utc(2026, 11, 10));
      expect(f.source, contains('ADA'));
      expect(f.recordType, 'lab');
    });

    test('due now when none is recorded; nothing without the condition', () {
      final [f] = run(const Hba1cRule(), person(conditions: 'diabetes'));
      expect(f.dueOn, DateTime.utc(2026, 11, 3));
      // Hiding it lasts past today: the cycle doesn't move with the date.
      final [tomorrow] = run(
        const Hba1cRule(),
        person(conditions: 'diabetes'),
        const [],
        DateTime(2026, 11, 4),
      );
      expect(tomorrow.cycleKey, f.cycleKey);
      expect(f.cycleKey, 'p1|lab.hba1c|none');
      expect(run(const Hba1cRule(), person(conditions: 'ربو')), isEmpty);
      expect(run(const Hba1cRule(), person()), isEmpty);
    });

    test('lipid profile yearly with heart disease or high cholesterol', () {
      final [f] = run(const LipidProfileRule(), person(conditions: 'قلب'), [
        record('lab', DateTime(2025, 12, 1), {'test': 'Lipid profile'}),
      ]);
      expect(f.dueOn, DateTime.utc(2026, 12, 1));
      expect(f.severityOn(today), Severity.info);
      expect(
        run(const LipidProfileRule(), person(conditions: 'كوليسترول')),
        hasLength(1),
      );
    });

    test('kidney check yearly with high blood pressure', () {
      final [f] = run(const KidneyCheckRule(), person(conditions: 'ضغط'), [
        record('lab', DateTime(2025, 10, 1), {'test': 'كرياتينين'}),
      ]);
      expect(f.dueOn, DateTime.utc(2026, 10, 1));
      expect(f.severityOn(today), Severity.actSoon);
    });
  });

  group('ScanFollowUpRule', () {
    const rule = ScanFollowUpRule();

    test('uses the months written in the result, Arabic digits too', () {
      final [f] = run(rule, person(), [
        record('scan', DateTime(2026, 8, 1), {
          'kind': 'ultrasound',
          'result': 'كيس بسيط، متابعة بعد ٣ شهور',
        }),
      ]);
      expect(f.dueOn, DateTime.utc(2026, 11, 1));
      expect(f.recordType, 'scan');
    });

    test('weeks, the six-month default, and a later scan closing it', () {
      final [weeks] = run(rule, person(), [
        record('scan', DateTime(2026, 10, 1), {
          'kind': 'xray',
          'result': 'Repeat in 6 weeks',
        }),
      ]);
      expect(weeks.dueOn, DateTime.utc(2026, 11, 12));

      final nodule = record('scan', DateTime(2026, 6, 1), {
        'kind': 'ct',
        'result': 'Small nodule, follow-up advised',
      });
      final [f] = run(rule, person(), [nodule]);
      expect(f.dueOn, DateTime.utc(2026, 12, 1));
      expect(
        run(rule, person(), [
          nodule,
          record('scan', DateTime(2026, 10, 1), {'kind': 'ct'}),
        ]),
        isEmpty,
      );
    });

    test('"no follow-up needed" needs nothing; a comma ends the "no"', () {
      for (final result in [
        'لا يحتاج متابعة',
        'Normal. No follow-up needed',
        'لا داعي للمتابعة',
      ]) {
        expect(
          run(rule, person(), [
            record('scan', DateTime(2026, 6, 1), {
              'kind': 'xray',
              'result': result,
            }),
          ]),
          isEmpty,
          reason: result,
        );
      }
      expect(
        run(rule, person(), [
          record('scan', DateTime(2026, 6, 1), {
            'kind': 'ct',
            'result': 'No change, follow up in 6 months',
          }),
        ]),
        hasLength(1),
      );
    });

    test('a normal result needs nothing', () {
      expect(
        run(rule, person(), [
          record('scan', DateTime(2026, 6, 1), {
            'kind': 'xray',
            'result': 'سليمة',
          }),
        ]),
        isEmpty,
      );
    });
  });

  group('screening by age and sex', () {
    test('blood pressure yearly from 18', () {
      const rule = BloodPressureRule();
      expect(run(rule, person(birth: aged(16))), isEmpty);
      // Turns 18 within the year: due on the birthday.
      final [soon] = run(rule, person(birth: aged(18, days: -30)));
      expect(soon.dueOn, DateTime.utc(2026, 12, 3));
      final [f] = run(rule, person(birth: aged(30)), [
        record('visit', DateTime(2026, 3, 1), {'reason': 'قياس ضغط'}),
      ]);
      expect(f.dueOn, DateTime.utc(2027, 3, 1));
      expect(f.source, contains('USPSTF'));
      expect(run(rule, person()), isEmpty, reason: 'no birth date');
    });

    test('diabetes screening at 35–70, not for diabetics', () {
      const rule = DiabetesScreeningRule();
      expect(run(rule, person(birth: aged(30))), isEmpty);
      final [f] = run(rule, person(birth: aged(50)), [
        record('lab', DateTime(2024, 1, 15), {'test': 'Fasting glucose'}),
      ]);
      expect(f.dueOn, DateTime.utc(2027, 1, 15));
      expect(run(rule, person(birth: aged(50), conditions: 'سكر')), isEmpty);
      expect(run(rule, person(birth: aged(71))), isEmpty);
    });

    test('mammogram every two years for women 40–74', () {
      const rule = BreastScreeningRule();
      expect(run(rule, person(birth: aged(45), sex: 'male')), isEmpty);
      expect(
        run(rule, person(birth: aged(45))),
        isEmpty,
        reason: 'sex unknown',
      );
      expect(run(rule, person(birth: aged(75), sex: 'female')), isEmpty);
      final [f] = run(rule, person(birth: aged(45), sex: 'female'), [
        record('scan', DateTime(2025, 5, 1), {
          'kind': 'other',
          'result': 'Mammogram BIRADS 1',
        }),
      ]);
      expect(f.dueOn, DateTime.utc(2027, 5, 1));
      final [never] = run(rule, person(birth: aged(41), sex: 'female'));
      expect(never.dueOn, DateTime.utc(2026, 11, 3));
      // A visit for breast pain isn't a mammogram.
      expect(
        run(rule, person(birth: aged(45), sex: 'female'), [
          record('visit', DateTime(2026, 5, 1), {'reason': 'ألم في الثدي'}),
        ]).single.dueOn,
        DateTime.utc(2026, 11, 3),
      );
    });

    test('colorectal at 45–75; a colonoscopy lasts ten years', () {
      const rule = ColorectalScreeningRule();
      expect(run(rule, person(birth: aged(40))), isEmpty);
      final [scope] = run(rule, person(birth: aged(55)), [
        record('surgery', DateTime(2020, 4, 1), {'procedure': 'منظار قولون'}),
      ]);
      expect(scope.dueOn, DateTime.utc(2030, 4, 1));
      final [stool] = run(rule, person(birth: aged(55)), [
        record('lab', DateTime(2026, 1, 1), {'test': 'FIT test'}),
      ]);
      expect(stool.dueOn, DateTime.utc(2027, 1, 1));
      // Next screening falls after 75: nothing left to suggest.
      expect(
        run(rule, person(birth: aged(74)), [
          record('surgery', DateTime(2025, 1, 1), {'procedure': 'Colonoscopy'}),
        ]),
        isEmpty,
      );
    });

    test('yearly eye exam with diabetes only', () {
      const rule = DiabeticEyeExamRule();
      expect(run(rule, person(birth: aged(60))), isEmpty);
      final [f] = run(rule, person(birth: aged(60), conditions: 'DM2'), [
        record('visit', DateTime(2025, 12, 20), {'reason': 'كشف قاع العين'}),
      ]);
      expect(f.dueOn, DateTime.utc(2026, 12, 20));
    });

    test('dental check-up yearly from age 1', () {
      const rule = DentalCheckupRule();
      // From the first birthday.
      final [baby] = run(rule, person(birth: aged(0, days: 100)));
      expect(baby.dueOn, DateTime.utc(2027, 7, 26));
      final [f] = run(rule, person(birth: aged(8)), [
        record('visit', DateTime(2026, 2, 1), {'doctorName': 'دكتور أسنان'}),
      ]);
      expect(f.dueOn, DateTime.utc(2027, 2, 1));
    });

    test("dental: a child sees the children's guideline, an adult the "
        "adults' (e2e #6)", () {
      const rule = DentalCheckupRule();
      final [child] = run(rule, person(birth: aged(8)));
      expect(child.source, DentalCheckupRule.childSource);
      expect(child.source, contains('AAPD'));
      final [teen] = run(rule, person(birth: aged(17)));
      expect(teen.source, DentalCheckupRule.childSource);
      final [adult] = run(rule, person(birth: aged(35)));
      expect(adult.source, DentalCheckupRule.adultSource);
      expect(adult.source, isNot(contains('children')));
      expect(adult.source, isNot(contains('AAPD')));
      final [grandpa] = run(rule, person(birth: aged(61)));
      expect(grandpa.source, DentalCheckupRule.adultSource);
    });
  });

  group('ChildCheckupRule', () {
    const rule = ChildCheckupRule();
    final birth = DateTime(2026, 4, 3); // 7 months old on [today]

    test('missed check-ups make one: the latest one due', () {
      final [f] = run(rule, person(birth: birth));
      expect(f.dueOn, DateTime.utc(2026, 10, 3)); // 6 months
      expect(f.ruleId, 'screening.childCheckup.6');
      expect(f.severityOn(today), Severity.actSoon);
    });

    test('after the 6-month check-up the next is at 9 months', () {
      final [f] = run(rule, person(birth: birth), [
        record('growth', DateTime(2026, 10, 1), {'weightKg': 7.5}),
      ]);
      expect(f.dueOn, DateTime.utc(2027, 1, 3));
      expect(f.severityOn(today), Severity.info);
    });

    test('yearly for school-age children, none from 18', () {
      final [f] = run(rule, person(birth: aged(10, days: 40)), [
        record('visit', DateTime(2026, 1, 1), {'reason': 'كشف دوري'}),
      ]);
      // Last seen at 9; the 10-year check-up was due in September.
      expect(f.ruleId, 'screening.childCheckup.120');
      expect(f.severityOn(today), Severity.actSoon);
      expect(run(rule, person(birth: aged(18))), isEmpty);
    });
  });

  group('EgyptVaccineRule', () {
    const rule = EgyptVaccineRule();

    test('the earliest open doses, with a month of grace', () {
      final birth = DateTime(2026, 7, 1); // 4 months old on [today]
      final given = [
        for (final name in ['كبدي', 'BCG', 'شلل الأطفال'])
          record('vaccine', birth, {'vaccine': name}),
        for (final name in ['شلل', 'شلل بالحقن', 'خماسي'])
          record('vaccine', DateTime(2026, 9, 1), {'vaccine': name}),
      ];
      final [f] = run(rule, person(birth: birth), given);
      expect(f.ruleId, 'vaccines.egypt.4');
      expect(f.dueOn, DateTime.utc(2026, 11, 1));
      expect(f.severityOn(today), Severity.headsUp);
      expect(f.recordType, 'vaccine');
    });

    test('not for over-fives or unknown birth dates', () {
      expect(run(rule, person(birth: aged(6))), isEmpty);
      expect(run(rule, person()), isEmpty);
    });
  });

  group('dismissal store', () {
    test('saves and reloads; a corrupt file starts empty', () async {
      final dir = await Directory.systemTemp.createTemp('usra_dismissals');
      addTearDown(() => dir.delete(recursive: true));
      final store = await FileDismissalStore.open(dir);
      expect(store.load(), isEmpty);
      await store.save({'p1|visit.e1|2026-11-10'});
      expect((await FileDismissalStore.open(dir)).load(), {
        'p1|visit.e1|2026-11-10',
      });
      await File('${dir.path}/${FileDismissalStore.fileName}')
          .writeAsString('{not json');
      expect((await FileDismissalStore.open(dir)).load(), isEmpty);
    });

    test('a failed write doesn\'t block the next one', () async {
      final dir = await Directory.systemTemp.createTemp('usra_dismissals');
      addTearDown(() => dir.delete(recursive: true));
      final store = await FileDismissalStore.open(dir);
      // A folder where the temporary file goes makes the write fail.
      final tmp = Directory('${dir.path}/${FileDismissalStore.fileName}.tmp')
        ..createSync();
      await expectLater(store.save({'a'}), throwsA(isA<FileSystemException>()));
      tmp.deleteSync();
      await store.save({'b'});
      expect((await FileDismissalStore.open(dir)).load(), {'b'});
    });
  });

  testWidgets('reasons follow the person’s sex in Arabic', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('ar'),
        delegates: AppLocalizations.localizationsDelegates,
        child: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final [her] = run(
      const DiabeticEyeExamRule(),
      person(birth: aged(50), sex: 'female', conditions: 'سكر'),
    );
    expect(her.reason(ctx), 'لأن عندها سكر – مفيش واحد متسجل لسه');
    final [him] = run(
      const DiabeticEyeExamRule(),
      person(birth: aged(50), sex: 'male', conditions: 'سكر'),
    );
    expect(him.reason(ctx), startsWith('لأن عنده سكر'));
  });
}
