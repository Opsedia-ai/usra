import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/features/labs/lab_report.dart';

import '../support/fits.dart';
import '../support/screen_harness.dart';

void main() {
  late ScreenHarness h;

  setUp(() => h = ScreenHarness());
  tearDown(() => h.dispose());

  Finder key(String k) => find.byKey(ValueKey(k));

  Future<(String, String)> seedLab(
    WidgetTester tester, {
    String? allergies,
    String? conditions,
    bool medicine = false,
  }) async => (await tester.runAsync(() async {
    final id = await h.db.addProfile(
      'جدو',
      sex: 'male',
      birthDate: DateTime(1952, 1, 1),
      allergies: allergies,
      conditions: conditions,
    );
    if (medicine) {
      await h.db.saveMedicine(
        profileId: id,
        name: 'Glucophage',
        strength: '500 mg',
        startOn: DateTime(2026, 1, 1),
        schedule: const DoseScheduleInput(times: ['20:00']),
      );
    }
    final lab = await h.db.addEvent(
      profileId: id,
      type: LabFields.type,
      occurredAt: DateTime(2026, 9, 12),
      dataJson: jsonEncode({
        LabFields.lab: 'البرج',
        LabFields.tests: [
          {
            'name': 'Hemoglobin',
            'value': 11.8,
            'unit': 'g/dL',
            'low': 13.0,
            'high': 17.0,
            'rangePrinted': '13-17',
          },
          {'name': 'Platelets', 'value': 260.0, 'unit': 'K/uL'},
        ],
      }),
    );
    return (id, lab);
  }))!;

  group('Labs', () {
    testWidgets('compares with the lab\'s own range, and says when it has '
        'none', (tester) async {
      h.tall(tester);
      final (id, lab) = await seedLab(tester);
      await h.open(tester, '/family/$id/record/$lab');
      expect(
        find.descendant(
          of: key('lab-result-0'),
          matching: find.text('أقل من معدل المعمل'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: key('lab-result-1'),
          matching: find.text('مفيش معدل نقارن بيه'),
        ),
        findsOneWidget,
      );
      expect(key('lab-info-note'), findsOneWidget);
    });
  });

  group('Follow-ups', () {
    testWidgets('family page names people; empty says so', (tester) async {
      h.tall(tester);
      await h.open(tester, '/follow-ups');
      expect(key('follow-ups-empty'), findsOneWidget);
    });

    testWidgets('groups by this week and later, naming the person', (
      tester,
    ) async {
      h.tall(tester);
      await tester.runAsync(() async {
        final id = await h.db.addProfile(
          'جدو',
          sex: 'male',
          birthDate: DateTime(1952, 1, 1),
        );
        final today = DateTime.now();
        for (final (days, name) in [(3, 'soon'), (40, 'later')]) {
          await h.db.addEvent(
            profileId: id,
            type: 'visit',
            occurredAt: today,
            dataJson: jsonEncode({
              'doctorName': name,
              'nextVisit': today
                  .add(Duration(days: days))
                  .toIso8601String()
                  .substring(0, 10),
            }),
          );
        }
      });
      await h.open(tester, '/follow-ups');
      expect(find.text('النهارده والأسبوع ده'), findsOneWidget);
      expect(find.text('بعد كده'), findsOneWidget);
      expect(find.textContaining('جدو –'), findsWidgets);
    });
  });

  group('Doctor summary', () {
    testWidgets('invents nothing: only what was recorded', (tester) async {
      h.tall(tester);
      final (id, _) = await seedLab(tester);
      await h.open(tester, '/family/$id/doctor-summary');
      expect(key('summary-preview-allergies'), findsNothing);
      expect(key('summary-preview-conditions'), findsNothing);
      expect(key('summary-preview-medicines'), findsNothing);
      expect(key('summary-preview-labs'), findsOneWidget);
      expect(
        find.text('ده ملخص من اللي العيلة سجلته، مش رأي طبي.'),
        findsOneWidget,
      );
    });

    testWidgets('the preview lists what the PDF lists: not future, not empty', (
      tester,
    ) async {
      h.tall(tester);
      final id = (await tester.runAsync(() async {
        final id = await h.db.addProfile('جدو', sex: 'male');
        final soon = DateTime.now().add(const Duration(days: 30));
        await h.db.saveMedicine(
          profileId: id,
          name: 'Later',
          startOn: soon,
          schedule: const DoseScheduleInput(times: ['20:00']),
        );
        await h.db.addEvent(
          profileId: id,
          type: LabFields.type,
          occurredAt: soon,
          dataJson: jsonEncode({
            LabFields.tests: [
              {'name': 'Hemoglobin', 'value': 11.8},
            ],
          }),
        );
        return id;
      }))!;
      await h.open(tester, '/family/$id/doctor-summary');
      expect(key('summary-preview-medicines'), findsNothing);
      expect(key('summary-preview-labs'), findsNothing);
    });

    testWidgets('shows what exists, and a section unticked leaves', (
      tester,
    ) async {
      h.tall(tester);
      final (id, _) = await seedLab(
        tester,
        allergies: 'Penicillin',
        conditions: 'سكر',
        medicine: true,
      );
      await h.open(tester, '/family/$id/doctor-summary');
      expect(find.text('Penicillin'), findsOneWidget);
      expect(find.text('سكر'), findsOneWidget);
      expect(find.text('Glucophage 500 mg'), findsOneWidget);
      await h.tapKey(tester, 'summary-section-allergies');
      expect(find.text('Penicillin'), findsNothing);
    });
  });

  group('fits 320 px at double text', () {
    forEachSmallLayout(() => h, (tester) async {
      final (id, lab) = await seedLab(
        tester,
        allergies: 'Penicillin',
        conditions: 'سكر، ضغط',
        medicine: true,
      );
      await h.open(tester, '/family/$id/record/$lab');
      await walkScreen(tester);
      await h.go(tester, '/family/$id/labs');
      await walkScreen(tester);
      await h.go(tester, '/follow-ups');
      await walkScreen(tester);
      await h.go(tester, '/family/$id/doctor-summary');
      await walkScreen(tester);
    });
  });
}
