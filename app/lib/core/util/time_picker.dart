import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

/// [showTimePicker] with digits its typed mode can read.
///
/// In that mode Flutter fills the hour and minute with its localized digits
/// but reads them back with `int.tryParse`, which only takes 0-9. With
/// Arabic-Indic digits the time could never be confirmed, so in Arabic the
/// picker alone keeps 0-9. Its words stay Arabic.
Future<TimeOfDay?> pickTime(
  BuildContext context, {
  required TimeOfDay initialTime,
  String? helpText,
}) => showTimePicker(
  context: context,
  initialTime: initialTime,
  helpText: helpText,
  builder: (context, child) =>
      Localizations.localeOf(context).languageCode == 'ar'
      ? Localizations.override(
          context: context,
          delegates: const [_ArabicLatinDigits()],
          child: child,
        )
      : child!,
);

class _ArabicLatinDigits extends LocalizationsDelegate<MaterialLocalizations> {
  const _ArabicLatinDigits();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ar';

  @override
  Future<MaterialLocalizations> load(Locale locale) => SynchronousFuture(
    MaterialLocalizationAr(
      fullYearFormat: DateFormat.y('ar'),
      compactDateFormat: DateFormat.yMd('ar'),
      shortDateFormat: DateFormat.yMMMd('ar'),
      mediumDateFormat: DateFormat.MMMEd('ar'),
      longDateFormat: DateFormat.yMMMMEEEEd('ar'),
      yearMonthFormat: DateFormat.yMMMM('ar'),
      shortMonthDayFormat: DateFormat.MMMd('ar'),
      decimalFormat: NumberFormat.decimalPattern('en'),
      twoDigitZeroPaddedFormat: NumberFormat('00', 'en'),
    ),
  );

  @override
  bool shouldReload(_ArabicLatinDigits old) => false;
}
