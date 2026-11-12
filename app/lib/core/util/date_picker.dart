import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

/// [showDatePicker] whose typed mode reads what people type.
///
/// In Arabic, Flutter's typed mode only accepts its own compact format,
/// day‏/month‏/year with hidden right-to-left marks, so nothing a person
/// types on either keyboard was ever accepted. Here, in Arabic, typing
/// takes Arabic-Indic or Latin digits, day/month/year or year/month/day,
/// separated by "/", "-" or "."; anything else shows the picker's "invalid
/// format" error instead of being dropped. Every date field uses this.
Future<DateTime?> pickDate(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
}) => showDatePicker(
  context: context,
  initialDate: initialDate,
  firstDate: firstDate,
  lastDate: lastDate,
  helpText: helpText,
  builder: (context, child) =>
      Localizations.localeOf(context).languageCode == 'ar'
      ? Localizations.override(
          context: context,
          delegates: const [_ArabicTypedDates()],
          child: child,
        )
      : child!,
);

const _arabicIndic = '٠١٢٣٤٥٦٧٨٩';
const _persian = '۰۱۲۳۴۵۶۷۸۹';

/// A date typed as day/month/year, or year/month/day when the first part
/// has four digits; Arabic-Indic, Persian or Latin digits. Null when it
/// isn't a real calendar date.
DateTime? parseTypedDate(String? input) {
  if (input == null) return null;
  final latin = StringBuffer();
  for (final c in input.characters) {
    final a = _arabicIndic.indexOf(c);
    final p = _persian.indexOf(c);
    latin.write(
      a >= 0
          ? '$a'
          : p >= 0
          ? '$p'
          : c,
    );
  }
  // Direction marks and spaces around the separators go.
  final text = latin
      .toString()
      .replaceAll(RegExp(r'[\u200e\u200f\u061c\u202a-\u202e]'), '')
      .trim();
  final parts = text.split(RegExp(r'\s*[/\-.\\،,]\s*|\s+'));
  if (parts.length != 3) return null;
  final numbers = [for (final p in parts) int.tryParse(p)];
  if (numbers.contains(null)) return null;
  final yearFirst = parts[0].length == 4;
  final (y, m, d) = yearFirst
      ? (numbers[0]!, numbers[1]!, numbers[2]!)
      : (numbers[2]!, numbers[1]!, numbers[0]!);
  if (y < 1000 || y > 9999 || m < 1 || m > 12 || d < 1) return null;
  final date = DateTime(y, m, d);
  // 31/2 would roll over into March: not a real date.
  if (date.month != m || date.day != d) return null;
  return date;
}

class _ArabicTypedDates extends LocalizationsDelegate<MaterialLocalizations> {
  const _ArabicTypedDates();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ar';

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture(_ArabicDateLocalizations());

  @override
  bool shouldReload(_ArabicTypedDates old) => false;
}

class _ArabicDateLocalizations extends MaterialLocalizationAr {
  _ArabicDateLocalizations()
    : super(
        fullYearFormat: DateFormat.y('ar'),
        compactDateFormat: DateFormat.yMd('ar'),
        shortDateFormat: DateFormat.yMMMd('ar'),
        mediumDateFormat: DateFormat.MMMEd('ar'),
        longDateFormat: DateFormat.yMMMMEEEEd('ar'),
        yearMonthFormat: DateFormat.yMMMM('ar'),
        shortMonthDayFormat: DateFormat.MMMd('ar'),
        decimalFormat: NumberFormat.decimalPattern('ar'),
        twoDigitZeroPaddedFormat: NumberFormat('00', 'ar'),
      );

  /// What the typed field starts with: day/month/year in Arabic digits,
  /// without hidden direction marks, so it can be edited and read back.
  @override
  String formatCompactDate(DateTime date) {
    final text = '${date.day}/${date.month}/${date.year}';
    return [
      for (final c in text.characters)
        if (int.tryParse(c) case final n?) _arabicIndic[n] else c,
    ].join();
  }

  /// The typed field's hint, in the order it's read.
  @override
  String get dateHelpText => 'يوم/شهر/سنة';

  @override
  DateTime? parseCompactDate(String? inputString) =>
      parseTypedDate(inputString);
}
