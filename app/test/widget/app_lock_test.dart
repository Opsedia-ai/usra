import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/app.dart';
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

  Widget app(AppLock lock, {KeyValueStore? prefs}) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      appLockProvider.overrideWithValue(lock),
      recoveryKeyStoreProvider.overrideWithValue(keys),
      if (prefs != null) keyValueStoreProvider.overrideWithValue(prefs),
    ],
    child: const UsraApp(),
  );

  /// Goes through the recovery key screen: written down, two groups back.
  Future<void> makeRecoveryKey(WidgetTester tester) async {
    final groups = [
      for (var n = 1; n <= 6; n++)
        tester
            .widget<Text>(
              find.byKey(ValueKey('recovery-group-$n'), skipOffstage: false),
            )
            .data!,
    ];
    await tester.ensureVisible(
      find.byKey(const ValueKey('recovery-key-written'), skipOffstage: false),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('recovery-key-written')));
    await tester.pumpAndSettle();
    for (var n = 1; n <= 6; n++) {
      final field = find.byKey(ValueKey('recovery-confirm-$n'));
      if (field.evaluate().isNotEmpty) {
        await tester.enterText(field, groups[n - 1]);
      }
    }
    await tester.tap(find.byKey(const ValueKey('recovery-confirm')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

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
      () async => (await db.addProfile('جدو'), await db.addProfile('منى')),
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

    // No backup and no key yet: the key comes first.
    await tester.tap(find.byKey(const ValueKey('lock-backup-skip')));
    await tester.pumpAndSettle();
    await makeRecoveryKey(tester);

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

  group('a forgotten PIN can\'t lose everything unannounced', () {
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

    testWidgets('leaving the recovery key screen leaves the lock off, with '
        'no PIN pad', (tester) async {
      final lock = await toSwitch(tester);
      expect(find.byKey(const ValueKey('lock-no-backup')), findsOneWidget);
      expect(find.textContaining('السجلات بتضيع'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lock-backup-skip')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('recovery-key-written'), skipOffstage: false),
        findsOneWidget,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pin-1')), findsNothing);
      expect(lock.enabled, isFalse);
      expect(store.value, isNull);
    });

    testWidgets('cancelling the warning leaves the lock off', (tester) async {
      final lock = await toSwitch(tester);
      await tester.tap(find.byKey(const ValueKey('lock-no-backup-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pin-1')), findsNothing);
      expect(lock.enabled, isFalse);
    });

    testWidgets('with no records there\'s no backup to offer, only the key', (
      tester,
    ) async {
      await toSwitch(tester);
      expect(find.byKey(const ValueKey('lock-backup-make')), findsNothing);
      expect(find.byKey(const ValueKey('lock-backup-skip')), findsOneWidget);
    });

    testWidgets('with a key but no backup it warns, then asks for the PIN', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await keys.write(RecoveryKey.generate());
        await db.addProfile('جدو');
      });
      await toSwitch(tester);
      expect(find.text('تعمل نسخة احتياطية الأول؟'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lock-backup-skip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('recovery-key-written')), findsNothing);
      expect(find.byKey(const ValueKey('pin-1')), findsOneWidget);
    });

    testWidgets('with a key and no records it warns without asking for a '
        'backup it can\'t offer', (tester) async {
      await tester.runAsync(() => keys.write(RecoveryKey.generate()));
      await toSwitch(tester);
      expect(find.text('تعمل نسخة احتياطية الأول؟'), findsNothing);
      expect(find.text('لو نسيت الرقم السري'), findsWidgets);
      expect(find.byKey(const ValueKey('lock-backup-make')), findsNothing);
    });

    testWidgets('with a backup it goes straight to choosing a PIN', (
      tester,
    ) async {
      await toSwitch(
        tester,
        prefs: MemoryKeyValueStore({
          PrefKeys.tutorialSeen: true,
          PrefKeys.lastBackupAt: 1,
        }),
      );
      expect(find.byKey(const ValueKey('lock-no-backup')), findsNothing);
      expect(find.byKey(const ValueKey('pin-1')), findsOneWidget);
    });

    testWidgets('the offer after the elder tour turns nothing on by itself', (
      tester,
    ) async {
      final lock = await openLock(tester);
      final prefs = MemoryKeyValueStore({
        PrefKeys.simpleMode: true,
        PrefKeys.tutorialSeen: true,
        PrefKeys.elderTutorialSeen: true,
      });
      await tester.pumpWidget(app(lock, prefs: prefs));
      await tester.pumpAndSettle();
      ProviderScope.containerOf(tester.element(find.byType(Navigator).first))
          .read(routerProvider)
          .go(appLockOfferPath);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('app-lock-offer')), findsOneWidget);
      expect(lock.enabled, isFalse);
      final skip = find.byKey(const ValueKey('app-lock-offer-skip'));
      await tester.ensureVisible(skip);
      await tester.pumpAndSettle();
      await tester.tap(skip);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(lock.enabled, isFalse);
      expect(prefs.getBool(PrefKeys.appLockOffered), isTrue);
    });
  });

  testWidgets('with records and no backup, turning it on suggests one', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final id = (await tester.runAsync(() => db.addProfile('جدو')))!;
    final lock = await openLock(tester);
    await tester.pumpWidget(app(lock));
    await tester.pumpAndSettle();
    await tester.tap(find.text('المزيد').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-app-lock')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('app-lock-switch')));
    await tester.pumpAndSettle();
    expect(find.text('مفتاح الاسترجاع الأول'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lock-backup-make')));
    await tester.pumpAndSettle();
    expect(location(tester), '/settings/backup');
    expect(lock.enabled, isFalse);

    // Or carry on without one, once there's a recovery key.
    await tester.tap(find.text('المزيد').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-app-lock')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app-lock-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lock-backup-skip')));
    await tester.pumpAndSettle();
    await makeRecoveryKey(tester);
    await typePin(tester, '730184');
    await typePin(tester, '730184');
    await tester.tap(find.byKey(const ValueKey('setup-biometrics-no')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(lock.enabled, isTrue);

    // Showing someone's card on the lock screen needs the PIN.
    final person = find.byKey(ValueKey('app-lock-emergency-$id'));
    await tester.scrollUntilVisible(
      person,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(person);
    await tester.pumpAndSettle();
    expect(find.text('أكّد إنه إنت'), findsOneWidget);
    await typePin(tester, '730184');
    expect(lock.emergencyProfiles, {id});
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
