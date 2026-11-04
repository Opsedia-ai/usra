import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Security plan S6/S20: health data and its key never leave the phone
/// through Android backup or device transfer, and the release app never
/// talks plain HTTP. Release builds use the main manifest; debug and profile
/// only add the INTERNET permission for the Flutter tool.
void main() {
  const res = 'android/app/src/main/res';
  const android = 'http://schemas.android.com/apk/res/android';

  final application = XmlDocument.parse(
    File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
  ).rootElement.getElement('application')!;
  String? attr(String name) =>
      application.getAttribute(name, namespaceUri: android);

  /// `@xml/foo` → `res/xml/foo.xml`.
  XmlDocument xmlResource(String reference) {
    expect(reference, startsWith('@xml/'));
    final name = reference.substring('@xml/'.length);
    return XmlDocument.parse(File('$res/xml/$name.xml').readAsStringSync());
  }

  test('Android backup is off', () {
    expect(attr('allowBackup'), 'false');
    // Android 6–11 full backup.
    expect(attr('fullBackupContent'), 'false');
  });

  test('Android 12+ cloud backup and device transfer copy nothing', () {
    final reference = attr('dataExtractionRules');
    expect(reference, isNotNull, reason: 'android:dataExtractionRules');
    final rules = xmlResource(reference!).rootElement;
    const domains = {'root', 'file', 'database', 'sharedpref', 'external'};
    for (final section in ['cloud-backup', 'device-transfer']) {
      final element = rules.getElement(section);
      expect(element, isNotNull, reason: '$section must be listed');
      expect(element!.findElements('include'), isEmpty, reason: section);
      final excluded = element
          .findElements('exclude')
          .map((e) => e.getAttribute('domain'))
          .toSet();
      expect(excluded, containsAll(domains), reason: section);
    }
  });

  test('no cleartext HTTP', () {
    // Unset means false when targetSdk is 28 or later (Flutter targets 34+).
    expect(attr('usesCleartextTraffic'), anyOf(isNull, 'false'));
    final config = attr('networkSecurityConfig');
    if (config == null) return;
    final permitted = xmlResource(config).descendantElements
        .map((e) => e.getAttribute('cleartextTrafficPermitted'))
        .whereType<String>();
    expect(permitted, everyElement('false'));
  });

  test('the release manifest is not debuggable', () {
    expect(attr('debuggable'), anyOf(isNull, 'false'));
  });
}
