import '../../../core/follow_ups/follow_up.dart';
import '../../../l10n/app_localizations.dart';
import '../../children/growth.dart' show addMonths;
import '../conditions.dart';
import 'reasons.dart';

/// A date field as stored by the record form (`yyyy-MM-dd`); null when
/// missing or malformed.
DateTime? dateField(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

/// Follow-ups more than a year overdue are most likely done but not
/// recorded, so they stop showing.
const staleAfterDays = 365;

bool _stale(DateTime due, DateTime today) =>
    dayOf(today).difference(dayOf(due)).inDays > staleAfterDays;

/// The next visit a doctor asked for (`nextVisit` on a visit). Closed by a
/// later visit to the same doctor.
class NextVisitRule extends FollowUpRule {
  const NextVisitRule();

  @override
  String get id => 'visit';

  @override
  List<FollowUp> evaluate(FollowUpSubject subject, DateTime today) {
    final visits = subject.ofType('visit').toList();
    String nameOf(SubjectRecord r) =>
        normalizeText('${r.data['doctorName'] ?? ''}');
    // The same saved doctor, or the same name (one may be linked to a saved
    // doctor and the other only typed).
    bool sameDoctor(SubjectRecord a, SubjectRecord b) =>
        (a.event.doctorId != null && a.event.doctorId == b.event.doctorId) ||
        nameOf(a) == nameOf(b);
    return [
      for (final v in visits)
        if (dateField(v.data['nextVisit']) case final due?)
          if (!_stale(due, today) &&
              !visits.any(
                (o) =>
                    sameDoctor(o, v) &&
                    dayOf(o.event.occurredAt)
                        .isAfter(dayOf(v.event.occurredAt)),
              ))
            FollowUp(
              ruleId: '$id.${v.event.id}',
              profileId: subject.profile.id,
              dueOn: due,
              title: (c) => AppLocalizations.of(c).fuNextVisit,
              reason: switch (v.data['doctorName']) {
                final String doctor when doctor.trim().isNotEmpty => (
                  c,
                ) => AppLocalizations.of(c).fuNextVisitBy(doctor.trim()),
                _ => (c) => AppLocalizations.of(c).fuNextVisitSet,
              },
              recordType: 'visit',
            ),
    ];
  }
}

/// The next dose written on a vaccine record (`nextDue`). Closed by a later
/// record of the same vaccine.
class VaccineNextDueRule extends FollowUpRule {
  const VaccineNextDueRule();

  @override
  String get id => 'vaccine';

  @override
  List<FollowUp> evaluate(FollowUpSubject subject, DateTime today) {
    final doses = subject.ofType('vaccine').toList();
    String nameOf(SubjectRecord r) =>
        normalizeText('${r.data['vaccine'] ?? ''}');
    return [
      for (final d in doses)
        if (dateField(d.data['nextDue']) case final due?)
          if (!_stale(due, today) &&
              !doses.any(
                (o) =>
                    nameOf(o) == nameOf(d) &&
                    dayOf(o.event.occurredAt)
                        .isAfter(dayOf(d.event.occurredAt)),
              ))
            FollowUp(
              ruleId: '$id.${d.event.id}',
              profileId: subject.profile.id,
              dueOn: due,
              title: (c) =>
                  AppLocalizations.of(c)
                      .fuNextDose('${d.data['vaccine'] ?? ''}'.trim()),
              reason: (c) => AppLocalizations.of(c).fuNextDoseSet,
              recordType: 'vaccine',
            ),
    ];
  }
}

/// A lab test people with a long-term condition repeat on a schedule.
/// Due [months] after the last one; due now if none is recorded.
abstract class ChronicLabRule extends FollowUpRule {
  const ChronicLabRule();

  /// Any of these conditions in the profile makes the test apply.
  Set<Condition> get conditions;

  /// Words in the lab's `test` field, normalized.
  List<String> get keywords;
  int get months;
  String get source;
  String title(AppLocalizations l);

  @override
  List<FollowUp> evaluate(FollowUpSubject subject, DateTime today) {
    final has = conditionsIn(subject.profile.conditions)
        .intersection(conditions);
    if (has.isEmpty) return const [];
    // The first matching condition, in the order the rule lists them.
    final because = conditions.firstWhere(has.contains);
    final last = subject
        .ofType('lab')
        .where((r) => mentionsAny('${r.data['test'] ?? ''}', keywords))
        .lastOrNull
        ?.event
        .occurredAt;
    return [
      FollowUp(
        ruleId: id,
        profileId: subject.profile.id,
        dueOn: last == null ? today : addMonths(last, months),
        title: (c) => title(AppLocalizations.of(c)),
        reason: (c) => joinReasons([
          becauseCondition(c, subject.profile.sex, because),
          lastDone(c, last, today),
        ]),
        recordType: 'lab',
        source: source,
        cycle: last == null ? 'none' : null,
      ),
    ];
  }
}

/// HbA1c at least twice a year with diabetes (quarterly when not at goal).
class Hba1cRule extends ChronicLabRule {
  const Hba1cRule();

  @override
  String get id => 'lab.hba1c';
  @override
  Set<Condition> get conditions => const {Condition.diabetes};
  @override
  List<String> get keywords => const [
    'hba1c',
    'a1c',
    'glycated',
    'glycosylated',
    'تراكمي',
  ];
  @override
  int get months => 6;
  @override
  String get source => 'ADA Standards of Care 2025, §6';
  @override
  String title(AppLocalizations l) => l.fuHba1c;
}

/// A yearly lipid profile with diabetes, heart disease or high cholesterol.
class LipidProfileRule extends ChronicLabRule {
  const LipidProfileRule();

  @override
  String get id => 'lab.lipids';
  @override
  Set<Condition> get conditions => const {
    Condition.heart,
    Condition.highCholesterol,
    Condition.diabetes,
  };
  @override
  List<String> get keywords => const [
    'lipid',
    'cholesterol',
    'ldl',
    'hdl',
    'triglycerid',
    'كوليسترول',
    'كولسترول',
    'دهون',
  ];
  @override
  int get months => 12;
  @override
  String get source => 'WHO HEARTS 2020; ADA Standards of Care 2025, §10';
  @override
  String title(AppLocalizations l) => l.fuLipids;
}

/// Yearly kidney function and urine albumin with diabetes or high blood
/// pressure.
class KidneyCheckRule extends ChronicLabRule {
  const KidneyCheckRule();

  @override
  String get id => 'lab.kidney';
  @override
  Set<Condition> get conditions => const {
    Condition.diabetes,
    Condition.hypertension,
    Condition.kidney,
  };
  @override
  List<String> get keywords => const [
    'creatinin',
    'egfr',
    'albumin',
    'acr',
    'kidney',
    'renal',
    'urea',
    'كرياتينين',
    'كلي',
    'زلال',
    'بولينا',
  ];
  @override
  int get months => 12;
  @override
  String get source => 'ADA Standards of Care 2025, §11; KDIGO 2024';
  @override
  String title(AppLocalizations l) => l.fuKidney;
}

/// A scan whose result asks for a follow-up ("follow up in 3 months",
/// "متابعة بعد ٦ شهور"). Due after the months written, or six months.
/// Closed by a later scan of the same kind.
class ScanFollowUpRule extends FollowUpRule {
  const ScanFollowUpRule();

  @override
  String get id => 'scan';

  static const _words = [
    'follow up',
    'followup',
    'repeat',
    'متابعه',
    'اعاده',
    'تتعاد',
    'تكرار',
  ];

  /// "لا يحتاج متابعة", "no follow-up needed", "لا داعي للمتابعة"; a comma
  /// ends the phrase, so "no change, follow up in 6 months" still counts.
  static final _negated = RegExp(
    r'(^|\s)(no|not|without|لا|مش|بدون|غير)\s+([^\s,،.;؛]+\s+){0,2}'
    r'(ال|لل|و|ب)?(follow|repeat|متابع|اعاد|تكرار|تتعاد)',
  );
  static final _months = RegExp(r'(\d{1,2})\s*(months?|شهر|شهور|اشهر)');
  static final _weeks = RegExp(r'(\d{1,2})\s*(weeks?|اسبوع|اسابيع)');
  static const defaultMonths = 6;

  @override
  List<FollowUp> evaluate(FollowUpSubject subject, DateTime today) {
    final scans = subject.ofType('scan').toList();
    final out = <FollowUp>[];
    for (final s in scans) {
      final result = normalizeText('${s.data['result'] ?? ''}');
      if (!mentionsAny(result, _words) || _negated.hasMatch(result)) continue;
      final kind = s.data['kind'];
      final redone = scans.any(
        (o) =>
            o.data['kind'] == kind &&
            dayOf(o.event.occurredAt).isAfter(dayOf(s.event.occurredAt)),
      );
      if (redone) continue;
      final taken = s.event.occurredAt;
      final weeks = _weeks.firstMatch(result);
      final due = weeks != null
          ? DateTime(
              taken.year,
              taken.month,
              taken.day + 7 * int.parse(weeks.group(1)!),
            )
          : addMonths(
              taken,
              int.tryParse(_months.firstMatch(result)?.group(1) ?? '') ??
                  defaultMonths,
            );
      if (_stale(due, today)) continue;
      out.add(
        FollowUp(
          ruleId: '$id.${s.event.id}',
          profileId: subject.profile.id,
          dueOn: due,
          title: (c) => AppLocalizations.of(c).fuScan,
          reason: (c) => AppLocalizations.of(c).fuScanResult,
          recordType: 'scan',
        ),
      );
    }
    return out;
  }
}
