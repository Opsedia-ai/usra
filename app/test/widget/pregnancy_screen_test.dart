import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/database/app_database.dart';

import '../support/fits.dart';
import '../support/screen_harness.dart';

void main() {
  late ScreenHarness h;

  setUp(() => h = ScreenHarness());
  tearDown(() => h.dispose());

  Finder key(String k) => find.byKey(ValueKey(k));

  String iso(DateTime d) => d.toIso8601String().substring(0, 10);

  Future<String> seed(WidgetTester tester, {bool medicines = false}) async =>
      (await tester.runAsync(() async {
        final today = DateUtils.dateOnly(DateTime.now());
        final id = await h.db.addProfile(
          'منى',
          sex: 'female',
          birthDate: DateTime(1994, 3, 1),
        );
        await h.db.addEvent(
          profileId: id,
          type: 'pregnancy',
          occurredAt: today,
          dataJson: jsonEncode({
            'lmp': iso(today.subtract(const Duration(days: 98))),
          }),
        );
        if (medicines) {
          for (final name in ['Folic acid', 'Ferrous']) {
            await h.db.saveMedicine(
              profileId: id,
              name: name,
              startOn: DateTime(2026, 1, 1),
              schedule: const DoseScheduleInput(times: ['00:01']),
            );
          }
        }
        return id;
      }))!;

  testWidgets('Add is the main button; the red call is only in danger signs', (
    tester,
  ) async {
    h.tall(tester);
    final id = await seed(tester);
    await h.open(tester, '/family/$id/pregnancy');
    expect(key('pregnancy-add'), findsOneWidget);
    expect(
      find.descendant(
        of: key('pregnancy-danger-signs'),
        matching: key('pregnancy-ambulance'),
      ),
      findsOneWidget,
    );
    await h.tapKey(tester, 'pregnancy-add');
    expect(find.text('منى'), findsWidgets);
    expect(find.byKey(ValueKey('add-person-$id')), findsOneWidget);
  });

  testWidgets('says "تورّم", never "ورم"', (tester) async {
    h.tall(tester);
    final id = await seed(tester);
    await h.open(tester, '/family/$id/pregnancy');
    expect(find.text('تورّم في الوش أو الإيدين'), findsOneWidget);
    expect(find.text('ورم في الوش أو الإيدين'), findsNothing);
  });

  testWidgets('every warning sign stays, with its source', (tester) async {
    h.tall(tester);
    final id = await seed(tester);
    await h.open(tester, '/family/$id/pregnancy');
    final card = key('pregnancy-danger-signs');
    for (final sign in const [
      'نزيف من المهبل',
      'صداع جامد',
      'زغللة في النظر',
      'تشنجات أو إغماء',
      'وجع جامد في البطن',
      'سخونية',
      'نزول مية من المهبل',
      'حركة البيبي قلّت عن العادي أو وقفت',
      'صعوبة في التنفس',
    ]) {
      expect(
        find.descendant(of: card, matching: find.text(sign)),
        findsOneWidget,
        reason: sign,
      );
    }
  });

  testWidgets('each dose today is ticked on its own, and no supplement is '
      'suggested', (tester) async {
    h.tall(tester);
    final id = await seed(tester, medicines: true);
    await h.open(tester, '/family/$id/pregnancy');
    expect(find.textContaining('Folic acid'), findsOneWidget);
    expect(find.textContaining('Ferrous'), findsOneWidget);
    // Due just after midnight, so past and open whatever time this runs.
    final taken = find.descendant(
      of: key('pregnancy-supplements'),
      matching: find.text('اتاخد'),
    );
    expect(taken, findsNWidgets(2));
    await tester.tap(taken.first);
    await h.settle(tester);
    expect(key('pregnancy-supplements-empty'), findsNothing);
    expect(
      find.descendant(
        of: key('pregnancy-supplements'),
        matching: find.textContaining('Folic acid'),
      ),
      findsOneWidget,
    );
    final logs = (await tester.runAsync(
      () => h.db.select(h.db.doseLogs).get(),
    ))!;
    expect(logs, hasLength(1));
  });

  testWidgets('nothing recorded: says so and names no supplement', (
    tester,
  ) async {
    h.tall(tester);
    final id = await seed(tester);
    await h.open(tester, '/family/$id/pregnancy');
    expect(key('pregnancy-supplements-empty'), findsOneWidget);
    expect(find.textContaining('حمض الفوليك'), findsNothing);
    expect(find.textContaining('الحديد'), findsNothing);
  });

  group('fits 320 px at double text', () {
    forEachSmallLayout(() => h, (tester) async {
      final id = await seed(tester, medicines: true);
      await h.open(tester, '/family/$id/pregnancy');
      await walkScreen(tester);
    });
  });
}
