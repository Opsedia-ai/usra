import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

void main() {
  for (final r in ['/home', 'Y']) {
    testWidgets('dbg $r', (tester) async {
      await atDemoTime(() async {
        await pumpDemoScreen(
          tester,
          UiScreen('x', (f) => r == 'Y' ? '/family/${f.youssef}' : r),
          size: const Size(393, 3000),
        );
        final keys = <String>{};
        for (final e
            in find
                .byWidgetPredicate((w) => w.key is ValueKey<String>)
                .evaluate()) {
          keys.add((e.widget.key! as ValueKey<String>).value);
        }
        debugPrint('### $r $keys');
      });
    });
  }
}
