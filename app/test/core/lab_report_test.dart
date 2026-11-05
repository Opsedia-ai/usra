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
      expect(LabRange.parse('4.0 - 11.0'), const LabRange(low: 4, high: 11));
      expect(LabRange.parse('(70–100)'), const LabRange(low: 70, high: 100));
      expect(LabRange.parse('١٢ - ١٦'), const LabRange(low: 12, high: 16));
      expect(LabRange.parse('< 200'), const LabRange(high: 200));
      expect(LabRange.parse('Up to 40'), const LabRange(high: 40));
      expect(LabRange.parse('>60'), const LabRange(low: 60));
      expect(LabRange.parse('Negative'), const LabRange(text: 'Negative'));
      expect(LabRange.parse('  '), LabRange.none);
      expect(const LabRange(low: 4, high: 11.5).format(), '4 - 11.5');
      expect(const LabRange(high: 200).format(), '< 200');
    });

    test('the flag comes from the printed range only', () {
      const range = LabRange(low: 12, high: 15.5);
      expect(labFlagOf(11.2, range), LabFlag.low);
      expect(labFlagOf(12, range), LabFlag.normal);
      expect(labFlagOf(15.5, range), LabFlag.normal);
      expect(labFlagOf(16, range), LabFlag.high);
      expect(labFlagOf(250, const LabRange(high: 200)), LabFlag.high);
      expect(labFlagOf(38, const LabRange(low: 40)), LabFlag.low);
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
      ],
    );
    final data =
        jsonDecode(jsonEncode(report.toData())) as Map<String, Object?>;
    // Features that look for a test by name find it.
    expect(data['test'], 'HbA1c, Urine glucose');
    final back = LabReport.fromData(data);
    expect(back.lab, 'Alfa');
    expect(back.orderedBy, 'د. هاني');
    expect(back.tests, report.tests);
    expect(back.tests.first.flag, LabFlag.high);
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
