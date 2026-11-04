import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/features/medicines/dose_widget.dart';
import 'package:usra/features/medicines/medicines_providers.dart';
import 'package:usra/features/medicines/reminder_sync.dart';
import 'package:usra/features/medicines/reminders.dart';
import 'package:usra/l10n/app_localizations.dart';

import '../support/fake_reminder_scheduler.dart';
import '../support/fake_widget_snapshot_publisher.dart';

void main() {
  late AppDatabase db;
  late String omar;
  late String mona;
  final ar = lookupAppLocalizations(const Locale('ar'));
  final en = lookupAppLocalizations(const Locale('en'));

  setUpAll(() async {
    await ensureWidgetDateFormatting('ar');
    await ensureWidgetDateFormatting('en');
  });

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    omar = await db.addProfile(
      'عمر محمد السيد',
      conditions: 'سكر',
      allergies: 'بنسلين',
    );
    mona = await db.addProfile('منى');
  });
  tearDown(() => db.close());

  Future<String> medicine(String profileId, String name, List<String> times) =>
      db.saveMedicine(
        profileId: profileId,
        name: name,
        strength: '500 مجم',
        instructions: 'بعد الأكل',
        startOn: DateTime(2026, 11, 1),
        schedule: DoseScheduleInput(times: times, amount: 'قرص واحد'),
      );

  Future<WidgetSnapshot> snapshotAt(
    DateTime now, {
    AppLocalizations? l,
    bool discreet = false,
  }) async {
    final regimens = await db.watchRegimens().first;
    final logs = await db
        .watchDoseLogs(
          from: now.subtract(const Duration(days: 1)),
          to: now.add(const Duration(days: 3)),
        )
        .first;
    return buildWidgetSnapshot(
      regimens,
      logs,
      now: now,
      l: l ?? ar,
      discreet: discreet,
    );
  }

  test('doses still due, soonest first, across the family', () async {
    await medicine(omar, 'باراسيتامول', ['08:00', '20:00']);
    await medicine(mona, 'أوجمنتين', ['14:00']);
    final s = await snapshotAt(DateTime(2026, 11, 3, 7, 30));
    expect(
      [
        for (final d in s.doses.take(4))
          '${d.time} · ${d.person} · ${d.medicine}',
      ],
      [
        '٨:٠٠ ص · عمر · باراسيتامول',
        '٢:٠٠ م · منى · أوجمنتين',
        '٨:٠٠ م · عمر · باراسيتامول',
        '٨:٠٠ ص · عمر · باراسيتامول',
      ],
    );
    // Today and tomorrow, so the widget rolls over at midnight alone.
    expect(s.doses, hasLength(6));
    expect(s.doses.last.at, DateTime(2026, 11, 4, 20));
    expect(s.validUntil, DateTime(2026, 11, 5));
    expect(s.rtl, isTrue);
    expect(s.empty, 'مفيش أدوية النهارده');
    expect(s.taken, ar.doseTaken);
  });

  test(
    'a dose missed over an hour ago drops off; a recent one stays',
    () async {
      await medicine(omar, 'باراسيتامول', ['08:00', '09:30', '20:00']);
      final s = await snapshotAt(DateTime(2026, 11, 3, 10));
      expect(s.doses.first.at, DateTime(2026, 11, 3, 9, 30));
    },
  );

  test('taken and skipped doses are left out; snoozed stay', () async {
    final id = await medicine(omar, 'باراسيتامول', ['08:00', '14:00', '20:00']);
    final now = DateTime(2026, 11, 3, 7);
    await db.logDose(id, DateTime(2026, 11, 3, 8).toUtc(), DoseOutcome.taken);
    await db.logDose(
      id,
      DateTime(2026, 11, 3, 14).toUtc(),
      DoseOutcome.skipped,
    );
    await db.logDose(
      id,
      DateTime(2026, 11, 3, 20).toUtc(),
      DoseOutcome.snoozed,
    );
    final s = await snapshotAt(now);
    expect(s.doses.first.at, DateTime(2026, 11, 3, 20));
  });

  test('a snoozed dose stays until an hour after its snooze', () async {
    final id = await medicine(omar, 'باراسيتامول', ['08:00', '20:00']);
    final eight = DateTime(2026, 11, 3, 8).toUtc();
    await db.logDose(
      id,
      eight,
      DoseOutcome.snoozed,
      at: DateTime(2026, 11, 3, 8, 55),
    );
    final s = await snapshotAt(DateTime(2026, 11, 3, 9, 30));
    expect(s.doses.first.at, DateTime(2026, 11, 3, 8));
    expect(s.doses.first.until, DateTime(2026, 11, 3, 10, 5));
    final later = await snapshotAt(DateTime(2026, 11, 3, 10, 10));
    expect(later.doses.first.at, DateTime(2026, 11, 3, 20));
  });

  test('marking a dose cancels its snooze', () async {
    final id = await medicine(omar, 'باراسيتامول', ['08:00', '20:00']);
    final eight = DateTime(2026, 11, 3, 8).toUtc();
    await db.logDose(id, eight, DoseOutcome.taken);
    final logs = await db.watchMedicineDoseLogs(id).first;
    expect(doneSnoozeIds(logs), {snoozeIdFor(id, eight)});
  });

  test('only first names and medicine names leave the database', () async {
    final id = await medicine(omar, 'باراسيتامول', ['08:00']);
    // Without the random id, which can contain "500".
    final json = (await snapshotAt(DateTime(2026, 11, 3, 7)))
        .encode()
        .replaceAll(id, '');
    expect(json, contains('عمر'));
    for (final secret in [
      'محمد',
      'السيد',
      'سكر',
      'بنسلين',
      '500',
      'بعد الأكل',
      'قرص',
    ]) {
      expect(json, isNot(contains(secret)), reason: secret);
    }
    final dose = (jsonDecode(json)['doses'] as List).first as Map;
    expect(
      dose.keys,
      unorderedEquals(['at', 'until', 'time', 'person', 'medicine', 'm']),
    );
  });

  test('discreet: no person or medicine names on the widget', () async {
    await medicine(omar, 'باراسيتامول', ['08:00', '20:00']);
    await medicine(mona, 'Augmentin', ['14:00']);
    final s = await snapshotAt(DateTime(2026, 11, 3, 7), discreet: true);
    expect(s.doses, hasLength(6));
    expect(s.doses.first.person, isEmpty);
    expect(s.doses.first.medicine, 'جرعة دوا');
    final json = s.encode();
    for (final secret in ['عمر', 'منى', 'باراسيتامول', 'Augmentin']) {
      expect(json, isNot(contains(secret)), reason: secret);
    }
    final english = await snapshotAt(
      DateTime(2026, 11, 3, 7),
      l: en,
      discreet: true,
    );
    expect(english.doses.first.medicine, 'Medicine dose');
  });

  test('switching discreet mode re-plans reminders and republishes the '
      'widget', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('usra_widget');
    addTearDown(() => dir.deleteSync(recursive: true));
    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
      ],
    );
    addTearDown(container.dispose);
    final widget = FakeWidgetSnapshotPublisher();
    final scheduler = FakeReminderScheduler();
    final now = DateTime(2026, 11, 3, 7);
    await medicine(omar, 'باراسيتامول', ['08:00', '20:00']);
    final sync = ReminderSync(
      db: db,
      scheduler: scheduler,
      inbox: DoseActionInbox(File('${dir.path}/a.jsonl')),
      texts: () => reminderTextsOf(container),
      widget: widget,
      clock: () => now,
    );
    resyncOnTextChange(container, sync.resync);

    // On by default.
    await sync.resync();
    expect(scheduler.planned.first.title, 'ميعاد دوا');
    expect(scheduler.planned.first.toPayload(), isNot(contains('عمر')));
    expect(widget.last.doses.first.medicine, 'جرعة دوا');

    await container.read(discreetNotificationsProvider.notifier).set(false);
    for (var i = 0; i < 100 && widget.published.length < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(
      scheduler.planned.first.title,
      'ميعاد دوا عمر محمد السيد: باراسيتامول 500 مجم',
    );
    expect(widget.last.doses.first.person, 'عمر');
    expect(widget.last.doses.first.medicine, 'باراسيتامول');
    expect(
      container
          .read(keyValueStoreProvider)
          .getBool(PrefKeys.discreetNotifications),
      isFalse,
    );
  });

  test('English text and Western digits when the app is in English', () async {
    await medicine(mona, 'Augmentin', ['20:00']);
    final s = await snapshotAt(DateTime(2026, 11, 3, 7), l: en);
    expect(s.doses.first.time, '8:00\u202fPM');
    expect(s.rtl, isFalse);
    expect(s.empty, 'No medicines today');
  });

  test('empty when nobody has doses', () async {
    final s = await snapshotAt(DateTime(2026, 11, 3, 7));
    expect(s.doses, isEmpty);
    expect(jsonDecode(s.encode())['doses'], isEmpty);
  });

  test('sync updates the widget after a dose is logged', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('usra_widget');
    addTearDown(() => dir.deleteSync(recursive: true));
    final widget = FakeWidgetSnapshotPublisher();
    final now = DateTime(2026, 11, 3, 7);
    final id = await medicine(omar, 'باراسيتامول', ['08:00', '20:00']);
    final sync = ReminderSync(
      db: db,
      scheduler: FakeReminderScheduler(),
      inbox: DoseActionInbox(File('${dir.path}/a.jsonl')),
      texts: () => ReminderTexts(ar),
      widget: widget,
      clock: () => now,
    );
    addTearDown(sync.dispose);
    await sync.start();
    expect(widget.last.doses.first.at, DateTime(2026, 11, 3, 8));

    final before = widget.published.length;
    await db.logDose(id, DateTime(2026, 11, 3, 8).toUtc(), DoseOutcome.taken);
    // Picked up from the table change, after the debounce.
    for (var i = 0; i < 100 && widget.published.length == before; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(widget.published.length, greaterThan(before));
    expect(widget.last.doses.first.at, DateTime(2026, 11, 3, 20));
  });

  test('a Taken from the widget is saved and leaves the snapshot', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('usra_widget');
    addTearDown(() => dir.deleteSync(recursive: true));
    final widget = FakeWidgetSnapshotPublisher();
    final now = DateTime(2026, 11, 3, 8, 5);
    final id = await medicine(omar, 'باراسيتامول', ['08:00', '20:00']);
    final inbox = DoseActionInbox(File('${dir.path}/a.jsonl'));
    // What the Android widget's Taken button writes.
    File('${dir.path}/a.jsonl').writeAsStringSync(
      '${jsonEncode({'m': id, 's': DateTime(2026, 11, 3, 8).toUtc().millisecondsSinceEpoch, 'st': 'taken', 'at': now.toUtc().millisecondsSinceEpoch})}\n',
    );
    final scheduler = FakeReminderScheduler();
    final sync = ReminderSync(
      db: db,
      scheduler: scheduler,
      inbox: inbox,
      texts: () => ReminderTexts(ar),
      widget: widget,
      clock: () => now,
    );
    await sync.resync();
    expect((await db.watchMedicineDoseLogs(id).first).single.status, 'taken');
    expect(widget.last.doses.first.at, DateTime(2026, 11, 3, 20));
    // A snooze set before it was taken won't ring.
    expect(
      scheduler.doneSnoozes,
      contains(snoozeIdFor(id, DateTime(2026, 11, 3, 8).toUtc())),
    );
  });
}
