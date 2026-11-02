import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

  testWidgets('a saved doctor fills the visit and lists it on their page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    // Database calls outside the widgets run on real time, not fake time.
    final kid = (await tester.runAsync(() => db.addProfile('عمر')))!;
    await tester.runAsync(
      () => db.saveDoctor(name: 'د. هاني', feeMinor: 60000),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Add the doctor.
    await tester.tap(find.text('الدكاترة'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('doctor-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('doctor-name')), 'د. منى');
    await tester.enterText(
      find.byKey(const ValueKey('doctor-phone')),
      '01012345678',
    );
    await tester.enterText(find.byKey(const ValueKey('doctor-fee')), '٤٥٠');
    await tester.tap(find.byKey(const ValueKey('doctor-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('doctor-call')), findsOneWidget);
    expect(find.byKey(const ValueKey('doctor-whatsapp')), findsOneWidget);

    // Record a visit for Omar, picking her from the menu.
    final router = tester.element(find.byType(Scaffold).first);
    GoRouter.of(router).go('/family/$kid/add/visit');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('field-doctorPick')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('د. منى').last);
    await tester.pumpAndSettle();
    String costText() => tester
        .widget<TextField>(
          find.descendant(
            of: find.byKey(const ValueKey('field-cost')),
            matching: find.byType(TextField),
          ),
        )
        .controller!
        .text;
    expect(costText(), '450');
    // Switching to another doctor replaces the auto-filled fee.
    await tester.tap(find.byKey(const ValueKey('field-doctorPick')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('د. هاني').last);
    await tester.pumpAndSettle();
    expect(costText(), '600');
    await tester.tap(find.byKey(const ValueKey('field-doctorPick')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('د. منى').last);
    await tester.pumpAndSettle();
    expect(costText(), '450');

    await tester.tap(find.byKey(const ValueKey('record-save')));
    await tester.pumpAndSettle();
    expect(find.text('زيارة دكتور · د. منى'), findsOneWidget);

    // The doctor's page lists the visit, with who it was for.
    final doctors = (await tester.runAsync(() => db.watchDoctors().first))!;
    final doctorId = doctors.singleWhere((d) => d.name == 'د. منى').id;
    GoRouter.of(router).go('/doctors/$doctorId');
    await tester.pumpAndSettle();
    expect(find.text('عمر · زيارة دكتور'), findsOneWidget);
  });

  testWidgets('the Money tab adds up spending for the family and a person', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    final today = DateTime.now();
    final omar = (await tester.runAsync(() async {
      final omar = await db.addProfile('عمر');
      final mona = await db.addProfile('منى');
      final doctor = await db.saveDoctor(name: 'د. هاني');
      await db.addEvent(
        profileId: omar,
        type: 'visit',
        occurredAt: today,
        costMinor: 45000,
        currency: 'EGP',
        doctorId: doctor,
      );
      await db.addEvent(
        profileId: mona,
        type: 'lab',
        occurredAt: today,
        costMinor: 10050,
        currency: 'EGP',
      );
      return omar;
    }))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    String total() =>
        tester.widget<Text>(find.byKey(const ValueKey('spending-total'))).data!;

    await tester.tap(find.text('الفلوس'));
    await tester.pumpAndSettle();
    expect(total(), contains('550.50'));
    expect(find.byKey(const ValueKey('spending-by-type')), findsOneWidget);
    expect(find.byKey(const ValueKey('spending-by-person')), findsOneWidget);
    expect(find.text('د. هاني'), findsOneWidget);

    // Only Omar.
    await tester.tap(find.byKey(ValueKey('spending-person-$omar')));
    await tester.pumpAndSettle();
    expect(total(), contains('450'));
    expect(find.byKey(const ValueKey('spending-by-person')), findsNothing);

    // The year holds this month's spending; the years around it are empty.
    await tester.tap(find.text('سنة'));
    await tester.pumpAndSettle();
    expect(total(), contains('450'));
    await tester.tap(find.byKey(const ValueKey('spending-previous')));
    await tester.pumpAndSettle();
    expect(total(), startsWith('0'));
    expect(find.textContaining('مفيش مصاريف'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('spending-next')));
    await tester.tap(find.byKey(const ValueKey('spending-next')));
    await tester.pumpAndSettle();
    expect(total(), startsWith('0'));

    // A person's page links to their spending.
    final router = tester.element(find.byType(Scaffold).first);
    GoRouter.of(router).go('/family/$omar');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('member-spending')));
    await tester.pumpAndSettle();
    expect(total(), contains('450'));
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(ValueKey('spending-person-$omar')))
          .selected,
      isTrue,
    );
  });

  testWidgets('Home opens a person\'s emergency card with what ER needs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    final id = (await tester.runAsync(
      () => db.addProfile('جدّة سعاد', bloodType: 'B+', allergies: 'بنسلين'),
    ))!;
    await tester.runAsync(
      () => db.addEvent(
        profileId: id,
        type: 'surgery',
        occurredAt: DateTime(2019, 5, 1),
        dataJson: '{"procedure":"مرارة"}',
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('home-emergency-$id')));
    await tester.pumpAndSettle();

    expect(find.text('بطاقة الطوارئ'), findsOneWidget);
    expect(find.text('B+'), findsOneWidget);
    expect(find.text('بنسلين'), findsOneWidget);
    expect(find.text('مرارة · 2019'), findsOneWidget);
    // Conditions were never entered, so the card says so instead of hiding it.
    expect(find.text('مفيش حاجة متسجلة'), findsOneWidget);
    expect(find.byKey(const ValueKey('emergency-ambulance')), findsOneWidget);
    expect(find.byKey(const ValueKey('emergency-complete')), findsNothing);
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
