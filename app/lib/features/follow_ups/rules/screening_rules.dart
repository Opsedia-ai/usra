import 'package:flutter/widgets.dart';

import '../../../core/follow_ups/follow_up.dart';
import '../../../l10n/app_localizations.dart';
import '../../children/growth.dart' show addMonths;
import '../conditions.dart';
import 'reasons.dart';
import '../../pregnancy/pregnancy.dart' show PregnancyFields, PregnancyTypes;

/// Screenings starting more than this far ahead don't show yet.
const screeningLookaheadDays = 365;

/// How often a screening repeats, depending on which test was done: a
/// colonoscopy lasts ten years, a stool test one.
typedef ScreeningTest = ({List<String> keywords, int months});

/// A check public guidance suggests by age and sex (and sometimes a
/// condition). Due [ScreeningTest.months] after the last matching record;
/// due now when none is recorded, or on the birthday it starts at.
abstract class ScreeningRule extends FollowUpRule {
  const ScreeningRule();

  /// Ages it applies to, in whole years, both included.
  int get minAge;
  int get maxAge => 200;

  /// `female` or `male`; null for everyone.
  String? get sex => null;

  /// The person must have one of these (empty: anyone).
  Set<Condition> get requires => const {};

  /// Not suggested to people who have one of these (they're already
  /// followed for it).
  Set<Condition> get skipWhen => const {};

  /// Tests that count, checked in order; the first that matches a record
  /// sets the interval.
  List<ScreeningTest> get tests;

  /// Record types searched for a matching test.
  Set<String> get searchIn;

  /// A test [r] stands for without naming it in text (a measurement record,
  /// say); null when it doesn't.
  ScreeningTest? measuredBy(SubjectRecord r) => null;

  /// The record type to add once done.
  String get recordType;
  String get source;

  /// The guideline shown to [subject] on [today]: [source], unless the rule
  /// spans children and adults and each has its own (end-to-end test #6: an
  /// adult was shown a children's guideline).
  String sourceFor(FollowUpSubject subject, DateTime today) => source;
  String title(AppLocalizations l);

  /// Why this person: their age, sex or condition.
  String reason(BuildContext c, FollowUpSubject subject);

  @override
  List<FollowUp> evaluate(FollowUpSubject subject, DateTime today) {
    final profile = subject.profile;
    final birth = profile.birthDate;
    if (birth == null) return const [];
    if (sex != null && profile.sex != sex) return const [];
    final conditions = conditionsIn(profile.conditions);
    if (requires.isNotEmpty && conditions.intersection(requires).isEmpty) {
      return const [];
    }
    if (conditions.intersection(skipWhen).isNotEmpty) return const [];

    final day = dayOf(today);
    final from = dayOf(addMonths(birth, 12 * minAge));
    final until = dayOf(addMonths(birth, 12 * (maxAge + 1)));
    if (!day.isBefore(until)) return const [];
    if (from.difference(day).inDays > screeningLookaheadDays) return const [];

    DateTime? last;
    int? months;
    for (final r in subject.records.reversed) {
      final test = searchIn.contains(r.event.type)
          ? tests
                .where(
                  (t) => mentionsAny(
                    r.data.values.whereType<String>().join(' '),
                    t.keywords,
                  ),
                )
                .firstOrNull
          : measuredBy(r);
      if (test == null) continue;
      last = r.event.occurredAt;
      months = test.months;
      break;
    }
    final due = last == null
        ? (from.isAfter(day) ? from : day)
        : dayOf(addMonths(last, months!));
    if (!due.isBefore(until)) return const [];
    return [
      FollowUp(
        ruleId: id,
        profileId: profile.id,
        dueOn: due,
        title: (c) => title(AppLocalizations.of(c)),
        reason: (c) =>
            joinReasons([reason(c, subject), lastDone(c, last, today)]),
        recordType: recordType,
        source: sourceFor(subject, day),
        cycle: last == null && !from.isAfter(day) ? 'none' : null,
      ),
    ];
  }
}

String _ageFrom(BuildContext c, int age) =>
    AppLocalizations.of(c).fuAgeFrom(age);

/// Blood pressure measured at least yearly from 18 (USPSTF suggests every
/// 3–5 years for 18–39 at low risk; yearly is the simple, safe default).
class BloodPressureRule extends ScreeningRule {
  const BloodPressureRule();

  @override
  String get id => 'screening.bloodPressure';
  @override
  int get minAge => 18;
  @override
  List<ScreeningTest> get tests => const [
    (keywords: ['ضغط', 'blood pressure', 'hypertension'], months: 12),
  ];
  @override
  Set<String> get searchIn => const {'visit', 'lab'};

  /// A reading logged during pregnancy is a measurement too.
  @override
  ScreeningTest? measuredBy(SubjectRecord r) =>
      r.event.type == PregnancyTypes.check &&
          (r.data[PregnancyFields.systolic] is num ||
              r.data[PregnancyFields.diastolic] is num)
      ? tests.first
      : null;
  @override
  String get recordType => 'visit';
  @override
  String get source => 'USPSTF 2021: Hypertension in adults';
  @override
  String title(AppLocalizations l) => l.fuBloodPressure;
  @override
  String reason(BuildContext c, FollowUpSubject s) {
    final has = conditionsIn(s.profile.conditions);
    return has.contains(Condition.hypertension)
        ? becauseCondition(c, s.profile.sex, Condition.hypertension)
        : _ageFrom(c, minAge);
  }
}

/// Blood sugar every three years at 35–70, for people not known to have
/// diabetes (USPSTF: adults with overweight or obesity).
class DiabetesScreeningRule extends ScreeningRule {
  const DiabetesScreeningRule();

  @override
  String get id => 'screening.diabetes';
  @override
  int get minAge => 35;
  @override
  int get maxAge => 70;
  @override
  Set<Condition> get skipWhen => const {Condition.diabetes};
  @override
  List<ScreeningTest> get tests => const [
    (
      keywords: [
        'سكر',
        'جلوكوز',
        'glucose',
        'sugar',
        'hba1c',
        'a1c',
        'fbs',
        'تراكمي',
      ],
      months: 36,
    ),
  ];
  @override
  Set<String> get searchIn => const {'lab'};
  @override
  String get recordType => 'lab';
  @override
  String get source => 'USPSTF 2021: Prediabetes and type 2 diabetes';
  @override
  String title(AppLocalizations l) => l.fuBloodSugar;
  @override
  String reason(BuildContext c, FollowUpSubject s) =>
      AppLocalizations.of(c).fuAgeRange(minAge, maxAge);
}

/// A mammogram every two years for women 40–74.
class BreastScreeningRule extends ScreeningRule {
  const BreastScreeningRule();

  @override
  String get id => 'screening.breast';
  @override
  int get minAge => 40;
  @override
  int get maxAge => 74;
  @override
  String? get sex => 'female';
  @override
  List<ScreeningTest> get tests => const [
    (
      keywords: ['mammo', 'ماموجرام', 'ماموغرام', 'ماموجرافي', 'ثدي', 'breast'],
      months: 24,
    ),
  ];
  // Scans only: a visit for breast pain isn't a screening.
  @override
  Set<String> get searchIn => const {'scan'};
  @override
  String get recordType => 'scan';
  @override
  String get source => 'USPSTF 2024: Breast cancer screening';
  @override
  String title(AppLocalizations l) => l.fuMammogram;
  @override
  String reason(BuildContext c, FollowUpSubject s) =>
      AppLocalizations.of(c).fuWomenAgeRange(minAge, maxAge);
}

/// Colorectal cancer screening at 45–75: a stool test yearly, or a
/// colonoscopy every ten years.
class ColorectalScreeningRule extends ScreeningRule {
  const ColorectalScreeningRule();

  @override
  String get id => 'screening.colorectal';
  @override
  int get minAge => 45;
  @override
  int get maxAge => 75;
  @override
  List<ScreeningTest> get tests => const [
    (keywords: ['colonoscopy', 'منظار قولون', 'منظار القولون'], months: 120),
    (keywords: ['sigmoidoscopy', 'منظار سيني'], months: 60),
    (
      keywords: ['fit test', 'fobt', 'occult', 'stool', 'دم خفي', 'براز'],
      months: 12,
    ),
  ];
  @override
  Set<String> get searchIn => const {'lab', 'scan', 'visit', 'surgery'};
  @override
  String get recordType => 'lab';
  @override
  String get source => 'USPSTF 2021: Colorectal cancer screening';
  @override
  String title(AppLocalizations l) => l.fuColorectal;
  @override
  String reason(BuildContext c, FollowUpSubject s) =>
      AppLocalizations.of(c).fuAgeRange(minAge, maxAge);
}

/// A yearly dilated eye (retina) exam with diabetes.
class DiabeticEyeExamRule extends ScreeningRule {
  const DiabeticEyeExamRule();

  @override
  String get id => 'screening.diabeticEye';
  @override
  int get minAge => 0;
  @override
  Set<Condition> get requires => const {Condition.diabetes};
  @override
  List<ScreeningTest> get tests => const [
    (
      keywords: [
        'عين',
        'عيون',
        'رمد',
        'قاع',
        'شبكيه',
        'eye',
        'retina',
        'fundus',
        'ophthalm',
      ],
      months: 12,
    ),
  ];
  @override
  Set<String> get searchIn => const {'visit', 'scan'};
  @override
  String get recordType => 'visit';
  @override
  String get source => 'ADA Standards of Care 2025, §12; WHO HEARTS-D';
  @override
  String title(AppLocalizations l) => l.fuEyeExam;
  @override
  String reason(BuildContext c, FollowUpSubject s) =>
      becauseCondition(c, s.profile.sex, Condition.diabetes);
}

/// A dental check-up once a year from the first birthday. Children's and
/// adults' guidelines differ, so each sees their own as the source.
class DentalCheckupRule extends ScreeningRule {
  const DentalCheckupRule();

  @override
  String get id => 'screening.dental';
  @override
  int get minAge => 1;
  @override
  List<ScreeningTest> get tests => const [
    (
      keywords: ['سنان', 'اسنان', 'ضرس', 'dentist', 'dental', 'teeth', 'tooth'],
      months: 12,
    ),
  ];
  @override
  Set<String> get searchIn => const {'visit', 'surgery'};
  @override
  String get recordType => 'visit';
  @override
  String get source => childSource;

  /// Under 18: the American Academy of Pediatric Dentistry's periodicity
  /// schedule (a visit every 6–12 months from the first tooth or birthday).
  static const childSource = 'AAPD 2024 (children); WHO oral health';

  /// 18 and over: NICE CG19 sets adult recall between 3 and 24 months by the
  /// dentist's judgement; yearly sits inside that. Needs the doctor's review.
  static const adultSource =
      'NICE CG19 (dental recall, adults); WHO oral health';

  @override
  String sourceFor(FollowUpSubject subject, DateTime today) {
    final birth = subject.profile.birthDate;
    if (birth == null) return source;
    final adultFrom = dayOf(addMonths(birth, 12 * 18));
    return dayOf(today).isBefore(adultFrom) ? childSource : adultSource;
  }

  @override
  String title(AppLocalizations l) => l.fuDental;
  @override
  String reason(BuildContext c, FollowUpSubject s) =>
      AppLocalizations.of(c).fuYearlyForAll;
}

/// Well-child check-ups at the ages AAP Bright Futures lists: 1, 2, 4, 6,
/// 9, 12, 15, 18, 24 and 30 months, then every year until 18.
class ChildCheckupRule extends FollowUpRule {
  const ChildCheckupRule();

  @override
  String get id => 'screening.childCheckup';

  static final milestoneMonths = [
    1, 2, 4, 6, 9, 12, 15, 18, 24, 30, //
    for (var year = 3; year < 18; year++) 12 * year,
  ];

  /// A check-up up to two weeks early still counts for that age.
  static const earlyDays = 14;

  static const _checkupWords = [
    'كشف دوري',
    'متابعه',
    'متابعة نمو',
    'check up',
    'checkup',
    'well child',
    'well baby',
    'routine',
  ];

  @override
  List<FollowUp> evaluate(FollowUpSubject subject, DateTime today) {
    final birth = subject.profile.birthDate;
    if (birth == null) return const [];
    final day = dayOf(today);
    if (!day.isBefore(dayOf(addMonths(birth, 12 * 18)))) return const [];

    // A growth measurement or a visit called a check-up.
    final last = subject.records
        .where(
          (r) =>
              r.event.type == 'growth' ||
              (r.event.type == 'visit' &&
                  mentionsAny(
                    r.data.values.whereType<String>().join(' '),
                    _checkupWords,
                  )),
        )
        .lastOrNull
        ?.event
        .occurredAt;
    final after = dayOf(last ?? birth).add(const Duration(days: earlyDays));
    final open = [
      for (final m in milestoneMonths)
        if (dayOf(addMonths(birth, m)).isAfter(after)) m,
    ];
    if (open.isEmpty) return const [];
    // Several missed check-ups make one: the latest one already due.
    final missed = open.where((m) => !dayOf(addMonths(birth, m)).isAfter(day));
    final months = missed.isEmpty ? open.first : missed.last;
    return [
      FollowUp(
        ruleId: '$id.$months',
        profileId: subject.profile.id,
        dueOn: addMonths(birth, months),
        title: (c) => AppLocalizations.of(c).fuChildCheckup,
        reason: (c) {
          final l = AppLocalizations.of(c);
          return l.fuChildCheckupAt(
            months < 24 ? l.fuAgeMonths(months) : l.ageYears(months ~/ 12),
          );
        },
        recordType: 'visit',
        source: 'AAP Bright Futures periodicity schedule 2025',
      ),
    ];
  }
}
