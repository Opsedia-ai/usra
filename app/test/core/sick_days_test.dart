import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/features/medicines/reminder_sync.dart';
import 'package:usra/features/medicines/min_hours.dart';
import 'package:usra/features/medicines/reminders.dart';
import 'package:usra/features/sick_days/fever.dart';
import 'package:usra/features/sick_days/next_dose.dart';
import 'package:usra/l10n/app_localizations.dart';

import '../generated_migrations/schema.dart';
import '../support/fake_reminder_scheduler.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ar = lookupAppLocalizations(const Locale('ar'));
  late AppDatabase db;
  late String sara;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    sara = await db.addProfile('Sara', birthDate: DateTime(2025, 1, 1));
  });
  tearDown(() => db.close());

  Future<String> paracetamol(String? instructions, {double? hours}) =>
      db.saveMedicine(
        profileId: sara,
        name: 'Paracetamol syrup',
        instructions: instructions,
        startOn: DateTime(2026, 11, 1),
        minHoursBetweenDoses: Value(hours),
      );

  group('database', () {
    test(
      'a sick day keeps readings, symptoms and medicines as entered',
      () async {
        final e = await db.saveEpisode(
          profileId: sara,
          startedAt: DateTime(2026, 11, 4, 8),
          symptoms: const [Symptom.cough, Symptom.cough, Symptom.rash],
        );
        await db.saveReading(
          episodeId: e,
          takenAt: DateTime(2026, 11, 4, 9),
          value: 101.3,
          unit: TemperatureUnit.fahrenheit,
          site: TemperatureSite.ear,
        );
        final m = await paracetamol('5 ml every 6 hours', hours: 6);
        await db.saveGivenMedicine(
          episodeId: e,
          medicineId: m,
          name: 'Paracetamol syrup',
          amount: '  5 مل  ',
          givenAt: DateTime(2026, 11, 4, 9, 5),
          remindNext: true,
        );
        final episode = (await db.watchEpisodes(sara).first).single;
        expect(decodeSymptoms(episode.symptomsJson), [
          Symptom.cough,
          Symptom.rash,
        ]);
        final r = (await db.watchReadings(e).first).single;
        expect((r.value, r.unit, r.site), (101.3, 'f', 'ear'));
        expect(readingC(r), closeTo(38.5, 0.01));
        final g = (await db.watchGivenMedicines(e).first).single;
        expect(g.amount, '5 مل');
        expect(g.remindNext, isTrue);
        expect((await db.watchNextDoseSources().first).single.given.id, g.id);
      },
    );

    test('bad input is refused', () async {
      final e = await db.saveEpisode(
        profileId: sara,
        startedAt: DateTime(2026, 11, 4),
      );
      expect(
        () => db.saveReading(
          episodeId: e,
          takenAt: DateTime(2026, 11, 4),
          value: 38,
          unit: 'k',
        ),
        throwsArgumentError,
      );
      expect(
        () => db.saveReading(
          episodeId: e,
          takenAt: DateTime(2026, 11, 4),
          value: 38,
          unit: 'c',
          site: 'toe',
        ),
        throwsArgumentError,
      );
      // A reminder only ever comes from a saved medicine's instructions.
      expect(
        () => db.saveGivenMedicine(
          episodeId: e,
          name: 'Something',
          givenAt: DateTime(2026, 11, 4),
          remindNext: true,
        ),
        throwsArgumentError,
      );
      expect(
        () => db.saveEpisode(
          profileId: sara,
          startedAt: DateTime(2026, 11, 4),
          endedAt: DateTime(2026, 11, 3),
        ),
        throwsArgumentError,
      );
    });

    test('reminder sources stop with the sick day, the medicine or the '
        'person', () async {
      final e = await db.saveEpisode(
        profileId: sara,
        startedAt: DateTime(2026, 11, 4),
      );
      final m = await paracetamol('every 6 hours', hours: 6);
      await db.saveGivenMedicine(
        episodeId: e,
        medicineId: m,
        name: 'Paracetamol syrup',
        givenAt: DateTime(2026, 11, 4, 9),
        remindNext: true,
      );
      await db.saveGivenMedicine(
        episodeId: e,
        medicineId: m,
        name: 'Paracetamol syrup',
        givenAt: DateTime(2026, 11, 4, 9),
      );
      // Both doses: the latest decides whether a reminder rings.
      expect(await db.watchNextDoseSources().first, hasLength(2));
      await db.setEpisodeEnded(e, DateTime(2026, 11, 5));
      expect(await db.watchNextDoseSources().first, isEmpty);
      await db.setEpisodeEnded(e, null);
      expect(await db.watchNextDoseSources().first, hasLength(2));
      await db.softDeleteMedicine(m);
      expect(await db.watchNextDoseSources().first, isEmpty);
    });

    test(
      'deleting a sick day or the person deletes everything in it',
      () async {
        final e = await db.saveEpisode(
          profileId: sara,
          startedAt: DateTime(2026, 11, 4),
        );
        await db.saveReading(
          episodeId: e,
          takenAt: DateTime(2026, 11, 4),
          value: 38,
          unit: 'c',
        );
        await db.saveGivenMedicine(
          episodeId: e,
          name: 'x',
          givenAt: DateTime(2026, 11, 4),
        );
        final other = await db.saveEpisode(
          profileId: sara,
          startedAt: DateTime(2026, 10, 1),
        );
        await db.softDeleteEpisode(e);
        expect(await db.watchReadings(e).first, isEmpty);
        expect(await db.watchGivenMedicines(e).first, isEmpty);
        expect((await db.watchEpisodes(sara).first).single.id, other);
        await db.softDeleteProfile(sara);
        expect(await db.watchEpisodes(sara).first, isEmpty);
        // Kept as deleted rows for sync, never erased.
        expect(await db.select(db.sickEpisodes).get(), hasLength(2));
        expect(
          (await db.select(db.outboxEntries).get())
              .where(
                (o) => o.entity == 'sick_episode' && o.operation == 'delete',
              )
              .length,
          2,
        );
      },
    );
  });

  group('fever', () {
    test('converts units and tells fevers apart', () {
      expect(toCelsius(100.4, 'f'), closeTo(38, 1e-9));
      expect(fromCelsius(38, 'f'), closeTo(100.4, 1e-9));
      expect(isPlausible(38.2, 'c'), isTrue);
      expect(isPlausible(382, 'c'), isFalse);
      expect(isPlausible(38.2, 'f'), isFalse);
      expect(isPlausible(101, 'f'), isTrue);
      expect(isPlausible(43, 'c'), isTrue);
      expect(isPlausible(43.1, 'c'), isFalse);
      expect(isPlausible(45, 'c'), isFalse);
      expect(needsConfirm(42, 'c'), isFalse);
      expect(needsConfirm(42.3, 'c'), isTrue);
      expect(needsConfirm(33.5, 'c'), isTrue);
      expect(needsConfirm(100.4, 'f'), isFalse);
      // Saved as a thermometer shows it: the label matches the screen.
      expect(roundReading(37.96), 38.0);
      expect(roundReading(100.35), 100.4);
    });

    test('age groups', () {
      final b = DateTime(2026, 1, 15);
      expect(ageGroupOf(b, DateTime(2026, 4, 14)), AgeGroup.under3Months);
      expect(ageGroupOf(b, DateTime(2026, 4, 15)), AgeGroup.months3to6);
      expect(ageGroupOf(b, DateTime(2026, 7, 15)), AgeGroup.under2);
      expect(ageGroupOf(b, DateTime(2028, 1, 15)), AgeGroup.child);
      expect(ageGroupOf(b, DateTime(2044, 1, 15)), AgeGroup.adult);
      expect(ageGroupOf(null, DateTime(2026)), AgeGroup.unknown);
      // Born on the 30th: 3 months later is the last day of February.
      final late = DateTime(2025, 11, 30);
      expect(ageGroupOf(late, DateTime(2026, 2, 27)), AgeGroup.under3Months);
      expect(ageGroupOf(late, DateTime(2026, 2, 28)), AgeGroup.months3to6);
    });

    SickEpisode episode({List<String> symptoms = const [], DateTime? ended}) =>
        SickEpisode(
          id: 'e',
          profileId: 'p',
          startedAt: DateTime(2026, 11, 1),
          endedAt: ended,
          symptomsJson: jsonEncode(symptoms),
          updatedAt: DateTime(2026),
        );
    TemperatureReading reading(DateTime at, double c, {String unit = 'c'}) =>
        TemperatureReading(
          id: '$at',
          episodeId: 'e',
          takenAt: at,
          value: fromCelsius(c, unit),
          unit: unit,
          updatedAt: DateTime(2026),
        );

    test('any fever under 3 months is a warning sign; 38 is not under 6', () {
      final now = DateTime(2026, 11, 2);
      expect(
        matchedWarnings(
          episode: episode(),
          readings: [reading(DateTime(2026, 11, 1, 9), 38.0, unit: 'f')],
          birthDate: DateTime(2026, 9, 1),
          now: now,
        ),
        {'under3Months'},
      );
      expect(
        matchedWarnings(
          episode: episode(),
          readings: [reading(DateTime(2026, 11, 1, 9), 38.5)],
          birthDate: DateTime(2026, 6, 1),
          now: now,
        ),
        isEmpty,
      );
      expect(
        matchedWarnings(
          episode: episode(),
          readings: [reading(DateTime(2026, 11, 1, 9), 39.1)],
          birthDate: DateTime(2026, 6, 1),
          now: now,
        ),
        {'months3to6'},
      );
    });

    test('how long a fever lasted, by age', () {
      final readings = [
        reading(DateTime(2026, 11, 1, 8), 38.6),
        reading(DateTime(2026, 11, 2, 9), 38.2),
      ];
      // Under 2: more than 24 hours.
      expect(
        matchedWarnings(
          episode: episode(ended: DateTime(2026, 11, 3)),
          readings: readings,
          birthDate: DateTime(2025, 6, 1),
          now: DateTime(2026, 11, 3),
        ),
        {'longUnder2'},
      );
      // 2 or older: more than 3 days; ongoing counts up to now.
      expect(
        matchedWarnings(
          episode: episode(),
          readings: readings,
          birthDate: DateTime(2020, 1, 1),
          now: DateTime(2026, 11, 4, 9),
        ),
        {'longChild'},
      );
      expect(
        matchedWarnings(
          episode: episode(),
          readings: readings,
          birthDate: DateTime(2020, 1, 1),
          now: DateTime(2026, 11, 6, 9),
        ),
        {'longChild', 'fiveDays'},
      );
      // The fever went: it lasted to the last fever reading only.
      expect(
        matchedWarnings(
          episode: episode(),
          readings: [...readings, reading(DateTime(2026, 11, 2, 20), 37)],
          birthDate: DateTime(2020, 1, 1),
          now: DateTime(2026, 11, 6, 9),
        ),
        isEmpty,
      );
    });

    test('100.4 °F and 102.2 °F count exactly at the thresholds', () {
      TemperatureReading f(double v) => TemperatureReading(
        id: '$v',
        episodeId: 'e',
        takenAt: DateTime(2026, 11, 1, 9),
        value: v,
        unit: 'f',
        updatedAt: DateTime(2026),
      );
      expect(isFever(f(100.4)), isTrue);
      expect(isFever(f(100.3)), isFalse);
      Set<String> at(double v, DateTime birth) => matchedWarnings(
        episode: episode(),
        readings: [f(v)],
        birthDate: birth,
        now: DateTime(2026, 11, 1, 10),
      );
      expect(at(100.4, DateTime(2026, 9, 1)), {'under3Months'});
      expect(at(102.2, DateTime(2026, 6, 1)), {'months3to6'});
      expect(at(102.1, DateTime(2026, 6, 1)), isEmpty);
    });

    test(
      'babies under 3 months: armpit from 37.5 °C, and low temperatures',
      () {
        TemperatureReading armpit(double c, {String? site = 'armpit'}) =>
            TemperatureReading(
              id: '$c$site',
              episodeId: 'e',
              takenAt: DateTime(2026, 11, 1, 9),
              value: c,
              unit: 'c',
              site: site,
              updatedAt: DateTime(2026),
            );
        Set<String> m(TemperatureReading r, DateTime birth) => matchedWarnings(
          episode: episode(),
          readings: [r],
          birthDate: birth,
          now: DateTime(2026, 11, 1, 10),
        );
        final baby = DateTime(2026, 9, 20);
        expect(m(armpit(37.6), baby), {'armpitUnder3Months'});
        expect(m(armpit(37.6, site: 'ear'), baby), isEmpty);
        expect(m(armpit(37.4), baby), isEmpty);
        expect(m(armpit(35.8, site: null), baby), {'lowUnder3Months'});
        // Older: neither applies.
        expect(m(armpit(37.6), DateTime(2025, 1, 1)), isEmpty);
        expect(m(armpit(35.8), DateTime(2025, 1, 1)), isEmpty);
      },
    );

    test('without a date of birth, every age\'s signs are shown', () {
      final keys = warningSignsFor(AgeGroup.unknown).map((s) => s.key).toSet();
      for (final age in AgeGroup.values) {
        expect(
          keys,
          containsAll(warningSignsFor(age).map((s) => s.key)),
          reason: '$age',
        );
      }
    });

    test('not drinking and vomiting everything are emergency signs', () {
      final levels = {
        for (final s in warningSignsFor(AgeGroup.child)) s.key: s.level,
      };
      expect(levels['notDrinking'], WarningLevel.emergency);
      expect(levels['vomitsEverything'], WarningLevel.emergency);
      expect(levels['dehydration'], WarningLevel.doctorNow);
    });

    test('ticked danger symptoms are warning signs at any age', () {
      expect(
        matchedWarnings(
          episode: episode(
            symptoms: [Symptom.cough, Symptom.breathing, Symptom.rashNotFading],
          ),
          readings: const [],
          birthDate: DateTime(1960, 1, 1),
          now: DateTime(2026, 11, 2),
        ),
        {'breathing', 'rashGlass'},
      );
    });

    test('every sign has a source, a text in both languages, and the right '
        'signs for the age', () {
      for (final age in AgeGroup.values) {
        for (final s in warningSignsFor(age)) {
          expect(s.sources, isNotEmpty, reason: s.key);
          for (final sex in ['female', 'male', 'other']) {
            expect(en.warnSign(sex, s.key), isNotEmpty, reason: s.key);
            expect(ar.warnSign(sex, s.key), isNotEmpty, reason: s.key);
          }
        }
      }
      for (final url in warningSourceUrls.values) {
        expect(url, startsWith('https://'));
      }
      for (final s in Symptom.all) {
        for (final sex in ['female', 'male', 'other']) {
          expect(en.symptomName(sex, s), isNot('Other'));
          expect(ar.symptomName(sex, s), isNot('تاني'));
        }
      }
      final adult = warningSignsFor(AgeGroup.adult).map((s) => s.key);
      expect(adult, isNot(contains('under3Months')));
      expect(adult, contains('notImproving'));
      expect(
        warningSignsFor(AgeGroup.under3Months).map((s) => s.key),
        containsAll(['under3Months', 'longUnder2', 'breathing', 'seizure']),
      );
      // Emergency wording says to call the ambulance; the others a doctor.
      expect(en.warnEmergency, contains('123'));
      expect(ar.warnEmergency, contains('١٢٣'));
      expect(en.warnDoctorNow, contains('doctor now'));
    });
  });

  group('minimum hours between doses: typed, never guessed', () {
    test('typed hours: any digits, a comma or a point', () {
      expect(parseMinHours('6'), 6);
      expect(parseMinHours('٦'), 6);
      expect(parseMinHours('6.5'), 6.5);
      expect(parseMinHours('6,5'), 6.5);
      expect(parseMinHours('٦٫٥'), 6.5);
      expect(parseMinHours('٦،٥'), 6.5);
      for (final bad in ['', ' ', '0', '0.2', '73', 'six', '-4']) {
        expect(parseMinHours(bad), isNull, reason: bad);
      }
    });

    test('a suggestion only from one unambiguous figure', () {
      for (final (text, hours, phrase) in [
        ('5 ml every 6 hours', 6.0, 'every 6 hours'),
        ('Every 8 hrs after food', 8.0, 'Every 8 hrs'),
        ('1-2 tablets every 6h if needed', 6.0, 'every 6h'),
        ('q4h', 4.0, 'q4h'),
        ('at least 6 hours apart', 6.0, '6 hours apart'),
        ('6.5 hours apart', 6.5, '6.5 hours apart'),
        ('10.5 hours apart', 10.5, '10.5 hours apart'),
        ('every 6,5 hours', 6.5, 'every 6,5 hours'),
        ('every six hours', 6.0, 'every six hours'),
        ('٥ مل كل ٦ ساعات', 6.0, 'كل ٦ ساعات'),
        ('كل ٦٫٥ ساعة', 6.5, 'كل ٦٫٥ ساعة'),
        ('كل 8 ساعة بعد الأكل', 8.0, 'كل 8 ساعة'),
        ('كل ساعتين', 2.0, 'كل ساعتين'),
        ('كل ست ساعات عند اللزوم', 6.0, 'كل ست ساعات'),
        ('كل ١٢ س', 12.0, 'كل ١٢ س'),
      ]) {
        expect(
          suggestMinHours(text),
          MinHoursSuggestion(hours, phrase),
          reason: text,
        );
      }
    });

    test('no suggestion for ranges, alternatives, limits or no figure', () {
      for (final text in [
        null,
        '',
        '5 مل بعد الأكل',
        'twice a day',
        'مرتين في اليوم',
        '3 times a day',
        'every day',
        'كل يوم',
        'every few hours',
        'كل ساعة',
        'every 4-6 hours',
        'every 4 to 6 hours',
        'every 4 hrs to 6 hrs',
        'every 4 hours (or 6 hours if needed)',
        'q4h-6h',
        'q4/6h',
        'كل ٤-٦ ساعات',
        'كل ٤ إلى ٦ ساعات',
        'كل 4 ساعات إلى 6 ساعات',
        'كل ٦ ساعات أو ٨ ساعات',
        'every 6 hours or 8 hours',
        'every 6 hours, or every 8 hours at night',
        'up to 3 times every 24 hours',
        'every 6 hours, max 4 doses in 24 hours',
        'max every 4 hours',
        'كل ٦ ساعات بحد أقصى ٤ مرات',
        'every 100 hours',
        'وجع في الرأس كل يوم',
      ]) {
        expect(suggestMinHours(text), isNull, reason: text);
      }
    });

    test(
      'an entry keeps the hours it was saved with; none means no time',
      () async {
        final e = await db.saveEpisode(
          profileId: sara,
          startedAt: DateTime(2026, 11, 4),
        );
        // Instructions alone never give a time.
        final m = await paracetamol('5 مل كل ٦ ساعات');
        final noHours = await db.saveGivenMedicine(
          episodeId: e,
          medicineId: m,
          name: 'Paracetamol syrup',
          givenAt: DateTime(2026, 11, 4, 8),
        );
        expect(
          hoursAfter((await db.watchGivenMedicines(e).first).single),
          isNull,
        );
        await expectLater(
          db.saveGivenMedicine(
            episodeId: e,
            medicineId: m,
            name: 'Paracetamol syrup',
            givenAt: DateTime(2026, 11, 4, 9),
            remindNext: true,
          ),
          throwsArgumentError,
        );

        await db.saveMedicine(
          id: m,
          profileId: sara,
          name: 'Paracetamol syrup',
          instructions: '5 مل كل ٦ ساعات',
          startOn: DateTime(2026, 11, 1),
          minHoursBetweenDoses: const Value(6.5),
        );
        final withHours = await db.saveGivenMedicine(
          episodeId: e,
          medicineId: m,
          name: 'Paracetamol syrup',
          givenAt: DateTime(2026, 11, 4, 10),
          remindNext: true,
        );
        // Edited later: the dose already given keeps 6.5.
        await db.saveMedicine(
          id: m,
          profileId: sara,
          name: 'Paracetamol syrup',
          startOn: DateTime(2026, 11, 1),
          minHoursBetweenDoses: const Value(8),
        );
        // A save that doesn't mention the hours keeps them.
        await db.saveMedicine(
          id: m,
          profileId: sara,
          name: 'Paracetamol syrup',
          startOn: DateTime(2026, 11, 1),
        );
        expect((await db.watchMedicine(m).first)!.minHoursBetweenDoses, 8);
        final given = {
          for (final g in await db.watchGivenMedicines(e).first) g.id: g,
        };
        expect(given[noHours]!.intervalHours, isNull);
        expect(given[withHours]!.intervalHours, 6.5);
        expect(hoursAfter(given[withHours]!), DateTime(2026, 11, 4, 16, 30));

        // Typed, not a saved medicine: nothing to take hours from.
        final typed = await db.saveGivenMedicine(
          episodeId: e,
          name: 'Ibuprofen',
          amount: '5 ml',
          givenAt: DateTime(2026, 11, 4, 9),
        );
        expect(
          (await db.watchGivenMedicines(e).first)
              .firstWhere((g) => g.id == typed)
              .intervalHours,
          isNull,
        );
        expect(
          () => db.saveMedicine(
            profileId: sara,
            name: 'x',
            startOn: DateTime(2026, 11, 1),
            minHoursBetweenDoses: const Value(0),
          ),
          throwsArgumentError,
        );
      },
    );

    test('no text in the feature suggests an amount, a time or to give', () {
      final keys = RegExp(
        r'^(memberSickDays|sickDay|reading|given|nextDose|symptom|warn'
        r'|medicineMinHours)',
      );
      final dose = RegExp(
        r'\d\s*(mg|ml|مل|مجم|ملل)|\bgive\b|\bevery \d|allowed|اديله|اديها'
        r'|ادي له|الجرعة الجاية',
        caseSensitive: false,
      );
      for (final lang in ['en', 'ar']) {
        final arb = jsonDecode(
          File('lib/l10n/app_$lang.arb').readAsStringSync(),
        ) as Map<String, dynamic>;
        for (final MapEntry(:key, :value) in arb.entries) {
          if (!keys.hasMatch(key) || value is! String) continue;
          expect(dose.hasMatch(value), isFalse, reason: '$lang $key: $value');
        }
      }
      // The amount field never comes filled in, so no example amount.
      expect(en.givenAmountHint, isNot(contains(RegExp(r'\d'))));
      expect(
        en.givenHoursAfter('6', '14:00'),
        '6 hours after this dose: 14:00',
      );
      expect(en.givenRemind, 'Remind me at that time');
      expect(ar.givenRemind, 'فكرني في الوقت ده');
    });
  });

  group('next-dose reminders', () {
    late String episode;
    late String medicine;

    setUp(() async {
      episode = await db.saveEpisode(
        profileId: sara,
        startedAt: DateTime(2026, 11, 4, 8),
      );
      medicine = await paracetamol('5 مل كل ٦ ساعات', hours: 6);
    });

    Future<String> give(DateTime at, {bool remind = true}) =>
        db.saveGivenMedicine(
          episodeId: episode,
          medicineId: medicine,
          name: 'Paracetamol syrup',
          amount: '5 مل',
          givenAt: at,
          remindNext: remind,
        );

    test(
      'one per medicine, from the latest time given, with no buttons',
      () async {
        await give(DateTime(2026, 11, 4, 8));
        final last = await give(DateTime(2026, 11, 4, 14));
        final planned = await loadNextDoseReminders(
          db,
          now: DateTime(2026, 11, 4, 15),
          texts: NextDoseTexts(en, discreet: false),
        );
        final r = planned.single;
        expect(r.at, DateTime(2026, 11, 4, 20));
        expect(r.id, nextDoseReminderId(last));
        expect(r.id, inInclusiveRange(nextDoseReminderIdBase, 899999));
        expect(r.id, lessThan(snoozeIdBase));
        expect(r.takenLabel, isNull);
        expect(r.snoozeLabel, isNull);
        expect(r.hasButtons, isFalse);
        expect(r.isVaccine, isFalse);
        expect(r.title, 'Sara: Paracetamol syrup');
        expect(
          r.body,
          '6 hours have passed since the dose you logged. Check other '
          'medicines with the same ingredient.',
        );
        // The payload names the sick day, never the person or medicine.
        final ref = ReminderRef.fromPayload(r.toPayload())!;
        expect(ref.isNextDose, isTrue);
        expect(ref.isVaccine, isFalse);
        expect((ref.episodeId, ref.profileId), (episode, sara));
        expect(r.toPayload(), isNot(contains('Sara')));
        expect(r.toPayload(), isNot(contains('Paracetamol')));
      },
    );

    test('discreet: "A reminder from Usra", nothing named', () async {
      await give(DateTime(2026, 11, 4, 8));
      for (final l in [en, ar]) {
        final r = (await loadNextDoseReminders(
          db,
          now: DateTime(2026, 11, 4, 9),
          texts: NextDoseTexts(l, discreet: true),
        )).single;
        expect(r.title, l.nextDoseDiscreetTitle);
        expect(r.body, l.nextDoseDiscreetBody);
        for (final secret in ['Sara', 'Paracetamol', '٦', 'مل']) {
          expect('${r.title} ${r.body}', isNot(contains(secret)));
        }
        expect(r.hasButtons, isFalse);
      }
      expect(en.nextDoseDiscreetTitle, 'A reminder from Usra');
      expect(ar.nextDoseDiscreetTitle, 'تذكير من أسرة');
    });

    test('a later dose without a reminder cancels the earlier one', () async {
      await give(DateTime(2026, 11, 4, 8));
      await give(DateTime(2026, 11, 4, 11), remind: false);
      expect(
        await loadNextDoseReminders(
          db,
          now: DateTime(2026, 11, 4, 12),
          texts: NextDoseTexts(en, discreet: false),
        ),
        isEmpty,
      );
      // Asked again on the next dose: from that one.
      await give(DateTime(2026, 11, 4, 17));
      final r = (await loadNextDoseReminders(
        db,
        now: DateTime(2026, 11, 4, 18),
        texts: NextDoseTexts(en, discreet: false),
      )).single;
      expect(r.at, DateTime(2026, 11, 4, 23));
    });

    test('off unless asked for', () async {
      await give(DateTime(2026, 11, 4, 8), remind: false);
      expect(
        await loadNextDoseReminders(
          db,
          now: DateTime(2026, 11, 4, 9),
          texts: NextDoseTexts(en, discreet: false),
        ),
        isEmpty,
      );
    });

    test('the reminder sync schedules future ones first and rewrites one '
        'on screen', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      var now = DateTime(2026, 11, 4, 9);
      var discreet = true;
      final scheduler = FakeReminderScheduler();
      final dir = Directory.systemTemp.createTempSync('usra_sick_days');
      addTearDown(() => dir.deleteSync(recursive: true));
      final sync = ReminderSync(
        db: db,
        scheduler: scheduler,
        inbox: DoseActionInbox(File('${dir.path}/inbox.jsonl')),
        texts: () => ReminderTexts(en, discreet: discreet),
        clock: () => now,
        nextDoses: (now) => loadNextDoseReminders(
          db,
          now: now,
          texts: NextDoseTexts(en, discreet: discreet),
        ),
      );
      final given = await give(DateTime(2026, 11, 4, 8));
      await sync.resync();
      final r = scheduler.planned.single;
      expect(r.at, DateTime(2026, 11, 4, 14));
      expect(r.title, 'A reminder from Usra');

      // It rang; discreet is switched off: the one on screen is rewritten.
      now = DateTime(2026, 11, 4, 15);
      discreet = false;
      await sync.resync();
      expect(scheduler.planned, isEmpty);
      final rebuilt = scheduler.rebuild!(
        nextDoseReminderId(given),
        r.ref,
        r.at,
      );
      expect(rebuilt?.title, 'Sara: Paracetamol syrup');
      // Tapping Taken can't exist; an action on it saves nothing.
      await sync.handleAction(r.ref, DoseOutcome.taken);
      expect(await db.select(db.doseLogs).get(), isEmpty);

      // The entry is deleted while its notification is on screen: it goes.
      await db.softDeleteGivenMedicine(given);
      await sync.resync();
      expect(
        scheduler.rebuild!(nextDoseReminderId(given), r.ref, r.at),
        isNull,
      );
      final changes = diffReminders(
        pending: const [],
        shown: [
          (id: r.id, title: r.title, body: r.body, payload: r.toPayload()),
        ],
        wanted: const [],
        rebuild: scheduler.rebuild,
        now: now,
      );
      expect(changes.cancel, {r.id});
    });

    test(
      'nearest first with dose reminders, for the iOS limit of 64',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        final now = DateTime(2026, 11, 4, 9);
        // A medicine 9 times a day: a week of doses fills the plan.
        await db.saveMedicine(
          profileId: sara,
          name: 'Drops',
          startOn: DateTime(2026, 11, 1),
          schedule: DoseScheduleInput(
            times: [
              for (var h = 6; h <= 22; h += 2) '${'$h'.padLeft(2, '0')}:30',
            ],
          ),
        );
        await give(DateTime(2026, 11, 4, 8));
        final scheduler = FakeReminderScheduler();
        final dir = Directory.systemTemp.createTempSync('usra_sick_days');
        addTearDown(() => dir.deleteSync(recursive: true));
        final sync = ReminderSync(
          db: db,
          scheduler: scheduler,
          inbox: DoseActionInbox(File('${dir.path}/inbox.jsonl')),
          texts: () => ReminderTexts(en, discreet: true),
          clock: () => now,
          nextDoses: (now) => loadNextDoseReminders(
            db,
            now: now,
            texts: NextDoseTexts(en, discreet: true),
          ),
        );
        await sync.resync();
        final planned = scheduler.planned;
        final times = planned.map((r) => r.at).toList();
        expect(times, [...times]..sort());
        final next = planned.indexWhere((r) => r.isNextDose);
        // 14:00, after the 10:30 and 12:30 doses, before the 14:30 one.
        expect(planned[next].at, DateTime(2026, 11, 4, 14));
        expect(next, 2);
      },
    );
  });

  test('an older build can open a v8 database, and updating again works', () async {
    final file = File(
      '${Directory.systemTemp.createTempSync('usra_rollback').path}/db.sqlite',
    );
    addTearDown(() => file.parent.deleteSync(recursive: true));
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final v8 = AppDatabase(NativeDatabase(file));
    final p = await v8.addProfile('Mona');
    final m = await v8.saveMedicine(
      profileId: p,
      name: 'Paracetamol',
      startOn: DateTime(2026, 11, 1),
      minHoursBetweenDoses: const Value(6),
    );
    final e = await v8.saveEpisode(
      profileId: p,
      startedAt: DateTime(2026, 11, 4),
    );
    await v8.close();

    // A v7 build (rolled back): drift calls onUpgrade(8, 7), which does
    // nothing; the app opens and the version goes back to 7.
    final v7 = _V7Database(NativeDatabase(file));
    expect((await v7.watchMedicine(m).first)!.name, 'Paracetamol');
    expect(
      (await v7.customSelect('PRAGMA user_version').getSingle()).read<int>(
        'user_version',
      ),
      7,
    );
    await v7.close();

    // Fix forward: the v8 migration runs again over its own tables.
    final again = AppDatabase(NativeDatabase(file));
    addTearDown(again.close);
    expect((await again.watchMedicine(m).first)!.minHoursBetweenDoses, 6);
    expect((await again.watchEpisode(e).first)!.profileId, p);
  });

  group('migration from v7 (drift_schemas snapshot)', () {
    late SchemaVerifier verifier;
    setUpAll(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      verifier = SchemaVerifier(GeneratedHelper());
    });

    test('the upgraded schema matches a fresh current one', () async {
      final schema = await verifier.schemaAt(7);
      final upgraded = AppDatabase(schema.newConnection());
      addTearDown(upgraded.close);
      await verifier.migrateAndValidate(upgraded, AppDatabase.currentSchema);
    });

    test('a v7 database keeps its data and gains sick days', () async {
      final schema = await verifier.schemaAt(7);
      schema.rawDatabase.execute('''
        INSERT INTO profiles (id, display_name, updated_at)
          VALUES ('p1', 'Mona', 0);
        INSERT INTO prescriptions (id, profile_id, prescribed_on, updated_at)
          VALUES ('rx1', 'p1', 1767225600, 0);
        INSERT INTO medicines (id, profile_id, name, instructions,
            prescription_id, start_on, updated_at)
          VALUES ('m1', 'p1', 'Paracetamol', 'every 6 hours', 'rx1',
            1767225600, 0);
      ''');
      final upgraded = AppDatabase(schema.newConnection());
      addTearDown(upgraded.close);
      expect((await upgraded.watchMedicine('m1').first)!.prescriptionId, 'rx1');
      // The new column is there, empty: no hours unless the family types them.
      expect(
        (await upgraded.watchMedicine('m1').first)!.minHoursBetweenDoses,
        isNull,
      );
      await upgraded.customStatement(
        "UPDATE medicines SET min_hours_between_doses = 6 WHERE id = 'm1'",
      );

      final e = await upgraded.saveEpisode(
        profileId: 'p1',
        startedAt: DateTime(2026, 11, 4),
      );
      await upgraded.saveGivenMedicine(
        episodeId: e,
        medicineId: 'm1',
        prescriptionId: 'rx1',
        name: 'Paracetamol',
        givenAt: DateTime(2026, 11, 4, 8),
        remindNext: true,
      );
      expect(
        (await upgraded.watchNextDoseSources().first).single.medicine.id,
        'm1',
      );
      // The foreign keys came with the upgrade.
      await expectLater(
        upgraded
            .into(upgraded.temperatureReadings)
            .insert(
              TemperatureReadingsCompanion.insert(
                id: 'bad',
                episodeId: 'missing',
                takenAt: DateTime.utc(2026),
                value: 38,
                unit: 'c',
                updatedAt: DateTime.utc(2026),
                site: const Value(null),
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });
  });
}

/// The app as a v7 build sees the same code: a lower schema version.
class _V7Database extends AppDatabase {
  _V7Database(super.executor);

  @override
  int get schemaVersion => 7;
}
