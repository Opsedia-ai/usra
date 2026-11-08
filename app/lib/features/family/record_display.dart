import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../core/records/record_type.dart';
import '../../core/util/localized_digits.dart';
import '../../l10n/app_localizations.dart';

/// A stored field value as people read it: choice labels, dates and numbers
/// in the app's language, yes or no. Typed text stays as typed.
String displayFieldValue(BuildContext context, FieldSpec field, Object value) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return switch (field.kind) {
    FieldKind.choice => field.choiceLabelOf(context, '$value'),
    FieldKind.boolean =>
      value == true
          ? AppLocalizations.of(context).fieldYes
          : AppLocalizations.of(context).fieldNo,
    FieldKind.date => switch (DateTime.tryParse('$value')) {
      final d? => DateFormat.yMMMd(locale).format(d),
      null => '$value',
    },
    FieldKind.number || FieldKind.money
        when value is num && !field.keepsLatinDigits =>
      localizedDigitsIn(context, '$value'),
    FieldKind.text || FieldKind.number || FieldKind.money => '$value',
  };
}
