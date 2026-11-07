import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/app.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/features/family/record_form_screen.dart';
import 'package:usra/features/medicines/medicines_providers.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 11, 3, 13);

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  tearDown(() => db.close());

  Widget app() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => now),
    ],
    child: const UsraApp(),
  );

  Future<List<String>> people(WidgetTester tester, List<String> names) async =>
      (await tester.runAsync(() async {
        return [for (final n in names) await db.addProfile(n)];
      }))!;

  // Database work needs real time, which a widget test's clock doesn't pass.
  Future<void> settleDb(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  void phone(WidgetTester tester, {double width = 390, double height = 844}) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);
  }

  testWidgets('the regular bar has five labelled places', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    for (final label in ['الرئيسية', 'الأدوية', 'إضافة', 'السجلات', 'المزيد']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('four people fit without swiping', (tester) async {
    phone(tester);
    await people(tester, ['ليلى', 'جدو', 'يوسف', 'أنا']);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('مفيش حاجة مطلوبة'), findsNWidgets(4));
    expect(find.byKey(const ValueKey('home-family-scroller')), findsNothing);
    expect(find.byKey(const ValueKey('home-new-person')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nine people swipe, and all of them are in the list', (
    tester,
  ) async {
    phone(tester);
    final names = [for (var i = 1; i <= 9; i++) 'فرد $i'];
    await people(tester, names);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-family-scroller')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-all-family')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('family-count')), findsOneWidget);
    for (final n in names) {
      await tester.scrollUntilVisible(
        find.text(n),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(n), findsOneWidget);
    }
    // Back returns to Home, not out of the app.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-greeting')), findsOneWidget);
  });

  testWidgets('someone sick is named at the top and never "nothing needed"', (
    tester,
  ) async {
    phone(tester);
    final ids = await people(tester, ['يوسف', 'ليلى']);
    await tester.runAsync(
      () => db.saveEpisode(
        profileId: ids[0],
        startedAt: now.subtract(const Duration(hours: 5)),
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('تعبان'), findsOneWidget);
    expect(find.text('مفيش حاجة مطلوبة'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('home-attention-${ids[0]}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-greeting')), findsNothing);
  });

  testWidgets('a missed dose shows; Taken logs it and Undo takes it back', (
    tester,
  ) async {
    phone(tester);
    final ids = await people(tester, ['جدو']);
    await tester.runAsync(
      () => db.saveMedicine(
        profileId: ids[0],
        name: 'جلوكوفاج',
        startOn: DateTime(2026, 11, 1),
        schedule: const DoseScheduleInput(times: ['08:00']),
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('دوا فات'), findsOneWidget);
    expect(find.text('الجاي النهارده'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'اتاخد'));
    await settleDb(tester);
    expect(find.text('الجاي النهارده'), findsNothing);
    expect(find.text('مفيش حاجة مطلوبة'), findsOneWidget);
    expect(find.textContaining('اتسجل'), findsOneWidget);

    await tester.tap(find.text('تراجع'));
    await settleDb(tester);
    expect(find.text('دوا فات'), findsOneWidget);
  });

  testWidgets('a dose stays "next" for an hour, and snoozing keeps it open', (
    tester,
  ) async {
    phone(tester);
    final ids = await people(tester, ['جدو']);
    final medicine = await tester.runAsync(
      () => db.saveMedicine(
        profileId: ids[0],
        name: 'جلوكوفاج',
        startOn: DateTime(2026, 11, 1),
        // 12:30 is half an hour ago at the test's 13:00.
        schedule: const DoseScheduleInput(times: ['12:30']),
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('دوا فات'), findsNothing);
    expect(find.text('مفيش حاجة مطلوبة'), findsNothing);
    expect(find.textContaining('دوا ١٢:٣٠'), findsOneWidget);

    await tester.runAsync(
      () => db.logDose(
        medicine!,
        DateTime(2026, 11, 3, 12, 30).toUtc(),
        DoseOutcome.snoozed,
        at: now,
      ),
    );
    await settleDb(tester);
    expect(find.text('مفيش حاجة مطلوبة'), findsNothing);
  });

  testWidgets('a sick woman is تعبانة', (tester) async {
    phone(tester);
    final id = (await tester.runAsync(
      () => db.addProfile('ليلى', sex: 'female'),
    ))!;
    await tester.runAsync(() => db.saveEpisode(profileId: id, startedAt: now));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('تعبانة'), findsOneWidget);
  });

  testWidgets('Emergency can switch to anyone in the family', (tester) async {
    phone(tester);
    final ids = (await tester.runAsync(() async {
      return [
        await db.addProfile('ليلى'),
        await db.addProfile('جدو', allergies: 'بنسلين'),
      ];
    }))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-emergency')));
    await tester.pumpAndSettle();
    expect(find.text('بنسلين'), findsNothing);
    await tester.tap(find.byKey(ValueKey('emergency-person-${ids[1]}')));
    await tester.pumpAndSettle();
    expect(find.text('بنسلين'), findsOneWidget);
  });

  testWidgets('Add makes you choose a person when there are several', (
    tester,
  ) async {
    phone(tester);
    final ids = await people(tester, ['ليلى', 'جدو']);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-pick-person')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-medicines/new')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-pick-person')), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('add-person-${ids[1]}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-pick-person')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('add-add/visit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-pick-person')), findsNothing);
    final form = tester.widget<RecordFormScreen>(find.byType(RecordFormScreen));
    expect(form.profileId, ids[1]);
    expect(form.typeKey, 'visit');
  });

  testWidgets('Add starts on the person whose page is open', (tester) async {
    phone(tester);
    final ids = await people(tester, ['ليلى', 'جدو']);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('home-person-${ids[1]}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('person-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-pick-person')), findsNothing);
    final chip = tester.widget<ChoiceChip>(
      find.byKey(ValueKey('add-person-${ids[1]}')),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('Records lists everyone, and filters by person', (tester) async {
    phone(tester);
    final ids = await people(tester, ['ليلى', 'جدو']);
    await tester.runAsync(() async {
      await db.addEvent(
        profileId: ids[0],
        type: 'visit',
        occurredAt: DateTime(2026, 10, 1),
        dataJson: '{"doctorName":"د. منى"}',
      );
      await db.addEvent(
        profileId: ids[1],
        type: 'visit',
        occurredAt: DateTime(2026, 10, 2),
        dataJson: '{"doctorName":"د. هاني"}',
      );
    });
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('السجلات'));
    await tester.pumpAndSettle();
    expect(find.textContaining('د. منى'), findsOneWidget);
    expect(find.textContaining('د. هاني'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('records-filter-${ids[0]}')));
    await tester.pumpAndSettle();
    expect(find.textContaining('د. منى'), findsOneWidget);
    expect(find.textContaining('د. هاني'), findsNothing);
  });

  for (final (width, scale) in [(320.0, 1.0), (360.0, 2.0), (430.0, 1.3)]) {
    for (final count in [2, 9]) {
      testWidgets('Home fits $count people at $width px and $scale text', (
        tester,
      ) async {
        phone(tester, width: width, height: 700);
        await people(tester, [for (var i = 1; i <= count; i++) 'خالتو $i']);
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: Size(width, 700),
              textScaler: TextScaler.linear(scale),
            ),
            child: app(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
