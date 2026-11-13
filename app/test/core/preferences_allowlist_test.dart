import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/features/account/account_secure_storage.dart';
import 'package:usra/features/home/home_setup_cards.dart';

/// Shared preferences throws for a key missing from [PrefKeys.all]. On Home
/// that showed a red error panel in place of the first-steps cards (QA H1).
void main() {
  test('the in-memory store throws for a key outside the allowlist, '
      'like the real one', () {
    final store = MemoryKeyValueStore();
    expect(() => store.getBool('notAllowed'), throwsArgumentError);
    expect(() => store.setString('notAllowed', 'x'), throwsArgumentError);
    expect(
      () => MemoryKeyValueStore({'notAllowed': true}),
      throwsArgumentError,
    );
  });

  test('keys kept outside PrefKeys are in the allowlist', () {
    expect(PrefKeys.all, contains(homeSetupHiddenKey));
    expect(PrefKeys.all, contains(accountInstalledPref));
  });

  test('every settings key used in lib/ is in the allowlist', () {
    final prefs = File('lib/core/preferences.dart').readAsStringSync();
    final allBlock = RegExp(r'static const all = \{([^}]*)\}')
        .firstMatch(prefs)!
        .group(1)!;
    final allowed = RegExp(r'\w+').allMatches(allBlock).map((m) => m[0]);

    // Names defined as `const someKey = PrefKeys.x;` outside PrefKeys.
    final aliases = <String, String>{};
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.contains('/l10n/'))
        .toList();
    for (final f in files) {
      for (final m in RegExp(
        r'const (\w+) = PrefKeys\.(\w+);',
      ).allMatches(f.readAsStringSync())) {
        aliases[m[1]!] = m[2]!;
      }
    }

    final call = RegExp(r'\.(?:get|set)(?:Bool|Int|String)\(\s*([\w.]+)');
    final problems = <String>[];
    var checked = 0;
    for (final f in files) {
      if (f.path.endsWith('core/preferences.dart')) continue;
      for (final m in call.allMatches(f.readAsStringSync())) {
        final arg = m[1]!;
        final name = arg.startsWith('PrefKeys.')
            ? arg.substring('PrefKeys.'.length)
            : aliases[arg];
        checked++;
        if (name == null) {
          problems.add('${f.path}: key "$arg" is not a PrefKeys constant');
        } else if (!allowed.contains(name)) {
          problems.add('${f.path}: PrefKeys.$name is missing from all');
        }
      }
    }
    expect(checked, greaterThan(10), reason: 'the scan found the calls');
    expect(problems, isEmpty);
  });
}
