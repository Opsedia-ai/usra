import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/ocr/medicine_name_extractor.dart';
import 'package:usra/core/ocr/ocr_dates.dart';
import 'package:usra/core/ocr/ocr_service.dart';
import 'package:usra/features/medicines/prescription_parser.dart';

import '../support/fake_ocr_service.dart';

void main() {
  late PrescriptionParser parser;

  setUpAll(() {
    parser = PrescriptionParser(
      MedicineNameExtractor.fromList(
        File(MedicineNameExtractor.asset).readAsStringSync(),
      ),
    );
  });

  PrescriptionScan read(List<String> lines, {List<double?>? confidences}) =>
      parser.parse(ocrOf(lines, confidences: confidences));

  group('printed English prescription', () {
    late PrescriptionScan scan;
    setUpAll(() {
      scan = read([
        'Dr. Ahmed Samir Mostafa',
        'Consultant of Pediatrics',
        'Cairo University',
        'Date: 12/03/2026',
        'Name: ________   Age: 4 y',
        'R/',
        '1- Augmentin 457mg/5ml susp',
        '5 ml every 12 hours for 7 days',
        '2- Cetal syrup',
        '5 ml 1x3 after meals',
        '3- Otrivin 0.05% nasal drops  2 drops twice daily',
        'Tel: 0123 456 7890   Clinic: 15 Tahrir St.',
      ]);
    });

    test('doctor and date from the header', () {
      expect(scan.doctor, 'Dr. Ahmed Samir Mostafa');
      expect(scan.date, DateTime(2026, 3, 12));
      expect(scan.unclear, isFalse);
    });

    test('three medicines, nothing from the header or footer', () {
      expect(scan.items.map((i) => i.name), ['Augmentin', 'Cetal', 'Otrivin']);
    });

    test('strength as printed, dose word for word', () {
      final aug = scan.items[0];
      expect(aug.strength, '457mg/5ml');
      expect(aug.dose, '5 ml every 12 hours for 7 days');
      expect(aug.everyHours, 12);
      expect(aug.timesPerDay, isNull);
      expect(aug.days, 7);
      expect(aug.known, isTrue);
      expect(aug.unsure, isEmpty);

      final cetal = scan.items[1];
      expect(cetal.strength, isNull);
      expect(cetal.dose, '5 ml 1x3 after meals');
      expect(cetal.timesPerDay, 3);
      expect(cetal.days, isNull, reason: 'no course length printed');

      final otrivin = scan.items[2];
      expect(otrivin.strength, '0.05%');
      expect(otrivin.dose, '2 drops twice daily');
      expect(otrivin.timesPerDay, 2);
    });
  });

  test('Arabic prescription with Arabic-Indic digits', () {
    final scan = read([
      'د/ محمد علي حسن',
      'استشاري الباطنة',
      'التاريخ: ٥/١١/٢٠٢٦',
      'Nexium 40mg tab',
      'قرص مرة يوميا قبل الأكل لمدة ١٤ يوم',
      'Motilium 10mg',
      '١x٣ قبل الأكل بربع ساعة',
      'Brufen 400mg',
      'قرص عند اللزوم',
    ]);
    expect(scan.doctor, 'د. محمد علي حسن');
    expect(scan.date, DateTime(2026, 11, 5));
    expect(scan.items.map((i) => i.name), ['Nexium', 'Motilium', 'Brufen']);

    final nexium = scan.items[0];
    expect(nexium.strength, '40mg');
    // Copied as read: Arabic digits and all.
    expect(nexium.dose, 'قرص مرة يوميا قبل الأكل لمدة ١٤ يوم');
    expect(nexium.timesPerDay, 1);
    expect(nexium.days, 14);

    final motilium = scan.items[1];
    expect(motilium.dose, '١x٣ قبل الأكل بربع ساعة');
    expect(motilium.timesPerDay, 3);
    expect(motilium.days, isNull);

    final brufen = scan.items[2];
    expect(brufen.dose, 'قرص عند اللزوم');
    expect(brufen.timesPerDay, isNull, reason: 'as needed: no schedule');
  });

  group('how often, only when printed plainly', () {
    int? times(String s) => PrescriptionParser.timesPerDayIn(s);

    test('1x3 style', () {
      expect(times('1x3'), 3);
      expect(times('1 x 2'), 2);
      expect(times('½x2'), 2);
      expect(times('1×1 at night'), 1);
      expect(times('١x٢'), 2);
      // Amount and times could be either way round: not read.
      expect(times('2x3'), isNull);
      // "x 5 days" is how long, not how often.
      expect(times('1 x 5 days'), isNull);
    });

    test('Arabic words', () {
      expect(times('مرة يوميا'), 1);
      expect(times('مرة واحدة يومياً'), 1);
      expect(times('مرتين في اليوم'), 2);
      expect(times('3 مرات يوميا'), 3);
      expect(times('٣ مرات يوميا بعد الأكل'), 3);
      expect(times('تلات مرات'), 3);
      expect(times('مرتين في الأسبوع'), isNull);
      expect(times('قبل الأكل'), isNull, reason: 'when, not how often');
      expect(times('بعد الأكل'), isNull);
      expect(times('عند اللزوم'), isNull);
    });

    test('English words and abbreviations', () {
      expect(times('once daily'), 1);
      expect(times('twice a day'), 2);
      expect(times('3 times daily'), 3);
      expect(times('TID'), 3);
      expect(times('b.i.d.'), 2);
      expect(times('once weekly'), isNull);
      expect(times('before meals'), isNull);
      expect(times('as needed'), isNull);
      // Two different answers: none.
      expect(times('1x3 twice daily'), isNull);
    });

    test('every N hours', () {
      expect(PrescriptionParser.everyHoursIn('every 8 hours'), 8);
      expect(PrescriptionParser.everyHoursIn('كل ٨ ساعات'), 8);
      expect(PrescriptionParser.everyHoursIn('q6h'), 6);
      // Not an interval the form offers.
      expect(PrescriptionParser.everyHoursIn('every 5 hours'), isNull);
    });

    test('course length', () {
      int? days(String s) => PrescriptionParser.daysIn(s);
      expect(days('for 7 days'), 7);
      expect(days('x 5 days'), 5);
      expect(days('لمدة ٥ أيام'), 5);
      expect(days('لمدة اسبوع'), 7);
      expect(days('لمدة أسبوعين'), 14);
      expect(days('for 2 weeks'), 14);
      expect(days('1x3 يوميا'), isNull, reason: 'يوميا is daily, not days');
      expect(days('for a month'), isNull);
      expect(days('5 days then 3 days'), isNull);
    });
  });

  group('never guesses', () {
    test('handwriting (low confidence): nothing suggested', () {
      final scan = read(
        [
          'Dr. Hany Fouad',
          'Date: 3/11/2026',
          'Augmentin 1g',
          '1x2',
          'Cetal',
          'Antinal',
        ],
        confidences: [0.95, 0.9, 0.42, 0.31, 0.38, 0.45],
      );
      expect(scan.items, isEmpty);
      expect(scan.unclear, isTrue);
      // The printed header can still be offered, to be checked.
      expect(scan.doctor, 'Dr. Hany Fouad');
    });

    test('one unsure line on a printed page is left out', () {
      final scan = read(
        ['Zyrtec 10mg tab', '1x1 at night', 'Flagyl 500mg', 'xx scribble'],
        confidences: [0.95, 0.92, 0.4, 0.9],
      );
      expect(scan.items.map((i) => i.name), ['Zyrtec']);
      expect(scan.items.single.timesPerDay, 1);
    });

    test('an unclear instruction line is left for the person', () {
      final scan = read(
        ['Zyrtec 10mg tab', 'one at bedtime'],
        confidences: [0.95, 0.4],
      );
      expect(scan.items.single.dose, '');
      expect(scan.items.single.unsure, contains(RxField.dose));
    });

    test('a name not in the list needs a strength or form, and is marked', () {
      final scan = read([
        'Tab. Novaxolin 250mg',
        '1x2',
        'Cairo Medical Center',
        'Internal Medicine',
      ]);
      expect(scan.items.single.name, 'Novaxolin');
      expect(scan.items.single.known, isFalse);
      expect(scan.items.single.unsure, contains(RxField.name));
      expect(scan.items.single.strength, '250mg');
    });

    test('a name read with a slip is marked', () {
      final scan = read(
        ['Augrnentin 1g tab', '1x2 for 5 days'],
        confidences: [0.9, 0.9],
      );
      expect(scan.items.single.name, 'Augmentin');
      expect(scan.items.single.unsure, contains(RxField.name));
    });

    test('a near spelling with no confidence (iOS) is not suggested', () {
      final scan = read(['Augrnentin 1g tab', '1x2 for 5 days']);
      expect(scan.items, isEmpty);
      expect(scan.unclear, isTrue);
    });

    test('handwriting under a printed letterhead is unclear, not empty', () {
      final scan = read(
        [
          'Dr. Sara Adel',
          'Pediatrics',
          'Cairo University',
          'Tel 0100 123 4567',
          'Clinic: Nasr City',
          'xx scrawl',
          'yy scrawl',
        ],
        confidences: [0.95, 0.95, 0.95, 0.95, 0.95, 0.3, 0.35],
      );
      expect(scan.items, isEmpty);
      expect(scan.unclear, isTrue);
    });

    test('no instructions: the dose stays empty and is marked', () {
      final scan = read(['Telfast 120mg']);
      expect(scan.items.single.name, 'Telfast');
      expect(scan.items.single.dose, '');
      expect(scan.items.single.unsure, contains(RxField.dose));
      expect(scan.items.single.timesPerDay, isNull);
    });

    test('blank photo', () {
      expect(parser.parse(OcrResult.empty).items, isEmpty);
      expect(parser.parse(OcrResult.empty).unclear, isFalse);
    });

    test('a page with no medicines is not "unclear"', () {
      final scan = read(['Dr. Sara Adel', 'Pediatrics', 'Tel 0100 123 4567']);
      expect(scan.items, isEmpty);
      expect(scan.unclear, isFalse);
    });
  });

  test('two columns (name left, instructions right) join into one row', () {
    const h = 20.0;
    OcrLine at(String t, double x, double y) =>
        OcrLine(t, Rect.fromLTWH(x, y, 200, h));
    final ocr = OcrResult([
      OcrBlock('names', const Rect.fromLTWH(10, 10, 200, 80), [
        at('Controloc 40mg', 10, 10),
        at('Ventolin syrup', 10, 50),
      ]),
      OcrBlock('doses', const Rect.fromLTWH(300, 10, 200, 80), [
        at('1x1 before breakfast', 300, 12),
        at('5 ml 1x3', 300, 52),
      ]),
    ]);
    final scan = parser.parse(ocr);
    expect(scan.items.map((i) => i.name), ['Controloc', 'Ventolin']);
    expect(scan.items[0].dose, '1x1 before breakfast');
    expect(scan.items[0].timesPerDay, 1);
    expect(scan.items[1].dose, '5 ml 1x3');
  });

  group('dates', () {
    test('day first, Arabic digits, two-digit years, year first', () {
      expect(datesIn('12/3/2026').single.date, DateTime(2026, 3, 12));
      expect(datesIn('١٢/٣/٢٠٢٦').single.date, DateTime(2026, 3, 12));
      expect(datesIn('12-03-26').single.date, DateTime(2026, 3, 12));
      expect(datesIn('2026/3/12').single.date, DateTime(2026, 3, 12));
      expect(datesIn('5.11.2026').single.date, DateTime(2026, 11, 5));
    });

    test('impossible dates are left out, not fixed', () {
      expect(datesIn('31/2/2026'), isEmpty);
      expect(datesIn('12/13/2026'), isEmpty);
      expect(datesIn('1/2 tab'), isEmpty);
    });

    test('a birth date or next visit is not the prescription date', () {
      final scan = read([
        'Dr. Mona Hassan',
        'DOB: 1/1/2022',
        'Next visit: 20/11/2026',
        'Zyrtec 5mg',
        '1x1',
        '4/11/2026',
      ]);
      expect(scan.date, DateTime(2026, 11, 4));
    });
  });

  test('doctor names match without titles, Arabic letter forms or case', () {
    expect(sameDoctorName('Ahmed Samir', 'Dr. Ahmed Samir Mostafa'), isTrue);
    expect(sameDoctorName('د. أحمد سمير', 'دكتور احمد سمير'), isTrue);
    expect(sameDoctorName('Dr Ahmed', 'Dr. Ahmed Samir'), isFalse);
    expect(sameDoctorName('Ahmed Samir', 'Ahmed Saad'), isFalse);
    expect(sameDoctorName('Mona', 'Dr. Mona'), isTrue);
  });
}
