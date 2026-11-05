import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/ocr/ocr_service.dart';
import 'package:usra/features/children/egypt_vaccines.dart';
import 'package:usra/features/children/vaccine_card_parser.dart';

import '../support/fake_ocr_service.dart';

void main() {
  const parser = VaccineCardParser();
  final today = DateTime(2026, 11, 5);

  VaccineCardScan read(List<String> lines) =>
      parser.parse(ocrOf(lines), today: today);

  Map<String, DateTime> byKey(VaccineCardScan s) => {
    for (final d in s.doses) d.key: d.date,
  };

  group('Ministry of Health card, in Arabic', () {
    late VaccineCardScan scan;
    setUpAll(() {
      scan = read([
        'وزارة الصحة والسكان',
        'بطاقة التطعيمات الإجبارية',
        'اسم الطفل: ________',
        'تاريخ الميلاد: ١/٣/٢٠٢٥',
        'السن  التطعيم  الجرعة  تاريخ الإعطاء  موعد الجرعة التالية',
        'عند الولادة  شلل الأطفال سابين + الالتهاب الكبدي B  الجرعة الصفرية  ١/٣/٢٠٢٥',
        'خلال الأسبوع الأول  الدرن BCG  ٥/٣/٢٠٢٥',
        'شهرين  سابين + سولك + الخماسي  الجرعة الأولى  ٣/٥/٢٠٢٥  ٣/٧/٢٠٢٥',
        '٤ شهور  سابين + سولك + الخماسي  الجرعة الثانية  ٥/٧/٢٠٢٥',
        '٦ شهور  سابين + سولك + الخماسي  الجرعة الثالثة  ٢/٩/٢٠٢٥',
        '٩ شهور  سابين  الجرعة الرابعة  ',
        '١٢ شهر  سابين + الحصبة MMR  ',
        '١٨ شهر  سابين + MMR + الثلاثي البكتيري  ',
      ]);
    });

    test('doses with a date are read, by the card\'s own words', () {
      expect(byKey(scan), {
        'opv-0': DateTime(2025, 3, 1),
        'hepB-0': DateTime(2025, 3, 1),
        'bcg-1': DateTime(2025, 3, 5),
        'opv-1': DateTime(2025, 5, 3),
        'ipv-1': DateTime(2025, 5, 3),
        'penta-1': DateTime(2025, 5, 3),
        'opv-2': DateTime(2025, 7, 5),
        'ipv-2': DateTime(2025, 7, 5),
        'penta-2': DateTime(2025, 7, 5),
        'opv-3': DateTime(2025, 9, 2),
        'ipv-3': DateTime(2025, 9, 2),
        'penta-3': DateTime(2025, 9, 2),
      });
      expect(scan.doses.where((d) => d.doseGuessed), isEmpty);
    });

    test('rows with no date were not given; the birth date is not a dose', () {
      expect(scan.doses.map((d) => d.key), isNot(contains('opv-4')));
      expect(scan.doses.map((d) => d.key), isNot(contains('mmr-1')));
      expect(scan.unknown, isEmpty);
    });

    test('a second date on the row (next visit) is flagged', () {
      final penta1 = scan.doses.firstWhere((d) => d.key == 'penta-1');
      expect(penta1.dateUnsure, isTrue);
      expect(penta1.date, DateTime(2025, 5, 3));
      final penta2 = scan.doses.firstWhere((d) => d.key == 'penta-2');
      expect(penta2.dateUnsure, isFalse);
    });
  });

  test('what the Latin-only reader gets: English names, ages, d/m/y', () {
    final scan = read([
      'Vaccination Card',
      'Date of birth: 10/01/2025',
      'At birth  OPV 0  HBV  10/01/2025',
      'BCG  20/01/2025',
      '2 months  OPV + IPV + Penta  10/03/2025',
      '4 months  OPV + IPV + Penta  12/05/2025',
      '12 months  OPV  MMR  10/01/2026',
      '18 months  OPV  MMR  DPT booster  15/07/2026',
    ]);
    expect(byKey(scan), {
      'opv-0': DateTime(2025, 1, 10),
      'hepB-0': DateTime(2025, 1, 10),
      'bcg-1': DateTime(2025, 1, 20),
      'opv-1': DateTime(2025, 3, 10),
      'ipv-1': DateTime(2025, 3, 10),
      'penta-1': DateTime(2025, 3, 10),
      'opv-2': DateTime(2025, 5, 12),
      'ipv-2': DateTime(2025, 5, 12),
      'penta-2': DateTime(2025, 5, 12),
      'opv-5': DateTime(2026, 1, 10),
      'mmr-1': DateTime(2026, 1, 10),
      'opv-6': DateTime(2026, 7, 15),
      'mmr-2': DateTime(2026, 7, 15),
      'dtp-1': DateTime(2026, 7, 15),
    });
  });

  test('hexavalent: one shot, one dose, standing for penta and IPV', () {
    final scan = read([
      'Hexyon  1st dose  2/3/2026',
      'Hexyon  2nd dose  4/5/2026',
    ]);
    expect(scan.doses.map((d) => d.key), ['hexa-1', 'hexa-2']);
    expect(
      scan.doses.first.kinds,
      containsAll({VaccineKind.hexa, VaccineKind.penta, VaccineKind.ipv}),
    );
  });

  test('no dose word, no age: numbered by date, and marked as guessed', () {
    final scan = read([
      'Prevenar  10/6/2025',
      'Prevenar  8/4/2025',
      'Rotarix  8/4/2025',
    ]);
    expect(byKey(scan), {
      'pcv-1': DateTime(2025, 4, 8),
      'rota-1': DateTime(2025, 4, 8),
      'pcv-2': DateTime(2025, 6, 10),
    });
    expect(scan.doses.every((d) => d.doseGuessed), isTrue);
  });

  test('a dated row the phone can\'t name is listed to map or skip', () {
    final scan = read(['BCG  5/3/2025', 'Xq lluo ,Jl  3/5/2025', '٧/٧/٢٠٢٥']);
    expect(scan.doses.single.key, 'bcg-1');
    expect(scan.unknown, hasLength(2));
    expect(scan.unknown[0].text, 'Xq lluo ,Jl');
    expect(scan.unknown[0].date, DateTime(2025, 5, 3));
    expect(scan.unknown[1].text, '');
    expect(scan.unknown[1].date, DateTime(2025, 7, 7));
  });

  test('a dose row that also prints its next visit is still read', () {
    final scan = read(['MMR  1st dose  1/3/2026  next  1/9/2026']);
    expect(scan.doses.single.key, 'mmr-1');
    expect(scan.doses.single.date, DateTime(2026, 3, 1));
    // A row only about the next visit is not a dose.
    expect(read(['Next visit: 1/9/2025']).isEmpty, isTrue);
  });

  test('ages in years', () {
    expect(VaccineCardParser.ageMonthsIn('4 6 years'), 72);
    expect(VaccineCardParser.ageMonthsIn('2 سنه'), 24);
    expect(VaccineCardParser.ageMonthsIn('جرعه صفر'), isNull);
    expect(VaccineCardParser.ordinalIn('جرعه صفر'), 0);
  });

  test('a date in the future is the next visit, not a dose', () {
    final scan = read(['MMR  12 months  1/12/2026']);
    expect(scan.isEmpty, isTrue);
  });

  test('the same dose twice with different dates is flagged', () {
    final scan = read(['MMR 1st dose 1/3/2026', 'MMR 1st dose 8/3/2026']);
    expect(scan.doses.single.key, 'mmr-1');
    expect(scan.doses.single.dateUnsure, isTrue);
  });

  test('ordinals and ages in Arabic and English', () {
    expect(VaccineCardParser.ordinalIn('الجرعه الصفريه'), 0);
    expect(VaccineCardParser.ordinalIn('الجرعه الاولي'), 1);
    expect(VaccineCardParser.ordinalIn('3rd dose'), 3);
    expect(VaccineCardParser.ordinalIn('خلال الشهر الاول'), isNull);
    expect(VaccineCardParser.ageMonthsIn('عند الولاده'), 0);
    expect(VaccineCardParser.ageMonthsIn('شهرين'), 2);
    expect(VaccineCardParser.ageMonthsIn('9 شهور'), 9);
    expect(VaccineCardParser.ageMonthsIn('سنه ونصف'), 18);
    expect(VaccineCardParser.ageMonthsIn('سنه'), 12);
    expect(VaccineCardParser.ageMonthsIn('4 months'), 4);
  });

  test('a tilted photo still keeps each row together', () {
    // Each row's cells drift down 1px per 10px across the page.
    OcrLine at(String t, double x, double y) =>
        OcrLine(t, Rect.fromLTWH(x, y + x / 10, 150, 20));
    final ocr = OcrResult([
      OcrBlock('a', Rect.zero, [
        at('BCG', 10, 10),
        at('MMR 1st', 10, 60),
        at('OPV 0', 10, 110),
      ]),
      OcrBlock('b', Rect.zero, [
        at('1/3/2025', 300, 10),
        at('2/3/2026', 300, 60),
        at('1/3/2025', 300, 110),
      ]),
    ]);
    final scan = parser.parse(ocr, today: today);
    expect(byKey(scan), {
      'bcg-1': DateTime(2025, 3, 1),
      'opv-0': DateTime(2025, 3, 1),
      'mmr-1': DateTime(2026, 3, 2),
    });
  });

  test('card doses map onto the route the child is on', () {
    final government = egyptSchedule(VaccineRoute.government).map((d) => d.key);
    final hexavalent = egyptSchedule(VaccineRoute.hexavalent).map((d) => d.key);
    CardDose dose(Set<VaccineKind> kinds, int n) =>
        CardDose(kinds: kinds, dose: n, date: DateTime(2025), row: '');
    final hexa = vaccineKindsOf('Hexyon');
    expect(cardDoseKeys(dose(hexa, 2), hexavalent), ['hexa-2']);
    expect(cardDoseKeys(dose(hexa, 2), government), ['penta-2', 'ipv-2']);
    expect(cardDoseKeys(dose(hexa, 4), government), ['dtp-1']);
    expect(cardDoseKeys(dose({VaccineKind.dtp}, 1), hexavalent), ['hexa-4']);
    expect(cardDoseKeys(dose({VaccineKind.penta}, 1), hexavalent), isEmpty);
    expect(cardDoseKeys(dose({VaccineKind.opv}, 0), government), ['opv-0']);
  });
}
