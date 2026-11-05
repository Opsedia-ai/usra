import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/ocr/ocr_service.dart';
import 'package:usra/features/labs/lab_report_parser.dart';

import '../support/fake_ocr_service.dart';

/// A report as the recogniser often returns a table: one block per column,
/// each line at its row's height. [rows] are the cells left to right; an
/// empty cell is left out.
OcrResult _columns(List<List<String>> rows, {double top = 200}) {
  const xs = [20.0, 260.0, 360.0, 470.0, 600.0];
  final columns = <int, List<OcrLine>>{};
  for (final (r, row) in rows.indexed) {
    for (final (c, cell) in row.indexed) {
      if (cell.isEmpty) continue;
      // A little skew, as on a photo.
      final y = top + r * 30 + c * 1.5;
      (columns[c] ??= []).add(
        OcrLine(cell, Rect.fromLTWH(xs[c], y, 8.0 * cell.length, 18)),
      );
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
    expect(hb.range, '12 - 15.5');
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
    expect(byName['Triglycerides']!.range, '< 150');
    expect(byName['HDL Cholesterol']!.range, '> 40');
    expect(byName['TSH']!.unit, 'µIU/mL');
    expect(byName['TSH']!.range, '0.27 - 4.2');
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
    // Several printed ranges: the person picks the right one.
    expect(byName['Vitamin D (25-OH)']!.unsure, {
      LabField.name,
      LabField.range,
    });
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
      ]),
    );
    expect(scan.tests.map((t) => t.name), ['ESR 1st hour']);
    expect(scan.tests.single.unit, 'mm/hr');
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

    final wbc = parser.parseRow('WBC  11.8*  x 10^3/uL  (4 - 11)')!;
    expect(wbc.value, '11.8');
    expect(wbc.unit, 'x10^3/uL');
    expect(wbc.range, '4 - 11');

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
}
