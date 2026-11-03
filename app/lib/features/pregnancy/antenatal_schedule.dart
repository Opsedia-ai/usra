import '../../core/follow_ups/follow_up.dart';
import '../../l10n/app_localizations.dart';
import '../follow_ups/conditions.dart' show mentionsAny;
import 'pregnancy.dart';

/// What an antenatal item is, and the record that shows it was done.
enum AncKind {
  contact('visit'),
  scan('scan'),
  lab('lab');

  const AncKind(this.recordType);

  final String recordType;
}

/// One visit, scan or test in pregnancy, by pregnancy week.
///
/// It counts as done when a matching record falls between [fromWeek] and
/// the end of [toWeek]; it is due at the start of [week].
class AncItem {
  const AncItem(
    this.id,
    this.kind, {
    required this.fromWeek,
    required this.week,
    required this.toWeek,
    this.keywords = const [],
  });

  final String id;
  final AncKind kind;
  final int fromWeek;
  final int week;
  final int toWeek;

  /// For tests: words (normalized, see `normalizeText`) of which one must
  /// start a word of the lab record's test name. Empty means any lab counts.
  final List<String> keywords;

  /// Days after the due day before it's overdue: to the end of [toWeek].
  int get graceDays => (toWeek - week) * 7 + 6;

  String get source => kind == AncKind.contact
      ? 'WHO antenatal care recommendations 2016'
      : 'Common practice in Egypt';
}

/// WHO's 2016 model: at least eight contacts, at weeks 12, 20, 26, 30, 34,
/// 36, 38 and 40; plus the scans and tests usually asked for in Egypt.
const ancSchedule = [
  AncItem('contact1', AncKind.contact, fromWeek: 0, week: 12, toWeek: 16),
  // Blood count, blood group and Rh, urine, sugar, hepatitis B and C.
  AncItem('bookingLabs', AncKind.lab, fromWeek: 0, week: 12, toWeek: 16),
  // Dating and nuchal translucency scan.
  AncItem('firstScan', AncKind.scan, fromWeek: 11, week: 12, toWeek: 14),
  AncItem('contact2', AncKind.contact, fromWeek: 17, week: 20, toWeek: 23),
  AncItem('anomalyScan', AncKind.scan, fromWeek: 18, week: 20, toWeek: 22),
  AncItem(
    'glucoseTest',
    AncKind.lab,
    fromWeek: 24,
    week: 24,
    toWeek: 28,
    keywords: ['سكر', 'منحني', 'glucose', 'sugar', 'ogtt', 'gtt'],
  ),
  AncItem('contact3', AncKind.contact, fromWeek: 24, week: 26, toWeek: 27),
  AncItem(
    'bloodCount',
    AncKind.lab,
    fromWeek: 26,
    week: 28,
    toWeek: 30,
    keywords: [
      'صوره دم',
      'هيموجلوبين',
      'cbc',
      'hemoglobin',
      'haemoglobin',
      'blood count',
    ],
  ),
  AncItem('contact4', AncKind.contact, fromWeek: 28, week: 30, toWeek: 31),
  AncItem('growthScan', AncKind.scan, fromWeek: 30, week: 32, toWeek: 36),
  AncItem('contact5', AncKind.contact, fromWeek: 32, week: 34, toWeek: 34),
  AncItem('contact6', AncKind.contact, fromWeek: 35, week: 36, toWeek: 36),
  AncItem('contact7', AncKind.contact, fromWeek: 37, week: 38, toWeek: 38),
  AncItem('contact8', AncKind.contact, fromWeek: 39, week: 40, toWeek: 41),
];

/// Where one item stands in a pregnancy.
enum AncState { done, missed, open }

typedef AncStatus = ({AncItem item, AncState state, DateTime dueOn});

/// Whether [r] shows that [item] was done during [pregnancy].
bool _matches(AncItem item, SubjectRecord r, Pregnancy pregnancy) {
  if (r.event.type != item.kind.recordType) return false;
  final day = pregnancy.daysOn(r.event.occurredAt);
  if (day < item.fromWeek * 7 || day >= (item.toWeek + 1) * 7) return false;
  return switch (item.kind) {
    AncKind.contact => true,
    AncKind.scan => switch (r.data['kind']) {
      null || 'ultrasound' || 'other' => true,
      _ => false,
    },
    AncKind.lab =>
      item.keywords.isEmpty ||
          mentionsAny('${r.data['test'] ?? ''}', item.keywords),
  };
}

/// Every item of the schedule for [pregnancy]: done, missed (its window
/// closed with no record) or open.
List<AncStatus> ancStatuses(
  Pregnancy pregnancy,
  Iterable<SubjectRecord> records,
  DateTime today,
) {
  final records_ = records.toList();
  final day = pregnancy.daysOn(today);
  return [
    for (final item in ancSchedule)
      (
        item: item,
        dueOn: pregnancy.weekStart(item.week),
        state: records_.any((r) => _matches(item, r, pregnancy))
            ? AncState.done
            : day >= (item.toWeek + 1) * 7
            ? AncState.missed
            : AncState.open,
      ),
  ];
}

/// Antenatal visits, scans and tests coming up in the next four weeks, or
/// overdue by up to two weeks after their window closed. Older ones are
/// dropped: the next visit is what matters then.
class AncScheduleRule extends FollowUpRule {
  const AncScheduleRule();

  static const horizonDays = 28;
  static const staleDays = 14;

  @override
  String get id => 'pregnancy.anc';

  @override
  List<FollowUp> evaluate(FollowUpSubject subject, DateTime today) {
    if (!canBePregnant(subject.profile, today)) return const [];
    final pregnancy = activePregnancy(subject.records, today);
    if (pregnancy == null) return const [];
    final day = pregnancy.daysOn(today);
    return [
      for (final s in ancStatuses(pregnancy, subject.records, today))
        if (s.state != AncState.done &&
            s.dueOn.difference(dayOf(today)).inDays <= horizonDays &&
            day < (s.item.toWeek + 1) * 7 + staleDays)
          FollowUp(
            ruleId: '$id.${s.item.id}',
            profileId: subject.profile.id,
            dueOn: s.dueOn,
            title: (c) => ancTitle(AppLocalizations.of(c), s.item),
            reason: (c) => ancReason(AppLocalizations.of(c), s.item),
            recordType: s.item.kind.recordType,
            source: s.item.source,
            graceDays: s.item.graceDays,
          ),
    ];
  }
}

String ancTitle(AppLocalizations l, AncItem item) => switch (item.id) {
  'bookingLabs' => l.ancBookingLabs,
  'firstScan' => l.ancFirstScan,
  'anomalyScan' => l.ancAnomalyScan,
  'glucoseTest' => l.ancGlucoseTest,
  'bloodCount' => l.ancBloodCount,
  'growthScan' => l.ancGrowthScan,
  _ => l.ancContact(int.parse(item.id.substring('contact'.length))),
};

String ancReason(AppLocalizations l, AncItem item) => switch (item.kind) {
  AncKind.contact => l.ancContactReason(item.week),
  _ => l.ancWindow(item.fromWeek, item.toWeek),
};
