import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/backup/recovery_key.dart';
import 'package:usra/features/backup/backup_providers.dart';
import 'package:usra/features/backup/backup_screen.dart';

import '../support/fits.dart';
import '../support/screen_harness.dart';

// The polished backup screens (list rows, amber dot notices) at 320 px with
// double text, in Arabic and English, light and dark. The rows sit below
// the fold there, so the walk scrolls to each of them.
void main() {
  late ScreenHarness h;

  setUp(
    () => h = ScreenHarness()
      ..overrides = [
        // The phone's secure storage isn't there in tests.
        recoveryKeyStoreProvider.overrideWithValue(MemoryRecoveryKeyStore()),
      ],
  );
  tearDown(() => h.dispose());

  group('backup', () {
    forEachSmallLayout(() => h, (tester) async {
      await h.open(tester, backupPath);
      await walkScreen(tester);
    });
  });

  group('new recovery key', () {
    forEachSmallLayout(() => h, (tester) async {
      await h.open(tester, recoveryKeyPath);
      await walkScreen(tester);
    });
  });
}
