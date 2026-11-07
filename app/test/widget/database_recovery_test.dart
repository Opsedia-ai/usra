import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/backup/backup_service.dart';
import 'package:usra/core/backup/recovery_key.dart';
import 'package:usra/core/files/photo_crypto.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/core/screen_privacy.dart';
import 'package:usra/core/security/app_lock.dart';
import 'package:usra/core/security/data_wipe.dart';
import 'package:usra/features/settings/database_recovery.dart';

import '../support/fake_lock.dart';

class _Service extends BackupService {
  _Service(Directory dir)
    : super(
        root: dir,
        databaseName: 'usra.sqlite',
        deviceKey: '0' * 64,
        photoKeys: PhotoKeys.ready(PhotoCipher(List.filled(32, 0))),
        temporary: dir,
        folders: const [],
      );

  final staged = <int>[];

  @override
  Future<StagedRestore> stage(
    File backup,
    RecoveryKey key, {
    required int currentSchema,
  }) async {
    staged.add(currentSchema);
    return StagedRestore(
      BackupManifest(
        createdAt: DateTime(2026, 11, 1),
        appVersion: '1',
        schemaVersion: currentSchema,
        counts: const {'people': 3},
      ),
    );
  }

  @override
  Future<void> discardStaged() async {}
}

void main() {
  late Directory dir;
  late _Service service;
  var retries = 0;
  var restored = 0;
  var wiped = 0;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('usra_recovery');
    service = _Service(dir);
    retries = 0;
    restored = 0;
    wiped = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ScreenPrivacy.channel, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ScreenPrivacy.channel, null);
    dir.deleteSync(recursive: true);
  });

  Future<AppLock> lockedWith(WidgetTester tester, String pin) async {
    final store = MemoryLockStore();
    final clocks = FakeClocks();
    Future<AppLock> open() => AppLock.open(
      store: store,
      hasher: fastHasher,
      biometrics: FakeBiometrics(),
      clock: clocks.wall,
      ticks: clocks.ticks,
      uptime: clocks,
    );
    return (await tester.runAsync(() async {
      await (await open()).enable(pin, biometrics: false);
      return open();
    }))!;
  }

  Future<void> show(
    WidgetTester tester, {
    AppLock? lock,
    DatabaseProblem problem = DatabaseProblem.openFailed,
    bool failed = false,
    MemoryKeyValueStore? prefs,
    WipeOutcome? wipe,
  }) async {
    tester.view.physicalSize = const Size(1170, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      DatabaseRecoveryApp(
        problem: problem,
        onRetry: () async => retries++,
        backup: service,
        recoveryKeys: MemoryRecoveryKeyStore(),
        lock: lock ?? AppLock.off(),
        preferences: prefs ?? MemoryKeyValueStore(),
        restoreFailed: failed,
        wipeOutcome: wipe,
        restore: (staged, key) async => restored++,
        startFresh: () async => wiped++,
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder key(String k) => find.byKey(ValueKey(k));

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

  testWidgets('offers try again, restore, the support address to select, and '
      'starting fresh, in both languages', (tester) async {
    await show(tester);
    expect(key('database-key-retry'), findsOneWidget);
    expect(key('database-restore'), findsOneWidget);
    expect(key('database-start-fresh'), findsOneWidget);
    final address = tester.widget<SelectableText>(
      key('database-support-address'),
    );
    expect(address.data, 'aya@opsedia.ai');
    expect(find.textContaining('nothing was deleted'), findsOneWidget);
    expect(find.textContaining('متمسحتش'), findsOneWidget);
    expect(find.textContaining('آخر حل'), findsOneWidget);
    expect(find.textContaining('A last resort'), findsOneWidget);

    await tester.tap(key('database-key-retry'));
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('says so when the last restore didn\'t go in', (tester) async {
    await show(tester, failed: true);
    expect(key('database-restore-failed'), findsOneWidget);
    expect(find.textContaining('مقدرناش نرجّع النسخة'), findsOneWidget);
  });

  testWidgets('after starting fresh it doesn\'t claim nothing was deleted', (
    tester,
  ) async {
    await show(tester, wipe: WipeOutcome.incomplete);
    expect(find.byKey(const ValueKey('database-wipe-outcome')), findsOneWidget);
    expect(find.textContaining('nothing was deleted'), findsNothing);
    expect(find.textContaining('متمسحتش'), findsNothing);
  });

  testWidgets('restoring works with no router or database open', (
    tester,
  ) async {
    await show(tester, problem: DatabaseProblem.keyUnavailable);
    await tester.tap(key('database-restore'));
    await tester.pumpAndSettle();
    expect(key('restore-pick'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a restore runs end to end through the recovery shell', (
    tester,
  ) async {
    final file = File('${dir.path}/family.usra')..writeAsStringSync('x');
    final keyText = RecoveryKey.generate().groups.join(' ');
    tester.view.physicalSize = const Size(1170, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      DatabaseRecoveryApp(
        problem: DatabaseProblem.openFailed,
        onRetry: () async {},
        backup: service,
        recoveryKeys: MemoryRecoveryKeyStore(),
        lock: AppLock.off(),
        preferences: MemoryKeyValueStore(),
        restore: (staged, key) async => restored++,
        startFresh: () async {},
        pickBackup: () async => file.path,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(key('database-restore'));
    await tester.pumpAndSettle();
    await tester.tap(key('restore-pick'));
    await tester.pumpAndSettle();
    await tester.enterText(key('restore-key'), keyText);
    await tester.tap(key('restore-open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('restore-contents')), findsOneWidget);
    await tester.tap(key('restore-replace'));
    await tester.pumpAndSettle();
    expect(restored, 1);
    expect(service.staged, hasLength(1));
  });

  testWidgets('starting fresh names what is lost, needs the word, and has no '
      'way to go to a backup that can\'t be made', (tester) async {
    await show(tester);
    await tester.tap(key('database-start-fresh'));
    await tester.pumpAndSettle();
    expect(wiped, 0);
    expect(key('start-fresh-intro'), findsOneWidget);
    expect(find.textContaining('كل الأشخاص والسجلات والأدوية'), findsOneWidget);
    expect(find.textContaining('مينفعش يترجع'), findsOneWidget);
    expect(key('wipe-backup-first'), findsNothing);

    await tester.tap(key('wipe-confirm'), warnIfMissed: false);
    await tester.pump();
    expect(wiped, 0);

    await tester.enterText(key('wipe-confirm-word'), 'امسح');
    await tester.pump();
    await tester.tap(key('wipe-confirm'));
    await tester.pumpAndSettle();
    expect(wiped, 1);
  });

  testWidgets('going back from starting fresh changes nothing', (tester) async {
    await show(tester);
    await tester.tap(key('database-start-fresh'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(key('database-key-unavailable'), findsOneWidget);
    expect(wiped, 0);
  });

  group('with the app lock on', () {
    testWidgets('restore and starting fresh need the PIN', (tester) async {
      final lock = await lockedWith(tester, '258046');
      await show(tester, lock: lock);

      await tester.tap(key('database-restore'));
      await tester.pumpAndSettle();
      expect(key('restore-pick'), findsNothing);
      await typePin(tester, '258046');
      expect(key('restore-pick'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await tester.tap(key('database-start-fresh'));
      await tester.pumpAndSettle();
      await tester.enterText(key('wipe-confirm-word'), 'امسح');
      await tester.pump();
      await tester.tap(key('wipe-confirm'));
      await tester.pumpAndSettle();
      expect(wiped, 0);
      await typePin(tester, '258046');
      expect(wiped, 1);
    });

    testWidgets('a lock that can\'t be read doesn\'t strand them', (
      tester,
    ) async {
      final flaky = FlakyLockStore()..failReads = 100;
      final clocks = FakeClocks();
      final lock = (await tester.runAsync(
        () => AppLock.open(
          store: flaky,
          hasher: fastHasher,
          biometrics: FakeBiometrics(),
          clock: clocks.wall,
          ticks: clocks.ticks,
          uptime: clocks,
        ),
      ))!;
      expect(lock.unreadable, isTrue);
      await show(tester, lock: lock);
      await tester.tap(key('database-restore'));
      await tester.pumpAndSettle();
      expect(key('restore-pick'), findsOneWidget);
    });
  });
}
