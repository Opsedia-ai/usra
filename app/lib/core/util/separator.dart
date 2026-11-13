import 'package:flutter/widgets.dart';

/// Between the parts of one line, as in "١٣ نوفمبر ٢٠٢٦ – ٣٥٠ ج.م" or
/// "Next dose – 8:00 PM". The same in both languages and in the ARB strings.
///
/// A spaced en dash. The middle dot it replaces looked like the Arabic zero
/// "٠" beside Arabic-Indic digits, so "٢٠٢٦ · ٣٥٠" read as "٣٥٠٠" (QA H2).
/// For a list of like things, such as several times of day, use
/// [listComma] instead: a dash between two times reads as a range.
const partSeparator = ' – ';

/// Between the items of a list: "، " in Arabic, ", " in English.
String listComma(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar' ? '، ' : ', ';
