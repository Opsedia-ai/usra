import 'package:intl/intl.dart';

import '../../core/database/app_database.dart' show isValidMinHours;
import '../../core/util/localized_numbers.dart';

/// "Minimum hours between doses" on a medicine (C8): typed by the family
/// from the label or the doctor. The app only ever offers a figure read
/// from the medicine's own instructions as a suggestion the family must
/// accept, and only when the instructions hold exactly one unambiguous
/// figure; ranges, alternatives and daily limits give none.

/// Hours as typed: Arabic or Western digits, `.`, `,`, `٫` or `،` as the
/// decimal separator. Null when blank, not a number or out of range.
double? parseMinHours(String raw) {
  final n = parseDecimal(raw);
  return n == null || !isValidMinHours(n) ? null : n;
}

/// [raw] as a number, with a comma (Latin or Arabic) as the decimal
/// separator too; null when blank or not a number.
double? parseDecimal(String raw) {
  final t = toWesternDigits(raw.trim()).replaceAll(RegExp('[,،]'), '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// 6 → "6", 6.5 → "6.5" (in the locale's digits).
String formatHours(double hours, String locale) =>
    NumberFormat('0.##', locale).format(hours);

/// A figure read from the instructions, and the words it came from.
class MinHoursSuggestion {
  const MinHoursSuggestion(this.hours, this.phrase);

  final double hours;

  /// As written in the instructions.
  final String phrase;

  @override
  bool operator ==(Object other) =>
      other is MinHoursSuggestion &&
      other.hours == hours &&
      other.phrase == phrase;

  @override
  int get hashCode => Object.hash(hours, phrase);

  @override
  String toString() => 'MinHoursSuggestion($hours, $phrase)';
}

const _words = {
  'one': 1.0,
  'two': 2.0,
  'three': 3.0,
  'four': 4.0,
  'five': 5.0,
  'six': 6.0,
  'seven': 7.0,
  'eight': 8.0,
  'twelve': 12.0,
  'ثلاث': 3.0,
  'تلات': 3.0,
  'أربع': 4.0,
  'اربع': 4.0,
  'خمس': 5.0,
  'ست': 6.0,
  'ستة': 6.0,
  'سبع': 7.0,
  'ثمان': 8.0,
  'تمان': 8.0,
  'اتناشر': 12.0,
};

const _ar = r'ء-ي';

/// Words that make the text a limit or a count, not one gap between doses.
final _limits = RegExp(
  r'\b(up\s*to|max|maximum|at\s*most|no\s*more|times|doses?\s*(a|per|in))\b'
  r'|حد\s*أقصى|أقصى|اقصى|مرات|مرة|مره|جرعات',
  caseSensitive: false,
);

/// Any hour unit, with or without a figure before it.
final _unit = RegExp(
  '(?<![a-z])(hours?|hrs?|h)(?![a-z])|ساعتين|ساعتان'
  '|(?<![$_ar])(ساعات|ساعة|ساعه|س)(?![$_ar])',
  caseSensitive: false,
);

/// A figure followed by an hour unit. The figure can't start inside a
/// longer number ("10.5" is never read as "5").
final _figure = RegExp(
  '(?<![\\d.])(\\d+(?:\\.\\d+)?|[a-z]+|[$_ar]+)\\s*'
  '(?:(?:hours?|hrs?|h)(?![a-z])|(?:ساعات|ساعة|ساعه|س)(?![$_ar]))',
  caseSensitive: false,
);

/// What must come right before the figure ("every", "each", "q", "كل"),
/// or right after it ("apart").
final _before = RegExp(r'(?:\bevery|\beach|\bq|كل)\s*$', caseSensitive: false);
final _after = RegExp(r'^\s*apart\b', caseSensitive: false);

/// The one minimum interval [instructions] state, offered to the family to
/// accept; null when they state none, a range, an alternative, a limit or
/// more than one figure.
MinHoursSuggestion? suggestMinHours(String? instructions) {
  if (instructions == null || instructions.trim().isEmpty) return null;
  // Same length as the original, so match positions map back to it.
  final text = toWesternDigits(instructions)
      .replaceAllMapped(RegExp(r'(\d)[,،](\d)'), (m) => '${m[1]}.${m[2]}');
  if (text.length != instructions.length) return null;
  if (_limits.hasMatch(text)) return null;
  final units = _unit.allMatches(text).length;
  if (units != 1) return null;

  final two = RegExp(r'كل\s*(ساعتين|ساعتان)').firstMatch(text);
  if (two != null) {
    return MinHoursSuggestion(
      2,
      instructions.substring(two.start, two.end).trim(),
    );
  }
  final m = _figure.firstMatch(text);
  if (m == null) return null;
  final word = m.group(1)!;
  final hours = double.tryParse(word) ?? _words[word.toLowerCase()];
  if (hours == null || !isValidMinHours(hours)) return null;
  final pre = text.substring(0, m.start);
  final post = text.substring(m.end);
  final prefixed = _before.firstMatch(pre);
  if (prefixed == null && !_after.hasMatch(post)) return null;
  // A second figure without a unit ("every 4-6 hours", "q4/6h").
  if (RegExp(r'[\d]\s*(?:-|–|/|to|or|إلى|الى|او|أو|ل)\s*$').hasMatch(pre)) {
    return null;
  }
  final start = prefixed?.start ?? m.start;
  final end = prefixed == null ? m.end + _after.firstMatch(post)!.end : m.end;
  return MinHoursSuggestion(hours, instructions.substring(start, end).trim());
}
