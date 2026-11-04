/// Countries an account can be opened in, with their mobile numbers.
enum AccountCountry {
  egypt('EG', '20', r'^1[0125]\d{8}$'),
  saudiArabia('SA', '966', r'^5\d{8}$'),
  uae('AE', '971', r'^5\d{8}$');

  const AccountCountry(this.code, this.dialCode, this._mobile);

  /// ISO code, as stored in `accounts.country`.
  final String code;
  final String dialCode;
  final String _mobile;

  /// The number in E.164 (`+201001234567`), or null if it isn't a mobile
  /// number of this country. Accepts Arabic digits, spaces, a leading 0
  /// and the country code typed again.
  String? toE164(String typed) {
    var digits = asciiDigits(typed);
    if (digits == null) return null;
    if (digits.startsWith('00$dialCode')) {
      digits = digits.substring(2 + dialCode.length);
    } else if (typed.trimLeft().startsWith('+')) {
      if (!digits.startsWith(dialCode)) return null;
      digits = digits.substring(dialCode.length);
    } else if (digits.startsWith(dialCode) &&
        RegExp(_mobile).hasMatch(digits.substring(dialCode.length))) {
      digits = digits.substring(dialCode.length);
    }
    if (digits.startsWith('0')) digits = digits.substring(1);
    return RegExp(_mobile).hasMatch(digits) ? '+$dialCode$digits' : null;
  }

  /// The country of an E.164 number, if it's one of ours.
  static AccountCountry? ofE164(String? phone) {
    if (phone == null) return null;
    final digits = phone.startsWith('+') ? phone.substring(1) : phone;
    for (final c in values) {
      if (digits.startsWith(c.dialCode) &&
          RegExp(c._mobile).hasMatch(digits.substring(c.dialCode.length))) {
        return c;
      }
    }
    return null;
  }
}

/// Digits only, with Arabic-Indic and Persian digits made ASCII; null if
/// anything other than digits and separators was typed.
String? asciiDigits(String typed) {
  final out = StringBuffer();
  for (final rune in typed.runes) {
    if (rune >= 0x30 && rune <= 0x39) {
      out.writeCharCode(rune);
    } else if (rune >= 0x660 && rune <= 0x669) {
      out.writeCharCode(rune - 0x660 + 0x30);
    } else if (rune >= 0x6F0 && rune <= 0x6F9) {
      out.writeCharCode(rune - 0x6F0 + 0x30);
    } else if (!' -()+\u200E\u200F'.runes.contains(rune)) {
      return null;
    }
  }
  return out.toString();
}

/// A phone number written left to right inside Arabic text.
String displayPhone(String e164) => '\u2066$e164\u2069';
