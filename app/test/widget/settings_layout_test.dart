import 'package:flutter_test/flutter_test.dart';
import 'package:usra/features/settings/about_privacy_screen.dart';
import 'package:usra/features/settings/delete_data_screen.dart';

import '../support/fits.dart';
import '../support/screen_harness.dart';

// The polished About and privacy and Delete all data screens (list rows,
// amber dot notices) at 320 px with double text, in Arabic and English,
// light and dark.
void main() {
  late ScreenHarness h;

  setUp(() => h = ScreenHarness());
  tearDown(() => h.dispose());

  group('about and privacy', () {
    forEachSmallLayout(() => h, (tester) async {
      await h.open(tester, aboutPath);
      await walkScreen(tester);
    });
  });

  group('delete all data', () {
    forEachSmallLayout(() => h, (tester) async {
      await h.open(tester, deleteDataPath);
      await walkScreen(tester);
    });
  });
}
