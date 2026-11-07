import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:usra/app.dart';
import 'package:usra/core/backup/backup_service.dart';
import 'package:usra/core/backup/recovery_key.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/core/files/photo_crypto.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/core/routing/app_router.dart';
import 'package:usra/core/screen_privacy.dart';
import 'package:usra/core/security/sensitive_clipboard.dart';
import 'package:usra/features/backup/backup_providers.dart';
import 'package:usra/features/backup/backup_screen.dart';

import '../support/fits.dart';

/// Hands back a ready-made file instead of packing the database.
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

  /// Photos the next backup says it left out.
  var skippedPhotos = 0;

  @override
  Future<CreatedBackup> create(
    AppDatabase db,
    RecoveryKey key, {
    required String appVersion,
    DateTime? now,
  }) async {
    made.add(key);
    return CreatedBackup(
      File('${root.path}/usra-backup-test.usra'),
      skippedPhotos: skippedPhotos,
    );
  }

  final discarded = <CreatedBackup>[];

  @override
  Future<void> discardCreated(CreatedBackup backup) async =>
      discarded.add(backup);

  final opened = <(String, RecoveryKey)>[];

  @override
  Future<StagedRestore> stage(
    File backup,
    RecoveryKey key, {
    required int currentSchema,
  }) async {
    opened.add((backup.path, key));
    return StagedRestore(
      BackupManifest(
        appVersion: '0.1.0+1',
        schemaVersion: currentSchema,
        createdAt: DateTime.utc(2026, 11, 3),
        counts: const {'people': 3, 'records': 12, 'medicines': 2, 'photos': 1},
      ),
    );
  }
}

void main() {
  late AppDatabase db;
  late MemoryRecoveryKeyStore keys;
  late MemoryKeyValueStore prefs;
  late _FakeBackupService service;
  late Directory dir;
  late List<ShareParams> shared;
  late ShareResultStatus shareStatus;
  late List<(StagedRestore, RecoveryKey)> restarted;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    keys = MemoryRecoveryKeyStore();
    prefs = MemoryKeyValueStore({
      PrefKeys.tutorialSeen: true,
      PrefKeys.elderTutorialSeen: true,
    });
    dir = Directory.systemTemp.createTempSync('usra_backup_widget');
    service = _FakeBackupService(dir);
    shared = [];
    shareStatus = ShareResultStatus.success;
    restarted = [];
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Widget app({List<Override> extra = const []}) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      keyValueStoreProvider.overrideWithValue(prefs),
      recoveryKeyStoreProvider.overrideWithValue(keys),
      backupServiceProvider.overrideWithValue(service),
      backupShareProvider.overrideWithValue((params) async {
        shared.add(params);
        return shareStatus;
      }),
      ...extra,
    ],
    child: const UsraApp(),
  );

  Future<void> go(WidgetTester tester, String path) async {
    final context = tester.element(find.byType(Navigator).first);
    ProviderScope.containerOf(context).read(routerProvider).go(path);
    await tester.pumpAndSettle();
  }

  String groupShown(WidgetTester tester, int n) =>
      tester.widget<Text>(find.byKey(ValueKey('recovery-group-$n'))).data!;

  testWidgets(
    'first backup makes a recovery key, checks two groups, then shares',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 3000);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('المزيد').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-backup')));
      await tester.pumpAndSettle();
      expect(find.text('لسه مفيش نسخة احتياطية'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('backup-now')));
      await tester.pumpAndSettle();

      // The key, six groups, and a plain warning about losing it.
      final groups = [for (var n = 1; n <= 6; n++) groupShown(tester, n)];
      final key = RecoveryKey.tryParse(groups.join());
      expect(key, isNotNull);
      expect(find.textContaining('ولا حتى إحنا'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('recovery-key-written')));
      await tester.pumpAndSettle();
      final asked = [
        for (var n = 1; n <= 6; n++)
          if (find.byKey(ValueKey('recovery-confirm-$n')).evaluate().isNotEmpty)
            n,
      ];
      expect(asked, hasLength(2));

      // A wrong group is caught, and nothing is saved.
      final wrong = groups[asked[0] - 1] == '000000' ? '111111' : '000000';
      await tester.enterText(
        find.byKey(ValueKey('recovery-confirm-${asked[0]}')),
        wrong,
      );
      await tester.enterText(
        find.byKey(ValueKey('recovery-confirm-${asked[1]}')),
        groups[asked[1] - 1],
      );
      await tester.tap(find.byKey(const ValueKey('recovery-confirm')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('recovery-confirm-error')),
        findsOneWidget,
      );
      expect(find.textContaining('المجموعة ${asked[0]}'), findsWidgets);
      expect(await keys.read(), isNull);

      // Typed right, with Arabic digits: saved, and the backup goes ahead.
      const arabic = '٠١٢٣٤٥٦٧٨٩';
      await tester.enterText(
        find.byKey(ValueKey('recovery-confirm-${asked[0]}')),
        groups[asked[0] - 1].split('').map((d) => arabic[int.parse(d)]).join(),
      );
      await tester.tap(find.byKey(const ValueKey('recovery-confirm')));
      await tester.pumpAndSettle();

      expect(await keys.read(), key);
      expect(service.made, [key]);
      // Not kept on the phone once shared (S11).
      expect(service.discarded, hasLength(1));
      expect(shared.single.files!.single.path, endsWith('.usra'));
      expect(prefs.getInt(PrefKeys.lastBackupAt), isNotNull);
      expect(find.textContaining('آخر نسخة احتياطية:'), findsOneWidget);

      // The next backup doesn't ask again.
      await tester.tap(find.byKey(const ValueKey('backup-now')));
      await tester.pumpAndSettle();
      expect(service.made, [key, key]);
      expect(find.byKey(const ValueKey('recovery-key-written')), findsNothing);
    },
  );

  testWidgets('a backup missing photos says so, not just "ready"', (
    tester,
  ) async {
    await keys.write(RecoveryKey.generate());
    service.skippedPhotos = 2;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await go(tester, '/settings/backup');
    await tester.tap(find.byKey(const ValueKey('backup-now')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final shown = tester
        .widget<Text>(find.byKey(const ValueKey('backup-done')))
        .data!;
    expect(shown, contains('صورتين'));
    expect(shown, contains('مقدرناش نفتحهم'));
  });

  testWidgets('Home reminds to back up once the family has someone in it', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('backup-due')), findsNothing);

    await tester.runAsync(() => db.addProfile('فاطمة'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('backup-due')), findsOneWidget);
    expect(find.textContaining('لو الموبايل ضاع'), findsOneWidget);

    // A recent backup: no reminder.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
    );
    await container
        .read(lastBackupProvider.notifier)
        .set(DateTime.now().subtract(const Duration(days: 3)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('backup-due')), findsNothing);

    // Over 30 days old: reminded again.
    await container
        .read(lastBackupProvider.notifier)
        .set(DateTime.now().subtract(const Duration(days: 31)));
    await tester.pumpAndSettle();
    expect(find.textContaining('أكتر من ٣٠ يوم'), findsOneWidget);
  });

  testWidgets('the recovery notice leads to restore, which checks the key', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        extra: [
          databaseRecoveredProvider.overrideWithValue(true),
          backupFilePickerProvider.overrideWithValue(
            () async => '${dir.path}/usra-backup-2026-11-03.usra',
          ),
          restoreAndRestartProvider.overrideWithValue(
            (staged, key) async => restarted.add((staged, key)),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final notice = find.byKey(const ValueKey('recovery-notice'));
    expect(notice, findsOneWidget);
    await tester.tap(
      find.descendant(of: notice, matching: find.byType(FilledButton)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('restore-pick')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('restore-pick')));
    await tester.pumpAndSettle();
    expect(find.text('usra-backup-2026-11-03.usra'), findsOneWidget);

    // Third group mistyped: said before even opening the file.
    final key = RecoveryKey.generate();
    final typed = [...key.groups];
    typed[2] =
        '${typed[2].substring(0, 5)}${(int.parse(typed[2][5]) + 1) % 10}';
    await tester.enterText(
      find.byKey(const ValueKey('restore-key')),
      typed.join(),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('restore-key')))
          .controller!
          .text,
      typed.join(' '),
    );
    await tester.tap(find.byKey(const ValueKey('restore-open')));
    await tester.pumpAndSettle();
    expect(find.textContaining('المجموعة 3 من المفتاح'), findsOneWidget);
    expect(service.opened, isEmpty);

    // Typed right: opened, what's inside is shown, then it's swapped in.
    await tester.enterText(
      find.byKey(const ValueKey('restore-key')),
      key.digits,
    );
    await tester.tap(find.byKey(const ValueKey('restore-open')));
    await tester.pumpAndSettle();
    expect(service.opened.single.$2, key);
    expect(find.text('3 أشخاص، 12 سجل، دوايين، صورة واحدة'), findsOneWidget);
    expect(restarted, isEmpty);
    expect(find.byKey(const ValueKey('restore-cancel')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('restore-replace')));
    await tester.pumpAndSettle();
    expect(restarted.single.$2, key);
    expect(restarted.single.$1.manifest.count('people'), 3);
  });

  testWidgets(
    'when Android can\'t tell, it asks whether the backup was saved',
    (tester) async {
      await keys.write(RecoveryKey.generate());
      shareStatus = ShareResultStatus.unavailable;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await go(tester, '/settings/backup');

      await tester.tap(find.byKey(const ValueKey('backup-now')));
      // The button's spinner keeps going behind the question.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('لأ'));
      await tester.pumpAndSettle();
      expect(prefs.getInt(PrefKeys.lastBackupAt), isNull);

      await tester.tap(find.byKey(const ValueKey('backup-now')));
      // The button's spinner keeps going behind the question.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('backup-saved-yes')));
      await tester.pumpAndSettle();
      expect(prefs.getInt(PrefKeys.lastBackupAt), isNotNull);
    },
  );

  testWidgets('after a restore Home says so', (tester) async {
    await tester.pumpWidget(
      app(
        extra: [
          restoreOutcomeProvider.overrideWithValue(RestoreOutcome.restored),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('رجّعنا نسختك الاحتياطية.'), findsOneWidget);
    // And the backup page is one step away.
    await go(tester, '/settings/backup');
    expect(find.byKey(const ValueKey('backup-now')), findsOneWidget);
  });

  group('screen privacy', () {
    late List<bool> secure;
    setUp(() => secure = []);

    Future<void> start(WidgetTester tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        ScreenPrivacy.channel,
        (call) async {
          if (call.method == 'setSecure') secure.add(call.arguments as bool);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          ScreenPrivacy.channel,
          null,
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
    }

    testWidgets('no screenshots of the recovery key', (tester) async {
      await start(tester);
      // "Block screenshots" is off by default.
      expect(secure, [false]);

      await go(tester, '$backupPath/key');
      expect(find.byKey(const ValueKey('recovery-group-1')), findsOneWidget);
      expect(secure, [false, true]);

      await go(tester, backupPath);
      expect(secure, [false, true, false]);

      // Restore, where the key is typed, too.
      await go(tester, '$backupPath/restore');
      expect(secure.last, isTrue);
    });

    testWidgets('the recovery key is copied only marked sensitive (S7)', (
      tester,
    ) async {
      final copied = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SensitiveClipboard.channel,
        (call) async {
          copied.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SensitiveClipboard.channel,
          null,
        ),
      );
      final key = RecoveryKey.generate();
      await keys.write(key);
      await start(tester);
      await go(tester, '$backupPath/key');
      // The digits can't be selected and copied the ordinary way.
      expect(find.byType(SelectableText), findsNothing);
      await tester.tap(find.byKey(const ValueKey('recovery-key-copy')));
      await tester.pumpAndSettle();
      expect(copied.single.method, 'copySensitive');
      expect(copied.single.arguments, key.groups.join(' '));
      expect(
        find.textContaining('هيتمسح من الحافظة بعد دقيقة'),
        findsOneWidget,
      );
    });

    testWidgets('Block screenshots and Discreet notifications in Settings', (
      tester,
    ) async {
      await start(tester);
      await go(tester, '/settings');
      Finder tile(String key) => find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(SwitchListTile),
      );
      final block = tile('settings-block-screenshots');
      final discreet = tile('settings-discreet');
      expect(tester.widget<SwitchListTile>(block).value, isFalse);
      expect(tester.widget<SwitchListTile>(discreet).value, isTrue);

      // The settings list is taller than the test screen.
      await tester.ensureVisible(block);
      await tester.pumpAndSettle();
      await tester.tap(block);
      await tester.pumpAndSettle();
      expect(secure, [false, true]);
      expect(prefs.getBool(PrefKeys.blockScreenshots), isTrue);
      // Leaving the recovery key keeps the whole app blocked.
      await go(tester, '$backupPath/key');
      await go(tester, backupPath);
      expect(secure, [false, true]);

      await go(tester, '/settings');
      await tester.ensureVisible(discreet);
      await tester.pumpAndSettle();
      await tester.tap(discreet);
      await tester.pumpAndSettle();
      expect(prefs.getBool(PrefKeys.discreetNotifications), isFalse);
      expect(find.text('تنبيهات من غير أسامي'), findsOneWidget);
    });
  });

  group('fits a small phone at double text', () {
    for (final locale in const ['ar', 'en']) {
      for (final theme in const [ThemeMode.light, ThemeMode.dark]) {
        for (final path in const [
          '/settings/backup',
          '/settings/backup/key',
          '/settings/backup/restore',
        ]) {
          testWidgets('$path, $locale, ${theme.name}', (tester) async {
            smallPhoneDoubleText(tester);
            await prefs.setString(PrefKeys.language, locale);
            await tester.pumpWidget(
              app(
                extra: [
                  themeModeProvider.overrideWith(() => _FixedTheme(theme)),
                ],
              ),
            );
            await tester.pumpAndSettle();
            await go(tester, path);
            await walkScreen(tester);
          });
        }
      }
    }
  });

  testWidgets('the main button comes before automatic backup, and there is no '
      'server option', (tester) async {
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await go(tester, '/settings/backup');
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('backup-now'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('backup-auto-toggle'))).dy,
      ),
    );
    expect(find.textContaining('سيرفر'), findsNothing);
    expect(find.byKey(const ValueKey('backup-restore')), findsOneWidget);
  });
}

class _FixedTheme extends ThemeModeController {
  _FixedTheme(this.mode);

  final ThemeMode mode;

  @override
  ThemeMode build() => mode;
}
