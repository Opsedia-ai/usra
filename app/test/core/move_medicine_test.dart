import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/files/photo_store.dart';
import 'package:usra/features/medicines/move_medicine_screen.dart';
import 'package:usra/features/medicines/reminder_sync.dart';
import 'package:usra/features/medicines/reminders.dart';
import 'package:usra/l10n/app_localizations.dart';

import '../support/fake_reminder_scheduler.dart';

void main() {
  late AppDatabase db;
  late Directory dir;
  late PhotoStore photos;
  late String sara;
  late String omar;
  final ar = lookupAppLocalizations(const Locale('ar'));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('usra_move');
    photos = PhotoStore(
      dir,
      PhotoStore.medicinesFolder,
      PhotoKeys.ready(PhotoCipher(PhotoCipher.generateKey())),
    );
    sara = await db.addProfile('سارة');
    omar = await db.addProfile('عمر');
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  /// A photo stored the way the app stores them, with [text] as its contents.
  Future<String> photo(String text) async {
    final pick = File(p.join(dir.path, '$text.jpg'))..writeAsStringSync(text);
    return photos.import(pick.path);
  }

  Future<String> medicine({
    String? profileId,
    List<String> photoPaths = const [],
    List<String> times = const ['08:00'],
  }) => db.saveMedicine(
    profileId: profileId ?? sara,
    name: 'جلوكوفاج',
    startOn: DateTime(2026, 11, 1),
    photos: photoPaths,
    schedule: DoseScheduleInput(times: times, amount: 'قرص'),
  );

  Future<void> move(String id, {String? from, String? to}) async {
    final m = (await db.watchMedicine(id).first)!;
    return moveMedicineToPerson(
      db: db,
      photos: photos,
      medicine: m,
      toProfileId: to ?? omar,
    );
  }

  test('the row, schedule, doses and photos go together', () async {
    final box = await photo('box');
    final id = await medicine(photoPaths: [box]);
    final at = DateTime(2026, 11, 3, 8).toUtc();
    await db.logDose(id, at, DoseOutcome.taken);
    final before = await photos.read(box);

    await move(id);

    expect(await db.watchMedicines(sara).first, isEmpty);
    final moved = (await db.watchMedicines(omar).first).single;
    expect(moved.id, id);
    expect(moved.name, 'جلوكوفاج');
    expect((await db.watchDoseSchedule(id).first)!.times, '08:00');
    expect((await db.watchDoseSchedule(id).first)!.amount, 'قرص');
    final logs = await db.watchMedicineDoseLogs(id).first;
    expect(logs.single.status, DoseOutcome.taken);
    expect(logs.single.scheduledAt.isAtSameMomentAs(at), isTrue);
    // The same file: nobody else uses it, so nothing is copied.
    expect(decodeMedicinePhotos(moved.photosJson), [box]);
    expect(await photos.read(box), before);
    expect(await photos.storedPaths(), {box});
  });

  test('reminders go to the new person, and name them', () async {
    final id = await medicine(times: ['08:00']);
    final now = DateTime(2026, 11, 3, 7);
    Future<List<String>> titles() async => [
      for (final r in planReminders(
        await db.watchRegimens().first,
        const [],
        now: now,
        texts: ReminderTexts(ar, discreet: false),
        window: const Duration(hours: 2),
      ))
        r.title,
    ];
    expect((await titles()).single, contains('سارة'));
    await move(id);
    expect((await titles()).single, contains('عمر'));
    expect((await titles()).single, isNot(contains('سارة')));
  });

  test('the phone\'s reminders are rewritten when it moves', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final scheduler = FakeReminderScheduler();
    final id = await medicine();
    final now = DateTime(2026, 11, 3, 7);
    final sync = ReminderSync(
      db: db,
      scheduler: scheduler,
      inbox: DoseActionInbox(File(p.join(dir.path, 'a.jsonl'))),
      texts: () => ReminderTexts(ar, discreet: false),
      clock: () => now,
    );
    addTearDown(sync.dispose);
    await sync.start();
    expect(scheduler.planned.first.title, contains('سارة'));
    await move(id);
    for (var i = 0; i < 100; i++) {
      if (scheduler.planned.first.title.contains('عمر')) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(scheduler.planned.first.title, contains('عمر'));
  });

  test('a save still can\'t move it, only the deliberate move', () async {
    final id = await medicine();
    await expectLater(
      db.saveMedicine(
        id: id,
        profileId: omar,
        name: 'x',
        startOn: DateTime(2026, 11, 1),
      ),
      throwsStateError,
    );
    expect((await db.watchMedicine(id).first)!.profileId, sara);
  });

  group('a move that can\'t happen changes nothing', () {
    test('a wrong owner', () async {
      final id = await medicine();
      final third = await db.addProfile('منى');
      await expectLater(
        db.moveMedicine(id: id, fromProfileId: third, toProfileId: omar),
        throwsStateError,
      );
      expect((await db.watchMedicine(id).first)!.profileId, sara);
    });

    test('a deleted person', () async {
      final id = await medicine();
      await db.softDeleteProfile(omar);
      await expectLater(
        db.moveMedicine(id: id, fromProfileId: sara, toProfileId: omar),
        throwsStateError,
      );
      expect((await db.watchMedicine(id).first)!.profileId, sara);
    });

    test('the same person', () async {
      final id = await medicine();
      await expectLater(
        db.moveMedicine(id: id, fromProfileId: sara, toProfileId: sara),
        throwsArgumentError,
      );
    });

    test('a deleted medicine', () async {
      final id = await medicine();
      await db.softDeleteMedicine(id);
      await expectLater(
        db.moveMedicine(id: id, fromProfileId: sara, toProfileId: omar),
        throwsStateError,
      );
    });
  });

  group('a photo shared with another record', () {
    test('each person keeps their own, with the same contents', () async {
      final shared = await photo('prescription');
      final rx = await db.savePrescription(
        profileId: sara,
        prescribedOn: DateTime(2026, 11, 1),
        photos: [shared],
        items: const [PrescriptionItemInput(name: 'بنادول')],
      );
      final own = await photo('box');
      final id = await medicine(photoPaths: [shared, own]);
      final before = await photos.read(shared);

      await move(id);

      final moved = (await db.watchMedicine(id).first)!;
      final list = decodeMedicinePhotos(moved.photosJson);
      expect(list, hasLength(2));
      expect(list.first, isNot(shared));
      expect(list.last, own);
      expect(await photos.read(list.first), before);
      // The prescription still has the original.
      final kept = (await db.watchPrescription(rx).first)!;
      expect(decodeMedicinePhotos(kept.photosJson), [shared]);

      // Deleting one doesn't touch the other.
      await db.softDeleteMedicine(id);
      await photos.prune(await db.liveMedicinePhotos());
      expect(await photos.read(shared), before);
      expect(photos.fileOf(list.first).existsSync(), isFalse);
      expect(photos.fileOf(own).existsSync(), isFalse);
    });

    test('moving straight through the database can\'t share it', () async {
      final shared = await photo('prescription');
      await db.savePrescription(
        profileId: sara,
        prescribedOn: DateTime(2026, 11, 1),
        photos: [shared],
        items: const [PrescriptionItemInput(name: 'بنادول')],
      );
      final id = await medicine(photoPaths: [shared]);
      await expectLater(
        db.moveMedicine(id: id, fromProfileId: sara, toProfileId: omar),
        throwsStateError,
      );
      expect((await db.watchMedicine(id).first)!.profileId, sara);
    });

    test('a shared photo whose file is gone doesn\'t stop the move', () async {
      final shared = await photo('prescription');
      await db.savePrescription(
        profileId: sara,
        prescribedOn: DateTime(2026, 11, 1),
        photos: [shared],
        items: const [PrescriptionItemInput(name: 'بنادول')],
      );
      final id = await medicine(photoPaths: [shared]);
      photos.fileOf(shared).deleteSync();
      await move(id);
      final moved = (await db.watchMedicine(id).first)!;
      expect(moved.profileId, omar);
      expect(decodeMedicinePhotos(moved.photosJson), isEmpty);
    });

    test(
      'a photo from before they were encrypted comes out encrypted',
      () async {
        final shared = await photo('prescription');
        final plain = p.join(PhotoStore.medicinesFolder, 'old.jpg');
        photos.fileOf(plain).writeAsStringSync('old photo');
        await db.savePrescription(
          profileId: sara,
          prescribedOn: DateTime(2026, 11, 1),
          photos: [shared, plain],
          items: const [PrescriptionItemInput(name: 'بنادول')],
        );
        final id = await medicine(photoPaths: [plain]);
        await move(id);
        final copy = decodeMedicinePhotos(
          (await db.watchMedicine(id).first)!.photosJson,
        ).single;
        expect(
          PhotoCipher.isSealed(photos.fileOf(copy).readAsBytesSync()),
          isTrue,
        );
      },
    );

    test('a failed move only clears its own copies', () async {
      final shared = await photo('prescription');
      await db.savePrescription(
        profileId: sara,
        prescribedOn: DateTime(2026, 11, 1),
        photos: [shared],
        items: const [PrescriptionItemInput(name: 'بنادول')],
      );
      final id = await medicine(photoPaths: [shared]);
      // Another form's photo that isn't saved yet.
      final unsaved = await photo('unsaved');
      await expectLater(
        moveMedicineToPerson(
          db: db,
          photos: photos,
          medicine: (await db.watchMedicine(id).first)!,
          toProfileId: 'nobody',
        ),
        throwsStateError,
      );
      expect(await photos.storedPaths(), {shared, unsaved});
    });

    test('a move that fails leaves no copy behind', () async {
      final shared = await photo('prescription');
      await db.savePrescription(
        profileId: sara,
        prescribedOn: DateTime(2026, 11, 1),
        photos: [shared],
        items: const [PrescriptionItemInput(name: 'بنادول')],
      );
      final id = await medicine(photoPaths: [shared]);
      final m = (await db.watchMedicine(id).first)!;
      await expectLater(
        moveMedicineToPerson(
          db: db,
          photos: photos,
          medicine: m,
          toProfileId: 'nobody',
        ),
        throwsStateError,
      );
      expect((await db.watchMedicine(id).first)!.profileId, sara);
      expect(await photos.storedPaths(), {shared});
    });
  });

  group('what stays with the old person', () {
    test('it comes off their prescription, which stays theirs', () async {
      final rx = await db.savePrescription(
        profileId: sara,
        prescribedOn: DateTime(2026, 11, 1),
        items: const [
          PrescriptionItemInput(name: 'بنادول'),
          PrescriptionItemInput(name: 'فيتامين'),
        ],
      );
      final onIt = await db
          .watchMedicines(sara)
          .first
          .then((all) => all.firstWhere((m) => m.name == 'بنادول'));
      await move(onIt.id);

      final moved = (await db.watchMedicine(onIt.id).first)!;
      expect(moved.prescriptionId, isNull);
      expect(moved.position, isNull);
      final prescription = (await db.watchPrescription(rx).first)!;
      expect(prescription.profileId, sara);
      expect(prescription.active, isTrue);
      final left = await db.watchMedicines(sara).first;
      expect(left.single.name, 'فيتامين');

      // Moved one comes back only by being moved; editing it can't re-attach.
      await move(left.single.id);
      final emptied = (await db.watchPrescription(rx).first)!;
      expect(emptied.active, isFalse);
    });

    test('it keeps a dose stopped with the prescription stopped, but on its '
        'own now', () async {
      final rx = await db.savePrescription(
        profileId: sara,
        prescribedOn: DateTime(2026, 11, 1),
        items: const [PrescriptionItemInput(name: 'بنادول')],
      );
      await db.setPrescriptionActive(rx, false);
      final m = (await db.watchMedicines(sara).first).single;
      expect(m.stoppedWithPrescription, isTrue);
      await move(m.id);
      final moved = (await db.watchMedicine(m.id).first)!;
      expect(moved.active, isFalse);
      expect(moved.stoppedWithPrescription, isFalse);
      // Resuming the old prescription can't restart it.
      await db.setPrescriptionActive(rx, true);
      expect((await db.watchMedicine(m.id).first)!.active, isFalse);
    });

    test('doses in their sick days stay there by name, and the next-dose '
        'reminder stops', () async {
      final id = await db.saveMedicine(
        profileId: sara,
        name: 'بنادول',
        startOn: DateTime(2026, 11, 1),
        minHoursBetweenDoses: const Value(6),
      );
      final episode = await db.saveEpisode(
        profileId: sara,
        startedAt: DateTime(2026, 11, 3),
      );
      final givenId = await db.saveGivenMedicine(
        episodeId: episode,
        medicineId: id,
        name: 'بنادول',
        amount: '٥ مل',
        givenAt: DateTime(2026, 11, 3, 8),
        remindNext: true,
      );
      expect(await db.watchNextDoseSources().first, hasLength(1));
      expect(await db.watchGivenOf(id).first, hasLength(1));

      await move(id);

      expect(await db.watchNextDoseSources().first, isEmpty);
      expect(await db.watchGivenOf(id).first, isEmpty);
      final given = (await db.select(db.givenMedicines).get()).single;
      expect(given.id, givenId);
      expect(given.episodeId, episode);
      expect(given.medicineId, isNull);
      expect(given.name, 'بنادول');
      expect(given.amount, '٥ مل');
      expect(given.remindNext, isFalse);
    });
  });
}
