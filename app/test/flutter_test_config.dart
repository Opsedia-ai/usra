import 'dart:async';

import 'package:usra/core/util/localized_digits.dart';

/// Runs before every test file, so tests read numbers as the app shows them.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  useArabicIndicNumbers();
  await testMain();
}
