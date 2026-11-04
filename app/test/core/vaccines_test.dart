import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/features/children/child_vaccines.dart';
import 'package:usra/features/children/egypt_vaccines.dart';
import 'package:usra/features/children/growth.dart';
import 'package:usra/features/children/vaccine_reminders.dart';
import 'package:usra/features/medicines/reminder_sync.dart';
import 'package:usra/features/medicines/reminders.dart';
import 'package:usra/l10n/app_localizations.dart';

import '../support/fake_reminder_scheduler.dart';

final ar = lookupAppLocalizations(const Locale('ar'));
final en = lookupAppLocalizations(const Locale('en'));

VaccineRecord rec(String name, DateTime date, {int? dose, String? id}) =>
    (id: id, name: name, dose: dose, date: date);

Map<String, DoseState> states(
  DateTime birth,
  List<VaccineRecord> records,
  DateTime now, {
  VaccinePlan plan = VaccinePlan.standard,
}) => {
  for (final s in matchSchedule(
    birthDate: birth,
    records: records,
    now: now,
    plan: plan,
  ))
    s.dose.key: s.state,
};

Profile child(String id, DateTime birth, {String name = 'ليلى'}) => Profile(
  id: id,
  displayName: name,
  birthDate: birth,
  sex: 'female',
  simpleMode: false,
  updatedAt: DateTime.utc(2026),
);

void main() {
  group('schedule data', () {
    String row(ScheduledDose d) => '${d.key}@${d.ageMonths}';

    test('government route: the MoHP schedule, all required', () {
      final required = [
        for (final d in egyptSchedule(VaccineRoute.government))
          if (d.required) row(d),
      ];
      expect(required, [
        'hepB-0@0', 'bcg-1@0', 'opv-0@0', //
        'opv-1@2', 'ipv-1@2', 'penta-1@2',
        'opv-2@4', 'ipv-2@4', 'penta-2@4',
        'opv-3@6', 'ipv-3@6', 'penta-3@6',
        'opv-4@9',
        'opv-5@12', 'mmr-1@12',
        'opv-6@18', 'mmr-2@18', 'dtp-1@18',
      ]);
    });

    test('hexavalent route replaces pentavalent, IPV and the DTP booster', () {
      final schedule = egyptSchedule(VaccineRoute.hexavalent);
      final kinds = {for (final d in schedule) d.kind};
      expect(kinds, isNot(contains(VaccineKind.penta)));
      expect(kinds, isNot(contains(VaccineKind.ipv)));
      expect(kinds, isNot(contains(VaccineKind.dtp)));
      expect(
        [
          for (final d in schedule)
            if (d.kind == VaccineKind.hexa) row(d),
        ],
        ['hexa-1@2', 'hexa-2@4', 'hexa-3@6', 'hexa-4@18'],
      );
      // Oral polio, BCG, hepatitis B and MMR stay.
      expect(schedule.where((d) => d.kind == VaccineKind.opv).length, 7);
      expect(schedule.where((d) => d.required).length, 15);
    });

    test('optional vaccines are never required, and sorted by age', () {
      final optional = [
        for (final d in egyptSchedule(VaccineRoute.government))
          if (!d.required) d,
      ];
      expect({for (final d in optional) d.kind}, optionalVaccines.toSet());
      expect(
        optional.map(row),
        containsAll([
          'pcv-1@2', 'pcv-2@4', 'pcv-3@6', 'pcv-4@12', //
          'rota-1@2', 'rota-2@4',
          'varicella-1@12', 'varicella-2@15',
          'hepA-1@12', 'hepA-2@18',
          'mening-1@12',
          'flu-1@6', 'flu-2@7',
        ]),
      );
      final ages = [
        for (final d in egyptSchedule(VaccineRoute.government)) d.ageMonths,
      ];
      expect(ages, [...ages]..sort());
      // Everything falls inside the under-five window the app follows.
      expect(ages.last, lessThan(whoMaxMonths));
    });

    test('dose keys are unique on each route', () {
      for (final route in VaccineRoute.values) {
        final keys = egyptSchedule(route).map((d) => d.key).toList();
        expect(keys.toSet().length, keys.length);
      }
    });
  });

  group('names', () {
    test('the names the app writes are read back as the same vaccine', () {
      for (final l in [ar, en]) {
        for (final kind in VaccineKind.values) {
          expect(
            vaccineKindsOf(vaccineName(l, kind)),
            contains(kind),
            reason: '${l.localeName} ${vaccineName(l, kind)}',
          );
        }
      }
    });

    test('optional vaccines in Arabic and English, and brand names', () {
      expect(vaccineKindsOf('بريفينار'), {VaccineKind.pcv});
      expect(vaccineKindsOf('Prevenar 13'), {VaccineKind.pcv});
      expect(vaccineKindsOf('روتاريكس'), {VaccineKind.rota});
      expect(vaccineKindsOf('Rotarix'), {VaccineKind.rota});
      expect(vaccineKindsOf('جدري مائي'), {VaccineKind.varicella});
      expect(vaccineKindsOf('الالتهاب الكبدي الوبائي أ'), {VaccineKind.hepA});
      expect(vaccineKindsOf('Hepatitis A'), {VaccineKind.hepA});
      expect(vaccineKindsOf('Havrix'), {VaccineKind.hepA});
      // B stays B.
      expect(vaccineKindsOf('الالتهاب الكبدي الوبائي ب'), {VaccineKind.hepB});
      expect(vaccineKindsOf('Hepatitis B'), {VaccineKind.hepB});
      expect(vaccineKindsOf('Nimenrix'), {VaccineKind.mening});
      expect(vaccineKindsOf('الحمى الشوكية'), {VaccineKind.mening});
      expect(vaccineKindsOf('Infanrix hexa'), contains(VaccineKind.hexa));
    });
  });

  group('plan', () {
    test('round trip, and a damaged plan falls back to the standard one', () {
      const plan = VaccinePlan(
        route: VaccineRoute.hexavalent,
        optional: {VaccineKind.pcv, VaccineKind.rota},
        notes: {'pcv-1': 'في العيادة'},
      );
      expect(
        VaccinePlan.fromData(jsonDecode(plan.toJson()) as Map<String, Object?>),
        plan,
      );
      expect(
        VaccinePlan.fromData({'route': 'nope', 'optional': 'pcv', 'notes': 3}),
        VaccinePlan.standard,
      );
      // A required vaccine can't be "optional".
      expect(
        VaccinePlan.fromData({
          'optional': ['penta', 'flu'],
        }).optional,
        {VaccineKind.flu},
      );
    });

    test('an empty note removes it', () {
      final plan = VaccinePlan.standard.withNote('bcg-1', 'ok');
      expect(plan.notes, {'bcg-1': 'ok'});
      expect(plan.withNote('bcg-1', '  ').notes, isEmpty);
    });
  });

  group('matching with a plan', () {
    final birth = DateTime(2026, 1, 1);

    test('optional vaccines are never overdue unless chosen', () {
      final now = DateTime(2027, 6, 1);
      final standard = states(birth, [], now);
      expect(standard['pcv-1'], DoseState.notFollowed);
      expect(standard['rota-2'], DoseState.notFollowed);
      expect(standard['penta-1'], DoseState.overdue);

      final withPcv = states(
        birth,
        [],
        now,
        plan: const VaccinePlan(optional: {VaccineKind.pcv}),
      );
      expect(withPcv['pcv-1'], DoseState.overdue);
      expect(withPcv['rota-1'], DoseState.notFollowed);
    });

    test('a given optional dose counts even when not followed', () {
      final s = states(birth, [
        rec('PCV', DateTime(2026, 3, 1)),
      ], DateTime(2026, 3, 2));
      expect(s['pcv-1'], DoseState.done);
      expect(s['pcv-2'], DoseState.notFollowed);
    });

    test('route switching: a hexavalent record fits either route', () {
      final records = [
        rec('Hexyon', DateTime(2026, 3, 1), dose: 1),
        rec('سداسي', DateTime(2026, 5, 1), dose: 2),
      ];
      final now = DateTime(2026, 5, 2);
      final gov = states(birth, records, now);
      expect(gov['penta-1'], DoseState.done);
      expect(gov['ipv-2'], DoseState.done);
      expect(gov.containsKey('hexa-1'), isFalse);

      final hexa = states(
        birth,
        records,
        now,
        plan: const VaccinePlan(route: VaccineRoute.hexavalent),
      );
      expect(hexa['hexa-1'], DoseState.done);
      expect(hexa['hexa-2'], DoseState.done);
      expect(hexa['hexa-3'], DoseState.later);
      expect(hexa.containsKey('penta-1'), isFalse);
    });

    test('on the hexavalent route a DTP booster counts for the booster', () {
      final s = states(
        birth,
        [rec('DTP booster', DateTime(2027, 7, 1))],
        DateTime(2027, 7, 2),
        plan: const VaccinePlan(route: VaccineRoute.hexavalent),
      );
      expect(s['hexa-4'], DoseState.done);
      expect(s['hexa-1'], DoseState.overdue);
    });

    test('progress counts required and chosen optional doses', () {
      final statuses = matchSchedule(
        birthDate: birth,
        records: [
          rec('BCG', DateTime(2026, 1, 2)),
          rec('Hep B', DateTime(2026, 1, 1)),
          rec('شلل', DateTime(2026, 1, 1)),
          rec('Rotarix', DateTime(2026, 3, 1)),
          rec('Prevenar', DateTime(2026, 3, 1)),
        ],
        now: DateTime(2026, 3, 2),
        plan: const VaccinePlan(optional: {VaccineKind.rota}),
      );
      final p = vaccineProgress(statuses);
      expect(p.requiredDone, 3);
      expect(p.requiredTotal, 18);
      // PCV was given but isn't followed: not in the optional count.
      expect(p.optionalDone, 1);
      expect(p.optionalTotal, 2);
    });

    test('next visit: earliest open date, overdue counted apart', () {
      final statuses = matchSchedule(
        birthDate: birth,
        records: [
          rec('BCG', DateTime(2026, 1, 2)),
          rec('شلل', DateTime(2026, 1, 1)),
        ],
        now: DateTime(2026, 2, 20),
      );
      final next = NextVaccineVisit.of(statuses);
      // Hepatitis B at birth is more than a month late.
      expect(next.overdue.map((s) => s.dose.key), ['hepB-0']);
      expect(next.date, DateTime(2026, 3, 1));
      expect(next.doses.map((d) => d.key), ['opv-1', 'ipv-1', 'penta-1']);
      expect(next.daysFrom(DateTime(2026, 2, 20)), 9);
      expect(next.daysFrom(DateTime(2026, 3, 3)), -2);
    });

    test('all done', () {
      final all = [
        for (final d in egyptMandatorySchedule)
          rec(d.kind.name, d.dueOn(birth), dose: d.dose),
      ];
      final next = NextVaccineVisit.of(
        matchSchedule(birthDate: birth, records: all, now: DateTime(2028)),
      );
      expect(next.date, isNull);
      expect(next.overdue, isEmpty);
      expect(next.isEmpty, isTrue);
    });
  });

  group('reminders', () {
    final birth = DateTime(2026, 1, 1);
    ChildVaccines kid(List<VaccineRecord> records, DateTime now) =>
        ChildVaccines(
          profile: child('kid', birth),
          plan: VaccinePlan.standard,
          statuses: matchSchedule(birthDate: birth, records: records, now: now),
        );

    test('a week before and on the day, at the chosen time', () {
      final now = DateTime(2026, 2, 1, 9);
      final planned = planVaccineReminders(
        [kid([], now)],
        now: now,
        settings: const VaccineReminderSettings(minutes: 10 * 60 + 30),
        texts: VaccineReminderTexts(en, discreet: false),
      );
      // 2-month visit on 1 March; 4-month visit on 1 May is past 60 days.
      expect(planned.map((r) => r.at), [
        DateTime(2026, 2, 22, 10, 30),
        DateTime(2026, 3, 1, 10, 30),
      ]);
      expect(planned.first.title, 'ليلى: vaccines in a week');
      expect(planned.last.title, 'ليلى: vaccines today');
      expect(planned.first.body, contains('Pentavalent'));
      expect(planned.every((r) => r.isVaccine), isTrue);
      expect(planned.every((r) => r.takenLabel == null), isTrue);
      expect(planned.every((r) => r.snoozeLabel == null), isTrue);
      expect(planned.map((r) => r.id), [
        vaccineReminderIdBase + 1,
        vaccineReminderIdBase + 2,
      ]);
      expect(planned.every((r) => r.id < snoozeIdBase), isTrue);
    });

    test('discreet: no child or vaccine name', () {
      final now = DateTime(2026, 2, 1, 9);
      final planned = planVaccineReminders(
        [kid([], now)],
        now: now,
        settings: const VaccineReminderSettings(),
        texts: VaccineReminderTexts(en, discreet: true),
      );
      expect(planned.first.title, 'A vaccine visit is coming up');
      expect(planned.last.title, 'A vaccine visit is today');
      for (final r in planned) {
        expect(r.body, 'Open Usra to see the details');
        expect('${r.title} ${r.body}', isNot(contains('ليلى')));
        expect('${r.title} ${r.body}', isNot(contains('Pentavalent')));
        expect(r.at.hour, 10);
      }
      final arabic = planVaccineReminders(
        [kid([], now)],
        now: now,
        settings: const VaccineReminderSettings(),
        texts: VaccineReminderTexts(ar, discreet: true),
      );
      expect(arabic.first.title, 'فيه ميعاد تطعيم قرّب');
      expect(arabic.first.locale, 'ar');
    });

    test('given doses, past reminders, overdue doses and "off"', () {
      final now = DateTime(2026, 2, 25, 9);
      final records = [
        rec('OPV', DateTime(2026, 1, 1)),
        rec('BCG', DateTime(2026, 1, 1)),
        rec('Hep B', DateTime(2026, 1, 1)),
      ];
      final planned = planVaccineReminders(
        [kid(records, now)],
        now: now,
        settings: const VaccineReminderSettings(),
        texts: VaccineReminderTexts(en, discreet: true),
      );
      // The week-before one (22 Feb) has passed; only the day itself.
      expect(planned.map((r) => r.at), [DateTime(2026, 3, 1, 10)]);

      // Every 2-month dose given: nothing until the 4-month visit.
      final given = [
        ...records,
        rec('OPV', DateTime(2026, 2, 25)),
        rec('IPV', DateTime(2026, 2, 25)),
        rec('Penta', DateTime(2026, 2, 25)),
      ];
      expect(
        planVaccineReminders(
          [kid(given, now)],
          now: now,
          settings: const VaccineReminderSettings(),
          texts: VaccineReminderTexts(en, discreet: true),
        ),
        isEmpty,
      );
      // Overdue doses (up to 12 months) ring nothing; the 18-month visit does.
      final late = DateTime(2027, 5, 15);
      expect(
        planVaccineReminders(
          [kid([], late)],
          now: late,
          settings: const VaccineReminderSettings(),
          texts: VaccineReminderTexts(en, discreet: true),
        ).map((r) => r.at),
        [DateTime(2027, 6, 24, 10), DateTime(2027, 7, 1, 10)],
      );
      expect(
        planVaccineReminders(
          [kid([], now)],
          now: now,
          settings: const VaccineReminderSettings(enabled: false),
          texts: VaccineReminderTexts(en, discreet: true),
        ),
        isEmpty,
      );
    });

    test('a vaccine payload reads back as a vaccine', () {
      final r = PlannedReminder.vaccine(
        id: vaccineReminderIdBase + 1,
        at: DateTime.utc(2026, 2, 22, 8),
        profileId: 'kid',
        dueOn: DateTime.utc(2026, 3, 1),
        title: 't',
        body: 'b',
      );
      final ref = ReminderRef.fromPayload(r.toPayload())!;
      expect(ref.isVaccine, isTrue);
      expect(ref.profileId, 'kid');
      expect(ref.medicineId, isEmpty);
      // Dose payloads are unchanged.
      final dose = ReminderRef.fromPayload(
        ReminderRef(
          medicineId: 'm',
          scheduledAt: DateTime.utc(2026),
          locale: 'ar',
        ).toPayload(),
      )!;
      expect(dose.isVaccine, isFalse);
      expect(dose.medicineId, 'm');
    });
  });

  group('database', () {
    late AppDatabase db;
    setUp(
      () => db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      ),
    );
    tearDown(() => db.close());

    test('existing records keep working without a plan (migration)', () async {
      // Records as earlier versions saved them: typed names, no plan.
      final birth = DateTime(2026, 1, 1);
      final id = await db.addProfile('ليلى', birthDate: birth);
      for (final (name, dose, date) in [
        ('شلل الأطفال', null, birth),
        ('BCG', '1', birth), // a dose saved as text
        ('الخماسي', 1, DateTime(2026, 3, 1)),
        ('Hexa', 2, DateTime(2026, 5, 1)),
      ]) {
        await db.addEvent(
          profileId: id,
          type: 'vaccine',
          occurredAt: date,
          dataJson: jsonEncode({'vaccine': name, 'dose': ?dose}),
        );
      }
      final events = await db.watchTimeline(id).first;
      final profile = (await db.watchProfile(id).first)!;
      final now = DateTime(2026, 5, 2);
      final c = childVaccines(profile, events, now)!;
      expect(c.plan, VaccinePlan.standard);
      final byKey = {for (final s in c.statuses) s.dose.key: s.state};
      // Same answers as the schedule had before plans existed.
      final before = states(birth, vaccineRecords(events), now);
      expect(byKey, before);
      expect(byKey['opv-0'], DoseState.done);
      expect(byKey['bcg-1'], DoseState.done);
      expect(byKey['penta-1'], DoseState.done);
      expect(byKey['penta-2'], DoseState.done);
      expect(byKey['ipv-2'], DoseState.done);
      expect(byKey['hepB-0'], DoseState.overdue);
      // No optional dose is due or overdue.
      expect(
        c.statuses
            .where((s) => !s.dose.required && !s.done)
            .map((s) => s.state),
        everyElement(DoseState.notFollowed),
      );
    });

    test('the plan is one record, updated in place', () async {
      final id = await db.addProfile('ليلى', birthDate: DateTime(2026, 1, 1));
      final first = await db.saveSingletonEvent(
        profileId: id,
        type: VaccinePlanFields.type,
        dataJson: const VaccinePlan(optional: {VaccineKind.pcv}).toJson(),
      );
      final second = await db.saveSingletonEvent(
        profileId: id,
        type: VaccinePlanFields.type,
        dataJson: const VaccinePlan(route: VaccineRoute.hexavalent).toJson(),
      );
      expect(second, first);
      final events = await db.watchTimeline(id).first;
      expect(events.where((e) => e.type == VaccinePlanFields.type).length, 1);
      expect(
        vaccinePlanOf(events),
        const VaccinePlan(route: VaccineRoute.hexavalent),
      );
    });

    test('ticking and unticking doses adds and removes records', () async {
      final birth = DateTime(2026, 1, 1);
      final id = await db.addProfile('ليلى', birthDate: birth);
      final dose = egyptMandatorySchedule.first; // hepatitis B at birth
      await db.replaceEvents(
        profileId: id,
        add: [vaccineRecordFor(ar, dose, birth)],
      );
      var events = await db.watchTimeline(id).first;
      final status = matchSchedule(
        birthDate: birth,
        records: vaccineRecords(events),
        now: DateTime(2026, 2, 1),
      ).firstWhere((s) => s.dose.key == dose.key);
      expect(status.done, isTrue);
      expect(status.recordIds, hasLength(1));

      await db.replaceEvents(profileId: id, remove: status.recordIds);
      events = await db.watchTimeline(id).first;
      expect(vaccineRecords(events), isEmpty);
    });

    test('reminders are planned from every child in the database', () async {
      final now = DateTime(2026, 2, 1, 9);
      final kid = await db.addProfile('ليلى', birthDate: DateTime(2026, 1, 1));
      await db.addProfile('منى', birthDate: DateTime(1990, 1, 1));
      await db.saveSingletonEvent(
        profileId: kid,
        type: VaccinePlanFields.type,
        dataJson: const VaccinePlan(optional: {VaccineKind.rota}).toJson(),
      );
      final planned = await loadVaccineReminders(
        db,
        now: now,
        settings: const VaccineReminderSettings(),
        texts: VaccineReminderTexts(en, discreet: false),
      );
      expect(planned.map((r) => r.profileId).toSet(), {kid});
      expect(planned.first.body, contains('Rotavirus'));
    });

    test('the reminder sync schedules vaccine visits with the doses, and '
        're-plans when a dose is ticked or the settings change', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final now = DateTime(2026, 2, 1, 9);
      final kid = await db.addProfile('ليلى', birthDate: DateTime(2026, 1, 1));
      final scheduler = FakeReminderScheduler();
      var settings = const VaccineReminderSettings();
      final dir = Directory.systemTemp.createTempSync('usra_vaccines');
      addTearDown(() => dir.deleteSync(recursive: true));
      final sync = ReminderSync(
        db: db,
        scheduler: scheduler,
        inbox: DoseActionInbox(File('${dir.path}/inbox.jsonl')),
        texts: () => ReminderTexts(en, discreet: true),
        clock: () => now,
        vaccines: (now) => loadVaccineReminders(
          db,
          now: now,
          settings: settings,
          texts: VaccineReminderTexts(en, discreet: true),
        ),
      );
      await sync.resync();
      expect(scheduler.planned.map((r) => r.at), [
        DateTime(2026, 2, 22, 10),
        DateTime(2026, 3, 1, 10),
      ]);
      expect(scheduler.planned.map((r) => r.title).toSet(), {
        'A vaccine visit is coming up',
        'A vaccine visit is today',
      });
      // Its payload names the child (opened on tap).
      final ref = scheduler.planned.first.ref;
      expect(ref.profileId, kid);
      // A vaccine notification on screen is rewritten from the new plan.
      expect(
        scheduler.rebuild!(vaccineReminderIdBase + 1, ref, now)?.title,
        scheduler.planned.first.title,
      );

      // All 2-month doses given: their reminders go.
      await db.replaceEvents(
        profileId: kid,
        add: [
          for (final d in egyptMandatorySchedule)
            if (d.ageMonths == 2) vaccineRecordFor(en, d, DateTime(2026, 2, 1)),
        ],
      );
      await sync.resync();
      expect(scheduler.planned, isEmpty);

      // A new time, and switched off.
      await db.replaceEvents(
        profileId: kid,
        remove: [
          for (final r in vaccineRecords(await db.watchTimeline(kid).first))
            r.id!,
        ],
      );
      settings = const VaccineReminderSettings(minutes: 8 * 60);
      await sync.resync();
      expect(scheduler.planned.first.at, DateTime(2026, 2, 22, 8));
      settings = const VaccineReminderSettings(enabled: false);
      await sync.resync();
      expect(scheduler.planned, isEmpty);
      sync.dispose();
    });
  });
}
