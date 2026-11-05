import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Profiles,
    MedicalEvents,
    Doctors,
    InsuranceCards,
    Attachments,
    Medicines,
    Prescriptions,
    DoseSchedules,
    DoseLogs,
    OutboxEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  static const _uuid = Uuid();

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(profiles, profiles.bloodType);
        await m.addColumn(profiles, profiles.allergies);
        await m.addColumn(profiles, profiles.conditions);
      }
      if (from < 3) {
        await m.createTable(doctors);
      }
      if (from < 4) {
        await m.createTable(insuranceCards);
      }
      if (from < 5) {
        await m.createTable(attachments);
      }
      if (from < 6) {
        await m.createTable(medicines);
        await m.createTable(doseSchedules);
        await m.createTable(doseLogs);
        await m.createIndex(doseLogsDose);
      }
      if (from < 7) {
        await m.createTable(prescriptions);
        // A table created above (from < 6) already has the columns.
        if (from >= 6) {
          await m.addColumn(medicines, medicines.prescriptionId);
          await m.addColumn(medicines, medicines.position);
          await m.addColumn(medicines, medicines.stoppedWithPrescription);
        }
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Stream<Profile?> watchProfile(String id) {
    return (select(profiles)
          ..where((p) => p.id.equals(id) & p.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  /// Updates a profile's details and records the change in the outbox.
  Future<void> updateProfile(
    String id, {
    required String displayName,
    DateTime? birthDate,
    String? sex,
    String? bloodType,
    String? allergies,
    String? conditions,
    bool? simpleMode,
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(
        displayName,
        'displayName',
        'must not be empty',
      );
    }
    await transaction(() async {
      await (update(profiles)..where((p) => p.id.equals(id))).write(
        ProfilesCompanion(
          displayName: Value(name),
          birthDate: Value(birthDate),
          sex: Value(_clean(sex)),
          bloodType: Value(_clean(bloodType)),
          allergies: Value(_clean(allergies)),
          conditions: Value(_clean(conditions)),
          simpleMode: Value.absentIfNull(simpleMode),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      await _queue('profile', id, 'upsert');
    });
  }

  /// Profiles that are not deleted, in the order they were added.
  /// UUID v7 ids sort by creation time, so editing never reorders the list.
  Stream<List<Profile>> watchProfiles() {
    final query = select(profiles)
      ..where((p) => p.deletedAt.isNull())
      ..orderBy([(p) => OrderingTerm.asc(p.id)]);
    return query.watch();
  }

  /// Creates a profile and records the change in the outbox.
  Future<String> addProfile(
    String displayName, {
    DateTime? birthDate,
    String? sex,
    String? bloodType,
    String? allergies,
    String? conditions,
    bool? simpleMode,
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(
        displayName,
        'displayName',
        'must not be empty',
      );
    }
    final id = _uuid.v7();
    await transaction(() async {
      await into(profiles).insert(
        ProfilesCompanion.insert(
          id: id,
          displayName: name,
          birthDate: Value(birthDate),
          sex: Value(_clean(sex)),
          bloodType: Value(_clean(bloodType)),
          allergies: Value(_clean(allergies)),
          conditions: Value(_clean(conditions)),
          simpleMode: Value.absentIfNull(simpleMode),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await _queue('profile', id, 'upsert');
    });
    return id;
  }

  /// Marks a profile and all its records, their attachments, insurance
  /// cards and medicines deleted (kept for sync) instead of erasing them.
  /// Photos are files: prune them with `PhotoStore.prune(...)` and
  /// [liveInsurancePhotos], [liveAttachmentPaths] and [liveMedicinePhotos]
  /// afterwards.
  Future<void> softDeleteProfile(String id) async {
    final now = DateTime.now().toUtc();
    await transaction(() async {
      await (update(profiles)..where((p) => p.id.equals(id))).write(
        ProfilesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await _queue('profile', id, 'delete');

      final liveEvents =
          medicalEvents.profileId.equals(id) & medicalEvents.deletedAt.isNull();
      final eventIds =
          await (selectOnly(medicalEvents)
                ..addColumns([medicalEvents.id])
                ..where(liveEvents))
              .map((row) => row.read(medicalEvents.id)!)
              .get();
      await (update(medicalEvents)..where((_) => liveEvents)).write(
        MedicalEventsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      for (final eventId in eventIds) {
        await _queue('medical_event', eventId, 'delete');
      }
      await _softDeleteAttachments(
        attachments.eventId.isInQuery(
          selectOnly(medicalEvents)
            ..addColumns([medicalEvents.id])
            ..where(medicalEvents.profileId.equals(id)),
        ),
        now,
      );

      final liveCards =
          insuranceCards.profileId.equals(id) &
          insuranceCards.deletedAt.isNull();
      final cardIds =
          await (selectOnly(insuranceCards)
                ..addColumns([insuranceCards.id])
                ..where(liveCards))
              .map((row) => row.read(insuranceCards.id)!)
              .get();
      await (update(insuranceCards)..where((_) => liveCards)).write(
        InsuranceCardsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      for (final cardId in cardIds) {
        await _queue('insurance_card', cardId, 'delete');
      }

      final medicineIds =
          await (selectOnly(medicines)
                ..addColumns([medicines.id])
                ..where(
                  medicines.profileId.equals(id) & medicines.deletedAt.isNull(),
                ))
              .map((row) => row.read(medicines.id)!)
              .get();
      for (final medicineId in medicineIds) {
        await _softDeleteMedicine(medicineId, now);
      }

      final prescriptionIds =
          await (selectOnly(prescriptions)
                ..addColumns([prescriptions.id])
                ..where(
                  prescriptions.profileId.equals(id) &
                      prescriptions.deletedAt.isNull(),
                ))
              .map((row) => row.read(prescriptions.id)!)
              .get();
      for (final prescriptionId in prescriptionIds) {
        await _softDeletePrescription(prescriptionId, now);
      }
    });
  }

  Stream<List<MedicalEvent>> watchTimeline(String profileId) {
    final query = select(medicalEvents)
      ..where((e) => e.profileId.equals(profileId) & e.deletedAt.isNull())
      ..orderBy([
        (e) => OrderingTerm.desc(e.occurredAt),
        // Same-day records: newest insert first. UUID v7 isn't monotonic
        // within one millisecond, rowid is.
        (e) => OrderingTerm.desc(const CustomExpression<int>('rowid')),
      ]);
    return query.watch();
  }

  Future<String> addEvent({
    required String profileId,
    required String type,
    required DateTime occurredAt,
    String dataJson = '{}',
    int? costMinor,
    String? currency,
    String? doctorId,
    List<String> photos = const [],
  }) async {
    final id = _uuid.v7();
    await transaction(() async {
      await into(medicalEvents).insert(
        MedicalEventsCompanion.insert(
          id: id,
          profileId: profileId,
          type: type,
          occurredAt: occurredAt,
          dataJson: Value(dataJson),
          costMinor: Value(costMinor),
          currency: Value(currency),
          doctorId: Value(doctorId),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await _queue('medical_event', id, 'upsert');
      for (final path in photos) {
        await _insertAttachment(id, path);
      }
    });
    return id;
  }

  static String? _clean(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();

  Stream<MedicalEvent?> watchEvent(String id) {
    return (select(medicalEvents)
          ..where((e) => e.id.equals(id) & e.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  /// Marks a record and its attachments deleted. Prune the photo files with
  /// `PhotoStore.prune(liveAttachmentPaths())` afterwards.
  Future<void> softDeleteEvent(String id) async {
    final now = DateTime.now().toUtc();
    await transaction(() async {
      await (update(medicalEvents)..where((e) => e.id.equals(id))).write(
        MedicalEventsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await _queue('medical_event', id, 'delete');
      await _softDeleteAttachments(attachments.eventId.equals(id), now);
    });
  }

  /// Saves [dataJson] as [profileId]'s one live record of [type] (a
  /// setting kept with the person's records, like their vaccine plan):
  /// updated in place when there is one, created otherwise.
  Future<String> saveSingletonEvent({
    required String profileId,
    required String type,
    required String dataJson,
  }) async {
    final now = DateTime.now().toUtc();
    return transaction(() async {
      final existing =
          await (select(medicalEvents)
                ..where(
                  (e) =>
                      e.profileId.equals(profileId) &
                      e.type.equals(type) &
                      e.deletedAt.isNull(),
                )
                ..orderBy([(e) => OrderingTerm.desc(e.updatedAt)])
                ..limit(1))
              .getSingleOrNull();
      if (existing == null) {
        final id = _uuid.v7();
        await into(medicalEvents).insert(
          MedicalEventsCompanion.insert(
            id: id,
            profileId: profileId,
            type: type,
            occurredAt: now,
            dataJson: Value(dataJson),
            updatedAt: now,
          ),
        );
        await _queue('medical_event', id, 'upsert');
        return id;
      }
      if (existing.dataJson != dataJson) {
        await (update(
          medicalEvents,
        )..where((e) => e.id.equals(existing.id))).write(
          MedicalEventsCompanion(
            dataJson: Value(dataJson),
            updatedAt: Value(now),
          ),
        );
        await _queue('medical_event', existing.id, 'upsert');
      }
      return existing.id;
    });
  }

  /// Adds [add] records and marks the records [remove] deleted, all or
  /// nothing: the vaccine checklist saves this way.
  ///
  /// [redate] moves records to a new date in place, keeping everything else
  /// on them (photos, doctor, cost).
  Future<void> replaceEvents({
    required String profileId,
    List<({String type, DateTime occurredAt, String dataJson})> add = const [],
    Iterable<String> remove = const [],
    Map<String, DateTime> redate = const {},
  }) async {
    final now = DateTime.now().toUtc();
    await transaction(() async {
      for (final MapEntry(key: id, value: date) in redate.entries) {
        await (update(
          medicalEvents,
        )..where((e) => e.id.equals(id) & e.profileId.equals(profileId))).write(
          MedicalEventsCompanion(
            occurredAt: Value(date),
            updatedAt: Value(now),
          ),
        );
        await _queue('medical_event', id, 'upsert');
      }
      for (final id in remove) {
        await (update(
          medicalEvents,
        )..where((e) => e.id.equals(id) & e.profileId.equals(profileId))).write(
          MedicalEventsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
        await _queue('medical_event', id, 'delete');
        await _softDeleteAttachments(attachments.eventId.equals(id), now);
      }
      for (final r in add) {
        final id = _uuid.v7();
        await into(medicalEvents).insert(
          MedicalEventsCompanion.insert(
            id: id,
            profileId: profileId,
            type: r.type,
            occurredAt: r.occurredAt,
            dataJson: Value(r.dataJson),
            updatedAt: now,
          ),
        );
        await _queue('medical_event', id, 'upsert');
      }
    });
  }

  /// Emits when a record of [types] is added, changed or deleted (and
  /// once at the start); changes to other records don't.
  Stream<void> watchEventChanges(Set<String> types) =>
      (select(medicalEvents)..where((e) => e.type.isIn(types)))
          .watch()
          .map(
            (rows) => [
              for (final e in rows)
                '${e.id}:${e.updatedAt.microsecondsSinceEpoch}:'
                    '${e.deletedAt != null}',
            ].join(','),
          )
          .distinct();

  /// Live records of [types], for everyone in the family, oldest first.
  Future<List<MedicalEvent>> eventsOfTypes(Set<String> types) {
    final query =
        select(medicalEvents).join([
            innerJoin(profiles, profiles.id.equalsExp(medicalEvents.profileId)),
          ])
          ..where(
            medicalEvents.type.isIn(types) &
                medicalEvents.deletedAt.isNull() &
                profiles.deletedAt.isNull(),
          )
          ..orderBy([OrderingTerm.asc(medicalEvents.occurredAt)]);
    return query.map((row) => row.readTable(medicalEvents)).get();
  }

  /// A record's live attachments, in the order they were added.
  Stream<List<Attachment>> watchAttachments(String eventId) {
    final query = select(attachments)
      ..where((a) => a.eventId.equals(eventId) & a.deletedAt.isNull())
      // Photos saved together share a millisecond, where UUID v7 isn't
      // monotonic; rowid keeps the order they were picked in.
      ..orderBy([
        (_) => OrderingTerm.asc(const CustomExpression<int>('rowid')),
      ]);
    return query.watch();
  }

  /// How many live attachments each of a person's records has; records
  /// without any are left out.
  Stream<Map<String, int>> watchAttachmentCounts(String profileId) {
    final count = attachments.id.count();
    final query =
        selectOnly(attachments).join([
            innerJoin(
              medicalEvents,
              medicalEvents.id.equalsExp(attachments.eventId),
              useColumns: false,
            ),
          ])
          ..addColumns([attachments.eventId, count])
          ..where(
            medicalEvents.profileId.equals(profileId) &
                attachments.deletedAt.isNull(),
          )
          ..groupBy([attachments.eventId]);
    return query.watch().map(
      (rows) => {
        for (final r in rows) r.read(attachments.eventId)!: r.read(count)!,
      },
    );
  }

  /// Attaches already-stored files to a live record. Returns their ids.
  Future<List<String>> addAttachments(String eventId, List<String> paths) {
    return transaction(() async {
      final live =
          await (select(medicalEvents)
                ..where((e) => e.id.equals(eventId) & e.deletedAt.isNull()))
              .getSingleOrNull();
      if (live == null) throw StateError('Record $eventId not found');
      return [for (final path in paths) await _insertAttachment(eventId, path)];
    });
  }

  Future<void> softDeleteAttachment(String id) async {
    await transaction(
      () => _softDeleteAttachments(
        attachments.id.equals(id),
        DateTime.now().toUtc(),
      ),
    );
  }

  /// Attachment files still used by a live record; any other file in the
  /// attachments folder can go.
  Future<Set<String>> liveAttachmentPaths() async {
    final query = selectOnly(attachments)
      ..addColumns([attachments.path])
      ..where(attachments.deletedAt.isNull());
    return {for (final r in await query.get()) r.read(attachments.path)!};
  }

  Future<String> _insertAttachment(
    String eventId,
    String path, {
    String kind = 'photo',
  }) async {
    final id = _uuid.v7();
    final now = DateTime.now().toUtc();
    await into(attachments).insert(
      AttachmentsCompanion.insert(
        id: id,
        eventId: eventId,
        path: path,
        kind: Value(kind),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await _queue('attachment', id, 'upsert');
    return id;
  }

  /// Soft-deletes the live attachments matching [where]; call in a
  /// transaction.
  Future<void> _softDeleteAttachments(
    Expression<bool> where,
    DateTime now,
  ) async {
    final live = where & attachments.deletedAt.isNull();
    final ids =
        await (selectOnly(attachments)
              ..addColumns([attachments.id])
              ..where(live))
            .map((row) => row.read(attachments.id)!)
            .get();
    await (update(attachments)..where((_) => live)).write(
      AttachmentsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    for (final id in ids) {
      await _queue('attachment', id, 'delete');
    }
  }

  /// Doctors that are not deleted, by name.
  Stream<List<Doctor>> watchDoctors() {
    final query = select(doctors)
      ..where((d) => d.deletedAt.isNull())
      ..orderBy([(d) => OrderingTerm.asc(d.name)]);
    return query.watch();
  }

  Stream<Doctor?> watchDoctor(String id) {
    return (select(doctors)
          ..where((d) => d.id.equals(id) & d.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  /// Creates a doctor, or updates [id] when given. Returns the doctor's id.
  Future<String> saveDoctor({
    String? id,
    required String name,
    String? specialty,
    String? phone,
    String? clinic,
    String? address,
    int? feeMinor,
    String? notes,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    final doctorId = id ?? _uuid.v7();
    final row = DoctorsCompanion(
      id: Value(doctorId),
      name: Value(cleanName),
      specialty: Value(_clean(specialty)),
      phone: Value(_clean(phone)),
      clinic: Value(_clean(clinic)),
      address: Value(_clean(address)),
      feeMinor: Value(feeMinor),
      notes: Value(_clean(notes)),
      updatedAt: Value(DateTime.now().toUtc()),
    );
    await transaction(() async {
      if (id == null) {
        await into(doctors).insert(row);
      } else {
        await (update(doctors)..where((d) => d.id.equals(id))).write(row);
      }
      await _queue('doctor', doctorId, 'upsert');
    });
    return doctorId;
  }

  /// Marks a doctor deleted. Past visits keep their link and the name saved
  /// in the visit, so history is never lost.
  Future<void> softDeleteDoctor(String id) async {
    final now = DateTime.now().toUtc();
    await transaction(() async {
      await (update(doctors)..where((d) => d.id.equals(id))).write(
        DoctorsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await _queue('doctor', id, 'delete');
    });
  }

  /// Every family member's live records with this doctor, newest first.
  Stream<List<DoctorVisit>> watchDoctorVisits(String doctorId) {
    final query =
        select(medicalEvents).join([
            innerJoin(profiles, profiles.id.equalsExp(medicalEvents.profileId)),
          ])
          ..where(
            medicalEvents.doctorId.equals(doctorId) &
                medicalEvents.deletedAt.isNull() &
                profiles.deletedAt.isNull(),
          )
          ..orderBy([OrderingTerm.desc(medicalEvents.occurredAt)]);
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          DoctorVisit(
            event: r.readTable(medicalEvents),
            person: r.readTable(profiles),
          ),
      ],
    );
  }

  /// A person's live insurance cards, in the order they were added.
  Stream<List<InsuranceCard>> watchInsuranceCards(String profileId) {
    final query = select(insuranceCards)
      ..where((c) => c.profileId.equals(profileId) & c.deletedAt.isNull())
      ..orderBy([(c) => OrderingTerm.asc(c.id)]);
    return query.watch();
  }

  Stream<InsuranceCard?> watchInsuranceCard(String id) {
    return (select(insuranceCards)
          ..where((c) => c.id.equals(id) & c.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  /// Creates a card for [profileId], or updates [id] when given.
  /// Returns the card's id.
  Future<String> saveInsuranceCard({
    String? id,
    required String profileId,
    required String label,
    String? insurer,
    String? memberNumber,
    DateTime? expiresOn,
    String? notes,
    String? frontPhoto,
    String? backPhoto,
  }) async {
    final cleanLabel = label.trim();
    if (cleanLabel.isEmpty) {
      throw ArgumentError.value(label, 'label', 'must not be empty');
    }
    final cardId = id ?? _uuid.v7();
    final row = InsuranceCardsCompanion(
      id: Value(cardId),
      profileId: Value(profileId),
      label: Value(cleanLabel),
      insurer: Value(_clean(insurer)),
      memberNumber: Value(_clean(memberNumber)),
      expiresOn: Value(
        expiresOn == null
            ? null
            : DateTime.utc(expiresOn.year, expiresOn.month, expiresOn.day),
      ),
      notes: Value(_clean(notes)),
      frontPhoto: Value(frontPhoto),
      backPhoto: Value(backPhoto),
      updatedAt: Value(DateTime.now().toUtc()),
    );
    await transaction(() async {
      if (id == null) {
        await into(insuranceCards).insert(row);
      } else {
        final changed = await (update(
          insuranceCards,
        )..where((c) => c.id.equals(id) & c.deletedAt.isNull())).write(row);
        // Deleted meanwhile (or never existed): don't revive a tombstone.
        if (changed == 0) throw StateError('Insurance card $id not found');
      }
      await _queue('insurance_card', cardId, 'upsert');
    });
    return cardId;
  }

  Future<void> softDeleteInsuranceCard(String id) async {
    final now = DateTime.now().toUtc();
    await transaction(() async {
      await (update(insuranceCards)..where((c) => c.id.equals(id))).write(
        InsuranceCardsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await _queue('insurance_card', id, 'delete');
    });
  }

  /// Photo paths still used by a live card; any other photo file can go.
  Future<Set<String>> liveInsurancePhotos() async {
    final query = selectOnly(insuranceCards)
      ..addColumns([insuranceCards.frontPhoto, insuranceCards.backPhoto])
      ..where(insuranceCards.deletedAt.isNull());
    final rows = await query.get();
    return {
      for (final r in rows) ...[
        ?r.read(insuranceCards.frontPhoto),
        ?r.read(insuranceCards.backPhoto),
      ],
    };
  }

  /// A person's live medicines: the ones still taken first, then by name.
  Stream<List<Medicine>> watchMedicines(String profileId) {
    final query = select(medicines)
      ..where((m) => m.profileId.equals(profileId) & m.deletedAt.isNull())
      ..orderBy([
        (m) => OrderingTerm.desc(m.active),
        (m) => OrderingTerm.asc(m.name),
      ]);
    return query.watch();
  }

  Stream<Medicine?> watchMedicine(String id) {
    return (select(medicines)
          ..where((m) => m.id.equals(id) & m.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  /// A medicine's live schedule, or null when it's taken as needed.
  Stream<DoseSchedule?> watchDoseSchedule(String medicineId) {
    return (select(doseSchedules)
          ..where((s) => s.medicineId.equals(medicineId) & s.deletedAt.isNull())
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Creates a medicine for [profileId], or updates [id] when given, with
  /// its [schedule] (null: no reminders). Returns the medicine's id.
  Future<String> saveMedicine({
    String? id,
    required String profileId,
    required String name,
    String? strength,
    String? form,
    String? instructions,
    String? doctorId,
    required DateTime startOn,
    DateTime? endOn,
    List<String> photos = const [],
    bool active = true,
    DoseScheduleInput? schedule,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    final start = _day(startOn);
    final end = endOn == null ? null : _day(endOn);
    if (end != null && end.isBefore(start)) {
      throw ArgumentError.value(endOn, 'endOn', 'is before startOn');
    }
    final medicineId = id ?? _uuid.v7();
    final now = DateTime.now().toUtc();
    final row = MedicinesCompanion(
      id: Value(medicineId),
      profileId: Value(profileId),
      name: Value(cleanName),
      strength: Value(_clean(strength)),
      form: Value(_clean(form)),
      instructions: Value(_clean(instructions)),
      doctorId: Value(doctorId),
      startOn: Value(start),
      endOn: Value(end),
      photosJson: Value(jsonEncode(photos)),
      active: Value(active),
      updatedAt: Value(now),
    );
    await transaction(() async {
      if (id == null) {
        await into(medicines).insert(row);
      } else {
        final changed = await (update(
          medicines,
        )..where((m) => m.id.equals(id) & m.deletedAt.isNull())).write(row);
        // Deleted meanwhile (or never existed): don't revive a tombstone.
        if (changed == 0) throw StateError('Medicine $id not found');
      }
      await _queue('medicine', medicineId, 'upsert');
      await _replaceSchedule(medicineId, schedule, now);
    });
    return medicineId;
  }

  /// Keeps one live schedule per medicine: updates it in place, adds it, or
  /// deletes it when [schedule] is null. Call in a transaction.
  Future<void> _replaceSchedule(
    String medicineId,
    DoseScheduleInput? schedule,
    DateTime now,
  ) async {
    final current =
        await (select(doseSchedules)..where(
              (s) => s.medicineId.equals(medicineId) & s.deletedAt.isNull(),
            ))
            .get();
    if (schedule == null || schedule.times.isEmpty) {
      for (final s in current) {
        await (update(doseSchedules)..where((x) => x.id.equals(s.id))).write(
          DoseSchedulesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
        await _queue('dose_schedule', s.id, 'delete');
      }
      return;
    }
    if (schedule.everyNDays != null && schedule.everyNDays! < 1) {
      throw ArgumentError.value(schedule.everyNDays, 'everyNDays');
    }
    final weekdays = schedule.weekdays;
    final row = DoseSchedulesCompanion(
      medicineId: Value(medicineId),
      times: Value(schedule.times.join(',')),
      // Every day of the week is the same as no limit.
      weekdays: Value(
        weekdays == null || weekdays & 0x7f == 0x7f ? null : weekdays & 0x7f,
      ),
      everyNDays: Value(
        schedule.everyNDays == null || schedule.everyNDays! <= 1
            ? null
            : schedule.everyNDays,
      ),
      amount: Value(_clean(schedule.amount)),
      updatedAt: Value(now),
    );
    if (row.weekdays.value == 0) {
      throw ArgumentError.value(weekdays, 'weekdays', 'has no day');
    }
    final String scheduleId;
    if (current.isEmpty) {
      scheduleId = _uuid.v7();
      await into(doseSchedules).insert(row.copyWith(id: Value(scheduleId)));
    } else {
      scheduleId = current.first.id;
      await (update(
        doseSchedules,
      )..where((s) => s.id.equals(scheduleId))).write(row);
    }
    await _queue('dose_schedule', scheduleId, 'upsert');
  }

  /// Stops or restarts reminders for a medicine, keeping its history.
  Future<void> setMedicineActive(String id, bool active) async {
    await transaction(() async {
      final now = DateTime.now().toUtc();
      final changed =
          await (update(
            medicines,
          )..where((m) => m.id.equals(id) & m.deletedAt.isNull())).write(
            MedicinesCompanion(
              active: Value(active),
              // Decided on its own now, not with its prescription.
              stoppedWithPrescription: const Value(false),
              updatedAt: Value(now),
            ),
          );
      if (changed == 0) throw StateError('Medicine $id not found');
      await _queue('medicine', id, 'upsert');
      await _refreshPrescriptionOf(id, now);
    });
  }

  /// Keeps the status of [medicineId]'s prescription, if any, in step.
  Future<void> _refreshPrescriptionOf(String medicineId, DateTime now) async {
    final row =
        await (selectOnly(medicines)
              ..addColumns([medicines.prescriptionId])
              ..where(medicines.id.equals(medicineId)))
            .getSingleOrNull();
    final prescriptionId = row?.read(medicines.prescriptionId);
    if (prescriptionId != null) {
      await _refreshPrescription(prescriptionId, now);
    }
  }

  /// Marks a medicine, its schedule and dose log deleted. Prune the photo
  /// files with `PhotoStore.prune(liveMedicinePhotos())` afterwards.
  Future<void> softDeleteMedicine(String id) async {
    final now = DateTime.now().toUtc();
    await transaction(() async {
      await _softDeleteMedicine(id, now);
      await _refreshPrescriptionOf(id, now);
    });
  }

  Future<void> _softDeleteMedicine(String id, DateTime now) async {
    await (update(medicines)..where((m) => m.id.equals(id))).write(
      MedicinesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    await _queue('medicine', id, 'delete');
    final liveSchedules =
        doseSchedules.medicineId.equals(id) & doseSchedules.deletedAt.isNull();
    final scheduleIds =
        await (selectOnly(doseSchedules)
              ..addColumns([doseSchedules.id])
              ..where(liveSchedules))
            .map((row) => row.read(doseSchedules.id)!)
            .get();
    await (update(doseSchedules)..where((_) => liveSchedules)).write(
      DoseSchedulesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    for (final s in scheduleIds) {
      await _queue('dose_schedule', s, 'delete');
    }
    final liveLogs =
        doseLogs.medicineId.equals(id) & doseLogs.deletedAt.isNull();
    final logIds =
        await (selectOnly(doseLogs)
              ..addColumns([doseLogs.id])
              ..where(liveLogs))
            .map((row) => row.read(doseLogs.id)!)
            .get();
    await (update(doseLogs)..where((_) => liveLogs)).write(
      DoseLogsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    for (final l in logIds) {
      await _queue('dose_log', l, 'delete');
    }
  }

  /// Files in the medicines photo store still used by a live medicine or
  /// prescription.
  Future<Set<String>> liveMedicinePhotos() async {
    final query = selectOnly(medicines)
      ..addColumns([medicines.photosJson])
      ..where(medicines.deletedAt.isNull());
    final rx = selectOnly(prescriptions)
      ..addColumns([prescriptions.photosJson])
      ..where(prescriptions.deletedAt.isNull());
    return {
      for (final r in await query.get())
        ...decodeMedicinePhotos(r.read(medicines.photosJson)!),
      for (final r in await rx.get())
        ...decodeMedicinePhotos(r.read(prescriptions.photosJson)!),
    };
  }

  /// A person's live prescriptions, newest first.
  Stream<List<Prescription>> watchPrescriptions(String profileId) {
    final query = select(prescriptions)
      ..where((p) => p.profileId.equals(profileId) & p.deletedAt.isNull())
      ..orderBy([
        (p) => OrderingTerm.desc(p.prescribedOn),
        (p) => OrderingTerm.desc(p.id),
      ]);
    return query.watch();
  }

  Stream<Prescription?> watchPrescription(String id) {
    return (select(prescriptions)
          ..where((p) => p.id.equals(id) & p.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  /// The live medicines written on a prescription, in the order entered.
  Stream<List<Medicine>> watchPrescriptionMedicines(String prescriptionId) {
    final query = select(medicines)
      ..where(
        (m) => m.prescriptionId.equals(prescriptionId) & m.deletedAt.isNull(),
      )
      ..orderBy([
        (m) => OrderingTerm(expression: m.position, nulls: NullsOrder.last),
        (m) => OrderingTerm.asc(m.id),
      ]);
    return query.watch();
  }

  /// Saves a prescription and all its medicines, schedules included, in one
  /// transaction: creates it, or updates [id] when given. Items with a
  /// `medicineId` update that medicine and keep what its own page changed
  /// (form, days of the week, amount, stopped on its own); new items start
  /// taken. The prescription's medicines no longer in [items] are stopped
  /// and taken off it, keeping their dose history. Returns the
  /// prescription's id.
  ///
  /// Doses are stored as the text the doctor wrote; nothing is computed.
  Future<String> savePrescription({
    String? id,
    required String profileId,
    String? doctorId,
    required DateTime prescribedOn,
    String? diagnosis,
    String? notes,
    List<String> photos = const [],
    required List<PrescriptionItemInput> items,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items', 'needs at least one medicine');
    }
    for (final item in items) {
      if (item.name.trim().isEmpty) {
        throw ArgumentError.value(item.name, 'name', 'must not be empty');
      }
      if (item.days != null && (item.days! < 1 || item.days! > maxCourseDays)) {
        throw ArgumentError.value(item.days, 'days', 'is out of range');
      }
    }
    final prescriptionId = id ?? _uuid.v7();
    final now = DateTime.now().toUtc();
    final row = PrescriptionsCompanion(
      id: Value(prescriptionId),
      profileId: Value(profileId),
      doctorId: Value(doctorId),
      prescribedOn: Value(_day(prescribedOn)),
      diagnosis: Value(_clean(diagnosis)),
      notes: Value(_clean(notes)),
      photosJson: Value(jsonEncode(photos)),
      updatedAt: Value(now),
    );
    await transaction(() async {
      if (id == null) {
        await into(prescriptions).insert(row);
      } else {
        final changed = await (update(
          prescriptions,
        )..where((p) => p.id.equals(id) & p.deletedAt.isNull())).write(row);
        if (changed == 0) throw StateError('Prescription $id not found');
      }
      await _queue('prescription', prescriptionId, 'upsert');

      final current = (await _prescriptionMedicineIds(prescriptionId)).toSet();
      final kept = <String>{};
      for (final (position, item) in items.indexed) {
        final existing = item.medicineId;
        if (existing != null && !current.contains(existing)) {
          throw StateError('Medicine $existing is not on this prescription');
        }
        final start = _day(item.startOn ?? prescribedOn);
        final medicineId = existing ?? _uuid.v7();
        final medicine = MedicinesCompanion(
          id: Value(medicineId),
          profileId: Value(profileId),
          prescriptionId: Value(prescriptionId),
          position: Value(position),
          name: Value(item.name.trim()),
          strength: Value(_clean(item.strength)),
          // Set on the medicine's own page; kept unless given here.
          form: existing != null && item.form == null
              ? const Value.absent()
              : Value(_clean(item.form)),
          instructions: Value(_clean(item.dose)),
          doctorId: Value(doctorId),
          startOn: Value(start),
          endOn: Value(
            item.days == null
                ? null
                : start.add(Duration(days: item.days! - 1)),
          ),
          // A medicine stopped, on its own or with the prescription, stays
          // as it is; see setPrescriptionActive.
          active: existing == null ? const Value(true) : const Value.absent(),
          updatedAt: Value(now),
        );
        if (existing == null) {
          await into(medicines).insert(medicine);
        } else {
          kept.add(existing);
          await (update(
            medicines,
          )..where((m) => m.id.equals(existing))).write(medicine);
        }
        await _queue('medicine', medicineId, 'upsert');
        // Keep what the medicine's own page added to its schedule (days of
        // the week, every N days, amount); the prescription sets the times.
        final schedule = existing == null
            ? null
            : await (select(doseSchedules)..where(
                    (s) => s.medicineId.equals(existing) & s.deletedAt.isNull(),
                  ))
                  .getSingleOrNull();
        await _replaceSchedule(
          medicineId,
          item.times.isEmpty
              ? null
              : DoseScheduleInput(
                  times: item.times,
                  weekdays: schedule?.weekdays,
                  everyNDays: schedule?.everyNDays,
                  amount: schedule?.amount,
                ),
          now,
        );
      }
      // Taken off the prescription: stopped, but its history is kept on its
      // own page.
      for (final removed in current.difference(kept)) {
        await (update(medicines)..where((m) => m.id.equals(removed))).write(
          MedicinesCompanion(
            prescriptionId: const Value(null),
            position: const Value(null),
            active: const Value(false),
            stoppedWithPrescription: const Value(false),
            updatedAt: Value(now),
          ),
        );
        await _queue('medicine', removed, 'upsert');
      }
      await _refreshPrescription(prescriptionId, now);
    });
    return prescriptionId;
  }

  /// Stops every medicine still taken on a prescription, remembering which;
  /// resuming restarts only those. A medicine stopped on its own stays
  /// stopped either way.
  Future<void> setPrescriptionActive(String id, bool active) async {
    final now = DateTime.now().toUtc();
    await transaction(() async {
      final exists =
          await (select(prescriptions)
                ..where((p) => p.id.equals(id) & p.deletedAt.isNull()))
              .getSingleOrNull();
      if (exists == null) throw StateError('Prescription $id not found');
      final onIt =
          medicines.prescriptionId.equals(id) & medicines.deletedAt.isNull();
      final affected = active
          ? onIt & medicines.stoppedWithPrescription.equals(true)
          : onIt & medicines.active.equals(true);
      final ids =
          await (selectOnly(medicines)
                ..addColumns([medicines.id])
                ..where(affected))
              .map((r) => r.read(medicines.id)!)
              .get();
      for (final medicineId in ids) {
        await (update(medicines)..where((m) => m.id.equals(medicineId))).write(
          MedicinesCompanion(
            active: Value(active),
            stoppedWithPrescription: Value(!active),
            updatedAt: Value(now),
          ),
        );
        await _queue('medicine', medicineId, 'upsert');
      }
      await _refreshPrescription(id, now);
    });
  }

  Future<List<String>> _prescriptionMedicineIds(String prescriptionId) =>
      (selectOnly(medicines)
            ..addColumns([medicines.id])
            ..where(
              medicines.prescriptionId.equals(prescriptionId) &
                  medicines.deletedAt.isNull(),
            ))
          .map((r) => r.read(medicines.id)!)
          .get();

  /// A prescription is taken while any of its medicines is. Call in a
  /// transaction after changing its medicines.
  Future<void> _refreshPrescription(String id, DateTime now) async {
    final taken =
        await (selectOnly(medicines)
              ..addColumns([medicines.id])
              ..where(
                medicines.prescriptionId.equals(id) &
                    medicines.deletedAt.isNull() &
                    medicines.active.equals(true),
              )
              ..limit(1))
            .getSingleOrNull() !=
        null;
    final changed =
        await (update(prescriptions)..where(
              (p) =>
                  p.id.equals(id) &
                  p.deletedAt.isNull() &
                  p.active.equals(!taken),
            ))
            .write(
              PrescriptionsCompanion(
                active: Value(taken),
                updatedAt: Value(now),
              ),
            );
    if (changed > 0) await _queue('prescription', id, 'upsert');
  }

  /// Marks a prescription and its medicines (with their schedules and dose
  /// logs) deleted. Prune photos with `liveMedicinePhotos()` afterwards.
  Future<void> softDeletePrescription(String id) async {
    await transaction(
      () => _softDeletePrescription(id, DateTime.now().toUtc()),
    );
  }

  Future<void> _softDeletePrescription(String id, DateTime now) async {
    await (update(prescriptions)..where((p) => p.id.equals(id))).write(
      PrescriptionsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    await _queue('prescription', id, 'delete');
    final ids =
        await (selectOnly(medicines)
              ..addColumns([medicines.id])
              ..where(
                medicines.prescriptionId.equals(id) &
                    medicines.deletedAt.isNull(),
              ))
            .map((r) => r.read(medicines.id)!)
            .get();
    for (final medicineId in ids) {
      await _softDeleteMedicine(medicineId, now);
    }
  }

  /// Every medicine someone in the family is taking now with a schedule,
  /// with whom it's for; ordered by person, then medicine name.
  Stream<List<Regimen>> watchRegimens() {
    final query =
        select(medicines).join([
            innerJoin(
              doseSchedules,
              doseSchedules.medicineId.equalsExp(medicines.id) &
                  doseSchedules.deletedAt.isNull(),
            ),
            innerJoin(profiles, profiles.id.equalsExp(medicines.profileId)),
          ])
          ..where(
            medicines.deletedAt.isNull() &
                medicines.active.equals(true) &
                profiles.deletedAt.isNull(),
          )
          ..orderBy([
            OrderingTerm.asc(profiles.id),
            OrderingTerm.asc(medicines.name),
          ]);
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          Regimen(
            medicine: r.readTable(medicines),
            schedule: r.readTable(doseSchedules),
            person: r.readTable(profiles),
          ),
      ],
    );
  }

  /// Live dose log entries planned between [from] (inclusive) and [to]
  /// (exclusive), for every medicine.
  Stream<List<DoseLog>> watchDoseLogs({
    required DateTime from,
    required DateTime to,
  }) {
    final query = select(doseLogs)
      ..where(
        (l) =>
            l.deletedAt.isNull() &
            l.scheduledAt.isBiggerOrEqualValue(from) &
            l.scheduledAt.isSmallerThanValue(to),
      );
    return query.watch();
  }

  /// A medicine's dose history, newest first.
  Stream<List<DoseLog>> watchMedicineDoseLogs(String medicineId) {
    final query = select(doseLogs)
      ..where((l) => l.medicineId.equals(medicineId) & l.deletedAt.isNull())
      ..orderBy([(l) => OrderingTerm.desc(l.scheduledAt)]);
    return query.watch();
  }

  /// Records what happened to the dose of [medicineId] planned for
  /// [scheduledAt]; marking it again replaces the earlier status, except
  /// that a snooze never undoes Taken or Skipped (a stale notification).
  /// Returns false when nothing was recorded for that reason.
  Future<bool> logDose(
    String medicineId,
    DateTime scheduledAt,
    String status, {
    DateTime? at,
  }) async {
    if (!DoseOutcome.all.contains(status)) {
      throw ArgumentError.value(status, 'status');
    }
    final now = DateTime.now().toUtc();
    final when = (at ?? now).toUtc();
    return transaction(() async {
      final existing =
          await (select(doseLogs)..where(
                (l) =>
                    l.medicineId.equals(medicineId) &
                    l.scheduledAt.equals(scheduledAt),
              ))
              .getSingleOrNull();
      if (status == DoseOutcome.snoozed &&
          existing != null &&
          existing.deletedAt == null &&
          existing.status != DoseOutcome.snoozed) {
        return false;
      }
      final String logId;
      if (existing == null) {
        logId = _uuid.v7();
        await into(doseLogs).insert(
          DoseLogsCompanion.insert(
            id: logId,
            medicineId: medicineId,
            scheduledAt: scheduledAt,
            status: status,
            at: when,
            updatedAt: now,
          ),
        );
      } else {
        logId = existing.id;
        await (update(doseLogs)..where((l) => l.id.equals(logId))).write(
          DoseLogsCompanion(
            status: Value(status),
            at: Value(when),
            updatedAt: Value(now),
            deletedAt: const Value(null),
          ),
        );
      }
      await _queue('dose_log', logId, 'upsert');
      return true;
    });
  }

  /// Takes back a mark (tapped by mistake): the dose is due again.
  Future<void> clearDoseLog(String medicineId, DateTime scheduledAt) async {
    final now = DateTime.now().toUtc();
    await transaction(() async {
      final existing =
          await (select(doseLogs)..where(
                (l) =>
                    l.medicineId.equals(medicineId) &
                    l.scheduledAt.equals(scheduledAt) &
                    l.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (existing == null) return;
      await (update(doseLogs)..where((l) => l.id.equals(existing.id))).write(
        DoseLogsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await _queue('dose_log', existing.id, 'delete');
    });
  }

  /// A calendar day as UTC midnight, the way dates are stored.
  static DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  /// Spending in [currency] for each period between consecutive [bounds]
  /// (each from inclusive, to exclusive), for the family or one person.
  /// Records with no currency count as [currency].
  Stream<List<int>> watchSpendingTotals(
    List<DateTime> bounds, {
    String? profileId,
    String currency = 'EGP',
  }) {
    if (bounds.length < 2) {
      throw ArgumentError.value(bounds, 'bounds', 'needs at least two dates');
    }
    final bucket = CaseWhenExpression<int>(
      cases: [
        for (var i = 1; i < bounds.length; i++)
          CaseWhen(
            medicalEvents.occurredAt.isSmallerThanValue(bounds[i]),
            then: Constant(i - 1),
          ),
      ],
    );
    final total = medicalEvents.costMinor.sum();
    final query = _spendingQuery(bounds.first, bounds.last, profileId, currency)
      ..addColumns([bucket, total])
      ..groupBy([bucket]);
    return query.watch().map((rows) {
      final totals = List.filled(bounds.length - 1, 0);
      for (final r in rows) {
        totals[r.read(bucket)!] = r.read(total) ?? 0;
      }
      return totals;
    });
  }

  /// Spending between [from] (inclusive) and [to] (exclusive), split by
  /// record type, person or doctor, biggest first. Records without a linked
  /// doctor are left out of the doctor split.
  Stream<List<SpendingSlice>> watchSpendingBy(
    SpendingGroup group, {
    required DateTime from,
    required DateTime to,
    String? profileId,
    String currency = 'EGP',
  }) {
    final (Expression<String> key, Expression<String>? label) = switch (group) {
      SpendingGroup.type => (medicalEvents.type, null),
      SpendingGroup.person => (medicalEvents.profileId, profiles.displayName),
      SpendingGroup.doctor => (medicalEvents.doctorId, doctors.name),
    };
    final total = medicalEvents.costMinor.sum();
    final count = medicalEvents.id.count();
    final query = _spendingQuery(from, to, profileId, currency)
      ..addColumns([key, ?label, total, count])
      ..groupBy([key, ?label])
      ..orderBy([OrderingTerm.desc(total), OrderingTerm.asc(key)]);
    if (group == SpendingGroup.doctor) {
      query
        ..join([
          leftOuterJoin(
            doctors,
            doctors.id.equalsExp(medicalEvents.doctorId),
            useColumns: false,
          ),
        ])
        ..where(medicalEvents.doctorId.isNotNull());
    }
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          SpendingSlice(
            key: r.read(key)!,
            label: label == null ? null : r.read(label),
            totalMinor: r.read(total) ?? 0,
            count: r.read(count) ?? 0,
          ),
      ],
    );
  }

  /// Live records with a cost in [from, to), of people still in the family.
  JoinedSelectStatement<HasResultSet, dynamic> _spendingQuery(
    DateTime from,
    DateTime to,
    String? profileId,
    String currency,
  ) {
    return selectOnly(medicalEvents).join([
        innerJoin(
          profiles,
          profiles.id.equalsExp(medicalEvents.profileId),
          useColumns: false,
        ),
      ])
      ..where(
        medicalEvents.deletedAt.isNull() &
            profiles.deletedAt.isNull() &
            medicalEvents.costMinor.isNotNull() &
            (medicalEvents.currency.isNull() |
                medicalEvents.currency.equals(currency)) &
            medicalEvents.occurredAt.isBiggerOrEqualValue(from) &
            medicalEvents.occurredAt.isSmallerThanValue(to),
      )
      ..where(
        profileId == null
            ? const Constant(true)
            : medicalEvents.profileId.equals(profileId),
      );
  }

  Future<void> _queue(String entity, String id, String operation) {
    return into(outboxEntries).insert(
      OutboxEntriesCompanion.insert(
        entity: entity,
        entityId: id,
        operation: operation,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }
}

/// A record with a doctor, and who in the family it was for.
class DoctorVisit {
  const DoctorVisit({required this.event, required this.person});

  final MedicalEvent event;
  final Profile person;
}

/// How spending is split on the Money tab.
enum SpendingGroup { type, person, doctor }

/// One line of a spending split: a record type, person or doctor.
class SpendingSlice {
  const SpendingSlice({
    required this.key,
    required this.label,
    required this.totalMinor,
    required this.count,
  });

  /// The record type key, profile id or doctor id.
  final String key;

  /// The person's or doctor's name; null for record types.
  final String? label;
  final int totalMinor;

  /// How many records add up to [totalMinor].
  final int count;
}

/// What can happen to a scheduled dose.
abstract final class DoseOutcome {
  static const taken = 'taken';
  static const skipped = 'skipped';
  static const snoozed = 'snoozed';
  static const all = {taken, skipped, snoozed};
}

/// A medicine's schedule as entered in the form.
class DoseScheduleInput {
  const DoseScheduleInput({
    required this.times,
    this.weekdays,
    this.everyNDays,
    this.amount,
  });

  /// "HH:mm" local times.
  final List<String> times;

  /// Bit mask, bit 0 = Monday; null for every day.
  final int? weekdays;
  final int? everyNDays;
  final String? amount;
}

/// The longest course a prescription takes, in days (about 100 years): any
/// end date the medicine's own page can pick fits.
const maxCourseDays = 36500;

/// One medicine on a prescription, as entered in the prescription form.
class PrescriptionItemInput {
  const PrescriptionItemInput({
    this.medicineId,
    required this.name,
    this.strength,
    this.form,
    this.dose,
    this.times = const [],
    this.startOn,
    this.days,
  });

  /// The medicine to update; null for a new one.
  final String? medicineId;
  final String name;
  final String? strength;
  final String? form;

  /// The dose exactly as the doctor wrote it, e.g. "5 مل بعد الأكل".
  /// Saved as the medicine's instructions; never computed.
  final String? dose;

  /// "HH:mm" local times; empty for no reminders.
  final List<String> times;

  /// First day; the prescription's date when null.
  final DateTime? startOn;

  /// How many days the course lasts, counting the first; null goes on.
  final int? days;
}

/// A medicine being taken on a schedule, and who takes it.
class Regimen {
  const Regimen({
    required this.medicine,
    required this.schedule,
    required this.person,
  });

  final Medicine medicine;
  final DoseSchedule schedule;
  final Profile person;
}

/// The photo paths saved in `Medicines.photosJson`.
List<String> decodeMedicinePhotos(String json) {
  try {
    final value = jsonDecode(json);
    return value is List
        ? [
            for (final p in value)
              if (p is String) p,
          ]
        : [];
  } on FormatException {
    return [];
  }
}
