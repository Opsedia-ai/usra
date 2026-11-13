import 'package:flutter/widgets.dart';
import 'package:intl/number_symbols_data.dart';

/// Makes intl write Arabic numbers in Arabic-Indic digits, once per isolate
/// before any text is made.
///
/// Its plain `ar` numbers are Latin (1,234.5) while its `ar` dates are
/// Arabic-Indic, so an amount in one sat beside a date in the other. Egypt's
/// own symbols (١٬٢٣٤٫٥) fix it in one place for what the app formats, what
/// gen-l10n formats and Flutter's own widgets. Dates are not affected.
void useArabicIndicNumbers() {
  numberFormatSymbols['ar'] = numberFormatSymbols['ar_EG']!;
}

/// [number] in the digits of the app's language: ٩ in Arabic, 9 in English.
/// Amounts a person typed stay as they typed them; this is for counts the app
/// writes, so they match the Arabic-Indic digits of the times beside them.
String localizedDigits(BuildContext context, int number) =>
    localizedDigitsIn(context, '$number');

/// [text] the app wrote, in the digits of the app's language, with a decimal
/// point as ٫ in Arabic. Never for what a person typed.
String localizedDigitsIn(BuildContext context, String text) =>
    digitsIn(Localizations.localeOf(context).languageCode, text);

/// The same for [languageCode], for text in a language other than the app's.
String digitsIn(String languageCode, String text) {
  if (languageCode != 'ar') return text;
  final units = text.codeUnits;
  bool latinAt(int i) =>
      i >= 0 && i < units.length && units[i] >= 0x30 && units[i] <= 0x39;
  bool digitAt(int i) =>
      latinAt(i) ||
      (i >= 0 && i < units.length && units[i] >= 0x660 && units[i] <= 0x669);
  return String.fromCharCodes([
    for (var i = 0; i < units.length; i++)
      if (latinAt(i))
        units[i] + 0x0660 - 0x30
      // A decimal point only between two digits: a full stop ending a
      // sentence stays a full stop, not ٫, which reads as a comma
      // (end-to-end test #17).
      else if (units[i] == 0x2E && digitAt(i - 1) && digitAt(i + 1))
        0x066B
      else
        units[i],
  ]);
}

/// A reading to one decimal, like a thermometer shows.
String localizedReading(BuildContext context, double value) =>
    localizedDigitsIn(context, value.toStringAsFixed(1));
