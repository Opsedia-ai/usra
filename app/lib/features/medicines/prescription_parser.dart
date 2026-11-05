import 'dart:math' as math;

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
    this.unsure = const {},
  });

  final String name;
  final String? strength;
  final String dose;
  final int? timesPerDay;
  final int? everyHours;
  final int? days;

  /// The name is in the bundled list of medicines sold in Egypt.
  final bool known;
  final Set<RxField> unsure;

  @override
  String toString() =>
      'RxCandidate($name | ${strength ?? '-'} | $dose | '
      '${timesPerDay ?? '-'}/day | q${everyHours ?? '-'}h | '
      '${days ?? '-'} days | $unsure)';
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
    for (var i = 0; i < rows.length; i++) {
      final head = _medicineRow(rows[i]);
      if (head == null) {
        if (_looksLikeMedicine(rows[i].text)) skippedUnsure = true;
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
      final unsure = {...c.unsure};
      for (var j = i + 1; j < rows.length && j <= i + 2; j++) {
        final next = rows[j];
        if (_medicineRow(next) != null || _isLabel(next.text)) break;
        if (!_isInstruction(next.text)) break;
        if ((next.confidence ?? 1) < unsureBelow) {
          // Read badly: left for the person to type.
          unsure.add(RxField.dose);
          break;
        }
        dose.add(next.text.replaceAll(RegExp(r'\s{2,}'), ' ').trim());
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

    final known = names?.knownIn(rest) ?? const <String>[];
    String name;
    var nameEnd = 0;
    final unsure = <RxField>{};
    var isKnown = false;
    if (known.isNotEmpty) {
      name = known.first;
      // Matched only as a near spelling ("Augrnentin"). Without the
      // recogniser's confidence (iOS) that may be handwriting read as a
      // name: never suggested then.
      if (!rest.toLowerCase().contains(name.toLowerCase()) &&
          confidence == null) {
        return (null, true);
      }
      final at = rest.toLowerCase().indexOf(name.toLowerCase());
      if (at >= 0 && at <= 3) {
        nameEnd = at + name.length;
      } else {
        // Matched despite an OCR slip, or not at the start: the leading
        // Latin words are taken as where the name was printed.
        final lead = _leadingName.firstMatch(rest);
        if (lead == null) return null;
        nameEnd = lead.end;
        unsure.add(RxField.name);
      }
      isKnown = true;
      if ((confidence ?? 1) < unsureBelow) return (null, true);
      if ((confidence ?? 1) < unknownNameBelow) unsure.add(RxField.name);
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
      // Only lines laid out like a medicine: a form before it, or a
      // strength right after it.
      if (!formBefore && !strengthNext) return null;
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
      strength = MedicineNameExtractor.strengthIn(s[0]!);
      if (strength != null) {
        after = after.trimLeft().substring(s.end);
        if (RegExp('[oOlI]').hasMatch(s[0]!.replaceAll(_unitWord, ''))) {
          unsure.add(RxField.strength);
        }
      }
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
        unsure: unsure,
      ),
      false,
    );
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
    final times = timesPerDayIn(dose);
    final hours = everyHoursIn(dose);
    var perDay = times;
    int? every = hours;
    if (perDay != null && every != null && perDay * every != 24) {
      // "1x3 every 6 hours": the paper disagrees with itself.
      perDay = null;
      every = null;
      unsure.add(RxField.times);
    } else if (every != null) {
      perDay = null;
    }
    if (perDay == null && every == null && _conflictingTimes(dose)) {
      unsure.add(RxField.times);
    }
    final days = daysIn(dose);
    if (dose.isEmpty) unsure.add(RxField.dose);
    return RxCandidate(
      name: c.name,
      strength: c.strength,
      dose: dose,
      timesPerDay: perDay,
      everyHours: every,
      days: days,
      known: c.known,
      unsure: unsure,
    );
  }

  // ---- Frequency and course length, only when printed plainly ----

  static String _plain(String raw) =>
      toWesternDigits(raw)
          .toLowerCase()
          .replaceAll(RegExp('[ً-ْـ]'), '')
          .replaceAll(RegExp('[أإآ]'), 'ا')
          .replaceAll('ى', 'ي')
          .replaceAll('ة', 'ه')
          .replaceAll('×', 'x')
          .replaceAll(RegExp(r'\s+'), ' ');

  static final _weekly = RegExp(r'week|weekly|اسبوع|الاسبوع|اسبوعيا');
  static final _asNeeded = RegExp(
    r'\b(prn|sos|as needed|when needed|if needed)\b|عند اللزوم|عند الحاجه|وقت اللزوم',
  );

  static List<int> _timesFound(String raw) {
    final t = _plain(raw);
    final found = <int>[];
    // "1x3", "½x2": one (or part of one), so many times a day. "2x3" could
    // be read either way round, so it isn't used.
    for (final m in RegExp(
      r'(?<![\d.])(1|½|¼|1/2|1/4|0\.5)\s*x\s*([1-4])(?![\d.])',
    ).allMatches(t)) {
      // Not "x 5 days" or "1 x 2 weeks".
      final tail = t.substring(m.end);
      if (RegExp(r'^\s*(days?|d\b|يوم|ايام|weeks?|اسابيع)').hasMatch(tail)) {
        continue;
      }
      found.add(int.parse(m[2]!));
    }
    final perDay = r'(a|per|/|in a|each)?\s*(day|daily)';
    void add(String pattern, int n) {
      for (final m in RegExp(pattern).allMatches(t)) {
        final near = t.substring(m.end, math.min(t.length, m.end + 14));
        if (_weekly.hasMatch(near)) continue;
        found.add(n);
      }
    }

    add('\\bonce\\s*$perDay', 1);
    add('\\b(twice|two times)\\s*$perDay?', 2);
    add('\\b(thrice|three times)\\s*$perDay?', 3);
    add('\\bfour times\\s*$perDay?', 4);
    for (final m in RegExp(
      r'(?<![\d.])([1-6])\s*times?\s*' + perDay,
    ).allMatches(t)) {
      found.add(int.parse(m[1]!));
    }
    add(r'\b(o\.?d\.?|q\.?d\.?)(?![a-z])', 1);
    add(r'\b(b\.?i\.?d\.?|b\.?d\.?)(?![a-z])', 2);
    add(r'\b(t\.?i\.?d\.?|t\.?d\.?s\.?)(?![a-z])', 3);
    add(r'\b(q\.?i\.?d\.?|q\.?d\.?s\.?)(?![a-z])', 4);
    // Arabic: "مرة يوميا", "مرتين في اليوم", "٣ مرات يوميا", "تلات مرات".
    const daily = r'(يوميا|يومي|في اليوم|فى اليوم|باليوم|كل يوم|في النهار)';
    add(r'مره (واحده )?' + daily, 1);
    add(r'مرتين', 2);
    add(r'(?<![\d])([3]|ثلاث|تلات|ثلاثه|تلاته) مرات', 3);
    add(r'(?<![\d])([4]|اربع|اربعه) مرات', 4);
    for (final m in RegExp(r'(?<![\d.])([1256]) مرات').allMatches(t)) {
      final near = t.substring(m.end, math.min(t.length, m.end + 14));
      if (!_weekly.hasMatch(near)) found.add(int.parse(m[1]!));
    }
    if (_asNeeded.hasMatch(t)) found.add(-1);
    return found;
  }

  /// How many times a day the paper says, when it says it once and
  /// plainly; null otherwise ("as needed", "once weekly", two answers).
  static int? timesPerDayIn(String dose) {
    final found = _timesFound(dose).toSet();
    if (found.length != 1 || found.single < 1) return null;
    return found.single;
  }

  static bool _conflictingTimes(String dose) =>
      _timesFound(dose).toSet().length > 1;

  /// "every 8 hours", "q8h", "كل ٨ ساعات": the interval, when it's one the
  /// form offers (4, 6, 8 or 12 hours).
  static int? everyHoursIn(String dose) {
    final t = _plain(dose);
    final found = <int>{
      for (final m in RegExp(
        r'(?:every|each|كل)\s*(\d{1,2})\s*(?:hours?|hrs?|h\b|ساعات|ساعه)',
      ).allMatches(t))
        int.parse(m[1]!),
      for (final m in RegExp(
        r'\bq\s*(\d{1,2})\s*h(?:rs?|ours?)?\b',
      ).allMatches(t))
        int.parse(m[1]!),
    };
    if (found.length != 1) return null;
    const offered = [4, 6, 8, 12];
    return offered.contains(found.single) ? found.single : null;
  }

  /// How many days the course lasts, when printed: "for 7 days", "x 5
  /// days", "لمدة ٥ أيام", "لمدة أسبوع", "2 weeks". Null when not printed,
  /// printed twice differently, or "for a month" (how long is that?).
  static int? daysIn(String dose) {
    final t = _plain(dose);
    final found = <int>{};
    for (final m in RegExp(
      r'(?<![\d.])(\d{1,3})\s*(?:days?|d\b|يوم(?!ي)|ايام)',
    ).allMatches(t)) {
      found.add(int.parse(m[1]!));
    }
    for (final m in RegExp(
      r'(?<![\d.])(\d)\s*(?:weeks?|wks?|اسابيع|اسبوع)',
    ).allMatches(t)) {
      found.add(7 * int.parse(m[1]!));
    }
    final preamble = r'(?:for|x|لمده|مده|لمدت)\s*(?:a|one|1)?\s*';
    if (RegExp(preamble + r'(?:week|اسبوع)(?!ين)').hasMatch(t) &&
        !RegExp(r'\d\s*(?:weeks?|اسابيع|اسبوع)').hasMatch(t)) {
      found.add(7);
    }
    if (RegExp(r'اسبوعين').hasMatch(t)) found.add(14);
    if (found.length != 1) return null;
    final n = found.single;
    return n >= 1 && n <= maxScannedDays ? n : null;
  }

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

  static final _instructionWords = RegExp(
    r'\b(take|tab|tabs|tablet|cap|caps|capsule|drop|drops|spoon|ml|puff|'
    r'puffs|times?|daily|day|days|week|weeks|hours?|hrs?|every|before|after|'
    r'with|meals?|food|breakfast|lunch|dinner|bedtime|night|morning|once|'
    r'twice|thrice|od|bid|tid|qid|tds|prn|sos|for|apply|inhale|sachet)\b|'
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
