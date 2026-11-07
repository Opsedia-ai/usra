import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/ocr/medicine_name_extractor.dart';

import '../support/fake_ocr_service.dart';

void main() {
  late MedicineNameExtractor extractor;

  setUpAll(() {
    extractor = MedicineNameExtractor.fromList(
      File(MedicineNameExtractor.asset).readAsStringSync(),
    );
  });

  List<String> labels(List<String> lines, {List<double>? heights}) => [
    for (final s in extractor.suggest(ocrOf(lines, heights: heights))) s.label,
  ];

  test('the bundled list loads a few hundred names', () {
    final text = File(MedicineNameExtractor.asset).readAsStringSync();
    final names = text
        .split('\n')
        .where((l) => l.trim().isNotEmpty && !l.startsWith('#'));
    expect(names.length, greaterThan(300));
    expect(text, contains('SEED LIST'));
  });

  test('Panadol Extra box: brand with its strength first', () {
    final s = extractor.suggest(
      ocrOf(
        [
          'Panadol® Extra',
          'Paracetamol 500mg / Caffeine 65mg',
          '24 Film-Coated Tablets',
          'GSK Consumer Healthcare',
          'Keep out of reach of children',
        ],
        heights: [60, 22, 20, 14, 12],
      ),
    );
    expect(s.first.label, 'Panadol Extra 500mg');
    expect(s.first.known, isTrue);
    expect(s.map((x) => x.name), contains('Paracetamol'));
    // "Panadol" alone isn't offered twice.
    expect(s.where((x) => x.name == 'Panadol'), isEmpty);
  });

  test('Augmentin 1g, written in capitals with a space', () {
    expect(
      labels(
        [
          'AUGMENTIN',
          '1 G',
          'amoxicillin/clavulanic acid',
          '14 film coated tablets',
          'Exp: 03/2027  B.N: 2304115',
        ],
        heights: [50, 30, 16, 14, 12],
      ).first,
      'Augmentin 1g',
    );
  });

  test('combined strength and syrup strength per volume', () {
    expect(
      MedicineNameExtractor.strengthIn('Augmentin 875/125 mg'),
      '875/125mg',
    );
    expect(MedicineNameExtractor.strengthIn('250 mg / 5 ml'), '250mg/5ml');
    expect(
      MedicineNameExtractor.strengthIn('Vidrop 2800 I.U./ml'),
      '2800IU/ml',
    );
    expect(MedicineNameExtractor.strengthIn('Dermovate 0,05 %'), '0.05%');
    expect(MedicineNameExtractor.strengthIn('Eltroxin 100 mcg'), '100mcg');
    // Bottle size is not a strength.
    expect(MedicineNameExtractor.strengthIn('Antinal syrup 120 ml'), isNull);
    expect(MedicineNameExtractor.strengthIn('Exp 12/2027'), isNull);
  });

  test('thousands separators are not decimals', () {
    expect(
      MedicineNameExtractor.strengthIn('Devarol-S 200,000 I.U.'),
      '200000IU',
    );
    expect(
      MedicineNameExtractor.strengthIn('Devarol-S 200.000 IU'),
      '200000IU',
    );
    expect(
      MedicineNameExtractor.strengthIn('Vidrop 1,000,000 IU'),
      '1000000IU',
    );
    expect(MedicineNameExtractor.strengthIn('Eltroxin 0,125 mg'), '0.125mg');
    expect(MedicineNameExtractor.strengthIn('Xarelto 2,5 mg'), '2.5mg');
  });

  test('inactive ingredients and the maker are not suggested', () {
    final s = extractor.suggest(
      ocrOf([
        'Concor 5 mg',
        'Excipients: magnesium stearate, zinc oxide',
        'Manufactured by Merck under licence, Egypt',
      ]),
    );
    expect(s.map((x) => x.label), ['Concor 5mg']);
  });

  test('a strength is not borrowed from another medicine\'s line', () {
    final s = extractor.suggest(
      ocrOf(['Concor', 'Lasix 40mg'], heights: [30, 30]),
    );
    expect(s.firstWhere((x) => x.name == 'Concor').strength, isNull);
    expect(s.firstWhere((x) => x.name == 'Lasix').strength, '40mg');
  });

  test('common OCR slips in the name and the strength', () {
    final s = extractor.suggest(
      ocrOf(['Augrnentin', '5OO rng'], heights: [40, 20]),
    );
    expect(s.first.label, 'Augmentin 500mg');
    expect(labels(['C0NCOR 5 mg']).first, 'Concor 5mg');
  });

  test('never suggests a dose from the instructions', () {
    final s = extractor.suggest(
      ocrOf([
        'Brufen 400',
        'Take 1 tablet 3 times daily after meals',
        'Do not exceed 2400 mg per day',
      ]),
    );
    expect(s.first.name, 'Brufen');
    expect(s.first.strength, isNull);
    for (final x in s) {
      expect(x.label, isNot(contains('2400')));
      expect(x.label.toLowerCase(), isNot(contains('tablet')));
    }
  });

  test('guesses an unlisted brand from the biggest print', () {
    final s = extractor.suggest(
      ocrOf(
        [
          'FLOTAC',
          '75 mg capsules',
          'Diclofenac sodium',
          'Manufactured by Novartis Pharma S.A.E. Cairo',
          'Store below 30°C',
        ],
        heights: [48, 20, 16, 10, 10],
      ),
    );
    // The brand in the biggest print comes before the listed generic.
    expect(s.first.label, 'Flotac 75mg');
    expect(s.first.known, isFalse);
    expect(s.map((x) => x.label), contains('Diclofenac 75mg'));
    expect(s.map((x) => x.name), isNot(contains('Store')));
  });

  test('nothing to suggest from Arabic or handwriting read as noise', () {
    expect(labels(['', '~ ., -', 'll1 /|', '12 3']), isEmpty);
    expect(extractor.suggest(ocrOf([])), isEmpty);
  });

  test('keeps at most the requested number', () {
    final s = extractor.suggest(
      ocrOf(['Panadol', 'Brufen', 'Concor', 'Lasix', 'Nexium', 'Eliquis']),
      max: 3,
    );
    expect(s, hasLength(3));
  });

  group('how sure a reading is', () {
    MedicineSuggestion first(List<String> lines) =>
        extractor.suggest(ocrOf(lines)).first;

    test('a listed name with its strength on the same line is sure', () {
      final s = first(['Panadol 500mg']);
      expect(s.nameSure, isTrue);
      expect(s.strengthSure, isTrue);
    });

    test('a near match of a listed name is unsure', () {
      final s = first(['Panadoi']);
      expect(s.name, 'Panadol');
      expect(s.known, isTrue);
      expect(s.nameSure, isFalse);
    });

    test('a name not in the list is unsure', () {
      expect(first(['Zzyxtra']).nameSure, isFalse);
    });

    test('a strength from another line is unsure', () {
      final s = first(['Panadol', '500mg']);
      expect(s.strength, '500mg');
      expect(s.strengthSure, isFalse);
    });

    test('a strength with characters corrected is unsure', () {
      final s = first(['Panadol 5OO mg']);
      expect(s.strength, '500mg');
      expect(s.strengthSure, isFalse);
    });
  });
}
