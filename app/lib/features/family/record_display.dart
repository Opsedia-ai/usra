import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/list_row.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/records/record_type.dart';
import '../../core/util/localized_digits.dart';
import '../../core/util/localized_numbers.dart';
import '../../l10n/app_localizations.dart';
import '../../core/util/separator.dart';

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

/// One record as a row of a [UsraListCard]: what it is, whose (where several
/// people are listed together), when and what it cost, and its photos.
/// Opens the record.
class RecordRow extends StatelessWidget {
  const RecordRow({
    super.key,
    required this.event,
    required this.type,
    required this.photos,
    this.personName,
    this.thumbnail,
  });

  final MedicalEvent event;
  final RecordTypeDefinition? type;
  final int photos;

  /// Shown first, where records of several people are listed together.
  final String? personName;

  /// The record's first photo, in place of the photo icon.
  final Widget? thumbnail;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final data = decodeRecordData(event.dataJson);
    final titleField = type?.titleField;
    final title = titleField == null ? null : data[titleField.key];
    final currency = event.currency;
    final money = event.costMinor == null
        ? null
        : formatMoney(
            event.costMinor!,
            locale: locale,
            currency: currency == null || currency == 'EGP'
                ? l.currencyEgp
                : currency,
          );
    return UsraListRow(
      key: ValueKey('event-${event.id}'),
      leading: IconBox(icon: type?.icon ?? Icons.description_outlined),
      title: [
        type?.labelOf(context) ?? event.type,
        if (title != null) displayFieldValue(context, titleField!, title),
      ].join(partSeparator),
      subtitleText: [
        ?personName,
        DateFormat.yMMMd(locale).format(event.occurredAt),
        ?money,
      ].join(partSeparator),
      onTap: () =>
          context.push('/family/${event.profileId}/record/${event.id}'),
      trailing: photos == 0
          ? null
          : Semantics(
              label: l.recordPhotoCount(photos),
              excludeSemantics: true,
              child: Row(
                key: ValueKey('event-photos-${event.id}'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    localizedDigits(context, photos),
                    style: UsraType.label.copyWith(
                      color: c.inkMuted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: UsraSpacing.s1),
                  thumbnail ??
                      Icon(Icons.photo_outlined, size: 20, color: c.inkMuted),
                ],
              ),
            ),
    );
  }
}
