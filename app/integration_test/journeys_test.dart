import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/ui/journeys.dart';

/// The top four tasks on a simulator or phone (integration_test/README.md).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final journey in journeys) {
    testWidgets('journey: $journey', (tester) async {
      await runJourney(tester, journey, size: null);
    });
  }
}
