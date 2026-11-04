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
import 'package:usra/features/family/profile_form_screen.dart'
    show pathAfterProfileSave;
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
        vaccineReminderId('kid', DateTime(2026, 3, 1), 7),
        vaccineReminderId('kid', DateTime(2026, 3, 1), 0),
      ]);
      expect(
        planned.every(
          (r) => r.id >= vaccineReminderIdBase && r.id < snoozeIdBase,
        ),
        isTrue,
      );
    });

    test('discreet: no child or vaccine name', () {
      final now = DateTime(2026, 2, 1, 9);
      final planned = planVaccineReminders(
        [kid([], now)],
        now: now,
        settings: const VaccineReminderSettings(),
        texts: VaccineReminderTexts(en, discreet: true),
      );
      expect(planned.first.title, 'A health visit is coming up');
      expect(planned.last.title, 'A health visit is today');
      for (final r in planned) {
        expect(r.body, 'Open Usra to see the details');
        expect('${r.title} ${r.body}', isNot(contains('ليلى')));
        expect('${r.title} ${r.body}', isNot(contains('Pentavalent')));
        // Not even that it's a vaccine.
        expect('${r.title} ${r.body}'.toLowerCase(), isNot(contains('vaccin')));
        expect(r.at.hour, 10);
      }
      final arabic = planVaccineReminders(
        [kid([], now)],
        now: now,
        settings: const VaccineReminderSettings(),
        texts: VaccineReminderTexts(ar, discreet: true),
      );
      expect(arabic.first.title, 'فيه ميعاد زيارة صحية قرّب');
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
      // Nothing given by 16 months: overdue doses ring nothing; the next
      // doses of each series come 4 weeks after the missing ones could be
      // given (today), so the first reminder is for 12 June.
      final late = DateTime(2027, 5, 15);
      final catchUp = planVaccineReminders(
        [kid([], late)],
        now: late,
        settings: const VaccineReminderSettings(),
        texts: VaccineReminderTexts(en, discreet: true),
      );
      expect(catchUp.first.at, DateTime(2027, 6, 5, 10));
      expect(catchUp.first.scheduledAt, DateTime(2027, 6, 12));
      expect(
        catchUp.every((r) => !r.scheduledAt.isBefore(DateTime(2027, 5, 15))),
        isTrue,
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
      // The answers the schedule gave before plans existed (pinned, not
      // recomputed), for every required dose. One intended change: polio
      // drops 2 now wait 4 weeks after the missing dose 1 (minimum
      // interval) instead of being "due".
      const old = {
        'hepB-0': DoseState.overdue,
        'bcg-1': DoseState.done,
        'opv-0': DoseState.done,
        'opv-1': DoseState.overdue,
        'ipv-1': DoseState.overdue,
        'penta-1': DoseState.done,
        'opv-2': DoseState.due,
        'ipv-2': DoseState.done,
        'penta-2': DoseState.done,
        'opv-3': DoseState.later,
        'ipv-3': DoseState.later,
        'penta-3': DoseState.later,
        'opv-4': DoseState.later,
        'opv-5': DoseState.later,
        'mmr-1': DoseState.later,
        'opv-6': DoseState.later,
        'mmr-2': DoseState.later,
        'dtp-1': DoseState.later,
      };
      expect(
        {
          for (final e in byKey.entries)
            if (old.containsKey(e.key)) e.key: e.value,
        },
        {...old, 'opv-2': DoseState.later},
      );
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
        'A health visit is coming up',
        'A health visit is today',
      });
      // Its payload names the child (opened on tap).
      final ref = scheduler.planned.first.ref;
      expect(ref.profileId, kid);
      // A vaccine notification on screen is rewritten from the new plan.
      expect(
        scheduler.rebuild!(scheduler.planned.first.id, ref, now)?.title,
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

  group('review fixes', () {
    final birth = DateTime(2026, 1, 1);
    List<DoseStatus> gov(List<VaccineRecord> records) => matchSchedule(
      birthDate: birth,
      records: records,
      now: DateTime(2026, 5, 2),
    );

    test('unticking one dose keeps the other dose a shared record covered', () {
      // On the government route one hexavalent record counts twice.
      final statuses = gov([
        rec('Hexa', DateTime(2026, 3, 1), dose: 1, id: 'h'),
      ]);
      final c = vaccineRecordChanges(en, statuses, {'ipv-1': null});
      expect(c.remove, {'h'});
      expect(c.add, hasLength(1));
      final added = jsonDecode(c.add.single.dataJson) as Map;
      expect(vaccineKindsOf(added['vaccine'] as String), {VaccineKind.penta});
      expect(added['dose'], 1);
      expect(c.add.single.occurredAt, DateTime(2026, 3, 1, 12));

      // Applied, penta-1 is still given and IPV-1 isn't.
      final after = gov([
        for (final a in c.add)
          rec(
            (jsonDecode(a.dataJson) as Map)['vaccine'] as String,
            a.occurredAt,
            dose: 1,
          ),
      ]);
      String state(String key) =>
          after.firstWhere((s) => s.dose.key == key).state.name;
      expect(state('penta-1'), 'done');
      expect(state('ipv-1'), isNot('done'));
    });

    test('re-dating a dose moves its record in place (one shot)', () {
      final statuses = gov([
        rec('Hexa', DateTime(2026, 3, 1), dose: 1, id: 'h'),
      ]);
      final c = vaccineRecordChanges(en, statuses, {
        'penta-1': DateTime(2026, 3, 4),
      });
      expect(c.remove, isEmpty);
      expect(c.add, isEmpty);
      expect(c.redate, {'h': DateTime(2026, 3, 4, 12)});
    });

    test('no change, and a dose with its own second record', () {
      final statuses = gov([
        rec('Hexa', DateTime(2026, 3, 1), dose: 1, id: 'h'),
        rec('Pentavalent', DateTime(2026, 3, 1), dose: 1, id: 'p'),
      ]);
      // Same day: nothing to do.
      final same = vaccineRecordChanges(en, statuses, {
        'penta-1': DateTime(2026, 3, 1, 18),
        'pcv-1': null,
      });
      expect(same.add, isEmpty);
      expect(same.remove, isEmpty);
      // Unticking IPV removes the hexa record; penta-1 still has 'p'.
      final c = vaccineRecordChanges(en, statuses, {'ipv-1': null});
      expect(c.remove, {'h'});
      expect(c.add, isEmpty);
    });

    test('a given date is never in the future', () {
      final today = DateTime(2026, 5, 2, 15);
      expect(givenDateOn(DateTime(2026, 8, 1), today), DateTime(2026, 5, 2));
      expect(givenDateOn(DateTime(2026, 3, 1, 9), today), DateTime(2026, 3, 1));
    });

    test('a vaccine notification is rebuilt by its visit, not its id', () {
      PlannedReminder visit(int id, String child, DateTime due, String title) =>
          PlannedReminder.vaccine(
            id: id,
            at: DateTime(due.year, due.month, due.day, 10),
            profileId: child,
            dueOn: due,
            title: title,
            body: '',
          );
      final laila = visit(
        vaccineReminderIdBase + 1,
        'laila',
        DateTime(2026, 3, 1),
        'Laila',
      );
      // Re-planned: Laila's visit is now second, Youssef's first.
      final planned = [
        visit(
          vaccineReminderIdBase + 1,
          'youssef',
          DateTime(2026, 2, 20),
          'Youssef',
        ),
        visit(
          vaccineReminderIdBase + 2,
          'laila',
          DateTime(2026, 3, 1),
          'Laila (new text)',
        ),
      ];
      final rebuilt = vaccineReminderFor(planned, laila.id, laila.ref)!;
      expect(rebuilt.id, laila.id);
      expect(rebuilt.title, 'Laila (new text)');
      expect(rebuilt.profileId, 'laila');
      // A visit no longer planned is left alone.
      expect(
        vaccineReminderFor(planned.take(1).toList(), laila.id, laila.ref),
        isNull,
      );
    });

    test('the iOS lock-screen placeholder suits doses and vaccines', () {
      for (final l in [ar, en]) {
        expect(l.reminderHiddenPreview, isNot(l.doseReminderDiscreetTitle));
        expect(l.reminderHiddenPreview, isNot(contains('دوا')));
        expect(l.reminderHiddenPreview, isNot(contains('medicine')));
      }
    });

    test('a new child under five goes to the vaccine setup', () {
      final today = DateTime(2026, 5, 2);
      expect(
        pathAfterProfileSave(
          'k',
          isNew: true,
          birthDate: DateTime(2026, 1, 1),
          today: today,
        ),
        '/family/k/vaccines/setup?first=1',
      );
      // Edited, grown up, or no birth date: their page.
      expect(
        pathAfterProfileSave(
          'k',
          isNew: false,
          birthDate: DateTime(2026, 1, 1),
          today: today,
        ),
        '/family/k',
      );
      expect(
        pathAfterProfileSave(
          'k',
          isNew: true,
          birthDate: DateTime(1990, 1, 1),
          today: today,
        ),
        '/family/k',
      );
      expect(
        pathAfterProfileSave('k', isNew: true, birthDate: null, today: today),
        '/family/k',
      );
    });
  });

  group('change stream', () {
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

    test('vaccine records re-plan reminders; other records do not', () async {
      final id = await db.addProfile('ليلى', birthDate: DateTime(2026, 1, 1));
      var emitted = 0;
      final sub = db
          .watchEventChanges(vaccineRecordTypes)
          .listen((_) => emitted++);
      addTearDown(sub.cancel);
      Future<void> settle() =>
          Future<void>.delayed(const Duration(milliseconds: 50));
      await settle();
      expect(emitted, 1); // the first reading
      await db.addEvent(
        profileId: id,
        type: 'growth',
        occurredAt: DateTime(2026, 3, 1),
        dataJson: '{"weightKg": 5}',
      );
      await settle();
      expect(emitted, 1);
      await db.replaceEvents(
        profileId: id,
        add: [
          vaccineRecordFor(
            ar,
            egyptMandatorySchedule.first,
            DateTime(2026, 1, 1),
          ),
        ],
      );
      await settle();
      expect(emitted, 2);
      await db.saveSingletonEvent(
        profileId: id,
        type: VaccinePlanFields.type,
        dataJson: const VaccinePlan(optional: {VaccineKind.flu}).toJson(),
      );
      await settle();
      expect(emitted, 3);
    });
  });

  group('independent review: medical logic', () {
    final birth = DateTime(2026, 1, 1);
    DoseStatus status(
      String key,
      List<VaccineRecord> records,
      DateTime now, {
      VaccinePlan plan = VaccinePlan.standard,
    }) => matchSchedule(
      birthDate: birth,
      records: records,
      now: now,
      plan: plan,
    ).firstWhere((s) => s.dose.key == key);
    const rota = VaccinePlan(optional: {VaccineKind.rota});

    group('rotavirus age limits', () {
      test('dose 1 after 14 weeks 6 days is too late, never overdue', () {
        // 7 months old, rotavirus just chosen.
        final now = DateTime(2026, 8, 1);
        for (final key in ['rota-1', 'rota-2']) {
          final s = status(key, [], now, plan: rota);
          expect(s.state, DoseState.tooLate, reason: key);
          expect(s.open, isFalse);
        }
        final c = ChildVaccines(
          profile: child('kid', birth),
          plan: rota,
          statuses: matchSchedule(
            birthDate: birth,
            records: [],
            now: now,
            plan: rota,
          ),
        );
        expect(
          c.next.overdue.map((s) => s.dose.kind),
          isNot(contains(VaccineKind.rota)),
        );
        expect(
          planVaccineReminders(
            [c],
            now: now,
            settings: const VaccineReminderSettings(),
            texts: VaccineReminderTexts(en, discreet: false),
          ).map((r) => r.body).join(),
          isNot(contains('Rotavirus')),
        );
        // Not counted in the progress either.
        expect(vaccineProgress(c.statuses).optionalTotal, 0);
      });

      test('within the limits it is due; the last dose by 24 weeks', () {
        expect(
          status('rota-1', [], DateTime(2026, 3, 1), plan: rota).state,
          DoseState.due,
        );
        // Dose 1 at 14 weeks: dose 2 four weeks later, still before 24 weeks.
        final first = rec('Rotarix', birth.add(const Duration(days: 98)));
        final s2 = status('rota-2', [first], DateTime(2026, 4, 10), plan: rota);
        expect(s2.state, isNot(DoseState.tooLate));
        // Due at 4 months (1 May) but 4 weeks after dose 1 (9 April).
        expect(s2.dueOn, DateTime(2026, 5, 7));
        // Dose 1 at 22 weeks: dose 2 can't fit before 24 weeks.
        final lateFirst = rec('Rotarix', birth.add(const Duration(days: 154)));
        expect(
          status('rota-2', [lateFirst], DateTime(2026, 6, 5), plan: rota).state,
          DoseState.tooLate,
        );
        // Past 24 weeks without dose 2.
        expect(
          status('rota-2', [first], DateTime(2026, 7, 1), plan: rota).state,
          DoseState.tooLate,
        );
      });
    });

    group('minimum intervals', () {
      test('hepatitis A dose 2 at least 6 months after dose 1', () {
        const plan = VaccinePlan(optional: {VaccineKind.hepA});
        final s = status(
          'hepA-2',
          [rec('Hepatitis A', DateTime(2027, 6, 1))], // dose 1 at 17 months
          DateTime(2027, 7, 2),
          plan: plan,
        );
        expect(s.dueOn, DateTime(2027, 12, 1));
        expect(s.state, DoseState.later);
      });

      test('varicella 3 months, flu 4 weeks after the previous dose', () {
        final v = status(
          'varicella-2',
          [rec('Varicella', DateTime(2027, 3, 1))], // 14 months
          DateTime(2027, 3, 2),
          plan: const VaccinePlan(optional: {VaccineKind.varicella}),
        );
        expect(v.dueOn, DateTime(2027, 6, 1));
        final f = status(
          'flu-2',
          [rec('Flu', DateTime(2026, 11, 1))], // 10 months
          DateTime(2026, 11, 2),
          plan: const VaccinePlan(optional: {VaccineKind.flu}),
        );
        expect(f.dueOn, DateTime(2026, 11, 29));
        expect(f.state, isNot(DoseState.overdue));
      });

      test(
        'a late start is a catch-up: only the first missing dose is overdue',
        () {
          // 10 months, nothing on the card.
          final now = DateTime(2026, 11, 1);
          expect(status('penta-1', [], now).state, DoseState.overdue);
          final p2 = status('penta-2', [], now);
          expect(p2.state, DoseState.later);
          expect(p2.dueOn, DateTime(2026, 11, 29));
          expect(status('penta-3', [], now).dueOn, DateTime(2026, 12, 27));
          // Penta 1 given late: penta 2 is due 4 weeks after it.
          final given = [rec('Penta', DateTime(2026, 10, 20), dose: 1)];
          expect(status('penta-2', given, now).dueOn, DateTime(2026, 11, 17));
        },
      );

      test('the DTP booster comes 6 months after the third dose', () {
        final records = [
          rec('Penta', DateTime(2026, 3, 1), dose: 1),
          rec('Penta', DateTime(2026, 5, 1), dose: 2),
          rec('Penta', DateTime(2027, 4, 1), dose: 3), // late, 15 months
        ];
        expect(
          status('dtp-1', records, DateTime(2027, 4, 2)).dueOn,
          DateTime(2027, 10, 1),
        );
      });
    });

    group('PCV catch-up', () {
      const pcv = VaccinePlan(optional: {VaccineKind.pcv});
      Map<String, DoseState> pcvStates(List<VaccineRecord> r, DateTime now) => {
        for (final s in matchSchedule(
          birthDate: birth,
          records: r,
          now: now,
          plan: pcv,
        ))
          if (s.dose.kind == VaccineKind.pcv) s.dose.key: s.state,
      };

      test('started at 24 months or later: one dose', () {
        final s = pcvStates([], DateTime(2028, 3, 1)); // 26 months
        expect(s['pcv-1'], DoseState.overdue);
        expect([
          s['pcv-2'],
          s['pcv-3'],
          s['pcv-4'],
        ], everyElement(DoseState.notNeeded));
        final done = pcvStates([
          rec('PCV', DateTime(2028, 3, 1)),
        ], DateTime(2028, 3, 2));
        expect(done.values.where((v) => v == DoseState.done), hasLength(1));
        expect(done.values, isNot(contains(DoseState.overdue)));
        expect(done.values, isNot(contains(DoseState.due)));
      });

      test('started at 12-23 months: two doses 8 weeks apart', () {
        final s = status(
          'pcv-2',
          [rec('PCV', DateTime(2027, 3, 1))], // 14 months
          DateTime(2027, 3, 2),
          plan: pcv,
        );
        expect(s.dueOn, DateTime(2027, 4, 26));
        expect(
          pcvStates([
            rec('PCV', DateTime(2027, 3, 1)),
          ], DateTime(2027, 3, 2))['pcv-3'],
          DoseState.notNeeded,
        );
        expect(
          pcvDosesNeeded(birth, [DateTime(2027, 3, 1)], DateTime(2027, 3, 2)),
          2,
        );
      });

      test('started at 7-11 months: 3 doses; infants: 4', () {
        expect(
          pcvDosesNeeded(birth, [DateTime(2026, 9, 1)], DateTime(2026, 9, 2)),
          3,
        );
        expect(pcvDosesNeeded(birth, [], DateTime(2026, 3, 1)), 4);
        // Two infant doses, then nothing until 2 years: one more.
        expect(
          pcvDosesNeeded(birth, [
            DateTime(2026, 3, 1),
            DateTime(2026, 5, 1),
          ], DateTime(2028, 2, 1)),
          3,
        );
      });
    });

    group('route switching', () {
      const hexa = VaccinePlan(route: VaccineRoute.hexavalent);

      test('health office doses then private hexavalent', () {
        final records = [
          rec('الخماسي', DateTime(2026, 3, 1), dose: 1),
          rec('سولك', DateTime(2026, 3, 1), dose: 1),
          rec('Hexyon', DateTime(2026, 5, 1), dose: 2),
        ];
        final s = {
          for (final d in matchSchedule(
            birthDate: birth,
            records: records,
            now: DateTime(2026, 5, 2),
            plan: hexa,
          ))
            d.dose.key: d.state,
        };
        // Position 1 shows what was given, not a missing hexavalent.
        expect(s['penta-1'], DoseState.done);
        expect(s['ipv-1'], DoseState.done);
        expect(s.containsKey('hexa-1'), isFalse);
        expect(s['hexa-2'], DoseState.done);
        expect(s['hexa-3'], DoseState.later);
      });

      test('pentavalent without IPV shows just the IPV as missing', () {
        final s = {
          for (final d in matchSchedule(
            birthDate: birth,
            records: [rec('Pentavalent', DateTime(2026, 3, 1), dose: 1)],
            now: DateTime(2026, 4, 15),
            plan: hexa,
          ))
            d.dose.key: d.state,
        };
        expect(s['penta-1'], DoseState.done);
        expect(s['ipv-1'], DoseState.overdue);
        expect(s.containsKey('hexa-1'), isFalse);
      });

      test('a hexavalent booster counts for the DTP booster, and back', () {
        final hexaBooster = [rec('Infanrix hexa', DateTime(2027, 7, 1))];
        // Government route: the 18-month hexa counts as the DTP booster.
        expect(
          status('dtp-1', hexaBooster, DateTime(2027, 7, 2)).state,
          DoseState.done,
        );
        // But an infant hexavalent dose doesn't.
        expect(
          status('dtp-1', [
            rec('Hexa', DateTime(2026, 3, 1)),
          ], DateTime(2026, 3, 2)).state,
          isNot(DoseState.done),
        );
        // Hexavalent route: a DTP booster counts for the hexa booster.
        expect(
          status(
            'hexa-4',
            [rec('DTP', DateTime(2027, 7, 1))],
            DateTime(2027, 7, 2),
            plan: hexa,
          ).state,
          DoseState.done,
        );
        expect(vaccineKindsOf('Hexa'), contains(VaccineKind.hexa));
      });
    });
  });

  group('independent review: reminders', () {
    final birth = DateTime(2026, 1, 1);
    ChildVaccines kid(String id, DateTime birth, DateTime now) => ChildVaccines(
      profile: child(id, birth, name: id),
      plan: VaccinePlan.standard,
      statuses: matchSchedule(birthDate: birth, records: [], now: now),
    );
    List<PlannedReminder> plan(List<ChildVaccines> c, DateTime now) =>
        planVaccineReminders(
          c,
          now: now,
          settings: const VaccineReminderSettings(),
          texts: VaccineReminderTexts(en, discreet: false),
        );

    test('ids are stable per child, visit and lead, across re-plans', () {
      final laila = birth, youssef = DateTime(2026, 1, 10);
      final before = plan([
        kid('laila', laila, DateTime(2026, 2, 1)),
        kid('youssef', youssef, DateTime(2026, 2, 1)),
      ], DateTime(2026, 2, 1, 9));
      // A week later Laila's week-before reminder has rung and dropped out.
      final after = plan([
        kid('laila', laila, DateTime(2026, 2, 23)),
        kid('youssef', youssef, DateTime(2026, 2, 23)),
      ], DateTime(2026, 2, 23, 9));
      String key(PlannedReminder r) =>
          '${r.profileId}|${r.scheduledAt}|${r.at}';
      final idsBefore = {for (final r in before) key(r): r.id};
      for (final r in after) {
        if (idsBefore[key(r)] case final id?) expect(r.id, id, reason: key(r));
      }
      expect(after.length, lessThan(before.length));
      expect({for (final r in before) r.id}.length, before.length);
      expect(before.every((r) => r.id > 60 && r.id < snoozeIdBase), isTrue);
    });

    test('a resync leaves a shown vaccine notification as it is', () {
      final now1 = DateTime(2026, 2, 1, 9);
      final first = plan([
        kid('laila', birth, now1),
        kid('youssef', DateTime(2026, 1, 10), now1),
      ], now1);
      final weekBefore = first.firstWhere((r) => r.profileId == 'laila');
      // It rang; the next day the app re-plans.
      final now2 = DateTime(2026, 2, 23, 9);
      final second = plan([
        kid('laila', birth, now2),
        kid('youssef', DateTime(2026, 1, 10), now2),
      ], now2);
      final changes = diffReminders(
        pending: [
          for (final r in second)
            (id: r.id, title: r.title, body: r.body, payload: r.toPayload()),
        ],
        shown: [
          (
            id: weekBefore.id,
            title: weekBefore.title,
            body: weekBefore.body,
            payload: weekBefore.toPayload(),
          ),
        ],
        wanted: second,
        rebuild: (id, ref, at) => vaccineReminderFor(second, id, ref),
        now: now2,
      );
      expect(changes.repost, isEmpty);
      expect(changes.cancel, isEmpty);
      expect(changes.schedule, isEmpty);
    });

    test('iOS budget: the nearest vaccine visits are kept first', () {
      final now = DateTime(2026, 2, 1, 9);
      final vaccines = plan([kid('laila', birth, now)], now);
      final doses = [
        for (var i = 0; i < 70; i++)
          PlannedReminder(
            id: i + 1,
            at: now.add(Duration(hours: i + 1)),
            medicineId: 'm',
            scheduledAt: now.add(Duration(hours: i + 1)),
            title: 'dose',
            body: '',
            takenLabel: null,
            snoozeLabel: 's',
          ),
      ];
      final kept = prioritiseReminders(doses, vaccines).take(64).toList();
      expect(kept.where((r) => r.isVaccine), hasLength(vaccines.length));
      expect(kept.where((r) => !r.isVaccine), hasLength(64 - vaccines.length));
      // Doses still go soonest first.
      final doseTimes = [
        for (final r in kept)
          if (!r.isVaccine) r.at,
      ];
      expect(doseTimes, [...doseTimes]..sort());
    });
  });

  group('independent review: keeping the family\'s records', () {
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

    test('a new date keeps the record, its fields and its photo', () async {
      final birth = DateTime(2026, 1, 1);
      final kid = await db.addProfile('ليلى', birthDate: birth);
      final id = await db.addEvent(
        profileId: kid,
        type: 'vaccine',
        occurredAt: DateTime(2026, 3, 1),
        dataJson: jsonEncode({'vaccine': 'Pentavalent', 'dose': 1}),
        costMinor: 25000,
        currency: 'EGP',
        photos: ['attachments/card.jpg'],
      );
      final events = await db.watchTimeline(kid).first;
      final statuses = matchSchedule(
        birthDate: birth,
        records: vaccineRecords(events),
        now: DateTime(2026, 3, 10),
      );
      final changes = vaccineRecordChanges(en, statuses, {
        'penta-1': DateTime(2026, 3, 3),
      });
      await db.replaceEvents(
        profileId: kid,
        add: changes.add,
        remove: changes.remove,
        redate: changes.redate,
      );
      final after = (await db.watchTimeline(kid).first).single;
      expect(after.id, id);
      expect(after.occurredAt, DateTime(2026, 3, 3, 12));
      expect(after.costMinor, 25000);
      expect(after.dataJson, events.single.dataJson);
      expect(await db.watchAttachments(id).first, hasLength(1));
    });

    test('records typed by hand are told apart from checklist ones', () async {
      final kid = await db.addProfile('ليلى', birthDate: DateTime(2026, 1, 1));
      final typed = await db.addEvent(
        profileId: kid,
        type: 'vaccine',
        occurredAt: DateTime(2026, 1, 1),
        dataJson: '{"vaccine": "BCG"}',
      );
      await db.replaceEvents(
        profileId: kid,
        add: [
          vaccineRecordFor(
            ar,
            egyptMandatorySchedule.first,
            DateTime(2026, 1, 1),
          ),
        ],
      );
      final events = await db.watchTimeline(kid).first;
      expect(userVaccineRecordIds(events), {typed});
      final c = childVaccines(
        (await db.watchProfile(kid).first)!,
        events,
        DateTime(2026, 2, 1),
      )!;
      expect(c.userRecordIds, {typed});
    });
  });
}
