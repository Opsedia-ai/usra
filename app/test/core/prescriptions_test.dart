import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/features/medicines/dose_schedule.dart';
import 'package:usra/features/medicines/medicine_text.dart';
import 'package:usra/features/medicines/reminders.dart';
import 'package:usra/l10n/app_localizations.dart';

void main() {
  late AppDatabase db;
  late String omar;
  late String doctor;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    omar = await db.addProfile('عمر');
    doctor = await db.saveDoctor(name: 'د. هالة');
  });
  tearDown(() => db.close());

  /// After a paediatric visit: an antibiotic for 7 days, a syrup for 3 and
  /// drops as needed.
  Future<String> afterVisit() => db.savePrescription(
    profileId: omar,
    doctorId: doctor,
    prescribedOn: DateTime(2026, 11, 1),
    diagnosis: ' التهاب لوز ',
    photos: const ['medicines/rx.jpg'],
    items: const [
      PrescriptionItemInput(
        name: 'أموكسيسيلين',
        strength: '250 مجم/5 مل',
        dose: '5 مل كل 8 ساعات',
        times: ['08:00', '16:00', '23:00'],
        days: 7,
      ),
      PrescriptionItemInput(
        name: 'باراسيتامول',
        dose: '5 مل عند اللزوم',
        times: ['09:00', '21:00'],
        days: 3,
      ),
      PrescriptionItemInput(name: 'نقط أنف', dose: 'نقطتين'),
    ],
  );

  Future<List<Medicine>> medicinesOf(String rx) =>
      db.watchPrescriptionMedicines(rx).first;

  group('saving a prescription', () {
    test('creates every medicine and its reminders in one go', () async {
      final rx = await afterVisit();
      final p = (await db.watchPrescription(rx).first)!;
      expect(p.profileId, omar);
      expect(p.doctorId, doctor);
      expect(p.diagnosis, 'التهاب لوز');
      expect(p.prescribedOn.toUtc(), DateTime.utc(2026, 11, 1));
      expect(decodeMedicinePhotos(p.photosJson), ['medicines/rx.jpg']);
      expect((await db.watchPrescriptions(omar).first).single.id, rx);

      final meds = await medicinesOf(rx);
      expect(meds.map((m) => m.name), [
        'أموكسيسيلين',
        'باراسيتامول',
        'نقط أنف',
      ]);
      for (final m in meds) {
        expect(m.prescriptionId, rx);
        expect(m.doctorId, doctor);
        expect(m.profileId, omar);
        expect(m.startOn.toUtc(), DateTime.utc(2026, 11, 1));
      }
      // The dose is kept word for word, as the instructions.
      expect(meds[0].instructions, '5 مل كل 8 ساعات');
      expect(meds[0].strength, '250 مجم/5 مل');
      // 7 days counting the first: 1 to 7 November.
      expect(meds[0].endOn!.toUtc(), DateTime.utc(2026, 11, 7));
      expect(meds[1].endOn!.toUtc(), DateTime.utc(2026, 11, 3));
      expect(meds[2].endOn, isNull);

      final regimens = await db.watchRegimens().first;
      expect(regimens.map((r) => r.medicine.name).toSet(), {
        'أموكسيسيلين',
        'باراسيتامول',
      });
      final amox = regimens.firstWhere((r) => r.medicine.id == meds[0].id);
      expect(amox.schedule.times, '08:00,16:00,23:00');
      // Nothing about the dose is put in the schedule.
      expect(amox.schedule.amount, isNull);
      expect(await db.watchDoseSchedule(meds[2].id).first, isNull);
    });

    test(
      'the course ends by itself: no reminders after the last day',
      () async {
        final rx = await afterVisit();
        final regimens = await db.watchRegimens().first;
        final texts = ReminderTexts(
          lookupAppLocalizations(const Locale('ar')),
          discreet: false,
        );

        // On day 7 (7 November) only the antibiotic is left.
        final lastDay = planReminders(
          regimens,
          const [],
          now: DateTime(2026, 11, 7, 7),
          texts: texts,
          window: const Duration(days: 7),
        );
        expect(lastDay, hasLength(3));
        expect(
          lastDay.every((r) => r.at.isBefore(DateTime(2026, 11, 8))),
          isTrue,
        );
        // From 8 November: none at all, though the medicines are still listed.
        expect(
          planReminders(
            regimens,
            const [],
            now: DateTime(2026, 11, 8),
            texts: texts,
          ),
          isEmpty,
        );
        final amox = (await medicinesOf(rx)).first;
        final schedule = (await db.watchDoseSchedule(amox.id).first)!;
        expect(
          DoseRule.of(amox, schedule).nextAfter(DateTime(2026, 11, 7, 23, 30)),
          isNull,
        );
        expect(medicineEnded(amox, DateTime(2026, 11, 8)), isTrue);
      },
    );

    test('editing updates, adds and removes its medicines', () async {
      final rx = await afterVisit();
      final [amox, para, drops] = await medicinesOf(rx);
      await db.logDose(
        amox.id,
        DateTime.utc(2026, 11, 1, 6),
        DoseOutcome.taken,
      );
      final other = await db.saveDoctor(name: 'د. سامي');

      await db.savePrescription(
        id: rx,
        profileId: omar,
        doctorId: other,
        prescribedOn: DateTime(2026, 11, 1),
        items: [
          PrescriptionItemInput(
            medicineId: amox.id,
            name: 'أموكسيسيلين',
            dose: '5 مل كل 12 ساعة',
            times: const ['08:00', '20:00'],
            startOn: DateTime(2026, 11, 2),
            days: 10,
          ),
          PrescriptionItemInput(medicineId: drops.id, name: 'نقط أنف'),
          const PrescriptionItemInput(name: 'فيتامين د', times: ['10:00']),
        ],
      );

      final meds = await medicinesOf(rx);
      expect(meds.map((m) => m.name), ['أموكسيسيلين', 'نقط أنف', 'فيتامين د']);
      final edited = meds.first;
      expect(edited.id, amox.id);
      expect(edited.instructions, '5 مل كل 12 ساعة');
      expect(edited.doctorId, other);
      expect(edited.startOn.toUtc(), DateTime.utc(2026, 11, 2));
      expect(edited.endOn!.toUtc(), DateTime.utc(2026, 11, 11));
      expect((await db.watchDoseSchedule(amox.id).first)!.times, '08:00,20:00');
      // Its history stays.
      expect(await db.watchMedicineDoseLogs(amox.id).first, hasLength(1));
      // Removed from the prescription: deleted, reminders and all.
      expect(await db.watchMedicine(para.id).first, isNull);
      expect(
        (await db.watchRegimens().first).map((r) => r.medicine.id),
        isNot(contains(para.id)),
      );
      // The diagnosis was cleared; the photo list too.
      final p = (await db.watchPrescription(rx).first)!;
      expect(p.diagnosis, isNull);
      expect(decodeMedicinePhotos(p.photosJson), isEmpty);
    });

    test('a medicine from elsewhere can\'t be pulled in', () async {
      final rx = await afterVisit();
      final loose = await db.saveMedicine(
        profileId: omar,
        name: 'كونكور',
        startOn: DateTime(2026, 1, 1),
      );
      await expectLater(
        db.savePrescription(
          id: rx,
          profileId: omar,
          prescribedOn: DateTime(2026, 11, 1),
          items: [PrescriptionItemInput(medicineId: loose, name: 'كونكور')],
        ),
        throwsStateError,
      );
      // Rolled back: nothing changed.
      expect(await medicinesOf(rx), hasLength(3));
      expect((await db.watchMedicine(loose).first)!.prescriptionId, isNull);
    });

    test('rejects an empty prescription, a nameless medicine or 0 days', () {
      Future<String> save(List<PrescriptionItemInput> items) =>
          db.savePrescription(
            profileId: omar,
            prescribedOn: DateTime(2026, 11, 1),
            items: items,
          );
      expect(save(const []), throwsArgumentError);
      expect(
        save(const [PrescriptionItemInput(name: '  ')]),
        throwsArgumentError,
      );
      expect(
        save(const [PrescriptionItemInput(name: 'x', days: 0)]),
        throwsArgumentError,
      );
    });
  });

  test('stopping a prescription stops all its reminders', () async {
    final rx = await afterVisit();
    await db.setPrescriptionActive(rx, false);
    expect((await db.watchPrescription(rx).first)!.active, isFalse);
    expect((await medicinesOf(rx)).every((m) => !m.active), isTrue);
    expect(await db.watchRegimens().first, isEmpty);

    await db.setPrescriptionActive(rx, true);
    expect(await db.watchRegimens().first, hasLength(2));
  });

  test(
    'deleting a prescription deletes its medicines and frees the photo',
    () async {
      final rx = await afterVisit();
      final ids = [for (final m in await medicinesOf(rx)) m.id];
      expect(await db.liveMedicinePhotos(), {'medicines/rx.jpg'});

      await db.softDeletePrescription(rx);
      expect(await db.watchPrescription(rx).first, isNull);
      expect(await db.watchPrescriptions(omar).first, isEmpty);
      for (final id in ids) {
        expect(await db.watchMedicine(id).first, isNull);
      }
      expect(await db.watchRegimens().first, isEmpty);
      expect(await db.liveMedicinePhotos(), isEmpty);
      // Kept for sync.
      final outbox = await db.select(db.outboxEntries).get();
      expect(
        outbox.where(
          (e) => e.entity == 'prescription' && e.operation == 'delete',
        ),
        hasLength(1),
      );
    },
  );

  test('deleting the person deletes their prescriptions', () async {
    final rx = await afterVisit();
    await db.softDeleteProfile(omar);
    final row = await (db.select(
      db.prescriptions,
    )..where((p) => p.id.equals(rx))).getSingle();
    expect(row.deletedAt, isNotNull);
    expect(await db.liveMedicinePhotos(), isEmpty);
  });

  group('course progress', () {
    Medicine course(DateTime start, DateTime? end) => Medicine(
      id: 'm',
      profileId: 'p',
      name: 'x',
      startOn: DateTime.utc(start.year, start.month, start.day),
      endOn: end == null ? null : DateTime.utc(end.year, end.month, end.day),
      photosJson: '[]',
      active: true,
      updatedAt: DateTime.utc(2026),
    );

    test('day 3 of 7', () {
      final m = course(DateTime(2026, 11, 1), DateTime(2026, 11, 7));
      expect(courseDays(m), 7);
      expect(courseProgress(m, DateTime(2026, 11, 3, 23, 59)), (
        day: 3,
        total: 7,
      ));
      expect(courseProgress(m, DateTime(2026, 11, 1)), (day: 1, total: 7));
      expect(courseProgress(m, DateTime(2026, 11, 7, 22)), (day: 7, total: 7));
      expect(courseProgress(m, DateTime(2026, 10, 31)), isNull);
      expect(courseProgress(m, DateTime(2026, 11, 8)), isNull);
    });

    test('across a clock change, and none for ongoing medicines', () {
      // Egypt's summer time ends on the last Friday of October.
      final m = course(DateTime(2026, 10, 28), DateTime(2026, 11, 2));
      expect(courseProgress(m, DateTime(2026, 11, 2, 0, 30)), (
        day: 6,
        total: 6,
      ));
      expect(courseDays(course(DateTime(2026, 11, 1), null)), isNull);
      expect(
        courseProgress(
          course(DateTime(2026, 11, 1), null),
          DateTime(2026, 11, 3),
        ),
        isNull,
      );
    });
  });

  test('a v6 database gains prescriptions and keeps its medicines', () async {
    final dir = await Directory.systemTemp.createTemp('usra_v6');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/v6.db');

    // The full current schema, then taken back to what version 6 had.
    final current = AppDatabase(NativeDatabase(file));
    final p = await current.addProfile('Mona');
    final old = await current.saveMedicine(
      profileId: p,
      name: 'Metformin',
      startOn: DateTime(2026),
      schedule: const DoseScheduleInput(times: ['08:00']),
    );
    await current.close();
    // SQLite can't drop a column with a foreign key: rebuild the table
    // without it, the way version 6 created it.
    final raw = sqlite3.open(file.path);
    final create =
        raw
                .select(
                  "SELECT sql FROM sqlite_master WHERE name = 'medicines'",
                )
                .single['sql']
            as String;
    final v6 = create
        .replaceFirst(RegExp(r',\s*"prescription_id"[^,]*'), '')
        .replaceFirst('"medicines"', '"medicines_v6"');
    expect(v6, isNot(contains('prescription')));
    final columns = [
      for (final c in raw.select('PRAGMA table_info(medicines)'))
        if (c['name'] != 'prescription_id') '"${c['name']}"',
    ].join(', ');
    raw.execute('''
      PRAGMA foreign_keys = OFF;
      PRAGMA legacy_alter_table = ON;
      $v6;
      INSERT INTO medicines_v6 ($columns) SELECT $columns FROM medicines;
      DROP TABLE medicines;
      ALTER TABLE medicines_v6 RENAME TO medicines;
      DROP TABLE prescriptions;
    ''');
    raw.userVersion = 6;
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final kept = (await upgraded.watchMedicine(old).first)!;
    expect(kept.name, 'Metformin');
    expect(kept.prescriptionId, isNull);
    expect((await upgraded.watchRegimens().first).single.medicine.id, old);

    final rx = await upgraded.savePrescription(
      profileId: p,
      prescribedOn: DateTime(2026, 11, 1),
      items: const [PrescriptionItemInput(name: 'Amoxicillin', days: 5)],
    );
    expect(
      (await upgraded.watchPrescriptionMedicines(rx).first).single.name,
      'Amoxicillin',
    );
    // The foreign key came with the upgrade.
    await expectLater(
      upgraded
          .into(upgraded.medicines)
          .insert(
            MedicinesCompanion.insert(
              id: 'bad',
              profileId: p,
              name: 'x',
              startOn: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
              prescriptionId: const Value('missing'),
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });
}
