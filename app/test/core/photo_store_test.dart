import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:usra/core/files/photo_store.dart';

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
      cipher,
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
