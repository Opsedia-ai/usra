import '../../core/util/localized_numbers.dart';

/// Digits (and a leading +) only, in western script; null if no digits. Anything
/// before the + (a bracket, the invisible marks a paste from Contacts brings)
/// doesn't lose it.
String? cleanPhone(String? raw) {
  if (raw == null) return null;
  final kept = toWesternDigits(raw).replaceAll(RegExp(r'[^0-9+]'), '');
  final digits = kept.replaceAll('+', '');
  if (digits.isEmpty) return null;
  return kept.startsWith('+') ? '+$digits' : digits;
}

/// Could be dialled: only what a phone number is written with, and enough digits
/// for the shortest (123). Not "ماما 1", whose only digit would be dialled.
bool isCallablePhone(String raw) {
  final western = toWesternDigits(raw).trim();
  if (RegExp(r'[^0-9+\-() \u200e\u200f\u202a-\u202e]').hasMatch(western)) {
    return false;
  }
  return (cleanPhone(western)?.replaceAll('+', '').length ?? 0) >= 3;
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
