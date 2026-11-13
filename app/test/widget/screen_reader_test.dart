import 'package:flutter_test/flutter_test.dart';

import '../support/screen_harness.dart';

/// Every tap target on the main screens has a label a screen reader can say
/// (bug 16). Before, the full-screen DismissKeyboard gesture detector was an
/// unlabelled tap node on every page, and UsraRoundIconButton's label sat
/// outside the button's own node.
void main() {
  late ScreenHarness h;
  late String childId;
  late String adultId;

  setUp(() => h = ScreenHarness());
  tearDown(() => h.dispose());

  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() async {
      adultId = await h.db.addProfile(
        'أنا',
        sex: 'female',
        birthDate: DateTime(1990, 3, 1),
      );
      childId = await h.db.addProfile(
        'بنتي',
        sex: 'female',
        birthDate: DateTime.now().subtract(const Duration(days: 400)),
        relationship: 'daughter',
      );
    });
  }

  final pages = <String, String Function()>{
    'Home': () => '/home',
    'Family': () => '/family',
    'Medicines': () => '/medicines',
    'Records': () => '/records',
    'Spending': () => '/money',
    'Settings': () => '/settings',
    'Follow-ups': () => '/follow-ups',
    'Doctors': () => '/doctors',
    'Adult page': () => '/family/$adultId',
    'Child page': () => '/family/$childId',
    'Edit person': () => '/family/$childId/edit',
    'Emergency card': () => '/family/$childId/emergency',
    'Vaccines': () => '/family/$childId/vaccines',
    'Growth': () => '/family/$childId/growth',
    'Development': () => '/family/$childId/development',
    'Sick days': () => '/family/$childId/sick-days',
    'Their medicines': () => '/family/$childId/medicines',
    'Insurance': () => '/family/$childId/insurance',
    'New visit': () => '/family/$childId/add/visit',
    'New person': () => '/family/new',
  };

  for (final MapEntry(key: name, value: path) in pages.entries) {
    testWidgets('$name: every tap target has a label', (tester) async {
      await seed(tester);
      await h.open(tester, path());
      final semantics = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  }
}
