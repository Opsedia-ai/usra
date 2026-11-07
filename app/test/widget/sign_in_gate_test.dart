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
import 'package:usra/features/account/account_providers.dart';
import 'package:usra/features/account/auth_gateway.dart';
import 'package:usra/features/account/device_identity.dart';
import 'package:usra/features/account/login_config.dart';
import 'package:usra/features/account/supabase_config.dart';
import 'package:usra/features/medicines/medicines_providers.dart';

import '../support/fake_auth_gateway.dart';
import '../support/fake_reminder_scheduler.dart';

void main() {
  late AppDatabase db;
  late FakeAuthGateway gateway;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    gateway = FakeAuthGateway();
  });
  tearDown(() => db.close());

  const cloud = SupabaseConfig(
    url: 'https://example.supabase.co',
    anonKey: 'anon',
  );
  const page = ValueKey('sign-in-required-body');
  const name = ValueKey('doctor-name');
  const google = ValueKey('account-sign-in-google');

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
  }

  Future<void> open(
    WidgetTester tester,
    String path, {
    bool configured = true,
    LoginConfig login = const LoginConfig(googleWebClientId: 'web'),
    Locale locale = const Locale('ar'),
    ThemeMode theme = ThemeMode.light,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          keyValueStoreProvider.overrideWithValue(
            MemoryKeyValueStore({
              PrefKeys.tutorialSeen: true,
              PrefKeys.elderTutorialSeen: true,
              PrefKeys.language: locale.languageCode,
            }),
          ),
          supabaseConfigProvider.overrideWithValue(
            configured ? cloud : SupabaseConfig.none,
          ),
          if (configured) authGatewayProvider.overrideWithValue(gateway),
          loginConfigProvider.overrideWithValue(login),
          devicePlatformProvider.overrideWithValue('android'),
          deviceIdentityStoreProvider.overrideWithValue(
            MemoryDeviceIdentityStore(),
          ),
          accountReinstallCheckProvider.overrideWithValue(() async {}),
          reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
          themeModeProvider.overrideWith(() => _FixedTheme(theme)),
        ],
        child: const UsraApp(),
      ),
    );
    await settle(tester);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);
    await settle(tester);
  }

  void phone(WidgetTester tester, {double width = 390, double height = 2000}) {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = Size(width * 2, height * 2);
    addTearDown(tester.view.reset);
  }

  Future<void> tapSave(WidgetTester tester) async {
    final save = find.byKey(const ValueKey('doctor-save'));
    await tester.ensureVisible(save);
    await settle(tester);
    await tester.tap(save);
    await settle(tester);
  }

  Future<int> doctors(WidgetTester tester) async => (await tester.runAsync(
    () async => (await db.watchDoctors().first).length,
  ))!;

  testWidgets('login off: a save goes straight through and the account '
      'backend never starts', (tester) async {
    phone(tester);
    await open(tester, '/doctors/new', configured: false);
    await tester.enterText(find.byKey(name), 'د. منى');
    await tapSave(tester);
    expect(find.byKey(page), findsNothing);
    expect(await doctors(tester), 1);
    expect(gateway.restores, 0);
    expect(db.newRecordGuard, isNull);
  });

  testWidgets('signed out: the save asks first, going back keeps what was '
      'typed and saves nothing', (tester) async {
    phone(tester);
    await open(tester, '/doctors/new');
    await tester.enterText(find.byKey(name), 'د. منى');
    await tapSave(tester);
    expect(find.byKey(page), findsOneWidget);
    expect(await doctors(tester), 0);
    // And a save that skipped the form's check is refused by the database.
    expect(db.newRecordGuard, throwsA(isA<SignInRequiredException>()));

    await tester.tap(find.byKey(const ValueKey('sign-in-required-back')));
    await settle(tester);
    expect(find.byKey(page), findsNothing);
    expect(
      tester.widget<TextField>(find.byKey(name)).controller!.text,
      'د. منى',
    );
    expect(await doctors(tester), 0);
  });

  testWidgets('signing in carries on with the same save, with what was typed', (
    tester,
  ) async {
    phone(tester);
    await open(tester, '/doctors/new');
    await tester.enterText(find.byKey(name), 'د. منى');
    await tapSave(tester);
    await tester.tap(find.byKey(google));
    await settle(tester);
    expect(find.byKey(page), findsNothing);
    final saved = await tester.runAsync(() => db.watchDoctors().first);
    expect(saved!.single.name, 'د. منى');
  });

  testWidgets('a failed sign-in says why and loses nothing', (tester) async {
    phone(tester);
    await open(tester, '/doctors/new');
    await tester.enterText(find.byKey(name), 'د. منى');
    await tapSave(tester);
    gateway.failSignIn = const AccountException(AccountErrorKind.network);
    await tester.tap(find.byKey(google));
    await settle(tester);
    expect(
      find.byKey(const ValueKey('sign-in-required-error')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('sign-in-required-back')));
    await settle(tester);
    expect(
      tester.widget<TextField>(find.byKey(name)).controller!.text,
      'د. منى',
    );
    expect(await doctors(tester), 0);
  });

  testWidgets('closing the sheet shows no error and stays on the page', (
    tester,
  ) async {
    phone(tester);
    await open(tester, '/doctors/new');
    await tester.enterText(find.byKey(name), 'د. منى');
    await tapSave(tester);
    gateway.failSignIn = const AccountException(AccountErrorKind.cancelled);
    await tester.tap(find.byKey(google));
    await settle(tester);
    expect(find.byKey(page), findsOneWidget);
    expect(find.byKey(const ValueKey('sign-in-required-error')), findsNothing);
  });

  testWidgets('a session on the phone is enough, with no network calls', (
    tester,
  ) async {
    phone(tester);
    gateway.signedIn = FakeAuthGateway.googleUser;
    await open(tester, '/doctors/new');
    await tester.enterText(find.byKey(name), 'د. منى');
    await tapSave(tester);
    expect(find.byKey(page), findsNothing);
    expect(await doctors(tester), 1);
  });

  testWidgets('another page opening behind it, as from a notification, leaves '
      'nothing stuck: going back is a no and the next save asks again', (
    tester,
  ) async {
    phone(tester);
    await open(tester, '/doctors/new');
    await tester.enterText(find.byKey(name), 'د. منى');
    await tapSave(tester);
    expect(find.byKey(page), findsOneWidget);
    GoRouter.of(tester.element(find.byKey(page))).go('/records');
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('sign-in-required-back')));
    await settle(tester);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/doctors/new');
    await settle(tester);
    await tester.enterText(find.byKey(name), 'د. سارة');
    await tapSave(tester);
    expect(find.byKey(page), findsOneWidget);
    expect(await doctors(tester), 0);
  });

  testWidgets('correcting a saved record doesn\'t ask', (tester) async {
    phone(tester);
    final id = await tester.runAsync(() => db.saveDoctor(name: 'د. منى'));
    await open(tester, '/doctors/$id/edit');
    await tester.enterText(find.byKey(name), 'د. منى علي');
    await tapSave(tester);
    expect(find.byKey(page), findsNothing);
    final saved = await tester.runAsync(() => db.watchDoctors().first);
    expect(saved!.single.name, 'د. منى علي');
  });

  testWidgets('a build with no sign-in buttons doesn\'t trap anyone', (
    tester,
  ) async {
    phone(tester);
    await open(tester, '/doctors/new', login: const LoginConfig());
    await tester.enterText(find.byKey(name), 'د. منى');
    await tapSave(tester);
    expect(find.byKey(page), findsNothing);
    expect(await doctors(tester), 1);
  });

  testWidgets('a temperature in the sick-day sheet stays while signing in', (
    tester,
  ) async {
    phone(tester);
    final person = await tester.runAsync(() => db.addProfile('يوسف'));
    final episode = await tester.runAsync(
      () =>
          db.saveEpisode(profileId: person!, startedAt: DateTime(2026, 11, 7)),
    );
    await open(tester, '/family/$person/sick-days/$episode');
    await tester.tap(find.byKey(const ValueKey('sick-day-add-reading')));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('reading-value')), '38.5');
    await tester.tap(find.byKey(const ValueKey('reading-save')));
    await settle(tester);
    expect(find.byKey(page), findsOneWidget);
    await tester.tap(find.byKey(google));
    await settle(tester);
    expect(find.byKey(page), findsNothing);
    final readings = await tester.runAsync(
      () => db.watchReadings(episode!).first,
    );
    expect(readings!.single.value, 38.5);
  });

  group('the sign-in page fits', () {
    for (final locale in const [Locale('ar'), Locale('en')]) {
      for (final theme in const [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('320 wide at 200%, ${locale.languageCode}, ${theme.name}', (
          tester,
        ) async {
          // Tall to reach Save at the bottom of the form, then a real phone.
          phone(tester, width: 320, height: 4000);
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await open(tester, '/doctors/new', locale: locale, theme: theme);
          await tester.enterText(find.byKey(name), 'x');
          await tapSave(tester);
          tester.view.physicalSize = const Size(640, 1280);
          await settle(tester);
          expect(find.byKey(page), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.byKey(google),
            200,
            scrollable: find.byType(Scrollable).last,
          );
          await settle(tester);
          expect(
            tester.getSize(find.byKey(google)).height,
            greaterThanOrEqualTo(48),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('the database refuses a new record while signed out', () {
    Future<void> refuses(Future<Object?> Function() write) =>
        expectLater(write(), throwsA(isA<SignInRequiredException>()));

    test('every way in', () async {
      final person = await db.addProfile('منى');
      final episode = await db.saveEpisode(
        profileId: person,
        startedAt: DateTime(2026),
      );
      db.newRecordGuard = () => throw const SignInRequiredException();
      final now = DateTime(2026);
      await refuses(() => db.addProfile('ليلى'));
      await refuses(
        () => db.addEvent(profileId: person, type: 'visit', occurredAt: now),
      );
      await refuses(() => db.saveDoctor(name: 'x'));
      await refuses(() => db.saveInsuranceCard(profileId: person, label: 'x'));
      await refuses(
        () => db.saveMedicine(profileId: person, name: 'x', startOn: now),
      );
      await refuses(
        () => db.savePrescription(
          profileId: person,
          prescribedOn: now,
          items: [
            PrescriptionItemInput(name: 'x', times: const [], startOn: now),
          ],
        ),
      );
      await refuses(
        () => db.saveReading(
          episodeId: episode,
          takenAt: now,
          value: 38,
          unit: 'c',
        ),
      );
      await refuses(
        () => db.saveGivenMedicine(episodeId: episode, name: 'x', givenAt: now),
      );
      await refuses(
        () => db.saveSingletonEvent(
          profileId: person,
          type: 'plan',
          dataJson: '{}',
        ),
      );
      await refuses(
        () => db.replaceEvents(
          profileId: person,
          add: [(type: 'vaccine', occurredAt: now, dataJson: '{}')],
        ),
      );
    });

    test('but not the person\'s own first profile, corrections, deletes or '
        'doses', () async {
      db.newRecordGuard = () => throw const SignInRequiredException();
      final me = await db.addProfile('منى', firstRun: true);
      await db.updateProfile(me, displayName: 'منى علي');
      db.newRecordGuard = null;
      final now = DateTime(2026);
      final medicine = await db.saveMedicine(
        profileId: me,
        name: 'x',
        startOn: now,
      );
      final event = await db.addEvent(
        profileId: me,
        type: 'visit',
        occurredAt: now,
      );
      db.newRecordGuard = () => throw const SignInRequiredException();
      await db.saveMedicine(
        id: medicine,
        profileId: me,
        name: 'y',
        startOn: now,
      );
      await db.updateEvent(event, occurredAt: now, dataJson: '{}');
      await db.logDose(medicine, now, 'taken');
      await db.setMedicineActive(medicine, false);
      await db.softDeleteEvent(event);
      await db.softDeleteMedicine(medicine);
      await db.softDeleteProfile(me);
    });
  });
}

class _FixedTheme extends ThemeModeController {
  _FixedTheme(this.mode);

  final ThemeMode mode;

  @override
  ThemeMode build() => mode;
}
