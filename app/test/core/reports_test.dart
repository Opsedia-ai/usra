import 'dart:convert';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart' show TtfParser;
import 'package:usra/core/database/app_database.dart';
import 'package:usra/features/children/egypt_vaccines.dart';
import 'package:usra/features/children/growth.dart' show addMonths;
import 'package:usra/features/labs/lab_report.dart';
import 'package:usra/features/reports/doctor_summary.dart';
import 'package:usra/features/reports/report.dart';
import 'package:usra/features/reports/vaccination_record.dart';
import 'package:usra/l10n/app_localizations.dart';

import '../support/pdf_text.dart';

final _ar = lookupAppLocalizations(const Locale('ar'));
final _en = lookupAppLocalizations(const Locale('en'));
final _now = DateTime(2026, 11, 5, 10);

Profile _profile({
  String name = 'ليلى',
  DateTime? birthDate,
  String? sex = 'female',
  String? allergies,
  String? conditions,
  String? bloodType,
}) => Profile(
  id: 'p1',
  displayName: name,
  birthDate: birthDate,
  sex: sex,
  simpleMode: false,
  bloodType: bloodType,
  allergies: allergies,
  conditions: conditions,
  updatedAt: _now,
);

var _n = 0;
MedicalEvent _event(
  String type,
  DateTime at,
  Map<String, Object?> data, {
  String? doctorId,
}) => MedicalEvent(
  id: 'e${_n++}',
  profileId: 'p1',
  type: type,
  occurredAt: at,
  doctorId: doctorId,
  dataJson: jsonEncode(data),
  updatedAt: at,
);

Medicine _medicine(
  String name, {
  String? strength,
  String? instructions,
  bool active = true,
  DateTime? endOn,
}) => Medicine(
  id: 'm$name',
  profileId: 'p1',
  name: name,
  strength: strength,
  instructions: instructions,
  stoppedWithPrescription: false,
  startOn: DateTime.utc(2026, 10, 1),
  endOn: endOn,
  photosJson: '[]',
  active: active,
  updatedAt: _now,
);

/// The text of a PDF made without compression: the font's ToUnicode map
/// lists every character drawn, so Arabic shows there.
String _pdfText(List<int> bytes) => latin1.decode(bytes);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeDateFormatting);

  group('vaccination record (C4)', () {
    final birth = addMonths(DateTime(2026, 11, 5), -7);
    final events = [
      // Ticked in Arabic on the checklist.
      _event('vaccine', DateTime(birth.year, birth.month, birth.day, 12), {
        'vaccine': 'الدرن (BCG)',
        'dose': 1,
        'source': 'checklist',
      }),
      _event('vaccine', addMonths(birth, 2), {
        'vaccine': 'الخماسي',
        'dose': 1,
        'source': 'checklist',
      }),
      // Typed by hand, not on the schedule.
      _event('vaccine', addMonths(birth, 3), {'vaccine': 'Yellow fever'}),
      _event(VaccinePlanFields.type, birth, {
        'route': 'government',
        'optional': <String>[],
        'notes': {'penta-1': 'فضلت سخنة يوم'},
      }),
    ];

    test('name, birth date, route, doses given, upcoming, disclaimer', () {
      final r = vaccinationRecord(
        l: _en,
        profile: _profile(birthDate: birth),
        events: events,
        now: _now,
      )!;
      final text = r.allText.toList();
      expect(r.rtl, isFalse);
      expect(r.title, 'Vaccination record');
      expect(text, contains('ليلى'));
      expect(text, contains('Government (health office)'));
      expect(r.disclaimer, contains('Not an official vaccination certificate'));
      expect(r.appLine, contains('Usra'));
      expect(r.generated, contains('2026'));
      final given = r.sections.firstWhere((s) => s.id == 'given');
      // In English, whatever language the record was ticked in.
      expect(
        given.rows.map((row) => row.first),
        contains('Pentavalent, dose 1'),
      );
      // Off the schedule: as the family wrote it.
      expect(given.rows.map((row) => row.first), contains('Yellow fever'));
      // Oldest first.
      expect(given.rows.last.first, 'Yellow fever');
      // Notes only when asked for.
      expect(given.columns, isNot(contains('Notes')));
      expect(text, isNot(contains('فضلت سخنة يوم')));
      final upcoming = r.sections.firstWhere((s) => s.id == 'upcoming');
      expect(upcoming.rows, isNotEmpty);
      expect(
        upcoming.rows.map((row) => row.first),
        contains(startsWith('MMR')),
      );
    });

    test('notes when the family chooses; Arabic is right to left', () {
      final r = vaccinationRecord(
        l: _ar,
        profile: _profile(birthDate: birth),
        events: events,
        now: _now,
        includeNotes: true,
      )!;
      expect(r.rtl, isTrue);
      expect(r.title, 'سجل التطعيمات');
      final given = r.sections.firstWhere((s) => s.id == 'given');
      expect(given.columns, contains('ملاحظات'));
      final penta = given.rows.firstWhere(
        (row) => row.first.contains('الخماسي'),
      );
      expect(penta.last, 'فضلت سخنة يوم');
      expect(r.disclaimer, contains('مش شهادة تطعيم رسمية'));
    });

    test('rotavirus past its age: "too late, ask the doctor"', () {
      final r = vaccinationRecord(
        l: _en,
        profile: _profile(birthDate: birth),
        events: [
          _event(VaccinePlanFields.type, birth, {
            'route': 'government',
            'optional': ['rota'],
          }),
        ],
        now: _now,
      )!;
      final upcoming = r.sections.firstWhere((s) => s.id == 'upcoming');
      final rota = upcoming.rows.where((row) => row.first.startsWith('Rota'));
      expect(rota, isNotEmpty);
      expect(
        rota.map((row) => row.last),
        everyElement('Too late for this vaccine: ask the doctor'),
      );
    });

    test('none without a birth date', () {
      expect(
        vaccinationRecord(
          l: _en,
          profile: _profile(),
          events: events,
          now: _now,
        ),
        isNull,
      );
    });

    test('Arabic PDF: A4, Amiri embedded, Arabic shaped in the text', () async {
      final r = vaccinationRecord(
        l: _ar,
        profile: _profile(birthDate: birth),
        events: events,
        now: _now,
      )!;
      final bytes = await renderReportPdf(
        r,
        await ReportFonts.load(),
        compress: false,
      );
      final pdf = _pdfText(bytes);
      expect(pdf, startsWith('%PDF'));
      expect(pdf, contains('/MediaBox[0 0 595.27559 841.88976]'));
      expect(pdf, contains('/FontName/Amiri-Regular'));
      expect(pdf, contains('/FontName/Amiri-Bold'));
      // Shaped into Arabic presentation forms (U+FExx), e.g. initial
      // and final forms, rather than drawn as separate letters.
      expect(
        RegExp(r'<[0-9A-F]{4}> <FE[89A-F][0-9A-F]>').hasMatch(pdf),
        isTrue,
      );
      // Nothing about the person in the file's properties.
      expect(pdf, isNot(contains('/Author')));
      expect(pdf, isNot(contains('/Subject')));
    });
  });

  group('doctor summary (C10)', () {
    final adult = _profile(
      name: 'Hoda',
      birthDate: DateTime.utc(1960, 3, 1),
      bloodType: 'O+',
      allergies: 'Penicillin\nPeanuts',
      conditions: 'Type 2 diabetes',
    );
    final inputs = SummaryInputs(
      profile: adult,
      events: [
        _event('lab', DateTime(2026, 10, 20), {
          'tests': [
            {'name': 'HbA1c', 'value': 7.2, 'unit': '%', 'low': 4, 'high': 5.6},
            {'name': 'Urine', 'valueText': 'Clear', 'rangeText': 'Clear'},
          ],
        }),
        _event('visit', DateTime(2026, 10, 18), {
          'reason': 'Check-up',
          'diagnosis': 'Stable',
        }, doctorId: 'd1'),
        _event('lab', DateTime(2026, 6, 1), {
          'test': 'Glucose',
          'value': 140,
          'unit': 'mg/dL',
        }),
        // Not yet: never in "recent visits".
        _event('visit', DateTime(2026, 12, 1), {'reason': 'Future'}),
      ],
      medicines: [
        (
          _medicine(
            'Glucophage',
            strength: '500 mg',
            instructions: 'قرص بعد الفطار والعشا',
          ),
          DoseSchedule(
            id: 's1',
            medicineId: 'mGlucophage',
            times: '08:00,20:00',
            amount: '1 tablet',
            updatedAt: _now,
          ),
        ),
        (_medicine('Panadol'), null),
        (_medicine('Augmentin', active: false), null),
        (_medicine('Flagyl', endOn: DateTime.utc(2026, 10, 7)), null),
      ],
      doctors: {'d1': Doctor(id: 'd1', name: 'Dr. Samir', updatedAt: _now)},
    );

    test('all sections, in order; child-only ones not offered', () {
      final r = doctorSummary(
        l: _en,
        inputs: inputs,
        sections: SummarySection.values.toSet(),
        now: _now,
      );
      expect(r.sections.map((s) => s.id), [
        'basics',
        'allergies',
        'conditions',
        'medicines',
        'visits',
        'labs',
      ]);
      final text = r.allText.toList();
      expect(text, containsAll(['Hoda', 'O+', 'Penicillin', 'Peanuts']));
      expect(text, contains('Type 2 diabetes'));
      expect(text, contains('66 years'));
      final meds = r.sections.firstWhere((s) => s.id == 'medicines');
      expect(meds.rows.map((row) => row.first), [
        'Glucophage 500 mg',
        'Panadol',
      ]);
      // Dose and instructions word for word.
      expect(meds.rows.first.last, contains('1 tablet'));
      expect(meds.rows.first.last, contains('قرص بعد الفطار والعشا'));
      expect(meds.rows.first.last, contains('8:00'));
      expect(meds.rows.last.last, contains('When needed'));
      final visits = r.sections.firstWhere((s) => s.id == 'visits');
      expect(visits.rows, hasLength(1));
      expect(visits.rows.single, contains('Dr. Samir'));
      expect(visits.rows.single.last, 'Check-up · Stable');
      final labs = r.sections.firstWhere((s) => s.id == 'labs');
      expect(labs.rows.map((row) => row[1]), ['HbA1c', 'Urine', 'Glucose']);
      // The lab's flag, from the printed range only.
      expect(labs.rows.first[2], '7.2 % · High');
      expect(labs.rows.first[3], '4 - 5.6');
      expect(labs.rows[1][2], 'Clear');
      expect(labs.rows[2][2], '140 mg/dL');
      expect(r.disclaimer, contains('Informational only'));
    });

    test('only the sections picked', () {
      final r = doctorSummary(
        l: _en,
        inputs: inputs,
        sections: {
          SummarySection.allergies,
          SummarySection.medicines,
          SummarySection.growth,
        },
        now: _now,
      );
      expect(r.sections.map((s) => s.id), ['allergies', 'medicines']);
      final text = r.allText.join('\n');
      expect(text, contains('Penicillin'));
      expect(text, isNot(contains('Type 2 diabetes')));
      expect(text, isNot(contains('O+')));
      expect(text, isNot(contains('HbA1c')));
      expect(text, isNot(contains('Dr. Samir')));
    });

    test('a child: growth with WHO percentiles and vaccines', () {
      final birth = addMonths(DateTime(2026, 11, 5), -10);
      final child = SummaryInputs(
        profile: _profile(name: 'ليلى', birthDate: birth, sex: 'female'),
        events: [
          _event('growth', DateTime(2026, 11, 1), {'weightKg': 8.5}),
          _event('growth', DateTime(2026, 9, 1), {
            'weightKg': 7.9,
            'heightCm': 68.0,
          }),
          _event('vaccine', addMonths(birth, 2), {
            'vaccine': 'الخماسي',
            'dose': 1,
          }),
          // Off the schedule: a travel vaccine.
          _event('vaccine', addMonths(birth, 4), {'vaccine': 'الحمى الصفراء'}),
        ],
      );
      expect(
        summarySectionsFor(child.profile, _now),
        contains(SummarySection.growth),
      );
      final r = doctorSummary(
        l: _ar,
        inputs: child,
        sections: {SummarySection.growth, SummarySection.vaccines},
        now: _now,
      );
      expect(r.rtl, isTrue);
      expect(r.sections.map((s) => s.id), ['growth', 'vaccines']);
      final growth = r.sections.first;
      // Latest of each measurement.
      expect(growth.rows, hasLength(2));
      expect(growth.rows.first[0], 'الوزن (كجم)');
      expect(growth.rows.first[3], isNotEmpty);
      expect(growth.note, isNotNull);
      final vaccines = r.sections.last;
      expect(vaccines.fields.first.label, 'طريقة التطعيم');
      expect(vaccines.fields.first.value, 'حكومي (مكتب الصحة)');
      expect(vaccines.fields[1].value, contains('اتاخدت'));
      // Latest first, the travel vaccine included.
      expect(vaccines.rows.map((row) => row.first), [
        'الحمى الصفراء',
        contains('الخماسي'),
      ]);
    });

    test('older child: no schedule counts, only doses given', () {
      final birth = DateTime(2017, 3, 1);
      final r = doctorSummary(
        l: _en,
        inputs: SummaryInputs(
          profile: _profile(name: 'Omar', birthDate: birth, sex: 'male'),
          events: [
            _event('vaccine', DateTime(2018, 3, 1), {
              'vaccine': 'MMR',
              'dose': 1,
            }),
          ],
        ),
        sections: {SummarySection.vaccines},
        now: _now,
      );
      final vaccines = r.sections.single;
      // Route only: "1 of 20 given" would read as missed vaccines.
      expect(vaccines.fields.map((f) => f.label), ['Vaccination route']);
      expect(r.allText.join(), isNot(contains('doses in the plan given')));
      expect(r.allText.join(), isNot(contains('Overdue')));
      expect(vaccines.rows.single.first, startsWith('MMR'));
    });

    test('a record dated later today counts; tomorrow does not', () {
      final r = doctorSummary(
        l: _en,
        inputs: SummaryInputs(
          profile: _profile(name: 'Ali'),
          events: [
            _event('visit', DateTime(2026, 11, 6), {'reason': 'Tomorrow'}),
            _event('visit', DateTime(2026, 11, 5, 23), {'reason': 'Tonight'}),
          ],
        ),
        sections: {SummarySection.visits},
        now: _now,
      );
      expect(r.sections.single.rows.single.last, 'Tonight');
    });

    test('empty sections say so', () {
      final r = doctorSummary(
        l: _ar,
        inputs: SummaryInputs(
          profile: _profile(name: 'Ali'),
          events: const [],
        ),
        sections: {SummarySection.allergies, SummarySection.labs},
        now: _now,
      );
      expect(r.sections.every((s) => s.isEmpty), isTrue);
      expect(r.allText, contains('مفيش حاجة متسجلة'));
    });

    test('English PDF is drawn left to right with the same font', () async {
      final r = doctorSummary(
        l: _en,
        inputs: inputs,
        sections: SummarySection.values.toSet(),
        now: _now,
      );
      final pdf = _pdfText(
        await renderReportPdf(r, await ReportFonts.load(), compress: false),
      );
      expect(pdf, contains('/FontName/Amiri-Regular'));
      // Latin letters drawn, and the Arabic instructions too.
      expect(pdf, contains('<0048>')); // H
      expect(RegExp(r'<FE[89A-F][0-9A-F]>').hasMatch(pdf), isTrue);
    });
  });

  group('lab ranges in the PDF', () {
    test('one-sided, open and printed ranges in characters the font has', () {
      expect(labRangeText(const LabRange(high: 4.5)), '<= 4.5');
      expect(
        labRangeText(const LabRange(high: 200, highInclusive: false)),
        '< 200',
      );
      expect(labRangeText(const LabRange(low: 60)), '>= 60');
      expect(
        labRangeText(const LabRange(low: 60, lowInclusive: false)),
        '> 60',
      );
      expect(labRangeText(LabRange.parse('≤ 150')), '<= 150');
      expect(labRangeText(LabRange.parse('Negative')), 'Negative');
      expect(labRangeText(LabRange.none), '');
    });

    test('a report: value, unit, flag and range, old records too', () {
      final r = doctorSummary(
        l: _ar,
        inputs: SummaryInputs(
          profile: _profile(name: 'Ali'),
          events: [
            _event('lab', DateTime(2026, 10, 1), {
              'tests': [
                {
                  'name': 'LDL',
                  'value': 210,
                  'unit': 'mg/dL',
                  'high': 200,
                  'highOpen': true,
                },
                {'name': 'Vit D', 'value': 12, 'unit': 'ng/mL', 'low': 30},
                {'name': 'CRP', 'valueText': '<0.5', 'rangePrinted': '< 5'},
              ],
            }),
            _event('lab', DateTime(2026, 1, 1), {'test': 'CBC'}),
          ],
        ),
        sections: {SummarySection.labs},
        now: _now,
      );
      final rows = r.sections.single.rows;
      expect(rows[0].sublist(1), ['LDL', '210 mg/dL · عالي', '< 200']);
      expect(rows[1].sublist(1), ['Vit D', '12 ng/mL · واطي', '>= 30']);
      expect(rows[2].sublist(1), ['CRP', '<0.5', '< 5']);
      expect(rows[3].sublist(1), ['CBC', '', '']);
    });
  });

  group('mixed Arabic and Latin', () {
    test('Latin runs in an Arabic line are wrapped in LRM marks', () {
      String marks(String s) => s.replaceAll(lrm, '|');
      expect(marks(isolateLtrRuns('بنادول 500 mg')), 'بنادول |500 mg|');
      expect(
        marks(isolateLtrRuns('قرص 2.5 ml كل 8 ساعات')),
        'قرص |2.5 ml| كل |8| ساعات',
      );
      expect(marks(isolateLtrRuns('حرارة 38.5°C')), 'حرارة |38.5°C|');
      expect(
        marks(isolateLtrRuns('الدرن (BCG)، جرعة 1')),
        'الدرن |(BCG)|، جرعة |1|',
      );
      expect(
        marks(isolateLtrRuns('المعدل (70 - 100) mg/dL')),
        'المعدل |(70 - 100) mg/dL|',
      );
      expect(marks(isolateLtrRuns('بدون أرقام')), 'بدون أرقام');
    });

    test('direction per line', () {
      expect(bidiLine('Panadol 500 mg', rtlReport: true).$2.name, 'ltr');
      expect(
        bidiLine('ليلى', rtlReport: false).$1,
        '$lrm$lre'
        'ليلى'
        '$pdfPop',
      );
      expect(bidiLine('5 أبريل', rtlReport: true).$1, startsWith(rlm));
    });

    test('drawn in reading order (read back from the PDF)', () async {
      final fonts = await ReportFonts.load();
      Future<String> ar(String s) => visualLine(s, fonts, rtlReport: true);
      Future<String> en(String s) => visualLine(s, fonts, rtlReport: false);
      // Left to right as drawn: Latin runs keep their order, Arabic (ع)
      // reads from the right.
      expect(await ar('بنادول 500 mg'), '500 mg ع');
      expect(await ar('قرص 2.5 ml كل 8 ساعات'), 'ع 8 ع 2.5 ml ع');
      expect(await ar('حرارة 38.5°C'), '38.5°C ع');
      expect(await ar('5 أبريل 2026 · متأخرة'), 'ع · 2026 ع 5');
      expect(
        await en('1 tablet · قرص بعد الفطار · Since Oct 1, 2026'),
        '1 tablet · ع ع ع · Since Oct 1, 2026',
      );
      expect(await en('Panadol 500 mg'), 'Panadol 500 mg');
    });

    test('every character of both reports is in the font', () async {
      final fonts = await ReportFonts.load();
      final regular = TtfParser(fonts.regular).charToGlyphIndexMap;
      final bold = TtfParser(fonts.bold).charToGlyphIndexMap;
      final birth = addMonths(DateTime(2026, 11, 5), -10);
      final child = SummaryInputs(
        profile: _profile(
          birthDate: birth,
          bloodType: 'AB-',
          allergies: 'بنسلين',
        ),
        events: [
          _event('growth', DateTime(2026, 11, 1), {'weightKg': 8.5}),
          _event('vaccine', addMonths(birth, 2), {
            'vaccine': 'الخماسي',
            'dose': 1,
          }),
          _event('lab', DateTime(2026, 10, 1), {
            'tests': [
              {'name': 'Hb', 'value': 9.1, 'unit': 'g/dL', 'low': 11},
              {'name': 'TSH', 'value': 2, 'rangePrinted': '≤ 4.5'},
            ],
          }),
          _event('visit', DateTime(2026, 10, 2), {'reason': 'سخونية'}),
        ],
        medicines: [
          (
            _medicine('Augmentin', strength: '457 mg/5 ml'),
            DoseSchedule(
              id: 's',
              medicineId: 'mAugmentin',
              times: '08:00,20:00',
              weekdays: 0x15,
              amount: '5 مل',
              updatedAt: _now,
            ),
          ),
        ],
      );
      for (final l in [_ar, _en]) {
        final reports = [
          doctorSummary(
            l: l,
            inputs: child,
            sections: SummarySection.values.toSet(),
            now: _now,
          ),
          vaccinationRecord(
            l: l,
            profile: child.profile,
            events: child.events,
            now: _now,
            includeNotes: true,
          )!,
        ];
        for (final r in reports) {
          final text = [...r.allText, r.pageLabel(1, 2)];
          for (final s in text) {
            final (line, _) = bidiLine(s, rtlReport: r.rtl);
            final missing = {
              for (final c in line.runes)
                if (!regular.containsKey(c) || !bold.containsKey(c))
                  'U+${c.toRadixString(16)} in "$s"',
            };
            expect(missing, isEmpty);
          }
        }
      }
    });

    test('characters the font lacks are replaced or left out', () {
      final glyphs = {for (final c in 'ab <=>'.runes) c: 1};
      expect(pdfSafe('a ≤ b', glyphs), 'a <= b');
      expect(pdfSafe('a😀b', glyphs), 'ab');
    });
  });

  test('a summary never reads another person\'s records', () async {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(db.close);
    final hoda = await db.addProfile('Hoda', allergies: 'Penicillin');
    final sami = await db.addProfile('Sami', allergies: 'Sulfa');
    for (final (id, tag) in [(hoda, 'H'), (sami, 'S')]) {
      await db.addEvent(
        profileId: id,
        type: 'visit',
        occurredAt: DateTime(2026, 10, 1),
        dataJson: '{"reason": "visit-$tag"}',
      );
      await db.addEvent(
        profileId: id,
        type: 'lab',
        occurredAt: DateTime(2026, 10, 2),
        dataJson: '{"test": "lab-$tag"}',
      );
      await db.saveMedicine(
        profileId: id,
        name: 'med-$tag',
        startOn: DateTime(2026, 9, 1),
        schedule: const DoseScheduleInput(times: ['08:00']),
      );
    }
    final inputs = (await SummaryInputs.load(db, hoda))!;
    expect(inputs.events.map((e) => e.profileId).toSet(), {hoda});
    expect(inputs.medicines.map((m) => m.$1.profileId).toSet(), {hoda});
    final text = doctorSummary(
      l: _en,
      inputs: inputs,
      sections: SummarySection.values.toSet(),
      now: _now,
    ).allText.join('\n');
    expect(
      text,
      allOf(contains('visit-H'), contains('lab-H'), contains('med-H')),
    );
    for (final other in ['Sami', 'Sulfa', 'visit-S', 'lab-S', 'med-S']) {
      expect(text, isNot(contains(other)));
    }
    final records = (await SummaryInputs.loadRecords(db, sami))!;
    expect(records.events.map((e) => e.profileId).toSet(), {sami});
  });
}
