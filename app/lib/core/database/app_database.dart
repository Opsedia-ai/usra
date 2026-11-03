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
    OutboxEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  static const _uuid = Uuid();

  @override
  int get schemaVersion => 5;

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

  /// Marks a profile and all its records, their attachments and insurance
  /// cards deleted (kept for sync) instead of erasing them. Photos are
  /// files: prune them with `PhotoStore.prune(liveInsurancePhotos())` and
  /// `PhotoStore.prune(liveAttachmentPaths())` afterwards.
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
