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
    // Not dropped silently: counted, so the screen can say so.
    expect(scan.futureRows, 1);
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

  group('review of PR #12: the exact inputs', () {
    final birth = DateTime(2025, 1, 10);
    VaccineCardScan withBirth(List<String> lines) =>
        parser.parse(ocrOf(lines), today: today, birthDate: birth);

    test('V1: each vaccine on a row keeps its own dose word', () {
      expect(
        byKey(read(['12 months  OPV 5th dose + MMR 1st dose  10/01/2026'])),
        {'opv-5': DateTime(2026, 1, 10), 'mmr-1': DateTime(2026, 1, 10)},
      );
      expect(
        byKey(read(['سابين الجرعة الخامسة + MMR الجرعة الأولى  10/01/2026'])),
        {'opv-5': DateTime(2026, 1, 10), 'mmr-1': DateTime(2026, 1, 10)},
      );
      expect(
        byKey(read(['18 months  OPV 6th + MMR 2nd + DTP booster  15/07/2026'])),
        {
          'opv-6': DateTime(2026, 7, 15),
          'mmr-2': DateTime(2026, 7, 15),
          'dtp-1': DateTime(2026, 7, 15),
        },
      );
      // Two dose words that can't be tied to their vaccines: the age.
      final s = read(['12 months  OPV + MMR  5th  1st  10/01/2026']);
      expect(byKey(s), {
        'opv-5': DateTime(2026, 1, 10),
        'mmr-1': DateTime(2026, 1, 10),
      });
      // ...and with no age either: numbered by date, marked as guessed.
      final g = read(['OPV + MMR  5th  1st  10/01/2026']);
      expect(g.doses.every((d) => d.doseGuessed), isTrue);
    });

    test('V2: Arabic table, cells right to left: the given date is kept', () {
      // Columns right to left: age, vaccines, dose, date given, next visit.
      OcrLine cell(String t, double x, double y) =>
          OcrLine(t, Rect.fromLTWH(x, y, 180, 20));
      final ocr = OcrResult([
        OcrBlock('table', Rect.zero, [
          cell('شهرين', 900, 10),
          cell('سابين + سولك + الخماسي', 680, 10),
          cell('الجرعة الأولى', 470, 10),
          cell('3/5/2025', 260, 10),
          cell('3/7/2025', 50, 10),
          cell('٦ شهور', 900, 60),
          cell('سابين + سولك + الخماسي', 680, 60),
          cell('الجرعة الثالثة', 470, 60),
          cell('2/9/2025', 260, 60),
          cell('2/12/2026', 50, 60),
        ]),
      ]);
      final scan = parser.parse(ocr, today: today);
      expect(byKey(scan), {
        'opv-1': DateTime(2025, 5, 3),
        'ipv-1': DateTime(2025, 5, 3),
        'penta-1': DateTime(2025, 5, 3),
        'opv-3': DateTime(2025, 9, 2),
        'ipv-3': DateTime(2025, 9, 2),
        'penta-3': DateTime(2025, 9, 2),
      });
      // Two dates on each row: marked.
      expect(scan.doses.every((d) => d.dateUnsure), isTrue);
      expect(scan.futureRows, 0);
    });

    test('V3: an infant DTP dose is not the 18-month booster', () {
      final infant = read(['2 months  DTP  10/03/2025']);
      expect(infant.doses, isEmpty);
      expect(infant.unknown.single.date, DateTime(2025, 3, 10));
      final first = withBirth(['DTP 1st dose  10/03/2025']);
      expect(first.doses, isEmpty);
      expect(first.unknown, hasLength(1));
      // Not knowing the age, it isn't assumed to be the booster either.
      expect(read(['DTP 1st dose  10/03/2025']).doses, isEmpty);
      // The booster itself, at 18 months.
      expect(withBirth(['DTP booster  12/07/2026']).doses.single.key, 'dtp-1');
      // The same for the fourth hexavalent.
      expect(withBirth(['Hexyon 4th  10/03/2025']).doses, isEmpty);
    });

    test('V4: other DTaP combinations are listed, not counted', () {
      final scan = read([
        'Infanrix-IPV+Hib  2nd  10/05/2025',
        'Pentaxim  10/03/2025',
        'Infanrix hexa  3rd  10/07/2025',
      ]);
      expect(scan.doses.map((d) => d.key), ['hexa-3']);
      expect(scan.unknown.map((u) => u.text), ['Infanrix-IPV', 'Pentaxim']);
      expect(scan.unknown.map((u) => u.date), [
        DateTime(2025, 5, 10),
        DateTime(2025, 3, 10),
      ]);
    });

    test('V5: dates out of order or before the age are marked', () {
      final order = read(['Penta 1st 10/05/2025', 'Penta 2nd 10/03/2025']);
      expect(order.doses.map((d) => d.key).toSet(), {'penta-1', 'penta-2'});
      expect(order.doses.every((d) => d.dateUnsure), isTrue);

      // MMR at 12 months, dated when the child was 2 months old.
      final early = withBirth(['MMR 12 months  10/03/2025']);
      expect(early.doses.single.key, 'mmr-1');
      expect(early.doses.single.dateUnsure, isTrue);

      // A 9-month measles dose, then the 12-month MMR.
      final measles = withBirth([
        'Measles 9 months  10/10/2025',
        'MMR 12 months  10/01/2026',
      ]);
      final mmr2 = measles.doses.firstWhere((d) => d.key == 'mmr-2');
      expect(mmr2.dateUnsure, isTrue);
      expect(mmr2.doseGuessed, isTrue);

      // Doses in order, at their ages: not marked.
      final fine = withBirth(['Penta 1st 10/03/2025', 'Penta 2nd 10/05/2025']);
      expect(fine.doses.any((d) => d.dateUnsure), isFalse);
    });
  });
}
