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

/// A medicine a person takes, written as the doctor prescribed it
/// (schema v6). The app records the prescription; it never suggests doses.
class Medicines extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get name => text()();

  /// As printed on the box, e.g. "500 مجم".
  TextColumn get strength => text().nullable()();

  /// tablet, capsule, syrup, drops, injection, cream, inhaler or other.
  TextColumn get form => text().nullable()();

  /// What the doctor wrote, word for word.
  TextColumn get instructions => text().nullable()();

  /// The shortest time between doses, in hours, as the family typed it
  /// from the label or the doctor (schema v8). Never filled in by the app;
  /// sick days show "N hours after this dose" only when it's set.
  RealColumn get minHoursBetweenDoses => real().nullable()();
  TextColumn get doctorId => text().nullable()();

  /// The prescription it was written on, if any (schema v7).
  TextColumn get prescriptionId =>
      text().nullable().references(Prescriptions, #id)();

  /// Its place on the prescription, as entered (schema v7).
  IntColumn get position => integer().nullable()();

  /// Stopped by stopping the whole prescription, not on its own (schema
  /// v7); resuming the prescription restarts only these.
  BoolColumn get stoppedWithPrescription =>
      boolean().withDefault(const Constant(false))();

  /// First and last day (inclusive), stored as UTC midnight.
  DateTimeColumn get startOn => dateTime()();
  DateTimeColumn get endOn => dateTime().nullable()();

  /// Photos of the box or prescription: a JSON list of paths relative to
  /// the app's private folder (see `PhotoStore`).
  TextColumn get photosJson => text().withDefault(const Constant('[]'))();

  /// False once the person stops taking it; kept for history.
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One prescription from a doctor: the date, who wrote it, why, and a photo
/// of the paper (schema v7). Its medicines point back to it with
/// `Medicines.prescriptionId`. The app records what the doctor wrote; it
/// never suggests or computes a dose.
class Prescriptions extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get doctorId => text().nullable()();

  /// The day it was written, stored as UTC midnight.
  DateTimeColumn get prescribedOn => dateTime()();

  /// The diagnosis or reason, as the family writes it.
  TextColumn get diagnosis => text().nullable()();
  TextColumn get notes => text().nullable()();

  /// Photos of the prescription: a JSON list of paths relative to the app's
  /// private folder, in the medicines photo store (see `PhotoStore`).
  TextColumn get photosJson => text().withDefault(const Constant('[]'))();

  /// False when none of its medicines is taken any more (kept in step with
  /// them by the database).
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// When a medicine is taken (schema v6).
class DoseSchedules extends Table {
  TextColumn get id => text()();
  TextColumn get medicineId => text().references(Medicines, #id)();

  /// Local times of day, "HH:mm" separated by commas, e.g. "08:00,20:00".
  TextColumn get times => text()();

  /// Days of the week as a bit mask (bit 0 = Monday ... bit 6 = Sunday);
  /// null means every day.
  IntColumn get weekdays => integer().nullable()();

  /// Every N days counted from the medicine's first day; null means daily.
  IntColumn get everyNDays => integer().nullable()();

  /// How much, as the doctor wrote it, e.g. "قرص واحد" or "5 مل".
  TextColumn get amount => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// What happened to one scheduled dose (schema v6). One row per dose:
/// marking it again updates the row.
@TableIndex(
  name: 'dose_logs_dose',
  columns: {#medicineId, #scheduledAt},
  unique: true,
)
class DoseLogs extends Table {
  TextColumn get id => text()();
  TextColumn get medicineId => text().references(Medicines, #id)();

  /// The dose's planned time (the local time of day, as an instant).
  DateTimeColumn get scheduledAt => dateTime()();

  /// taken, skipped or snoozed.
  TextColumn get status => text()();

  /// When it was marked.
  DateTimeColumn get at => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A sick day (or several) for one person: when it started and ended, the
/// symptoms ticked and the family's notes (schema v8).
class SickEpisodes extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  DateTimeColumn get startedAt => dateTime()();

  /// Null while the person is still ill.
  DateTimeColumn get endedAt => dateTime().nullable()();

  /// The symptoms ticked, a JSON list of keys (see `sick_days/fever.dart`).
  TextColumn get symptomsJson => text().withDefault(const Constant('[]'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One temperature reading in a sick day, as read off the thermometer
/// (schema v8).
class TemperatureReadings extends Table {
  TextColumn get id => text()();
  TextColumn get episodeId => text().references(SickEpisodes, #id)();
  DateTimeColumn get takenAt => dateTime()();

  /// As read, in [unit].
  RealColumn get value => real()();

  /// `c` or `f`.
  TextColumn get unit => text()();

  /// armpit, ear, forehead, mouth or rectal; null if not said.
  TextColumn get site => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A medicine given during a sick day, as the family wrote it (schema v8).
/// The app records what was given; it never suggests an amount or a time.
class GivenMedicines extends Table {
  TextColumn get id => text()();
  TextColumn get episodeId => text().references(SickEpisodes, #id)();

  /// The saved medicine, if one was picked.
  TextColumn get medicineId => text().nullable().references(Medicines, #id)();

  /// The prescription it came from, if one was picked.
  TextColumn get prescriptionId =>
      text().nullable().references(Prescriptions, #id)();

  /// The medicine's name: copied from the saved medicine, or typed.
  TextColumn get name => text()();

  /// How much, word for word as the family wrote it.
  TextColumn get amount => text().nullable()();
  DateTimeColumn get givenAt => dateTime()();

  /// Remind when the medicine's own saved instructions allow the next
  /// dose (only offered when they state a minimum interval).
  BoolColumn get remindNext => boolean().withDefault(const Constant(false))();

  /// The medicine's minimum hours between doses when this was saved, so
  /// editing the medicine later doesn't move the time for this dose.
  RealColumn get intervalHours => real().nullable()();
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
