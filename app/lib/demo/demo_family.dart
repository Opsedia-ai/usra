import 'dart:convert';

import 'package:flutter/widgets.dart' show Locale;

import '../core/database/app_database.dart';
import '../core/preferences.dart';
import '../features/children/child_vaccines.dart';
import '../features/children/egypt_vaccines.dart';
import '../features/children/growth.dart';
import '../features/children/infant_log.dart';
import '../features/labs/lab_report.dart';
import '../features/pregnancy/pregnancy.dart';
import '../features/sick_days/fever.dart';
import '../l10n/app_localizations.dart';

/// A made-up family for screenshots, golden tests and on-device journeys:
/// a grandmother who uses Simple Mode, a pregnant mother, a father with an
/// insurance card, a toddler with a fever today and a three-month-old.
///
/// Never runs in a release build: the app only calls it from a debug build
/// started with `--dart-define=USRA_DEMO=true` (see `lib/demo/README.md`),
/// and only into an empty database. Everything is relative to [now] so the
/// vaccine and pregnancy screens always look the same.
Future<DemoFamily> seedDemoFamily(
  AppDatabase db, {
  required DateTime now,
  AppLocalizations? l,
}) async {
  final texts = l ?? lookupAppLocalizations(const Locale('ar'));
  final today = DateTime(now.year, now.month, now.day);
  DateTime daysAgo(int d) => today.subtract(Duration(days: d));
  DateTime monthsAgo(int m) => addMonths(today, -m);

  final drSami = await db.saveDoctor(
    name: 'د. سامي عبد الله',
    specialty: 'أطفال',
    phone: '01001234567',
    clinic: 'عيادة النيل',
    address: 'شارع التحرير، الدقي',
    feeMinor: 40000,
  );
  final drHala = await db.saveDoctor(
    name: 'د. هالة منصور',
    specialty: 'نسا وتوليد',
    phone: '01117654321',
    clinic: 'مستشفى السلام',
    feeMinor: 50000,
  );
  final drOmar = await db.saveDoctor(
    name: 'د. عمر فتحي',
    specialty: 'باطنة',
    phone: '0233445566',
    feeMinor: 30000,
  );

  // Grandmother: Simple Mode, two daily medicines, a lab.
  final fatma = await _addInOrder(
    db,
    'تيتة فاطمة',
    birthDate: DateTime(1952, 3, 14),
    sex: 'female',
    bloodType: 'A+',
    allergies: 'بنسلين',
    conditions: 'ضغط، سكر',
    simpleMode: true,
  );
  final concor = await db.saveMedicine(
    profileId: fatma,
    name: 'Concor',
    strength: '5 mg',
    form: 'tablet',
    instructions: 'قرص الصبح بعد الفطار',
    doctorId: drOmar,
    startOn: monthsAgo(6),
    schedule: const DoseScheduleInput(times: ['09:00'], amount: 'قرص'),
  );
  await db.saveMedicine(
    profileId: fatma,
    name: 'Glucophage',
    strength: '500 mg',
    form: 'tablet',
    instructions: 'قرص بعد الفطار وقرص بعد العشا',
    doctorId: drOmar,
    startOn: monthsAgo(6),
    schedule: const DoseScheduleInput(times: ['09:00', '21:00'], amount: 'قرص'),
  );
  await db.logDose(
    concor,
    DateTime(today.year, today.month, today.day, 9),
    DoseOutcome.taken,
    at: DateTime(today.year, today.month, today.day, 9, 10),
  );
  await db.addEvent(
    profileId: fatma,
    type: LabFields.type,
    occurredAt: daysAgo(20),
    doctorId: drOmar,
    costMinor: 45000,
    currency: 'EGP',
    dataJson: jsonEncode({
      LabFields.test: 'HbA1c, Creatinine',
      LabFields.lab: 'معامل البرج',
      LabFields.tests: [
        {'name': 'HbA1c', 'value': 7.4, 'unit': '%', 'high': 5.7},
        {
          'name': 'Creatinine',
          'value': 1.0,
          'unit': 'mg/dL',
          'low': 0.5,
          'high': 1.1,
        },
      ],
    }),
  );
  await db.addEvent(
    profileId: fatma,
    type: 'visit',
    occurredAt: daysAgo(21),
    doctorId: drOmar,
    costMinor: 30000,
    currency: 'EGP',
    dataJson: jsonEncode({
      'doctorName': 'د. عمر فتحي',
      'reason': 'متابعة الضغط والسكر',
      'diagnosis': 'السكر محتاج ضبط',
      'nextVisit': addMonths(today, 2).toIso8601String(),
    }),
  );

  // Mother: about 22 weeks pregnant, a check-up, a blood count.
  final mona = await _addInOrder(
    db,
    'منى',
    birthDate: DateTime(1993, 7, 2),
    sex: 'female',
    bloodType: 'O+',
  );
  await db.addEvent(
    profileId: mona,
    type: PregnancyTypes.start,
    occurredAt: daysAgo(150),
    dataJson: jsonEncode({
      PregnancyFields.dueDate: today
          .add(const Duration(days: 126))
          .toIso8601String(),
    }),
  );
  await db.addEvent(
    profileId: mona,
    type: PregnancyTypes.check,
    occurredAt: daysAgo(10),
    doctorId: drHala,
    costMinor: 50000,
    currency: 'EGP',
    dataJson: jsonEncode({
      PregnancyFields.weightKg: 68.5,
      PregnancyFields.systolic: 115,
      PregnancyFields.diastolic: 75,
    }),
  );
  await db.addEvent(
    profileId: mona,
    type: LabFields.type,
    occurredAt: daysAgo(10),
    doctorId: drHala,
    dataJson: jsonEncode({
      LabFields.test: 'Hemoglobin, Ferritin',
      LabFields.lab: 'معامل المختبر',
      LabFields.tests: [
        {
          'name': 'Hemoglobin',
          'value': 10.4,
          'unit': 'g/dL',
          'low': 11.0,
          'high': 15.0,
        },
        {
          'name': 'Ferritin',
          'value': 18,
          'unit': 'ng/mL',
          'low': 15,
          'high': 150,
        },
      ],
    }),
  );
  await db.saveMedicine(
    profileId: mona,
    name: 'Ferrotron',
    form: 'capsule',
    instructions: 'كبسولة قبل الأكل بساعة',
    doctorId: drHala,
    startOn: daysAgo(9),
    schedule: const DoseScheduleInput(times: ['08:00'], amount: 'كبسولة'),
  );

  // Father: an insurance card and a visit.
  final ahmed = await _addInOrder(
    db,
    'أحمد',
    birthDate: DateTime(1989, 11, 20),
    sex: 'male',
    bloodType: 'B+',
  );
  await db.saveInsuranceCard(
    profileId: ahmed,
    label: 'تأمين الشغل',
    insurer: 'مصر للتأمين',
    memberNumber: '4410 2235 9087',
    expiresOn: addMonths(today, 8),
  );

  // Toddler: 2 years 3 months, a fever today, vaccines up to 12 months.
  final youssefBirth = monthsAgo(27);
  final youssef = await _addInOrder(
    db,
    'يوسف',
    birthDate: youssefBirth,
    sex: 'male',
  );
  for (final dose in egyptMandatorySchedule.where((d) => d.ageMonths <= 12)) {
    final r = vaccineRecordFor(
      texts,
      dose,
      addMonths(youssefBirth, dose.ageMonths),
    );
    await db.addEvent(
      profileId: youssef,
      type: r.type,
      occurredAt: r.occurredAt,
      dataJson: r.dataJson,
    );
  }
  for (final (months, kg, cm, head) in [
    (6, 7.6, 66.0, 43.0),
    (12, 9.8, 75.5, 46.0),
    (18, 11.0, 81.0, 47.2),
    (24, 12.1, 86.5, 48.0),
  ]) {
    await db.addEvent(
      profileId: youssef,
      type: 'growth',
      occurredAt: addMonths(youssefBirth, months),
      dataJson: jsonEncode({
        GrowthFields.weightKg: kg,
        GrowthFields.heightCm: cm,
        GrowthFields.headCm: head,
      }),
    );
  }
  final augmentin = await db.savePrescription(
    profileId: youssef,
    doctorId: drSami,
    prescribedOn: daysAgo(1),
    diagnosis: 'التهاب في الزور',
    items: [
      PrescriptionItemInput(
        name: 'Augmentin 228 mg/5 ml',
        form: 'syrup',
        dose: '5 مل كل 12 ساعة بعد الأكل',
        times: const ['08:00', '20:00'],
        startOn: daysAgo(1),
        days: 7,
      ),
      PrescriptionItemInput(
        name: 'Cetal 120 mg/5 ml',
        form: 'syrup',
        dose: '5 مل عند اللزوم لو الحرارة فوق 38',
        startOn: daysAgo(1),
      ),
    ],
  );
  final episode = await db.saveEpisode(
    profileId: youssef,
    startedAt: today.subtract(const Duration(hours: 20)),
    symptoms: const [Symptom.soreThroat, Symptom.cough],
  );
  for (final (hoursAgo, value) in [
    (19, 38.2),
    (14, 38.9),
    (8, 38.4),
    (2, 37.8),
  ]) {
    await db.saveReading(
      episodeId: episode,
      takenAt: now.subtract(Duration(hours: hoursAgo)),
      value: value,
      unit: TemperatureUnit.celsius,
      site: TemperatureSite.armpit,
    );
  }
  await db.saveGivenMedicine(
    episodeId: episode,
    prescriptionId: augmentin,
    name: 'Cetal 120 mg/5 ml',
    amount: '5 مل',
    givenAt: now.subtract(const Duration(hours: 14)),
  );
  await db.addEvent(
    profileId: youssef,
    type: 'visit',
    occurredAt: daysAgo(1),
    doctorId: drSami,
    costMinor: 40000,
    currency: 'EGP',
    dataJson: jsonEncode({
      'doctorName': 'د. سامي عبد الله',
      'reason': 'سخونية وكحة',
      'diagnosis': 'التهاب في الزور',
    }),
  );

  // Infant: three months, birth and two-month vaccines, a baby log.
  final laylaBirth = monthsAgo(3);
  final layla = await _addInOrder(
    db,
    'ليلى',
    birthDate: laylaBirth,
    sex: 'female',
  );
  for (final dose in egyptMandatorySchedule.where((d) => d.ageMonths <= 2)) {
    final r = vaccineRecordFor(
      texts,
      dose,
      addMonths(laylaBirth, dose.ageMonths),
    );
    await db.addEvent(
      profileId: layla,
      type: r.type,
      occurredAt: r.occurredAt,
      dataJson: r.dataJson,
    );
  }
  for (final (months, kg, cm, head) in [
    (0, 3.2, 50.0, 34.5),
    (1, 4.3, 54.0, 37.0),
    (2, 5.4, 57.5, 38.8),
  ]) {
    await db.addEvent(
      profileId: layla,
      type: 'growth',
      occurredAt: addMonths(laylaBirth, months),
      dataJson: jsonEncode({
        GrowthFields.weightKg: kg,
        GrowthFields.heightCm: cm,
        GrowthFields.headCm: head,
      }),
    );
  }
  for (final (hoursAgo, type, data) in <(int, String, Map<String, Object>)>[
    (1, InfantLog.feed, {InfantLog.kind: 'breast', InfantLog.minutes: 15}),
    (3, InfantLog.diaper, {InfantLog.kind: 'wet'}),
    (4, InfantLog.feed, {InfantLog.kind: 'bottle', InfantLog.amountMl: 90}),
    (6, InfantLog.sleep, {InfantLog.minutes: 120}),
  ]) {
    await db.addEvent(
      profileId: layla,
      type: type,
      occurredAt: now.subtract(Duration(hours: hoursAgo)),
      dataJson: jsonEncode(data),
    );
  }

  return DemoFamily(
    fatma: fatma,
    mona: mona,
    ahmed: ahmed,
    youssef: youssef,
    layla: layla,
    youssefFever: episode,
    pediatrician: drSami,
  );
}

/// The ids [seedDemoFamily] created, for tests that open a given screen.
class DemoFamily {
  const DemoFamily({
    required this.fatma,
    required this.mona,
    required this.ahmed,
    required this.youssef,
    required this.layla,
    required this.youssefFever,
    required this.pediatrician,
  });

  final String fatma;
  final String mona;
  final String ahmed;
  final String youssef;
  final String layla;
  final String youssefFever;
  final String pediatrician;
}

/// Seeds [seedDemoFamily] into an empty database and skips the first-run
/// tour, so the app opens on the family. Does nothing once anyone exists.
Future<void> seedDemoIfEmpty(AppDatabase db, KeyValueStore prefs) async {
  if ((await db.watchProfiles().first).isNotEmpty) return;
  await seedDemoFamily(db, now: DateTime.now());
  await prefs.setBool(PrefKeys.tutorialSeen, true);
  await prefs.setBool(PrefKeys.appLockOffered, true);
}

/// People are listed by id, a UUID v7 that keeps only the millisecond it
/// was made in; two people added in the same one come out in either order.
/// A real family is added by hand, a demo one in a burst: wait a moment
/// so screenshots always list them the same way.
Future<String> _addInOrder(
  AppDatabase db,
  String name, {
  DateTime? birthDate,
  String? sex,
  String? bloodType,
  String? allergies,
  String? conditions,
  bool? simpleMode,
}) async {
  await Future<void>.delayed(const Duration(milliseconds: 2));
  return db.addProfile(
    name,
    birthDate: birthDate,
    sex: sex,
    bloodType: bloodType,
    allergies: allergies,
    conditions: conditions,
    simpleMode: simpleMode,
  );
}
