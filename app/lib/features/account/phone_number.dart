import '../../core/util/localized_numbers.dart';

/// Countries an account can be opened in, with their mobile numbers.
enum AccountCountry {
  egypt('EG', '20', r'^1[0125]\d{8}$'),
  saudiArabia('SA', '966', r'^5\d{8}$'),
  uae('AE', '971', r'^5[024568]\d{7}$');

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
  final western = toWesternDigits(typed).replaceAll(_separators, '');
  return RegExp(r'^\d*$').hasMatch(western) ? western : null;
}

final _separators = RegExp('[\\s\\-()+\u200E\u200F]');

/// A phone number written left to right inside Arabic text, with the
/// middle hidden: `+20 10•••••567`.
String displayPhone(String e164) {
  final country = AccountCountry.ofE164(e164);
  final digits = e164.startsWith('+') ? e164.substring(1) : e164;
  final code = country?.dialCode ?? '';
  final national = digits.substring(code.length);
  final masked = national.length <= 5
      ? '•' * national.length
      : '${national.substring(0, 2)}'
            '${'•' * (national.length - 5)}'
            '${national.substring(national.length - 3)}';
  return '\u2066${code.isEmpty ? '' : '+$code '}$masked\u2069';
}
