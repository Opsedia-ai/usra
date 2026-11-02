/// Arabic-Indic (٠-٩) and Persian (۰-۹) digits become 0-9, and the Arabic
/// decimal separator becomes a dot. Everything else is kept.
String toWesternDigits(String raw) {
  final out = StringBuffer();
  for (final unit in raw.runes) {
    if (unit >= 0x0660 && unit <= 0x0669) {
      out.writeCharCode(0x30 + unit - 0x0660);
    } else if (unit >= 0x06F0 && unit <= 0x06F9) {
      out.writeCharCode(0x30 + unit - 0x06F0);
    } else if (unit == 0x066B) {
      out.write('.');
    } else {
      out.writeCharCode(unit);
    }
  }
  return out.toString();
}

/// Parses a number typed in either script; null when empty or not a number.
num? parseLocalizedNumber(String raw) {
  final western = toWesternDigits(raw.trim());
  return western.isEmpty ? null : num.tryParse(western);
}

/// An amount like "350.5" in minor units (35050); null when blank, negative
/// or not a number.
int? parseMoneyMinor(String raw) {
  final amount = parseLocalizedNumber(raw);
  if (amount == null || amount < 0) return null;
  return (amount * 100).round();
}

/// Minor units back to the text a person would type: 35000 → "350",
/// 35050 → "350.5".
String formatMoneyInput(int minor) {
  final whole = minor ~/ 100;
  final cents = minor % 100;
  if (cents == 0) return '$whole';
  final frac = cents % 10 == 0
      ? '${cents ~/ 10}'
      : cents.toString().padLeft(2, '0');
  return '$whole.$frac';
}
