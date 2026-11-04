import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/app.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/core/routing/app_router.dart';
import 'package:usra/core/security/app_lock.dart';

import '../core/app_lock_test.dart' show fastHasher;

const home = 'أهلاً! أنا دكتور أسرة';

void main() {
  late AppDatabase db;
  late MemoryLockStore store;
  late DateTime now;
  late _FakeBiometrics biometrics;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    store = MemoryLockStore();
    now = DateTime(2026, 11, 4, 9);
    biometrics = _FakeBiometrics();
  });
  tearDown(() => db.close());

  Future<AppLock> openLock(WidgetTester tester) async => (await tester.runAsync(
    () => AppLock.open(
      store: store,
      hasher: fastHasher,
      biometrics: biometrics,
      clock: () => now,
    ),
  ))!;

  /// A lock with [pin] set, as on a cold start.
  Future<AppLock> lockedWith(
    WidgetTester tester,
    String pin, {
    bool emergency = false,
    bool face = false,
  }) async {
    final first = await openLock(tester);
    await tester.runAsync(() async {
      await first.enable(pin, biometrics: face);
      await first.setEmergencyOnLockScreen(emergency);
    });
    return openLock(tester);
  }

  Widget app(AppLock lock) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      appLockProvider.overrideWithValue(lock),
    ],
    child: const UsraApp(),
  );

  /// Taps the PIN in and waits for the (real, off-thread) hash check.
  Future<void> typePin(WidgetTester tester, String pin) async {
    for (final d in pin.split('')) {
      await tester.tap(find.byKey(ValueKey('pin-$d')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('pin-ok')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
  }

  String location(WidgetTester tester) {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(UsraApp)),
    );
    return container
        .read(routerProvider)
        .routerDelegate
        .currentConfiguration
        .uri
        .path;
  }

  testWidgets('a locked app shows only the lock screen until the PIN', (
    tester,
  ) async {
    final lock = await lockedWith(tester, '2580');
    await tester.pumpWidget(app(lock));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lock-screen')), findsOneWidget);
    expect(find.text(home), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    // No emergency button unless turned on.
    expect(find.byKey(const ValueKey('lock-emergency')), findsNothing);

    await typePin(tester, '1111');
    expect(find.text('الرقم السري غلط. جرّب تاني.'), findsOneWidget);
    expect(find.byKey(const ValueKey('lock-screen')), findsOneWidget);

    await typePin(tester, '2580');
    expect(find.byKey(const ValueKey('lock-screen')), findsNothing);
    expect(find.text(home), findsOneWidget);
  });

  testWidgets('a deep link waits behind the lock and opens after it', (
    tester,
  ) async {
    final lock = await lockedWith(tester, '2580');
    await tester.pumpWidget(app(lock));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(UsraApp)),
    );

    // What main.dart does for a reminder or widget tap.
    lock.runWhenUnlocked(() => container.read(routerProvider).go('/medicines'));
    await tester.pumpAndSettle();
    expect(location(tester), isNot('/medicines'));
    expect(find.byKey(const ValueKey('lock-screen')), findsOneWidget);

    await typePin(tester, '2580');
    expect(location(tester), '/medicines');
    expect(find.byKey(const ValueKey('lock-screen')), findsNothing);
  });

  testWidgets('five wrong PINs lock the pad for 30 seconds', (tester) async {
    final lock = await lockedWith(tester, '2580');
    await tester.pumpWidget(app(lock));
    await tester.pumpAndSettle();

    for (var i = 0; i < 5; i++) {
      await typePin(tester, '0000');
    }
    expect(find.text('محاولات غلط كتير. جرّب تاني بعد 0:30.'), findsOneWidget);
    // Keys do nothing while waiting.
    await typePin(tester, '2580');
    expect(find.byKey(const ValueKey('lock-screen')), findsOneWidget);
    expect(lock.failures, 5);

    now = now.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 1));
    await typePin(tester, '2580');
    expect(find.byKey(const ValueKey('lock-screen')), findsNothing);
  });

  testWidgets('Simple Mode: a big pad that fits with 2× phone text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final lock = await lockedWith(tester, '2580', emergency: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLockProvider.overrideWithValue(lock),
          keyValueStoreProvider.overrideWithValue(
            MemoryKeyValueStore({
              PrefKeys.simpleMode: true,
              PrefKeys.elderTutorialSeen: true,
            }),
          ),
        ],
        child: const UsraApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(const ValueKey('pin-5'))).width, 84);

    await tester.ensureVisible(find.byKey(const ValueKey('pin-ok')));
    await typePin(tester, '2580');
    expect(lock.locked, isFalse);
  });

  testWidgets('biometrics come first and unlock on their own', (tester) async {
    biometrics.pass = true;
    final lock = await lockedWith(tester, '2580', face: true);
    await tester.pumpWidget(app(lock));
    await tester.pumpAndSettle();

    expect(biometrics.asked, 1);
    expect(find.byKey(const ValueKey('lock-screen')), findsNothing);
    expect(find.text(home), findsOneWidget);
  });

  testWidgets('forgot PIN explains the reset, without a way around', (
    tester,
  ) async {
    final lock = await lockedWith(tester, '2580');
    await tester.pumpWidget(app(lock));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('lock-forgot')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lock-forgot-body')), findsOneWidget);
    expect(find.textContaining('مفتاح الاسترجاع'), findsOneWidget);
    await tester.tap(find.text('تمام'));
    await tester.pumpAndSettle();
    expect(lock.locked, isTrue);
  });

  testWidgets('emergency card from the lock screen only when turned on', (
    tester,
  ) async {
    final id = (await tester.runAsync(() => db.addProfile('جدو')))!;
    final lock = await lockedWith(tester, '2580', emergency: true);
    await tester.pumpWidget(app(lock));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('lock-emergency')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lock-emergency')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('lock-emergency-$id')));
    await tester.pumpAndSettle();
    expect(find.text('بطاقة الطوارئ'), findsWidgets);
    expect(find.byKey(const ValueKey('emergency-blood')), findsOneWidget);
    // Nothing on it leads into the app.
    expect(find.byKey(const ValueKey('emergency-complete')), findsNothing);

    // Back goes to the lock screen, still locked.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lock-screen')), findsOneWidget);
    expect(lock.locked, isTrue);
  });

  testWidgets('locks again after the timeout in the background', (
    tester,
  ) async {
    final lock = await lockedWith(tester, '2580');
    await tester.pumpWidget(app(lock));
    await tester.pumpAndSettle();
    await typePin(tester, '2580');

    void lifecycle(AppLifecycleState s) =>
        tester.binding.handleAppLifecycleStateChanged(s);

    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.hidden);
    lifecycle(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 30));
    lifecycle(AppLifecycleState.hidden);
    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lock-screen')), findsNothing);

    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.hidden);
    lifecycle(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 2));
    lifecycle(AppLifecycleState.hidden);
    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lock-screen')), findsOneWidget);
  });

  testWidgets('turn the lock on from Settings, then off with the PIN', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final lock = await openLock(tester);
    await tester.pumpWidget(app(lock));
    await tester.pumpAndSettle();

    await tester.tap(find.text('المزيد').last);
    await tester.pumpAndSettle();
    expect(find.text('مقفول: أي حد معاه الموبايل يقدر يفتح أسرة'), findsOne);
    await tester.tap(find.byKey(const ValueKey('settings-app-lock')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app-lock-switch')));
    await tester.pumpAndSettle();

    await typePin(tester, '13579');
    expect(find.text('اكتب نفس الرقم السري تاني'), findsOneWidget);
    await typePin(tester, '13570');
    expect(find.byKey(const ValueKey('setup-mismatch')), findsOneWidget);
    await typePin(tester, '13579');
    await typePin(tester, '13579');
    // The phone has biometrics: asked, and declined.
    await tester.tap(find.byKey(const ValueKey('setup-biometrics-no')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    expect(lock.enabled, isTrue);
    expect(lock.locked, isFalse);
    expect(lock.biometricsEnabled, isFalse);
    expect(store.value, isNot(contains('13579')));
    expect(find.byKey(const ValueKey('app-lock-emergency')), findsOneWidget);

    await tester.tap(find.text('على طول'));
    await tester.pump();
    expect(lock.timeout, LockTimeout.immediately);

    // Turning it off asks for the PIN first.
    await tester.tap(find.byKey(const ValueKey('app-lock-switch')));
    await tester.pumpAndSettle();
    await typePin(tester, '11111');
    expect(lock.enabled, isTrue);
    await typePin(tester, '13579');
    expect(lock.enabled, isFalse);
    expect(store.value, isNull);
  });
}

class _FakeBiometrics implements BiometricUnlock {
  bool pass = false;
  int asked = 0;

  @override
  Future<bool> available() async => true;

  @override
  Future<bool> authenticate(String reason) async {
    asked++;
    return pass;
  }
}
