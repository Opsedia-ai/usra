import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../core/records/record_type.dart';
import '../../l10n/app_localizations.dart';

/// A record's stored fields, or none if the JSON is unreadable.
Map<String, Object?> decodeRecordData(String json) {
  try {
    final v = jsonDecode(json);
    return v is Map<String, Object?> ? v : const {};
  } catch (_) {
    return const {};
  }
}

/// A stored field value as people read it: choice labels, dates in the
/// app's language, yes or no.
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
    FieldKind.text || FieldKind.number || FieldKind.money => '$value',
  };
}
