import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Profiles, MedicalEvents, Doctors, InsuranceCards, OutboxEntries],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  static const _uuid = Uuid();

  @override
  int get schemaVersion => 4;

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
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await _queue('profile', id, 'upsert');
    });
    return id;
  }

  /// Marks a profile and all its records and insurance cards deleted (kept
  /// for sync) instead of erasing them. Card photos are files: prune them
  /// with `CardPhotoStore.prune(liveInsurancePhotos())` afterwards.
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
    });
    return id;
  }

  static String? _clean(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();

  Future<void> softDeleteEvent(String id) async {
    final now = DateTime.now().toUtc();
    await transaction(() async {
      await (update(medicalEvents)..where((e) => e.id.equals(id))).write(
        MedicalEventsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await _queue('medical_event', id, 'delete');
    });
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
