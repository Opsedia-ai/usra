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

/// A doctor the family sees, shared by every person (schema v3).
class Doctors extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get specialty => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get clinic => text().nullable()();
  TextColumn get address => text().nullable()();

  /// Usual visit fee in the smallest currency unit (piasters for EGP).
  IntColumn get feeMinor => integer().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A health insurance card; one person can have several (schema v4).
class InsuranceCards extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();

  /// The name the family gives the card, e.g. "نقابة" or "شغل 1".
  TextColumn get label => text()();
  TextColumn get insurer => text().nullable()();
  TextColumn get memberNumber => text().nullable()();

  /// The last day the card is valid (a date, stored as UTC midnight).
  DateTimeColumn get expiresOn => dateTime().nullable()();
  TextColumn get notes => text().nullable()();

  /// Photos of the card, relative to the app's private photo folder.
  TextColumn get frontPhoto => text().nullable()();
  TextColumn get backPhoto => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A file attached to a record, e.g. a photo of a prescription or a lab
/// report (schema v5).
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get eventId => text().references(MedicalEvents, #id)();

  /// The file, relative to the app's private folder (see `PhotoStore`).
  TextColumn get path => text()();

  /// `photo` for now; `pdf` later.
  TextColumn get kind => text().withDefault(const Constant('photo'))();
  TextColumn get caption => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
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
