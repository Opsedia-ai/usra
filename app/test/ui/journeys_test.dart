import 'package:flutter_test/flutter_test.dart';

import 'journeys.dart';
import 'ui_harness.dart';

void main() {
  for (final journey in journeys) {
    testWidgets('journey: $journey', (tester) async {
      await atDemoTime(() => runJourney(tester, journey));
    });
  }
}
