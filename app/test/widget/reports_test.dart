import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:usra/app.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/files/photo_store.dart';
import 'package:usra/core/log.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/features/children/growth.dart' show addMonths;
import 'package:usra/features/medicines/medicines_providers.dart';
import 'package:usra/features/medicines/reminders.dart';
import 'package:usra/features/reports/report.dart';
import 'package:usra/features/reports/report_share.dart';

import '../support/fake_reminder_scheduler.dart';
import '../support/sync_photo_store.dart';

void main() {
  late AppDatabase db;
  late Directory dir;
  late SyncSharedPhotoCache shareCache;
  late List<String> logs;
  final shared = <ShareParams>[];
  // What the other app got: each file's bytes, read while the sheet is open.
  final sharedBytes = <List<int>>[];
  ReportFonts? fonts;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    dir = Directory.systemTemp.createTempSync('usra_reports');
    shareCache = SyncSharedPhotoCache(Directory('${dir.path}/cache'));
    shared.clear();
    sharedBytes.clear();
    logs = [];
    Log.output = logs.add;
  });
  tearDown(() async {
    Log.output = debugPrint;
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Widget app({
    Future<ReportFonts> Function()? loadFonts,
    bool simple = false,
  }) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      if (simple)
        keyValueStoreProvider.overrideWithValue(
          MemoryKeyValueStore({
            PrefKeys.simpleMode: true,
            PrefKeys.elderTutorialSeen: true,
          }),
        ),
      reminderSchedulerProvider.overrideWithValue(
        FakeReminderScheduler(
          granted: const ReminderAccess(notifications: true),
        ),
      ),
      sharedPhotoCacheProvider.overrideWithValue(shareCache),
      // Loaded outside the fake clock (asset loading is real I/O).
      reportFontsProvider.overrideWithValue(loadFonts ?? () async => fonts!),
      shareProvider.overrideWithValue((p) async {
        shared.add(p);
        for (final f in p.files ?? <XFile>[]) {
          sharedBytes.add(File(f.path).readAsBytesSync());
        }
      }),
    ],
    child: const UsraApp(),
  );

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  /// Taps share, lets the PDF be made (real time: database reads and
  /// drawing), and accepts the share warning.
  Future<void> shareThroughWarning(WidgetTester tester, String key) async {
    await tapKey(tester, key);
    expect(find.byKey(const ValueKey('share-warning')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('share-warning-go')));
    for (var i = 0; i < 20 && shared.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    fonts = await ReportFonts.load();
  });

  testWidgets('doctor summary: pick sections, warned, shared as a PDF, '
      'file deleted after', (tester) async {
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    final id = (await tester.runAsync(
      () => db.addProfile(
        'هدى',
        birthDate: DateTime.utc(1960, 3, 1),
        allergies: 'بنسلين',
        conditions: 'سكر',
        bloodType: 'O+',
      ),
    ))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go('/family/$id');
    await tester.pumpAndSettle();
    await tapKey(tester, 'member-doctor-summary');
    expect(find.text('ملخص للدكتور'), findsWidgets);
    // An adult: no growth or vaccines to pick.
    expect(find.byKey(const ValueKey('summary-section-allergies')), findsOne);
    expect(find.byKey(const ValueKey('summary-section-growth')), findsNothing);
    expect(
      find.byKey(const ValueKey('summary-vaccination-record')),
      findsNothing,
    );

    // Untick everything: nothing to share.
    for (final s in [
      'basics',
      'allergies',
      'conditions',
      'medicines',
      'visits',
      'labs',
    ]) {
      await tapKey(tester, 'summary-section-$s');
    }
    expect(find.text('اختار حاجة واحدة على الأقل'), findsOneWidget);
    expect(
      tester
          .widget<ButtonStyleButton>(
            find.byKey(const ValueKey('summary-share')),
          )
          .onPressed,
      isNull,
    );
    await tapKey(tester, 'summary-section-allergies');
    await tapKey(tester, 'report-lang-en');

    await shareThroughWarning(tester, 'summary-share');
    expect(shared, hasLength(1));
    final file = shared.single.files!.single;
    expect(file.mimeType, 'application/pdf');
    // Anchored to the button on an iPad.
    expect(shared.single.sharePositionOrigin, isNotNull);
    // Says what it is, never whose.
    expect(file.name, doctorSummaryFile);
    expect(String.fromCharCodes(sharedBytes.single.take(4)), '%PDF');
    // Deleted once the sheet returned.
    expect(File(file.path).existsSync(), isFalse);
    expect(shareCache.dir.existsSync(), isFalse);
    // Nothing about her in the logs.
    expect(logs, isEmpty);
  });

  for (final dark in [false, true]) {
    testWidgets('doctor summary fits 320 px at text x2, '
        '${dark ? 'dark' : 'light'}', (tester) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(640, 6000);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      if (dark) {
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      }
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final id = (await tester.runAsync(
        () => db.addProfile(
          'هدى',
          birthDate: DateTime.utc(1960, 3, 1),
          allergies: 'بنسلين',
          conditions: 'سكر',
        ),
      ))!;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .go('/family/$id/doctor-summary');
      await tester.pumpAndSettle();
      // The sections sit in one grouped card, right to left.
      final section = find.byKey(const ValueKey('summary-section-allergies'));
      expect(section, findsOneWidget);
      expect(Directionality.of(tester.element(section)), TextDirection.rtl);
      expect(find.byKey(const ValueKey('summary-share')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cancelling the warning makes no file', (tester) async {
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    final id = (await tester.runAsync(() => db.addProfile('هدى')))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/family/$id/doctor-summary');
    await tester.pumpAndSettle();
    await tapKey(tester, 'summary-share');
    await tester.tap(find.byKey(const ValueKey('share-warning-cancel')));
    await tester.pumpAndSettle();
    expect(shared, isEmpty);
    expect(shareCache.dir.existsSync(), isFalse);
  });

  testWidgets('vaccination record from the vaccines page, in English', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    final today = DateUtils.dateOnly(DateTime.now());
    final kid = (await tester.runAsync(
      () =>
          db.addProfile('ليلى', birthDate: addMonths(today, -7), sex: 'female'),
    ))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/family/$kid/vaccines');
    await tester.pumpAndSettle();
    await tapKey(tester, 'vaccines-share-pdf');
    expect(find.byKey(const ValueKey('vaccination-pdf-dialog')), findsOne);
    await tapKey(tester, 'report-lang-en');
    await tapKey(tester, 'vaccination-pdf-notes');
    await shareThroughWarning(tester, 'vaccination-pdf-share');
    expect(shared, hasLength(1));
    expect(shared.single.files!.single.name, vaccinationRecordFile);
    expect(String.fromCharCodes(sharedBytes.single.take(4)), '%PDF');
    expect(shareCache.dir.existsSync(), isFalse);
    expect(logs, isEmpty);
  });

  testWidgets('no birth date: says so, no warning, no file', (tester) async {
    final id = (await tester.runAsync(() => db.addProfile('ليلى')))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/family/$id/vaccines');
    await tester.pumpAndSettle();
    await tapKey(tester, 'vaccines-share-pdf');
    expect(find.byKey(const ValueKey('vaccination-pdf-dialog')), findsNothing);
    expect(find.byKey(const ValueKey('share-warning')), findsNothing);
    expect(find.text('ضيف تاريخ الميلاد في البروفايل الأول.'), findsOneWidget);
    expect(shared, isEmpty);
  });

  testWidgets('Simple Mode: no choices, everything in, one button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    final today = DateUtils.dateOnly(DateTime.now());
    final kid = (await tester.runAsync(
      () => db.addProfile(
        'ليلى',
        birthDate: addMonths(today, -7),
        sex: 'female',
        allergies: 'بنسلين',
      ),
    ))!;
    await tester.pumpWidget(app(simple: true));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/family/$kid/doctor-summary');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('summary-section-allergies')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('report-language')), findsNothing);
    await shareThroughWarning(tester, 'summary-share');
    expect(shared.single.files!.single.name, doctorSummaryFile);

    // The vaccination record skips its options too.
    shared.clear();
    await tapKey(tester, 'summary-vaccination-record');
    expect(find.byKey(const ValueKey('vaccination-pdf-dialog')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('share-warning-go')));
    for (var i = 0; i < 20 && shared.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(shared.single.files!.single.name, vaccinationRecordFile);
    expect(shareCache.dir.existsSync(), isFalse);
  });

  testWidgets('a failure is logged without health data and says so', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    const secret = 'هدى بنسلين +201001234567';
    final id = (await tester.runAsync(
      () => db.addProfile('هدى', allergies: 'بنسلين'),
    ))!;
    await tester.pumpWidget(
      app(loadFonts: () async => throw StateError('Font for $secret')),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/family/$id/doctor-summary');
    await tester.pumpAndSettle();
    await tapKey(tester, 'summary-share');
    await tester.tap(find.byKey(const ValueKey('share-warning-go')));
    for (var i = 0; i < 20 && logs.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('معرفناش نعمل الملف'), findsOneWidget);
    expect(shared, isEmpty);
    expect(logs, ['[usra] Report PDF failed (StateError)']);
    expect(logs.join(), isNot(contains('هدى')));
    expect(logs.join(), isNot(contains('بنسلين')));
  });
}
