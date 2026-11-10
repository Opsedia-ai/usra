import '../util/localized_numbers.dart';

/// A date printed on a page, and the words just before it ("Date:",
/// "التاريخ", "تاريخ الميلاد"), so callers can tell what it is for.
typedef OcrDate = ({DateTime date, String label});

final _dayFirst = RegExp(
  r'(?<![\d/.\-])(\d{1,2})\s*[/.\-]\s*(\d{1,2})\s*[/.\-]\s*(\d{4}|\d{2})(?![\d/.\-])',
);
final _yearFirst = RegExp(
  r'(?<![\d/.\-])(\d{4})\s*[/.\-]\s*(\d{1,2})\s*[/.\-]\s*(\d{1,2})(?![\d/.\-])',
);

/// Every real calendar date in [raw], left to right. Egyptian papers write
/// the day first ("12/3/2026", "١٢/٣/٢٠٢٦", "12-03-26"); a four-digit year
/// first ("2026/3/12") is read as year, month, day. Impossible dates
/// ("31/2/2026", "13/13/2026") and years outside [minYear]..[maxYear] are
/// left out, never "fixed".
List<OcrDate> datesIn(String raw, {int minYear = 1990, int maxYear = 2100}) {
  final text = toWesternDigits(raw).replaceAll('٫', '.');
  final found = <(int, int, DateTime)>[];
  void add(int start, int end, int y, int m, int d) {
    if (y < 100) y += 2000;
    if (y < minYear || y > maxYear || m < 1 || m > 12 || d < 1) return;
    final date = DateTime(y, m, d);
    if (date.month != m || date.day != d) return;
    if (found.any((f) => start < f.$2 && end > f.$1)) return;
    found.add((start, end, date));
  }

  for (final m in _yearFirst.allMatches(text)) {
    add(m.start, m.end, int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }
  for (final m in _dayFirst.allMatches(text)) {
    add(m.start, m.end, int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
  }
  found.sort((a, b) => a.$1.compareTo(b.$1));
  final out = <OcrDate>[];
  var from = 0;
  for (final (start, end, date) in found) {
    out.add((date: date, label: text.substring(from, start)));
    from = end;
  }
  return out;
}
