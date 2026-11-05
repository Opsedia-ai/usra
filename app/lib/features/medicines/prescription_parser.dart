import '../../core/ocr/medicine_name_extractor.dart';
import '../../core/ocr/ocr_dates.dart';
import '../../core/ocr/ocr_rows.dart';
import '../../core/ocr/ocr_service.dart';
import '../../core/util/localized_numbers.dart';

/// Parts of a medicine read from a prescription the person should look at
/// twice before confirming it.
enum RxField { name, strength, dose, times, days }

/// One medicine line read from a prescription photo: a suggestion, never
/// saved until the person has checked it against the paper.
///
/// [dose] is the text as the phone read it, word for word ("1x3 بعد
/// الأكل"); nothing in it is worked out or filled in. [timesPerDay],
/// [everyHours] and [days] are set only when the paper says so plainly
/// ("1x3", "مرتين يوميا", "every 8 hours", "لمدة ٥ أيام").
class RxCandidate {
  const RxCandidate({
    required this.name,
    this.strength,
    this.dose = '',
    this.timesPerDay,
    this.everyHours,
    this.days,
    this.known = false,
    this.suggestedName,
    this.unsure = const {},
  });

  /// As read from the paper, never swapped for a listed name.
  final String name;
  final String? strength;
  final String dose;
  final int? timesPerDay;
  final int? everyHours;
  final int? days;

  /// The name is in the bundled list of medicines sold in Egypt.
  final bool known;

  /// A listed name close to what was read ("Augrnentin" → "Augmentin"),
  /// offered as "Did you mean …?"; never filled in by itself, since look-
  /// alike names in the list can be very different medicines.
  final String? suggestedName;
  final Set<RxField> unsure;

  @override
  String toString() =>
      'RxCandidate($name | ${strength ?? '-'} | $dose | '
      '${timesPerDay ?? '-'}/day | q${everyHours ?? '-'}h | '
      '${days ?? '-'} days | ${suggestedName ?? ''} | $unsure)';
}

/// What a prescription photo gave. Every part is a suggestion.
class PrescriptionScan {
  const PrescriptionScan({
    this.items = const [],
    this.doctor,
    this.date,
    this.unclear = false,
  });

  static const empty = PrescriptionScan();

  final List<RxCandidate> items;

  /// The doctor's name as printed at the top ("Dr. Ahmed Samir", "د/ أحمد
  /// سمير"), title included.
  final String? doctor;
  final DateTime? date;

  /// The medicines look handwritten or the phone wasn't sure of them:
  /// nothing was filled in, so the person types them from the photo.
  final bool unclear;
}

/// Reads an Egyptian prescription: the doctor and date printed at the top,
/// then one medicine per line ("1- Augmentin 1g tab  1x2 for 7 days"), the
/// instructions often on the next line, in English or Arabic.
///
/// It is careful rather than clever. A line counts as a medicine only if
/// its name is in the bundled list, or it is laid out like a medicine
/// (a form such as "Tab." or a strength such as "500mg" next to a Latin
/// name). When the recogniser says it wasn't sure (handwriting), nothing
/// is suggested: the photo is kept and the person types. A dose is never
/// made up, worked out or tidied: [RxCandidate.dose] is what was read.
class PrescriptionParser {
  const PrescriptionParser([this.names]);

  /// Known medicine names, to tell a medicine line from the rest; without
  /// it only lines laid out like a medicine are read.
  final MedicineNameExtractor? names;

  /// The longest course read from a paper; longer is more likely a misread.
  static const maxScannedDays = 365;

  /// Below this, a line is too unsure to suggest from (handwriting).
  static const unsureBelow = 0.6;

  /// A name not in the list is only suggested when the recogniser was at
  /// least this sure of it (or didn't say).
  static const unknownNameBelow = 0.8;

  PrescriptionScan parse(OcrResult ocr) {
    final rows = ocrRows(ocr);
    if (rows.isEmpty) return PrescriptionScan.empty;
    final texts = [for (final r in rows) r.text];
    final doctor = _doctor(texts);
    final date = _date(texts);

    // Mostly unsure lines: a handwritten page. Suggest no medicines at all.
    final confidences = [
      for (final l in ocr.lines)
        if (l.text.trim().isNotEmpty) ?l.confidence,
    ]..sort();
    if (confidences.length >= 3 &&
        confidences[confidences.length ~/ 2] < unsureBelow) {
      return PrescriptionScan(doctor: doctor, date: date, unclear: true);
    }

    final items = <RxCandidate>[];
    // Lines read unsurely (handwriting under a printed letterhead): if no
    // medicine was read, the page is unclear, not empty.
    var skippedUnsure = confidences.where((c) => c < unsureBelow).length >= 2;
    // Two listed names on one row (two columns read as one line): each
    // starts its own row, and what goes with which is marked.
    final split = <(OcrRow, bool)>[for (final r in rows) ..._splitAtNames(r)];
    for (var i = 0; i < split.length; i++) {
      final (row, wasSplit) = split[i];
      final head = _medicineRow(row);
      if (head == null) {
        if (_looksLikeMedicine(row.text)) skippedUnsure = true;
        continue;
      }
      if (head.$2) {
        // Laid out like a medicine, but too unsure to say which.
        skippedUnsure = true;
        continue;
      }
      var c = head.$1!;
      // Instructions on the lines under it, until the next medicine.
      final dose = [if (c.dose.isNotEmpty) c.dose];
      final unsure = {...c.unsure, if (wasSplit) RxField.dose};
      for (var j = i + 1; j < split.length && j <= i + 2; j++) {
        final next = split[j].$1;
        if (_startsNewItem(next.text) ||
            _medicineRow(next) != null ||
            _isLabel(next.text)) {
          break;
        }
        if (!_isInstruction(next.text)) break;
        if ((next.confidence ?? 1) < unsureBelow) {
          // Read badly: left for the person to type.
          unsure.add(RxField.dose);
          break;
        }
        dose.add(next.text.replaceAll(RegExp(r'\s{2,}'), ' ').trim());
        // Which lines belong to which medicine is the phone's guess.
        unsure.add(RxField.dose);
        i = j;
      }
      final text = dose.join(' ');
      c = _withInstructions(c, text, unsure);
      items.add(c);
    }
    return PrescriptionScan(
      items: items,
      doctor: doctor,
      date: date,
      unclear: items.isEmpty && skippedUnsure,
    );
  }

  /// The medicine on [row], or null if it isn't one. A row that looks
  /// like one but was read too unsurely gives (null, true).
  (RxCandidate?, bool)? _medicineRow(OcrRow row) {
    final raw = row.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (raw.isEmpty || _isLabel(raw)) return null;
    final confidence = row.confidence;
    // Bullet ("1-", "2)", "•", "R/") and form ("Tab.", "شراب") before the
    // name.
    var rest = raw.replaceFirst(_bullet, '');
    var formBefore = false;
    while (true) {
      final m = _formPrefix.firstMatch(rest);
      if (m == null) break;
      rest = rest.substring(m.end);
      formBefore = true;
    }
    rest = rest.trimLeft();
    final numbered = _numbered.hasMatch(raw);

    final known = names?.knownIn(rest) ?? const <String>[];
    final exact = _namesAt(rest);
    String name;
    var nameEnd = 0;
    final unsure = <RxField>{};
    var isKnown = false;
    String? suggested;
    if (exact.isNotEmpty) {
      // The listed name printed first on the row.
      final first = exact.first;
      name = first.name;
      nameEnd = first.end;
      if (first.start > 3) unsure.add(RxField.name);
      isKnown = true;
      if ((confidence ?? 1) < unsureBelow) return (null, true);
      if ((confidence ?? 1) < unknownNameBelow) unsure.add(RxField.name);
    } else if (known.isNotEmpty) {
      // Only a near spelling of a listed name ("Augrnentin"). Without the
      // recogniser's confidence (iOS) that may be handwriting: nothing is
      // suggested. Otherwise the text stays as read, the listed name is
      // only offered: look-alikes in the list are different medicines.
      if (confidence == null || confidence < unknownNameBelow) {
        return (null, true);
      }
      final lead = _leadingName.firstMatch(rest);
      if (lead == null) return null;
      final words = lead[0]!.trim().split(' ');
      while (words.length > 1 &&
          _formWords.contains(words.last.toLowerCase())) {
        words.removeLast();
      }
      name = words.join(' ');
      nameEnd = rest.indexOf(name) + name.length;
      suggested = known.first;
      unsure.add(RxField.name);
    } else {
      final lead = _leadingName.firstMatch(rest);
      if (lead == null) return null;
      final words = lead[0]!.trim().split(' ');
      // Drop a form word at the end ("Flotac caps").
      while (words.length > 1 &&
          _formWords.contains(words.last.toLowerCase())) {
        words.removeLast();
      }
      name = words.join(' ');
      nameEnd =
          lead.start + rest.substring(lead.start).indexOf(name) + name.length;
      if (name.replaceAll(RegExp('[^A-Za-z]'), '').length < 4) return null;
      if (_formWords.contains(words.first.toLowerCase()) ||
          _notNames.contains(words.first.toLowerCase())) {
        return null;
      }
      final after = rest.substring(nameEnd);
      final strengthNext = _strengthAtStart.hasMatch(
        after.replaceFirst(_formAfter, '').trimLeft(),
      );
      final formNext = _formAfter.hasMatch(after);
      // Only lines laid out like a medicine: numbered, a form before or
      // after it, or a strength right after it.
      if (!formBefore && !strengthNext && !formNext && !numbered) return null;
      if ((confidence ?? 1) < unknownNameBelow) return (null, true);
      unsure.add(RxField.name);
      if (name == name.toUpperCase()) {
        name = words.map((w) => w[0] + w.substring(1).toLowerCase()).join(' ');
      }
    }

    // Strength right after the name, then the form ("1g tab").
    var after = rest.substring(nameEnd);
    after = after.replaceFirst(_formAfter, '');
    String? strength;
    final s = _strengthAtStart.firstMatch(after.trimLeft());
    if (s != null) {
      final token = s[0]!.trim();
      if (RegExp('[oOlI]').hasMatch(token.replaceAll(_unitWord, ''))) {
        // A letter where a digit should be ("l000mg"): kept as read, never
        // cut down to something that looks right ("000mg").
        strength = token;
        unsure.add(RxField.strength);
      } else {
        strength = MedicineNameExtractor.strengthIn(token);
      }
      if (strength != null) after = after.trimLeft().substring(s.end);
    }
    after = after.replaceFirst(_formAfter, '');
    final dose = after
        .replaceFirst(RegExp(r'^[\s\-–:,.()/]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (row.loose) unsure.addAll({RxField.name, RxField.dose});
    return (
      RxCandidate(
        name: name.trim(),
        strength: strength,
        dose: dose,
        known: isKnown,
        suggestedName: suggested,
        unsure: unsure,
      ),
      false,
    );
  }

  /// Listed names printed on [text] as they are spelled, first first.
  List<({int start, int end, String name})> _namesAt(String text) {
    final found = <({int start, int end, String name})>[];
    for (final n in names?.knownIn(text) ?? const <String>[]) {
      final m = RegExp(
        '(?<![A-Za-z])${RegExp.escape(n)}(?![A-Za-z])',
        caseSensitive: false,
      ).firstMatch(text);
      if (m != null) found.add((start: m.start, end: m.end, name: n));
    }
    return found..sort((a, b) => a.start.compareTo(b.start));
  }

  /// [row] cut before each listed name after the first one; the pieces
  /// are marked as split.
  List<(OcrRow, bool)> _splitAtNames(OcrRow row) {
    final at = _namesAt(row.text);
    if (at.length < 2 || _isLabel(row.text)) return [(row, false)];
    final cuts = <int>[];
    var end = at.first.end;
    for (final n in at.skip(1)) {
      if (n.start < end) continue;
      cuts.add(n.start);
      end = n.end;
    }
    if (cuts.isEmpty) return [(row, false)];
    final bounds = [0, ...cuts, row.text.length];
    return [
      for (var k = 0; k + 1 < bounds.length; k++)
        (
          OcrRow(
            row.text.substring(bounds[k], bounds[k + 1]).trim(),
            loose: row.loose,
            confidence: row.confidence,
          ),
          true,
        ),
    ];
  }

  /// A numbered line ("2- Zisrocin", "3) Tab ..."): a new medicine.
  static final _numbered = RegExp(
    r'^\s*(?:\d{1,2}|[٠-٩]{1,2})\s*(?:[-)]|\.(?![\d٠-٩]))\s*(?=[A-Za-z؀-ۿ])',
  );

  /// A line that starts another medicine rather than going on with the
  /// last one's instructions: numbered, or a Latin name (after a form
  /// word) that isn't an instruction word.
  static bool _startsNewItem(String text) {
    if (_numbered.hasMatch(text)) return true;
    var t = text.trimLeft().replaceFirst(RegExp(r'^[-•*·>]+\s*'), '');
    while (true) {
      final m = _formPrefix.firstMatch(t);
      if (m == null) break;
      t = t.substring(m.end);
    }
    final w = RegExp(r'^[A-Za-z][A-Za-z\-]{2,}').firstMatch(t.trimLeft());
    if (w == null) return false;
    return !RegExp(
      '^(${_instructionList.join('|')})\$',
      caseSensitive: false,
    ).hasMatch(w[0]!);
  }

  /// A row with a Latin word and a strength, or a form word: maybe a
  /// medicine the phone couldn't read well enough.
  static bool _looksLikeMedicine(String text) =>
      _formPrefix.hasMatch(text.replaceFirst(_bullet, '')) ||
      (_leadingName.hasMatch(text) &&
          MedicineNameExtractor.strengthIn(text) != null);

  RxCandidate _withInstructions(
    RxCandidate c,
    String dose,
    Set<RxField> unsure,
  ) {
    final f = frequencyIn(dose);
    final d = durationIn(dose);
    if (f.unsure) unsure.add(RxField.times);
    if (d.unsure) unsure.add(RxField.days);
    if (dose.isEmpty) unsure.add(RxField.dose);
    return RxCandidate(
      name: c.name,
      strength: c.strength,
      dose: dose,
      timesPerDay: f.perDay,
      everyHours: f.everyHours,
      days: d.days,
      known: c.known,
      suggestedName: c.suggestedName,
      unsure: unsure,
    );
  }

  // ---- How often and how long: only from a short list of plain forms ----
  //
  // A value is read only when the text says it in one of the forms below
  // and in nothing else. Any other wording about how often or how long
  // ("twice a month", "every other day", "1 drop OD", "weekly", "then")
  // leaves the value empty and marks it for the person.

  static String _plain(String raw) =>
      toWesternDigits(raw)
          .toLowerCase()
          .replaceAll(RegExp('[ً-ْـ]'), '')
          .replaceAll(RegExp('[أإآ]'), 'ا')
          .replaceAll('ى', 'ي')
          .replaceAll('ة', 'ه')
          .replaceAll('×', 'x')
          .replaceAll(RegExp(r'\s+'), ' ');

  static const _daily =
      r'(?:daily|a day|per day|/ ?day|each day|every day|in a day|'
      r'يوميا|يومي|في اليوم|فى اليوم|باليوم|(?<![ء-ي])كل يوم|في النهار)';

  /// "1x3", "½x2" (one, or part of one, so many times a day). "2x3" could
  /// be read either way round, so it isn't one of them.
  static final _xTimes = RegExp(
    r'(?<![\d.])(?:1|½|¼|1/2|1/4|0\.5)\s*x\s*([1-4])(?![\d.])'
    r'(?!\s*(?:days?|d\b|يوم|ايام|weeks?|wks?|اسابيع|اسبوع|months?|شهر))'
    '(?:\\s*$_daily)?',
  );

  static final _perDayWords = <(RegExp, int?)>[
    (RegExp('\\b(?:once|one time)\\s*$_daily'), 1),
    (RegExp('\\b(?:twice|two times)\\s*$_daily'), 2),
    (RegExp('\\b(?:thrice|three times)\\s*$_daily'), 3),
    (RegExp('\\bfour times\\s*$_daily'), 4),
    (RegExp('(?<![\\d.])([1-6])\\s*times?\\s*$_daily'), null),
    (RegExp(r'\b(?:b\.?i\.?d|b\.i\.d\.)(?![a-z])\.?'), 2),
    (RegExp(r'\b(?:t\.?i\.?d|t\.?d\.?s)(?![a-z])\.?'), 3),
    (RegExp(r'\b(?:q\.?i\.?d|q\.?d\.?s)(?![a-z])\.?'), 4),
    (RegExp('مره (?:واحده )?$_daily'), 1),
    (RegExp('مرتين $_daily'), 2),
    (RegExp('(?<![\\d])(?:3|ثلاث|تلات|ثلاثه|تلاته) مرات $_daily'), 3),
    (RegExp('(?<![\\d])(?:4|اربع|اربعه) مرات $_daily'), 4),
    (RegExp('(?<![\\d.])([1256]) مرات $_daily'), null),
  ];

  static final _hoursForms = [
    RegExp(
      r'(?:every|each|(?<![ء-ي])كل)\s*(\d{1,2})\s*(?:hours?|hrs?|h\b|ساعات|ساعه)',
    ),
    RegExp(r'\bq\s*(\d{1,2})\s*h(?:rs?|ours?)?\b'),
  ];

  static final _asNeeded = RegExp(
    r'\b(?:prn|sos|as needed|when needed|if needed|when required)\b|'
    r'عند اللزوم|عند الحاجه|وقت اللزوم',
  );

  /// Words about how often that none of the plain forms took: "twice"
  /// alone, "OD" (once daily, or the right eye?), "weekly", "every other".
  static final _oftenWords = RegExp(
    r'\b(?:once|twice|thrice|times?|daily|od|o\.d|qd|q\.d|bd|b\.d|qod|q\.o\.d|'
    r'hs|nocte|mane|weekly|monthly|yearly|every|each|alternate|other)\b|'
    r'\d\s*x\s*\d|(?<![ء-ي])(?:مره|مرتين|مرات|يوميا|يومي|كل|اسبوعيا|شهريا|'
    r'يوم بعد يوم|يوم ويوم)(?![ء-ي])',
  );

  static String _blank(String t, Match m) =>
      t.replaceRange(m.start, m.end, ' ' * (m.end - m.start));

  /// How often the paper says, when it says it once, plainly. Otherwise
  /// nothing, marked [unsure] when there was wording about it.
  static ({int? perDay, int? everyHours, bool unsure}) frequencyIn(
    String dose,
  ) {
    var t = _plain(dose);
    final perDay = <int>{};
    final hours = <int>{};
    void take(RegExp r, void Function(Match) found) {
      for (final m in r.allMatches(t).toList().reversed) {
        found(m);
        t = _blank(t, m);
      }
    }

    take(_xTimes, (m) => perDay.add(int.parse(m[1]!)));
    for (final (r, n) in _perDayWords) {
      take(r, (m) => perDay.add(n ?? int.parse(m[1]!)));
    }
    for (final r in _hoursForms) {
      take(r, (m) => hours.add(int.parse(m[1]!)));
    }
    var asNeeded = false;
    take(_asNeeded, (_) => asNeeded = true);
    final leftOver = _oftenWords.hasMatch(t);
    const none = (perDay: null, everyHours: null, unsure: false);
    if (perDay.isEmpty && hours.isEmpty) {
      return leftOver ? (perDay: null, everyHours: null, unsure: true) : none;
    }
    const offered = [4, 6, 8, 12];
    final agree =
        perDay.length <= 1 &&
        hours.length <= 1 &&
        (perDay.isEmpty || hours.isEmpty || perDay.single * hours.single == 24);
    if (leftOver || asNeeded || !agree) {
      return (perDay: null, everyHours: null, unsure: true);
    }
    if (hours.isNotEmpty) {
      return offered.contains(hours.single)
          ? (perDay: null, everyHours: hours.single, unsure: false)
          : (perDay: null, everyHours: null, unsure: true);
    }
    return (perDay: perDay.single, everyHours: null, unsure: false);
  }

  /// How many times a day, when printed plainly; null otherwise.
  static int? timesPerDayIn(String dose) => frequencyIn(dose).perDay;

  /// "every 8 hours", "q8h", "كل ٨ ساعات", when it's an interval the form
  /// offers (4, 6, 8 or 12 hours) and nothing else on the text disagrees.
  static int? everyHoursIn(String dose) => frequencyIn(dose).everyHours;

  static const _for = r'(?:for|x|لمده|مده|لمدت|duration:?)\s*';

  static final _dayForms = <(RegExp, int Function(Match))>[
    (
      RegExp('$_for(\\d{1,3})\\s*(?:days?|d\\b|يوم(?!ي)|ايام)'),
      (m) => int.parse(m[1]!),
    ),
    (
      RegExp('$_for(\\d)\\s*(?:weeks?|wks?|اسابيع|اسبوع(?!ي))'),
      (m) => 7 * int.parse(m[1]!),
    ),
    (RegExp('$_forاسبوعين'), (_) => 14),
    (
      RegExp(
        '(?:for|لمده|مده|لمدت)\\s*(?:a |one |1 )?(?:week|اسبوع)(?!ين|ي|s)',
      ),
      (_) => 7,
    ),
  ];

  /// Wording that makes a course length unsafe to read: a dose that
  /// changes ("then"), or a dose repeated on some days ("weekly", "every
  /// 7 days", "every other day").
  static final _notACourse = RegExp(
    r'\b(?:then|after that|followed by|weekly|monthly|alternate|qod|'
    r'every other)\b|(?:every|each|(?<![ء-ي])كل)\s*\d*\s*(?:days?|weeks?|months?|يوم|ايام|اسبوع|شهر)|'
    r'ثم|بعدين|بعد كده|بعد ذلك|اسبوعيا|شهريا|يوم بعد يوم|يوم ويوم',
  );

  static final _lengthWords = RegExp(
    r'\b(?:days?|weeks?|wks?|months?|years?)\b|ايام|يوم(?!ي)|اسبوع|اسابيع|شهر|سنه',
  );

  /// How many days the course lasts, when printed plainly ("for 7 days",
  /// "x 5 days", "لمدة ٥ أيام", "لمدة أسبوع"). Otherwise nothing, marked
  /// [unsure] when there was wording about it.
  static ({int? days, bool unsure}) durationIn(String dose) {
    var t = _plain(dose);
    final unsafe = _notACourse.hasMatch(t);
    final found = <int>{};
    for (final (r, value) in _dayForms) {
      for (final m in r.allMatches(t).toList().reversed) {
        found.add(value(m));
        t = _blank(t, m);
      }
    }
    final leftOver = _lengthWords.hasMatch(t);
    if (unsafe) return (days: null, unsure: found.isNotEmpty || leftOver);
    if (found.isEmpty) return (days: null, unsure: leftOver);
    if (found.length > 1 || leftOver) return (days: null, unsure: true);
    final n = found.single;
    return n >= 1 && n <= maxScannedDays
        ? (days: n, unsure: false)
        : (days: null, unsure: true);
  }

  /// How many days the course lasts, when printed plainly; null otherwise.
  static int? daysIn(String dose) => durationIn(dose).days;

  // ---- The header: doctor and date ----

  static final _doctorTitle = RegExp(
    r'(?:^|\s|\b)(prof(?![a-z])\.?\s*(?:dr(?![a-z])\.?)?|dr(?![a-z])\.?|doctor(?![a-z])|'
    r'[اأ]\s*\.\s*د\s*[/.]?|د\s*[/.]|دكتور[ةه]?|الدكتور[ةه]?|الطبيب[ةه]?)'
    r'\s*[/:.]?\s*',
    caseSensitive: false,
  );
  static final _notNameWord = RegExp(
    r'^(consultant|specialist|lecturer|professor|of|md|m\.?b\.?b\.?ch|'
    r'phd|ph\.d|msc|استشاري|اخصائي|أخصائي|مدرس|استاذ|أستاذ|زميل|ماجستير|دكتوراه|'
    r'كليه|كلية|جامعه|جامعة|طب|عياده|عيادة)',
    caseSensitive: false,
  );

  /// The doctor's name as printed, with its title ("Dr. Ahmed Samir").
  static String? _doctor(List<String> rows) {
    for (final raw in rows.take(10)) {
      for (final cell in raw.split(RegExp(r'\s{2,}'))) {
        final m = _doctorTitle.firstMatch(cell);
        if (m == null) continue;
        final words = cell
            .substring(m.end)
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .toList();
        final name = <String>[];
        for (final w in words) {
          if (_notNameWord.hasMatch(w) || RegExp(r'[\d:@/|]').hasMatch(w)) {
            break;
          }
          if (!RegExp(r'^[A-Za-zء-ي.\-]+$').hasMatch(w) ||
              !RegExp('[A-Za-zء-ي]').hasMatch(w)) {
            break;
          }
          name.add(w);
          if (name.length == 4) break;
        }
        while (name.isNotEmpty && name.last.replaceAll('.', '').isEmpty) {
          name.removeLast();
        }
        if (name.isEmpty || name.join().replaceAll('.', '').length < 3) {
          continue;
        }
        final arabic = RegExp(r'[؀-ۿ]').hasMatch(name.first);
        return '${arabic ? 'د.' : 'Dr.'} ${name.join(' ')}';
      }
    }
    return null;
  }

  static final _dateLabel = RegExp(r'date|تاريخ|التاريخ', caseSensitive: false);
  static final _birthLabel = RegExp(
    r'birth|dob|ميلاد|الميلاد|next|follow|اعاده|إعادة|الاعاده|العوده',
    caseSensitive: false,
  );

  /// The prescription's date: one labelled as the date, else the first one
  /// that isn't a birth date or the next visit.
  static DateTime? _date(List<String> rows) {
    DateTime? first;
    for (final row in rows) {
      for (final d in datesIn(row)) {
        if (_birthLabel.hasMatch(d.label)) continue;
        if (_dateLabel.hasMatch(d.label)) return d.date;
        first ??= d.date;
      }
    }
    return first;
  }

  // ---- What a line is ----

  static final _label = RegExp(
    r'\b(tel|tele|phone|mob|mobile|fax|address|clinic|clinics|hospital|'
    r'signature|e-?mail|www|patient|name|age|date|diagnosis|next visit|'
    r'follow\s*up|consultant|specialist|appointments?|saturday|'
    r'sunday|daily from)\b|'
    r'تليفون|ت\s*[:/]|موبايل|محمول|العنوان|عياده|عيادة|مستشفى|مستشفي|'
    r'الاسم|اسم المريض|السن|التاريخ|تاريخ|التشخيص|الاعاده|الإعادة|اعاده|'
    r'توقيع|مواعيد|المواعيد|يوميا من|استشاري|أخصائي|اخصائي',
    caseSensitive: false,
  );

  static bool _isLabel(String text) {
    final t = toWesternDigits(text);
    if (RegExp(r'\d{8,}|\d{3,4}[\s-]\d{3,4}[\s-]\d{3,4}').hasMatch(t)) {
      return true;
    }
    if (_doctorTitle.hasMatch(t) &&
        RegExp(
          r'^\s*(prof|dr|doctor|[اأ]\s*\.\s*د|د\s*[/.]|دكتور|الدكتور)',
          caseSensitive: false,
        ).hasMatch(t.replaceFirst(_bullet, ''))) {
      return true;
    }
    if (datesIn(t).isNotEmpty && !_isInstruction(t)) return true;
    return _label.hasMatch(t);
  }

  static const _instructionList = [
    'take',
    'tab',
    'tabs',
    'tablet',
    'tablets',
    'cap',
    'caps',
    'capsule',
    'drop',
    'drops',
    'spoon',
    'ml',
    'puff',
    'puffs',
    'time',
    'times',
    'daily',
    'day',
    'days',
    'week',
    'weeks',
    'hour',
    'hours',
    'hrs',
    'every',
    'each',
    'before',
    'after',
    'with',
    'meal',
    'meals',
    'food',
    'breakfast',
    'lunch',
    'dinner',
    'bedtime',
    'night',
    'morning',
    'evening',
    'once',
    'twice',
    'thrice',
    'od',
    'bid',
    'tid',
    'qid',
    'tds',
    'prn',
    'sos',
    'for',
    'apply',
    'inhale',
    'sachet',
    'then',
    'until',
    'when',
    'needed',
    'as',
    'one',
    'two',
    'half',
    'dissolve',
    'chew',
    'spray',
    'puff',
    'into',
    'on',
    'in',
    'at',
    'if',
    'do',
    'not',
    'stop',
  ];

  static final _instructionWords = RegExp(
    '\\b(${_instructionList.join('|')})\\b|'
    r'\d\s*[x×]\s*\d|'
    r'[؀-ۿ]',
    caseSensitive: false,
  );

  static bool _isInstruction(String text) => _instructionWords.hasMatch(text);

  static final _bullet = RegExp(
    r'^\s*(?:(?:\d{1,2}|[٠-٩]{1,2})\s*[-.)\]/]+|[-•*·>]+|r\s*/|rx\.?|℞)\s*',
    caseSensitive: false,
  );

  static const _formWords = {
    'tab',
    'tabs',
    'tablet',
    'tablets',
    'cap',
    'caps',
    'capsule',
    'capsules',
    'syrup',
    'syr',
    'syp',
    'susp',
    'suspension',
    'amp',
    'amps',
    'ampoule',
    'ampoules',
    'inj',
    'injection',
    'vial',
    'supp',
    'supps',
    'suppository',
    'suppositories',
    'drops',
    'drop',
    'cream',
    'oint',
    'ointment',
    'gel',
    'spray',
    'sachet',
    'sachets',
    'eff',
    'effervescent',
    'lotion',
    'inhaler',
    'eye',
    'ear',
    'nasal',
    'oral',
  };

  // Words a line can start with that aren't medicine names.
  static const _notNames = {
    'take',
    'apply',
    'before',
    'after',
    'every',
    'once',
    'twice',
    'for',
    'with',
    'the',
    'and',
    'then',
    'stop',
    'repeat',
    'signature',
    'patient',
    'name',
  };

  static final _formPrefix = RegExp(
    r'^\s*(?:tabs?|tablets?|caps?|capsules?|syrup|syr|syp|susp|suspension|'
    r'amps?|ampoules?|inj|injection|vial|supps?|suppositor(?:y|ies)|drops?|'
    r'cream|oint|ointment|gel|spray|sachets?|eff|effervescent|lotion|'
    r'inhaler|eye\s*drops?|ear\s*drops?|nasal\s*(?:drops?|spray)|'
    r'أقراص|اقراص|قرص|شراب|كبسول(?:ه|ة)?|كبسولات|حقن|حقنه|حقنة|أمبول|امبول|'
    r'لبوس|نقط|نقطه|مرهم|كريم|جل|فوار|أكياس|اكياس|كيس|بخاخ)'
    r'(?:\s*\.|\s*:|\b|(?=\s))\s*',
    caseSensitive: false,
  );

  static final _formAfter = RegExp(
    r'^\s*(?:(?:eye|ear|nasal|oral)\s*(?:drops?|spray|gel|susp)|'
    r'tabs?|tablets?|caps?|capsules?|syrup|syr|syp|susp|amps?|'
    r'ampoules?|inj|vial|supps?|drops?|cream|oint|ointment|gel|spray|'
    r'sachets?|eff|f\.?c\.?|s\.?r\.?|x\.?r\.?|retard|forte)\b\.?',
    caseSensitive: false,
  );

  /// One to three Latin words at the start: where a name is printed.
  static final _leadingName = RegExp(
    r"^[A-Za-z][A-Za-z\-&+']*(?:\s+[A-Za-z][A-Za-z\-&+']*){0,2}",
  );

  static final _unitWord = RegExp(
    r'(mg|mcg|µg|ug|grams?|gm|g|ml|i\.?u\.?|%)',
    caseSensitive: false,
  );

  static final _strengthAtStart = RegExp(
    r'^[\dOolI]*\d[\dOolI]*(?:[.,]\d+)*(?:\s*/\s*\d+(?:[.,]\d+)*)?\s*'
    r'(?:mg|mcg|µg|ug|grams?|gm|g|ml|i\.?u\.?|%)'
    r'(?:\s*/\s*(?:\d+(?:[.,]\d+)?)?\s*(?:ml|g|mg))?(?![a-z])',
    caseSensitive: false,
  );
}

/// A doctor's name without titles, Arabic letters in one form, lower case:
/// "Dr. Ahmed Samir" and "ahmed samir" compare equal, as do "د/ أحمد" and
/// "دكتور احمد".
String bareDoctorName(String name) => toWesternDigits(name)
    .toLowerCase()
    .replaceAll(RegExp('[ً-ْـ]'), '')
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه')
    .replaceAll(RegExp(r'[./:\-,()]'), ' ')
    .split(RegExp(r'\s+'))
    .where(
      (w) =>
          w.isNotEmpty &&
          !const {
            'dr',
            'doctor',
            'prof',
            'د',
            'ا',
            'دكتور',
            'دكتوره',
            'الدكتور',
            'الدكتوره',
          }.contains(w),
    )
    .join(' ');

/// Whether a doctor saved as [saved] is the one printed as [printed]: the
/// same name, or one is the other plus more names ("Ahmed Samir" and
/// "Ahmed Samir Mostafa"), with at least two names in common.
bool sameDoctorName(String saved, String printed) {
  final a = bareDoctorName(saved).split(' ');
  final b = bareDoctorName(printed).split(' ');
  if (a.join().isEmpty || b.join().isEmpty) return false;
  final short = a.length <= b.length ? a : b;
  final long = a.length <= b.length ? b : a;
  if (short.length < 2 && a.length != b.length) return false;
  for (var i = 0; i < short.length; i++) {
    if (short[i] != long[i]) return false;
  }
  return true;
}
