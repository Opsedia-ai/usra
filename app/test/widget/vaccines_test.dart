import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:usra/app.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/features/children/child_vaccines.dart';
import 'package:usra/features/children/egypt_vaccines.dart';
import 'package:usra/features/children/growth.dart';
import 'package:usra/features/medicines/medicines_providers.dart';
import 'package:usra/features/medicines/reminders.dart';

import '../support/fake_reminder_scheduler.dart';

void main() {
  late AppDatabase db;
  late FakeReminderScheduler scheduler;

  setUp(() {
    // Notifications not allowed yet, as on a phone with no medicines.
    scheduler = FakeReminderScheduler(
      granted: const ReminderAccess(notifications: false),
    )..afterRequest = const ReminderAccess(notifications: true);
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
      reminderSchedulerProvider.overrideWithValue(scheduler),
    ],
    child: const UsraApp(),
  );

  Finder inKey(String key, String text) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.textContaining(text),
  );

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('setup: route, optional vaccines, doses given; then filters, '
      'notes and the Home countdown', (tester) async {
    tester.view.physicalSize = const Size(1170, 9000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    final today = DateUtils.dateOnly(DateTime.now());
    final birth = addMonths(today, -7);
    final kid = (await tester.runAsync(
      () => db.addProfile('ليلى', birthDate: birth, sex: 'female'),
    ))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));

    // Right after adding the child.
    router.go('/family/$kid/vaccines/setup?first=1');
    await tester.pumpAndSettle();
    expect(find.text('تجهيز التطعيمات'), findsOneWidget);
    expect(find.byKey(const ValueKey('vaccine-setup-skip')), findsOneWidget);
    // Government route by default: pentavalent, no hexavalent.
    expect(find.byKey(const ValueKey('setup-penta-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-hexa-1')), findsNothing);
    // Optional doses aren't listed until chosen.
    expect(find.byKey(const ValueKey('setup-pcv-1')), findsNothing);

    await tapKey(tester, 'vaccine-route-hexavalent');
    expect(find.byKey(const ValueKey('setup-penta-1')), findsNothing);
    expect(find.byKey(const ValueKey('setup-hexa-1')), findsOneWidget);
    await tapKey(tester, 'vaccine-optional-pcv');
    expect(find.byKey(const ValueKey('setup-pcv-1')), findsOneWidget);
    // Not due yet (12 months): not in the "already given" list.
    expect(find.byKey(const ValueKey('setup-opv-5')), findsNothing);

    for (final key in ['hepB-0', 'bcg-1', 'opv-0', 'hexa-1', 'pcv-1']) {
      await tapKey(tester, 'setup-$key');
    }
    expect(scheduler.requests, 0);
    await tapKey(tester, 'vaccine-setup-save');
    // Vaccine reminders need notifications: asked for once the plan is saved.
    expect(scheduler.requests, 1);
    expect(scheduler.lastRequestedExactAlarms, isFalse);

    // The vaccine page, with the counter.
    expect(find.text('تطعيمات ليلى'), findsWidgets);
    expect(inKey('vaccine-required-$kid', '٤/١٥'), findsOneWidget);
    expect(inKey('vaccine-optional-$kid', '١/٤'), findsOneWidget);
    expect(inKey('dose-hexa-1', 'اتاخد'), findsOneWidget);
    await tapKey(tester, 'vaccine-done-group');
    expect(inKey('dose-bcg-1', 'اتاخد'), findsOneWidget);
    // Saved as ordinary vaccine records, with the due date as the date.
    final events = (await tester.runAsync(() => db.watchTimeline(kid).first))!;
    final records = vaccineRecords(events);
    expect(records, hasLength(5));
    expect(
      records.firstWhere((r) => r.name == 'السداسي').date,
      DateTime(
        addMonths(birth, 2).year,
        addMonths(birth, 2).month,
        addMonths(birth, 2).day,
        12,
      ),
    );
    expect(vaccinePlanOf(events).route, VaccineRoute.hexavalent);
    expect(vaccinePlanOf(events).optional, {VaccineKind.pcv});

    // Filters.
    await tapKey(tester, 'vaccine-filter-overdue');
    expect(find.byKey(const ValueKey('dose-hexa-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('dose-bcg-1')), findsNothing);
    // Rotavirus isn't in the plan: never overdue.
    expect(find.byKey(const ValueKey('dose-rota-1')), findsNothing);
    await tapKey(tester, 'vaccine-filter-optional');
    expect(inKey('dose-rota-1', 'مش في خطتك'), findsOneWidget);
    expect(find.byKey(const ValueKey('dose-hexa-1')), findsNothing);
    await tapKey(tester, 'vaccine-filter-required');
    expect(find.byKey(const ValueKey('dose-pcv-1')), findsNothing);
    expect(find.byKey(const ValueKey('dose-opv-4')), findsOneWidget);
    await tapKey(tester, 'vaccine-filter-all');
    expect(find.byKey(const ValueKey('dose-rota-1')), findsNothing);
    expect(find.byKey(const ValueKey('dose-pcv-2')), findsOneWidget);

    // A note on a dose, and marking it given.
    await tapKey(tester, 'dose-hexa-2');
    await tester.enterText(
      find.byKey(const ValueKey('dose-note')),
      'اتأجلت عشان دور برد',
    );
    await tapKey(tester, 'dose-given');
    await tapKey(tester, 'dose-save');
    expect(inKey('dose-hexa-2', 'اتأجلت عشان دور برد'), findsOneWidget);
    expect(inKey('dose-hexa-2', 'اتاخد'), findsOneWidget);
    expect(inKey('vaccine-required-$kid', '٥/١٥'), findsOneWidget);

    // Home: the child's next visit and what's overdue.
    router.go('/home');
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('home-vaccines-$kid')), findsOneWidget);
    expect(inKey('home-vaccines-$kid', 'ليلى'), findsOneWidget);
    expect(inKey('vaccine-overdue-$kid', 'متأخر'), findsOneWidget);
    // The 9-month visit is about two months away.
    expect(inKey('vaccine-next-$kid', 'بعد'), findsOneWidget);
    // Home's follow-up list leaves vaccines to this card.
    expect(inKey('home-follow-ups', 'التطعيمات'), findsNothing);

    await tester.tap(find.byKey(ValueKey('home-vaccines-$kid')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('vaccine-setup-open')), findsOneWidget);
  });

  testWidgets('Home: no card without young children; "today" countdown', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 6000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    final today = DateUtils.dateOnly(DateTime.now());
    final kid = (await tester.runAsync(() async {
      await db.addProfile('منى', birthDate: DateTime(1990, 5, 1));
      // Exactly 2 months old today: the 2-month visit is today.
      final birth = addMonths(today, -2);
      final kid = await db.addProfile('يوسف', birthDate: birth);
      for (final d in egyptMandatorySchedule.where((d) => d.ageMonths == 0)) {
        await db.addEvent(
          profileId: kid,
          type: 'vaccine',
          occurredAt: birth,
          dataJson: '{"vaccine": "${d.kind.name}", "dose": ${d.dose}}',
        );
      }
      return kid;
    }))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-vaccines')), findsOneWidget);
    // addMonths can land on a month end; only check when it's exact.
    if (addMonths(addMonths(today, -2), 2) == today) {
      expect(inKey('vaccine-next-$kid', 'النهارده'), findsOneWidget);
    }
    expect(find.byKey(ValueKey('vaccine-overdue-$kid')), findsNothing);

    await tester.runAsync(() => db.softDeleteProfile(kid));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-vaccines')), findsNothing);
  });

  testWidgets('dose sheet: a later dose is never given in the future, and a '
      'record from before the birth date can be re-dated', (tester) async {
    tester.view.physicalSize = const Size(1170, 9000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    final today = DateUtils.dateOnly(DateTime.now());
    final birth = addMonths(today, -7);
    final kid = (await tester.runAsync(() async {
      final kid = await db.addProfile('ليلى', birthDate: birth);
      // Typed before the birth date was corrected.
      await db.addEvent(
        profileId: kid,
        type: 'vaccine',
        occurredAt: birth.subtract(const Duration(days: 3)),
        dataJson: '{"vaccine": "BCG"}',
      );
      return kid;
    }))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/family/$kid/vaccines');
    await tester.pumpAndSettle();

    // The 9-month polio drops, marked given at 7 months.
    await tapKey(tester, 'dose-opv-4');
    await tapKey(tester, 'dose-given');
    await tapKey(tester, 'dose-save');
    final records = vaccineRecords(
      (await tester.runAsync(() => db.watchTimeline(kid).first))!,
    );
    final opv = records.firstWhere((r) => r.dose == 4);
    expect(DateUtils.dateOnly(opv.date), today);

    // The early BCG record opens the date picker without an error.
    await tapKey(tester, 'dose-bcg-1');
    await tapKey(tester, 'dose-date');
    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('turning vaccine reminders on in Settings asks for '
      'notifications', (tester) async {
    tester.view.physicalSize = const Size(1170, 9000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/settings');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-vaccine-time')), findsOneWidget);
    await tapKey(tester, 'settings-vaccine-reminders');
    expect(find.byKey(const ValueKey('settings-vaccine-time')), findsNothing);
    expect(scheduler.requests, 0);
    await tapKey(tester, 'settings-vaccine-reminders');
    expect(scheduler.requests, 1);
    // Already allowed: not asked again.
    await tapKey(tester, 'settings-vaccine-reminders');
    await tapKey(tester, 'settings-vaccine-reminders');
    expect(scheduler.requests, 1);
  });

  testWidgets('unticking a dose the family typed asks first', (tester) async {
    tester.view.physicalSize = const Size(1170, 9000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    final birth = addMonths(DateUtils.dateOnly(DateTime.now()), -3);
    final kid = (await tester.runAsync(() async {
      final kid = await db.addProfile('ليلى', birthDate: birth);
      await db.addEvent(
        profileId: kid,
        type: 'vaccine',
        occurredAt: birth,
        dataJson: '{"vaccine": "BCG"}',
        photos: ['attachments/card.jpg'],
      );
      return kid;
    }))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/family/$kid/vaccines');
    await tester.pumpAndSettle();
    Future<int> records() async => vaccineRecords(
      (await tester.runAsync(() => db.watchTimeline(kid).first))!,
    ).length;

    await tapKey(tester, 'dose-bcg-1');
    await tapKey(tester, 'dose-given');
    await tapKey(tester, 'dose-save');
    expect(
      find.byKey(const ValueKey('vaccine-remove-confirm')),
      findsOneWidget,
    );
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(await records(), 1);
    expect(find.byKey(const ValueKey('dose-save')), findsOneWidget);

    await tapKey(tester, 'dose-save');
    await tapKey(tester, 'vaccine-remove-ok');
    expect(await records(), 0);
    expect(inKey('dose-bcg-1', 'اتاخد'), findsNothing);

    // A dose ticked in the app is unticked without asking.
    await tapKey(tester, 'dose-hepB-0');
    await tapKey(tester, 'dose-given');
    await tapKey(tester, 'dose-save');
    expect(await records(), 1);
    await tapKey(tester, 'dose-hepB-0');
    await tapKey(tester, 'dose-given');
    await tapKey(tester, 'dose-save');
    expect(find.byKey(const ValueKey('vaccine-remove-confirm')), findsNothing);
    expect(await records(), 0);
  });

  testWidgets('Simple Mode Home shows the next vaccine visit', (tester) async {
    tester.view.physicalSize = const Size(1170, 6000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    final kid = (await tester.runAsync(
      () => db.addProfile(
        'يوسف',
        birthDate: addMonths(DateUtils.dateOnly(DateTime.now()), -1),
      ),
    ))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          reminderSchedulerProvider.overrideWithValue(scheduler),
          keyValueStoreProvider.overrideWithValue(
            MemoryKeyValueStore({
              PrefKeys.simpleMode: true,
              PrefKeys.tutorialSeen: true,
              PrefKeys.elderTutorialSeen: true,
            }),
          ),
        ],
        child: const UsraApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('simple-greeting')), findsOneWidget);
    expect(find.byKey(ValueKey('home-vaccines-$kid')), findsOneWidget);
    expect(find.byKey(const ValueKey('simple-medicines')), findsOneWidget);
  });

  testWidgets('the hidden vaccine plan never shows in the timeline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 6000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    final kid = (await tester.runAsync(() async {
      final kid = await db.addProfile('ليلى', birthDate: DateTime(2026, 1, 1));
      await db.saveSingletonEvent(
        profileId: kid,
        type: VaccinePlanFields.type,
        dataJson: const VaccinePlan(optional: {VaccineKind.pcv}).toJson(),
      );
      // A record type this version doesn't know (from a newer build).
      await db.addEvent(
        profileId: kid,
        type: 'fromTheFuture',
        occurredAt: DateTime(2026, 2, 1),
      );
      return kid;
    }))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/family/$kid');
    await tester.pumpAndSettle();
    expect(find.textContaining('vaccinePlan'), findsNothing);
    expect(find.textContaining('fromTheFuture'), findsNothing);
    expect(find.text('خطة التطعيم'), findsNothing);
  });
}
