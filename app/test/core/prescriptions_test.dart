import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/features/medicines/dose_schedule.dart';
import 'package:usra/features/medicines/medicine_text.dart';
import 'package:usra/features/medicines/prescription_form_screen.dart'
    show everyHours;
import 'package:usra/features/medicines/reminders.dart';
import 'package:usra/l10n/app_localizations.dart';

import '../generated_migrations/schema.dart';

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
      // Taken off: stopped and unlinked, but not deleted, history kept.
      final removed = (await db.watchMedicine(para.id).first)!;
      expect(removed.prescriptionId, isNull);
      expect(removed.active, isFalse);
      expect(
        (await db.watchRegimens().first).map((r) => r.medicine.id),
        isNot(contains(para.id)),
      );
      // The diagnosis was cleared; the photo list too.
      final p = (await db.watchPrescription(rx).first)!;
      expect(p.diagnosis, isNull);
      expect(decodeMedicinePhotos(p.photosJson), isEmpty);
    });

    test('editing keeps what each medicine\'s own page changed', () async {
      final rx = await afterVisit();
      final [amox, para, drops] = await medicinesOf(rx);
      // Changed on the medicine's own page: form, days of the week, amount.
      await db.saveMedicine(
        id: amox.id,
        profileId: omar,
        name: amox.name,
        form: 'syrup',
        instructions: amox.instructions,
        startOn: amox.startOn,
        endOn: amox.endOn,
        schedule: const DoseScheduleInput(
          times: ['08:00'],
          weekdays: 1 << 0 | 1 << 3,
          amount: '5 مل',
        ),
      );
      await db.setMedicineActive(para.id, false);

      await db.savePrescription(
        id: rx,
        profileId: omar,
        doctorId: doctor,
        prescribedOn: DateTime(2026, 11, 1),
        diagnosis: 'التهاب لوز صديدي',
        items: [
          PrescriptionItemInput(
            medicineId: amox.id,
            name: amox.name,
            dose: amox.instructions,
            times: const ['08:00', '20:00'],
            days: 7,
          ),
          PrescriptionItemInput(
            medicineId: para.id,
            name: para.name,
            times: const ['09:00'],
            days: 3,
          ),
          PrescriptionItemInput(medicineId: drops.id, name: drops.name),
        ],
      );
      final edited = (await db.watchMedicine(amox.id).first)!;
      expect(edited.form, 'syrup');
      final s = (await db.watchDoseSchedule(amox.id).first)!;
      expect(s.times, '08:00,20:00');
      expect(s.weekdays, 1 << 0 | 1 << 3);
      expect(s.amount, '5 مل');
      // Stopped on its own: still stopped.
      expect((await db.watchMedicine(para.id).first)!.active, isFalse);
    });

    test('medicines keep the order they were entered in', () async {
      // Saved in the same millisecond: UUID v7 order is random there.
      final names = [for (var i = 0; i < 12; i++) 'دوا $i'];
      final rx = await db.savePrescription(
        profileId: omar,
        prescribedOn: DateTime(2026, 11, 1),
        items: [for (final n in names) PrescriptionItemInput(name: n)],
      );
      final saved = await medicinesOf(rx);
      expect(saved.map((m) => m.name), names);
      expect(saved.map((m) => m.position), List.generate(12, (i) => i));
      // Reordered in an edit: the new order sticks.
      await db.savePrescription(
        id: rx,
        profileId: omar,
        prescribedOn: DateTime(2026, 11, 1),
        items: [
          for (final m in saved.reversed)
            PrescriptionItemInput(medicineId: m.id, name: m.name),
        ],
      );
      expect((await medicinesOf(rx)).map((m) => m.name), names.reversed);
    });

    test('any course length a medicine can hold is accepted', () async {
      final rx = await db.savePrescription(
        profileId: omar,
        prescribedOn: DateTime(2026, 11, 1),
        items: const [PrescriptionItemInput(name: 'كونكور', days: 400)],
      );
      expect(courseDays((await medicinesOf(rx)).single), 400);
      expect(
        db.savePrescription(
          profileId: omar,
          prescribedOn: DateTime(2026, 11, 1),
          items: const [
            PrescriptionItemInput(name: 'x', days: maxCourseDays + 1),
          ],
        ),
        throwsArgumentError,
      );
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
    expect((await db.watchPrescription(rx).first)!.active, isTrue);
  });

  test('resume leaves a medicine stopped on its own stopped', () async {
    final rx = await afterVisit();
    final [amox, para, _] = await medicinesOf(rx);
    // A rash from the antibiotic: stopped on its own page.
    await db.setMedicineActive(amox.id, false);

    await db.setPrescriptionActive(rx, false);
    await db.setPrescriptionActive(rx, true);
    expect((await db.watchMedicine(amox.id).first)!.active, isFalse);
    expect((await db.watchMedicine(para.id).first)!.active, isTrue);
    expect((await db.watchRegimens().first).map((r) => r.medicine.id), [
      para.id,
    ]);

    // Stopped with the prescription, then restarted on its own: resuming
    // the prescription later doesn't touch it twice.
    await db.setPrescriptionActive(rx, false);
    await db.setMedicineActive(para.id, true);
    expect(
      (await db.watchMedicine(para.id).first)!.stoppedWithPrescription,
      isFalse,
    );
    await db.setPrescriptionActive(rx, true);
    expect((await db.watchMedicine(amox.id).first)!.active, isFalse);
  });

  test('the prescription\'s status follows its medicines', () async {
    final rx = await afterVisit();
    Future<bool> active() async =>
        (await db.watchPrescription(rx).first)!.active;
    for (final m in await medicinesOf(rx)) {
      await db.setMedicineActive(m.id, false);
    }
    expect(await active(), isFalse);
    // One restarted while the prescription shows stopped.
    await db.setMedicineActive((await medicinesOf(rx)).first.id, true);
    expect(await active(), isTrue);
    // The only one taken is deleted.
    await db.softDeleteMedicine((await medicinesOf(rx)).first.id);
    expect(await active(), isFalse);
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

  test('every N hours is laid out on the clock from the first time', () {
    List<String> keys(int h, int m, int every) => [
      for (final t in everyHours(DoseTime(h, m), every)) t.key,
    ];
    expect(keys(8, 0, 8), ['00:00', '08:00', '16:00']);
    expect(keys(9, 30, 12), ['09:30', '21:30']);
    expect(keys(6, 0, 6), ['00:00', '06:00', '12:00', '18:00']);
    expect(keys(22, 0, 4), [
      '02:00',
      '06:00',
      '10:00',
      '14:00',
      '18:00',
      '22:00',
    ]);
    expect(() => everyHours(const DoseTime(8, 0), 0), throwsArgumentError);
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
      stoppedWithPrescription: false,
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

    // Meaningful only where the clocks change in late October 2026; CI
    // runs this file again with TZ=Africa/Cairo (see app-ci.yml).
    final noClockChange =
        DateTime(2026, 10, 28).timeZoneOffset ==
        DateTime(2026, 11, 2).timeZoneOffset;
    test(
      'across a clock change',
      skip: noClockChange
          ? 'no clock change here; run with TZ=Africa/Cairo'
          : false,
      () {
        // Egypt's summer time ended on 29-30 October 2026.
        final m = course(DateTime(2026, 10, 28), DateTime(2026, 11, 2));
        expect(courseDays(m), 6);
        for (var day = 1; day <= 6; day++) {
          for (final hour in [0, 12, 23]) {
            expect(courseProgress(m, DateTime(2026, 10, 27 + day, hour, 30)), (
              day: day,
              total: 6,
            ), reason: 'day $day $hour:30');
          }
        }
      },
    );

    test('none for ongoing medicines', () {
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

  group('migration from v6 (drift_schemas snapshot)', () {
    late SchemaVerifier verifier;
    setUpAll(() {
      // Each test opens its own database on its own connection.
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      verifier = SchemaVerifier(GeneratedHelper());
    });

    test('the upgraded schema matches a fresh v7 one', () async {
      final schema = await verifier.schemaAt(6);
      final upgraded = AppDatabase(schema.newConnection());
      addTearDown(upgraded.close);
      await verifier.migrateAndValidate(upgraded, 7);
    });

    test('a v6 database keeps its medicines and gains prescriptions', () async {
      final schema = await verifier.schemaAt(6);
      schema.rawDatabase.execute('''
        INSERT INTO profiles (id, display_name, updated_at)
          VALUES ('p1', 'Mona', 0);
        INSERT INTO medicines (id, profile_id, name, start_on, updated_at)
          VALUES ('m1', 'p1', 'Metformin', 1767225600, 0);
        INSERT INTO dose_schedules (id, medicine_id, times, updated_at)
          VALUES ('s1', 'm1', '08:00', 0);
      ''');
      final upgraded = AppDatabase(schema.newConnection());
      addTearDown(upgraded.close);

      final kept = (await upgraded.watchMedicine('m1').first)!;
      expect(kept.name, 'Metformin');
      expect(kept.prescriptionId, isNull);
      expect(kept.position, isNull);
      expect(kept.stoppedWithPrescription, isFalse);
      expect((await upgraded.watchRegimens().first).single.medicine.id, 'm1');

      final rx = await upgraded.savePrescription(
        profileId: 'p1',
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
                profileId: 'p1',
                name: 'x',
                startOn: DateTime.utc(2026),
                updatedAt: DateTime.utc(2026),
                prescriptionId: const Value('missing'),
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });
  });
}
