import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:usra/app.dart';
import 'package:usra/core/design/pill_chip.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/design/bottom_bar.dart';
import 'package:usra/core/design/dr_usra.dart';
import 'package:usra/core/design/tokens.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/core/security/app_lock.dart';
import 'package:usra/features/doctors/contact_links.dart';
import 'package:usra/features/family/profile_form_screen.dart'
    show relationships;
import 'package:usra/l10n/app_localizations.dart';

import '../support/fake_lock.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 11, 3, 13);
  final ar = lookupAppLocalizations(const Locale('ar'));

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  tearDown(() => db.close());

  Widget app({AppLock? lock, Map<String, Object> prefs = const {}}) =>
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
          if (lock != null) appLockProvider.overrideWithValue(lock),
          keyValueStoreProvider.overrideWithValue(
            MemoryKeyValueStore({
              PrefKeys.tutorialSeen: true,
              PrefKeys.elderTutorialSeen: true,
              ...prefs,
            }),
          ),
        ],
        child: const UsraApp(),
      );

  void phone(WidgetTester tester, {double width = 390, double height = 844}) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);
  }

  void largeText(WidgetTester tester) {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  // Database work needs real time, which a widget test's clock doesn't pass.
  Future<void> settleDb(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> open(WidgetTester tester, String path) async {
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);
    await settleDb(tester);
  }

  // The person page is a lazy list: scroll until a section is built.
  Future<void> reveal(
    WidgetTester tester,
    Finder f, {
    double delta = 200,
  }) async {
    await tester.scrollUntilVisible(
      f,
      delta,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await reveal(tester, f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await settleDb(tester);
  }

  Future<String> baby(WidgetTester tester) async => (await tester.runAsync(
    () => db.addProfile(
      'ليلى',
      sex: 'female',
      birthDate: DateTime(2026, 3, 1),
      allergies: 'بيض',
      conditions: 'أنيميا',
      bloodType: 'O+',
    ),
  ))!;

  Future<String> grandfather(WidgetTester tester) async =>
      (await tester.runAsync(() async {
        final id = await db.addProfile(
          'محمود',
          sex: 'male',
          birthDate: DateTime(1958, 2, 1),
          allergies: 'بنسلين',
          conditions: 'ضغط، سكر',
          bloodType: 'O+',
        );
        await db.saveMedicine(
          profileId: id,
          name: 'Concor',
          strength: '5 mg',
          startOn: DateTime(2026, 1, 1),
          schedule: const DoseScheduleInput(times: ['20:00'], amount: 'حباية'),
        );
        // Finished last month: not a current medicine.
        await db.saveMedicine(
          profileId: id,
          name: 'Augmentin',
          startOn: DateTime(2026, 9, 1),
          endOn: DateTime(2026, 9, 7),
          schedule: const DoseScheduleInput(times: ['08:00']),
        );
        return id;
      }))!;

  group('Person', () {
    testWidgets('a child\'s page: name once, age, everything reachable', (
      tester,
    ) async {
      phone(tester);
      final id = await baby(tester);
      await tester.pumpWidget(app());
      await settleDb(tester);
      await open(tester, '/family/$id');

      expect(find.text('ليلى'), findsOneWidget);
      expect(find.text('٨ شهور'), findsOneWidget);
      // Its own actions and back, as designed: no tab bar.
      expect(find.byType(UsraBottomBar), findsNothing);
      expect(find.byKey(const ValueKey('member-doctor-summary')), findsOne);
      expect(find.text('إضافة لليلى'), findsOneWidget);

      // Add opens on this person.
      await tester.tap(find.byKey(const ValueKey('person-add')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<UsraPill>(find.byKey(ValueKey('add-person-$id')))
            .selected,
        isTrue,
      );
      Navigator.of(tester.element(find.byKey(ValueKey('add-person-$id'))))
          .pop();
      await tester.pumpAndSettle();

      for (final key in [
        'open-emergency',
        'member-edit',
        'member-vaccines',
        'member-growth',
        'member-visits',
        'member-insurance',
        'member-medicines',
        'member-sick-days',
        'member-development',
        'member-baby-log',
        'member-documents',
        'member-spending',
        'add-record',
      ]) {
        final f = find.byKey(ValueKey(key));
        await tester.scrollUntilVisible(
          f,
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(f, findsOneWidget, reason: key);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the tab bar comes back on the pages around it', (
      tester,
    ) async {
      phone(tester);
      final id = await grandfather(tester);
      await tester.pumpWidget(app());
      await settleDb(tester);
      expect(find.byType(UsraBottomBar), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('home-person-$id')));
      await settleDb(tester);
      expect(find.byType(UsraBottomBar), findsNothing);

      await tapKey(tester, 'member-visits');
      expect(find.byType(UsraBottomBar), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await settleDb(tester);
      expect(find.byType(UsraBottomBar), findsNothing);

      await tester.tap(find.byKey(const ValueKey('member-back')));
      await settleDb(tester);
      expect(find.byKey(const ValueKey('home-greeting')), findsOneWidget);
      expect(find.byType(UsraBottomBar), findsOneWidget);
    });

    testWidgets(
      'a grown-up has no child or pregnancy tiles, and no empty age',
      (tester) async {
        phone(tester);
        final id = (await tester.runAsync(
          () => db.addProfile('سعاد', sex: 'male'),
        ))!;
        await tester.pumpWidget(app());
        await settleDb(tester);
        await open(tester, '/family/$id');

        expect(find.byKey(const ValueKey('member-details')), findsNothing);
        expect(find.byKey(const ValueKey('member-vaccines')), findsNothing);
        expect(find.byKey(const ValueKey('member-growth')), findsNothing);
        expect(find.byKey(const ValueKey('member-baby-log')), findsNothing);
        expect(find.byKey(const ValueKey('member-pregnancy')), findsNothing);
        // Nothing recorded and nothing due: quiet, never "all is well".
        expect(find.byKey(const ValueKey('person-recorded')), findsNothing);
        expect(
          find.byKey(const ValueKey('person-vaccine-overdue')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('person-next-dose')), findsNothing);
        expect(find.text('مفيش حاجة مطلوبة'), findsNothing);
      },
    );

    testWidgets(
      'allergies and conditions stay in view, as the family\'s words',
      (tester) async {
        phone(tester);
        final id = await baby(tester);
        await tester.pumpWidget(app());
        await settleDb(tester);
        await open(tester, '/family/$id');

        final recorded = find.byKey(const ValueKey('person-recorded'));
        await reveal(tester, recorded);
        await tester.pumpAndSettle();
        Finder inside(String text) =>
            find.descendant(of: recorded, matching: find.textContaining(text));
        expect(inside('اللي العيلة سجّلته'), findsOneWidget);
        expect(inside('بيض'), findsOneWidget);
        expect(inside('أنيميا'), findsOneWidget);
      },
    );

    testWidgets('an overdue vaccine names its source and can be logged there', (
      tester,
    ) async {
      phone(tester);
      final id = await baby(tester);
      await tester.pumpWidget(app());
      await settleDb(tester);
      await open(tester, '/family/$id');

      final card = find.byKey(const ValueKey('person-vaccine-overdue'));
      expect(card, findsOneWidget);
      // A dot row in the one "needs attention" card; sections are a list.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('person-attention')),
          matching: card,
        ),
        findsOneWidget,
      );
      // What the app concludes shows its reference and the date it was checked.
      final source = tester.widget<Text>(
        find.byKey(const ValueKey('person-vaccine-source')),
      );
      expect(source.data, contains('جدول التطعيمات في مصر'));
      expect(source.data, contains('اتراجع'));
      expect(source.data, contains('٢٠٢٦'));
      await reveal(tester, find.byKey(const ValueKey('person-sections')));
      expect(find.byKey(const ValueKey('person-sections')), findsOneWidget);
      // Back up to the attention card.
      await reveal(
        tester,
        find.byKey(const ValueKey('person-vaccine-log')),
        delta: -200,
      );

      await tapKey(tester, 'person-vaccine-log');
      // Opened to log it: "given" is already on, and it says whose it is.
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const ValueKey('dose-given')))
            .value,
        isTrue,
      );
      expect(find.textContaining('ليلى –'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('dose-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dose-save')));
      await settleDb(tester);

      final events = (await tester.runAsync(() => db.watchTimeline(id).first))!;
      final logged = events.where((e) => e.type == 'vaccine').single;
      // Logged without a date: taken as given on its day on the schedule
      // (the birth dose, at birth), never today.
      expect(
        DateTime(
          logged.occurredAt.year,
          logged.occurredAt.month,
          logged.occurredAt.day,
        ),
        DateTime(2026, 3, 1),
      );
    });

    testWidgets('the next dose: Taken in one tap, and Undo', (tester) async {
      phone(tester);
      final id = await grandfather(tester);
      await tester.pumpWidget(app());
      await settleDb(tester);
      await open(tester, '/family/$id');

      final doseCard = find.byKey(const ValueKey('person-next-dose'));
      expect(doseCard, findsOneWidget);
      expect(
        find.descendant(of: doseCard, matching: find.text('Concor 5 mg')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: doseCard, matching: find.textContaining('حباية')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('person-dose-taken')));
      await settleDb(tester);
      Future<List<DoseLog>> logs() async => (await tester.runAsync(
        () => db
            .watchDoseLogs(
              from: DateTime(2026, 11, 3).toUtc(),
              to: DateTime(2026, 11, 4).toUtc(),
            )
            .first,
      ))!;
      expect(await logs(), hasLength(1));
      expect(doseCard, findsNothing);

      await tester.tap(find.text('تراجع'));
      await settleDb(tester);
      expect(await logs(), isEmpty);
      expect(doseCard, findsOneWidget);
    });

    testWidgets('an expired insurance card asks for attention', (tester) async {
      phone(tester);
      late String id;
      late String card;
      await tester.runAsync(() async {
        id = await db.addProfile('محمود', sex: 'male');
        card = await db.saveInsuranceCard(
          profileId: id,
          label: 'نقابة',
          expiresOn: DateTime.utc(2020),
        );
      });
      await tester.pumpWidget(app());
      await settleDb(tester);
      await open(tester, '/family/$id');
      expect(find.byKey(ValueKey('person-insurance-$card')), findsOneWidget);
      expect(find.text('نقابة'), findsOneWidget);
    });

    testWidgets('tile dates from another year say the year', (tester) async {
      phone(tester);
      final id = (await tester.runAsync(() async {
        final id = await db.addProfile('محمود', sex: 'male');
        await db.addEvent(
          profileId: id,
          type: 'visit',
          occurredAt: DateTime(2023, 3, 3),
          dataJson: '{"doctorName":"د. سارة"}',
        );
        return id;
      }))!;
      await tester.pumpWidget(app());
      await settleDb(tester);
      await open(tester, '/family/$id');
      final tile = find.byKey(const ValueKey('member-visits'));
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: tile, matching: find.textContaining('٢٠٢٣')),
        findsOneWidget,
      );
    });

    testWidgets('a dose past its time shows as missed', (tester) async {
      phone(tester);
      final id = (await tester.runAsync(() async {
        final id = await db.addProfile('محمود', sex: 'male');
        await db.saveMedicine(
          profileId: id,
          name: 'Concor',
          startOn: DateTime(2026, 1, 1),
          schedule: const DoseScheduleInput(times: ['08:00']),
        );
        return id;
      }))!;
      await tester.pumpWidget(app());
      await settleDb(tester);
      await open(tester, '/family/$id');
      expect(find.text('دوا فات'), findsOneWidget);
    });

    testWidgets('visits and labs, documents, insurance and follow-ups open', (
      tester,
    ) async {
      phone(tester);
      final id = (await tester.runAsync(() async {
        final id = await db.addProfile('محمود', sex: 'male');
        await db.addEvent(
          profileId: id,
          type: 'visit',
          occurredAt: DateTime(2026, 10, 20),
          dataJson: '{"doctorName":"د. سارة"}',
        );
        return id;
      }))!;
      await tester.pumpWidget(app());
      await settleDb(tester);
      await open(tester, '/family/$id');

      await tapKey(tester, 'member-visits');
      expect(find.byKey(const ValueKey('member-labs')), findsOneWidget);
      expect(find.textContaining('د. سارة'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await settleDb(tester);

      await tapKey(tester, 'member-documents');
      expect(find.text('لسه مفيش سجلات فيها صور.'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await settleDb(tester);

      await tapKey(tester, 'member-insurance');
      expect(find.byKey(const ValueKey('insurance-add')), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await settleDb(tester);
    });

    testWidgets('no overflow at 320 px with 200% text', (tester) async {
      phone(tester);
      final id = await baby(tester);
      await tester.pumpWidget(app());
      await settleDb(tester);
      await open(tester, '/family/$id');
      phone(tester, width: 320, height: 568);
      largeText(tester);
      await settleDb(tester);
      expect(tester.takeException(), isNull);
      // The buttons scroll with the page, so they don't take the whole screen.
      await tester.ensureVisible(find.byKey(const ValueKey('person-add')));
      expect(find.byKey(const ValueKey('add-record')), findsNothing);
      await tester.drag(find.byType(ListView).first, const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow in English, dark, or Simple Mode at 320 px', (
      tester,
    ) async {
      // Opened at a normal size, so only this page is measured at 320 px.
      phone(tester);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final id = await baby(tester);
      await tester.pumpWidget(app(prefs: const {PrefKeys.simpleMode: true}));
      await settleDb(tester);
      await open(tester, '/family/$id');
      phone(tester, width: 320, height: 568);
      await settleDb(tester);
      expect(tester.takeException(), isNull);
      // No spending charts in Simple Mode.
      expect(find.byKey(const ValueKey('member-spending')), findsNothing);
      // Its big bottom buttons stay.
      expect(find.byType(NavigationBar), findsOneWidget);
      // The stacked buttons leave room for the page.
      await settleDb(tester);
      phone(tester);
      await settleDb(tester);
      expect(
        tester.getSize(find.byType(ListView).first).height,
        greaterThan(300),
      );
      phone(tester, width: 320, height: 568);
      await settleDb(tester);
      expect(
        tester.getSize(find.byKey(const ValueKey('person-add'))).height,
        greaterThanOrEqualTo(64),
      );

      await tester.pumpWidget(Container());
      phone(tester);
      await tester.pumpWidget(app());
      await settleDb(tester);
      ProviderScope.containerOf(tester.element(find.byType(UsraApp)))
          .read(localeProvider.notifier)
          .change(const Locale('en'));
      await settleDb(tester);
      await open(tester, '/family/$id');
      phone(tester, width: 320, height: 568);
      await settleDb(tester);
      expect(find.text('Add for ليلى'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('relationship and emergency contact on the person', () {
    testWidgets(
      'the person form saves them and the page shows the relationship',
      (tester) async {
        phone(tester, height: 2000);
        final id = (await tester.runAsync(
          () => db.addProfile('ليلى', birthDate: DateTime(2026, 3, 2)),
        ))!;
        await tester.pumpWidget(app());
        await settleDb(tester);
        await open(tester, '/family/$id/edit');
        await tester.tap(
          find.byKey(const ValueKey('profile-relationship-daughter')),
        );
        await tester.pump();
        await tester.enterText(
          find.byKey(const ValueKey('profile-emergency-phone')),
          '010 1234 5678',
        );
        await tester.enterText(
          find.byKey(const ValueKey('profile-emergency-name')),
          'آية، مامتها',
        );
        await tester.tap(find.byKey(const ValueKey('profile-save')));
        await settleDb(tester);
        final saved = (await tester.runAsync(() => db.watchProfile(id).first))!;
        expect(saved.relationship, 'daughter');
        expect(saved.emergencyPhone, '010 1234 5678');
        expect(saved.emergencyContactName, 'آية، مامتها');
        expect(find.textContaining('بنتك'), findsOneWidget);

        // Opening it again shows what's saved, and tapping again clears it.
        await open(tester, '/family/$id/edit');
        await tester.tap(
          find.byKey(const ValueKey('profile-relationship-daughter')),
        );
        await tester.pump();
        await tester.enterText(
          find.byKey(const ValueKey('profile-emergency-phone')),
          '',
        );
        await tester.tap(find.byKey(const ValueKey('profile-save')));
        await settleDb(tester);
        final cleared = (await tester.runAsync(
          () => db.watchProfile(id).first,
        ))!;
        expect(cleared.relationship, isNull);
        expect(cleared.emergencyPhone, isNull);
        expect(cleared.emergencyContactName, 'آية، مامتها');
        expect(find.textContaining('بنتك'), findsNothing);
      },
    );

    test('what counts as a number that can be called', () {
      for (final good in [
        '123',
        '16000',
        '010 1234 5678',
        '٠١٠-١٢٣٤-٥٦٧٨',
        '+20 10 1234 5678',
        '(02) 2345 6789',
        '\u202a+20 10 1234\u202c',
      ]) {
        expect(isCallablePhone(good), isTrue, reason: good);
      }
      for (final bad in ['ماما', 'ماما 1', 'فودافون 2', '5', '12', '']) {
        expect(isCallablePhone(bad), isFalse, reason: bad);
      }
      // A + pasted behind an invisible mark or a bracket isn't lost.
      expect(cleanPhone('\u202a+20 10 1234'), '+20101234');
      expect(cleanPhone('(+20) 10 1234'), '+20101234');
      expect(cleanPhone('0020 10'), '002010');
    });

    testWidgets('a number with no digits isn\'t saved', (tester) async {
      phone(tester, height: 2000);
      final id = (await tester.runAsync(() => db.addProfile('ليلى')))!;
      await tester.pumpWidget(app());
      await settleDb(tester);
      await open(tester, '/family/$id/edit');
      await tester.enterText(
        find.byKey(const ValueKey('profile-emergency-phone')),
        'ماما',
      );
      await tester.tap(find.byKey(const ValueKey('profile-save')));
      await settleDb(tester);
      expect(find.text('ده مش رقم تليفون.'), findsOneWidget);
      final saved = (await tester.runAsync(() => db.watchProfile(id).first))!;
      expect(saved.emergencyPhone, isNull);
    });

    testWidgets('the person using the app isn\'t asked how they\'re related', (
      tester,
    ) async {
      phone(tester, height: 2000);
      final id = (await tester.runAsync(() => db.addProfile('آية')))!;
      await tester.pumpWidget(app(prefs: {PrefKeys.meProfileId: id}));
      await settleDb(tester);
      await open(tester, '/family/$id/edit');
      expect(
        find.byKey(const ValueKey('profile-relationship-son')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('profile-emergency-phone')),
        findsOneWidget,
      );
    });

    test('every relationship has words, in both languages', () {
      for (final code in ['ar', 'en']) {
        final l = lookupAppLocalizations(Locale(code));
        for (final r in relationships) {
          expect(l.relationshipMine(r), isNotEmpty, reason: '$code $r');
          if (r != 'other') {
            expect(l.relationshipYours(r), isNotEmpty, reason: '$code $r');
          }
        }
        expect(l.relationshipYours('other'), isEmpty);
      }
    });
  });

  group('Emergency', () {
    testWidgets('the number and whose it is show at the top, and it calls', (
      tester,
    ) async {
      final id = (await tester.runAsync(
        () => db.addProfile(
          'ليلى',
          emergencyPhone: '٠١٠ ١٢٣٤ ٥٦٧٨',
          emergencyContactName: 'آية، مامتها',
        ),
      ))!;
      phone(tester);
      await tester.pumpWidget(app());
      await settleDb(tester);
      await open(tester, '/family/$id/emergency');
      expect(find.text('آية، مامتها'), findsOneWidget);
      expect(find.text('٠١٠ ١٢٣٤ ٥٦٧٨'), findsOneWidget);
      // Above the facts.
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('emergency-contact'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('emergency-card'))).dy,
        ),
      );
      expect(callUri('٠١٠ ١٢٣٤ ٥٦٧٨').toString(), 'tel:01012345678');
      // A screen reader hears who and the number, and can act on it.
      final handle = tester.ensureSemantics();
      final node = tester.getSemantics(
        find.byKey(const ValueKey('emergency-contact')),
      );
      expect(node.label, contains('آية، مامتها'));
      expect(node.label, contains('٠١٠ ١٢٣٤ ٥٦٧٨'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();

      // A tap goes to the dialer; none here, so it says so.
      await tester.tap(find.byKey(const ValueKey('emergency-contact')));
      await settleDb(tester);
      expect(find.text(ar.contactFailed), findsOneWidget);
    });

    testWidgets('a number with no name still shows; no number shows nothing', (
      tester,
    ) async {
      final (withNumber, without) = (await tester.runAsync(
        () async => (
          await db.addProfile('ليلى', emergencyPhone: '0101234'),
          await db.addProfile('يوسف'),
        ),
      ))!;
      phone(tester);
      await tester.pumpWidget(app());
      await settleDb(tester);
      await open(tester, '/family/$withNumber/emergency');
      expect(find.text('رقم للطوارئ'), findsOneWidget);
      // It follows the card when it's handed to someone in the other language.
      await tester.tap(find.byKey(const ValueKey('emergency-language')));
      await settleDb(tester);
      expect(find.text('Emergency number'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('emergency-language')));
      await settleDb(tester);
      await open(tester, '/family/$without/emergency');
      expect(find.byKey(const ValueKey('emergency-contact')), findsNothing);
    });

    testWidgets('the call comes first, then what a paramedic needs', (
      tester,
    ) async {
      phone(tester);
      final id = await grandfather(tester);
      await tester.pumpWidget(app());
      await settleDb(tester);
      await open(tester, '/family/$id/emergency');

      final ambulance = find.byKey(const ValueKey('emergency-ambulance'));
      expect(find.text('الإسعاف ١٢٣'), findsOneWidget);
      expect(tester.getSize(ambulance).height, greaterThanOrEqualTo(72));
      // Red stays for the emergency call, whatever the polish does elsewhere.
      final button = tester.widget<ButtonStyleButton>(ambulance);
      expect(
        button.style?.backgroundColor?.resolve(const {}),
        tester.element(ambulance).usra.urgent,
      );
      expect(
        tester.getTopLeft(ambulance).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('emergency-allergies')))
              .dy,
        ),
      );

      expect(find.text('بنسلين'), findsOneWidget);
      expect(find.text('O+'), findsOneWidget);
      expect(find.text('ضغط، سكر'), findsOneWidget);
      expect(find.text('٦٨ سنة – ذكر'), findsOneWidget);
      // Current medicines only, in their own direction.
      final medicine = find.text('Concor 5 mg');
      expect(medicine, findsOneWidget);
      expect(tester.widget<Text>(medicine).textDirection, TextDirection.ltr);
      expect(find.textContaining('Augmentin'), findsNothing);
      // Never here.
      expect(find.byType(DrUsra), findsNothing);
      // Keeps its focus: no tab bar.
      expect(find.byType(UsraBottomBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('English view: labels and direction change, typed words stay, '
        'and it survives switching person', (tester) async {
      phone(tester);
      final id = await grandfather(tester);
      final other = await baby(tester);
      await tester.pumpWidget(app());
      await settleDb(tester);
      await open(tester, '/family/$id/emergency');

      expect(find.text('حساسية'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('emergency-language')));
      await settleDb(tester);

      expect(find.text('Allergies'), findsOneWidget);
      expect(find.text('Blood type'), findsOneWidget);
      expect(find.text('Current medicines'), findsOneWidget);
      expect(find.text('68 years – Male'), findsOneWidget);
      expect(find.text('بنسلين'), findsOneWidget);
      expect(find.byKey(const ValueKey('emergency-as-typed')), findsOneWidget);
      expect(find.text('عربي'), findsOneWidget);
      // Only the card: the screen's title stays in the app's language.
      expect(find.text('كارت الطوارئ'), findsOneWidget);
      expect(
        Directionality.of(
          tester.element(find.byKey(const ValueKey('emergency-blood'))),
        ),
        TextDirection.ltr,
      );

      await tester.tap(find.byKey(ValueKey('emergency-person-$other')));
      await settleDb(tester);
      expect(find.text('Allergies'), findsOneWidget);
      expect(find.text('بيض'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('emergency-language')));
      await settleDb(tester);
      expect(find.text('حساسية'), findsOneWidget);
    });

    testWidgets(
      'without the app lock: no switch, just the Medical ID pointer',
      (tester) async {
        phone(tester);
        final id = await grandfather(tester);
        await tester.pumpWidget(app());
        await settleDb(tester);
        await open(tester, '/family/$id/emergency');

        expect(
          find.byKey(const ValueKey('emergency-lock-switch')),
          findsNothing,
        );
        final pointer = find.byKey(const ValueKey('emergency-medical-id'));
        await tester.ensureVisible(pointer);
        expect(tester.widget<Text>(pointer).data, contains('Medical ID'));
        expect(tester.widget<Text>(pointer).data, contains('قفل أسرة'));
      },
    );

    testWidgets('showing on Usra\'s lock screen confirms, then asks the PIN', (
      tester,
    ) async {
      phone(tester, height: 1200);
      final store = MemoryLockStore();
      final clocks = FakeClocks();
      final lock = (await tester.runAsync(() async {
        final lock = await AppLock.open(
          store: store,
          hasher: fastHasher,
          biometrics: FakeBiometrics(),
          clock: clocks.wall,
          ticks: clocks.ticks,
          uptime: clocks,
        );
        await lock.enable('730184', biometrics: false);
        return lock;
      }))!;
      final id = await grandfather(tester);
      await tester.pumpWidget(app(lock: lock));
      await settleDb(tester);
      await open(tester, '/family/$id/emergency');

      final toggle = find.byKey(const ValueKey('emergency-lock-switch'));
      expect(find.text('إظهاره على قفل أسرة'), findsOneWidget);

      // Saying no leaves it off, without the PIN.
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('emergency-lock-confirm')),
        findsOneWidget,
      );
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(lock.emergencyProfiles, isEmpty);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('emergency-lock-yes')));
      await tester.pumpAndSettle();
      for (final d in '730184'.split('')) {
        await tester.tap(find.byKey(ValueKey('pin-$d')));
        await tester.pump();
      }
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      expect(lock.emergencyProfiles, {id});
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);

      // Turning it off needs nothing more.
      await tester.tap(toggle);
      await settleDb(tester);
      expect(lock.emergencyProfiles, isEmpty);
    });

    testWidgets('no overflow at 320 px with 200% text, Arabic and English', (
      tester,
    ) async {
      phone(tester);
      final id = await grandfather(tester);
      await baby(tester);
      await tester.pumpWidget(app());
      await settleDb(tester);
      await open(tester, '/family/$id/emergency');
      phone(tester, width: 320, height: 568);
      largeText(tester);
      await settleDb(tester);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(
        find.byKey(const ValueKey('emergency-language')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('emergency-language')));
      await settleDb(tester);
      await tester.drag(find.byType(ListView).first, const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
