import 'dart:ui' show Rect;

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
    this.unsure = const {},
  });

  final String name;

  /// As read: a number, or text like "<0.5".
  final String value;
  final String? unit;

  /// The printed range, tidied ("4 - 11", "< 200"), or '' when none.
  final String range;
  final Set<LabField> unsure;

  @override
  String toString() =>
      'LabCandidate($name | $value | ${unit ?? '-'} | $range | $unsure)';
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

/// Turns the text of a lab report photo into result rows.
///
/// Reports from Egyptian labs print a table (test, result, unit, reference
/// range) in English, often with Arabic headers. The recogniser reads it
/// in blocks that may be whole columns, so lines are first put back into
/// rows by where they sit on the page. A row becomes a result only if it
/// has a name and a number; everything uncertain is marked for checking.
/// Printed High/Low marks are ignored: the app works the flag out from the
/// printed range itself.
class LabReportParser {
  const LabReportParser();

  LabScan parse(OcrResult ocr) {
    final rows = rowsOf(ocr);
    final tests = <LabCandidate>[];
    for (final row in rows) {
      final c = parseRow(row);
      if (c != null) tests.add(c);
    }
    return LabScan(
      tests: tests,
      date: _date(rows),
      lab: _lab(rows),
      orderedBy: _doctor(rows),
    );
  }

  /// The page's lines grouped into rows, top to bottom, each read left to
  /// right with cells separated by two spaces.
  List<String> rowsOf(OcrResult ocr) {
    final lines = [
      for (final l in ocr.lines)
        if (l.text.trim().isNotEmpty) l,
    ]..sort((a, b) => a.box.center.dy.compareTo(b.box.center.dy));
    final rows = <List<OcrLine>>[];
    for (final line in lines) {
      final row = rows.isEmpty ? null : rows.last;
      if (row != null && _sameRow(row, line.box)) {
        row.add(line);
      } else {
        rows.add([line]);
      }
    }
    return [
      for (final row in rows)
        (row..sort((a, b) => a.box.left.compareTo(b.box.left)))
            .map((l) => l.text.trim())
            .join('  '),
    ];
  }

  static bool _sameRow(List<OcrLine> row, Rect box) {
    final top = row.map((l) => l.box.top).reduce((a, b) => a < b ? a : b);
    final bottom = row.map((l) => l.box.bottom).reduce((a, b) => a > b ? a : b);
    final height = (bottom - top).clamp(1.0, double.infinity);
    final centre = (top + bottom) / 2;
    final tolerance =
        0.5 * (height < box.height ? height : box.height).clamp(1.0, 1e9);
    return (box.center.dy - centre).abs() <= tolerance;
  }

  // Rows that are about the patient or the page, not a result.
  static final _notATest = RegExp(
    r'^((patient|name|age|sex|gender|date|time|ref|doctor|dr|consultant|'
    r'tel|phone|mobile|hotline|fax|page|sample|specimen|registration|reg|'
    r'lab|laboratory|id|visit|code|branch|www|e-?mail|file|birth|dob|'
    r'tests?|results?|reference|units?|address|signature|approved|checked|'
    r'comments?|notes?)\b|collect|receiv|print|report|referr)',
    caseSensitive: false,
  );

  static final _valueToken = RegExp(r'^[<>≤≥]?\d+(?:\.\d+)?\*?$');

  // Read as digits when they sit inside a number: O/o for 0, l/I for 1.
  static final _misreadNumber = RegExp(r'^[<>]?[\dOoIl]+(?:\.[\dOoIl]+)?$');

  static final _printedFlag = RegExp(
    r'^(h|l|hh|ll|high|low|\*+|n|normal|abnormal|\(h\)|\(l\)|\[h\]|\[l\])$',
    caseSensitive: false,
  );

  static const _num = r'(\d+(?:\.\d+)?)';
  static final _ranges = [
    RegExp('$_num\\s*(?:-|to)\\s*$_num', caseSensitive: false),
    RegExp(
      '(?:<=?|≤|up\\s*to|less\\s*than|below|till)\\s*$_num',
      caseSensitive: false,
    ),
    RegExp(
      '(?:>=?|≥|more\\s*than|above|greater\\s*than|over)\\s*$_num',
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

  /// A result from one row, or null if the row isn't one.
  LabCandidate? parseRow(String rawRow) {
    var row = toWesternDigits(rawRow)
        .replaceAll(RegExp('[–—−]'), '-')
        // Arabic words: headers and labels the Latin recogniser can't read.
        .replaceAll(RegExp(r'[؀-ۿ]+'), ' ')
        .replaceAll('|', ' ')
        .replaceAll(RegExp(r'(?<=\d),(?=\d{3}(?!\d))'), '');
    final tokens = row.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    final words = tokens.toList();
    if (words.length < 2) return null;

    final unsure = <LabField>{};
    var at = -1;
    for (var i = 1; i < words.length; i++) {
      var fixedHere = false;
      final nameSoFar = words.sublist(0, i).join(' ');
      if (RegExp('[A-Za-z]').allMatches(nameSoFar).length < 2) continue;
      var w = words[i];
      if (!_valueToken.hasMatch(w)) {
        // "1O.5" read for "10.5": take it, but ask.
        if (_misreadNumber.hasMatch(w) && RegExp(r'\d').hasMatch(w)) {
          w = w.replaceAll(RegExp('[Oo]'), '0').replaceAll(RegExp('[Il]'), '1');
          words[i] = w;
          fixedHere = true;
        } else if (RegExp(r'^\d+,\d+$').hasMatch(w)) {
          // A decimal comma: "12,5".
          words[i] = w.replaceAll(',', '.');
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
    if (name.length < 2 || _notATest.hasMatch(name)) return null;
    if (!RegExp('[A-Za-z]{2}').hasMatch(name) && name.length < 3) return null;

    var value = words[at].replaceAll('*', '');
    final rest = words.sublist(at + 1);
    // A printed H or L right after the value: not ours to repeat.
    while (rest.isNotEmpty && _printedFlag.hasMatch(rest.first)) {
      rest.removeAt(0);
    }
    if (value.startsWith('<') ||
        value.startsWith('>') ||
        value.startsWith('≤') ||
        value.startsWith('≥')) {
      unsure.add(LabField.value);
    }

    var tail = rest.join(' ');
    // The printed range: the first one found. More than one (by age or
    // sex) means the person picks.
    Match? found;
    for (final r in _ranges) {
      for (final m in r.allMatches(tail)) {
        if (found == null || m.start < found.start) found = m;
      }
    }
    var range = '';
    if (found != null) {
      range = LabRange.parse(found[0]!).format();
      final others = _ranges
          .expand((r) => r.allMatches(tail))
          .where((m) => m.end <= found!.start || m.start >= found.end);
      if (others.isNotEmpty) unsure.add(LabField.range);
      tail = '${tail.substring(0, found.start)} ${tail.substring(found.end)}';
    } else {
      unsure.add(LabField.range);
    }
    final unit = _unit(
      tail.replaceAll(RegExp(r'[()\[\]]'), ' ').split(RegExp(r'\s+')),
    );
    if (unit == null) unsure.add(LabField.unit);
    if (matchLabTest(name) == null) unsure.add(LabField.name);

    // A value ten times past the range edge: maybe a dropped decimal point.
    final number = double.tryParse(value);
    final r = LabRange.parse(range);
    if (number != null && r.isNumeric) {
      final high = r.high ?? r.low!;
      final low = r.low ?? 0;
      if ((high > 0 && number > high * 10) || (low > 0 && number < low / 10)) {
        unsure.add(LabField.value);
      }
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
