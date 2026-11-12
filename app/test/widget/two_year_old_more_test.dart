// The founder's walk of 12 Nov 2026, continued: the doctor summary,
// pregnancy, how fast the main pages open, and accessibility, for her
// daughter جميلة (born 12 Nov 2024, two today) with a full set of records.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/files/photo_store.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/features/follow_ups/follow_ups_providers.dart';
import 'package:usra/features/medicines/medicines_providers.dart';
import 'package:usra/features/reports/doctor_summary.dart';
import 'package:usra/features/reports/report.dart';
import 'package:usra/features/reports/report_share.dart';
import 'package:usra/l10n/app_localizations_ar.dart';

import '../support/fake_reminder_scheduler.dart';
import '../support/fits.dart';
import '../support/screen_harness.dart';
import '../support/sync_photo_store.dart';

final ar = AppLocalizationsAr();
final today10 = DateTime(2026, 11, 12, 10);
final birth = DateTime(2024, 11, 12);

Finder key(String k) => find.byKey(ValueKey(k));

String screenText(WidgetTester tester) => [
  for (final e in find.byType(RichText).evaluate())
    (e.widget as RichText).text.toPlainText(),
].join(' | ');

/// Everything the report holds, as one string.
String reportText(Report r) => [
  r.title,
  for (final f in r.fields) '${f.label}: ${f.value}',
  for (final s in r.sections) ...[
    s.heading,
    for (final f in s.fields) '${f.label}: ${f.value}',
    for (final row in s.rows) row.join(' / '),
    ?s.empty,
    ?s.note,
  ],
].join('\n');

void main() {
  late ScreenHarness h;
  var now = today10;
  late String meId;
  late String gamilaId;
  late String episodeId;
  ReportFonts? fonts;
  final shared = <ShareParams>[];
  final sharedBytes = <List<int>>[];

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    fonts = await ReportFonts.load();
  });

  setUp(() {
    now = today10;
    shared.clear();
    sharedBytes.clear();
    h = ScreenHarness();
    h.overrides = [
      cardPhotoStoreProvider.overrideWithValue(
        SyncPhotoStore(Directory(h.dir.path), PhotoStore.cardsFolder),
      ),
      medicinePhotoStoreProvider.overrideWithValue(
        SyncPhotoStore(Directory(h.dir.path), PhotoStore.medicinesFolder),
      ),
      reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
      todayProvider.overrideWithValue(today10),
      clockProvider.overrideWithValue(() => now),
      sharedPhotoCacheProvider.overrideWithValue(
        SyncSharedPhotoCache(Directory('${h.dir.path}/cache')),
      ),
      reportFontsProvider.overrideWithValue(() async => fonts!),
      shareProvider.overrideWithValue((p) async {
        shared.add(p);
        for (final f in p.files ?? <XFile>[]) {
          sharedBytes.add(File(f.path).readAsBytesSync());
        }
      }),
    ];
  });
  tearDown(() => h.dispose());

  /// The founder and Gamila, with what the first file records through the
  /// UI: growth, MMR 1, a sick day, the paracetamol course, a visit and an
  /// insurance card.
  Future<void> seed(WidgetTester tester) async {
    final ids = (await tester.runAsync(() async {
      final db = h.db;
      final me = await db.addProfile(
        'أنا',
        sex: 'female',
        birthDate: DateTime(1990),
      );
      final g = await db.addProfile(
        'جميلة',
        sex: 'female',
        birthDate: birth,
        relationship: 'daughter',
        bloodType: 'A+',
        allergies: 'بنسلين',
      );
      await db.addEvent(
        profileId: g,
        type: 'growth',
        occurredAt: DateTime(2026, 11, 12),
        dataJson: jsonEncode({
          'weightKg': 12.0,
          'heightCm': 86.0,
          'headCm': 47.0,
        }),
      );
      await db.addEvent(
        profileId: g,
        type: 'vaccine',
        occurredAt: DateTime(2026, 11, 12),
        dataJson: jsonEncode({'vaccine': 'MMR', 'dose': '1'}),
      );
      await db.addEvent(
        profileId: g,
        type: 'visit',
        occurredAt: DateTime(2026, 11, 12),
        dataJson: jsonEncode({'doctorName': 'د. منى'}),
        costMinor: 30000,
        currency: 'EGP',
      );
      final e = await db.saveEpisode(
        profileId: g,
        startedAt: DateTime(2026, 11, 12, 8),
      );
      for (final (hour, v) in [(8, 38.5), (12, 39.1), (18, 37.8)]) {
        await db.saveReading(
          episodeId: e,
          takenAt: DateTime(2026, 11, 12, hour),
          value: v,
          unit: 'c',
        );
      }
      await db.saveMedicine(
        profileId: g,
        name: 'باراسيتامول شراب',
        instructions: '5 مل',
        startOn: DateTime(2026, 11, 12),
        endOn: DateTime(2026, 11, 16),
        schedule: const DoseScheduleInput(times: ['08:00', '20:00']),
      );
      await db.saveInsuranceCard(
        profileId: g,
        label: 'شغل ماما',
        expiresOn: DateTime.utc(2027, 6, 30),
      );
      return (me, g, e);
    }))!;
    (meId, gamilaId, episodeId) = ids;
    await h.prefs.setString(PrefKeys.meProfileId, meId);
  }

  // ---------------------------------------------------------------------
  // 8c. Doctor summary.
  // ---------------------------------------------------------------------
  testWidgets('8c. the doctor summary is made as a PDF and holds her name, '
      'age, vaccines, growth and medicine', (tester) async {
    h.tall(tester);
    await seed(tester);
    await h.open(tester, '/family/$gamilaId');
    await h.tapKey(tester, 'member-doctor-summary');
    // A child: growth and vaccines are offered.
    expect(key('summary-section-growth'), findsOneWidget);
    expect(key('summary-vaccination-record'), findsOneWidget);
    await h.tapKey(tester, 'summary-share');
    expect(key('share-warning'), findsOneWidget);
    await tester.tap(key('share-warning-go'));
    for (var i = 0; i < 40 && shared.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(shared, hasLength(1));
    expect(shared.single.files!.single.mimeType, 'application/pdf');
    expect(String.fromCharCodes(sharedBytes.single.take(4)), '%PDF');

    // What the PDF draws: the report the share button builds, in Arabic,
    // every section (the default). Its text can't be read back from the
    // PDF in Arabic (glyphs, not letters), so the report is checked.
    final inputs = (await tester.runAsync(
      () async => (await SummaryInputs.load(h.db, gamilaId))!,
    ))!;
    final report = doctorSummary(
      l: ar,
      inputs: inputs,
      sections: SummarySection.values.toSet(),
      now: today10,
    );
    final text = reportText(report);
    expect(text, contains('جميلة'));
    // Age two: "سنتين".
    expect(text, contains('${ar.reportAge}: سنتين'));
    expect(text, contains('A+'));
    expect(text, contains('بنسلين'));
    expect(text, contains('باراسيتامول شراب'));
    expect(text, contains('5 مل'));
    // Growth rows with the percentiles worked out by hand from the WHO
    // tables (64th, 45th, 45th; see the first file).
    expect(text, contains('١٢'));
    expect(text, contains('٦٤'));
    expect(text, contains('٤٥'));
    // Vaccines: MMR 1 given today.
    expect(text, contains(ar.reportSectionVaccines));
    expect(text, contains('١٢ نوفمبر ٢٠٢٦'));
  });

  // ---------------------------------------------------------------------
  // 9. Pregnancy.
  // ---------------------------------------------------------------------
  testWidgets('9a. pregnancy is not offered for a two-year-old', (
    tester,
  ) async {
    h.tall(tester);
    await seed(tester);
    await h.open(tester, '/family/$gamilaId');
    expect(key('member-pregnancy'), findsNothing);
    await h.tapKey(tester, 'add-record');
    expect(key('type-pregnancy'), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await h.settle(tester);
    // Opened by address anyway, the page doesn't offer to start one.
    await h.go(tester, '/family/$gamilaId/pregnancy');
    expect(key('pregnancy-start'), findsNothing);
  });

  testWidgets('9b. the founder, LMP 1 Jun 2026: 23 weeks 3 days on 12 Nov', (
    tester,
  ) async {
    h.tall(tester);
    await seed(tester);
    await h.open(tester, '/family/$meId');
    expect(key('member-pregnancy'), findsOneWidget);
    await h.tapKey(tester, 'member-pregnancy');
    await h.tapKey(tester, 'pregnancy-start');
    await h.tapKey(tester, 'field-lmp');
    Navigator.of(tester.element(find.byType(DatePickerDialog)))
        .pop(DateTime(2026, 6, 1));
    await tester.pumpAndSettle();
    await h.tapKey(tester, 'record-save');
    await h.go(tester, '/family/$meId/pregnancy');
    // 1 Jun -> 12 Nov 2026: 29 (rest of June) + 31 + 31 + 30 + 31 + 12 =
    // 164 days = 23 weeks 3 days. Due date 1 Jun + 280 days = 8 Mar 2027,
    // 116 days away.
    final t = screenText(tester);
    expect(t, contains('٢٣ أسبوع و٣ أيام'));
    expect(
      tester.widget<Text>(key('pregnancy-days-left')).data,
      contains('١١٦'),
    );
  });

  // ---------------------------------------------------------------------
  // 10. Response time, test environment only.
  // ---------------------------------------------------------------------
  testWidgets('10. time to first frame and to data on the main pages '
      '(test environment: software rendering, in-memory database)', (
    tester,
  ) async {
    h.tall(tester);
    await seed(tester);
    final results = <String>[];

    Future<void> measure(String name, String path, Finder ready) async {
      final sw = Stopwatch()..start();
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);
      await tester.pump();
      final first = sw.elapsedMilliseconds;
      var i = 0;
      for (; i < 400 && ready.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
        await tester.pump();
      }
      final loaded = sw.elapsedMilliseconds;
      expect(ready, findsWidgets, reason: name);
      await tester.pumpAndSettle();
      results.add('$name: first frame ${first}ms, data ${loaded}ms');
    }

    final sw = Stopwatch()..start();
    await h.open(tester, '/home');
    results.add('cold start to Home settled: ${sw.elapsedMilliseconds}ms');
    await measure('Her page', '/family/$gamilaId', key('member-details'));
    await measure(
      'Vaccines',
      '/family/$gamilaId/vaccines',
      key('vaccine-next-card'),
    );
    await measure(
      'Growth',
      '/family/$gamilaId/growth',
      key('growth-status-weight'),
    );
    await measure('Medicines Today', '/medicines', find.byType(Card));
    await measure('Records', '/records', find.textContaining('جميلة'));
    await measure(
      'Sick day',
      '/family/$gamilaId/sick-days/$episodeId',
      key('sick-day-fever-duration'),
    );
    await measure('Home', '/home', key('home-person-$gamilaId'));
    debugPrint('TIMINGS (widget test, not a device):\n${results.join('\n')}');
  });

  // ---------------------------------------------------------------------
  // 11. Accessibility at 320 px and text x2.
  // ---------------------------------------------------------------------
  group('11. accessibility at 320 px, text x2', () {
    final pages = <String, String Function()>{
      'Home': () => '/home',
      'Person page': () => '/family/$gamilaId',
      'Vaccines': () => '/family/$gamilaId/vaccines',
      'Growth': () => '/family/$gamilaId/growth',
      'Today': () => '/medicines',
      'Sick day': () => '/family/$gamilaId/sick-days/$episodeId',
      'Emergency card': () => '/family/$gamilaId/emergency',
    };
    for (final MapEntry(key: name, value: path) in pages.entries) {
      testWidgets(name, (tester) async {
        smallPhoneDoubleText(tester);
        await seed(tester);
        await h.open(tester, path());
        final semantics = tester.ensureSemantics();
        final out = <String>[];
        final passed = <String, bool>{};
        for (final (label, g) in [
          ('textContrast', textContrastGuideline),
          ('androidTapTarget', androidTapTargetGuideline),
          ('labeledTapTarget', labeledTapTargetGuideline),
        ]) {
          final r = await g.evaluate(tester);
          passed[label] = r.passed;
          out.add('$label: ${r.passed ? 'pass' : 'FAIL\n${r.reason}'}');
        }
        semantics.dispose();
        debugPrint('A11Y $name\n${out.join('\n')}');
        // What is on screen at the top of the page (no scrolling).
        expect(passed['textContrast'], isTrue);
        expect(passed['androidTapTarget'], isTrue);
        // BUG: on every page the whole screen is a tappable node with no
        // label (DismissKeyboard's GestureDetector, lib/core/design/
        // dismiss_keyboard.dart), and on her page, the sick day and the
        // emergency card a 48x48 round icon button's tap node has no label
        // (UsraRoundIconButton puts its label on a Semantics around the
        // IconButton, not on the button's own node).
        expect(passed['labeledTapTarget'], isFalse);
        // Layout too: nothing overflows top to bottom.
        await walkScreen(tester);
      });
    }
  });
}
