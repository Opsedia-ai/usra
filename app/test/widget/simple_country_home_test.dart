import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/features/medicines/medicines_providers.dart';
import 'package:usra/features/onboarding/onboarding_chrome.dart';
import 'package:usra/features/medicines/reminders.dart';

import '../support/fake_reminder_scheduler.dart';
import '../support/fits.dart';
import '../support/screen_harness.dart';

void main() {
  late ScreenHarness h;
  late FakeReminderScheduler scheduler;

  setUp(() {
    scheduler = FakeReminderScheduler(
      granted: const ReminderAccess(notifications: false),
    )..afterRequest = const ReminderAccess(notifications: true);
    h = ScreenHarness()
      ..overrides = [reminderSchedulerProvider.overrideWithValue(scheduler)];
  });
  tearDown(() => h.dispose());

  Finder key(String k) => find.byKey(ValueKey(k));

  Future<String> seedSimple(
    WidgetTester tester, {
    List<(String, String)> medicines = const [],
  }) async {
    await h.prefs.setBool(PrefKeys.simpleMode, true);
    return (await tester.runAsync(() async {
      final id = await h.db.addProfile(
        'محمود',
        sex: 'male',
        birthDate: DateTime(1950, 1, 1),
      );
      await h.db.updateProfile(id, displayName: 'محمود', simpleMode: true);
      for (final (name, time) in medicines) {
        await h.db.saveMedicine(
          profileId: id,
          name: name,
          startOn: DateTime(2026, 1, 1),
          schedule: DoseScheduleInput(times: [time]),
        );
      }
      return id;
    }))!;
  }

  group('Simple Mode', () {
    testWidgets('no doses: says so, and keeps the emergency button', (
      tester,
    ) async {
      h.tall(tester);
      await seedSimple(tester);
      await h.open(tester, '/home');
      expect(key('simple-no-doses'), findsOneWidget);
      expect(key('simple-emergency'), findsOneWidget);
    });

    testWidgets('several doses at one time each get a button, then the next', (
      tester,
    ) async {
      h.tall(tester);
      await seedSimple(
        tester,
        medicines: [
          ('Concor', '00:01'),
          ('Aspirin', '00:01'),
          ('Late', '23:59'),
        ],
      );
      await h.open(tester, '/home');
      expect(key('simple-doses'), findsOneWidget);
      expect(
        find.descendant(of: key('simple-doses'), matching: find.text('اتاخد')),
        findsNWidgets(2),
      );
      expect(find.textContaining('وبعده: Late'), findsOneWidget);
      // As wide as the big buttons under it.
      final card = find.descendant(
        of: key('simple-doses'),
        matching: find.byType(Card),
      );
      expect(
        tester.getSize(card.first).width,
        tester.getSize(key('simple-medicines')).width,
      );
    });

    testWidgets('a dose missed earlier doesn\'t hide the one that\'s due', (
      tester,
    ) async {
      h.tall(tester);
      final hour = DateTime.now().hour;
      // Only meaningful with room for a missed dose before now.
      if (hour < 4) return;
      String at(int h) => '${h.toString().padLeft(2, '0')}:00';
      await seedSimple(
        tester,
        medicines: [('Old', at(hour - 3)), ('Current', at(hour))],
      );
      await h.open(tester, '/home');
      expect(
        find.descendant(
          of: key('simple-doses'),
          matching: find.textContaining('Current'),
        ),
        findsWidgets,
      );
      expect(find.textContaining('وبعده: Current'), findsNothing);
    });

    testWidgets('leaving asks first; staying changes nothing', (tester) async {
      h.tall(tester);
      await seedSimple(tester);
      await h.open(tester, '/home');
      await h.tapKey(tester, 'simple-exit');
      expect(key('simple-exit-confirm'), findsOneWidget);
      await h.tapKey(tester, 'simple-exit-stay');
      expect(key('simple-no-doses'), findsOneWidget);
      await h.tapKey(tester, 'simple-exit');
      await h.tapKey(tester, 'simple-exit-go');
      expect(key('simple-no-doses'), findsNothing);
      expect(h.prefs.getBool(PrefKeys.simpleMode), isFalse);
    });

    testWidgets('settings can\'t get round the question', (tester) async {
      h.tall(tester);
      await seedSimple(tester);
      await h.open(tester, '/settings');
      await h.tapKey(tester, 'settings-simple-mode');
      expect(key('simple-exit-confirm'), findsOneWidget);
      await h.tapKey(tester, 'simple-exit-stay');
      expect(h.prefs.getBool(PrefKeys.simpleMode), isTrue);
    });
  });

  group('Language and country', () {
    testWidgets('Saudi Arabia and Jordan say soon and stay disabled', (
      tester,
    ) async {
      h.tall(tester);
      await h.prefs.setBool(PrefKeys.tutorialSeen, false);
      await h.open(tester, '/welcome/country');
      for (final other in ['country-saudi', 'country-jordan']) {
        final card = tester.widget<ChoiceCard>(key(other));
        expect(card.onTap, isNull);
        expect(card.detail, 'قريب');
      }
      expect(key('country-soon-note'), findsOneWidget);
      await h.tapKey(tester, 'country-lang-en');
      expect(
        tester.widget<ChoiceCard>(key('country-saudi')).detail,
        'Coming soon',
      );
      await h.tapKey(tester, 'country-next');
      expect(h.prefs.getString(PrefKeys.country), 'EG');
    });
  });

  group('New family Home', () {
    Future<String> seedOwner(WidgetTester tester) async =>
        (await tester.runAsync(
          () => h.db.addProfile(
            'آية',
            sex: 'female',
            birthDate: DateTime(1990, 1, 1),
          ),
        ))!;

    testWidgets('offers what isn\'t done, optional, and can be hidden', (
      tester,
    ) async {
      h.tall(tester);
      await seedOwner(tester);
      await h.open(tester, '/home');
      for (final card in const [
        'setup-family',
        'setup-reminders',
        'setup-emergency',
      ]) {
        expect(key(card), findsOneWidget, reason: card);
      }
      // Nothing asked for until the card is tapped.
      expect(scheduler.requests, 0);
      await h.tapKey(tester, 'setup-reminders');
      expect(scheduler.requests, 1);
      expect(key('setup-reminders'), findsNothing);

      await h.tapKey(tester, 'setup-hide');
      expect(key('home-setup'), findsNothing);
      expect(h.prefs.getBool('homeSetupHidden'), isTrue);
    });

    testWidgets('a card leaves when it\'s done', (tester) async {
      h.tall(tester);
      final id = await seedOwner(tester);
      await tester.runAsync(() async {
        await h.db.addProfile('ليلى', sex: 'female');
        await h.db.updateProfile(id, displayName: 'آية', bloodType: 'O+');
      });
      await h.open(tester, '/home');
      expect(key('setup-family'), findsNothing);
      expect(key('setup-emergency'), findsNothing);
      // The backup is asked for by Home's own notice, not twice.
      expect(key('backup-due'), findsOneWidget);
      expect(key('setup-backup'), findsNothing);
    });
  });

  group('fits 320 px at double text', () {
    forEachSmallLayout(() => h, (tester) async {
      await seedSimple(
        tester,
        medicines: [('Concor', '00:01'), ('Late', '23:59')],
      );
      await h.open(tester, '/home');
      await walkScreen(tester);
    });

    group('country', () {
      forEachSmallLayout(() => h, (tester) async {
        await h.prefs.setBool(PrefKeys.tutorialSeen, false);
        await h.open(tester, '/welcome/country');
        expect(key('country-egypt'), findsOneWidget);
        await walkScreen(tester);
      });
    });

    group('welcome', () {
      forEachSmallLayout(() => h, (tester) async {
        await h.prefs.setBool(PrefKeys.tutorialSeen, false);
        await h.open(tester, '/welcome');
        expect(key('welcome-start'), findsOneWidget);
        await walkScreen(tester);
      });
    });

    group('about you', () {
      forEachSmallLayout(() => h, (tester) async {
        await h.prefs.setBool(PrefKeys.tutorialSeen, false);
        await h.open(tester, '/welcome/country/about');
        expect(key('about-sex-female'), findsOneWidget);
        await walkScreen(tester);
      });
    });

    testWidgets('new family Home', (tester) async {
      smallPhoneDoubleText(tester);
      await tester.runAsync(
        () => h.db.addProfile(
          'آية',
          sex: 'female',
          birthDate: DateTime(1990, 1, 1),
        ),
      );
      await h.open(tester, '/home');
      await walkScreen(tester);
    });
  });
}
