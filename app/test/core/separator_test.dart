import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/util/separator.dart';

/// The middle dot looked like the Arabic zero beside Arabic-Indic digits:
/// "٢٠٢٦ · ٣٥٠" read as "٣٥٠٠" (QA H2). Lines use [partSeparator] instead.
void main() {
  test('the separator has no digit look-alike', () {
    expect(partSeparator, ' – ');
    expect(partSeparator, isNot(contains('·')));
  });

  test('no middle dot in the strings or in text the code builds', () {
    // The prescription reader still accepts "·" as a bullet in scanned text.
    const allowed = {'lib/features/medicines/prescription_parser.dart'};
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || allowed.contains(f.path)) continue;
      if (!f.path.endsWith('.dart') && !f.path.endsWith('.arb')) continue;
      final lines = f.readAsLinesSync();
      for (final (i, line) in lines.indexed) {
        if (line.trimLeft().startsWith('//')) continue;
        if (line.contains('·')) offenders.add('${f.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty);
  });
}
