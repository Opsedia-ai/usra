import 'package:drift/drift.dart';

// Every synced table has a UUID id, `updatedAt` and a soft-delete
// `deletedAt`, so end-to-end-encrypted sync can be added later without
// changing what the data means.

/// A person in the family (no login needed).
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  DateTimeColumn get birthDate => dateTime().nullable()();
  TextColumn get sex => text().nullable()();
  BoolColumn get simpleMode => boolean().withDefault(const Constant(false))();

  /// One of A+, A-, B+, B-, AB+, AB-, O+, O- (schema v2).
  TextColumn get bloodType => text().nullable()();

  /// Free text, shown on the emergency card (schema v2).
  TextColumn get allergies => text().nullable()();
  TextColumn get conditions => text().nullable()();

  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One generic record for visits, scans, labs, vaccines, surgeries...
/// Type-specific fields live in [dataJson], described by the record type.
class MedicalEvents extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get type => text()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get doctorId => text().nullable()();
  IntColumn get costMinor => integer().nullable()();
  TextColumn get currency => text().nullable()();
  TextColumn get dataJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local changes waiting to be synced (used once sync is switched on).
class OutboxEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  DateTimeColumn get createdAt => dateTime()();
}
