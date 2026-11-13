import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/app.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/design/bottom_bar.dart';
import 'package:usra/core/design/dr_usra.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/core/routing/app_router.dart';
import 'package:usra/core/backup/backup_service.dart';
import 'package:usra/features/backup/backup_providers.dart';
import 'package:usra/features/backup/backup_screen.dart';
import 'package:usra/features/onboarding/onboarding_chrome.dart';
import 'package:usra/features/settings/about_privacy_screen.dart';
import 'package:usra/l10n/app_localizations.dart';

void main() {
  late AppDatabase db;
  late MemoryKeyValueStore store;
  late List<Uri> opened;
  final evening = DateTime(2026, 11, 7, 19);

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    store = MemoryKeyValueStore();
    opened = [];
  });
  tearDown(() => db.close());

  // A new scope each time is like opening the app again.
  Widget app() => ProviderScope(
    key: UniqueKey(),
    overrides: [
      databaseProvider.overrideWithValue(db),
      keyValueStoreProvider.overrideWithValue(store),
      clockProvider.overrideWithValue(() => evening),
      backupServiceProvider.overrideWithValue(_NoBackupService()),
      openLinkProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return true;
      }),
    ],
    child: const UsraApp(),
  );

  void phone(WidgetTester tester, {double width = 390, double height = 844}) {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = Size(width * 2, height * 2);
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(key)));
    await settle(tester);
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  /// Opens the date picker on About you and takes what it starts on: 1990.
  Future<void> pickBirthDate(WidgetTester tester) async {
    await tapKey(tester, 'about-birthDate');
    await tester.tap(
      find
          .descendant(
            of: find.byType(DatePickerDialog),
            matching: find.byType(TextButton),
          )
          .last,
    );
    await settle(tester);
  }

  void go(WidgetTester tester, String path) =>
      ProviderScope.containerOf(tester.element(find.byType(Navigator).first))
          .read(routerProvider)
          .go(path);

  testWidgets('first run: Welcome, country, About you, then Home with the name '
      'in the greeting, and no tour or lock offer on the way', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await settle(tester);

    expect(key('welcome-headline'), findsOneWidget);
    expect(find.byType(DrUsra), findsOneWidget);
    expect(find.byType(UsraBottomBar), findsNothing);
    expect(key('tutorial-step'), findsNothing);
    expect(store.getBool(PrefKeys.tutorialSeen), isNull);

    // Every page leads here until the first run is done.
    go(tester, '/settings');
    await settle(tester);
    expect(key('welcome-headline'), findsOneWidget);

    await tapKey(tester, 'welcome-start');
    expect(key('country-egypt'), findsOneWidget);
    // Only Egypt can be chosen: the ambulance number is Egypt's everywhere.
    for (final other in ['country-saudi', 'country-jordan']) {
      expect(tester.widget<ChoiceCard>(key(other)).onTap, isNull);
    }
    await tapKey(tester, 'country-next');
    expect(store.getString(PrefKeys.country), 'EG');

    // Name, date of birth and sex are all needed, and sex isn't chosen for
    // anyone.
    await tapKey(tester, 'about-done');
    expect(key('about-sex-missing'), findsOneWidget);
    expect(find.text('مطلوب'), findsNWidgets(3));
    await tester.enterText(key('about-name'), 'آية');
    await tapKey(tester, 'about-done');
    expect(key('about-sex-missing'), findsOneWidget);
    expect((await tester.runAsync(() => db.watchProfiles().first))!, isEmpty);
    await tapKey(tester, 'about-sex-female');
    await tapKey(tester, 'about-done');
    // Name and sex alone aren't enough.
    expect(find.text('مطلوب'), findsOneWidget);
    expect((await tester.runAsync(() => db.watchProfiles().first))!, isEmpty);
    await pickBirthDate(tester);
    await tapKey(tester, 'about-done');

    final people = (await tester.runAsync(() => db.watchProfiles().first))!;
    expect(people.single.displayName, 'آية');
    expect(people.single.sex, 'female');
    expect(people.single.birthDate, DateTime(1990));
    expect(store.getString(PrefKeys.meProfileId), people.single.id);
    expect(store.getBool(PrefKeys.tutorialSeen), isTrue);
    expect(store.getBool(PrefKeys.appLockOffered), isNull);
    expect(key('app-lock-offer'), findsNothing);
    expect(find.byType(UsraBottomBar), findsOneWidget);
    expect(find.text('مساء الخير يا آية'), findsOneWidget);

    // Opening the app again goes straight Home.
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.text('مساء الخير يا آية'), findsOneWidget);
    expect(key('welcome-headline'), findsNothing);
  });

  group('date of birth in About you', () {
    Future<void> toAboutYou(WidgetTester tester) async {
      phone(tester);
      await tester.pumpWidget(app());
      await settle(tester);
      await tapKey(tester, 'welcome-start');
      await tapKey(tester, 'country-next');
    }

    testWidgets('the picker offers nothing after today', (tester) async {
      await toAboutYou(tester);
      await tapKey(tester, 'about-birthDate');
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      // The app clock's today (bug 13), not the phone's.
      final today = DateUtils.dateOnly(evening);
      expect(DateUtils.dateOnly(picker.lastDate), today);
      expect(picker.firstDate, DateTime(1900));
    });

    testWidgets('a birth date typed in Arabic digits is kept (bug E)', (
      tester,
    ) async {
      await toAboutYou(tester);
      expect(find.text('اختيار التاريخ'), findsOneWidget);
      await tapKey(tester, 'about-birthDate');
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.byType(TextField),
        ),
        '١٩٩١/٥/١٤',
      );
      await tester.tap(find.text('حسنًا').last);
      await settle(tester);
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(find.text('اختيار التاريخ'), findsNothing);
      expect(find.text('١٤ مايو ١٩٩١'), findsOneWidget);
    });

    testWidgets('a date saved earlier that\'s in the future isn\'t accepted, '
        'and the picker still opens', (tester) async {
      phone(tester);
      final id = (await tester.runAsync(
        () => db.addProfile(
          'آية',
          sex: 'female',
          birthDate: DateTime.now().add(const Duration(days: 30)),
        ),
      ))!;
      await store.setString(PrefKeys.meProfileId, id);
      await tester.pumpWidget(app());
      await settle(tester);
      go(tester, '/welcome/country/about');
      await settle(tester);
      await tapKey(tester, 'about-done');
      expect(
        find.text('تاريخ الميلاد مينفعش يكون في المستقبل.'),
        findsOneWidget,
      );
      expect(store.getBool(PrefKeys.tutorialSeen), isNot(isTrue));

      await pickBirthDate(tester);
      expect(find.text('تاريخ الميلاد مينفعش يكون في المستقبل.'), findsNothing);
      await tapKey(tester, 'about-done');
      expect(store.getBool(PrefKeys.tutorialSeen), isTrue);
      final people = (await tester.runAsync(() => db.watchProfiles().first))!;
      expect(people.single.birthDate, DateTime(1990));
    });

    testWidgets('someone already past the first run isn\'t asked', (
      tester,
    ) async {
      phone(tester);
      await store.setBool(PrefKeys.tutorialSeen, true);
      await tester.runAsync(() => db.addProfile('جدو'));
      await tester.pumpWidget(app());
      await settle(tester);
      expect(key('about-birthDate'), findsNothing);
      expect(key('welcome-headline'), findsNothing);
    });
  });

  testWidgets('going back from About you and again makes one person, not two', (
    tester,
  ) async {
    phone(tester);
    // The app stopped after saving the person, before the first run finished.
    final id = (await tester.runAsync(
      () => db.addProfile(
        'آية',
        sex: 'female',
        birthDate: DateTime(1994, 3, 12),
        allergies: 'بنسلين',
      ),
    ))!;
    await store.setString(PrefKeys.meProfileId, id);
    await tester.pumpWidget(app());
    await settle(tester);
    go(tester, '/welcome/country/about');
    await settle(tester);
    expect(find.text('آية'), findsOneWidget);
    await tester.enterText(key('about-name'), 'آية ناصر');
    await tapKey(tester, 'about-done');
    final people = (await tester.runAsync(() => db.watchProfiles().first))!;
    expect(people.single.displayName, 'آية ناصر');
    // Nothing else recorded about them is lost.
    expect(people.single.birthDate, DateTime(1994, 3, 12));
    expect(people.single.allergies, 'بنسلين');
    expect(find.text('مساء الخير يا آية ناصر'), findsOneWidget);
  });

  testWidgets('the backup button opens restore, outside the tabs, and the '
      'first run carries on if it\'s left', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await settle(tester);
    await tapKey(tester, 'welcome-restore');
    expect(find.byType(RestoreScreen), findsOneWidget);
    expect(find.byType(UsraBottomBar), findsNothing);
    expect(key('restore-pick'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(key('welcome-headline'), findsOneWidget);
  });

  testWidgets('after a restore the first run is over', (tester) async {
    phone(tester);
    final made = DateTime(2026, 10, 1, 12);
    await tester.runAsync(() => db.addProfile('جدو'));
    await rememberRestore(store, made);
    expect(store.getInt(PrefKeys.lastBackupAt), made.millisecondsSinceEpoch);
    await tester.pumpWidget(app());
    await settle(tester);
    expect(key('welcome-headline'), findsNothing);
    expect(find.byType(UsraBottomBar), findsOneWidget);
    // Backups don't carry "me", so the greeting just has no name.
    expect(find.text('مساء الخير'), findsOneWidget);
  });

  testWidgets('a failed restore says so on Welcome', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          keyValueStoreProvider.overrideWithValue(store),
          restoreOutcomeProvider.overrideWithValue(RestoreOutcome.failed),
        ],
        child: const UsraApp(),
      ),
    );
    await settle(tester);
    expect(key('welcome-headline'), findsOneWidget);
    expect(key('restore-outcome'), findsOneWidget);
    expect(key('backup-due'), findsNothing);
  });

  testWidgets('a double tap doesn\'t stack a step twice', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await settle(tester);
    // No frame between them, as with two quick taps.
    await tester.tap(key('welcome-start'));
    await tester.tap(key('welcome-start'));
    await settle(tester);
    await tapKey(tester, 'onboarding-back');
    expect(key('welcome-headline'), findsOneWidget);
  });

  testWidgets('the language pill switches and is remembered', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.text('يلا نبدأ'), findsOneWidget);
    await tapKey(tester, 'welcome-language');
    expect(find.text("Let's start"), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
    expect(store.getString(PrefKeys.language), 'en');

    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.text("Let's start"), findsOneWidget);
    await tapKey(tester, 'welcome-language');
    expect(find.text('يلا نبدأ'), findsOneWidget);
    expect(store.getString(PrefKeys.language), 'ar');
  });

  testWidgets('privacy and terms open, each a 48 px target', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await settle(tester);
    for (final k in [
      'welcome-language',
      'welcome-start',
      'welcome-restore',
      'welcome-privacy',
      'welcome-terms',
    ]) {
      expect(
        tester.getSize(key(k)).height,
        greaterThanOrEqualTo(48),
        reason: k,
      );
      expect(tester.getSize(key(k)).width, greaterThanOrEqualTo(48), reason: k);
    }
    await tapKey(tester, 'welcome-privacy');
    await tapKey(tester, 'welcome-terms');
    expect(opened, [privacyPolicyUrl('ar'), termsUrl('ar')]);
    expect(key('welcome-disclaimer'), findsOneWidget);
  });

  testWidgets('a "me" that was deleted or isn\'t in the family is no name', (
    tester,
  ) async {
    phone(tester);
    await store.setBool(PrefKeys.tutorialSeen, true);
    await store.setString(PrefKeys.meProfileId, 'gone');
    await tester.runAsync(() => db.addProfile('جدو'));
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.text('مساء الخير'), findsOneWidget);
  });

  test('every new setting can be saved, and so deleted with the rest', () {
    // SharedPreferencesWithCache refuses keys outside this list, and
    // "Delete all my data" clears everything in it.
    expect(
      PrefKeys.all,
      containsAll([PrefKeys.meProfileId, PrefKeys.country, PrefKeys.language]),
    );
  });

  test('wording before the sex question stays neutral, and promises nothing '
      'the app doesn\'t do', () {
    final l = lookupAppLocalizations(const Locale('ar'));
    final beforeAnswer = [
      l.welcomeHeadline,
      l.welcomePrivacyLine,
      l.welcomeStart,
      l.welcomeHaveBackup,
      l.welcomeDisclaimer,
      l.countryTitle,
      l.countryHint,
      l.aboutYouTitle,
      l.aboutYouHint,
      l.aboutYouSex,
      l.aboutYouSexHint,
      l.aboutYouDone,
    ].join(' ');
    for (final word in ['عرّفنا', 'إنت', 'تقدر', 'تقدري', 'اختار', 'اختاري']) {
      expect(beforeAnswer, isNot(contains(word)), reason: word);
    }
    for (final promise in ['صورة', 'بنفس الحساب', 'مزامنة', 'طول العمر']) {
      expect(beforeAnswer, isNot(contains(promise)), reason: promise);
    }
  });

  for (final (width, scale, code, dark) in [
    (320.0, 2.0, 'ar', false),
    (320.0, 2.0, 'en', true),
    (430.0, 1.0, 'ar', true),
    (375.0, 1.3, 'en', false),
  ]) {
    testWidgets(
      'every step fits at $width px, text x$scale, $code, dark $dark',
      (tester) async {
        phone(tester, width: width, height: 640);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await store.setString(PrefKeys.language, code);
        await tester.pumpWidget(app());
        await settle(tester);
        expect(tester.takeException(), isNull);
        await tapKey(tester, 'welcome-start');
        expect(tester.takeException(), isNull);
        await tapKey(tester, 'country-next');
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.byKey(const ValueKey('about-name'), skipOffstage: false),
        );
        await tester.pumpAndSettle();
        await tester.enterText(key('about-name'), 'عبد الرحمن محمد عبد العزيز');
        await pickBirthDate(tester);
        expect(tester.takeException(), isNull);
        await tapKey(tester, 'about-sex-male');
        await tapKey(tester, 'about-done');
        // Home with the long name, the greeting and the emergency pill.
        expect(tester.takeException(), isNull);
        expect(key('home-emergency'), findsOneWidget);
        expect(key('home-greeting'), findsOneWidget);
      },
    );
  }

  testWidgets('restore keeps its own back route in the Backup screen too', (
    tester,
  ) async {
    phone(tester);
    await store.setBool(PrefKeys.tutorialSeen, true);
    await tester.pumpWidget(app());
    await settle(tester);
    go(tester, restorePath);
    await settle(tester);
    expect(find.byType(RestoreScreen), findsOneWidget);
    expect(find.byType(UsraBottomBar), findsOneWidget);
  });
}

class _NoBackupService extends Fake implements BackupService {}
