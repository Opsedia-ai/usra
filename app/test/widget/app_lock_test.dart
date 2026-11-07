import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/app.dart';
import 'package:usra/core/backup/auto_backup.dart';
import 'package:usra/core/backup/recovery_key.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/core/routing/app_router.dart';
import 'package:usra/core/screen_privacy.dart';
import 'package:usra/core/security/app_lock.dart';
import 'package:usra/features/backup/backup_providers.dart';

import '../support/fake_lock.dart';

const home = 'أهلاً! أنا دكتور أسرة';

void main() {
  late AppDatabase db;
  late MemoryLockStore store;
  late FakeClocks clocks;
  late FakeBiometrics biometrics;
  late MemoryRecoveryKeyStore keys;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    store = MemoryLockStore();
    clocks = FakeClocks();
    biometrics = FakeBiometrics();
    keys = MemoryRecoveryKeyStore();
  });
  tearDown(() => db.close());

  Future<AppLock> openLock(WidgetTester tester) async => (await tester.runAsync(
    () => AppLock.open(
      store: store,
      hasher: fastHasher,
      biometrics: biometrics,
      clock: clocks.wall,
      ticks: clocks.ticks,
      uptime: clocks,
    ),
  ))!;

  /// A lock with [pin] set, as on a cold start.
  Future<AppLock> lockedWith(
    WidgetTester tester,
    String pin, {
    String? emergency,
    bool face = false,
  }) async {
    final first = await openLock(tester);
    await tester.runAsync(() async {
      await first.enable(pin, biometrics: face);
      if (emergency != null) await first.setEmergencyProfile(emergency, true);
    });
    return openLock(tester);
  }

  /// A phone where a backup has been made.
  MemoryKeyValueStore backedUp() => MemoryKeyValueStore({
    PrefKeys.tutorialSeen: true,
    PrefKeys.lastBackupAt: 1,
  });

  Widget app(AppLock lock, {KeyValueStore? prefs}) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      appLockProvider.overrideWithValue(lock),
      recoveryKeyStoreProvider.overrideWithValue(keys),
      if (prefs != null) keyValueStoreProvider.overrideWithValue(prefs),
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
    final lock = await lockedWith(tester, '258046');
    await tester.pumpWidget(app(lock));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lock-screen')), findsOneWidget);
    expect(find.text(home), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    // No emergency button unless turned on.
    expect(find.byKey(const ValueKey('lock-emergency')), findsNothing);

    await typePin(tester, '111111');
    expect(find.text('الرقم السري غلط. جرّب تاني.'), findsOneWidget);
    expect(find.byKey(const ValueKey('lock-screen')), findsOneWidget);

    await typePin(tester, '258046');
    expect(find.byKey(const ValueKey('lock-screen')), findsNothing);
    expect(find.text(home), findsOneWidget);
  });

  testWidgets('a deep link waits behind the lock and opens after it', (
    tester,
  ) async {
    final lock = await lockedWith(tester, '258046');
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

    await typePin(tester, '258046');
    expect(location(tester), '/medicines');
    expect(find.byKey(const ValueKey('lock-screen')), findsNothing);
  });

  testWidgets('five wrong PINs lock the pad for 30 seconds', (tester) async {
    final lock = await lockedWith(tester, '258046');
    await tester.pumpWidget(app(lock));
    await tester.pumpAndSettle();

    for (var i = 0; i < 5; i++) {
      await typePin(tester, '000000');
    }
    expect(find.text('محاولات غلط كتير. جرّب تاني بعد 0:30.'), findsOneWidget);
    // Keys do nothing while waiting.
    await typePin(tester, '258046');
    expect(find.byKey(const ValueKey('lock-screen')), findsOneWidget);
    expect(lock.failures, 5);

    clocks.pass(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 1));
    await typePin(tester, '258046');
    expect(find.byKey(const ValueKey('lock-screen')), findsNothing);
  });

  testWidgets('Simple Mode: a big pad that fits with 2× phone text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final lock = await lockedWith(tester, '258046', emergency: 'x');
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
    await typePin(tester, '258046');
    expect(lock.locked, isFalse);
  });

  testWidgets('biometrics come first and unlock on their own', (tester) async {
    biometrics.pass = true;
    final lock = await lockedWith(tester, '258046', face: true);
    await tester.pumpWidget(app(lock));
    await tester.pumpAndSettle();

    expect(biometrics.asked, 1);
    expect(find.byKey(const ValueKey('lock-screen')), findsNothing);
    expect(find.text(home), findsOneWidget);
  });

  testWidgets('forgot PIN explains the reset, without a way around', (
    tester,
  ) async {
    final lock = await lockedWith(tester, '258046');
    await tester.pumpWidget(app(lock));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('lock-forgot')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lock-forgot')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lock-forgot-body')), findsOneWidget);
    expect(find.textContaining('مفتاح الاسترجاع'), findsOneWidget);
    await tester.tap(find.text('تمام'));
    await tester.pumpAndSettle();
    expect(lock.locked, isTrue);
  });

  testWidgets('emergency card from the lock screen only for chosen people', (
    tester,
  ) async {
    final (id, other) = (await tester.runAsync(
      () async => (
        await db.addProfile('جدو', emergencyPhone: '010 1234'),
        await db.addProfile('منى'),
      ),
    ))!;
    final lock = await lockedWith(tester, '258046', emergency: id);
    await tester.pumpWidget(app(lock));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('lock-emergency')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lock-emergency')));
    await tester.pumpAndSettle();
    // Only the people the owner chose.
    expect(find.byKey(ValueKey('lock-emergency-$other')), findsNothing);
    expect(find.text('منى'), findsNothing);
    await tester.tap(find.byKey(ValueKey('lock-emergency-$id')));
    await tester.pumpAndSettle();
    expect(find.text('كارت الطوارئ'), findsWidgets);
    expect(find.byKey(const ValueKey('emergency-blood')), findsOneWidget);
    // Someone to call is what the card is for here.
    expect(find.byKey(const ValueKey('emergency-contact')), findsOneWidget);
    // Nothing on it leads into the app.
    expect(find.byKey(const ValueKey('emergency-complete')), findsNothing);
    expect(find.byKey(const ValueKey('emergency-lock-switch')), findsNothing);
    expect(find.byKey(const ValueKey('emergency-medical-id')), findsNothing);

    // Back goes to the lock screen, still locked.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lock-screen')), findsOneWidget);
    expect(lock.locked, isTrue);

    // Back on the lock screen itself is handled (the app closes), and
    // never reaches the pages behind it.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lock-screen')), findsOneWidget);
    expect(lock.locked, isTrue);
  });

  testWidgets('locks again after the timeout in the background', (
    tester,
  ) async {
    final lock = await lockedWith(tester, '258046');
    await tester.pumpWidget(app(lock));
    await tester.pumpAndSettle();
    await typePin(tester, '258046');

    void lifecycle(AppLifecycleState s) =>
        tester.binding.handleAppLifecycleStateChanged(s);

    lifecycle(AppLifecycleState.inactive);
    await tester.pump();
    // Covered from the moment it starts to leave.
    expect(find.byKey(const ValueKey('lock-cover')), findsOneWidget);
    expect(find.text(home), findsNothing);
    lifecycle(AppLifecycleState.hidden);
    lifecycle(AppLifecycleState.paused);
    clocks.pass(const Duration(seconds: 30));
    lifecycle(AppLifecycleState.hidden);
    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lock-screen')), findsNothing);
    expect(find.byKey(const ValueKey('lock-cover')), findsNothing);
    expect(find.text(home), findsOneWidget);

    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.hidden);
    lifecycle(AppLifecycleState.paused);
    clocks.pass(const Duration(minutes: 2));
    lifecycle(AppLifecycleState.hidden);
    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lock-screen')), findsOneWidget);
  });

  testWidgets('the native cover is held until the lock screen is drawn', (
    tester,
  ) async {
    final calls = <String>[];
    // What the native cover shows when Dart uncovers it.
    final shown = <bool>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      ScreenPrivacy.channel,
      (call) async {
        // FLAG_SECURE follows its own setting.
        if (call.method == 'setSecure') return null;
        calls.add(
          call.method == 'coverUntilReady'
              ? 'coverUntilReady ${call.arguments}'
              : call.method,
        );
        if (call.method == 'uncover') {
          shown.add(
            find.byKey(const ValueKey('lock-screen')).evaluate().isNotEmpty,
          );
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        ScreenPrivacy.channel,
        null,
      ),
    );
    final lock = await lockedWith(tester, '258046');
    await tester.pumpWidget(app(lock));
    await tester.pumpAndSettle();
    expect(calls, ['coverUntilReady true']);
    await typePin(tester, '258046');

    void lifecycle(AppLifecycleState s) =>
        tester.binding.handleAppLifecycleStateChanged(s);
    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.hidden);
    lifecycle(AppLifecycleState.paused);
    clocks.pass(const Duration(minutes: 2));
    lifecycle(AppLifecycleState.hidden);
    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    // Uncovered only once the lock screen was on screen.
    expect(calls.last, 'uncover');
    expect(shown, [true]);

    await typePin(tester, '258046');
    await tester.runAsync(lock.disable);
    await tester.pump();
    expect(calls.last, 'coverUntilReady false');
  });

  testWidgets('turn the lock on from Settings, then off with the PIN', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => db.addProfile('جدو'));
    final lock = await openLock(tester);
    await tester.pumpWidget(app(lock, prefs: backedUp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('المزيد').last);
    await tester.pumpAndSettle();
    expect(find.text('مش شغّال: أي حد معاه الموبايل يقدر يفتح أسرة'), findsOne);
    await tester.tap(find.byKey(const ValueKey('settings-app-lock')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app-lock-switch')));
    await tester.pumpAndSettle();

    // Too easy to guess: refused.
    await typePin(tester, '123456');
    expect(find.byKey(const ValueKey('setup-trivial')), findsOneWidget);
    await typePin(tester, '135792');
    expect(find.text('اكتب نفس الرقم السري تاني'), findsOneWidget);
    await typePin(tester, '135790');
    expect(find.byKey(const ValueKey('setup-mismatch')), findsOneWidget);
    await typePin(tester, '135792');
    await typePin(tester, '135792');
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
    expect(store.value, isNot(contains('135792')));

    // Tightening needs nothing…
    await tester.ensureVisible(find.byKey(const ValueKey('app-lock-timeout')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('على طول'));
    await tester.pumpAndSettle();
    expect(lock.timeout, LockTimeout.immediately);
    // …loosening needs the PIN.
    await tester.tap(find.text('5 دقايق'));
    await tester.pumpAndSettle();
    expect(find.text('أكّد إنه إنت'), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(lock.timeout, LockTimeout.immediately);
    await tester.tap(find.text('5 دقايق'));
    await tester.pumpAndSettle();
    await typePin(tester, '135792');
    expect(lock.timeout, LockTimeout.fiveMinutes);

    // Turning it off asks for the PIN first.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('app-lock-switch')),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app-lock-switch')));
    await tester.pumpAndSettle();
    await typePin(tester, '111111');
    expect(lock.enabled, isTrue);
    await typePin(tester, '135792');
    expect(lock.enabled, isFalse);
    expect(store.value, isNull);
  });

  group('a forgotten PIN can\'t lose everything', () {
    Future<AppLock> toSwitch(
      WidgetTester tester, {
      KeyValueStore? prefs,
    }) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final lock = await openLock(tester);
      await tester.pumpWidget(app(lock, prefs: prefs));
      await tester.pumpAndSettle();
      await tester.tap(find.text('المزيد').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-app-lock')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('app-lock-switch')));
      await tester.pumpAndSettle();
      return lock;
    }

    testWidgets('with records and no backup there\'s no way past: only make '
        'one, or cancel', (tester) async {
      await tester.runAsync(() => db.addProfile('جدو'));
      final lock = await toSwitch(tester);
      expect(find.text('لازم نسخة احتياطية الأول'), findsOneWidget);
      expect(find.textContaining('السجلات بتضيع'), findsOneWidget);
      expect(find.byKey(const ValueKey('pin-1')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('lock-backup-make')));
      await tester.pumpAndSettle();
      expect(location(tester), '/settings/backup');
      expect(find.byKey(const ValueKey('pin-1')), findsNothing);
      expect(lock.enabled, isFalse);
    });

    testWidgets('a recovery key alone isn\'t enough', (tester) async {
      await tester.runAsync(() async {
        await keys.write(RecoveryKey.generate());
        await db.addProfile('جدو');
      });
      final lock = await toSwitch(tester);
      expect(find.text('لازم نسخة احتياطية الأول'), findsOneWidget);
      expect(find.byKey(const ValueKey('pin-1')), findsNothing);
      expect(lock.enabled, isFalse);
    });

    testWidgets('cancelling leaves the lock off', (tester) async {
      final lock = await toSwitch(tester);
      await tester.tap(find.byKey(const ValueKey('lock-no-backup-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pin-1')), findsNothing);
      expect(lock.enabled, isFalse);
    });

    testWidgets('with no records there\'s no backup to offer yet, and no PIN', (
      tester,
    ) async {
      final lock = await toSwitch(tester);
      expect(find.text('العيلة الأول'), findsOneWidget);
      expect(find.byKey(const ValueKey('lock-backup-make')), findsNothing);
      expect(find.byKey(const ValueKey('pin-1')), findsNothing);
      expect(lock.enabled, isFalse);
    });

    testWidgets('with a backup it goes straight to choosing a PIN', (
      tester,
    ) async {
      await tester.runAsync(() => db.addProfile('جدو'));
      await toSwitch(tester, prefs: backedUp());
      expect(find.byKey(const ValueKey('lock-no-backup')), findsNothing);
      expect(find.byKey(const ValueKey('pin-1')), findsOneWidget);
    });

    testWidgets('a backup made before anyone was added doesn\'t count while '
        'the family is empty', (tester) async {
      final lock = await toSwitch(tester, prefs: backedUp());
      expect(find.text('العيلة الأول'), findsOneWidget);
      expect(find.byKey(const ValueKey('pin-1')), findsNothing);
      expect(lock.enabled, isFalse);
    });

    testWidgets('choosing to back up brings Home\'s offer back, even after '
        '"Not now"', (tester) async {
      await tester.runAsync(() => db.addProfile('جدو'));
      final prefs = MemoryKeyValueStore({
        PrefKeys.tutorialSeen: true,
        PrefKeys.appLockOffered: true,
      });
      await toSwitch(tester, prefs: prefs);
      await tester.tap(find.byKey(const ValueKey('lock-backup-make')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(prefs.getBool(PrefKeys.appLockOffered), isFalse);
    });

    testWidgets('someone whose lock was on before the rule keeps it, is '
        'warned, and can still change the PIN and turn it off', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final lock = await lockedWith(tester, '258046');
      await tester.pumpWidget(app(lock));
      await tester.pumpAndSettle();
      // No backup, and it still opens.
      expect(find.byKey(const ValueKey('lock-screen')), findsOneWidget);
      await typePin(tester, '258046');
      expect(lock.locked, isFalse);
      expect(lock.enabled, isTrue);

      await tester.tap(find.text('المزيد').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-app-lock')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('app-lock-no-backup-warning')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('app-lock-change')));
      await tester.pumpAndSettle();
      await typePin(tester, '258046');
      expect(find.byKey(const ValueKey('lock-no-backup')), findsNothing);
      await typePin(tester, '730184');
      await typePin(tester, '730184');
      expect(lock.enabled, isTrue);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('app-lock-switch')));
      await tester.pumpAndSettle();
      await typePin(tester, '730184');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(lock.enabled, isFalse);
      expect(
        find.byKey(const ValueKey('app-lock-no-backup-warning')),
        findsNothing,
      );
    });

    testWidgets('no warning when the lock is on and there\'s a backup', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final lock = await lockedWith(tester, '258046');
      await tester.pumpWidget(app(lock, prefs: backedUp()));
      await tester.pumpAndSettle();
      await typePin(tester, '258046');
      await tester.tap(find.text('المزيد').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-app-lock')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('app-lock-no-backup-warning')),
        findsNothing,
      );
    });
  });

  group('Home\'s offer of the lock', () {
    final offer = find.byKey(const ValueKey('app-lock-offer'));

    Future<AppLock> toHome(WidgetTester tester, KeyValueStore prefs) async {
      tester.view.physicalSize = const Size(1170, 4200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.runAsync(() => db.addProfile('جدو'));
      final lock = await openLock(tester);
      await tester.pumpWidget(app(lock, prefs: prefs));
      await tester.pumpAndSettle();
      return lock;
    }

    testWidgets('stays away until there\'s a backup', (tester) async {
      await toHome(tester, MemoryKeyValueStore({PrefKeys.tutorialSeen: true}));
      expect(offer, findsNothing);
    });

    testWidgets('shows after a backup, and turning it on goes to the PIN and '
        'then away', (tester) async {
      final lock = await toHome(tester, backedUp());
      expect(lock.enabled, isFalse);
      await tester.tap(find.byKey(const ValueKey('app-lock-offer-yes')));
      await tester.pumpAndSettle();
      await typePin(tester, '730184');
      await typePin(tester, '730184');
      await tester.tap(find.byKey(const ValueKey('setup-biometrics-no')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      expect(lock.enabled, isTrue);
      expect(offer, findsNothing);
    });

    testWidgets('"Not now" hides it for good; it stays in More', (
      tester,
    ) async {
      final prefs = backedUp();
      final lock = await toHome(tester, prefs);
      final skip = find.byKey(const ValueKey('app-lock-offer-skip'));
      await tester.tap(skip);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(offer, findsNothing);
      expect(lock.enabled, isFalse);
      expect(prefs.getBool(PrefKeys.appLockOffered), isTrue);
      await tester.tap(find.text('المزيد').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-app-lock')), findsOneWidget);
    });

    testWidgets('someone who said no to the old first-run offer isn\'t asked '
        'again', (tester) async {
      final prefs = backedUp()..setBool(PrefKeys.appLockOffered, true);
      await toHome(tester, prefs);
      expect(offer, findsNothing);
    });

    testWidgets('it doesn\'t come back after the lock is turned on and later '
        'off', (tester) async {
      final prefs = backedUp();
      final lock = await toHome(tester, prefs);
      await tester.tap(find.byKey(const ValueKey('app-lock-offer-yes')));
      await tester.pumpAndSettle();
      await typePin(tester, '730184');
      await typePin(tester, '730184');
      await tester.tap(find.byKey(const ValueKey('setup-biometrics-no')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      expect(lock.enabled, isTrue);
      expect(prefs.getBool(PrefKeys.appLockOffered), isTrue);
      await tester.runAsync(lock.disable);
      await tester.pumpAndSettle();
      expect(offer, findsNothing);
    });

    testWidgets(
      'Simple Mode warns on Home when the lock is on with no backup',
      (tester) async {
        tester.view.physicalSize = const Size(1170, 4200);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final lock = await lockedWith(tester, '258046');
        await tester.pumpWidget(
          app(
            lock,
            prefs: MemoryKeyValueStore({
              PrefKeys.tutorialSeen: true,
              PrefKeys.simpleMode: true,
              PrefKeys.elderTutorialSeen: true,
            }),
          ),
        );
        await tester.pumpAndSettle();
        await typePin(tester, '258046');
        expect(
          find.byKey(const ValueKey('app-lock-no-backup-warning')),
          findsOneWidget,
        );
        expect(offer, findsNothing);
      },
    );

    testWidgets('Simple Mode gets it on its Home too', (tester) async {
      await toHome(
        tester,
        backedUp()
          ..setBool(PrefKeys.simpleMode, true)
          ..setBool(PrefKeys.elderTutorialSeen, true),
      );
      expect(offer, findsOneWidget);
      expect(find.byKey(const ValueKey('simple-greeting')), findsOneWidget);
    });
  });

  testWidgets('a card on the lock screen says what shows and needs the PIN', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final id = (await tester.runAsync(() => db.addProfile('جدو')))!;
    final lock = await lockedWith(tester, '730184');
    await tester.pumpWidget(app(lock, prefs: backedUp()));
    await tester.pumpAndSettle();
    await typePin(tester, '730184');
    await tester.tap(find.text('المزيد').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-app-lock')));
    await tester.pumpAndSettle();

    final person = find.byKey(ValueKey('app-lock-emergency-$id'));
    await tester.scrollUntilVisible(
      person,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(person);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('emergency-lock-confirm')),
      findsOneWidget,
    );
    expect(lock.emergencyProfiles, isEmpty);
    await tester.tap(find.byKey(const ValueKey('emergency-lock-yes')));
    await tester.pumpAndSettle();
    expect(find.text('أكّد إنه إنت'), findsOneWidget);
    await typePin(tester, '730184');
    expect(lock.emergencyProfiles, {id});
  });

  group('what counts as a backup', () {
    bool hasBackup(AutoBackupSettings settings, [KeyValueStore? prefs]) {
      final container = ProviderContainer(
        overrides: [
          autoBackupStoreProvider.overrideWithValue(
            AutoBackupStore.memory(settings),
          ),
          if (prefs != null) keyValueStoreProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);
      return container.read(hasBackupProvider);
    }

    test('one sent somewhere, or restored from', () {
      expect(hasBackup(const AutoBackupSettings(), backedUp()), isTrue);
    });

    test('one that landed in the automatic folder', () {
      expect(hasBackup(AutoBackupSettings(lastAt: DateTime(2026))), isTrue);
    });

    test('not a failed automatic attempt, or just having it switched on', () {
      expect(
        hasBackup(
          AutoBackupSettings(
            enabled: true,
            enabledAt: DateTime(2026),
            lastAttemptAt: DateTime(2026),
            failure: AutoBackupFailure.folderMissing,
          ),
        ),
        isFalse,
      );
    });
  });

  testWidgets('a lock that can\'t be read stays locked and says try again', (
    tester,
  ) async {
    final flaky = FlakyLockStore();
    store = flaky;
    await lockedWith(tester, '258046');
    flaky.failReads = 2;
    final lock = await openLock(tester);
    await tester.pumpWidget(app(lock));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lock-screen')), findsOneWidget);
    expect(
      find.text('مقدرناش نقرا القفل دلوقتي. جرّب تاني كمان شوية.'),
      findsOneWidget,
    );

    await typePin(tester, '258046');
    expect(lock.locked, isTrue);
    // Readable now: the pad works and the real PIN opens.
    await typePin(tester, '258046');
    expect(lock.locked, isFalse);
  });
}
