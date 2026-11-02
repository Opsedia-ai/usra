import '../../core/util/localized_numbers.dart';

/// Digits (and a leading +) only, in western script; null if no digits.
String? cleanPhone(String? raw) {
  if (raw == null) return null;
  final western = toWesternDigits(raw.trim());
  final digits = western.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return western.startsWith('+') ? '+$digits' : digits;
}

/// A `tel:` link that opens the dialer with [phone].
Uri? callUri(String? phone) {
  final clean = cleanPhone(phone);
  return clean == null ? null : Uri(scheme: 'tel', path: clean);
}

/// A WhatsApp chat link. Local numbers (leading 0) get [countryCode]
/// (Egypt by default); "00" and "+" prefixes are already international.
Uri? whatsappUri(String? phone, {String countryCode = '20'}) {
  var digits = cleanPhone(phone);
  if (digits == null) return null;
  if (digits.startsWith('+')) {
    digits = digits.substring(1);
  } else if (digits.startsWith('00')) {
    digits = digits.substring(2);
  } else if (digits.startsWith('0')) {
    digits = countryCode + digits.substring(1);
  }
  if (digits.length < 8) return null;
  return Uri.https('wa.me', '/$digits');
}
