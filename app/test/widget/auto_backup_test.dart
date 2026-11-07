import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:usra/app.dart';
import 'package:usra/core/backup/auto_backup.dart';
import 'package:usra/core/backup/auto_backup_runner.dart';
import 'package:usra/core/backup/backup_folder.dart';
import 'package:usra/core/backup/backup_service.dart';
import 'package:usra/core/backup/recovery_key.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/files/photo_crypto.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/core/routing/app_router.dart';
import 'package:usra/features/backup/backup_providers.dart';
import 'package:usra/features/backup/backup_screen.dart';

/// Hands back a small ready-made file instead of packing the database.
class _FakeBackupService extends BackupService {
  _FakeBackupService(Directory dir)
    : super(
        root: dir,
        databaseName: 'usra.sqlite',
        deviceKey: '0' * 64,
        photoKeys: PhotoKeys.ready(PhotoCipher(List.filled(32, 0))),
        temporary: dir,
        folders: const [],
      );

  final made = <RecoveryKey>[];

  /// Held open to look at the app while a backup runs.
  Completer<void>? hold;

  @override
  Future<CreatedBackup> create(
    AppDatabase db,
    RecoveryKey key, {
    required String appVersion,
    DateTime? now,
  }) async {
    made.add(key);
    await hold?.future;
    final file = File(p.join(root.path, 'made.usra'))
      ..writeAsBytesSync(List.filled(3 * 1024 * 1024, 7));
    return CreatedBackup(file);
  }

  @override
  Future<void> discardCreated(CreatedBackup backup) async {}
}

class _FakeFolder implements BackupFolderAccess {
  PickedFolder? nextPick = const PickedFolder(
    folder: BackupFolder(id: 'tree', name: 'Usra backups', onThisPhone: true),
  );
  BackupFolderProblem? pickProblem;
  BackupFolderProblem? inspectProblem;
  BackupFolderProblem? writeProblem;
  var picks = 0;
  final files = <String, int>{};
  final released = <String>[];

  @override
  Future<PickedFolder?> pick() async {
    picks++;
    if (pickProblem case final problem?) throw BackupFolderException(problem);
    return nextPick;
  }

  @override
  Future<FolderStatus> inspect(String id) async {
    if (inspectProblem case final problem?) {
      throw BackupFolderException(problem);
    }
    return const FolderStatus();
  }

  @override
  Future<void> write(String id, String sourcePath, String name) async {
    if (writeProblem case final problem?) throw BackupFolderException(problem);
    files[name] = File(sourcePath).lengthSync();
  }

  @override
  Future<int> verify(String id, String sourcePath, String name) async =>
      files[name]!;

  @override
  Future<void> rename(String id, String from, String to) async {
    files[to] = files.remove(from)!;
  }

  @override
  Future<void> delete(String id, String name) async => files.remove(name);

  @override
  Future<List<FolderEntry>> list(String id) async => [
    for (final e in files.entries) FolderEntry(e.key, e.value),
  ];

  @override
  Future<void> release(String id) async => released.add(id);

  @override
  Future<bool> protectedDataAvailable() async => true;
}

void main() {
  late AppDatabase db;
  late MemoryRecoveryKeyStore keys;
  late MemoryKeyValueStore prefs;
  late _FakeBackupService service;
  late _FakeFolder folder;
  late AutoBackupStore store;
  late BackupGate gate;
  late Directory dir;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    keys = MemoryRecoveryKeyStore(RecoveryKey.generate());
    prefs = MemoryKeyValueStore({
      PrefKeys.tutorialSeen: true,
      PrefKeys.elderTutorialSeen: true,
    });
    dir = Directory.systemTemp.createTempSync('usra_auto_widget');
    service = _FakeBackupService(dir);
    folder = _FakeFolder();
    store = AutoBackupStore.memory();
    gate = BackupGate();
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Widget app({
    List<Override> extra = const [],
    Duration startDelay = Duration.zero,
  }) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      keyValueStoreProvider.overrideWithValue(prefs),
      recoveryKeyStoreProvider.overrideWithValue(keys),
      backupServiceProvider.overrideWithValue(service),
      backupFolderAccessProvider.overrideWithValue(folder),
      autoBackupStoreProvider.overrideWithValue(store),
      backupGateProvider.overrideWithValue(gate),
      autoBackupStartDelayProvider.overrideWithValue(startDelay),
      ...extra,
    ],
    child: const UsraApp(),
  );

  Future<ProviderContainer> open(WidgetTester tester, [String? path]) async {
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Navigator).first);
    final container = ProviderScope.containerOf(context);
    if (path != null) {
      container.read(routerProvider).go(path);
      await tester.pumpAndSettle();
    }
    return container;
  }

  // Backups read and write real files, which the fake clock of a widget test
  // doesn't wait for.
  Future<void> settleBackup(WidgetTester tester) async {
    var quiet = 0;
    for (var i = 0; i < 200 && quiet < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      quiet = gate.busy ? 0 : quiet + 1;
    }
    await tester.pumpAndSettle();
  }

  AutoBackupSettings on({
    bool enabled = true,
    AutoBackupFailure? failure,
    bool? onThisPhone = true,
    DateTime? lastAt,
    int? lastSize,
  }) => AutoBackupSettings(
    enabled: enabled,
    folder: BackupFolder(
      id: 'tree',
      name: 'Usra backups',
      onThisPhone: onThisPhone,
    ),
    tag: 'abcd1234',
    enabledAt: DateTime.now(),
    failure: failure,
    lastAt: lastAt ?? DateTime.now(),
    lastSize: lastSize ?? 1024,
  );

  testWidgets('turning it on with a key: pick a folder, back up, show it', (
    tester,
  ) async {
    await open(tester, backupPath);
    expect(find.byKey(const ValueKey('backup-auto-folder')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('backup-auto-toggle')));
    await settleBackup(tester);

    expect(folder.picks, 1);
    expect(service.made, hasLength(1));
    expect(folder.files.keys.single, startsWith('usra-auto-'));
    expect(folder.files.keys.single, endsWith('.usra'));
    final settings = store.current;
    expect(settings.enabled, isTrue);
    expect(settings.frequency, BackupFrequency.weekly);
    expect(settings.lastSize, 3 * 1024 * 1024);

    // Date and size, in Arabic, with the folder's name.
    expect(find.textContaining('آخر نسخة تلقائية:'), findsOneWidget);
    expect(find.textContaining('ميجابايت'), findsOneWidget);
    expect(find.text('Usra backups'), findsOneWidget);
    // On the phone itself: said plainly, and Drive's route is explained.
    expect(find.byKey(const ValueKey('backup-auto-on-phone')), findsOneWidget);
    expect(find.byKey(const ValueKey('backup-auto-hint')), findsOneWidget);
    expect(
      Directionality.of(
        tester.element(find.byKey(const ValueKey('backup-auto-toggle'))),
      ),
      TextDirection.rtl,
    );
  });

  testWidgets('no recovery key: guided through it first, then the folder', (
    tester,
  ) async {
    keys = MemoryRecoveryKeyStore();
    await open(tester, backupPath);
    await tester.tap(find.byKey(const ValueKey('backup-auto-toggle')));
    await tester.pumpAndSettle();

    // Explains why before anything else, and asks for no folder yet.
    expect(find.text('الأول، مفتاح الاسترجاع'), findsOneWidget);
    expect(folder.picks, 0);
    await tester.tap(find.byKey(const ValueKey('backup-auto-key-continue')));
    await tester.pumpAndSettle();

    final groups = [
      for (var n = 1; n <= 6; n++)
        tester.widget<Text>(find.byKey(ValueKey('recovery-group-$n'))).data!,
    ];
    await tester.tap(find.byKey(const ValueKey('recovery-key-written')));
    await tester.pumpAndSettle();
    for (var n = 1; n <= 6; n++) {
      final field = find.byKey(ValueKey('recovery-confirm-$n'));
      if (field.evaluate().isNotEmpty) {
        await tester.enterText(field, groups[n - 1]);
      }
    }
    await tester.tap(find.byKey(const ValueKey('recovery-confirm')));
    await settleBackup(tester);

    expect(await keys.read(), isNotNull);
    expect(folder.picks, 1);
    expect(store.current.enabled, isTrue);
    expect(folder.files, hasLength(1));
    // The key is in secure storage only.
    final digits = (await keys.read())!.digits;
    expect(store.current.toJson().toString(), isNot(contains(digits)));
    expect(folder.files.keys.single, isNot(contains(digits)));
  });

  testWidgets('backing out of the key leaves it off', (tester) async {
    keys = MemoryRecoveryKeyStore();
    await open(tester, backupPath);
    await tester.tap(find.byKey(const ValueKey('backup-auto-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();
    expect(store.current.enabled, isFalse);
    expect(folder.picks, 0);
  });

  testWidgets('cancelling the picker leaves it off', (tester) async {
    folder.nextPick = null;
    await open(tester, backupPath);
    await tester.tap(find.byKey(const ValueKey('backup-auto-toggle')));
    await tester.pumpAndSettle();
    expect(store.current.enabled, isFalse);
    expect(store.current.folder, isNull);
    expect(service.made, isEmpty);
  });

  testWidgets('iCloud is refused with a plain explanation', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    folder.nextPick = const PickedFolder(
      folder: BackupFolder(id: '', name: 'Backups', onThisPhone: null),
      path:
          '/private/var/mobile/Library/Mobile Documents/com~apple~CloudDocs/B',
    );
    await open(tester, backupPath);
    await tester.tap(find.byKey(const ValueKey('backup-auto-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('backup-icloud-refused')), findsOneWidget);
    expect(find.textContaining('Apple'), findsOneWidget);
    expect(store.current.enabled, isFalse);
    expect(store.current.folder, isNull);
    expect(service.made, isEmpty);
    expect(folder.files, isEmpty);

    // The person can then choose another place.
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    folder.nextPick = const PickedFolder(
      folder: BackupFolder(id: 'bm', name: 'Dropbox', onThisPhone: null),
      path: '/private/var/mobile/Containers/Shared/AppGroup/1/File Provider Storage/x',
    );
    await tester.tap(find.byKey(const ValueKey('backup-auto-toggle')));
    await settleBackup(tester);
    expect(store.current.enabled, isTrue);
    expect(find.byKey(const ValueKey('backup-auto-on-phone')), findsNothing);
    // Can't tell where it is on iOS: says what to choose.
    expect(find.textContaining('On My iPhone'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a place that can\'t hold backups is refused too', (
    tester,
  ) async {
    folder.pickProblem = BackupFolderProblem.cantUse;
    await open(tester, backupPath);
    await tester.tap(find.byKey(const ValueKey('backup-auto-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('backup-folder-refused')), findsOneWidget);
    expect(store.current.enabled, isFalse);
  });

  testWidgets('how often can be changed', (tester) async {
    store = AutoBackupStore.memory(on());
    await open(tester, backupPath);
    expect(find.text('كل أسبوع'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('backup-auto-frequency')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('backup-frequency-monthly')));
    await tester.pumpAndSettle();
    expect(store.current.frequency, BackupFrequency.monthly);
    expect(find.text('كل شهر'), findsOneWidget);
  });

  testWidgets('a new folder replaces the old one and lets go of it', (
    tester,
  ) async {
    store = AutoBackupStore.memory(on());
    folder.nextPick = const PickedFolder(
      folder: BackupFolder(id: 'other', name: 'Other', onThisPhone: true),
    );
    await open(tester, backupPath);
    await tester.tap(find.byKey(const ValueKey('backup-auto-folder')));
    await settleBackup(tester);
    expect(store.current.folder!.id, 'other');
    expect(folder.released, ['tree']);
    // Not left empty until the next one is due.
    expect(service.made, hasLength(1));
    expect(folder.files, hasLength(1));
  });

  testWidgets('turning it off stays off and keeps the files', (tester) async {
    store = AutoBackupStore.memory(on());
    folder.files['usra-auto-abcd1234-20261101-100000.usra'] = 5;
    await open(tester, backupPath);
    await tester.tap(find.byKey(const ValueKey('backup-auto-toggle')));
    await tester.pumpAndSettle();
    expect(store.current.enabled, isFalse);
    expect(folder.files, hasLength(1));
    expect(find.byKey(const ValueKey('backup-auto-folder')), findsNothing);
  });

  testWidgets('"Back up now" runs, shows quiet progress, and blocks others', (
    tester,
  ) async {
    store = AutoBackupStore.memory(on());
    service.hold = Completer<void>();
    await open(tester, backupPath);
    await tester.tap(find.byKey(const ValueKey('backup-auto-now')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('backup-auto-progress')), findsOneWidget);
    expect(gate.busy, isTrue);
    // The run saves its own copy of the settings when it ends, so nothing
    // that changes them can be open during one.
    for (final row in ['backup-auto-frequency', 'backup-auto-folder']) {
      expect(tester.widget<ListTile>(find.byKey(ValueKey(row))).onTap, isNull);
    }
    // No sharing or restoring underneath a backup.
    final send = tester.widget<ButtonStyleButton>(
      find.byKey(const ValueKey('backup-now')),
    );
    expect(send.onPressed, isNull);

    service.hold!.complete();
    await settleBackup(tester);
    expect(find.byKey(const ValueKey('backup-auto-progress')), findsNothing);
    expect(folder.files, hasLength(1));
    expect(find.text('نسخة لمكان تاني'), findsOneWidget);
  });

  group('opening the app', () {
    testWidgets('a due backup starts by itself, without blocking', (
      tester,
    ) async {
      store = AutoBackupStore.memory(
        on().copyWith(lastAt: DateTime.now().subtract(const Duration(days: 8))),
      );
      await tester.runAsync(() => db.addProfile('فاطمة'));
      await tester.pumpWidget(app());
      await settleBackup(tester);
      // iOS can start the app in the background for a reminder's Taken
      // button, possibly locked: nothing runs until it's on screen.
      expect(service.made, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleBackup(tester);
      expect(service.made, hasLength(1));
      expect(folder.files, hasLength(1));
      expect(store.current.failure, isNull);
    });

    testWidgets('left during the short wait: nothing starts', (tester) async {
      store = AutoBackupStore.memory(
        on().copyWith(lastAt: DateTime.now().subtract(const Duration(days: 8))),
      );
      await tester.runAsync(() => db.addProfile('فاطمة'));
      tester.view.physicalSize = const Size(1170, 4000);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(startDelay: const Duration(seconds: 4)));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 5));
      await settleBackup(tester);
      expect(service.made, isEmpty);
    });

    testWidgets('not due: nothing happens', (tester) async {
      store = AutoBackupStore.memory(on());
      await open(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleBackup(tester);
      expect(service.made, isEmpty);
    });

    testWidgets('off: nothing happens', (tester) async {
      store = AutoBackupStore.memory(
        on(
          enabled: false,
        ).copyWith(lastAt: DateTime.now().subtract(const Duration(days: 40))),
      );
      await open(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleBackup(tester);
      expect(service.made, isEmpty);
    });

    testWidgets('nobody in the family: no empty backup', (tester) async {
      store = AutoBackupStore.memory(
        on().copyWith(lastAt: DateTime.now().subtract(const Duration(days: 8))),
      );
      await open(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleBackup(tester);
      expect(service.made, isEmpty);
    });

    testWidgets('records lost to a damaged database: paused, not backed up', (
      tester,
    ) async {
      store = AutoBackupStore.memory(
        on().copyWith(lastAt: DateTime.now().subtract(const Duration(days: 8))),
      );
      tester.view.physicalSize = const Size(1170, 4000);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(extra: [databaseRecoveredProvider.overrideWithValue(true)]),
      );
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleBackup(tester);
      expect(service.made, isEmpty);
      expect(store.current.enabled, isFalse);
      expect(store.current.failure, AutoBackupFailure.pausedForRecovery);
      final context = tester.element(find.byType(Navigator).first);
      final container = ProviderScope.containerOf(context);
      container.read(routerProvider).go(backupPath);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('backup-auto-paused')), findsOneWidget);

      // Turning it back on sticks when the person comes back to the app.
      await container.read(autoBackupProvider.notifier).enable();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(store.current.enabled, isTrue);
      expect(store.current.failure, isNull);
    });
  });

  group('when it fails', () {
    testWidgets('Home says so, and "try again" works', (tester) async {
      store = AutoBackupStore.memory(on(failure: AutoBackupFailure.noSpace));
      await open(tester);
      expect(find.byKey(const ValueKey('auto-backup-failed')), findsOneWidget);
      expect(
        find.text('مفيش مساحة كفاية للنسخة. فضّي شوية مساحة وحاول تاني.'),
        findsOneWidget,
      );

      await tester.tap(find.text('حاول تاني'));
      await tester.pump();
      await settleBackup(tester);
      expect(find.byKey(const ValueKey('auto-backup-failed')), findsNothing);
      expect(store.current.failure, isNull);
      expect(folder.files, hasLength(1));
    });

    testWidgets('a new failure shows up on Home with no details', (
      tester,
    ) async {
      store = AutoBackupStore.memory(on());
      folder.writeProblem = BackupFolderProblem.noSpace;
      final container = await open(tester);
      unawaited(container.read(autoBackupProvider.notifier).runNow());
      await tester.pump();
      await settleBackup(tester);
      expect(store.current.failure, AutoBackupFailure.noSpace);
      final notice = find.byKey(const ValueKey('auto-backup-failed'));
      expect(notice, findsOneWidget);
      expect(
        find.descendant(of: notice, matching: find.textContaining('.usra')),
        findsNothing,
      );
      expect(folder.files, isEmpty);
    });

    testWidgets('folder gone: choosing it again backs up', (tester) async {
      store = AutoBackupStore.memory(
        on(failure: AutoBackupFailure.folderMissing),
      );
      await open(tester);
      expect(find.text('اختيار فولدر'), findsOneWidget);
      await tester.tap(find.text('اختيار فولدر'));
      await settleBackup(tester);
      expect(folder.picks, 1);
      expect(store.current.failure, isNull);
      expect(folder.files, hasLength(1));
    });

    testWidgets('Simple Mode shows it too, in English as well', (tester) async {
      prefs = MemoryKeyValueStore({
        PrefKeys.tutorialSeen: true,
        PrefKeys.elderTutorialSeen: true,
        PrefKeys.simpleMode: true,
      });
      store = AutoBackupStore.memory(
        on(failure: AutoBackupFailure.interrupted),
      );
      final container = await open(tester);
      expect(find.byKey(const ValueKey('auto-backup-failed')), findsOneWidget);
      container.read(localeProvider.notifier).change(const Locale('en'));
      await tester.pumpAndSettle();
      expect(find.text('The automatic backup didn\'t finish'), findsOneWidget);
      expect(find.textContaining('removed next time'), findsOneWidget);
    });

    testWidgets('paused after recovery reaches Home, in Simple Mode too', (
      tester,
    ) async {
      prefs = MemoryKeyValueStore({
        PrefKeys.tutorialSeen: true,
        PrefKeys.elderTutorialSeen: true,
        PrefKeys.simpleMode: true,
      });
      store = AutoBackupStore.memory(
        on(enabled: false, failure: AutoBackupFailure.pausedForRecovery),
      );
      await open(tester);
      expect(find.byKey(const ValueKey('auto-backup-failed')), findsOneWidget);
      expect(find.text('النسخ التلقائي واقف'), findsOneWidget);
      await tester.tap(find.text('افتح النسخة الاحتياطية'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('backup-auto-paused')), findsOneWidget);
    });

    testWidgets('settings that couldn\'t be read are said on Home', (
      tester,
    ) async {
      await tester.runAsync(() async {
        File(p.join(dir.path, AutoBackupStore.fileName))
            .writeAsStringSync('{{');
        store = await AutoBackupStore.open(dir);
      });
      final container = await open(tester);
      expect(
        find.byKey(const ValueKey('auto-backup-unreadable')),
        findsOneWidget,
      );
      await tester.runAsync(
        () => container.read(autoBackupProvider.notifier).enable(),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('auto-backup-unreadable')),
        findsNothing,
      );
    });

    testWidgets('a drop in content is said on Home and can be accepted', (
      tester,
    ) async {
      prefs = MemoryKeyValueStore({
        PrefKeys.tutorialSeen: true,
        PrefKeys.elderTutorialSeen: true,
        PrefKeys.simpleMode: true,
      });
      store = AutoBackupStore.memory(
        on().copyWith(
          baselineCounts: const {'people': 4},
          latestCounts: const {'people': 1},
          contentDropped: true,
          heldBackups: const ['usra-auto-abcd1234-20261101-100000.usra'],
        ),
      );
      await open(tester);
      expect(
        find.byKey(const ValueKey('auto-backup-content-dropped')),
        findsOneWidget,
      );
      await tester.tap(find.text('افتح النسخة الاحتياطية'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('backup-content-restore')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('backup-content-accept')));
      await tester.pumpAndSettle();
      expect(store.current.contentDropped, isFalse);
      expect(store.current.heldBackups, isEmpty);
      expect(store.current.baselineCounts, {'people': 1});
      expect(find.byKey(const ValueKey('backup-content-accept')), findsNothing);
    });

    testWidgets('no notice while off, or while trying again', (tester) async {
      store = AutoBackupStore.memory(
        on(enabled: false, failure: AutoBackupFailure.noSpace),
      );
      await open(tester);
      expect(find.byKey(const ValueKey('auto-backup-failed')), findsNothing);
    });
  });

  group('the reminder about a copy off this phone', () {
    testWidgets('a folder on the phone doesn\'t quiet it', (tester) async {
      store = AutoBackupStore.memory(on());
      final container = await open(tester, backupPath);
      unawaited(container.read(autoBackupProvider.notifier).runNow());
      await tester.pump();
      await settleBackup(tester);
      expect(prefs.getInt(PrefKeys.lastBackupAt), isNull);
    });

    testWidgets('a folder off the phone counts', (tester) async {
      store = AutoBackupStore.memory(on(onThisPhone: false));
      final container = await open(tester, backupPath);
      unawaited(container.read(autoBackupProvider.notifier).runNow());
      await tester.pump();
      await settleBackup(tester);
      expect(prefs.getInt(PrefKeys.lastBackupAt), isNotNull);
    });

    testWidgets('where the phone can\'t tell, it doesn\'t count', (
      tester,
    ) async {
      store = AutoBackupStore.memory(on(onThisPhone: null));
      final container = await open(tester, backupPath);
      unawaited(container.read(autoBackupProvider.notifier).runNow());
      await tester.pump();
      await settleBackup(tester);
      expect(prefs.getInt(PrefKeys.lastBackupAt), isNull);
    });
  });

  testWidgets('the share sheet holding a backup holds off automatic ones', (
    tester,
  ) async {
    store = AutoBackupStore.memory(on());
    final sharing = Completer<void>();
    final container = await open(tester, backupPath);
    unawaited(
      gate.tryRun(() async {
        await sharing.future;
        return true;
      }),
    );
    await container.read(autoBackupProvider.notifier).runNow();
    expect(service.made, isEmpty);
    sharing.complete();
  });
}
