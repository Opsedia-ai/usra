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

  /// What `checkPhotoIntegrity` found: numbers only, so no name or path can
  /// get in. Silent in release builds, like [error].
  static void photoCheck({required int missing, required int unused}) {
    if (kReleaseMode || release) return;
    output('[usra] Photo check (missing: $missing, unused: $unused)');
  }

  /// Call first in `main()`. Flutter's default handlers print the
  /// exception text and stack trace, in release builds too: framework
  /// errors, [FlutterError.reportError] and uncaught async errors all go
  /// through [error] instead. In release, `debugPrint` from the framework
  /// and plugins is switched off as well.
  static void installErrorHandlers() {
    FlutterError.onError = (details) =>
        error('Framework error', details.exception);
    PlatformDispatcher.instance.onError = (e, _) {
      error('Uncaught error', e);
      return true;
    };
    if (kReleaseMode || release) debugPrint = _silent;
  }

  static void _debugPrint(String line) => debugPrint(line);

  static void _silent(String? message, {int? wrapWidth}) {}
}
