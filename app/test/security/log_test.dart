import 'dart:io';

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
  tearDown(() => Log.release = false);

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

  test('nothing in lib/ prints except core/log.dart', () {
    final writes = RegExp(
      r'''\b(print|debugPrint|debugPrintStack|printError)\s*\(|'''
      r'''\bstd(out|err)\.(write|add)|'''
      r'''import\s+'dart:developer';''',
    );
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('.g.dart'))
        .where((f) => !p.equals(f.path, p.join('lib', 'core', 'log.dart')));
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
