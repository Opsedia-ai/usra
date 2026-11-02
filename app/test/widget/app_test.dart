import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/app.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/design/dr_usra.dart';
import 'package:usra/core/providers.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  tearDown(() => db.close());

  Widget app() => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: const UsraApp(),
  );

  testWidgets('starts in Arabic, right to left, with Dr. Usra', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('أهلاً! أنا دكتور أسرة'), findsOneWidget);
    expect(find.byType(DrUsra), findsOneWidget);
    final direction = Directionality.of(tester.element(find.byType(DrUsra)));
    expect(direction, TextDirection.rtl);
  });

  testWidgets('switching to English changes the language', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('المزيد').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('Language'))),
      TextDirection.ltr,
    );
  });

  testWidgets('add a person, then a doctor visit appears on their timeline', (
    tester,
  ) async {
    // A tall phone screen so the whole form is built at once.
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('العيلة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ضيف شخص'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('profile-name')), 'فاطمة');
    await tester.ensureVisible(find.byKey(const ValueKey('profile-save')));
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    await tester.pumpAndSettle();

    // Now on Fatma's page, with an empty timeline.
    expect(find.text('فاطمة'), findsWidgets);
    expect(find.textContaining('مفيش سجلات لسه'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-record')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('type-visit')));
    await tester.pumpAndSettle();

    // Saving without the required doctor shows an error and stays on the form.
    await tester.ensureVisible(find.byKey(const ValueKey('record-save')));
    await tester.tap(find.byKey(const ValueKey('record-save')));
    await tester.pumpAndSettle();
    expect(find.text('مطلوب'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('field-doctorName')),
      'د. هاني',
    );
    await tester.enterText(find.byKey(const ValueKey('field-cost')), '٦٠٠');
    await tester.ensureVisible(find.byKey(const ValueKey('record-save')));
    await tester.tap(find.byKey(const ValueKey('record-save')));
    await tester.pumpAndSettle();

    expect(find.text('زيارة دكتور · د. هاني'), findsOneWidget);
    expect(find.textContaining('600'), findsOneWidget);
  });

  testWidgets('every Dr. Usra pose paints without errors', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            for (final p in DrUsraPose.values) DrUsra(pose: p, size: 60),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
