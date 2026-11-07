import 'package:flutter/widgets.dart';

/// [number] in the digits of the app's language: ٩ in Arabic, 9 in English.
/// Amounts a person typed stay as they typed them; this is for counts the app
/// writes, so they match the Arabic-Indic digits of the times beside them.
String localizedDigits(BuildContext context, int number) {
  final text = '$number';
  if (Localizations.localeOf(context).languageCode != 'ar') return text;
  return String.fromCharCodes(
    text.codeUnits.map((u) => u >= 0x30 && u <= 0x39 ? u + 0x0660 - 0x30 : u),
  );
}
