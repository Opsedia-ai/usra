import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/ocr/ocr_service.dart';
import 'package:usra/features/labs/lab_report_parser.dart';

import '../support/fake_ocr_service.dart';

/// A report as the recogniser often returns a table: one block per column,
/// each line at its row's height. [rows] are the cells left to right; an
/// empty cell is left out.
///
/// [tilt] turns the page (dy/dx), as a photo taken at an angle does: each
/// line's box is then the upright box around the turned text.
OcrResult _columns(
  List<List<String>> rows, {
  double top = 200,
  double tilt = 0,
}) {
  const xs = [20.0, 260.0, 360.0, 470.0, 600.0];
  final columns = <int, List<OcrLine>>{};
  for (final (r, row) in rows.indexed) {
    for (final (c, cell) in row.indexed) {
      if (cell.isEmpty) continue;
      final w = 8.0 * cell.length;
      const h = 18.0;
      // A little unevenness, as on any photo.
      final y = top + r * 30 + c * 1.5 + tilt * (xs[c] + w / 2);
      final box = Rect.fromCenter(
        center: Offset(xs[c] + w / 2, y + h / 2),
        width: w + h * tilt.abs(),
        height: h + w * tilt.abs(),
      );
      (columns[c] ??= []).add(OcrLine(cell, box));
    }
  }
  return OcrResult([
    for (final lines in columns.values)
      OcrBlock(
        lines.map((l) => l.text).join('\n'),
        lines.first.box.expandToInclude(lines.last.box),
        lines,
      ),
  ]);
}

const parser = LabReportParser();

void main() {
  test('a CBC from a big Cairo lab, read column by column', () {
    final ocr = _columns([
      ['مختبرات', '', '', '', ''],
      ['Patient Name: Mona Ahmed', '', '', 'Age: 34 Years'],
      ['Ref. By: Dr. Hany Saleh', '', '', 'Date: 12/03/2026'],
      ['Complete Blood Count', '', '', ''],
      ['Test', 'Result', 'Unit', 'Reference Range'],
      ['Hemoglobin', '11.2 L', 'g/dL', '12.0 - 15.5'],
      ['Hematocrit', '35.1', '%', '36 - 46'],
      ['RBCs', '4.31', 'x10^6/uL', '3.8 - 4.8'],
      ['MCV', '81.4', 'fL', '83 - 101'],
      ['WBCs', '7.2', 'x10^3/uL', '4.0 - 11.0'],
      ['Platelets', '250', 'x10^3/uL', '150 - 410'],
    ]);
    final scan = parser.parse(ocr);
    expect(scan.tests.map((t) => t.name), [
      'Hemoglobin',
      'Hematocrit',
      'RBCs',
      'MCV',
      'WBCs',
      'Platelets',
    ]);
    final hb = scan.tests.first;
    // The printed L is dropped: the app works the flag out itself.
    expect(hb.value, '11.2');
    expect(hb.unit, 'g/dL');
    // Shown as printed.
    expect(hb.range, '12.0 - 15.5');
    expect(hb.unsure, isEmpty);
    expect(scan.tests[2].unit, 'x10^6/uL');
    expect(scan.tests[3].unit, 'fL');
    expect(scan.date, DateTime(2026, 3, 12));
    expect(scan.orderedBy, 'Dr. Hany Saleh');
  });

  test('chemistry with one-sided ranges and an Arabic header', () {
    final scan = parser.parse(
      ocrOf([
        'ALFA LABORATORIES',
        'معامل',
        'Collection Date : 05-10-2026  Birth Date: 01/02/1960',
        'Fasting Blood Sugar  126  mg/dL  70 - 100',
        'HbA1c  7.4  %  4.0 - 5.6',
        'Cholesterol Total  215  mg/dl  Desirable < 200',
        'Triglycerides  140  mg/dL  Up to 150',
        'HDL Cholesterol  38  mg/dL  > 40',
        'S. Creatinine  1.1  mg/dL  0.6 - 1.2',
        'TSH  2.35  µIU/mL  0.27 - 4.20',
        'Comment: please correlate clinically',
      ]),
    );
    expect(scan.lab, 'ALFA LABORATORIES');
    expect(scan.date, DateTime(2026, 10, 5));
    final byName = {for (final t in scan.tests) t.name: t};
    expect(byName.keys, [
      'Fasting Blood Sugar',
      'HbA1c',
      'Cholesterol Total',
      'Triglycerides',
      'HDL Cholesterol',
      'S. Creatinine',
      'TSH',
    ]);
    expect(byName['HbA1c']!.unit, '%');
    expect(byName['Cholesterol Total']!.range, '< 200');
    expect(byName['Triglycerides']!.range, 'Up to 150');
    expect(byName['HDL Cholesterol']!.range, '> 40');
    expect(byName['TSH']!.unit, 'µIU/mL');
    expect(byName['TSH']!.range, '0.27 - 4.20');
    for (final t in scan.tests) {
      expect(t.unsure, isEmpty, reason: t.name);
    }
  });

  test('vitamins and iron: Arabic digits, several ranges, misreads', () {
    final scan = parser.parse(
      ocrOf([
        'المعمل  Al Mokhtabar',
        'Date ١٨/٠٧/٢٠٢٦',
        'Serum Ferritin  ١٢  ng/mL  13 - 150',
        'Vitamin D (25-OH)  18.5  ng/mL  Deficiency < 20  Sufficiency 30 - 100',
        'Vitamin B 12  2O5  pg/mL  197 - 771',
        'Serum Iron  4.5  ug/dL  60 - 170',
        'Unknownase  12  U/L',
      ]),
    );
    expect(scan.date, DateTime(2026, 7, 18));
    final byName = {for (final t in scan.tests) t.name: t};
    expect(byName['Serum Ferritin']!.value, '12');
    expect(byName['Serum Ferritin']!.unsure, isEmpty);
    // Several printed ranges: none is taken (so no flag); the person picks
    // the one that applies.
    final vitD = byName['Vitamin D (25-OH)']!;
    expect(vitD.range, '');
    expect(vitD.ranges, ['< 20', '30 - 100']);
    expect(vitD.unsure, containsAll([LabField.name, LabField.range]));
    // "Vitamin B 12" keeps its 12; "2O5" was "205".
    expect(byName['Vitamin B 12']!.value, '205');
    expect(byName['Vitamin B 12']!.unsure, {LabField.value});
    // Far below the range: maybe a lost decimal point, so check it.
    expect(byName['Serum Iron']!.unsure, contains(LabField.value));
    // Not a test the app knows, and no printed range.
    expect(byName['Unknownase']!.unsure, {LabField.name, LabField.range});
  });

  test('rows about the patient or the page are not results', () {
    final scan = parser.parse(
      ocrOf([
        'Patient ID 102345',
        'Age : 45 Y',
        'Tel 19911',
        'Lab No 2231',
        'Page 1 of 2',
        'Printed 13/03/2026 10:30',
        'Urine Glucose  Nil  Nil',
        'ESR 1st hour  22  mm/hr  0 - 15',
        'Sex Hormone Binding Globulin  45  nmol/L  18 - 144',
        'Name: Ahmed Ali 45',
      ]),
    );
    expect(scan.tests.map((t) => t.name), [
      'ESR 1st hour',
      'Sex Hormone Binding Globulin',
    ]);
    expect(scan.tests.first.unit, 'mm/hr');
    expect(scan.orderedBy, isNull);
  });

  test('values with a sign, thousands and printed flags', () {
    final crp = parser.parseRow('CRP  <0.5  mg/L  0 - 6')!;
    expect(crp.value, '<0.5');
    expect(crp.unsure, contains(LabField.value));

    final plt = parser.parseRow(
      'Platelets  250,000  H  /cumm  150,000 - 450,000',
    )!;
    expect(plt.value, '250000');
    expect(plt.unit, '/cumm');
    expect(plt.range, '150000 - 450000');
    // A comma was read: worth a look.
    expect(plt.unsure, contains(LabField.value));
    expect(parser.parseRow('Hemoglobin  12,5  g/dL  12 - 16')!.value, '12.5');
    // "0,250" isn't thousands.
    expect(parser.parseRow('TSH  0,250  uIU/mL  0.27 - 4.2')!.value, '0.25');
    expect(parser.parseRow('WBC  ٧٫٢  x10^3/uL  4 - 11')!.value, '7.2');

    final wbc = parser.parseRow('WBC  11.8*  x 10^3/uL  (4 - 11)')!;
    expect(wbc.value, '11.8');
    expect(wbc.unit, 'x10^3/uL');
    expect(wbc.range, '4 - 11');

    // A misread folded into the name stays marked.
    final b12 = parser.parseRow('Vitamin B 1O  2O5  pg/mL  197 - 771')!;
    expect(b12.unsure, contains(LabField.value));

    // A value with its unit run in.
    final run = parser.parseRow('WBCs  4.5x10^3/uL  4.0 - 11.0')!;
    expect(run.value, '4.5');
    expect(run.unit, 'x10^3/uL');
    final pct = parser.parseRow('HbA1c  6.1%  4.0 - 5.6')!;
    expect((pct.value, pct.unit), ('6.1', '%'));
    expect(pct.unsure, isEmpty);
    // "ESR 1st hour" keeps its "1st".
    expect(parser.parseRow('ESR 1st hour  22  mm/hr  0 - 15')!.value, '22');
    // A value equal to a range bound may be a range cell: check it.
    expect(
      parser.parseRow('MCV  83  fL  83 - 101')!.unsure,
      contains(LabField.value),
    );

    expect(parser.parseRow('Hematology'), isNull);
    expect(parser.parseRow('Test  Result  Unit  Normal Range'), isNull);
  });

  test('a photo with no table gives nothing', () {
    expect(parser.parse(OcrResult.empty).isEmpty, isTrue);
    expect(
      parser
          .parse(ocrOf(['Thank you for choosing us', 'www.lab.example']))
          .tests,
      isEmpty,
    );
  });

  group('a tilted photo', () {
    const table = [
      ['Patient Name: Mona Ahmed', '', '', 'Date: 12/03/2026'],
      ['Test', 'Result', 'Unit', 'Reference Range'],
      ['Hemoglobin', '11.2', 'g/dL', '12.0 - 15.5'],
      ['Hematocrit', '35.1', '%', '36 - 46'],
      ['MCV', '81.4', 'fL', '83 - 101'],
      ['WBCs', '7.2', 'x10^3/uL', '4.0 - 11.0'],
      ['Platelets', '250', 'x10^3/uL', '150 - 410'],
      ['Ferritin', '35', 'ng/mL', '13 - 150'],
    ];
    for (final tilt in [0.05, 0.1, 0.15, -0.08, -0.15]) {
      test('turned by $tilt still reads each row as one', () {
        final ocr = _columns(table, tilt: tilt);
        expect(LabReportParser.pageSlope(ocr.lines), closeTo(tilt, 0.02));
        final scan = parser.parse(ocr);
        expect(
          [for (final t in scan.tests) (t.name, t.value, t.unit, t.range)],
          [
            ('Hemoglobin', '11.2', 'g/dL', '12.0 - 15.5'),
            ('Hematocrit', '35.1', '%', '36 - 46'),
            ('MCV', '81.4', 'fL', '83 - 101'),
            ('WBCs', '7.2', 'x10^3/uL', '4.0 - 11.0'),
            ('Platelets', '250', 'x10^3/uL', '150 - 410'),
            ('Ferritin', '35', 'ng/mL', '13 - 150'),
          ],
        );
        expect(scan.date, DateTime(2026, 3, 12));
      });
    }

    test('the recogniser\'s own line angles are used when given', () {
      final lines = [
        for (var i = 0; i < 5; i++)
          OcrLine('x', Rect.fromLTWH(0, i * 30.0, 50, 18), angle: 5),
      ];
      expect(LabReportParser.pageSlope(lines), closeTo(0.0875, 0.001));
    });

    test('a row whose cells wander up or down is marked', () {
      final row = parser
          .rowsOf(
            OcrResult([
              OcrBlock('a', Rect.zero, [
                OcrLine('Hemoglobin', Rect.fromLTWH(20, 100, 80, 18), angle: 0),
                OcrLine(
                  '11.2',
                  const Rect.fromLTWH(260, 108, 32, 18),
                  angle: 0,
                ),
                OcrLine('g/dL', const Rect.fromLTWH(360, 95, 32, 18), angle: 0),
                OcrLine(
                  '12.0 - 15.5',
                  const Rect.fromLTWH(470, 104, 88, 18),
                  angle: 0,
                ),
              ]),
            ]),
          )
          .single;
      expect(row.loose, isTrue);
      final c = parser.parseRow(row.text, loose: row.loose)!;
      expect(c.unsure, containsAll([LabField.name, LabField.value]));
    });
  });

  test('the same row read twice counts once', () {
    final scan = parser.parse(
      ocrOf(['TSH  2.1  uIU/mL  0.27 - 4.2', 'TSH  2.1  uIU/mL  0.27 - 4.2']),
    );
    expect(scan.tests, hasLength(1));
  });
}
