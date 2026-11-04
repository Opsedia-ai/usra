import 'package:flutter/foundation.dart';

/// The app's only logger (security plan S5: no health data in logs).
///
/// Silent in release builds. In debug it prints a fixed [event] and the
/// error's type, never the error's message or stack: those can carry record
/// data, names, phone numbers, file paths or tokens. Pass a constant string
/// as [event], never one built from data.
///
/// Tests fail if `print(` or `debugPrint(` appears anywhere else in lib/,
/// or if an [event] is anything but a plain string literal.
abstract final class Log {
  /// Replaced in tests to capture output and to act as a release build.
  @visibleForTesting
  static void Function(String line) output = _debugPrint;

  @visibleForTesting
  static bool release = kReleaseMode;

  static void error(String event, Object error) {
    if (kReleaseMode || release) return;
    output('[usra] $event (${error.runtimeType})');
  }

  static void _debugPrint(String line) => debugPrint(line);
}
