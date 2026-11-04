import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/features/medicines/reminder_sync.dart';
import 'package:usra/features/medicines/reminders.dart';
import 'package:usra/l10n/app_localizations.dart';

import '../support/fake_reminder_scheduler.dart';

void main() {
  late AppDatabase db;
  late String omar;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    omar = await db.addProfile('عمر');
  });
  tearDown(() => db.close());

  Future<String> paracetamol({
    List<String> times = const ['08:00', '20:00'],
    DateTime? startOn,
    DateTime? endOn,
  }) => db.saveMedicine(
    profileId: omar,
    name: ' باراسيتامول ',
    strength: '500 مجم',
    form: 'tablet',
    instructions: 'بعد الأكل',
    startOn: startOn ?? DateTime(2026, 11, 1),
    endOn: endOn,
    photos: const ['medicines/box.jpg'],
    schedule: DoseScheduleInput(times: times, amount: 'قرص واحد'),
  );

  Future<List<String>> outboxFor(String id) async => [
    for (final o in await (db.select(
      db.outboxEntries,
    )..where((o) => o.entityId.equals(id))).get())
      o.operation,
  ];

  group('medicines in the database', () {
    test('saving keeps the prescription and its schedule', () async {
      final id = await paracetamol();
      final m = (await db.watchMedicines(omar).first).single;
      expect(m.id, id);
      expect(m.name, 'باراسيتامول');
      expect(m.strength, '500 مجم');
      expect(m.instructions, 'بعد الأكل');
      expect(m.startOn.isAtSameMomentAs(DateTime.utc(2026, 11, 1)), isTrue);
      expect(decodeMedicinePhotos(m.photosJson), ['medicines/box.jpg']);
      final s = (await db.watchDoseSchedule(id).first)!;
      expect(s.times, '08:00,20:00');
      expect(s.amount, 'قرص واحد');
      expect(s.weekdays, isNull);
      expect(await outboxFor(id), ['upsert']);
      expect(await outboxFor(s.id), ['upsert']);
    });

    test('editing updates the same schedule; no times removes it', () async {
      final id = await paracetamol();
      final first = (await db.watchDoseSchedule(id).first)!;
      await db.saveMedicine(
        id: id,
        profileId: omar,
        name: 'باراسيتامول',
        startOn: DateTime(2026, 11, 1),
        schedule: const DoseScheduleInput(
          times: ['09:00'],
          weekdays: 0x7f,
          everyNDays: 1,
        ),
      );
      final edited = (await db.watchDoseSchedule(id).first)!;
      expect(edited.id, first.id);
      expect(edited.times, '09:00');
      // Every weekday, or every 1 day, is just daily.
      expect(edited.weekdays, isNull);
      expect(edited.everyNDays, isNull);

      await db.saveMedicine(
        id: id,
        profileId: omar,
        name: 'باراسيتامول',
        startOn: DateTime(2026, 11, 1),
      );
      expect(await db.watchDoseSchedule(id).first, isNull);
      expect(await outboxFor(first.id), ['upsert', 'upsert', 'delete']);
    });

    test(
      'blank names, no weekdays and ends before starts are refused',
      () async {
        expect(
          () => db.saveMedicine(
            profileId: omar,
            name: ' ',
            startOn: DateTime(2026),
          ),
          throwsArgumentError,
        );
        expect(
          () => db.saveMedicine(
            profileId: omar,
            name: 'x',
            startOn: DateTime(2026, 2),
            endOn: DateTime(2026, 1),
          ),
          throwsArgumentError,
        );
        expect(
          () => db.saveMedicine(
            profileId: omar,
            name: 'x',
            startOn: DateTime(2026),
            schedule: const DoseScheduleInput(times: ['08:00'], weekdays: 0),
          ),
          throwsArgumentError,
        );
        expect(await db.watchMedicines(omar).first, isEmpty);
      },
    );

    test('a deleted medicine is not revived by a late save', () async {
      final id = await paracetamol();
      await db.softDeleteMedicine(id);
      expect(
        () => db.saveMedicine(
          id: id,
          profileId: omar,
          name: 'x',
          startOn: DateTime(2026),
        ),
        throwsStateError,
      );
    });

    test('stopped medicines sort last and leave the regimens', () async {
      final id = await paracetamol();
      await db.saveMedicine(
        profileId: omar,
        name: 'أموكسيسيلين',
        startOn: DateTime(2026, 11, 1),
        schedule: const DoseScheduleInput(times: ['10:00']),
      );
      expect((await db.watchRegimens().first), hasLength(2));
      await db.setMedicineActive(id, false);
      final list = await db.watchMedicines(omar).first;
      expect(list.map((m) => m.name), ['أموكسيسيلين', 'باراسيتامول']);
      final regimens = await db.watchRegimens().first;
      expect(regimens.single.medicine.name, 'أموكسيسيلين');
      expect(regimens.single.person.displayName, 'عمر');
    });

    test('marking a dose again replaces it; undo makes it due again', () async {
      final id = await paracetamol();
      final at = DateTime.utc(2026, 11, 3, 6);
      await db.logDose(id, at, DoseOutcome.snoozed);
      await db.logDose(id, at, DoseOutcome.taken);
      var logs = await db.watchMedicineDoseLogs(id).first;
      expect(logs.single.status, DoseOutcome.taken);

      // A stale notification's snooze doesn't undo Taken.
      expect(await db.logDose(id, at, DoseOutcome.snoozed), isFalse);
      expect(
        (await db.watchMedicineDoseLogs(id).first).single.status,
        DoseOutcome.taken,
      );

      await db.clearDoseLog(id, at);
      expect(await db.watchMedicineDoseLogs(id).first, isEmpty);
      await db.logDose(id, at, DoseOutcome.skipped);
      logs = await db.watchMedicineDoseLogs(id).first;
      expect(logs.single.status, DoseOutcome.skipped);
      // Still one row, so the unique (medicine, time) index holds.
      expect(await db.select(db.doseLogs).get(), hasLength(1));
      expect(() => db.logDose(id, at, 'forgotten'), throwsArgumentError);
    });

    test(
      'deleting a person deletes their medicines, schedules and logs',
      () async {
        final id = await paracetamol();
        await db.logDose(id, DateTime.utc(2026, 11, 3, 6), DoseOutcome.taken);
        await db.softDeleteProfile(omar);
        expect(await db.watchMedicines(omar).first, isEmpty);
        expect(await db.watchRegimens().first, isEmpty);
        expect(await db.watchMedicineDoseLogs(id).first, isEmpty);
        expect(await db.liveMedicinePhotos(), isEmpty);
        expect(await outboxFor(id), ['upsert', 'delete']);
      },
    );

    test('live photos are those of medicines not deleted', () async {
      final id = await paracetamol();
      await db.saveMedicine(
        profileId: omar,
        name: 'شراب كحة',
        startOn: DateTime(2026),
        photos: const ['medicines/syrup.jpg'],
      );
      expect(await db.liveMedicinePhotos(), {
        'medicines/box.jpg',
        'medicines/syrup.jpg',
      });
      await db.softDeleteMedicine(id);
      expect(await db.liveMedicinePhotos(), {'medicines/syrup.jpg'});
    });
  });

  test('a v5 database gains the medicine tables on upgrade', () async {
    final dir = await Directory.systemTemp.createTemp('usra_v5');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/v5.db');

    final raw = sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE profiles (id TEXT NOT NULL PRIMARY KEY, display_name TEXT NOT NULL,
        birth_date INTEGER, sex TEXT, simple_mode INTEGER NOT NULL DEFAULT 0,
        blood_type TEXT, allergies TEXT, conditions TEXT,
        updated_at INTEGER NOT NULL, deleted_at INTEGER);
      CREATE TABLE medical_events (id TEXT NOT NULL PRIMARY KEY,
        profile_id TEXT NOT NULL REFERENCES profiles (id), type TEXT NOT NULL,
        occurred_at INTEGER NOT NULL, doctor_id TEXT, cost_minor INTEGER,
        currency TEXT, data_json TEXT NOT NULL DEFAULT '{}',
        updated_at INTEGER NOT NULL, deleted_at INTEGER);
      CREATE TABLE doctors (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL,
        specialty TEXT, phone TEXT, clinic TEXT, address TEXT,
        fee_minor INTEGER, notes TEXT,
        updated_at INTEGER NOT NULL, deleted_at INTEGER);
      CREATE TABLE insurance_cards (id TEXT NOT NULL PRIMARY KEY,
        profile_id TEXT NOT NULL REFERENCES profiles (id), label TEXT NOT NULL,
        insurer TEXT, member_number TEXT, expires_on INTEGER, notes TEXT,
        front_photo TEXT, back_photo TEXT,
        updated_at INTEGER NOT NULL, deleted_at INTEGER);
      CREATE TABLE attachments (id TEXT NOT NULL PRIMARY KEY,
        event_id TEXT NOT NULL REFERENCES medical_events (id),
        path TEXT NOT NULL, kind TEXT NOT NULL DEFAULT 'photo', caption TEXT,
        created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
        deleted_at INTEGER);
      CREATE TABLE outbox_entries (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        entity TEXT NOT NULL, entity_id TEXT NOT NULL, operation TEXT NOT NULL,
        created_at INTEGER NOT NULL);
      INSERT INTO profiles (id, display_name, updated_at) VALUES ('p1', 'Mona', 0);
      INSERT INTO medical_events (id, profile_id, type, occurred_at, updated_at)
        VALUES ('e1', 'p1', 'visit', 0, 0);
      INSERT INTO attachments (id, event_id, path, created_at, updated_at)
        VALUES ('a1', 'e1', 'attachments/rx.jpg', 0, 0);
      PRAGMA user_version = 5;
    ''');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final id = await upgraded.saveMedicine(
      profileId: 'p1',
      name: 'Metformin',
      startOn: DateTime(2026),
      schedule: const DoseScheduleInput(times: ['08:00']),
    );
    final at = DateTime.utc(2026, 1, 1, 6);
    await upgraded.logDose(id, at, DoseOutcome.taken);
    expect((await upgraded.watchRegimens().first).single.medicine.id, id);
    expect(
      (await upgraded.watchMedicineDoseLogs(id).first).single.status,
      DoseOutcome.taken,
    );
    // The unique index came with the upgrade.
    await expectLater(
      upgraded
          .into(upgraded.doseLogs)
          .insert(
            DoseLogsCompanion.insert(
              id: 'dup',
              medicineId: id,
              scheduledAt: at,
              status: DoseOutcome.skipped,
              at: at,
              updatedAt: at,
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
    // Earlier data is untouched.
    expect((await upgraded.watchTimeline('p1').first).single.id, 'e1');
    expect(
      (await upgraded.watchAttachments('e1').first).single.path,
      'attachments/rx.jpg',
    );
  });

  group('reminders', () {
    final ar = lookupAppLocalizations(const Locale('ar'));
    final texts = ReminderTexts(ar, discreet: false);

    test('discreet: no person, medicine or instructions', () async {
      final id = await paracetamol();
      final regimens = await db.watchRegimens().first;
      final now = DateTime(2026, 11, 3, 9);
      for (final (l, title, body) in [
        (ar, 'ميعاد دوا', 'افتح أسرة عشان تشوف أنهي دوا'),
        (
          lookupAppLocalizations(const Locale('en')),
          'Time for a medicine',
          'Open Usra to see which',
        ),
      ]) {
        final planned = planReminders(
          regimens,
          const [],
          now: now,
          texts: ReminderTexts(l, discreet: true),
          window: const Duration(days: 1),
        );
        expect(planned.first.title, title);
        expect(planned.first.body, body);
        expect(planned.first.takenLabel, isNull);
        // Without the random id, which can contain "500".
        final payload = planned.first.toPayload().replaceAll(id, '');
        for (final secret in ['عمر', 'باراسيتامول', '500', 'قرص', 'الأكل']) {
          expect(payload, isNot(contains(secret)), reason: secret);
        }
      }
    });

    test('one per dose not yet marked, in Arabic with the name', () async {
      final id = await paracetamol();
      final now = DateTime(2026, 11, 3, 9);
      await db.logDose(
        id,
        DateTime(2026, 11, 3, 20).toUtc(),
        DoseOutcome.taken,
      );
      final planned = planReminders(
        await db.watchRegimens().first,
        await db
            .watchDoseLogs(from: DateTime.utc(2026), to: DateTime.utc(2027))
            .first,
        now: now,
        texts: texts,
        window: const Duration(days: 2),
      );
      // 20:00 today is taken already; 08:00 today has passed.
      expect(planned.map((r) => r.at), [
        DateTime(2026, 11, 4, 8),
        DateTime(2026, 11, 4, 20),
        DateTime(2026, 11, 5, 8),
      ]);
      expect(planned.map((r) => r.id), [1, 2, 3]);
      expect(planned.first.title, 'ميعاد دوا عمر: باراسيتامول 500 مجم');
      expect(planned.first.body, 'قرص واحد · بعد الأكل');
      expect(planned.first.takenLabel, 'اتاخد');
      expect(planned.first.scheduledAt, DateTime(2026, 11, 4, 8).toUtc());
    });

    test('capped, and nothing after the last day', () async {
      await paracetamol(endOn: DateTime(2026, 11, 30));
      final regimens = await db.watchRegimens().first;
      final capped = planReminders(
        regimens,
        const [],
        now: DateTime(2026, 11, 3),
        texts: texts,
        window: const Duration(days: 60),
        max: 5,
      );
      expect(capped, hasLength(5));
      final all = planReminders(
        regimens,
        const [],
        now: DateTime(2026, 11, 3),
        texts: texts,
        window: const Duration(days: 60),
        max: 1000,
      );
      expect(all.last.at, DateTime(2026, 11, 30, 20));
    });

    test('the payload holds only the dose, never text', () {
      final r = PlannedReminder(
        id: 4,
        at: DateTime(2026, 11, 4, 8),
        medicineId: 'm1',
        scheduledAt: DateTime(2026, 11, 4, 8).toUtc(),
        title: 'ميعاد دوا عمر',
        body: 'بعد الأكل',
        takenLabel: 'اتاخد',
        snoozeLabel: 'أجّل',
      );
      final payload = r.toPayload();
      expect(
        (jsonDecode(payload) as Map).keys,
        unorderedEquals(['m', 's', 'a', 'l']),
      );
      final back = ReminderRef.fromPayload(payload)!;
      expect(back.medicineId, 'm1');
      expect(back.scheduledAt, r.scheduledAt);
      expect(back.at!.isAtSameMomentAs(r.at), isTrue);
      expect(back.locale, 'ar');
      expect(ReminderRef.fromPayload('nonsense'), isNull);
      // What older versions saved: still read, the text ignored.
      final old = ReminderRef.fromPayload(
        jsonEncode({
          'm': 'm1',
          's': 1,
          't': 'عمر',
          'b': 'b',
          'tl': 'x',
          'sl': 'y',
        }),
      )!;
      expect(old.at, isNull);
      expect(old.medicineId, 'm1');

      expect(
        snoozeIdFor('m1', r.scheduledAt),
        greaterThanOrEqualTo(snoozeIdBase),
      );
      expect(
        snoozeIdFor('m1', r.scheduledAt),
        snoozeIdFor('m1', r.scheduledAt),
      );
    });

    test('a snooze pressed while the app is closed is discreet', () {
      final ref = ReminderRef(
        medicineId: 'm1',
        scheduledAt: DateTime.utc(2026, 11, 4, 6),
        locale: 'en',
      );
      final s = ReminderTexts.generic(ref, at: DateTime(2026, 11, 4, 8, 10));
      expect(s.title, 'Time for a medicine');
      expect(s.takenLabel, isNull);
      expect(s.snoozeLabel, 'Snooze 10 min');
      expect(s.id, snoozeIdFor('m1', ref.scheduledAt));
    });

    test('the inbox hands back actions once, even after a cut-off run', () {
      final dir = Directory.systemTemp.createTempSync('usra_inbox');
      addTearDown(() => dir.deleteSync(recursive: true));
      final inbox = DoseActionInbox(File('${dir.path}/a.jsonl'));
      expect(inbox.hasActions, isFalse);
      final a = DoseAction(
        medicineId: 'm1',
        scheduledAt: DateTime.utc(2026, 11, 4, 6),
        status: DoseOutcome.taken,
        at: DateTime.utc(2026, 11, 4, 6, 2),
      );
      inbox.add(a);
      File('${dir.path}/a.jsonl')
          .writeAsStringSync('{"cut', mode: FileMode.append);
      expect(inbox.hasActions, isTrue);
      // Taken but not marked done: handed back again.
      expect(inbox.take().single.medicineId, 'm1');
      inbox.add(a);
      expect(inbox.take(), hasLength(1));
      inbox.done();
      expect(inbox.take(), hasLength(1));
      inbox.done();
      expect(inbox.take(), isEmpty);
      expect(inbox.hasActions, isFalse);
    });

    test('sync saves notification actions and re-plans', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final dir = Directory.systemTemp.createTempSync('usra_sync');
      addTearDown(() => dir.deleteSync(recursive: true));
      final inbox = DoseActionInbox(File('${dir.path}/a.jsonl'));
      final scheduler = FakeReminderScheduler();
      final now = DateTime(2026, 11, 3, 7);
      final id = await paracetamol();
      final eight = DateTime(2026, 11, 3, 8).toUtc();
      inbox.add(
        DoseAction(
          medicineId: id,
          scheduledAt: eight,
          status: DoseOutcome.taken,
          at: now.toUtc(),
        ),
      );
      final sync = ReminderSync(
        db: db,
        scheduler: scheduler,
        inbox: inbox,
        texts: () => texts,
        clock: () => now,
      );
      await sync.resync();
      final log = (await db.watchMedicineDoseLogs(id).first).single;
      expect(log.scheduledAt.isAtSameMomentAs(eight), isTrue);
      expect(inbox.hasActions, isFalse);
      // 08:00 was taken from the notification: 20:00 is next.
      expect(scheduler.planned.first.at, DateTime(2026, 11, 3, 20));

      // Snoozing from the stale 08:00 notification changes nothing.
      await sync.handleAction(
        ReminderRef(medicineId: id, scheduledAt: eight, locale: 'ar'),
        DoseOutcome.snoozed,
      );
      expect(scheduler.snoozes, isEmpty);

      await sync.handleAction(scheduler.planned.first.ref, DoseOutcome.snoozed);
      expect(scheduler.snoozes.single.at, now.add(snoozeDuration));
      // Rebuilt from the database, not copied from the notification.
      expect(
        scheduler.snoozes.single.title,
        'ميعاد دوا عمر: باراسيتامول 500 مجم',
      );
      await sync.resync();
      expect(scheduler.planned.first.at, DateTime(2026, 11, 4, 8));
    });
  });
}
