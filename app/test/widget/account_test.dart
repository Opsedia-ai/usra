import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/app.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/core/routing/app_router.dart';
import 'package:usra/features/account/account_providers.dart';
import 'package:usra/features/account/auth_gateway.dart';
import 'package:usra/features/account/device_identity.dart';
import 'package:usra/features/account/login_config.dart';
import 'package:usra/features/account/supabase_config.dart';
import 'package:usra/features/settings/key_unavailable.dart';
import 'package:usra/l10n/app_localizations.dart';

import '../support/fake_auth_gateway.dart';

void main() {
  late AppDatabase db;
  late FakeAuthGateway gateway;
  late MemoryDeviceIdentityStore ids;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    gateway = FakeAuthGateway();
    ids = MemoryDeviceIdentityStore();
  });
  tearDown(() => db.close());

  const cloud = SupabaseConfig(
    url: 'https://example.supabase.co',
    anonKey: 'anon',
  );

  const googleKey = ValueKey('account-sign-in-google');
  const appleKey = ValueKey('account-sign-in-apple');

  Widget app({
    bool configured = true,
    bool isIos = true,
    LoginConfig login = const LoginConfig(
      googleWebClientId: 'web',
      googleIosClientId: 'ios',
      appleEnabled: true,
    ),
    List<Override> extra = const [],
  }) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      keyValueStoreProvider.overrideWithValue(
        MemoryKeyValueStore({
          PrefKeys.tutorialSeen: true,
          PrefKeys.elderTutorialSeen: true,
        }),
      ),
      supabaseConfigProvider.overrideWithValue(
        configured ? cloud : SupabaseConfig.none,
      ),
      if (configured) authGatewayProvider.overrideWithValue(gateway),
      loginConfigProvider.overrideWithValue(login),
      devicePlatformProvider.overrideWithValue(isIos ? 'ios' : 'android'),
      deviceIdentityStoreProvider.overrideWithValue(ids),
      accountReinstallCheckProvider.overrideWithValue(() async {}),
      ...extra,
    ],
    child: const UsraApp(),
  );

  Future<void> openAccount(WidgetTester tester, {Widget? root}) async {
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(root ?? app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('المزيد').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-account')));
    await tester.pumpAndSettle();
  }

  testWidgets('no cloud configured: Settings has no account entry', (
    tester,
  ) async {
    await tester.pumpWidget(app(configured: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('المزيد').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-backup')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-account')), findsNothing);
    expect(gateway.restores, 0);
  });

  testWidgets('Settings doesn\'t start the backend until the account opens', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('المزيد').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-account')), findsOneWidget);
    expect(gateway.restores, 0);
  });

  testWidgets('sign in with Google, in Arabic', (tester) async {
    await openAccount(tester);
    expect(gateway.restores, 1);
    // Says plainly that records stay on the phone.
    expect(
      find.textContaining('سجلات العيلة الصحية فاضلة على الموبايل ده'),
      findsOneWidget,
    );
    expect(find.text('تسجيل الدخول باستخدام Google'), findsOneWidget);
    expect(find.text('تسجيل الدخول باستخدام Apple'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byKey(googleKey))),
      TextDirection.rtl,
    );

    await tester.tap(find.byKey(googleKey));
    await tester.pumpAndSettle();
    expect(gateway.signIns, [SignInMethod.google]);
    expect(find.byKey(const ValueKey('account-signed-in')), findsOneWidget);
    expect(find.text('mona@example.com'), findsOneWidget);
    // An address stays left to right on the Arabic screen.
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('account-email')))
          .textDirection,
      TextDirection.ltr,
    );
    expect(gateway.accountUpdates.single, 'ar');
    expect(gateway.devices, hasLength(1));
    expect(find.byKey(googleKey), findsNothing);
  });

  testWidgets('sign in with Apple', (tester) async {
    gateway.nextUser = FakeAuthGateway.appleUser;
    await openAccount(tester);
    await tester.tap(find.byKey(appleKey));
    await tester.pumpAndSettle();
    expect(gateway.signIns, [SignInMethod.apple]);
    expect(find.byKey(const ValueKey('account-signed-in')), findsOneWidget);
  });

  testWidgets('Android shows Google and no Apple', (tester) async {
    await openAccount(tester, root: app(isIos: false));
    expect(find.byKey(googleKey), findsOneWidget);
    expect(find.byKey(appleKey), findsNothing);
  });

  testWidgets('the sign-in screen says what agreeing means, with a link', (
    tester,
  ) async {
    await openAccount(tester);
    expect(
      find.byKey(const ValueKey('account-sign-in-consent')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('account-privacy-link')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('about-medical')), findsOneWidget);
  });

  testWidgets('a button whose setup is missing is hidden', (tester) async {
    await openAccount(
      tester,
      root: app(login: const LoginConfig(appleEnabled: true)),
    );
    expect(find.byKey(appleKey), findsOneWidget);
    expect(find.byKey(googleKey), findsNothing);
  });

  testWidgets('no button at all says so plainly', (tester) async {
    await openAccount(tester, root: app(login: const LoginConfig()));
    expect(find.byKey(appleKey), findsNothing);
    expect(find.byKey(googleKey), findsNothing);
    expect(
      find.byKey(const ValueKey('account-sign-in-unavailable')),
      findsOneWidget,
    );
  });

  testWidgets('closing the sheet shows no error and stays signed out', (
    tester,
  ) async {
    await openAccount(tester);
    gateway.failSignIn = const AccountException(AccountErrorKind.cancelled);
    await tester.tap(find.byKey(googleKey));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byKey(googleKey), findsOneWidget);
    expect(gateway.signIns, isEmpty);
    expect(gateway.devices, isEmpty);
  });

  testWidgets('a failed sign-in says so; trying again works', (tester) async {
    await openAccount(tester);
    gateway.failSignIn = const AccountException(AccountErrorKind.unknown);
    await tester.tap(find.byKey(appleKey));
    await tester.pumpAndSettle();
    expect(find.text('حصلت مشكلة. جرّب تاني'), findsOneWidget);
    expect(find.byKey(appleKey), findsOneWidget);

    await tester.tap(find.byKey(appleKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-signed-in')), findsOneWidget);
  });

  testWidgets('no internet during sign-in says so', (tester) async {
    await openAccount(tester);
    gateway.failSignIn = const AccountException(AccountErrorKind.network);
    await tester.tap(find.byKey(googleKey));
    await tester.pumpAndSettle();
    expect(find.text('مفيش اتصال. اتأكد من النت وجرّب تاني'), findsOneWidget);
  });

  testWidgets('tapping twice while signing in signs in once', (tester) async {
    await openAccount(tester);
    gateway.holdSignIn = Completer();
    await tester.tap(find.byKey(googleKey));
    await tester.pump();
    await tester.tap(find.byKey(googleKey), warnIfMissed: false);
    await tester.tap(find.byKey(appleKey), warnIfMissed: false);
    await tester.pump();
    gateway.holdSignIn!.complete();
    await tester.pumpAndSettle();
    expect(gateway.signIns, [SignInMethod.google]);
  });

  testWidgets('Simple Mode text fits the buttons, in Arabic', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openAccount(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(googleKey), findsOneWidget);
    expect(
      tester.getSize(find.byKey(googleKey)).height,
      greaterThanOrEqualTo(52),
    );
  });

  testWidgets('deleting an Apple account warns about Apple\'s sheet', (
    tester,
  ) async {
    const id = 'user-1';
    gateway.signedIn = FakeAuthGateway.appleUser;
    await ids.saveDeviceId(id, 'device-1');
    await openAccount(tester);
    await tester.tap(find.byKey(const ValueKey('account-delete')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Apple هتطلب منك تأكيد'), findsOneWidget);

    // Closing Apple's sheet: nothing happens and nothing is shown.
    gateway.failDelete = const AccountException(AccountErrorKind.cancelled);
    await tester.tap(find.byKey(const ValueKey('account-confirm')));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(gateway.deleted, 0);
    expect(find.byKey(const ValueKey('account-signed-in')), findsOneWidget);
  });

  testWidgets('deleting a Google account has no Apple step', (tester) async {
    const id = 'user-1';
    gateway.signedIn = FakeAuthGateway.googleUser;
    await ids.saveDeviceId(id, 'device-1');
    await openAccount(tester);
    await tester.tap(find.byKey(const ValueKey('account-delete')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Apple'), findsNothing);
  });

  testWidgets('a family with other members blocks delete, plainly', (
    tester,
  ) async {
    const id = 'user-1';
    gateway.signedIn = FakeAuthGateway.googleUser;
    await ids.saveDeviceId(id, 'device-1');
    await openAccount(tester);
    gateway.failDelete = const AccountException(
      AccountErrorKind.familyHasMembers,
    );
    await tester.tap(find.byKey(const ValueKey('account-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-confirm')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('إنت عامل عيلة فيها ناس تانيين'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('account-signed-in')), findsOneWidget);
  });

  testWidgets('too many tries shows a wait message', (tester) async {
    await openAccount(tester);
    gateway.failSignIn = const AccountException(
      AccountErrorKind.tooManyRequests,
    );
    await tester.tap(find.byKey(googleKey));
    await tester.pumpAndSettle();
    expect(find.text('محاولات كتير. استنى شوية وجرّب تاني'), findsOneWidget);
    expect(find.byKey(googleKey), findsOneWidget);
  });

  testWidgets('sign out and delete both wipe the device key', (tester) async {
    const id = 'user-1';
    gateway.signedIn = FakeAuthGateway.googleUser;
    gateway.devices['device-1'] = (platform: 'ios', appVersion: '1', key: [1]);
    await ids.saveDeviceId(id, 'device-1');
    await ids.publicKey(id);
    await openAccount(tester);
    expect(find.text('mona@example.com'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('account-sign-out')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(googleKey), findsOneWidget);
    expect(ids.devices, isEmpty);
    expect(ids.keys, isEmpty);
    expect(gateway.revokedDevices, ['device-1']);

    // Back in, then delete (cancelling once first).
    await tester.tap(find.byKey(googleKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('account-delete')));
    await tester.pumpAndSettle();
    expect(find.textContaining('السجلات اللي على الموبايل ده'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(gateway.deleted, 0);

    await tester.tap(find.byKey(const ValueKey('account-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-confirm')));
    await tester.pumpAndSettle();
    expect(gateway.deleted, 1);
    expect(find.text('الحساب اتمسح'), findsOneWidget);
    expect(find.byKey(googleKey), findsOneWidget);
    expect(ids.devices, isEmpty);
    expect(ids.keys, isEmpty);
  });

  testWidgets('the account screen redirects to Settings without a cloud', (
    tester,
  ) async {
    await tester.pumpWidget(app(configured: false));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Navigator).first);
    ProviderScope.containerOf(context)
        .read(routerProvider)
        .go('/settings/account');
    await tester.pumpAndSettle();
    expect(find.byKey(googleKey), findsNothing);
    expect(find.byKey(const ValueKey('settings-backup')), findsOneWidget);
  });

  testWidgets('with no account, every tab still opens', (tester) async {
    await tester.pumpWidget(app(configured: false));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final tab in ['العيلة', 'الأدوية', 'الدكاترة', 'الفلوس', 'المزيد']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
    expect(gateway.restores, 0);
  });

  testWidgets('the database key screen says records are safe and retries', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DatabaseKeyUnavailable(onRetry: () async => retries++),
          ),
        ),
      ),
    );
    expect(find.textContaining('nothing was deleted'), findsOneWidget);
    expect(find.textContaining('متمسحتش'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('database-key-retry')));
    expect(retries, 1);
  });

  group('the database unavailable screen', () {
    Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    final retry = find.byKey(const ValueKey('database-key-retry'));
    bool enabled(WidgetTester tester) =>
        tester.widget<FilledButton>(retry).onPressed != null;

    testWidgets('a double tap retries once and disables the button', (
      tester,
    ) async {
      var retries = 0;
      final done = Completer<void>();
      await pump(
        tester,
        DatabaseKeyUnavailable(
          onRetry: () {
            retries++;
            return done.future;
          },
        ),
      );
      // Same frame: the button hasn't been rebuilt between the two calls.
      final press = tester.widget<FilledButton>(retry).onPressed!;
      press();
      press();
      expect(retries, 1);
      await tester.pump();
      expect(enabled(tester), isFalse);
      await tester.tap(retry, warnIfMissed: false);
      expect(retries, 1);
      done.complete();
    });

    testWidgets('the button comes back when the retry fails again', (
      tester,
    ) async {
      // main() shows this screen again with runApp, which keeps the State.
      var retries = 0;
      Future<void> onRetry() async => retries++;
      await pump(tester, DatabaseKeyUnavailable(onRetry: onRetry));
      await tester.tap(retry);
      await tester.pump();
      await pump(tester, DatabaseKeyUnavailable(onRetry: onRetry));
      await tester.pump();
      expect(enabled(tester), isTrue);
      await tester.tap(retry);
      expect(retries, 2);
    });

    testWidgets('a retry that throws brings the button back too', (
      tester,
    ) async {
      await pump(
        tester,
        DatabaseKeyUnavailable(onRetry: () async => throw StateError('no')),
      );
      await tester.tap(retry);
      await tester.pump();
      expect(tester.takeException(), isStateError);
      expect(enabled(tester), isTrue);
    });

    testWidgets('an open failure says records are safe, not the key', (
      tester,
    ) async {
      await pump(
        tester,
        DatabaseKeyUnavailable.openFailed(onRetry: () async {}),
      );
      expect(find.textContaining('free storage'), findsOneWidget);
      expect(find.textContaining('nothing was deleted'), findsOneWidget);
      expect(find.textContaining('مساحة فاضية'), findsOneWidget);
      expect(find.textContaining('مفتاح'), findsNothing);
    });
  });

  test('account privacy text lists what the privacy policy lists', () {
    final en = lookupAppLocalizations(const Locale('en'));
    for (final text in [
      en.aboutPrivacyOptionalAccount,
      en.accountSignInIntro,
    ]) {
      for (final item in [
        'email',
        'name',
        'profile photo link',
        'account ID',
        'language',
        'device information',
      ]) {
        expect(text, contains(item));
      }
    }
    final ar = lookupAppLocalizations(const Locale('ar'));
    for (final text in [
      ar.aboutPrivacyOptionalAccount,
      ar.accountSignInIntro,
    ]) {
      for (final item in [
        'إيميلك',
        'اسمك',
        'لينك صورة حسابك',
        'رقم تعريف للحساب',
        'اللغة',
        'معلومات الجهاز',
      ]) {
        expect(text, contains(item));
      }
    }
  });

  testWidgets('English strings', (tester) async {
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Navigator).first);
    ProviderScope.containerOf(context)
        .read(localeProvider.notifier)
        .change(const Locale('en'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-account')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining("Your family's health records stay on this phone"),
      findsOneWidget,
    );
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Sign in with Apple'), findsOneWidget);
  });
}
