import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/l10n/app_localizations.dart';

void main() {
  final ar = lookupAppLocalizations(const Locale('ar'));

  // "مقفول" says something is locked, so it can't also say a switch is off:
  // on these screens the two mean opposite things.
  test('Arabic never says "locked" where the English says "off"', () {
    final off = <String, String>{
      'settingsAppLockOff': ar.settingsAppLockOff,
      'lockOffDone': ar.lockOffDone,
      'lockSettingsBiometricsHint': ar.lockSettingsBiometricsHint,
      'settingsBlockScreenshotsHint': ar.settingsBlockScreenshotsHint,
      'rootWarningTitle': ar.rootWarningTitle,
      'backupAutoUnreadableTitle': ar.backupAutoUnreadableTitle,
    };
    for (final MapEntry(:key, :value) in off.entries) {
      expect(value, isNot(contains('مقفول')), reason: key);
      expect(value, isNot(contains('اتقفل')), reason: key);
    }
  });

  test('The app lock setting says plainly that it is not on', () {
    expect(ar.settingsAppLockOff, startsWith('مش شغّال'));
  });

  test('Being locked still says locked', () {
    expect(ar.lockTitle, contains('مقفولة'));
  });
}
