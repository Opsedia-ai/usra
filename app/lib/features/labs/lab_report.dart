import '../../core/database/app_database.dart';
import '../../core/records/record_type.dart';
import '../../core/util/localized_numbers.dart';
import 'lab_tests.dart';

/// Keys in a `lab` record's `dataJson`.
///
/// A lab report holds [tests], a list of results. Records saved before
/// reports existed hold one result in [test], [value] and [unit]; they are
/// read as a report with one test. A report also keeps the names of its
/// tests in [test], so features that look for a test by name (follow-ups,
/// the pregnancy checklist) find it in either kind of record.
abstract final class LabFields {
  static const type = 'lab';
  static const test = 'test';
  static const value = 'value';
  static const unit = 'unit';
  static const lab = 'lab';
  static const orderedBy = 'orderedBy';
  static const tests = 'tests';
}

/// How a result compares with the range printed on the report. Only ever
/// computed from that printed range: never from the app's own idea of
/// normal, and never a diagnosis.
enum LabFlag { low, normal, high, unknown }

/// A number as labs print and people type it, read strictly (no NaN,
/// Infinity or hex). Arabic digits and separators are accepted. A comma is
/// a thousands separator only in "1,250" / "250,000" form (first group 1-3
/// digits without a leading zero, every other group exactly 3 digits);
/// otherwise a single comma is a decimal comma. [rewritten] says a comma
/// was read either way, so the result is worth a second look.
({double? value, bool rewritten}) parseLabNumber(String raw) {
  var s = toWesternDigits(raw.trim()).replaceAll('\u066C', ',');
  s = s.replaceAll(RegExp(r'\s+'), '');
  var rewritten = false;
  if (s.contains(',')) {
    rewritten = true;
    final thousands = RegExp(r'^[+-]?[1-9]\d{0,2}(,\d{3})+(\.\d+)?$');
    if (thousands.hasMatch(s)) {
      s = s.replaceAll(',', '');
    } else if (RegExp(r'^[+-]?\d+,\d+$').hasMatch(s)) {
      s = s.replaceAll(',', '.');
    } else {
      return (value: null, rewritten: true);
    }
  }
  if (!RegExp(r'^[+-]?(\d+(\.\d*)?|\.\d+)$').hasMatch(s)) {
    return (value: null, rewritten: rewritten);
  }
  final v = double.tryParse(s);
  return (value: v != null && v.isFinite ? v : null, rewritten: rewritten);
}

/// The reference range the lab printed next to a result: numbers ([low],
/// [high] or both) or, when it isn't numeric ("Negative"), [text].
///
/// Each bound is inclusive unless printed otherwise: "< 200" excludes 200
/// (so 200 is above it), "up to 150" and "≤ 150" include 150. [printed] keeps
/// the range as the lab wrote it, for display.
class LabRange {
  const LabRange({
    this.low,
    this.high,
    this.text,
    this.lowInclusive = true,
    this.highInclusive = true,
    this.printed,
  });

  static const none = LabRange();

  final double? low;
  final double? high;
  final String? text;
  final bool lowInclusive;
  final bool highInclusive;
  final String? printed;

  bool get isNumeric => low != null || high != null;
  bool get isEmpty => !isNumeric && (text == null || text!.trim().isEmpty);

  static const _n = r'([+-]?[\d,]*\d(?:\.\d+)?)';
  // Not ":", which is a titre ("1:80").
  static final _between = RegExp('^$_n\\s*(?:-|to)\\s*$_n\$');
  static final _below = RegExp(
    '^(<=|≤|=<|<|up\\s*to|less\\s*than|below|till|lower\\s*than)\\s*$_n\$',
  );
  static final _above = RegExp(
    '^(>=|≥|=>|>|more\\s*than|above|greater\\s*than|over|higher\\s*than)'
    '\\s*$_n\$',
  );

  static bool _inclusive(String op) =>
      op == '<=' ||
      op == '≤' ||
      op == '=<' ||
      op == '>=' ||
      op == '≥' ||
      op == '=>' ||
      op.startsWith('up') ||
      op.startsWith('till');

  /// Reads a range as people type it or labs print it: "4 - 11", "4.0–11.0",
  /// "(70-100)", "< 200", "up to 40", "≥ 60", "150,000 - 450,000",
  /// "-2 - +2". Anything else is kept as text.
  static LabRange parse(String raw) {
    final shown = raw.trim();
    final s = toWesternDigits(shown)
        .replaceAll('\u066C', ',')
        .replaceAll(RegExp('[–—−]'), '-')
        .replaceAll(RegExp(r'^[(\[]|[)\]]$'), '')
        .trim()
        .toLowerCase();
    if (s.isEmpty) return none;
    double? n(String t) => parseLabNumber(t).value;
    final printed = shown;
    if (_between.firstMatch(s) case final m?) {
      final a = n(m[1]!);
      final b = n(m[2]!);
      if (a != null && b != null) {
        return LabRange(
          low: a < b ? a : b,
          high: a < b ? b : a,
          printed: printed,
        );
      }
    }
    if (_below.firstMatch(s) case final m?) {
      if (n(m[2]!) case final v?) {
        return LabRange(
          high: v,
          highInclusive: _inclusive(m[1]!),
          printed: printed,
        );
      }
    }
    if (_above.firstMatch(s) case final m?) {
      if (n(m[2]!) case final v?) {
        return LabRange(
          low: v,
          lowInclusive: _inclusive(m[1]!),
          printed: printed,
        );
      }
    }
    return LabRange(text: shown);
  }

  /// As printed when known, else "4 - 11", "< 200", "≤ 150", "> 60".
  String format([String Function(double)? number]) {
    if (printed != null && printed!.isNotEmpty) return printed!;
    final n = number ?? formatLabNumber;
    if (low != null && high != null) return '${n(low!)} - ${n(high!)}';
    if (high != null) return '${highInclusive ? '≤' : '<'} ${n(high!)}';
    if (low != null) return '${lowInclusive ? '≥' : '>'} ${n(low!)}';
    return text ?? '';
  }

  @override
  bool operator ==(Object other) =>
      other is LabRange &&
      other.low == low &&
      other.high == high &&
      other.text == text &&
      other.lowInclusive == lowInclusive &&
      other.highInclusive == highInclusive &&
      other.printed == printed;

  @override
  int get hashCode =>
      Object.hash(low, high, text, lowInclusive, highInclusive, printed);

  @override
  String toString() => 'LabRange(${format()})';
}

/// 12, 12.5, 0.75: no trailing zeros, no thousands separators.
String formatLabNumber(num v) {
  if (v == v.roundToDouble() && v.abs() < 1e15) return '${v.round()}';
  var s = v.toStringAsFixed(4);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
}

/// One result on a report.
class LabTest {
  const LabTest({
    required this.name,
    this.value,
    this.valueText,
    this.unit,
    this.range = LabRange.none,
  });

  final String name;

  /// The result when it is a number.
  final double? value;

  /// The result as printed when it isn't a plain number ("Negative", "<0.5").
  final String? valueText;
  final String? unit;
  final LabRange range;

  /// The result against the printed range: [LabFlag.unknown] when either is
  /// missing or not a number. Bounds count as inside unless printed with
  /// "<" or ">".
  LabFlag get flag => labFlagOf(value, range);

  /// The result as shown: the number, or the text.
  String get shownValue =>
      value != null ? formatLabNumber(value!) : (valueText ?? '');

  /// A typed result: a number in either script, else the text.
  static ({double? value, String? text}) readValue(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return (value: null, text: null);
    final n = parseLabNumber(t).value;
    if (n != null) return (value: n, text: null);
    return (value: null, text: t);
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'value': ?value,
    'valueText': ?valueText,
    'unit': ?unit,
    'low': ?range.low,
    'high': ?range.high,
    'rangeText': ?range.text,
    if (!range.lowInclusive) 'lowOpen': true,
    if (!range.highInclusive) 'highOpen': true,
    'rangePrinted': ?range.printed,
  };

  static LabTest? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) return null;
    double? number(Object? v) => v is num && v.isFinite ? v.toDouble() : null;
    String? text(Object? v) =>
        v is String && v.trim().isNotEmpty ? v.trim() : null;
    return LabTest(
      name: name.trim(),
      value: number(json['value']),
      valueText: text(json['valueText']),
      unit: text(json['unit']),
      range: LabRange(
        low: number(json['low']),
        high: number(json['high']),
        text: text(json['rangeText']),
        lowInclusive: json['lowOpen'] != true,
        highInclusive: json['highOpen'] != true,
        printed: text(json['rangePrinted']),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LabTest &&
      other.name == name &&
      other.value == value &&
      other.valueText == valueText &&
      other.unit == unit &&
      other.range == range;

  @override
  int get hashCode => Object.hash(name, value, valueText, unit, range);

  @override
  String toString() =>
      'LabTest($name $shownValue ${unit ?? ''} '
      '[${range.format()}] $flag)';
}

/// [value] against the lab's printed [range].
LabFlag labFlagOf(double? value, LabRange range) {
  if (value == null || !range.isNumeric) return LabFlag.unknown;
  if (range.low case final low?) {
    if (value < low || (!range.lowInclusive && value == low)) {
      return LabFlag.low;
    }
  }
  if (range.high case final high?) {
    if (value > high || (!range.highInclusive && value == high)) {
      return LabFlag.high;
    }
  }
  return LabFlag.normal;
}

/// A lab record: where it was done, who asked for it, and its results.
class LabReport {
  const LabReport({this.lab, this.orderedBy, this.tests = const []});

  final String? lab;
  final String? orderedBy;
  final List<LabTest> tests;

  /// Reads a `lab` record's data, old single-test records included.
  factory LabReport.fromData(Map<String, Object?> data) {
    String? text(Object? v) =>
        v is String && v.trim().isNotEmpty ? v.trim() : null;
    final lab = text(data[LabFields.lab]);
    final orderedBy = text(data[LabFields.orderedBy]);
    final list = data[LabFields.tests];
    if (list is List) {
      return LabReport(
        lab: lab,
        orderedBy: orderedBy,
        tests: [for (final t in list) ?LabTest.fromJson(t)],
      );
    }
    // Saved before reports: one test, a number, a unit, no range.
    final name = text(data[LabFields.test]);
    if (name == null) return LabReport(lab: lab, orderedBy: orderedBy);
    final value = data[LabFields.value];
    final read = value is num && value.isFinite
        ? (value: value.toDouble(), text: null)
        : LabTest.readValue(value is String ? value : '');
    return LabReport(
      lab: lab,
      orderedBy: orderedBy,
      tests: [
        LabTest(
          name: name,
          value: read.value,
          valueText: read.text,
          unit: text(data[LabFields.unit]),
        ),
      ],
    );
  }

  factory LabReport.of(MedicalEvent event) =>
      LabReport.fromData(decodeRecordData(event.dataJson));

  /// The test names, for lists and for features that search by name.
  String get summary => tests.map((t) => t.name).join(', ');

  Map<String, Object?> toData() => {
    LabFields.test: summary,
    LabFields.lab: ?lab,
    LabFields.orderedBy: ?orderedBy,
    LabFields.tests: [for (final t in tests) t.toJson()],
  };
}

/// One result of one test on a chart.
class LabPoint {
  const LabPoint({
    required this.eventId,
    required this.date,
    required this.value,
    required this.range,
    required this.name,
  });

  final String eventId;
  final DateTime date;
  final double value;
  final LabRange range;

  /// The name as printed on that report.
  final String name;

  LabFlag get flag => labFlagOf(value, range);

  @override
  bool operator ==(Object other) =>
      other is LabPoint &&
      other.eventId == eventId &&
      other.date == date &&
      other.value == value &&
      other.range == range &&
      other.name == name;

  @override
  int get hashCode => Object.hash(eventId, date, value, range, name);
}

/// One test in one unit across a person's reports, oldest first. The same
/// test in another unit is a different series: values are never converted.
class LabSeries {
  const LabSeries({
    required this.testKey,
    required this.name,
    required this.unit,
    required this.points,
  });

  /// [labSeriesKey] of the test.
  final String testKey;

  /// The most recent name it was printed under.
  final String name;
  final String? unit;
  final List<LabPoint> points;

  LabPoint get latest => points.last;

  /// [testKey] as it may appear in a page address (see [labRouteId]).
  String get routeId => labRouteId(testKey);
}

/// Every test with a number result in a person's lab [events], one series
/// per test and unit, most recently done first.
List<LabSeries> labSeriesOf(Iterable<MedicalEvent> events) {
  final sorted = [
    for (final e in events)
      if (e.type == LabFields.type && e.deletedAt == null) e,
  ]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
  final groups = <String, List<(LabPoint, String?)>>{};
  for (final e in sorted) {
    for (final t in LabReport.of(e).tests) {
      if (t.value == null) continue;
      // A test with no unit is its own series, never merged with one
      // that has a unit.
      final key = '${labSeriesKey(t.name)}\u0000${labUnitKey(t.unit)}';
      (groups[key] ??= []).add((
        LabPoint(
          eventId: e.id,
          date: e.occurredAt,
          value: t.value!,
          range: t.range,
          name: t.name,
        ),
        t.unit,
      ));
    }
  }
  final series = [
    for (final MapEntry(key: key, value: points) in groups.entries)
      LabSeries(
        testKey: key.substring(0, key.indexOf('\u0000')),
        name: points.last.$1.name,
        unit: points.last.$2,
        points: [for (final (p, _) in points) p],
      ),
  ];
  series.sort((a, b) => b.latest.date.compareTo(a.latest.date));
  return series;
}
