import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:usra/core/backup/auto_backup.dart'
    show backupMissingPhotosCount;
import 'package:usra/core/backup/backup_crypto.dart';
import 'package:usra/core/backup/backup_service.dart';
import 'package:usra/core/backup/recovery_key.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/database/connection.dart';
import 'package:usra/core/files/photo_integrity.dart';
import 'package:usra/core/files/photo_store.dart';
import 'package:usra/core/log.dart';

/// Cheap Argon2id so the tests run fast; real backups use the standard cost.
const _testKdf = BackupKdf(memory: 64, iterations: 1, parallelism: 1);

/// One phone: real encrypted database, real encrypted photo files and the
/// real backup service, in a folder of its own.
class _Phone {
  _Phone(this.dir)
    : key = DatabaseKeyStore.generateKey(),
      photoKeys = PhotoKeys.ready(PhotoCipher(PhotoCipher.generateKey())),
      root = Directory(p.join(dir.path, 'support'))..createSync(),
      temp = Directory(p.join(dir.path, 'tmp'))..createSync();

  final Directory dir;
  final String key;
  final PhotoKeys photoKeys;
  final Directory root;
  final Directory temp;

  late final cards = PhotoStore(root, PhotoStore.cardsFolder, photoKeys);
  late final attachments = PhotoStore(
    root,
    PhotoStore.attachmentsFolder,
    photoKeys,
  );
  late final medicines = PhotoStore(
    root,
    PhotoStore.medicinesFolder,
    photoKeys,
  );

  late final service = BackupService(
    root: root,
    databaseName: 'usra.sqlite',
    deviceKey: key,
    photoKeys: photoKeys,
    temporary: temp,
    folders: const [
      PhotoStore.cardsFolder,
      PhotoStore.attachmentsFolder,
      PhotoStore.medicinesFolder,
    ],
    kdf: _testKdf,
    chunkSize: 4096,
  );

  AppDatabase open() => AppDatabase(
    openEncryptedDatabase(File(p.join(root.path, 'usra.sqlite')), key),
  );

  File file(String path) => File(p.join(root.path, path));

  Future<void> pruneAll(AppDatabase db) async {
    await cards.prune(await db.liveInsurancePhotos());
    await attachments.prune(await db.liveAttachmentPaths());
    await medicines.prune(await db.liveMedicinePhotos());
  }

  Future<PhotoIntegrity> check(AppDatabase db) => checkPhotoIntegrity(
    db,
    cards: cards,
    attachments: attachments,
    medicines: medicines,
  );

  /// Every photo [profileId]'s own rows point at, opened: path to bytes.
  /// Through the same per-person queries the screens use.
  Future<Map<String, List<int>>> photosOf(
    AppDatabase db,
    String profileId,
  ) async {
    final found = <String, List<int>>{};
    for (final c in await db.watchInsuranceCards(profileId).first) {
      for (final path in [?c.frontPhoto, ?c.backPhoto]) {
        found[path] = await cards.read(path);
      }
    }
    for (final m in await db.watchMedicines(profileId).first) {
      for (final path in decodeMedicinePhotos(m.photosJson)) {
        found[path] = await medicines.read(path);
      }
    }
    for (final r in await db.watchPrescriptions(profileId).first) {
      for (final path in decodeMedicinePhotos(r.photosJson)) {
        found[path] = await medicines.read(path);
      }
    }
    for (final e in await db.watchTimeline(profileId).first) {
      for (final a in await db.watchAttachments(e.id).first) {
        found[a.path] = await attachments.read(a.path);
      }
    }
    return found;
  }
}

/// One family member with a photo of every kind.
class _Person {
  _Person({
    required this.id,
    required this.cardId,
    required this.medicineId,
    required this.prescriptionId,
    required this.eventId,
    required this.cardFront,
    required this.cardBack,
    required this.medicinePhoto,
    required this.prescriptionPhoto,
    required this.recordPhoto,
    required this.photos,
  });

  final String id;
  final String cardId;
  final String medicineId;
  final String prescriptionId;
  final String eventId;
  final String cardFront;
  final String cardBack;
  final String medicinePhoto;
  final String prescriptionPhoto;
  final String recordPhoto;

  /// What the phone should hold for them: path to the bytes first picked.
  final Map<String, List<int>> photos;
}

/// Bytes that can only be this one photo: a mix-up can't pass by luck.
Uint8List _bytes(String label) => Uint8List.fromList([
  ...utf8.encode(label),
  for (var i = 0; i < 2000; i++) (i * label.length) % 251,
]);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory dir;
  late _Phone phone;
  late AppDatabase db;
  var picks = 0;

  /// A new temporary file, like the picker hands back.
  String pick(String label) {
    final file = File(p.join(dir.path, 'picked_${picks++}.jpg'));
    file.writeAsBytesSync(_bytes(label));
    return file.path;
  }

  /// Adds [name] with an insurance card (front and back), a medicine, a
  /// prescription and a record, each with its own photo.
  Future<_Person> addPerson(String name) async {
    final photos = <String, List<int>>{};
    Future<String> keep(PhotoStore store, String label) async {
      final path = await store.import(pick('$name $label'));
      photos[path] = _bytes('$name $label');
      return path;
    }

    final id = await db.addProfile(name);
    final front = await keep(phone.cards, 'front');
    final back = await keep(phone.cards, 'back');
    final medicinePhoto = await keep(phone.medicines, 'medicine');
    final prescriptionPhoto = await keep(phone.medicines, 'prescription');
    final recordPhoto = await keep(phone.attachments, 'record');
    return _Person(
      id: id,
      cardId: await db.saveInsuranceCard(
        profileId: id,
        label: 'card',
        frontPhoto: front,
        backPhoto: back,
      ),
      medicineId: await db.saveMedicine(
        profileId: id,
        name: 'medicine',
        startOn: DateTime(2026, 11, 1),
        photos: [medicinePhoto],
      ),
      prescriptionId: await db.savePrescription(
        profileId: id,
        prescribedOn: DateTime(2026, 11, 1),
        photos: [prescriptionPhoto],
        items: const [PrescriptionItemInput(name: 'item', days: 3)],
      ),
      eventId: await db.addEvent(
        profileId: id,
        type: 'visit',
        occurredAt: DateTime(2026, 11, 1),
        photos: [recordPhoto],
      ),
      cardFront: front,
      cardBack: back,
      medicinePhoto: medicinePhoto,
      prescriptionPhoto: prescriptionPhoto,
      recordPhoto: recordPhoto,
      photos: photos,
    );
  }

  Future<void> expectClean(_Phone phone, AppDatabase db) async {
    final check = await phone.check(db);
    expect((check.missing, check.unused), (0, 0));
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('usra_photo_safety');
    phone = _Phone(Directory(p.join(dir.path, 'phone'))..createSync());
    db = phone.open();
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  group('two people with a photo of every kind', () {
    late _Person sara;
    late _Person omar;

    setUp(() async {
      sara = await addPerson('Sara');
      omar = await addPerson('Omar');
    });

    test(
      "each person's queries return only their own paths and bytes",
      () async {
        expect(sara.photos, hasLength(5));
        expect(omar.photos, hasLength(5));
        expect(await phone.photosOf(db, sara.id), sara.photos);
        expect(await phone.photosOf(db, omar.id), omar.photos);
        expect(
          sara.photos.keys.toSet().intersection(omar.photos.keys.toSet()),
          isEmpty,
        );
      },
    );

    test(
      'back up and restore into a fresh phone: the same, byte for byte',
      () async {
        final recovery = RecoveryKey.generate();
        final made = await phone.service.create(
          db,
          recovery,
          appVersion: 'test',
        );
        expect(made.skippedPhotos, 0);
        expect(made.counts[backupMissingPhotosCount], 0);
        expect(made.counts['photos'], 10);

        final fresh = _Phone(
          Directory(p.join(dir.path, 'fresh'))..createSync(),
        );
        final staged = await fresh.service.stage(
          made.file,
          recovery,
          currentSchema: db.schemaVersion,
        );
        expect(staged.skippedPhotos, 0);
        await fresh.service.commit();

        final restored = fresh.open();
        addTearDown(restored.close);
        expect(await fresh.photosOf(restored, sara.id), sara.photos);
        expect(await fresh.photosOf(restored, omar.id), omar.photos);
        await expectClean(fresh, restored);
        // Encrypted for the new phone, not left as the old phone's files.
        for (final path in [...sara.photos.keys, ...omar.photos.keys]) {
          final onDisk = fresh.file(path).readAsBytesSync();
          expect(PhotoCipher.isSealed(onDisk), isTrue);
          expect(onDisk, isNot(phone.file(path).readAsBytesSync()));
        }
      },
    );

    test('deleting a person takes only their photos, once pruned', () async {
      await db.softDeleteProfile(sara.id);
      await phone.pruneAll(db);

      for (final path in sara.photos.keys) {
        expect(phone.file(path).existsSync(), isFalse, reason: path);
      }
      for (final path in omar.photos.keys) {
        expect(phone.file(path).existsSync(), isTrue, reason: path);
      }
      expect(await phone.photosOf(db, sara.id), isEmpty);
      expect(await phone.photosOf(db, omar.id), omar.photos);
      await expectClean(phone, db);
    });

    group('replacing a photo and pruning', () {
      /// The new photo is in, [replaced] is gone, and everyone's other
      /// photos are exactly as they were.
      Future<void> expectReplaced(String replaced, String added) async {
        await phone.pruneAll(db);

        expect(phone.file(replaced).existsSync(), isFalse);
        expect(await phone.photosOf(db, omar.id), omar.photos);
        expect(
          await phone.photosOf(db, sara.id),
          {...sara.photos, added: _bytes('Sara new')}..remove(replaced),
        );
        await expectClean(phone, db);
      }

      test('on an insurance card', () async {
        final added = await phone.cards.import(pick('Sara new'));
        await db.saveInsuranceCard(
          id: sara.cardId,
          profileId: sara.id,
          label: 'card',
          frontPhoto: added,
          backPhoto: sara.cardBack,
        );
        await expectReplaced(sara.cardFront, added);
      });

      test('on a medicine', () async {
        final added = await phone.medicines.import(pick('Sara new'));
        await db.saveMedicine(
          id: sara.medicineId,
          profileId: sara.id,
          name: 'medicine',
          startOn: DateTime(2026, 11, 1),
          photos: [added],
        );
        await expectReplaced(sara.medicinePhoto, added);
      });

      test('on a prescription', () async {
        final added = await phone.medicines.import(pick('Sara new'));
        final items = await db
            .watchPrescriptionMedicines(sara.prescriptionId)
            .first;
        await db.savePrescription(
          id: sara.prescriptionId,
          profileId: sara.id,
          prescribedOn: DateTime(2026, 11, 1),
          photos: [added],
          items: [
            PrescriptionItemInput(
              medicineId: items.single.id,
              name: 'item',
              days: 3,
            ),
          ],
        );
        await expectReplaced(sara.prescriptionPhoto, added);
      });

      test('on a record', () async {
        final added = await phone.attachments.import(pick('Sara new'));
        final old = (await db.watchAttachments(sara.eventId).first).single;
        await db.softDeleteAttachment(old.id);
        await db.addAttachments(sara.eventId, [added]);
        await expectReplaced(sara.recordPhoto, added);
      });
    });

    group('an edit that names the wrong person', () {
      Future<void> expectNothingMoved() async {
        expect(await phone.photosOf(db, sara.id), sara.photos);
        expect(await phone.photosOf(db, omar.id), omar.photos);
      }

      test('cannot move an insurance card and its photos', () async {
        await expectLater(
          db.saveInsuranceCard(
            id: sara.cardId,
            profileId: omar.id,
            label: 'card',
            frontPhoto: sara.cardFront,
            backPhoto: sara.cardBack,
          ),
          throwsStateError,
        );
        await expectNothingMoved();
      });

      test('cannot move a medicine and its photos', () async {
        await expectLater(
          db.saveMedicine(
            id: sara.medicineId,
            profileId: omar.id,
            name: 'medicine',
            startOn: DateTime(2026, 11, 1),
            photos: [sara.medicinePhoto],
          ),
          throwsStateError,
        );
        await expectNothingMoved();
      });

      test('cannot move a prescription, its medicines or its photos', () async {
        final items = await db
            .watchPrescriptionMedicines(sara.prescriptionId)
            .first;
        await expectLater(
          db.savePrescription(
            id: sara.prescriptionId,
            profileId: omar.id,
            prescribedOn: DateTime(2026, 11, 1),
            photos: [sara.prescriptionPhoto],
            items: [
              PrescriptionItemInput(
                medicineId: items.single.id,
                name: 'item',
                days: 3,
              ),
            ],
          ),
          throwsStateError,
        );
        await expectNothingMoved();
        final after = await db
            .watchPrescriptionMedicines(sara.prescriptionId)
            .first;
        expect(after.single.profileId, sara.id);
      });
    });

    test('two photos never share a place in the image cache', () {
      final a = phone.medicines.image(sara.medicinePhoto);
      expect(a, phone.medicines.image(sara.medicinePhoto));
      expect(a, isNot(phone.medicines.image(omar.medicinePhoto)));
      expect(a, isNot(phone.medicines.image(sara.prescriptionPhoto)));
    });

    test('a photo two rows use stays until the last of them goes', () async {
      await db.saveMedicine(
        id: sara.medicineId,
        profileId: sara.id,
        name: 'medicine',
        startOn: DateTime(2026, 11, 1),
        photos: [sara.prescriptionPhoto],
      );
      await phone.pruneAll(db);
      expect(phone.file(sara.prescriptionPhoto).existsSync(), isTrue);

      await db.softDeleteMedicine(sara.medicineId);
      await phone.pruneAll(db);
      expect(phone.file(sara.prescriptionPhoto).existsSync(), isTrue);

      await db.softDeletePrescription(sara.prescriptionId);
      await phone.pruneAll(db);
      expect(phone.file(sara.prescriptionPhoto).existsSync(), isFalse);
    });

    group('the photo check', () {
      test('finds nothing wrong when nothing is', () async {
        await expectClean(phone, db);
      });

      test('counts photos with no file and files nothing uses', () async {
        phone.file(omar.medicinePhoto).deleteSync();
        phone.file(sara.recordPhoto).deleteSync();
        // An import whose record was never saved, and one left by a delete
        // that wasn't pruned.
        await phone.cards.import(pick('never saved'));
        await db.softDeleteMedicine(sara.medicineId);

        final check = await phone.check(db);
        expect(check.missing, 2);
        expect(check.unused, 2);
      });

      test('agrees with what a backup finds missing', () async {
        phone.file(omar.cardBack).deleteSync();
        phone.file(sara.prescriptionPhoto).deleteSync();
        final made = await phone.service.create(
          db,
          RecoveryKey.generate(),
          appVersion: 'test',
        );
        expect(made.counts[backupMissingPhotosCount], 2);
        expect((await phone.check(db)).missing, 2);
      });

      test('ignores hidden files, and copes with a folder gone', () async {
        phone.file('${PhotoStore.cardsFolder}/.DS_Store').writeAsBytesSync([1]);
        phone.file(sara.medicinePhoto).parent.deleteSync(recursive: true);

        final check = await phone.check(db);
        // Both people's medicine and prescription photos, nothing else.
        expect((check.missing, check.unused), (4, 0));
      });

      test('deletes and changes nothing, even when things are wrong', () async {
        phone.file(omar.medicinePhoto).deleteSync();
        await phone.cards.import(pick('never saved'));
        await db.softDeleteMedicine(sara.medicineId);
        Future<Map<String, String>> everything() async => {
          for (final f
              in phone.root.listSync(recursive: true).whereType<File>())
            f.path:
                '${f.lastModifiedSync()} ${base64.encode(f.readAsBytesSync())}',
          'rows': jsonEncode({
            'cards': (await db.liveInsurancePhotos()).toList()..sort(),
            'attachments': (await db.liveAttachmentPaths()).toList()..sort(),
            'medicines': (await db.liveMedicinePhotos()).toList()..sort(),
            'outbox': (await db.select(db.outboxEntries).get()).length,
          }),
        };
        final before = await everything();

        final check = await phone.check(db);

        expect(check.missing, greaterThan(0));
        expect(check.unused, greaterThan(0));
        expect(await everything(), before);
      });

      test('logs counts only, never a path or a name', () async {
        final lines = <String>[];
        Log.output = lines.add;
        addTearDown(() => Log.output = debugPrint);
        phone.file(omar.medicinePhoto).deleteSync();
        final orphan = await phone.cards.import(pick('never saved'));

        await phone.check(db);

        expect(lines, ['[usra] Photo check (missing: 1, unused: 1)']);
        for (final leak in [omar.medicinePhoto, orphan, 'Omar', 'Sara']) {
          expect(lines.join(), isNot(contains(leak)));
        }
      });
    });
  });

  // Nothing inside the store guards against this. It is safe today only
  // because each form saves its row before it prunes, and every other prune
  // is on a screen the form has already left: test/widget/photo_forms_test.dart
  // pins that order. Importing as soon as a photo is picked, or pruning in
  // the background, would turn this into lost photos.
  test('prune leaves hidden files, like one being written, alone', () async {
    final path = await phone.cards.import(pick('saved'));
    final part = phone.file('${PhotoStore.cardsFolder}/.x.jpg.sealing')
      ..writeAsBytesSync([1]);
    await phone.cards.prune({path});
    expect(part.existsSync(), isTrue);
  });

  test('prune deletes a photo whose row is not saved yet', () async {
    final path = await phone.medicines.import(pick('not saved yet'));
    await phone.medicines.prune(await db.liveMedicinePhotos());
    expect(phone.file(path).existsSync(), isFalse);
  });
}
