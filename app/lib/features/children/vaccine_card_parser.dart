import '../../core/ocr/ocr_dates.dart';
import '../../core/ocr/ocr_rows.dart';
import '../../core/ocr/ocr_service.dart';
import '../../core/util/localized_numbers.dart';
import 'egypt_vaccines.dart';
import 'growth.dart' show addMonths;

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

  /// The same dose with its date marked for checking.
  CardDose marked() => CardDose(
    kinds: kinds,
    dose: dose,
    date: date,
    row: row,
    doseGuessed: doseGuessed,
    dateUnsure: true,
  );

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
  const VaccineCardScan({
    this.doses = const [],
    this.unknown = const [],
    this.futureRows = 0,
  });

  static const empty = VaccineCardScan();

  final List<CardDose> doses;
  final List<CardUnknownRow> unknown;

  /// Rows naming a vaccine whose every date is after today: next visits,
  /// not doses. Not ticked, but counted, so nothing goes unsaid.
  final int futureRows;

  bool get isEmpty => doses.isEmpty && unknown.isEmpty;
}

/// Reads a child's vaccination card, chiefly the Ministry of Health and
/// Population card: one row per visit, with the age ("عند الولادة",
/// "شهرين", "4 months"), the vaccines ("سابين + سولك + الخماسي", "OPV +
/// IPV + Penta"), sometimes the dose ("الجرعة الأولى"), the date given and
/// the next visit.
///
/// A row counts only with a date on it: printed vaccines with an empty
/// date column weren't given. The day given is the earliest date on the
/// row that isn't after [today] (an Arabic table puts the next visit to
/// the left, so reading order can't tell them apart); a row with more than
/// one date is marked. A row whose dates are all in the future is a next
/// visit, counted in [VaccineCardScan.futureRows].
///
/// The dose number comes from the words next to that vaccine ("OPV 5th"),
/// else from the one dose word on the row, else from the age on the row,
/// else (marked as guessed) from the order of that vaccine's dates. Dates
/// that don't fit (dose 2 before dose 1, a dose well before its age) are
/// marked. Combinations that aren't the Egyptian pentavalent or a
/// hexavalent ("Pentaxim", "Infanrix-IPV+Hib"), and DTP doses before 12
/// months (an infant dose, not the 18-month booster), are listed for the
/// person to say what they are.
class VaccineCardParser {
  const VaccineCardParser();

  /// A dose this long before its age on the schedule is marked.
  static const earlyDays = 60;

  VaccineCardScan parse(
    OcrResult ocr, {
    required DateTime today,
    DateTime? birthDate,
  }) {
    final end = DateTime(today.year, today.month, today.day);
    final found =
        <
          ({
            Set<VaccineKind> kinds,
            int? dose,
            int? age,
            DateTime date,
            String row,
            bool dateUnsure,
          })
        >[];
    final unknown = <CardUnknownRow>[];
    var futureRows = 0;
    for (final row in ocrRows(ocr)) {
      final dates = [
        for (final d in datesIn(row.text))
          if (!_birth.hasMatch(_plain(d.label))) d.date,
      ];
      if (dates.isEmpty) continue;
      final past = dates.where((d) => !d.isAfter(end)).toList()..sort();
      // The words of the row without its dates.
      var words = toWesternDigits(row.text);
      for (final m in _dateLike.allMatches(words).toList().reversed) {
        words = words.replaceRange(m.start, m.end, ' ');
      }
      final plain = _plain(words);
      final parts = partsIn(words);
      final shown = words.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (past.isEmpty) {
        if (parts.isNotEmpty || _otherCombo.hasMatch(plain)) futureRows++;
        continue;
      }
      final date = past.first;
      final dateUnsure = dates.length > 1;
      final combos = [
        for (final part in words.split(_separator))
          if (_otherCombo.hasMatch(_plain(part))) part.trim(),
      ];
      // About the child or the office, not a dose. A dose row may still
      // print its next visit ("next", "موعد").
      if (parts.isEmpty && combos.isEmpty && _label.hasMatch(plain)) continue;
      for (final c in combos) {
        unknown.add(CardUnknownRow(text: c, date: date));
      }
      if (parts.isEmpty) {
        if (combos.isNotEmpty) continue;
        unknown.add(
          CardUnknownRow(
            // Only a date: what was given is unknown.
            text: RegExp('[A-Za-zء-ي]{2}').hasMatch(shown) ? shown : '',
            date: date,
          ),
        );
        continue;
      }
      // One dose word for the whole row ("الجرعة الأولى" in its own column)
      // counts for every vaccine on it; several can't be shared out.
      final rowOrdinals = ordinalsIn(plain);
      final age = ageMonthsIn(plain);
      for (final part in parts) {
        final kinds = part.kinds;
        final primary = _primary(kinds);
        final own = ordinalsIn(_plain(part.text));
        final ordinal = own.length == 1
            ? own.single
            : own.isEmpty && rowOrdinals.length == 1
            ? rowOrdinals.single
            : null;
        int? dose;
        if (ordinal != null && _exists(primary, ordinal)) {
          dose = ordinal;
        } else if (age != null) {
          dose = _doseAtAge(primary, age);
        }
        found.add((
          kinds: kinds,
          dose: dose,
          age: age,
          date: date,
          row: shown,
          dateUnsure: dateUnsure,
        ));
      }
    }

    // A DTP-containing booster (DTP, or the fourth hexavalent) only from
    // 12 months: before that a DTP is an infant dose this schedule counts
    // under another vaccine.
    bool boosterAge(int? age, DateTime date) => age != null
        ? age >= 12
        : birthDate != null && !date.isBefore(addMonths(birthDate, 12));

    // Doses the card didn't number: the n-th date of a vaccine is its n-th
    // dose not already accounted for.
    final doses = <String, CardDose>{};
    final taken = <VaccineKind, Set<int>>{};
    for (final f in found) {
      if (f.dose != null) (taken[_primary(f.kinds)] ??= {}).add(f.dose!);
    }
    final unnumbered = [
      for (final f in found)
        if (f.dose == null) f,
    ]..sort((a, b) => a.date.compareTo(b.date));
    void add(CardDose d, int? age) {
      if ((d.key == 'dtp-1' || d.key == 'hexa-4') && !boosterAge(age, d.date)) {
        unknown.add(CardUnknownRow(text: d.row, date: d.date));
        return;
      }
      final had = doses[d.key];
      if (had == null) {
        doses[d.key] = d;
      } else if (had.date != d.date) {
        // The same dose twice with different dates: ask.
        doses[d.key] = had.marked();
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
        f.age,
      );
    }
    for (final f in unnumbered) {
      final k = _primary(f.kinds);
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
        f.age,
      );
    }

    // Dates that don't fit: a later dose dated before an earlier one, or a
    // dose given well before its age on the schedule.
    final byKind = <VaccineKind, List<CardDose>>{};
    for (final d in doses.values) {
      (byKind[d.kind] ??= []).add(d);
    }
    for (final series in byKind.values) {
      series.sort((a, b) => a.dose.compareTo(b.dose));
      for (var i = 0; i < series.length; i++) {
        final d = series[i];
        var odd = i > 0 && d.date.isBefore(series[i - 1].date);
        if (i + 1 < series.length && series[i + 1].date.isBefore(d.date)) {
          odd = true;
        }
        final scheduled = _all.where((s) => s.key == d.key).firstOrNull;
        if (birthDate != null &&
            scheduled != null &&
            d.date.isBefore(
              addMonths(
                birthDate,
                scheduled.ageMonths,
              ).subtract(const Duration(days: earlyDays)),
            )) {
          odd = true;
        }
        if (odd) doses[d.key] = d.marked();
      }
    }

    final list = doses.values.toList()
      ..sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return VaccineCardScan(
      doses: list,
      unknown: unknown,
      futureRows: futureRows,
    );
  }

  static VaccineKind _primary(Set<VaccineKind> kinds) =>
      kinds.contains(VaccineKind.hexa) ? VaccineKind.hexa : kinds.first;

  /// Every vaccine named on a row, with the words around it ("OPV 5th
  /// dose"): one per `+`-separated part. A hexavalent shot is one part of
  /// three kinds. Combinations that aren't on the Egyptian schedule
  /// ("Pentaxim") are left out: see [parse].
  static List<({Set<VaccineKind> kinds, String text})> partsIn(String row) {
    final parts = <({Set<VaccineKind> kinds, String text})>[];
    final seen = <VaccineKind>{};
    for (final part in row.split(_separator)) {
      if (_otherCombo.hasMatch(_plain(part))) continue;
      final kinds = vaccineKindsOf(part);
      if (kinds.isEmpty || kinds.every(seen.contains)) continue;
      seen.addAll(kinds);
      parts.add((kinds: kinds, text: part));
    }
    return parts;
  }

  /// Every vaccine named on a row, one group per vaccine.
  static List<Set<VaccineKind>> kindsIn(String row) => [
    for (final p in partsIn(row)) p.kinds,
  ];

  /// The dose the card names: "الجرعة الصفرية" 0, "الأولى" / "1st" 1, and so
  /// on; null when it doesn't (or names several).
  static int? ordinalIn(String plain) {
    final all = ordinalsIn(plain);
    return all.length == 1 ? all.single : null;
  }

  /// Every dose number named in [plain].
  static Set<int> ordinalsIn(String plain) => {
    for (final (n, pattern) in _ordinals)
      if (pattern.hasMatch(plain)) n,
  };

  /// DTaP combinations that aren't the government pentavalent (which has
  /// hepatitis B) or a full hexavalent: counting them as either would mark
  /// antigens given that weren't.
  static final _otherCombo = RegExp(
    r'pentaxim|tetraxim|tetravac|infanrix(?! ?hexa)|pediacel|pentacel|'
    r'quadracel|kinrix|repevax|boostrix|adacel|بنتاكسيم|تتراكسيم',
  );

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
    // "2 سنه", "4 years": that many years ("4 6 years" is the last number).
    final years = RegExp(
      r'(?<![\d.])(\d{1,2}) ?(سنه|سنين|سنوات|عام|اعوام|years?|y\b)',
    ).firstMatch(plain);
    if (years != null) return 12 * int.parse(years[1]!);
    if (RegExp(r'(سنه|سنة|عام|year)(?! ?و)').hasMatch(plain)) return 12;
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
    (0, RegExp(r'صفريه|الصفريه|صفر(?![ء-ي])|zero|\b0 dose|dose 0')),
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
