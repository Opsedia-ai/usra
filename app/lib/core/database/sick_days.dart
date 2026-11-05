part of 'app_database.dart';

/// Where a temperature was taken.
abstract final class TemperatureSite {
  static const armpit = 'armpit';
  static const ear = 'ear';
  static const forehead = 'forehead';
  static const mouth = 'mouth';
  static const rectal = 'rectal';
  static const all = [armpit, ear, forehead, mouth, rectal];
}

/// The unit a temperature was read in.
abstract final class TemperatureUnit {
  static const celsius = 'c';
  static const fahrenheit = 'f';
  static const all = {celsius, fahrenheit};
}

/// A medicine given with a reminder on, and what the reminder needs: the
/// saved medicine (for its instructions), who took it and the sick day.
class NextDoseSource {
  const NextDoseSource({
    required this.given,
    required this.medicine,
    required this.person,
    required this.episode,
  });

  final GivenMedicine given;
  final Medicine medicine;
  final Profile person;
  final SickEpisode episode;
}

/// Sick days (C8): episodes, temperature readings and medicines given.
/// Everything is kept as the family entered it.
extension SickDayDatabase on AppDatabase {
  /// A person's sick days, the latest first.
  Stream<List<SickEpisode>> watchEpisodes(String profileId) {
    final query = select(sickEpisodes)
      ..where((e) => e.profileId.equals(profileId) & e.deletedAt.isNull())
      ..orderBy([(e) => OrderingTerm.desc(e.startedAt)]);
    return query.watch();
  }

  Stream<SickEpisode?> watchEpisode(String id) {
    final query = select(sickEpisodes)
      ..where((e) => e.id.equals(id) & e.deletedAt.isNull());
    return query.watchSingleOrNull();
  }

  /// Adds a sick day, or updates [id]. Returns its id.
  Future<String> saveEpisode({
    String? id,
    required String profileId,
    required DateTime startedAt,
    DateTime? endedAt,
    List<String> symptoms = const [],
    String? notes,
  }) async {
    if (endedAt != null && endedAt.isBefore(startedAt)) {
      throw ArgumentError.value(endedAt, 'endedAt', 'before the start');
    }
    final now = DateTime.now().toUtc();
    final key = id ?? AppDatabase._uuid.v4();
    final row = SickEpisodesCompanion(
      id: Value(key),
      profileId: Value(profileId),
      startedAt: Value(startedAt.toUtc()),
      endedAt: Value(endedAt?.toUtc()),
      symptomsJson: Value(jsonEncode(symptoms.toSet().toList())),
      notes: Value(_blankToNull(notes)),
      updatedAt: Value(now),
    );
    await transaction(() async {
      if (id == null) {
        await into(sickEpisodes).insert(row);
      } else {
        final n = await (update(
          sickEpisodes,
        )..where((e) => e.id.equals(id) & e.deletedAt.isNull())).write(row);
        if (n == 0) throw StateError('No sick day $id');
      }
      await _queue('sick_episode', key, id == null ? 'insert' : 'update');
    });
    return key;
  }

  /// Ticks or unticks the symptoms of sick day [id].
  Future<void> setEpisodeSymptoms(String id, List<String> symptoms) async {
    final now = DateTime.now().toUtc();
    await transaction(() async {
      await (update(sickEpisodes)..where((e) => e.id.equals(id))).write(
        SickEpisodesCompanion(
          symptomsJson: Value(jsonEncode(symptoms.toSet().toList())),
          updatedAt: Value(now),
        ),
      );
      await _queue('sick_episode', id, 'update');
    });
  }

  /// Marks sick day [id] over at [endedAt], or ongoing again with null.
  Future<void> setEpisodeEnded(String id, DateTime? endedAt) async {
    final now = DateTime.now().toUtc();
    await transaction(() async {
      await (update(sickEpisodes)..where((e) => e.id.equals(id))).write(
        SickEpisodesCompanion(
          endedAt: Value(endedAt?.toUtc()),
          updatedAt: Value(now),
        ),
      );
      await _queue('sick_episode', id, 'update');
    });
  }

  /// Deletes sick day [id] with its readings and medicines given.
  Future<void> softDeleteEpisode(String id) async {
    final now = DateTime.now().toUtc();
    await transaction(() => _softDeleteEpisode(id, now));
  }

  Future<void> _softDeleteEpisode(String id, DateTime now) async {
    await (update(sickEpisodes)..where((e) => e.id.equals(id))).write(
      SickEpisodesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    await _queue('sick_episode', id, 'delete');
    final liveReadings =
        temperatureReadings.episodeId.equals(id) &
        temperatureReadings.deletedAt.isNull();
    final readingIds =
        await (selectOnly(temperatureReadings)
              ..addColumns([temperatureReadings.id])
              ..where(liveReadings))
            .map((row) => row.read(temperatureReadings.id)!)
            .get();
    await (update(temperatureReadings)..where((_) => liveReadings)).write(
      TemperatureReadingsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    for (final r in readingIds) {
      await _queue('temperature_reading', r, 'delete');
    }
    final liveGiven =
        givenMedicines.episodeId.equals(id) & givenMedicines.deletedAt.isNull();
    final givenIds =
        await (selectOnly(givenMedicines)
              ..addColumns([givenMedicines.id])
              ..where(liveGiven))
            .map((row) => row.read(givenMedicines.id)!)
            .get();
    await (update(givenMedicines)..where((_) => liveGiven)).write(
      GivenMedicinesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    for (final g in givenIds) {
      await _queue('given_medicine', g, 'delete');
    }
  }

  /// Every live sick day of [profileId], deleted with the person.
  Future<void> _softDeleteEpisodesOf(String profileId, DateTime now) async {
    final ids =
        await (selectOnly(sickEpisodes)
              ..addColumns([sickEpisodes.id])
              ..where(
                sickEpisodes.profileId.equals(profileId) &
                    sickEpisodes.deletedAt.isNull(),
              ))
            .map((row) => row.read(sickEpisodes.id)!)
            .get();
    for (final id in ids) {
      await _softDeleteEpisode(id, now);
    }
  }

  /// A sick day's readings, oldest first.
  Stream<List<TemperatureReading>> watchReadings(String episodeId) {
    final query = select(temperatureReadings)
      ..where((r) => r.episodeId.equals(episodeId) & r.deletedAt.isNull())
      ..orderBy([(r) => OrderingTerm.asc(r.takenAt)]);
    return query.watch();
  }

  /// Every live reading of [profileId]'s sick days, oldest first.
  Stream<List<TemperatureReading>> watchProfileReadings(String profileId) {
    final query =
        select(temperatureReadings).join([
            innerJoin(
              sickEpisodes,
              sickEpisodes.id.equalsExp(temperatureReadings.episodeId),
            ),
          ])
          ..where(
            sickEpisodes.profileId.equals(profileId) &
                sickEpisodes.deletedAt.isNull() &
                temperatureReadings.deletedAt.isNull(),
          )
          ..orderBy([OrderingTerm.asc(temperatureReadings.takenAt)]);
    return query.watch().map(
      (rows) => [for (final r in rows) r.readTable(temperatureReadings)],
    );
  }

  /// Adds a reading, or updates [id]. Returns its id.
  Future<String> saveReading({
    String? id,
    required String episodeId,
    required DateTime takenAt,
    required double value,
    required String unit,
    String? site,
  }) async {
    if (!TemperatureUnit.all.contains(unit)) {
      throw ArgumentError.value(unit, 'unit');
    }
    if (site != null && !TemperatureSite.all.contains(site)) {
      throw ArgumentError.value(site, 'site');
    }
    if (!value.isFinite) throw ArgumentError.value(value, 'value');
    final now = DateTime.now().toUtc();
    final key = id ?? AppDatabase._uuid.v4();
    final row = TemperatureReadingsCompanion(
      id: Value(key),
      episodeId: Value(episodeId),
      takenAt: Value(takenAt.toUtc()),
      value: Value(value),
      unit: Value(unit),
      site: Value(site),
      updatedAt: Value(now),
    );
    await transaction(() async {
      if (id == null) {
        await into(temperatureReadings).insert(row);
      } else {
        await (update(
          temperatureReadings,
        )..where((r) => r.id.equals(id))).write(row);
      }
      await _queue(
        'temperature_reading',
        key,
        id == null ? 'insert' : 'update',
      );
    });
    return key;
  }

  Future<void> softDeleteReading(String id) async {
    final now = DateTime.now().toUtc();
    await transaction(() async {
      await (update(temperatureReadings)..where((r) => r.id.equals(id))).write(
        TemperatureReadingsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _queue('temperature_reading', id, 'delete');
    });
  }

  /// Medicines given in a sick day, the latest first.
  Stream<List<GivenMedicine>> watchGivenMedicines(String episodeId) {
    final query = select(givenMedicines)
      ..where((g) => g.episodeId.equals(episodeId) & g.deletedAt.isNull())
      ..orderBy([(g) => OrderingTerm.desc(g.givenAt)]);
    return query.watch();
  }

  /// Records a medicine given, or updates [id]. [amount] is saved word for
  /// word. Returns its id.
  Future<String> saveGivenMedicine({
    String? id,
    required String episodeId,
    String? medicineId,
    String? prescriptionId,
    required String name,
    String? amount,
    required DateTime givenAt,
    bool remindNext = false,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError.value(name, 'name');
    // Only a saved medicine has instructions a reminder can come from.
    if (remindNext && medicineId == null) {
      throw ArgumentError.value(remindNext, 'remindNext', 'needs a medicine');
    }
    final now = DateTime.now().toUtc();
    final key = id ?? AppDatabase._uuid.v4();
    final row = GivenMedicinesCompanion(
      id: Value(key),
      episodeId: Value(episodeId),
      medicineId: Value(medicineId),
      prescriptionId: Value(prescriptionId),
      name: Value(name.trim()),
      amount: Value(_blankToNull(amount)),
      givenAt: Value(givenAt.toUtc()),
      remindNext: Value(remindNext),
      updatedAt: Value(now),
    );
    await transaction(() async {
      if (id == null) {
        await into(givenMedicines).insert(row);
      } else {
        await (update(
          givenMedicines,
        )..where((g) => g.id.equals(id))).write(row);
      }
      await _queue('given_medicine', key, id == null ? 'insert' : 'update');
    });
    return key;
  }

  Future<void> softDeleteGivenMedicine(String id) async {
    final now = DateTime.now().toUtc();
    await transaction(() async {
      await (update(givenMedicines)..where((g) => g.id.equals(id))).write(
        GivenMedicinesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await _queue('given_medicine', id, 'delete');
    });
  }

  /// Medicines given with "remind me" on, in sick days still going on, for
  /// people and medicines not deleted: what next-dose reminders come from.
  Stream<List<NextDoseSource>> watchNextDoseSources() {
    final query =
        select(givenMedicines).join([
          innerJoin(
            sickEpisodes,
            sickEpisodes.id.equalsExp(givenMedicines.episodeId),
          ),
          innerJoin(
            medicines,
            medicines.id.equalsExp(givenMedicines.medicineId),
          ),
          innerJoin(profiles, profiles.id.equalsExp(sickEpisodes.profileId)),
        ])..where(
          givenMedicines.deletedAt.isNull() &
              givenMedicines.remindNext.equals(true) &
              sickEpisodes.deletedAt.isNull() &
              sickEpisodes.endedAt.isNull() &
              medicines.deletedAt.isNull() &
              profiles.deletedAt.isNull(),
        );
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          NextDoseSource(
            given: r.readTable(givenMedicines),
            medicine: r.readTable(medicines),
            person: r.readTable(profiles),
            episode: r.readTable(sickEpisodes),
          ),
      ],
    );
  }
}

String? _blankToNull(String? s) {
  final t = s?.trim();
  return t == null || t.isEmpty ? null : t;
}

/// The symptom keys saved in `SickEpisodes.symptomsJson`.
List<String> decodeSymptoms(String json) {
  try {
    final value = jsonDecode(json);
    return value is List
        ? [
            for (final s in value)
              if (s is String) s,
          ]
        : [];
  } on FormatException {
    return [];
  }
}
