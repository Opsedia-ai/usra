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
import 'package:usra/features/account/supabase_config.dart';

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

  Widget app({bool configured = true, List<Override> extra = const []}) =>
      ProviderScope(
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
          deviceIdentityStoreProvider.overrideWithValue(ids),
          accountReinstallCheckProvider.overrideWithValue(() async {}),
          ...extra,
        ],
        child: const UsraApp(),
      );

  Future<void> openAccount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
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

  testWidgets('sign in with an Egyptian number and a texted code', (
    tester,
  ) async {
    await openAccount(tester);
    expect(gateway.restores, 1);
    // Says plainly that records stay on the phone.
    expect(
      find.textContaining('سجلات العيلة الصحية فاضلة على الموبايل ده'),
      findsOneWidget,
    );
    expect(find.text('+20 '), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('account-phone')), '123');
    await tester.tap(find.byKey(const ValueKey('account-send-code')));
    await tester.pumpAndSettle();
    expect(find.text('اتأكد من رقم الموبايل'), findsOneWidget);
    expect(gateway.codesSent, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('account-phone')),
      '٠١٠٠١٢٣٤٥٦٧',
    );
    await tester.tap(find.byKey(const ValueKey('account-send-code')));
    await tester.pumpAndSettle();
    expect(gateway.codesSent, ['+201001234567']);
    expect(find.textContaining('+20 10•••••567'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('account-code')),
      '000000',
    );
    await tester.tap(find.byKey(const ValueKey('account-verify')));
    await tester.pumpAndSettle();
    expect(find.text('الكود ده مش صح أو انتهى'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('account-code')),
      FakeAuthGateway.validCode,
    );
    await tester.tap(find.byKey(const ValueKey('account-verify')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-signed-in')), findsOneWidget);
    expect(gateway.accountUpdates.single, (country: 'EG', locale: 'ar'));
    expect(gateway.devices, hasLength(1));
  });

  testWidgets('choose Saudi Arabia, resend and change the number', (
    tester,
  ) async {
    await openAccount(tester);
    await tester.tap(find.text('السعودية'));
    await tester.pumpAndSettle();
    expect(find.text('+966 '), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('account-phone')),
      '0501234567',
    );
    await tester.tap(find.byKey(const ValueKey('account-send-code')));
    await tester.pumpAndSettle();
    expect(gateway.codesSent, ['+966501234567']);

    // Resend waits a minute.
    expect(find.text('تقدر تطلب كود تاني بعد 60 ثانية'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('account-resend')));
    await tester.pump(const Duration(seconds: 30));
    expect(gateway.codesSent, ['+966501234567']);
    expect(find.text('تقدر تطلب كود تاني بعد 30 ثانية'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    await tester.tap(find.byKey(const ValueKey('account-resend')));
    await tester.pumpAndSettle();
    expect(gateway.codesSent, ['+966501234567', '+966501234567']);
    expect(find.text('الكود اتبعت تاني'), findsOneWidget);
    expect(find.text('تقدر تطلب كود تاني بعد 60 ثانية'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('account-change-number')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-phone')), findsOneWidget);
  });

  testWidgets('pressing Enter twice while sending sends one code', (
    tester,
  ) async {
    await openAccount(tester);
    gateway.holdSend = Completer();
    await tester.enterText(
      find.byKey(const ValueKey('account-phone')),
      '01001234567',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    gateway.holdSend!.complete();
    await tester.pumpAndSettle();
    expect(gateway.codesSent, ['+201001234567']);
  });

  testWidgets('a family with other members blocks delete, plainly', (
    tester,
  ) async {
    const id = 'user-201001234567';
    gateway.signedIn = const AccountUser(id: id, phone: '+201001234567');
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

  testWidgets('too many codes shows a wait message', (tester) async {
    await openAccount(tester);
    gateway.failSend = const AccountException(AccountErrorKind.tooManyRequests);
    await tester.enterText(
      find.byKey(const ValueKey('account-phone')),
      '01001234567',
    );
    await tester.tap(find.byKey(const ValueKey('account-send-code')));
    await tester.pumpAndSettle();
    expect(find.text('محاولات كتير. استنى شوية وجرّب تاني'), findsOneWidget);
    expect(find.byKey(const ValueKey('account-phone')), findsOneWidget);
  });

  testWidgets('sign out and delete both wipe the device key', (tester) async {
    const id = 'user-201001234567';
    gateway.signedIn = const AccountUser(id: id, phone: '+201001234567');
    gateway.devices['device-1'] = (platform: 'ios', appVersion: '1', key: [1]);
    await ids.saveDeviceId(id, 'device-1');
    await ids.publicKey(id);
    await openAccount(tester);
    expect(find.textContaining('+20 10•••••567'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('account-sign-out')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-phone')), findsOneWidget);
    expect(ids.devices, isEmpty);
    expect(ids.keys, isEmpty);
    expect(gateway.deletedDevices, ['device-1']);

    // Back in, then delete (cancelling once first).
    await tester.enterText(
      find.byKey(const ValueKey('account-phone')),
      '01001234567',
    );
    await tester.tap(find.byKey(const ValueKey('account-send-code')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('account-code')),
      FakeAuthGateway.validCode,
    );
    await tester.tap(find.byKey(const ValueKey('account-verify')));
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
    expect(find.byKey(const ValueKey('account-phone')), findsOneWidget);
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
    expect(find.byKey(const ValueKey('account-phone')), findsNothing);
    expect(find.byKey(const ValueKey('settings-backup')), findsOneWidget);
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
    expect(find.text('Send code'), findsOneWidget);
  });
}
