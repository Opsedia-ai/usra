import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/design/list_row.dart';
import 'package:usra/core/design/status_chip.dart';
import 'package:usra/core/design/status_dot.dart';
import 'package:usra/core/design/tokens.dart';
import 'package:usra/core/files/photo_store.dart';
import 'package:usra/features/insurance/watermark.dart';
import 'package:usra/core/util/periods.dart';

import '../support/fits.dart';
import '../support/screen_harness.dart';

void main() {
  late ScreenHarness h;

  setUp(() {
    h = ScreenHarness();
    h.overrides = [cardPhotoStoreProvider.overrideWithValue(h.photos)];
  });
  tearDown(() => h.dispose());

  Finder key(String k) => find.byKey(ValueKey(k));

  Future<(String, String)> seedCard(WidgetTester tester) async =>
      (await tester.runAsync(() async {
        final id = await h.db.addProfile('فاطمة', sex: 'female');
        final card = await h.db.saveInsuranceCard(
          profileId: id,
          label: 'نقابة المهندسين',
          insurer: 'نقابة',
          memberNumber: '1234 5678',
        );
        return (id, card);
      }))!;

  Future<String> seedSpending(WidgetTester tester) async =>
      (await tester.runAsync(() async {
        final id = await h.db.addProfile('فاطمة', sex: 'female');
        await h.db.addEvent(
          profileId: id,
          type: 'visit',
          occurredAt: DateTime.now(),
          dataJson: '{"doctorName":"سارة"}',
          costMinor: 40000,
          currency: 'EGP',
        );
        return id;
      }))!;

  group('Insurance', () {
    testWidgets('an expired card: an amber dot and the words, never red', (
      tester,
    ) async {
      h.tall(tester);
      final id = (await tester.runAsync(() async {
        final id = await h.db.addProfile('فاطمة', sex: 'female');
        await h.db.saveInsuranceCard(
          profileId: id,
          label: 'نقابة المهندسين',
          expiresOn: DateTime(2020, 1, 31),
        );
        return id;
      }))!;
      await h.open(tester, '/family/$id/insurance');
      final line = find.descendant(
        of: key('insurance-expiry'),
        matching: find.byType(StatusDotText),
        matchRoot: true,
      );
      expect(line, findsOneWidget);
      expect(tester.widget<StatusDotText>(line).label, startsWith('انتهى'));
      expect(find.byType(StatusChip), findsNothing);
    });

    testWidgets('member numbers read left to right', (tester) async {
      h.tall(tester);
      final (id, card) = await seedCard(tester);
      await h.open(tester, '/family/$id/insurance/$card');
      final number = tester.widget<SelectableText>(key('insurance-number'));
      expect(number.textDirection, TextDirection.ltr);
      expect(number.data, '1234 5678');
    });

    testWidgets('the saved fields are rows, with one filled button', (
      tester,
    ) async {
      h.tall(tester);
      final (id, card) = await seedCard(tester);
      await h.open(tester, '/family/$id/insurance/$card');
      final details = find.byType(UsraListCard);
      expect(details, findsOneWidget);
      for (final text in [
        'الكارت',
        'نقابة المهندسين',
        'شركة التأمين',
        'نقابة',
        'رقم العضوية',
      ]) {
        expect(
          find.descendant(of: details, matching: find.text(text)),
          findsWidgets,
          reason: text,
        );
      }
      // Copy is a short text action on the number's row.
      expect(
        find.descendant(of: details, matching: key('insurance-copy')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('انسخ رقم العضوية'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(key('insurance-share'), findsOneWidget);
      // Delete is a quiet text button at the end, not an app bar icon.
      expect(tester.widget(key('insurance-delete')), isA<TextButton>());
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('a card with only its name still shows it', (tester) async {
      h.tall(tester);
      final (id, card) = (await tester.runAsync(() async {
        final id = await h.db.addProfile('فاطمة', sex: 'female');
        return (
          id,
          await h.db.saveInsuranceCard(profileId: id, label: 'نقابة'),
        );
      }))!;
      await h.open(tester, '/family/$id/insurance/$card');
      expect(
        find.descendant(
          of: find.byType(UsraListCard),
          matching: find.text('نقابة'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('warns before sharing; cancel sends nothing', (tester) async {
      h.tall(tester);
      final (id, card) = await seedCard(tester);
      await h.open(tester, '/family/$id/insurance/$card');
      await h.tapKey(tester, 'insurance-share');
      expect(key('insurance-share-warning'), findsOneWidget);
      await h.tapKey(tester, 'insurance-share-cancel');
      expect(key('insurance-share-warning'), findsNothing);
    });

    testWidgets('the watermark changes the picture, and a photo that can\'t be '
        'read is refused', (tester) async {
      final original = (await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 200, 120),
          Paint()..color = const Color(0xFF3366AA),
        );
        final image = await recorder.endRecording().toImage(200, 120);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      }))!;
      final marked = (await tester.runAsync(
        () => watermarkPhoto(original, 'نقابة · ٧ نوفمبر'),
      ))!;
      expect(marked, isNot(equals(original)));
      final size = (await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(marked);
        final frame = await codec.getNextFrame();
        return (frame.image.width, frame.image.height);
      }))!;
      expect(size, (200, 120));

      Object? error;
      await tester.runAsync(() async {
        try {
          await watermarkPhoto(Uint8List.fromList([0, 1, 2]), 'x');
        } catch (e) {
          error = e;
        }
      });
      expect(error, isNotNull);
    });
  });

  group('Doctors', () {
    testWidgets('an empty state, no placeholder doctors', (tester) async {
      h.tall(tester);
      await h.open(tester, '/doctors');
      expect(key('doctors-empty'), findsOneWidget);
      expect(key('doctor-add'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(UsraListRow), findsNothing);
    });

    testWidgets('each doctor is a row with a short call, no tinted chips', (
      tester,
    ) async {
      h.tall(tester);
      final doctor = (await tester.runAsync(
        () => h.db.saveDoctor(
          name: 'د. منى',
          specialty: 'باطنة',
          phone: '01012345678',
          feeMinor: 45000,
        ),
      ))!;
      await h.open(tester, '/doctors');
      expect(
        find.ancestor(
          of: key('doctor-call-$doctor'),
          matching: find.byType(UsraListRow),
        ),
        findsOneWidget,
      );
      await h.go(tester, '/doctors/$doctor');
      expect(find.byType(StatusChip), findsNothing);
      expect(
        tester.widget<Text>(key('doctor-summary')).data,
        startsWith('باطنة · '),
      );
      // One filled button: the call.
      expect(key('doctor-call'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });

  group('Spending', () {
    testWidgets('bars with the amount and its currency', (tester) async {
      h.tall(tester);
      final id = await seedSpending(tester);
      await h.open(tester, '/money?person=$id');
      expect(find.byType(LinearProgressIndicator), findsWidgets);
      expect(key('spending-row-type-visit'), findsOneWidget);
      expect(
        find.descendant(
          of: key('spending-row-type-visit'),
          matching: find.textContaining('ج.م'),
        ),
        findsOneWidget,
      );
    });
  });

  group('Selected segments read in ink', () {
    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('spending period and the language toggle, ${mode.name}', (
        tester,
      ) async {
        h.tall(tester);
        h.theme = mode;
        final id = await seedSpending(tester);
        await h.open(tester, '/money?person=$id');
        UsraColors colors(Finder f) =>
            Theme.of(tester.element(f)).extension<UsraColors>()!;
        final period = key('spending-period');
        expect(
          tester
              .widget<SegmentedButton<SpendingPeriod>>(period)
              .style!
              .foregroundColor!
              .resolve({WidgetState.selected}),
          colors(period).ink,
        );
        await h.go(tester, '/settings');
        final language = key('settings-language');
        expect(
          tester
              .widget<SegmentedButton<String>>(language)
              .style!
              .foregroundColor!
              .resolve({WidgetState.selected}),
          colors(language).ink,
        );
      });
    }
  });

  group('fits 320 px at double text', () {
    forEachSmallLayout(() => h, (tester) async {
      final (id, card) = await seedCard(tester);
      await tester.runAsync(
        () => h.db.addEvent(
          profileId: id,
          type: 'visit',
          occurredAt: DateTime.now(),
          dataJson: '{"doctorName":"سارة"}',
          costMinor: 40000,
          currency: 'EGP',
        ),
      );
      await tester.runAsync(
        () => h.db.saveDoctor(
          name: 'د. منى',
          specialty: 'باطنة',
          phone: '01012345678',
        ),
      );
      await h.open(tester, '/family/$id/insurance/$card');
      await walkScreen(tester);
      await h.go(tester, '/doctors');
      await walkScreen(tester);
      await h.go(tester, '/money');
      await walkScreen(tester);
    });
  });
}
