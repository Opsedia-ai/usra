import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:usra/core/files/photo_store.dart';
import 'package:usra/l10n/app_localizations.dart';

/// A real (tiny) PNG, so "readable as an image" means something.
final _png = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGA'
  'hKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  late Directory dir;
  late PhotoCipher cipher;
  late PhotoStore store;
  // Recognisable bytes that would show up if anything leaked.
  final photo = Uint8List.fromList([
    ..._png,
    ...List<int>.generate(5000, (i) => (i * 31) % 251),
  ]);

  File picked(List<int> bytes, [String name = 'picked.png']) =>
      File(p.join(dir.path, name))..writeAsBytesSync(bytes);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('usra_photo_store');
    cipher = PhotoCipher(PhotoCipher.generateKey(Random(1)));
    store = PhotoStore(
      Directory(p.join(dir.path, 'support')),
      PhotoStore.attachmentsFolder,
      PhotoKeys.ready(cipher),
    );
  });
  tearDown(() => dir.deleteSync(recursive: true));

  group('a stored photo', () {
    test('is not an image on disk and holds none of its bytes', () async {
      final path = await store.import(picked(photo).path);
      final onDisk = store.fileOf(path).readAsBytesSync();

      expect(PhotoCipher.isSealed(onDisk), isTrue);
      // No PNG signature anywhere, and no run of the photo's bytes.
      expect(_contains(onDisk, _png.sublist(0, 8)), isFalse);
      for (var i = 0; i + 32 <= photo.length; i += 512) {
        expect(_contains(onDisk, photo.sublist(i, i + 32)), isFalse);
      }
      await expectLater(
        decodeImageFromList(onDisk),
        throwsA(anything),
        reason: 'the platform decoder must not read it as an image',
      );
      // Only the encrypted file: no temporary copy left next to it.
      expect(
        store.fileOf(path).parent.listSync().map((e) => p.basename(e.path)),
        [p.basename(path)],
      );
    });

    test('picker copies left by a killed app are cleared at the next '
        'start', () async {
      final tmp = Directory(p.join(dir.path, 'tmp'))..createSync();
      final left = File(p.join(tmp.path, 'image_picker_A1.jpg'))
        ..writeAsBytesSync(photo);
      Directory(p.join(tmp.path, 'sub')).createSync();
      await clearPickerLeftovers(tmp);
      expect(left.existsSync(), isFalse);
      expect(tmp.listSync(), isEmpty);
    });

    test('reads back exactly, in memory', () async {
      final path = await store.import(picked(photo).path);
      expect(await store.read(path), photo);
    });

    test('is sealed with a fresh nonce each time', () {
      expect(cipher.seal(photo), isNot(cipher.seal(photo)));
    });

    test('any change to the file is caught', () {
      final sealed = cipher.seal(photo);
      // The header (magic, version, nonce), the middle and the tag.
      for (final i in [
        0,
        7,
        8,
        31,
        32,
        sealed.length ~/ 2,
        sealed.length - 1,
      ]) {
        final changed = Uint8List.fromList(sealed)..[i] ^= 0x01;
        expect(
          () => cipher.open(changed),
          throwsA(isA<PhotoUnreadableException>()),
          reason: 'byte $i',
        );
      }
      for (final cut in [
        0,
        10,
        PhotoCipher.headerLength + 15,
        sealed.length - 1,
      ]) {
        expect(
          () => cipher.open(sealed.sublist(0, cut)),
          throwsA(isA<PhotoUnreadableException>()),
          reason: 'cut at $cut',
        );
      }
      expect(
        () => cipher.open([...sealed, 0]),
        throwsA(isA<PhotoUnreadableException>()),
      );
    });

    test('opens only with this phone\'s key', () {
      final other = PhotoCipher(PhotoCipher.generateKey(Random(2)));
      expect(
        () => other.open(cipher.seal(photo)),
        throwsA(isA<PhotoUnreadableException>()),
      );
    });

    test('a plain file is refused, not shown', () async {
      store.fileOf('attachments/plain.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(photo);
      await expectLater(
        store.read('attachments/plain.png'),
        throwsA(isA<PhotoUnreadableException>()),
      );
    });

    testWidgets('shows through the image provider', (tester) async {
      await tester.runAsync(() async {
        final path = await store.import(picked(_png).path);
        final image = store.image(path);
        expect(image, store.image(path));
        final info = Completer<ImageInfo>();
        image
            .resolve(ImageConfiguration.empty)
            .addListener(
              ImageStreamListener(
                (i, _) => info.complete(i),
                onError: (e, _) => info.completeError(e),
              ),
            );
        final loaded = await info.future.timeout(const Duration(seconds: 20));
        expect(loaded.image.width, 1);
        loaded.dispose();
      });
    });

    testWidgets('a changed file shows as a broken image', (tester) async {
      final path = (await tester.runAsync(
        () => store.import(picked(_png).path),
      ))!;
      final file = store.fileOf(path);
      final bytes = file.readAsBytesSync();
      file.writeAsBytesSync(bytes..[bytes.length - 1] ^= 1);
      await tester.runAsync(() async {
        final failed = Completer<Object>();
        store
            .image(path)
            .resolve(ImageConfiguration.empty)
            .addListener(
              ImageStreamListener(
                (_, _) => failed.completeError('decoded'),
                onError: (e, _) => failed.complete(e),
              ),
            );
        expect(
          await failed.future.timeout(const Duration(seconds: 20)),
          isA<PhotoUnreadableException>(),
        );
      });
    });
  });

  group('photos from before encryption', () {
    void writePlain(String name, List<int> bytes) => (store.fileOf(
      'attachments/$name',
    )..createSync(recursive: true)).writeAsBytesSync(bytes);

    test('are encrypted in place, once', () async {
      writePlain('a.jpg', photo);
      writePlain('b.png', [1, 2, 3]);
      writePlain('.DS_Store', [0]);

      expect(await store.sealPlainFiles(), 2);
      expect(await store.read('attachments/a.jpg'), photo);
      expect(await store.read('attachments/b.png'), [1, 2, 3]);
      final sealedOnce = store.fileOf('attachments/a.jpg').readAsBytesSync();

      // Already done: nothing changes on the next start.
      expect(await store.sealPlainFiles(), 0);
      expect(store.fileOf('attachments/a.jpg').readAsBytesSync(), sealedOnce);
      // Hidden system files are left alone.
      expect(store.fileOf('attachments/.DS_Store').readAsBytesSync(), [0]);
    });

    test('a run killed half way is finished on the next start', () async {
      writePlain('a.jpg', photo);
      writePlain('b.jpg', [7, 7]);
      // Killed after writing a's encrypted copy, before the rename: the
      // plain photo is still there, with a stray (maybe partial) copy.
      final stray = store.fileOf('attachments/.a.jpg.sealing')
        ..writeAsBytesSync(cipher.seal(photo).sublist(0, 100));
      // And b was already done before that.
      store.fileOf('attachments/b.jpg').writeAsBytesSync(cipher.seal([7, 7]));

      expect(await store.sealPlainFiles(), 1);
      expect(stray.existsSync(), isFalse);
      expect(await store.read('attachments/a.jpg'), photo);
      expect(await store.read('attachments/b.jpg'), [7, 7]);
    });

    test('one photo that fails does not keep the rest plain', () async {
      writePlain('a.jpg', [1]);
      writePlain('b.jpg', [2]);
      writePlain('c.jpg', [3]);
      final locked = store.fileOf('attachments/b.jpg');
      Process.runSync('chmod', ['000', locked.path]);
      addTearDown(() => Process.runSync('chmod', ['644', locked.path]));

      await expectLater(store.sealPlainFiles(), throwsA(anything));
      expect(await store.read('attachments/a.jpg'), [1]);
      expect(await store.read('attachments/c.jpg'), [3]);
    });

    test('no folder yet is fine', () async {
      expect(await store.sealPlainFiles(), 0);
    });
  });

  group('sharing', () {
    test('decrypts to the cache only, and clears it', () async {
      final a = await store.import(picked(photo).path);
      final b = await store.import(picked([5, 6], 'b.jpg').path);
      final temporary = Directory(p.join(dir.path, 'cache'))..createSync();
      final cache = SharedPhotoCache(temporary);

      final files = await cache.copyOut(store, [
        a,
        b,
        'attachments/missing.jpg',
      ]);
      expect(files, hasLength(2));
      expect(await files[0].readAsBytes(), photo);
      expect(files[0].mimeType, 'image/png');
      expect(p.isWithin(temporary.path, files[0].path), isTrue);
      expect(await files[1].readAsBytes(), [5, 6]);

      await cache.clear();
      expect(
        Directory(p.join(temporary.path, SharedPhotoCache.folderName))
            .existsSync(),
        isFalse,
      );
      // The stored photos are untouched.
      expect(await store.read(a), photo);
    });
  });

  group('the real store end to end', () {
    test(
      'writes atomically: the old file stays whole if a write fails',
      () async {
        final path = await store.import(picked(photo).path);
        final file = store.fileOf(path);
        final before = file.readAsBytesSync();

        // Replaced in one rename, never written in place.
        await writeSealedFile(file, cipher.seal([1, 2, 3]));
        expect(await store.read(path), [1, 2, 3]);
        expect(file.parent.listSync(), hasLength(1));

        // A write that can't happen (folder read-only) leaves it untouched.
        file.writeAsBytesSync(before);
        Process.runSync('chmod', ['555', file.parent.path]);
        addTearDown(() => Process.runSync('chmod', ['755', file.parent.path]));
        await expectLater(
          writeSealedFile(file, cipher.seal([4])),
          throwsA(isA<FileSystemException>()),
        );
        expect(await store.read(path), photo);
      },
    );

    test('many photos at once go through one worker, each correct', () async {
      final paths = [
        for (var i = 0; i < 12; i++)
          await store.import(picked([...photo, i], 'p$i.png').path),
      ];
      final read = await Future.wait([
        for (final path in paths) store.read(path),
      ]);
      for (var i = 0; i < paths.length; i++) {
        expect(read[i], [...photo, i]);
      }
      // Errors come back as themselves, and the worker keeps going.
      final bad = store.fileOf(paths.first);
      bad.writeAsBytesSync(bad.readAsBytesSync()..[40] ^= 1);
      await expectLater(
        store.read(paths.first),
        throwsA(isA<PhotoUnreadableException>()),
      );
      expect(await store.read(paths.last), [...photo, 11]);
    });
  });

  group('migration in the background', () {
    test('plain photos show until it has finished, then are refused', () async {
      final plain = store.fileOf('attachments/old.jpg')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2]);
      final migrating = store.sealPlainFiles();
      // Readable straight away, whether or not it was reached yet.
      expect(await store.read('attachments/old.jpg'), [1, 2]);
      expect(await migrating, 1);
      expect(PhotoCipher.isSealed(plain.readAsBytesSync()), isTrue);

      // Once done, a plain file is something that shouldn't be there.
      store.fileOf('attachments/late.jpg').writeAsBytesSync([3]);
      await expectLater(
        store.read('attachments/late.jpg'),
        throwsA(isA<PhotoUnreadableException>()),
      );
    });

    test('without a key, plain photos still show', () async {
      final locked = PhotoStore(
        store.root,
        PhotoStore.attachmentsFolder,
        PhotoKeys.unavailable(PhotoKeyProblem.lost),
      );
      locked.fileOf('attachments/old.jpg')
        ..createSync(recursive: true)
        ..writeAsBytesSync([5]);
      await expectLater(
        locked.sealPlainFiles(),
        throwsA(isA<PhotoKeyUnavailableException>()),
      );
      expect(await locked.read('attachments/old.jpg'), [5]);
    });
  });

  group('the photo key', () {
    Future<bool> none() async => false;
    Future<bool> some() async => true;

    test('is made on first start, then read back', () async {
      final keys = MemoryPhotoKeyStore();
      final first = await keys.load(sealedPhotosExist: none);
      expect(first.cipher, isNotNull);
      expect(keys.value, isNotNull);
      final again = await keys.load(sealedPhotosExist: some);
      expect(again.require.keyBytes, first.require.keyBytes);
    });

    test(
      'missing while encrypted photos exist: lost, never replaced',
      () async {
        final keys = MemoryPhotoKeyStore();
        final loaded = await keys.load(sealedPhotosExist: some);
        expect(loaded.cipher, isNull);
        expect(loaded.problem, PhotoKeyProblem.lost);
        // No new key hides the loss.
        expect(keys.value, isNull);
      },
    );

    test('corrupt: a clear state, kept as it was', () async {
      for (final bad in ['not base64!', 'AAAA']) {
        final keys = MemoryPhotoKeyStore(bad);
        final loaded = await keys.load(sealedPhotosExist: some);
        expect(loaded.problem, PhotoKeyProblem.corrupt);
        expect(keys.value, bad);
      }
    });

    test(
      "a key store that fails or never answers doesn't hang start-up",
      () async {
        final failing = _FailingKeyStore(Future.error(StateError('keystore')));
        expect(
          (await failing.load(sealedPhotosExist: none)).problem,
          PhotoKeyProblem.unreadable,
        );
        final silent = _FailingKeyStore(Completer<String?>().future);
        final loaded = await silent.load(
          sealedPhotosExist: none,
          timeout: const Duration(milliseconds: 50),
        );
        expect(loaded.problem, PhotoKeyProblem.unreadable);
        // Never overwritten: the real key may still be in there.
        expect(failing.written || silent.written, isFalse);
      },
    );

    test('lost is detected from the files on disk', () async {
      final root = Directory(p.join(dir.path, 'support'));
      expect(
        await anySealedPhoto(root, [PhotoStore.attachmentsFolder]),
        isFalse,
      );
      store.fileOf('attachments/plain.jpg')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1]);
      expect(
        await anySealedPhoto(root, [PhotoStore.attachmentsFolder]),
        isFalse,
      );
      await store.import(picked(photo).path);
      expect(
        await anySealedPhoto(root, [PhotoStore.attachmentsFolder]),
        isTrue,
      );
    });

    test("without it, photos can't be opened or saved", () async {
      final path = await store.import(picked(photo).path);
      final locked = PhotoStore(
        store.root,
        PhotoStore.attachmentsFolder,
        PhotoKeys.unavailable(PhotoKeyProblem.lost),
      );
      await expectLater(
        locked.read(path),
        throwsA(isA<PhotoKeyUnavailableException>()),
      );
      await expectLater(
        locked.import(picked(photo).path),
        throwsA(isA<PhotoKeyUnavailableException>()),
      );
    });

    testWidgets('without it, photos say so instead of looking broken', (
      tester,
    ) async {
      final path = (await tester.runAsync(
        () => store.import(picked(photo).path),
      ))!;
      final locked = PhotoStore(
        store.root,
        PhotoStore.attachmentsFolder,
        PhotoKeys.unavailable(PhotoKeyProblem.lost),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PhotoImage(image: locked.image(path), height: 200),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
        if (find.byKey(const ValueKey('photos-locked')).evaluate().isNotEmpty) {
          break;
        }
      }
      expect(find.byKey(const ValueKey('photos-locked')), findsOneWidget);
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    });
  });

  group('share leftovers', () {
    late Directory temporary;
    Directory folder(String name) => Directory(p.join(temporary.path, name));
    void leave(String name) => (File(
      p.join(folder(name).path, 'x.jpg'),
    )..createSync(recursive: true)).writeAsBytesSync([1]);

    setUp(() => temporary = Directory(p.join(dir.path, 'cache'))..createSync());

    test('clearing removes share_plus\'s own copies too', () async {
      leave(SharedPhotoCache.folderName);
      leave(SharedPhotoCache.sharePlusFolder);
      leave('unrelated');
      await SharedPhotoCache(temporary).clear();
      expect(folder(SharedPhotoCache.folderName).existsSync(), isFalse);
      expect(folder(SharedPhotoCache.sharePlusFolder).existsSync(), isFalse);
      expect(folder('unrelated').existsSync(), isTrue);
    });

    testWidgets('on Android: ours go when the sheet returns, share_plus\'s '
        'when Usra is back in front', (tester) async {
      await tester.runAsync(() async {
        leave(SharedPhotoCache.folderName);
        leave(SharedPhotoCache.sharePlusFolder);
        await SharedPhotoCache(temporary, android: true).clearAfterShare();
      });
      expect(folder(SharedPhotoCache.folderName).existsSync(), isFalse);
      // WhatsApp may still be reading it.
      expect(folder(SharedPhotoCache.sharePlusFolder).existsSync(), isTrue);

      // Real async: the delete is file I/O, which the fake clock never runs.
      await tester.runAsync(() async {
        final binding = tester.binding;
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        // Deleted in the background: wait for it, up to a few seconds.
        final sharePlus = folder(SharedPhotoCache.sharePlusFolder);
        for (var i = 0; i < 100 && sharePlus.existsSync(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      expect(folder(SharedPhotoCache.sharePlusFolder).existsSync(), isFalse);
    });

    testWidgets('on iOS: nothing is kept once the sheet returns', (
      tester,
    ) async {
      await tester.runAsync(() async {
        leave(SharedPhotoCache.folderName);
        await SharedPhotoCache(temporary, android: false).clearAfterShare();
      });
      expect(folder(SharedPhotoCache.folderName).existsSync(), isFalse);
    });
  });
}

class _FailingKeyStore extends PhotoKeyStore {
  _FailingKeyStore(this._read);

  final Future<String?> _read;
  var written = false;

  @override
  Future<String?> readRaw() => _read;

  @override
  Future<void> writeRaw(String value) async => written = true;
}

/// Whether [needle] appears anywhere in [haystack].
bool _contains(List<int> haystack, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}
