import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:usra/core/log.dart';

/// Security plan S5: nothing from a record, a person or a token reaches the
/// logs, and only core/log.dart writes to them.
void main() {
  late List<String> lines;

  setUp(() {
    lines = [];
    Log.output = lines.add;
  });
  tearDown(() {
    Log.output = debugPrint;
    Log.release = false;
  });

  group('installErrorHandlers', () {
    late FlutterExceptionHandler? flutterOnError;
    late bool Function(Object, StackTrace)? platformOnError;
    late DebugPrintCallback originalDebugPrint;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      flutterOnError = FlutterError.onError;
      platformOnError = PlatformDispatcher.instance.onError;
      originalDebugPrint = debugPrint;
    });
    tearDown(() {
      FlutterError.onError = flutterOnError;
      PlatformDispatcher.instance.onError = platformOnError;
      debugPrint = originalDebugPrint;
    });

    const leak = 'Cannot read /data/Sara Ali/+201001234567.json';

    test('reported and uncaught errors log the type only', () {
      Log.installErrorHandlers();
      expect(FlutterError.onError, isNot(FlutterError.presentError));
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: const FormatException(leak),
          stack: StackTrace.current,
        ),
      );
      expect(
        PlatformDispatcher.instance.onError!(
          StateError(leak),
          StackTrace.current,
        ),
        isTrue,
      );
      expect(lines, [
        '[usra] Framework error (FormatException)',
        '[usra] Uncaught error (StateError)',
      ]);
    });

    test(
      'release builds silence debugPrint from the framework and plugins',
      () {
        final printed = <String?>[];
        debugPrint = (message, {wrapWidth}) => printed.add(message);
        Log.release = true;
        Log.installErrorHandlers();
        debugPrint(leak);
        FlutterError.reportError(
          FlutterErrorDetails(exception: const FormatException(leak)),
        );
        expect(printed, isEmpty);
        expect(lines, isEmpty);
      },
    );
  });

  test('debug builds log the event and the error type only', () {
    Log.error(
      'Saving failed',
      FileSystemException('Cannot open /data/Sara Ali/+201001234567.jpg'),
    );
    expect(lines, ['[usra] Saving failed (FileSystemException)']);
  });

  test('release builds log nothing', () {
    Log.release = true;
    Log.error('Saving failed', StateError('token=abc'));
    expect(lines, isEmpty);
  });

  Iterable<File> libFiles() =>
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('.g.dart'));

  test('Log events are fixed text, never built from data', () {
    final call = RegExp(r'Log\.(error|counts)\(\s*');
    final fixedText = RegExp(r"^'[^'$\n]*'\s*,");
    final offenders = <String>[];
    for (final file in libFiles()) {
      final code = file.readAsStringSync();
      for (final m in call.allMatches(code)) {
        if (!fixedText.hasMatch(code.substring(m.end))) {
          offenders.add(
            '${file.path}: ${code.substring(m.start).split('\n').first}',
          );
        }
      }
    }
    expect(offenders, isEmpty, reason: "Pass a plain 'string' as the event.");
  });

  test('nothing in lib/ prints except core/log.dart', () {
    final writes = RegExp(
      r'''\b(print|debugPrint|debugPrintStack|printError)\s*\(|'''
      r'''\bZone\.current\.print\b|'''
      r'''\b(dumpErrorToConsole|presentError)\b|'''
      r'''\bstd(out|err)\.|'''
      r'''import\s+['"]dart:developer['"]''',
    );
    final offenders = <String>[];
    final files = libFiles().where(
      (f) => !p.equals(f.path, p.join('lib', 'core', 'log.dart')),
    );
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].trimLeft();
        if (code.startsWith('//')) continue;
        if (writes.hasMatch(code)) offenders.add('${file.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty, reason: 'Use Log.error from core/log.dart.');
  });
}
