import 'dart:math' as math;

import '../../core/ocr/ocr_service.dart';
import '../../core/util/localized_numbers.dart';
import 'lab_report.dart';
import 'lab_tests.dart';

/// Parts of a read result the person should check before saving.
enum LabField { name, value, unit, range }

/// One result read from a photo: a suggestion, never saved until the
/// person has checked it. [unsure] lists what the phone wasn't sure of.
class LabCandidate {
  const LabCandidate({
    required this.name,
    required this.value,
    this.unit,
    this.range = '',
    this.ranges = const [],
    this.unsure = const {},
  });

  final String name;

  /// As read: a number, or text like "<0.5".
  final String value;
  final String? unit;

  /// The printed range as printed ("4 - 11", "< 200"), or '' when none was
  /// found or when several were ([ranges]).
  final String range;

  /// Every range printed on the row, when there was more than one (by age,
  /// sex or level): the person picks the one that applies. Empty otherwise.
  final List<String> ranges;
  final Set<LabField> unsure;

  /// Same test, same result, same unit: the same row read twice.
  String get identity =>
      '${labSeriesKey(name)}|${value.trim()}|${labUnitKey(unit)}';

  @override
  String toString() =>
      'LabCandidate($name | $value | ${unit ?? '-'} | $range $ranges | '
      '$unsure)';
}

/// What a photo of a report gave: the results found, and the date, lab and
/// doctor when printed. Every part is a suggestion.
class LabScan {
  const LabScan({this.tests = const [], this.date, this.lab, this.orderedBy});

  static const empty = LabScan();

  final List<LabCandidate> tests;
  final DateTime? date;
  final String? lab;
  final String? orderedBy;

  bool get isEmpty => tests.isEmpty;
}

/// A row of the page put back together: its text, cells two spaces apart,
/// and whether its cells sat loosely (more than half a line's height apart
/// up and down, once the tilt is undone), which can mean cells from two
/// rows were joined.
class LabRow {
  const LabRow(this.text, {this.loose = false});

  final String text;
  final bool loose;
}

/// Turns the text of a lab report photo into result rows.
///
/// Reports from Egyptian labs print a table (test, result, unit, reference
/// range) in English, often with Arabic headers. The recogniser reads it
/// in blocks that may be whole columns, so lines are first put back into
/// rows by where they sit on the page, after undoing the photo's tilt. A
/// row becomes a result only if it has a name and a number; everything
/// uncertain is marked for checking. Printed High/Low marks are ignored:
/// the app works the flag out from the printed range itself.
class LabReportParser {
  const LabReportParser();

  LabScan parse(OcrResult ocr) {
    final rows = rowsOf(ocr);
    final texts = [for (final r in rows) r.text];
    final tests = <LabCandidate>[];
    final seen = <String>{};
    for (final row in rows) {
      final c = parseRow(row.text, loose: row.loose);
      // The same row read twice (overlapping blocks) counts once.
      if (c != null && seen.add(c.identity)) tests.add(c);
    }
    return LabScan(
      tests: tests,
      date: _date(texts),
      lab: _lab(texts),
      orderedBy: _doctor(texts),
    );
  }

  /// The page's lines grouped into rows, top to bottom, each read left to
  /// right with cells separated by two spaces.
  List<LabRow> rowsOf(OcrResult ocr) {
    final lines = [
      for (final l in ocr.lines)
        if (l.text.trim().isNotEmpty) l,
    ];
    if (lines.isEmpty) return const [];
    final slope = pageSlope(lines);
    // Text height: the median line, so one tall (tilted, long) box doesn't
    // set the tolerance.
    final heights = [for (final l in lines) _textHeight(l, slope)]..sort();
    final height = math.max(1.0, heights[heights.length ~/ 2]);
    // Undo the tilt: where each line would sit on a level page.
    double level(OcrLine l) => l.box.center.dy - slope * l.box.center.dx;
    final sorted = [...lines]..sort((a, b) => level(a).compareTo(level(b)));

    final rows = <List<OcrLine>>[];
    final centres = <double>[];
    for (final line in sorted) {
      final y = level(line);
      if (rows.isNotEmpty && (y - centres.last).abs() <= height * 0.5) {
        rows.last.add(line);
        final n = rows.last.length;
        centres.last += (y - centres.last) / n;
      } else {
        rows.add([line]);
        centres.add(y);
      }
    }
    return [
      for (final row in rows)
        LabRow(
          (row..sort((a, b) => a.box.left.compareTo(b.box.left)))
              .map((l) => l.text.trim())
              .join('  '),
          loose:
              row.length > 1 &&
              row.map(level).reduce(math.max) -
                      row.map(level).reduce(math.min) >
                  height * 0.5,
        ),
    ];
  }

  /// A line's text height on a level page: its box minus what the tilt
  /// added (a box around a turned line is taller than the text).
  static double _textHeight(OcrLine l, double slope) =>
      math.max(1.0, l.box.height - slope.abs() * l.box.width);

  /// The page's tilt as dy/dx: from the recogniser's line angles when it
  /// gives them, else the tilt that best lines up cells in different
  /// columns (tried in small steps up to about 12 degrees either way).
  static double pageSlope(List<OcrLine> lines) {
    final angles = <double>[for (final l in lines) ?l.angle]..sort();
    if (angles.length >= 3) {
      return math.tan(angles[angles.length ~/ 2] * math.pi / 180);
    }
    if (lines.length < 4) return 0;
    final heights = [for (final l in lines) l.box.height]..sort();
    final h = math.max(1.0, heights[heights.length ~/ 2]);
    var best = 0.0;
    var bestScore = -1;
    for (var step = 0; step <= 2 * 44; step++) {
      // 0, then +-0.005, +-0.01 ... so ties keep the smaller tilt.
      final k = (step + 1) ~/ 2;
      final slope = (step.isOdd ? 1 : -1) * k * 0.005;
      final tolerance = 0.25 * math.max(1.0, h - slope.abs() * 80);
      var score = 0;
      for (var i = 0; i < lines.length; i++) {
        final a = lines[i].box;
        final ya = a.center.dy - slope * a.center.dx;
        for (var j = i + 1; j < lines.length; j++) {
          final b = lines[j].box;
          // Only cells side by side, in different columns, say anything.
          if (a.right > b.left && b.right > a.left) continue;
          final yb = b.center.dy - slope * b.center.dx;
          if ((ya - yb).abs() <= tolerance) score++;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = slope;
      }
    }
    return best;
  }

  // Words that label the patient or the page. A row is skipped when its
  // name is one of these, a short label starting with one ("Patient ID",
  // "Lab No"), or a label followed by a colon. Longer names that only
  // start with one ("Sex Hormone Binding Globulin") are kept.
  static const _labelWords = {
    'patient',
    'name',
    'age',
    'sex',
    'gender',
    'date',
    'time',
    'ref',
    'doctor',
    'dr',
    'consultant',
    'tel',
    'phone',
    'mobile',
    'hotline',
    'fax',
    'page',
    'sample',
    'specimen',
    'registration',
    'reg',
    'lab',
    'laboratory',
    'id',
    'visit',
    'code',
    'branch',
    'www',
    'email',
    'e-mail',
    'file',
    'birth',
    'dob',
    'test',
    'tests',
    'result',
    'results',
    'reference',
    'unit',
    'units',
    'address',
    'signature',
    'approved',
    'checked',
    'comment',
    'comments',
    'note',
    'notes',
    'no',
    'mrn',
  };
  static final _labelPrefix = RegExp(
    r'^(collect|receiv|print|report|referr)',
    caseSensitive: false,
  );

  static bool _isLabel(String name, bool colonAfterFirst) {
    if (_labelPrefix.hasMatch(name)) return true;
    final words = name
        .toLowerCase()
        .split(RegExp(r'[\s.:#]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty || !_labelWords.contains(words.first)) return false;
    return colonAfterFirst ||
        words.length == 1 ||
        (words.length <= 3 && words.skip(1).every(_labelWords.contains));
  }

  static final _valueToken = RegExp(r'^[<>≤≥]?\d+(?:\.\d+)?\*?$');

  // Read as digits when they sit inside a number: O/o for 0, l/I for 1.
  static final _misreadNumber = RegExp(r'^[<>]?[\dOoIl]+(?:\.[\dOoIl]+)?$');

  // A number with thousands or decimal commas: "250,000", "12,5".
  static final _commaNumber = RegExp(r'^[<>]?\d[\d,]*,\d+(?:\.\d+)?\*?$');

  // A value with its unit run in: "4.5x10^3/uL", "6.1%", "13.5g/dL".
  static final _runIn = RegExp(r'^([<>]?\d+(?:\.\d+)?)([^\d.,].*)$');

  static final _printedFlag = RegExp(
    r'^(h|l|hh|ll|high|low|\*+|n|normal|abnormal|\(h\)|\(l\)|\[h\]|\[l\])$',
    caseSensitive: false,
  );

  static const _num = r'([+-]?\d+(?:\.\d+)?)';
  static final _ranges = [
    RegExp('$_num\\s*(?:-|to)\\s*$_num', caseSensitive: false),
    RegExp(
      '(?:<=|≤|=<|<|up\\s*to|less\\s*than|below|till)\\s*$_num',
      caseSensitive: false,
    ),
    RegExp(
      '(?:>=|≥|=>|>|more\\s*than|above|greater\\s*than|over)\\s*$_num',
      caseSensitive: false,
    ),
  ];

  static const _unitWords = {
    '%',
    'fl',
    'pg',
    'mg',
    'g',
    'iu',
    'u',
    'sec',
    'seconds',
    'ratio',
    'mm/hr',
    'mm/h',
    'mm/1st',
    'mmhg',
    'cells/cumm',
    '/cumm',
    '/hpf',
    '/ul',
  };

  /// A result from one row, or null if the row isn't one. A [loose] row's
  /// cells were spread over more than a line, so its name and value are
  /// marked for checking.
  LabCandidate? parseRow(String rawRow, {bool loose = false}) {
    final row = toWesternDigits(rawRow)
        .replaceAll('٬', ',')
        .replaceAll(RegExp('[–—−]'), '-')
        // Arabic words: headers and labels the Latin recogniser can't read.
        .replaceAll(RegExp(r'[؀-ۿ]+'), ' ')
        .replaceAll('|', ' ');
    final colonAfterFirst = RegExp(r'^\s*\S+(\s+\S+)?\s*:').hasMatch(row);
    final words = <String>[];
    for (final t in row.split(RegExp(r'\s+'))) {
      if (t.isEmpty) continue;
      // "4.5x10^3/uL": the value, then its unit, when the rest is a unit.
      final m = _runIn.firstMatch(t);
      if (m != null && _unit([m[2]!]) != null) {
        words
          ..add(m[1]!)
          ..add(m[2]!);
      } else {
        words.add(t);
      }
    }
    if (words.length < 2) return null;

    final unsure = <LabField>{};
    var at = -1;
    for (var i = 1; i < words.length; i++) {
      var fixedHere = false;
      final nameSoFar = words.sublist(0, i).join(' ');
      if (RegExp('[A-Za-z]').allMatches(nameSoFar).length < 2) continue;
      var w = words[i];
      if (!_valueToken.hasMatch(w)) {
        if (_commaNumber.hasMatch(w)) {
          // "250,000" or "12,5": read, but always worth a look.
          final sign = RegExp('^[<>]').firstMatch(w)?[0] ?? '';
          final n = parseLabNumber(
            w.substring(sign.length).replaceAll('*', ''),
          );
          if (n.value == null) continue;
          w = '$sign${formatLabNumber(n.value!)}';
          words[i] = w;
          fixedHere = true;
        } else if (_misreadNumber.hasMatch(w) && RegExp(r'\d').hasMatch(w)) {
          // "1O.5" read for "10.5": take it, but ask.
          w = w.replaceAll(RegExp('[Oo]'), '0').replaceAll(RegExp('[Il]'), '1');
          words[i] = w;
          fixedHere = true;
        } else {
          continue;
        }
      }
      // "Vitamin B 12 350": a letter then a number is part of the name.
      final next = i + 1 < words.length ? words[i + 1] : '';
      if (RegExp(r'^[A-Za-z]$').hasMatch(words[i - 1]) &&
          RegExp(r'^\d{1,2}$').hasMatch(words[i]) &&
          (_valueToken.hasMatch(next) ||
              _commaNumber.hasMatch(next) ||
              (_misreadNumber.hasMatch(next) &&
                  RegExp(r'\d').hasMatch(next)))) {
        continue;
      }
      if (fixedHere) unsure.add(LabField.value);
      at = i;
      break;
    }
    if (at < 0) return null;

    final name = words
        .sublist(0, at)
        .join(' ')
        .replaceAll(RegExp(r'[\s:.\-=]+$'), '')
        .trim();
    if (name.length < 2 || _isLabel(name, colonAfterFirst)) return null;
    if (!RegExp('[A-Za-z]{2}').hasMatch(name) && name.length < 3) return null;

    var value = words[at].replaceAll('*', '');
    final rest = words.sublist(at + 1);
    // A printed H or L right after the value: not ours to repeat.
    while (rest.isNotEmpty && _printedFlag.hasMatch(rest.first)) {
      rest.removeAt(0);
    }
    if (RegExp('^[<>≤≥]').hasMatch(value)) unsure.add(LabField.value);

    // Thousands in the range too ("150,000 - 450,000").
    var tail = rest
        .map((t) {
          if (!RegExp(r'^\(?\d[\d,]*,\d{3}\)?$').hasMatch(t)) return t;
          final bare = t.replaceAll(RegExp(r'[()]'), '');
          final n = parseLabNumber(bare).value;
          return n == null ? t : t.replaceFirst(bare, formatLabNumber(n));
        })
        .join(' ');
    // Every printed range on the row, left to right, without overlaps.
    final found = <Match>[];
    for (final r in _ranges) {
      for (final m in r.allMatches(tail)) {
        if (found.every((f) => m.end <= f.start || m.start >= f.end)) {
          found.add(m);
        }
      }
    }
    found.sort((a, b) => a.start.compareTo(b.start));
    var range = '';
    final ranges = <String>[];
    if (found.length == 1) {
      range = found.single[0]!.trim();
    } else if (found.length > 1) {
      // By age, sex or level: the person picks. No range, no flag, until
      // they do.
      ranges.addAll(found.map((m) => m[0]!.trim()));
      unsure.add(LabField.range);
    } else {
      unsure.add(LabField.range);
    }
    for (final m in found.reversed) {
      tail = '${tail.substring(0, m.start)} ${tail.substring(m.end)}';
    }
    final unit = _unit(
      tail.replaceAll(RegExp(r'[()\[\]]'), ' ').split(RegExp(r'\s+')),
    );
    if (unit == null) unsure.add(LabField.unit);
    if (matchLabTest(name) == null) unsure.add(LabField.name);
    if (loose) unsure.addAll({LabField.name, LabField.value});
    // "Vitamin B 12": a number in the name may be the value, or the other
    // way round. Known names with digits in them (HbA1c, Free T4) are fine.
    if (RegExp(r'(^|\s)\d+(\s|$)').hasMatch(name) ||
        (matchLabTest(name) == null && RegExp(r'\d').hasMatch(name))) {
      unsure.add(LabField.value);
    }

    final number = double.tryParse(value);
    final r = LabRange.parse(range);
    if (number != null && r.isNumeric) {
      // A value ten times past the range edge: maybe a dropped decimal.
      final high = r.high ?? r.low!;
      final low = r.low ?? 0;
      if ((high > 0 && number > high * 10) || (low > 0 && number < low / 10)) {
        unsure.add(LabField.value);
      }
      // The value is a bound: maybe a cell of the range read as the value.
      if (number == r.low || number == r.high) unsure.add(LabField.value);
      if (r.low != null && r.high != null && r.low! == r.high!) {
        unsure.add(LabField.range);
      }
    }
    value = value.replaceAll('≤', '<').replaceAll('≥', '>');
    return LabCandidate(
      name: name,
      value: value,
      unit: unit,
      range: range,
      ranges: ranges,
      unsure: unsure,
    );
  }

  static String? _unit(List<String> tokens) {
    final words = [
      for (final t in tokens)
        if (t.trim().isNotEmpty) t.trim(),
    ];
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      final lower = w.toLowerCase().replaceAll(RegExp('[µμ]'), 'u');
      // "x10^3/uL" or "x 10^3/uL" or "10^9/L".
      if (RegExp(r'^[x×*]?$').hasMatch(lower) &&
          i + 1 < words.length &&
          RegExp(r'^10\^?\d+/').hasMatch(words[i + 1])) {
        return '${w.isEmpty ? '' : 'x'}${words[i + 1]}'.replaceFirst(
          RegExp('^[*×]'),
          'x',
        );
      }
      if (RegExp(r'^[x×*]?10\^?\d+/').hasMatch(lower)) {
        return w.replaceFirst(RegExp('^[*×]'), 'x');
      }
      if (_unitWords.contains(lower)) return w;
      if (RegExp(r'^[a-z%]{1,6}/[a-z0-9.]{1,6}$').hasMatch(lower) &&
          RegExp('[a-z%]').hasMatch(lower)) {
        return w;
      }
    }
    return null;
  }

  static final _dateIn = RegExp(r'\b(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2,4})\b');
  static final _dateLine = RegExp(
    r'(date|collect|receiv|regist|report|sampl)',
    caseSensitive: false,
  );

  /// The report's date: a day-first date on a line that says so, else the
  /// first date on the page. Dates of birth don't count.
  static DateTime? _date(List<String> rows) {
    DateTime? first;
    for (final raw in rows) {
      final row = toWesternDigits(raw);
      var from = 0;
      for (final m in _dateIn.allMatches(row)) {
        // What the date's label says: the words since the previous date.
        final label = row.substring(from, m.start);
        from = m.end;
        if (RegExp(r'birth|dob', caseSensitive: false).hasMatch(label)) {
          continue;
        }
        final day = int.parse(m[1]!);
        final month = int.parse(m[2]!);
        var year = int.parse(m[3]!);
        if (year < 100) year += 2000;
        if (day < 1 || day > 31 || month < 1 || month > 12) continue;
        if (year < 1990 || year > 2100) continue;
        final d = DateTime(year, month, day);
        if (d.month != month) continue;
        if (_dateLine.hasMatch(label)) return d;
        first ??= d;
      }
    }
    return first;
  }

  /// The lab's name when a line near the top says "... Lab(s)" or
  /// "Laboratory".
  static String? _lab(List<String> rows) {
    for (final raw in rows.take(8)) {
      final row = raw
          .replaceAll(RegExp(r'[؀-ۿ]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (RegExp(r'\d').hasMatch(row)) continue;
      if (!RegExp(
        r'\blab(s|oratory|oratories)?\b',
        caseSensitive: false,
      ).hasMatch(row)) {
        continue;
      }
      if (row.split(' ').length > 6 || row.length < 3) continue;
      return row;
    }
    return null;
  }

  static final _doctorLine = RegExp(
    r'(?:ref(?:erred)?\.?\s*by|referring\s*(?:doctor|physician)|'
    r'requested\s*by|consultant)\s*[:.\-]?\s*(.+)',
    caseSensitive: false,
  );

  /// The doctor the report was sent from ("Ref. By: Dr. ...").
  static String? _doctor(List<String> rows) {
    for (final raw in rows) {
      final m = _doctorLine.firstMatch(raw.replaceAll(RegExp(r'[؀-ۿ]+'), ' '));
      if (m == null) continue;
      var name = m[1]!.split(RegExp(r'\s{2,}')).first.trim();
      name = name.replaceAll(RegExp(r'[:.\-]+$'), '').trim();
      if (name.length < 3 || !RegExp('[A-Za-z]{2}').hasMatch(name)) continue;
      if (RegExp(
        r'^(self|walk\s*in|-+)$',
        caseSensitive: false,
      ).hasMatch(name)) {
        continue;
      }
      return name;
    }
    return null;
  }
}
