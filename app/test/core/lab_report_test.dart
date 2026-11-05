import 'dart:convert';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/features/labs/lab_report.dart';
import 'package:usra/features/labs/lab_tests.dart';

MedicalEvent _event(String id, DateTime at, Map<String, Object?> data) =>
    MedicalEvent(
      id: id,
      profileId: 'p1',
      type: 'lab',
      occurredAt: at,
      dataJson: jsonEncode(data),
      updatedAt: at,
    );

void main() {
  group('printed range', () {
    test('reads the ways labs print it', () {
      (double?, double?, bool, bool, String?) read(String raw) {
        final r = LabRange.parse(raw);
        return (r.low, r.high, r.lowInclusive, r.highInclusive, r.text);
      }

      expect(read('4.0 - 11.0'), (4, 11, true, true, null));
      expect(read('(70–100)'), (70, 100, true, true, null));
      expect(read('١٢ - ١٦'), (12, 16, true, true, null));
      expect(read('< 200'), (null, 200, true, false, null));
      expect(read('<=200'), (null, 200, true, true, null));
      expect(read('≤ 200'), (null, 200, true, true, null));
      expect(read('Up to 40'), (null, 40, true, true, null));
      expect(read('>60'), (60, null, false, true, null));
      expect(read('≥ 60'), (60, null, true, true, null));
      expect(read('Negative'), (null, null, true, true, 'Negative'));
      expect(LabRange.parse('  '), LabRange.none);
      // Signed bounds and thousands.
      expect(read('-2 - 2'), (-2, 2, true, true, null));
      expect(read('-2 - +2'), (-2, 2, true, true, null));
      expect(read('150,000 - 450,000'), (150000, 450000, true, true, null));
      expect(read('١٥٠٬٠٠٠ - ٤٥٠٬٠٠٠'), (150000, 450000, true, true, null));
      // Shown as printed; built ones say which bounds are included.
      expect(LabRange.parse('Up to 150').format(), 'Up to 150');
      expect(const LabRange(low: 4, high: 11.5).format(), '4 - 11.5');
      expect(const LabRange(high: 200, highInclusive: false).format(), '< 200');
      expect(const LabRange(high: 200).format(), '≤ 200');
    });

    test('numbers are read strictly', () {
      expect(parseLabNumber('NaN').value, isNull);
      expect(parseLabNumber('Infinity').value, isNull);
      expect(parseLabNumber('0x1F').value, isNull);
      expect(parseLabNumber('1e5').value, isNull);
      expect(parseLabNumber('12.5'), (value: 12.5, rewritten: false));
      expect(parseLabNumber('250,000'), (value: 250000.0, rewritten: true));
      expect(parseLabNumber('12,5'), (value: 12.5, rewritten: true));
      // A leading zero or a short group means a decimal comma.
      expect(parseLabNumber('0,250').value, 0.25);
      expect(parseLabNumber('1,25').value, 1.25);
      expect(parseLabNumber('1,2,3').value, isNull);
      expect(parseLabNumber('١٢٫٥').value, 12.5);
      expect(parseLabNumber('١٬٢٥٠').value, 1250);
    });

    test('the flag comes from the printed range only', () {
      const range = LabRange(low: 12, high: 15.5);
      expect(labFlagOf(11.2, range), LabFlag.low);
      expect(labFlagOf(12, range), LabFlag.normal);
      expect(labFlagOf(15.5, range), LabFlag.normal);
      expect(labFlagOf(16, range), LabFlag.high);
      expect(labFlagOf(250, const LabRange(high: 200)), LabFlag.high);
      expect(labFlagOf(38, const LabRange(low: 40)), LabFlag.low);
      // "< 200" leaves 200 out; "up to 150" keeps 150 in.
      expect(labFlagOf(200, LabRange.parse('<200')), LabFlag.high);
      expect(labFlagOf(199, LabRange.parse('<200')), LabFlag.normal);
      expect(labFlagOf(150, LabRange.parse('Up to 150')), LabFlag.normal);
      expect(labFlagOf(150, LabRange.parse('≤ 150')), LabFlag.normal);
      expect(labFlagOf(40, LabRange.parse('> 40')), LabFlag.low);
      expect(labFlagOf(40, LabRange.parse('≥ 40')), LabFlag.normal);
      expect(labFlagOf(-5, LabRange.parse('-2 - 2')), LabFlag.low);
      // No range, a text range or no number: nothing to say.
      expect(labFlagOf(16, LabRange.none), LabFlag.unknown);
      expect(labFlagOf(16, const LabRange(text: 'Negative')), LabFlag.unknown);
      expect(labFlagOf(null, range), LabFlag.unknown);
    });
  });

  test('a report round-trips through the record data', () {
    const report = LabReport(
      lab: 'Alfa',
      orderedBy: 'د. هاني',
      tests: [
        LabTest(
          name: 'HbA1c',
          value: 7.4,
          unit: '%',
          range: LabRange(low: 4, high: 5.6),
        ),
        LabTest(
          name: 'Urine glucose',
          valueText: 'Nil',
          range: LabRange(text: 'Nil'),
        ),
        LabTest(
          name: 'LDL',
          value: 130,
          unit: 'mg/dL',
          range: LabRange(high: 130, highInclusive: false, printed: '<130'),
        ),
      ],
    );
    final data =
        jsonDecode(jsonEncode(report.toData())) as Map<String, Object?>;
    // Features that look for a test by name find it.
    expect(data['test'], 'HbA1c, Urine glucose, LDL');
    final back = LabReport.fromData(data);
    expect(back.lab, 'Alfa');
    expect(back.orderedBy, 'د. هاني');
    expect(back.tests, report.tests);
    expect(back.tests.first.flag, LabFlag.high);
    expect(back.tests.last.flag, LabFlag.high);
    expect(back.tests.last.range.format(), '<130');
  });

  test('a lab record from before reports reads as one test', () {
    final old = LabReport.fromData({
      'test': 'CBC',
      'value': 13,
      'unit': 'g/dL',
    });
    expect(old.tests, [const LabTest(name: 'CBC', value: 13, unit: 'g/dL')]);
    expect(old.tests.single.flag, LabFlag.unknown);
    expect(LabReport.fromData({'test': 'TSH'}).tests.single.shownValue, '');
    expect(LabReport.fromData(const {}).tests, isEmpty);
  });

  test('typed results: numbers in either script, else text', () {
    expect(LabTest.readValue('١٣٫٥'), (value: 13.5, text: null));
    expect(LabTest.readValue('12,5'), (value: 12.5, text: null));
    expect(LabTest.readValue('<0.5'), (value: null, text: '<0.5'));
    expect(LabTest.readValue(' '), (value: null, text: null));
    // Thousands, not a decimal comma.
    expect(LabTest.readValue('250,000'), (value: 250000.0, text: null));
    expect(LabTest.readValue('1,250.5'), (value: 1250.5, text: null));
  });

  test('names in Arabic and English are the same test', () {
    expect(labSeriesKey('السكر التراكمي'), 'hba1c');
    expect(labSeriesKey('Hb A1c'), 'hba1c');
    expect(labSeriesKey('S. Creatinine'), 'creatinine');
    expect(labSeriesKey('Serum Ferritin'), 'ferritin');
    expect(labSeriesKey('25-OH Vitamin D'), 'vitd');
    expect(labSeriesKey('HDL-Cholesterol'), 'hdl');
    expect(labSeriesKey('Cholesterol Total'), 'cholesterol');
    expect(labSeriesKey('Some new test'), 'some new test');
    expect(labUnitKey('µIU/mL'), labUnitKey('uIU/ml'));
    expect(labUnitKey('mg/dL'), isNot(labUnitKey('mmol/L')));
  });

  test('trends: one series per test and unit, oldest first', () {
    final events = [
      _event('e2', DateTime(2026, 6, 1), {
        'tests': [
          {'name': 'HbA1c', 'value': 6.9, 'unit': '%', 'low': 4, 'high': 5.6},
          {'name': 'Fasting glucose', 'value': 6.1, 'unit': 'mmol/L'},
        ],
      }),
      _event('e1', DateTime(2026, 1, 1), {
        'tests': [
          {'name': 'السكر التراكمي', 'value': 7.8, 'unit': '%'},
          {'name': 'FBS', 'value': 130, 'unit': 'mg/dL'},
          {'name': 'Urine', 'valueText': 'Nil'},
        ],
      }),
      // An old single-value record.
      _event('e0', DateTime(2025, 6, 1), {
        'test': 'HbA1c',
        'value': 8.2,
        'unit': '%',
      }),
    ];
    final series = labSeriesOf(events);
    final a1c = series.firstWhere((s) => s.testKey == 'hba1c');
    expect(a1c.points.map((p) => p.value), [8.2, 7.8, 6.9]);
    expect(a1c.name, 'HbA1c');
    expect(a1c.latest.flag, LabFlag.high);
    // Glucose in two units: two series, never converted.
    final glucose = series.where((s) => s.testKey == 'fbs').toList();
    expect(glucose.map((s) => s.unit).toSet(), {'mmol/L', 'mg/dL'});
    expect(glucose.every((s) => s.points.length == 1), isTrue);
    // Text results aren't charted.
    expect(series.any((s) => s.name == 'Urine'), isFalse);
    // Most recently done first.
    expect(series.first.latest.date, DateTime(2026, 6, 1));
  });

  test('a saved report can be changed in place, adding PDFs', () async {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(db.close);
    final p = await db.addProfile('فاطمة');
    final id = await db.addEvent(
      profileId: p,
      type: 'lab',
      occurredAt: DateTime(2026, 3, 12),
      dataJson: '{"test":"CBC"}',
      photos: ['attachments/a.jpg'],
      pdfs: ['attachments/r.pdf'],
    );
    await db.updateEvent(
      id,
      occurredAt: DateTime(2026, 3, 13),
      dataJson: '{"test":"CBC, TSH"}',
      costMinor: 35000,
      currency: 'EGP',
      pdfs: ['attachments/r2.pdf'],
    );
    final e = (await db.watchEvent(id).first)!;
    expect(e.occurredAt, DateTime(2026, 3, 13));
    expect(e.dataJson, '{"test":"CBC, TSH"}');
    expect(e.costMinor, 35000);
    final files = await db.watchAttachments(id).first;
    expect(
      [for (final a in files) (a.path, a.kind)],
      [
        ('attachments/a.jpg', 'photo'),
        ('attachments/r.pdf', 'pdf'),
        ('attachments/r2.pdf', 'pdf'),
      ],
    );

    await db.softDeleteEvent(id);
    expect(
      () => db.updateEvent(id, occurredAt: DateTime(2026), dataJson: '{}'),
      throwsStateError,
    );
  });
}
