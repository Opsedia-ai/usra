import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Runs an `integration_test/` file on a simulator or phone and saves the
/// screenshots it takes to `build/screenshots/` (see integration_test/README.md).
Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    File('build/screenshots/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    return true;
  },
);
