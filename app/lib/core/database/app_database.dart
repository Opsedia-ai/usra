import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Profiles, MedicalEvents, OutboxEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  static const _uuid = Uuid();

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(profiles, profiles.bloodType);
        await m.addColumn(profiles, profiles.allergies);
        await m.addColumn(profiles, profiles.conditions);
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

  /// Marks a profile and all its records deleted (kept for sync) instead of
  /// erasing them.
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
    });
  }

  Stream<List<MedicalEvent>> watchTimeline(String profileId) {
    final query = select(medicalEvents)
      ..where((e) => e.profileId.equals(profileId) & e.deletedAt.isNull())
      ..orderBy([(e) => OrderingTerm.desc(e.occurredAt)]);
    return query.watch();
  }

  Future<String> addEvent({
    required String profileId,
    required String type,
    required DateTime occurredAt,
    String dataJson = '{}',
    int? costMinor,
    String? currency,
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
