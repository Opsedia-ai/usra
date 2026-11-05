import '../../core/database/app_database.dart';
import '../../core/util/localized_numbers.dart';
import '../../l10n/app_localizations.dart';
import '../medicines/reminders.dart' show PlannedReminder;

/// "Next dose allowed after" (C8), only ever from a minimum interval the
/// family saved in the medicine's own instructions ("every 6 hours", "كل ٦
/// ساعات"). The app never proposes an interval or an amount: no
/// instructions, a range ("every 4 to 6 hours") or two different
/// intervals mean no time and no reminder.

/// The interval found in a medicine's instructions, and the words it was
/// read from, shown back to the family.
class MinimumInterval {
  const MinimumInterval(this.hours, this.phrase);

  final int hours;

  /// As written in the instructions.
  final String phrase;

  Duration get duration => Duration(hours: hours);

  @override
  bool operator ==(Object other) =>
      other is MinimumInterval &&
      other.hours == hours &&
      other.phrase == phrase;

  @override
  int get hashCode => Object.hash(hours, phrase);

  @override
  String toString() => 'MinimumInterval($hours, $phrase)';
}

/// Longer than this isn't a sick-day interval: likely a typo.
const _maxHours = 72;

const _englishWords = {
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'twelve': 12,
  'twenty-four': 24,
};

const _arabicWords = {
  'ثلاث': 3,
  'تلات': 3,
  'تلت': 3,
  'أربع': 4,
  'اربع': 4,
  'خمس': 5,
  'ست': 6,
  'ستة': 6,
  'سته': 6,
  'سبع': 7,
  'ثمان': 8,
  'ثماني': 8,
  'تمان': 8,
  'تماني': 8,
  'عشر': 10,
  'اتناشر': 12,
  'إتناشر': 12,
};

final _number = r'(\d{1,2}|[a-z-]+|[ء-ي]+)';

final _patterns = [
  // "every 6 hours", "every 6 hrs", "every 6h", "every six hours"
  RegExp(
    r'\bevery\s+' + _number + r'\s*(?:hours?|hrs?|h)\b',
    caseSensitive: false,
  ),
  // "q6h", "q 6 h"
  RegExp(r'\bq\s?(\d{1,2})\s?h\b', caseSensitive: false),
  // "6 hours apart"
  RegExp(r'\b(\d{1,2})\s*(?:hours?|hrs?)\s+apart\b', caseSensitive: false),
  // "كل ٦ ساعات", "كل 8 ساعة", "كل ست ساعات"
  RegExp(r'كل\s+' + _number + r'\s*(?:ساعات|ساعة|ساعه|س)(?![ء-ي])'),
  // "كل ساعتين"
  RegExp(r'كل\s+(ساعتين|ساعتان)'),
];

int? _hoursOf(String word) {
  final n = int.tryParse(word);
  if (n != null) return n;
  final w = word.toLowerCase();
  if (w == 'ساعتين' || w == 'ساعتان') return 2;
  return _englishWords[w] ?? _arabicWords[w];
}

/// The one minimum interval [instructions] state, or null when they state
/// none, a range, or more than one.
MinimumInterval? minimumIntervalIn(String? instructions) {
  if (instructions == null || instructions.trim().isEmpty) return null;
  final text = toWesternDigits(instructions);
  // A range is the doctor's choice to make, not the app's.
  if (RegExp(
    r'\d\s*(?:-|–|/|to|or|إلى|الى|لـ|ل|او|أو)\s*\d{1,2}\s*'
    r'(?:hours?|hrs?|h\b|ساع|س(?![ء-ي]))',
    caseSensitive: false,
  ).hasMatch(text)) {
    return null;
  }
  final found = <int, String>{};
  for (final p in _patterns) {
    for (final m in p.allMatches(text)) {
      final hours = _hoursOf(m.group(1)!);
      if (hours == null || hours < 1 || hours > _maxHours) continue;
      found.putIfAbsent(hours, () => instructions.substring(m.start, m.end));
    }
  }
  if (found.length != 1) return null;
  final e = found.entries.single;
  return MinimumInterval(e.key, e.value.trim());
}

/// When the next dose of [medicine] is allowed after [given], from its own
/// saved instructions; null when they state no single minimum interval.
DateTime? nextDoseAllowedAt(GivenMedicine given, Medicine? medicine) {
  if (medicine == null || given.medicineId != medicine.id) return null;
  final interval = minimumIntervalIn(medicine.instructions);
  return interval == null ? null : given.givenAt.add(interval.duration);
}

/// Next-dose reminders use ids from [nextDoseReminderIdBase] up to (not
/// including) the vaccine range at 900000.
const nextDoseReminderIdBase = 800000;
const _idRange = 100000;

/// A stable id for the reminder of one medicine given (FNV-1a).
int nextDoseReminderId(String givenId) {
  var hash = 0x811c9dc5;
  for (final unit in givenId.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return nextDoseReminderIdBase + hash % _idRange;
}

/// Notification text for next-dose reminders.
class NextDoseTexts {
  const NextDoseTexts(this.l, {required this.discreet});

  final AppLocalizations l;

  /// No person or medicine name, and no instructions: "A reminder from
  /// Usra".
  final bool discreet;

  String title(NextDoseSource s) => discreet
      ? l.nextDoseDiscreetTitle
      : l.nextDoseTitle(s.person.displayName, s.given.name);

  /// Facts only: the time noted and the family's own words. Never "give".
  String body(NextDoseSource s, MinimumInterval interval) =>
      discreet ? l.nextDoseDiscreetBody : l.nextDoseBody(interval.phrase);
}

/// One reminder per medicine per sick day, from the latest time it was
/// given, at the time its own instructions allow the next dose. Includes
/// times already passed (for rewriting notifications on screen); the
/// caller schedules only future ones. At most [max], soonest first.
List<PlannedReminder> planNextDoseReminders(
  List<NextDoseSource> sources, {
  required NextDoseTexts texts,
  required DateTime now,
  Duration keepPast = const Duration(days: 1),
  int max = 8,
}) {
  final latest = <(String, String), NextDoseSource>{};
  for (final s in sources) {
    final key = (s.episode.id, s.medicine.id);
    final seen = latest[key];
    if (seen == null || s.given.givenAt.isAfter(seen.given.givenAt)) {
      latest[key] = s;
    }
  }
  final out = <PlannedReminder>[];
  for (final s in latest.values) {
    final interval = minimumIntervalIn(s.medicine.instructions);
    if (interval == null) continue;
    final at = s.given.givenAt.add(interval.duration);
    if (at.isBefore(now.subtract(keepPast))) continue;
    out.add(
      PlannedReminder.nextDose(
        id: nextDoseReminderId(s.given.id),
        at: at,
        episodeId: s.episode.id,
        profileId: s.person.id,
        title: texts.title(s),
        body: texts.body(s, interval),
        locale: texts.l.localeName,
      ),
    );
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out.take(max).toList();
}

/// The reminders for [db]'s sick days now.
Future<List<PlannedReminder>> loadNextDoseReminders(
  AppDatabase db, {
  required DateTime now,
  required NextDoseTexts texts,
}) async => planNextDoseReminders(
  await db.watchNextDoseSources().first,
  texts: texts,
  now: now,
);
