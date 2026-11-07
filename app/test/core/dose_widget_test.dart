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
      unorderedEquals(['at', 'until', 'time', 'person', 'medicine', 'm', 't']),
    );
  });

  test('discreet: no person or medicine names on the widget', () async {
    await medicine(omar, 'باراسيتامول', ['08:00', '20:00']);
    await medicine(mona, 'Augmentin', ['14:00']);
    final s = await snapshotAt(DateTime(2026, 11, 3, 7), discreet: true);
    expect(s.doses, hasLength(6));
    expect(s.doses.first.person, isEmpty);
    expect(s.doses.first.medicine, 'ميعاد جرعة');
    expect(s.discreet, isTrue);
    expect(jsonDecode(s.encode())['discreet'], isTrue);
    final json = s.encode();
    for (final secret in ['عمر', 'منى', 'باراسيتامول', 'Augmentin']) {
      expect(json, isNot(contains(secret)), reason: secret);
    }
    final english = await snapshotAt(
      DateTime(2026, 11, 3, 7),
      l: en,
      discreet: true,
    );
    expect(english.doses.first.medicine, 'Dose due');
    // With names, the widget keeps its Taken buttons.
    expect((await snapshotAt(DateTime(2026, 11, 3, 7))).discreet, isFalse);
  });

  test('discreet: two people due at once get no Taken anywhere', () async {
    await medicine(omar, 'باراسيتامول', ['08:00']);
    await medicine(mona, 'Augmentin', ['08:00']);
    final now = DateTime(2026, 11, 3, 7);
    final regimens = await db.watchRegimens().first;
    final planned = planReminders(
      regimens,
      const [],
      now: now,
      texts: ReminderTexts(ar, discreet: true),
      window: const Duration(hours: 2),
    );
    // Identical notifications: a Taken on one could log the other's dose.
    expect(planned, hasLength(2));
    expect(planned.map((r) => r.title).toSet(), {'ميعاد الدوا'});
    expect(planned.every((r) => r.takenLabel == null), isTrue);
    expect(planned.every((r) => r.snoozeLabel == ar.doseSnooze), isTrue);
    final widget = await snapshotAt(now, discreet: true);
    expect(
      widget.doses.take(2).map((d) => '${d.time} · ${d.medicine}').toSet(),
      {'٨:٠٠ ص · ميعاد جرعة'},
    );
    expect(widget.discreet, isTrue);
    expect(widget.doses.take(2).every((d) => !d.canMark), isTrue);

    // With names they can be told apart, and Taken stays.
    final named = planReminders(
      regimens,
      const [],
      now: now,
      texts: ReminderTexts(ar, discreet: false),
      window: const Duration(hours: 2),
    );
    expect(named.map((r) => r.title).toSet(), hasLength(2));
    expect(named.every((r) => r.takenLabel == ar.doseTaken), isTrue);
  });

  test('a stored "off" wins over the default', () {
    final on = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
      ],
    );
    final off = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(
          MemoryKeyValueStore({PrefKeys.discreetNotifications: false}),
        ),
      ],
    );
    addTearDown(on.dispose);
    addTearDown(off.dispose);
    expect(reminderTextsOf(on).discreet, isTrue);
    expect(reminderTextsOf(off).discreet, isFalse);
  });

  test('switching discreet mode rewrites reminders, snoozes, notifications '
      'on screen and the widget', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('usra_widget');
    addTearDown(() => dir.deleteSync(recursive: true));
    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(
          MemoryKeyValueStore({PrefKeys.discreetNotifications: false}),
        ),
      ],
    );
    addTearDown(container.dispose);
    final widget = FakeWidgetSnapshotPublisher();
    final scheduler = FakeReminderScheduler();
    final now = DateTime(2026, 11, 3, 7);
    final id = await medicine(omar, 'باراسيتامول', ['08:00', '20:00']);
    final sync = ReminderSync(
      db: db,
      scheduler: scheduler,
      inbox: DoseActionInbox(File('${dir.path}/a.jsonl')),
      texts: () => reminderTextsOf(container),
      widget: widget,
      clock: () => now,
    );
    resyncOnTextChange(container, sync.resync);

    // Names on: what the phone holds, as the real scheduler would see it.
    await sync.resync();
    const name = 'ميعاد دوا عمر محمد السيد: باراسيتامول 500 مجم';
    expect(scheduler.planned.first.title, name);
    expect(widget.last.doses.first.person, 'عمر');
    PhoneReminder onPhone(PlannedReminder r) =>
        (id: r.id, title: r.title, body: r.body, payload: r.toPayload());
    // Yesterday's 20:00 snoozed until 07:05, and a 06:00 reminder still on
    // screen (the same medicine, made up for the test).
    final yesterday = DateTime(2026, 11, 2, 20).toUtc();
    final snooze = scheduler.rebuild!(
      snoozeIdFor(id, yesterday),
      ReminderRef(medicineId: id, scheduledAt: yesterday, locale: 'ar'),
      DateTime(2026, 11, 3, 7, 5),
    )!;
    expect(snooze.title, name);
    final shown = scheduler.rebuild!(
      77,
      ReminderRef(
        medicineId: id,
        scheduledAt: DateTime(2026, 11, 3, 6).toUtc(),
        locale: 'ar',
      ),
      DateTime(2026, 11, 3, 6),
    )!;
    final pending = [...scheduler.planned.map(onPhone), onPhone(snooze)];
    // Nothing changed: nothing to do.
    final same = diffReminders(
      pending: pending,
      shown: [onPhone(shown)],
      wanted: scheduler.planned,
      rebuild: scheduler.rebuild,
      now: now,
    );
    expect(same.cancel, isEmpty);
    expect(same.schedule, isEmpty);
    expect(same.repost, isEmpty);

    await container.read(discreetNotificationsProvider.notifier).set(true);
    for (var i = 0; i < 100 && widget.published.length < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(widget.last.doses.first.person, isEmpty);
    expect(widget.last.discreet, isTrue);

    final changes = diffReminders(
      pending: pending,
      shown: [onPhone(shown)],
      wanted: scheduler.planned,
      rebuild: scheduler.rebuild,
      now: now,
    );
    // Every reminder and the snooze replaced once, none lost or doubled.
    expect(changes.cancel, {...pending.map((p) => p.id)});
    final ids = changes.schedule.map((r) => r.id).toList();
    expect(ids.toSet(), {...pending.map((p) => p.id)});
    expect(ids, hasLength(ids.toSet().length));
    final again = changes.schedule.firstWhere((r) => r.id == snooze.id);
    expect(again.at.isAtSameMomentAs(DateTime(2026, 11, 3, 7, 5)), isTrue);
    expect(changes.repost.single.id, 77);
    for (final r in [...changes.schedule, ...changes.repost]) {
      expect(r.title, 'ميعاد الدوا');
      expect(r.discreet, isTrue);
      expect(r.toPayload(), isNot(contains('عمر')));
    }

    // Once applied, the phone matches.
    final after = diffReminders(
      pending: changes.schedule.map(onPhone).toList(),
      shown: changes.repost.map(onPhone).toList(),
      wanted: scheduler.planned,
      rebuild: scheduler.rebuild,
      now: now,
    );
    expect(after.cancel, isEmpty);
    expect(after.schedule, isEmpty);
    expect(after.repost, isEmpty);

    // A snooze from an older version (text in its payload, no time) is
    // rewritten too, ten minutes on.
    final old = diffReminders(
      pending: [
        (
          id: snooze.id,
          title: name,
          body: 'b',
          payload: jsonEncode({
            'm': id,
            's': yesterday.millisecondsSinceEpoch,
            't': name,
          }),
        ),
      ],
      wanted: const [],
      rebuild: scheduler.rebuild,
      now: now,
    );
    expect(old.schedule.single.title, 'ميعاد الدوا');
    expect(old.schedule.single.at, now.add(snoozeDuration));
  });

  test('a snooze after switching discreet on has no names', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('usra_widget');
    addTearDown(() => dir.deleteSync(recursive: true));
    final scheduler = FakeReminderScheduler();
    final now = DateTime(2026, 11, 3, 8, 2);
    var discreet = false;
    final id = await medicine(omar, 'باراسيتامول', ['08:00']);
    final sync = ReminderSync(
      db: db,
      scheduler: scheduler,
      inbox: DoseActionInbox(File('${dir.path}/a.jsonl')),
      texts: () => ReminderTexts(ar, discreet: discreet),
      clock: () => now,
    );
    // Pressed on a notification shown before the switch.
    discreet = true;
    await sync.handleAction(
      ReminderRef(
        medicineId: id,
        scheduledAt: DateTime(2026, 11, 3, 8).toUtc(),
        locale: 'ar',
      ),
      DoseOutcome.snoozed,
    );
    final s = scheduler.snoozes.single;
    expect(s.title, 'ميعاد الدوا');
    expect(s.discreet, isTrue);
    // No other dose near it, so Taken can only mean this one.
    expect(s.takenLabel, ar.doseTaken);
    expect(s.at, now.add(snoozeDuration));
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
      texts: () => ReminderTexts(ar, discreet: false),
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
      texts: () => ReminderTexts(ar, discreet: false),
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

  group('discreet Taken', () {
    Future<List<PlannedReminder>> plan(
      DateTime now, {
      AppLocalizations? l,
      List<DoseLog> logs = const [],
    }) async => planReminders(
      await db.watchRegimens().first,
      logs,
      now: now,
      texts: ReminderTexts(l ?? ar, discreet: true),
      window: const Duration(days: 1),
    );

    final now = DateTime(2026, 11, 3, 7);

    test('a dose on its own has Taken and Skip, and gives the time', () async {
      await medicine(omar, 'باراسيتامول', ['08:00']);
      final r = (await plan(now)).first;
      expect(r.title, 'ميعاد الدوا');
      expect(r.body, 'جرعة ٨:٠٠ ص');
      expect(r.takenLabel, ar.doseTaken);
      expect(r.skipLabel, ar.doseSkip);
      expect(r.snoozeLabel, ar.doseSnooze);
      expect(r.iosCategory, discreetLoneCategory);
    });

    test('never a name, whatever the buttons', () async {
      // Alone at 14:00, two close together at 08:00.
      await medicine(omar, 'باراسيتامول', ['08:00', '14:00']);
      await medicine(mona, 'Augmentin', ['08:30']);
      for (final l in [ar, en]) {
        final planned = await plan(now, l: l);
        expect({for (final r in planned) r.takenLabel != null}, {true, false});
        for (final r in planned) {
          for (final secret in [
            'عمر',
            'منى',
            'باراسيتامول',
            'Augmentin',
            '500',
            'قرص',
            'الأكل',
          ]) {
            expect('${r.title} ${r.body}', isNot(contains(secret)));
          }
        }
      }
    });

    test('another dose within the hour takes the buttons from both', () async {
      await medicine(omar, 'باراسيتامول', ['08:00']);
      await medicine(mona, 'Augmentin', ['09:00']);
      final planned = await plan(now);
      for (final r in planned.where((r) => r.at.day == 3)) {
        expect(r.takenLabel, isNull);
        expect(r.skipLabel, isNull);
        expect(r.snoozeLabel, ar.doseSnooze);
        expect(r.iosCategory, discreetCategory);
        expect(r.body, ar.doseReminderDiscreetSeveralBody);
      }
    });

    test('one person\'s two medicines close together count too', () async {
      await medicine(omar, 'باراسيتامول', ['08:00']);
      await medicine(omar, 'Augmentin', ['08:00']);
      expect((await plan(now)).first.takenLabel, isNull);
    });

    test('over an hour apart, each keeps its buttons', () async {
      await medicine(omar, 'باراسيتامول', ['08:00']);
      await medicine(mona, 'Augmentin', ['09:01']);
      final planned = (await plan(now)).where((r) => r.at.day == 3);
      expect(planned, hasLength(2));
      expect(planned.every((r) => r.takenLabel == ar.doseTaken), isTrue);
    });

    test('a dose already marked leaves the other on its own', () async {
      final first = await medicine(omar, 'باراسيتامول', ['08:00']);
      await medicine(mona, 'Augmentin', ['08:30']);
      final at = DateTime(2026, 11, 3, 8);
      await db.logDose(first, at.toUtc(), DoseOutcome.taken);
      final logs = await db
          .watchDoseLogs(
            from: now.subtract(const Duration(days: 1)),
            to: now.add(const Duration(days: 8)),
          )
          .first;
      final r = (await plan(now, logs: logs)).first;
      expect(r.at, DateTime(2026, 11, 3, 8, 30));
      expect(r.takenLabel, ar.doseTaken);
    });

    test('a snoozed dose counts at the time it rings again', () async {
      final first = await medicine(omar, 'باراسيتامول', ['06:00']);
      await medicine(mona, 'Augmentin', ['08:00']);
      // Snoozed at 07:45, it rings at 07:55, near Mona's 08:00.
      await db.logDose(
        first,
        DateTime(2026, 11, 3, 6).toUtc(),
        DoseOutcome.snoozed,
        at: DateTime(2026, 11, 3, 7, 45).toUtc(),
      );
      final logs = await db
          .watchDoseLogs(
            from: now.subtract(const Duration(days: 1)),
            to: now.add(const Duration(days: 8)),
          )
          .first;
      final r = (await plan(
        DateTime(2026, 11, 3, 7, 50),
        logs: logs,
      )).firstWhere((r) => r.at == DateTime(2026, 11, 3, 8));
      expect(r.takenLabel, isNull);
    });

    test('the widget offers Taken under the same rule', () async {
      await medicine(omar, 'باراسيتامول', ['08:00', '14:00']);
      await medicine(mona, 'Augmentin', ['08:30']);
      final s = await snapshotAt(now, discreet: true);
      final today = s.doses.where((d) => d.at.day == 3).toList();
      expect([for (final d in today) d.canMark], [false, false, true]);
      expect(today.every((d) => d.person.isEmpty), isTrue);
      expect(today.every((d) => d.medicine == ar.widgetDiscreetDose), isTrue);
      // With names, every row can be told apart.
      final named = await snapshotAt(now);
      expect(named.doses.every((d) => d.canMark), isTrue);
    });

    test('a marked dose leaves the screen instead of reading as due', () async {
      final id = await medicine(omar, 'باراسيتامول', ['08:00']);
      final at = DateTime(2026, 11, 3, 8).toUtc();
      final ref = ReminderRef(medicineId: id, scheduledAt: at, locale: 'ar');
      final changes = diffReminders(
        pending: const [],
        shown: [
          (
            id: 5,
            title: 'ميعاد الدوا',
            body: 'جرعة ٨:٠٠ ص',
            payload: ref.toPayload(),
          ),
        ],
        wanted: const [],
        doneSnoozes: {snoozeIdFor(id, at)},
        rebuild: (id, ref, at) => fail('should not be rewritten'),
        now: DateTime(2026, 11, 3, 8, 5),
      );
      expect(changes.cancel, {5});
      expect(changes.repost, isEmpty);
    });

    test(
      'a snoozed dose has no Taken on the widget, even with names',
      () async {
        final id = await medicine(omar, 'باراسيتامول', ['08:00']);
        await db.logDose(
          id,
          DateTime(2026, 11, 3, 8).toUtc(),
          DoseOutcome.snoozed,
          at: DateTime(2026, 11, 3, 8, 5).toUtc(),
        );
        final at = DateTime(2026, 11, 3, 8, 7);
        for (final discreet in [true, false]) {
          final s = await snapshotAt(at, discreet: discreet);
          expect(s.doses.first.at, DateTime(2026, 11, 3, 8));
          expect(s.doses.first.canMark, isFalse);
        }
      },
    );

    test('the widget sees a snooze from before midnight too', () async {
      final late = await medicine(omar, 'باراسيتامول', ['22:00']);
      await medicine(mona, 'Augmentin', ['00:30']);
      // Snoozed at 23:58, it rings at 00:08, near Mona's 00:30.
      await db.logDose(
        late,
        DateTime(2026, 11, 2, 22).toUtc(),
        DoseOutcome.snoozed,
        at: DateTime(2026, 11, 2, 23, 58).toUtc(),
      );
      final s = await snapshotAt(DateTime(2026, 11, 3, 0, 1), discreet: true);
      final dose = s.doses.firstWhere(
        (d) => d.at == DateTime(2026, 11, 3, 0, 30),
      );
      expect(dose.canMark, isFalse);
    });

    test('with names, the three buttons and the named category', () async {
      await medicine(omar, 'باراسيتامول', ['08:00']);
      await medicine(mona, 'Augmentin', ['08:00']);
      final r = planReminders(
        await db.watchRegimens().first,
        const [],
        now: now,
        texts: ReminderTexts(ar, discreet: false),
        window: const Duration(days: 1),
      ).first;
      expect(r.discreet, isFalse);
      expect(r.takenLabel, ar.doseTaken);
      expect(r.skipLabel, ar.doseSkip);
      expect(r.iosCategory, namedCategory);
    });

    test('a neighbour added later rewrites the notification', () async {
      await medicine(omar, 'باراسيتامول', ['08:00']);
      final before = (await plan(now)).first;
      await medicine(mona, 'Augmentin', ['08:30']);
      final after = (await plan(now)).firstWhere((r) => r.at == before.at);
      // Text is all the phone can compare, so a change of buttons must show.
      expect(after.body, isNot(before.body));
      expect(after.takenLabel, isNull);
    });
  });

  test('the Arabic reminder addresses the person by their sex', () {
    expect(ar.doseReminderBody('female'), contains('تاخده'));
    expect(ar.doseReminderBody('male'), contains('ياخده'));
    expect(ar.doseReminderBody('other'), contains('ياخده'));
    expect(en.doseReminderBody('female'), en.doseReminderBody('male'));
  });

  group('Taken from the iOS widget', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('usra_inbox'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('a line the widget writes is read, and saved like any other', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final id = await medicine(omar, 'باراسيتامول', ['08:00']);
      final at = DateTime(2026, 11, 3, 8).toUtc();
      final inbox = File('${dir.path}/group.jsonl');
      // What `markTaken` in DoseWidget.swift writes.
      inbox.writeAsStringSync(
        '${jsonEncode({'m': id, 's': at.millisecondsSinceEpoch, 'st': 'taken', 'at': at.millisecondsSinceEpoch})}\n',
      );
      final sync = ReminderSync(
        db: db,
        scheduler: FakeReminderScheduler(),
        inbox: DoseActionInbox(File('${dir.path}/app.jsonl')),
        widgetInbox: DoseActionInbox(inbox),
        texts: () => ReminderTexts(ar, discreet: true),
        clock: () => DateTime(2026, 11, 3, 8, 5),
      );
      await sync.saveInbox();
      final logs = await db
          .watchDoseLogs(
            from: at.subtract(const Duration(hours: 1)),
            to: at.add(const Duration(hours: 1)),
          )
          .first;
      expect(logs.single.status, DoseOutcome.taken);
      expect(logs.single.medicineId, id);
      expect(inbox.existsSync(), isFalse);
    });

    test('Skip from a notification is saved as skipped', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final id = await medicine(omar, 'باراسيتامول', ['08:00']);
      final at = DateTime(2026, 11, 3, 8).toUtc();
      final scheduler = FakeReminderScheduler();
      final sync = ReminderSync(
        db: db,
        scheduler: scheduler,
        inbox: DoseActionInbox(File('${dir.path}/app.jsonl')),
        texts: () => ReminderTexts(ar, discreet: true),
        clock: () => DateTime(2026, 11, 3, 8, 5),
      );
      await sync.handleAction(
        ReminderRef(medicineId: id, scheduledAt: at, locale: 'ar'),
        DoseOutcome.skipped,
      );
      final logs = await db
          .watchDoseLogs(
            from: at.subtract(const Duration(hours: 1)),
            to: at.add(const Duration(hours: 1)),
          )
          .first;
      expect(logs.single.status, DoseOutcome.skipped);
      expect(scheduler.snoozes, isEmpty);
    });

    test('clear forgets everything waiting', () {
      final file = File('${dir.path}/group.jsonl')..writeAsStringSync('x\n');
      final taking = File('${file.path}.taking')..writeAsStringSync('y\n');
      DoseActionInbox(file).clear();
      expect(file.existsSync(), isFalse);
      expect(taking.existsSync(), isFalse);
      // Nothing waiting is fine too.
      DoseActionInbox(file).clear();
    });

    test('elsewhere there is no widget inbox', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      if (Platform.isIOS) return;
      expect(await DoseActionInbox.openWidgetInbox('group.test'), isNull);
    });
  });
}
