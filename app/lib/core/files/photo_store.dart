import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import 'photo_crypto.dart';

export 'photo_crypto.dart';

/// Where insurance card photos live; provided in `main.dart`.
final cardPhotoStoreProvider = Provider<PhotoStore>(
  (ref) =>
      throw UnimplementedError('cardPhotoStoreProvider must be overridden'),
);

/// Where photos attached to records live; provided in `main.dart`.
final attachmentStoreProvider = Provider<PhotoStore>(
  (ref) =>
      throw UnimplementedError('attachmentStoreProvider must be overridden'),
);

/// Picks a photo and returns its temporary path, or null if cancelled.
/// Overridden in tests.
final photoPickerProvider = Provider<Future<String?> Function(ImageSource)>(
  (ref) => (source) async {
    final photo = await ImagePicker().pickImage(
      source: source,
      // A card or a report page is readable at this size and stays a few
      // hundred KB.
      maxWidth: _maxSide,
      maxHeight: _maxSide,
      imageQuality: _quality,
      requestFullMetadata: false,
    );
    return photo?.path;
  },
);

/// Picks several photos from the gallery and returns their temporary paths
/// (empty if cancelled). Overridden in tests.
final multiPhotoPickerProvider = Provider<Future<List<String>> Function()>(
  (ref) => () async {
    final photos = await ImagePicker().pickMultiImage(
      maxWidth: _maxSide,
      maxHeight: _maxSide,
      imageQuality: _quality,
      requestFullMetadata: false,
    );
    return [for (final x in photos) x.path];
  },
);

const double _maxSide = 2000;
const int _quality = 85;

/// Opens the system share sheet. Overridden in tests.
final shareProvider = Provider<Future<void> Function(ShareParams)>(
  (ref) =>
      (params) => SharePlus.instance.share(params),
);

/// Keeps photos in the app's private folder, next to the database, each
/// kind in its own [folder], encrypted with [cipher] (see [PhotoCipher]).
///
/// Never in the photo gallery, and never on disk unencrypted: photos are
/// decrypted into memory to show them ([image]) and only written out
/// decrypted for the share sheet ([SharedPhotoCache]). The folders are
/// also kept out of iCloud backup, since the key never leaves this phone.
/// (Android backup is switched off for the whole app.)
class PhotoStore {
  PhotoStore(this.root, this.folder, this.cipher);

  /// The app's private folder; photos go in [folder] inside it.
  final Directory root;
  final String folder;
  final PhotoCipher cipher;

  static const cardsFolder = 'insurance_cards';
  static const attachmentsFolder = 'attachments';
  static const medicinesFolder = 'medicines';
  static const _uuid = Uuid();
  static const _files = MethodChannel('usra/files');

  static Future<PhotoStore> open(String folder, PhotoCipher cipher) async =>
      PhotoStore(await getApplicationSupportDirectory(), folder, cipher);

  Directory get _dir => Directory(p.join(root.path, folder));

  /// Keeps [dir] out of iCloud backup; excluding a folder covers every file
  /// in it. (Android backup is off for the whole app.)
  static Future<void> excludeFromBackup(Directory dir) async {
    if (Platform.isIOS) {
      await _files.invokeMethod<void>('excludeFromBackup', dir.path);
    }
  }

  /// The encrypted file for a path saved in the database.
  File fileOf(String relativePath) => File(p.join(root.path, relativePath));

  /// Encrypts a picked photo in and returns the path to save in the
  /// database. Throws, storing nothing, if the folder can't be kept out of
  /// backup.
  Future<String> import(String sourcePath) async {
    await _dir.create(recursive: true);
    // Cheap and idempotent, so done every time rather than trusting an
    // earlier call.
    await excludeFromBackup(_dir);
    final ext = p.extension(sourcePath).toLowerCase();
    final relative = p.join(
      folder,
      '${_uuid.v7()}${ext.isEmpty ? '.jpg' : ext}',
    );
    final plain = await File(sourcePath).readAsBytes();
    final key = cipher.keyBytes;
    final sealed = await Isolate.run(() => PhotoCipher(key).seal(plain));
    await writeSealedFile(fileOf(relative), sealed);
    return relative;
  }

  /// The photo's bytes, decrypted in memory. Throws
  /// [PhotoUnreadableException] if the file was changed or can't be opened.
  Future<Uint8List> read(String relativePath) async {
    final sealed = await fileOf(relativePath).readAsBytes();
    // Tens of milliseconds for a full photo: off the UI thread.
    final key = cipher.keyBytes;
    return Isolate.run(() => PhotoCipher(key).open(sealed));
  }

  /// The photo for an [Image], decrypted in memory.
  ImageProvider image(String relativePath) =>
      StoredPhotoImage(this, relativePath);

  /// Deletes every photo in [folder] not in [keep] (replaced, or what it
  /// belonged to was deleted).
  Future<void> prune(Set<String> keep) async {
    if (!await _dir.exists()) return;
    await for (final entity in _dir.list()) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: root.path);
      if (!keep.contains(relative)) {
        try {
          await entity.delete();
        } on FileSystemException {
          // Already gone; nothing to do.
        }
      }
    }
  }

  /// Encrypts the photos saved before photos were encrypted, in an isolate.
  /// Safe to run on every start and to be killed half way: each file is
  /// only replaced once its encrypted copy has been written and read back.
  /// Returns how many were encrypted.
  Future<int> sealPlainFiles() {
    final (dir, key) = (_dir.path, cipher.keyBytes);
    return Isolate.run(() => sealPlainPhotos(Directory(dir), PhotoCipher(key)));
  }
}

/// Writes [sealed] to [file] through a hidden temporary file and a rename,
/// so [file] is either the old one or the whole new one, never half.
Future<void> writeSealedFile(File file, List<int> sealed) async {
  final part = File(
    p.join(file.parent.path, '.${p.basename(file.path)}$_partSuffix'),
  );
  await part.writeAsBytes(sealed, flush: true);
  await part.rename(file.path);
}

const _partSuffix = '.sealing';

/// See [PhotoStore.sealPlainFiles].
Future<int> sealPlainPhotos(Directory dir, PhotoCipher cipher) async {
  if (!await dir.exists()) return 0;
  // Listed first, so the clean-up below never meets a file this run made.
  final files = await dir.list().where((e) => e is File).toList();
  final candidates = <File>[];
  for (final entity in files.whereType<File>()) {
    final name = p.basename(entity.path);
    if (!name.startsWith('.')) {
      candidates.add(entity);
    } else if (name.endsWith(_partSuffix)) {
      // Left by a run that was killed before its rename; the plain photo
      // it was for is still there and is done again below.
      await entity.delete();
    }
  }
  var sealed = 0;
  Object? failure;
  for (final entity in candidates) {
    // One photo that fails mustn't keep the rest plain; it is tried again
    // on the next start.
    try {
      if (await _sealPlainPhoto(entity, cipher)) sealed++;
    } catch (e) {
      failure ??= e;
    }
  }
  if (failure != null) throw failure;
  return sealed;
}

/// Seals [file] in place if it's plain; false if it was sealed already.
Future<bool> _sealPlainPhoto(File file, PhotoCipher cipher) async {
  // Only the magic on every start, not the whole photo.
  final head = await file
      .openRead(0, PhotoCipher.magic.length)
      .fold(<int>[], (all, piece) => all..addAll(piece));
  if (PhotoCipher.isSealed(head)) return false;
  final plain = await file.readAsBytes();
  final part = File(
    p.join(file.parent.path, '.${p.basename(file.path)}$_partSuffix'),
  );
  await part.writeAsBytes(cipher.seal(plain), flush: true);
  // Read back from disk: the plain photo goes only once this opens to
  // exactly the same bytes.
  final check = cipher.open(await part.readAsBytes());
  if (!listEquals(check, plain)) {
    await part.delete();
    throw StateError('Encrypted photo did not read back the same');
  }
  await part.rename(file.path);
  return true;
}

/// A stored photo, decrypted in memory for [Image]. Decoded images live in
/// Flutter's [ImageCache] (bounded) like any other image; the decrypted
/// bytes are dropped as soon as they are decoded.
@immutable
class StoredPhotoImage extends ImageProvider<StoredPhotoImage> {
  const StoredPhotoImage(this.store, this.path);

  final PhotoStore store;
  final String path;

  @override
  Future<StoredPhotoImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    StoredPhotoImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _load(key, decode),
    scale: 1,
    debugLabel: path,
  );

  Future<ui.Codec> _load(
    StoredPhotoImage key,
    ImageDecoderCallback decode,
  ) async {
    try {
      final bytes = await store.read(path);
      return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } catch (_) {
      // Not cached, so a photo restored or repaired later shows up.
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is StoredPhotoImage &&
      other.store.root.path == store.root.path &&
      other.path == path;

  @override
  int get hashCode => Object.hash(store.root.path, path);

  @override
  String toString() => 'StoredPhotoImage($path)';
}

/// Where photos are decrypted for the share sheet; overridden in tests.
final sharedPhotoCacheProvider = Provider<SharedPhotoCache>(
  (ref) => SharedPhotoCache.system(),
);

/// Decrypted copies of photos for the share sheet (WhatsApp needs a file):
/// the only time a photo is on disk unencrypted. They go in one folder in
/// the cache, emptied after sharing, before the next share and on every
/// start.
class SharedPhotoCache {
  SharedPhotoCache(this._temporary);

  SharedPhotoCache.system() : _temporary = getTemporaryDirectory();

  final FutureOr<Directory> _temporary;

  static const folderName = 'usra-share';

  Future<Directory> get _dir async =>
      Directory(p.join((await _temporary).path, folderName));

  /// Decrypts stored photos into files to share, leaving out any that are
  /// missing or no longer open.
  Future<List<XFile>> copyOut(PhotoStore store, Iterable<String> paths) async {
    final dir = await _dir;
    await dir.create(recursive: true);
    final files = <XFile>[];
    for (final path in paths) {
      final Uint8List bytes;
      try {
        bytes = await store.read(path);
      } on PhotoUnreadableException {
        continue;
      } on FileSystemException {
        continue;
      }
      final file = File(p.join(dir.path, p.basename(path)));
      await file.writeAsBytes(bytes, flush: true);
      files.add(XFile(file.path, mimeType: photoMimeOf(path)));
    }
    return files;
  }

  /// Deletes every decrypted copy.
  Future<void> clear() async {
    final dir = await _dir;
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Deletes the copies once the share is over: right away on iOS (the
  /// sheet reports back after the other app took the files), and on
  /// Android when Usra comes back to the front, since WhatsApp may still
  /// be reading the file after the sheet closes.
  void clearAfterShare() {
    if (!Platform.isAndroid) {
      unawaited(clear().catchError((Object _) {}));
      return;
    }
    late final AppLifecycleListener listener;
    listener = AppLifecycleListener(
      onResume: () {
        listener.dispose();
        unawaited(clear().catchError((Object _) {}));
      },
    );
  }
}

/// Shares stored photos with [text] through the share sheet, decrypting
/// them to [SharedPhotoCache] for as long as the share takes.
Future<void> shareStoredPhotos(
  WidgetRef ref,
  PhotoStore store,
  Iterable<String> paths, {
  String? text,
  Rect? origin,
}) async {
  // Read now: the screen may be gone once the photos are decrypted.
  final (cache, share) = (
    ref.read(sharedPhotoCacheProvider),
    ref.read(shareProvider),
  );
  await cache.clear();
  try {
    final files = await cache.copyOut(store, paths);
    await share(
      ShareParams(
        text: text,
        files: files.isEmpty ? null : files,
        // iPad needs to know where to anchor the share sheet.
        sharePositionOrigin: origin,
      ),
    );
  } finally {
    cache.clearAfterShare();
  }
}

/// The MIME type to share a stored photo with.
String photoMimeOf(String path) => switch (p.extension(path).toLowerCase()) {
  '.png' => 'image/png',
  '.heic' => 'image/heic',
  _ => 'image/jpeg',
};

/// Deletes a picked photo's temporary file, if it's still there.
void discardPicked(String path) {
  try {
    File(path).deleteSync();
  } on FileSystemException {
    // Already gone.
  }
}

/// A photo, or a broken-image icon if it can't be read. [image] is
/// [PhotoStore.image] for a stored photo, or a [FileImage] for one just
/// picked (still the picker's own temporary file).
class PhotoImage extends StatelessWidget {
  const PhotoImage({
    super.key,
    required this.image,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
    this.cacheWidth,
    this.semanticLabel,
  });

  final ImageProvider image;
  final double? height;
  final double? width;
  final BoxFit fit;

  /// Decode at this width, so thumbnails don't hold full photos in memory.
  final int? cacheWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Image(
    image: ResizeImage.resizeIfNeeded(cacheWidth, null, image),
    height: height,
    width: width,
    fit: fit,
    semanticLabel: semanticLabel,
    errorBuilder: (_, _, _) => SizedBox(
      height: height ?? 120,
      width: width,
      child: const Center(child: Icon(Icons.broken_image_outlined, size: 40)),
    ),
  );
}
