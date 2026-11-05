import '../../core/ocr/ocr_dates.dart';
import '../../core/ocr/ocr_rows.dart';
import '../../core/ocr/ocr_service.dart';
import '../../core/util/localized_numbers.dart';
import 'egypt_vaccines.dart';

/// One dose read from a vaccination card: which vaccine (a hexavalent shot
/// stands for pentavalent and IPV too, as in [vaccineKindsOf]), which dose
/// as the card counts it, and the day it was given. A suggestion: every one
/// is confirmed by the person before it's saved.
class CardDose {
  const CardDose({
    required this.kinds,
    required this.dose,
    required this.date,
    required this.row,
    this.doseGuessed = false,
    this.dateUnsure = false,
  });

  final Set<VaccineKind> kinds;
  final int dose;
  final DateTime date;

  /// The card's row as read, to show next to the suggestion.
  final String row;

  /// The card didn't say which dose (no "first", no age): the dose number
  /// comes from the order of the dates.
  final bool doseGuessed;

  /// The row had more than one date, or the same dose was read twice with
  /// different dates.
  final bool dateUnsure;

  /// The vaccine that names the dose: the hexavalent shot when it's one.
  VaccineKind get kind =>
      kinds.contains(VaccineKind.hexa) ? VaccineKind.hexa : kinds.first;

  String get key => '${kind.name}-$dose';

  @override
  String toString() =>
      'CardDose($key $kinds ${date.toIso8601String().substring(0, 10)}'
      '${doseGuessed ? ' guessed' : ''}${dateUnsure ? ' date?' : ''})';
}

/// A dated row whose vaccine wasn't recognised (often Arabic the phone
/// can't read, or a brand it doesn't know): listed for the person to say
/// which dose it is, or to skip.
class CardUnknownRow {
  const CardUnknownRow({required this.text, required this.date});

  final String text;
  final DateTime date;

  @override
  String toString() =>
      'CardUnknownRow($text | ${date.toIso8601String().substring(0, 10)})';
}

class VaccineCardScan {
  const VaccineCardScan({this.doses = const [], this.unknown = const []});

  static const empty = VaccineCardScan();

  final List<CardDose> doses;
  final List<CardUnknownRow> unknown;

  bool get isEmpty => doses.isEmpty && unknown.isEmpty;
}

/// Reads a child's vaccination card, chiefly the Ministry of Health and
/// Population card: one row per visit, with the age ("عند الولادة",
/// "شهرين", "4 months"), the vaccines ("سابين + سولك + الخماسي", "OPV +
/// IPV + Penta"), sometimes the dose ("الجرعة الأولى"), and the date given.
///
/// A row counts only with a date on it: printed vaccines with an empty
/// date column weren't given. The first date on a row is the day given;
/// later ones are usually the next visit. Dates after [today] are next
/// visits, not doses. The dose number comes from the card's words
/// ("الصفرية", "الثانية", "2nd"), else from the age on the row, else (marked
/// as guessed) from the order of that vaccine's dates.
class VaccineCardParser {
  const VaccineCardParser();

  VaccineCardScan parse(OcrResult ocr, {required DateTime today}) {
    final end = DateTime(today.year, today.month, today.day);
    final found =
        <
          ({
            Set<VaccineKind> kinds,
            int? dose,
            DateTime date,
            String row,
            bool dateUnsure,
          })
        >[];
    final unknown = <CardUnknownRow>[];
    for (final row in ocrRows(ocr)) {
      final dates = [
        for (final d in datesIn(row.text))
          if (!_birth.hasMatch(_plain(d.label))) d,
      ];
      if (dates.isEmpty) continue;
      final date = dates.first.date;
      if (date.isAfter(end)) continue;
      // The words of the row without its dates.
      var words = toWesternDigits(row.text);
      for (final m in _dateLike.allMatches(words).toList().reversed) {
        words = words.replaceRange(m.start, m.end, ' ');
      }
      final plain = _plain(words);
      if (_label.hasMatch(plain)) continue;
      final groups = kindsIn(words);
      final shown = words.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (groups.isEmpty) {
        if (RegExp('[A-Za-zء-ي]{2}').hasMatch(shown)) {
          unknown.add(CardUnknownRow(text: shown, date: date));
        } else {
          // Only a date: what was given is unknown.
          unknown.add(CardUnknownRow(text: '', date: date));
        }
        continue;
      }
      final ordinal = ordinalIn(plain);
      final age = ageMonthsIn(plain);
      for (final kinds in groups) {
        final primary = kinds.contains(VaccineKind.hexa)
            ? VaccineKind.hexa
            : kinds.first;
        int? dose;
        if (ordinal != null && _exists(primary, ordinal)) {
          dose = ordinal;
        } else if (age != null) {
          dose = _doseAtAge(primary, age);
        }
        found.add((
          kinds: kinds,
          dose: dose,
          date: date,
          row: shown,
          dateUnsure: dates.length > 1,
        ));
      }
    }

    // Doses the card didn't number: the n-th date of a vaccine is its n-th
    // dose not already accounted for.
    final doses = <String, CardDose>{};
    final taken = <VaccineKind, Set<int>>{};
    for (final f in found) {
      if (f.dose != null) {
        final k = f.kinds.contains(VaccineKind.hexa)
            ? VaccineKind.hexa
            : f.kinds.first;
        (taken[k] ??= {}).add(f.dose!);
      }
    }
    final unnumbered = [
      for (final f in found)
        if (f.dose == null) f,
    ]..sort((a, b) => a.date.compareTo(b.date));
    void add(CardDose d) {
      final had = doses[d.key];
      if (had == null) {
        doses[d.key] = d;
      } else if (had.date != d.date) {
        // The same dose twice with different dates: ask.
        doses[d.key] = CardDose(
          kinds: had.kinds,
          dose: had.dose,
          date: had.date,
          row: had.row,
          doseGuessed: had.doseGuessed,
          dateUnsure: true,
        );
      }
    }

    for (final f in found) {
      if (f.dose == null) continue;
      add(
        CardDose(
          kinds: f.kinds,
          dose: f.dose!,
          date: f.date,
          row: f.row,
          dateUnsure: f.dateUnsure,
        ),
      );
    }
    for (final f in unnumbered) {
      final k = f.kinds.contains(VaccineKind.hexa)
          ? VaccineKind.hexa
          : f.kinds.first;
      final used = taken[k] ??= {};
      final next = _series(k).where((n) => !used.contains(n)).firstOrNull;
      if (next == null) continue;
      used.add(next);
      add(
        CardDose(
          kinds: f.kinds,
          dose: next,
          date: f.date,
          row: f.row,
          doseGuessed: true,
          dateUnsure: f.dateUnsure,
        ),
      );
    }
    final list = doses.values.toList()
      ..sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return VaccineCardScan(doses: list, unknown: unknown);
  }

  /// Every vaccine named on a row, one group per vaccine ("سابين + سولك +
  /// الخماسي" is three). A hexavalent shot is one group of three kinds.
  static List<Set<VaccineKind>> kindsIn(String row) {
    final groups = <Set<VaccineKind>>[];
    final seen = <VaccineKind>{};
    for (final part in row.split(_separator)) {
      final kinds = vaccineKindsOf(part);
      if (kinds.isEmpty || kinds.every(seen.contains)) continue;
      seen.addAll(kinds);
      groups.add(kinds);
    }
    return groups;
  }

  /// The dose the card names: "الجرعة الصفرية" 0, "الأولى" / "1st" 1, and so
  /// on; null when it doesn't.
  static int? ordinalIn(String plain) {
    for (final (n, pattern) in _ordinals) {
      if (pattern.hasMatch(plain)) return n;
    }
    return null;
  }

  /// The age on the row in months: "عند الولادة" 0, "شهرين" 2, "4 شهور" 4,
  /// "سنة" 12, "سنة ونصف" 18; null when none.
  static int? ageMonthsIn(String plain) {
    if (RegExp(r'ولاده|الولاده|birth|newborn|حديث الولاده').hasMatch(plain)) {
      return 0;
    }
    if (RegExp(r'اسبوع|الاسبوع|week|الشهر الاول|first month|24 ساعه')
        .hasMatch(plain)) {
      return 0;
    }
    if (RegExp(
      r'(سنه|سنة|عام) و ?(نص|نصف)|(?<![\d.])1\.5 ?(years?|y|سنه)|(?<![\d.])18 ?(شهر|months?|m\b)',
    ).hasMatch(plain)) {
      return 18;
    }
    if (RegExp(r'شهرين|(?<![\d.])2 ?(شهر|شهور|اشهر|months?)').hasMatch(plain)) {
      return 2;
    }
    final m = RegExp(r'(?<![\d.])(\d{1,2}) ?(شهر|شهور|اشهر|months?|mo?\b)')
        .firstMatch(plain);
    if (m != null) return int.parse(m[1]!);
    if (RegExp(r'(?<![\d.])(سنه|سنة|عام|year|1 ?(سنه|year))(?! ?و)')
        .hasMatch(plain)) {
      return 12;
    }
    return null;
  }

  static final _all = {
    for (final r in VaccineRoute.values)
      for (final d in egyptSchedule(r)) d.key: d,
  }.values.toList();

  static bool _exists(VaccineKind kind, int dose) =>
      _all.any((d) => d.kind == kind && d.dose == dose);

  static int? _doseAtAge(VaccineKind kind, int months) => _all
      .where((d) => d.kind == kind && d.ageMonths == months)
      .firstOrNull
      ?.dose;

  static List<int> _series(VaccineKind kind) => ([
    for (final d in _all)
      if (d.kind == kind) d.dose,
  ]..sort());

  static String _plain(String raw) =>
      normalizeVaccineName(toWesternDigits(raw))
          .replaceAll(RegExp(r'\s+'), ' ');

  static final _separator = RegExp(r'\+|&|،|,|\||\s{2,}|\s+و\s+|\s+and\s+');

  static final _dateLike = RegExp(
    r'\d{1,4}\s*[/.\-]\s*\d{1,2}\s*[/.\-]\s*\d{2,4}',
  );

  static final _birth = RegExp(
    r'date of birth|birth ?date|\bdob\b|d\.o\.b|تاريخ الميلاد|ميلاد ?:|مواليد',
  );

  /// Rows about the child or the office, not a dose.
  static final _label = RegExp(
    r'تاريخ الميلاد|date of birth|dob|الاسم|اسم الطفل|name|الرقم القومي|national|'
    r'مكتب|office|العنوان|address|تليفون|phone|موعد|next|التاليه|القادمه',
  );

  // Checked in order, after [normalizeVaccineName] (ة → ه, أ → ا, ى → ي).
  static final _ordinals = <(int, RegExp)>[
    (0, RegExp(r'صفريه|الصفريه|صفر\b|zero|\b0 dose|dose 0')),
    (1, RegExp(r'الاولي|اولي|\b1st\b|\bfirst\b|dose 1\b|جرعه 1\b')),
    (2, RegExp(r'الثانيه|ثانيه|التانيه|\b2nd\b|\bsecond\b|dose 2\b|جرعه 2\b')),
    (3, RegExp(r'الثالثه|ثالثه|التالته|\b3rd\b|\bthird\b|dose 3\b|جرعه 3\b')),
    (4, RegExp(r'الرابعه|رابعه|\b4th\b|\bfourth\b|dose 4\b|جرعه 4\b')),
    (5, RegExp(r'الخامسه|خامسه|\b5th\b|\bfifth\b|dose 5\b|جرعه 5\b')),
    (6, RegExp(r'السادسه|سادسه|\b6th\b|\bsixth\b|dose 6\b|جرعه 6\b')),
  ];
}

/// The checklist doses a card dose stands for, among [scheduleKeys] (the
/// child's schedule): a hexavalent shot is the hexavalent dose on that
/// route, else the pentavalent and IPV doses; a DTP booster and the
/// hexavalent booster stand in for each other. Empty when the schedule
/// has no such dose: the person says which it is.
List<String> cardDoseKeys(CardDose d, Iterable<String> scheduleKeys) {
  final keys = scheduleKeys.toSet();
  String key(VaccineKind k, int n) => '${k.name}-$n';
  if (d.kinds.contains(VaccineKind.hexa)) {
    if (keys.contains(d.key)) return [d.key];
    if (d.dose == 4 && keys.contains(key(VaccineKind.dtp, 1))) {
      return [key(VaccineKind.dtp, 1)];
    }
    return [
      for (final k in const [VaccineKind.penta, VaccineKind.ipv])
        if (keys.contains(key(k, d.dose))) key(k, d.dose),
    ];
  }
  if (keys.contains(d.key)) return [d.key];
  if (d.kind == VaccineKind.dtp && keys.contains(key(VaccineKind.hexa, 4))) {
    return [key(VaccineKind.hexa, 4)];
  }
  return const [];
}
