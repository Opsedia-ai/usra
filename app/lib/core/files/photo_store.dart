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

import '../preferences.dart';
import '../security/app_lock.dart';
import '../security/file_protection.dart';
import '../security/share_warning.dart';
import '../../l10n/app_localizations.dart';
import 'photo_crypto.dart';
import 'photo_worker.dart';

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
    final photo = await whileInOtherApp(
      () => ImagePicker().pickImage(
        source: source,
        // A card or a report page is readable at this size and stays a few
        // hundred KB.
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: _quality,
        requestFullMetadata: false,
      ),
    );
    return photo?.path;
  },
);

/// Picks several photos from the gallery and returns their temporary paths
/// (empty if cancelled). Overridden in tests.
final multiPhotoPickerProvider = Provider<Future<List<String>> Function()>(
  (ref) => () async {
    final photos = await whileInOtherApp(
      () => ImagePicker().pickMultiImage(
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: _quality,
        requestFullMetadata: false,
      ),
    );
    return [for (final x in photos) x.path];
  },
);

const double _maxSide = 2000;
const int _quality = 85;

/// Opens the system share sheet. Overridden in tests.
final shareProvider = Provider<Future<void> Function(ShareParams)>(
  (ref) =>
      (params) => whileInOtherApp(() => SharePlus.instance.share(params)),
);

/// Keeps photos in the app's private folder, next to the database, each
/// kind in its own [folder], encrypted with the key in [keys] (see
/// [PhotoCipher]).
///
/// Never in the photo gallery, and never on disk unencrypted: photos are
/// decrypted into memory to show them ([image]) and only written out
/// decrypted for the share sheet ([SharedPhotoCache]). The folders are
/// also kept out of iCloud backup, since the key never leaves this phone.
/// (Android backup is switched off for the whole app.)
class PhotoStore {
  PhotoStore(this.root, this.folder, this.keys);

  /// The app's private folder; photos go in [folder] inside it.
  final Directory root;
  final String folder;

  /// Shared by every folder; without a key nothing can be opened or saved
  /// ([PhotoKeyUnavailableException]).
  final PhotoKeys keys;

  /// True until [sealPlainFiles] has encrypted every plain photo: until
  /// then a photo from before encryption is shown as it is.
  var _plainAllowed = false;

  static const cardsFolder = 'insurance_cards';
  static const attachmentsFolder = 'attachments';
  static const medicinesFolder = 'medicines';
  static const _uuid = Uuid();
  static const _files = MethodChannel('usra/files');

  static Future<PhotoStore> open(String folder, PhotoKeys keys) async =>
      PhotoStore(await getApplicationSupportDirectory(), folder, keys);

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
  /// backup or there is no photo key.
  Future<String> import(String sourcePath) async {
    final cipher = keys.require;
    final created = !await _dir.exists();
    await _dir.create(recursive: true);
    // Cheap and idempotent, so done every time rather than trusting an
    // earlier call.
    await excludeFromBackup(_dir);
    // iOS: photos are unreadable while the phone is locked (S9); files
    // saved in the folder take this from it. Set again at each start.
    if (created) {
      await protectFiles(_dir, FileProtection.complete, contents: false);
    }
    final ext = p.extension(sourcePath).toLowerCase();
    final relative = p.join(
      folder,
      '${_uuid.v7()}${ext.isEmpty ? '.jpg' : ext}',
    );
    final plain = await File(sourcePath).readAsBytes();
    final sealed = await PhotoWorker.instance.seal(cipher, plain);
    await writeSealedFile(fileOf(relative), sealed);
    return relative;
  }

  /// The photo's bytes, decrypted in memory. Throws
  /// [PhotoUnreadableException] if the file was changed or can't be opened,
  /// and [PhotoKeyUnavailableException] if there is no key to open it.
  Future<Uint8List> read(String relativePath) async {
    final bytes = await fileOf(relativePath).readAsBytes();
    if (_plainAllowed && !PhotoCipher.isSealed(bytes)) return bytes;
    final cipher = keys.require;
    // Tens of milliseconds for a full photo: off the UI thread.
    return PhotoWorker.instance.open(cipher, bytes);
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

  /// Encrypts the photos saved before photos were encrypted, in an isolate,
  /// while the app is already running: photos still plain are shown as they
  /// are until this has finished without a failure. Safe to run on every
  /// start and to be killed half way: each file is only replaced once its
  /// encrypted copy has been written and read back. Returns how many were
  /// encrypted.
  Future<int> sealPlainFiles() async {
    // Set before the first await, so reads that start now still work.
    _plainAllowed = true;
    final (dir, key) = (_dir.path, keys.require.keyBytes);
    final sealed = await Isolate.run(
      () => sealPlainPhotos(Directory(dir), PhotoCipher(key)),
    );
    _plainAllowed = false;
    return sealed;
  }
}

/// Whether any of [folders] in [root] holds an encrypted photo: if so, a
/// missing key was lost rather than never made.
Future<bool> anySealedPhoto(Directory root, Iterable<String> folders) async {
  for (final folder in folders) {
    final dir = Directory(p.join(root.path, folder));
    if (!await dir.exists()) continue;
    await for (final entity in dir.list()) {
      if (entity is! File || p.basename(entity.path).startsWith('.')) {
        continue;
      }
      if (PhotoCipher.isSealed(await _head(entity))) return true;
    }
  }
  return false;
}

Future<List<int>> _head(File file) => file
    .openRead(0, PhotoCipher.magic.length)
    .fold(<int>[], (all, piece) => all..addAll(piece));

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
  if (PhotoCipher.isSealed(await _head(file))) return false;
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
/// the only time a photo is on disk unencrypted.
///
/// Ours go in one folder in the cache and are deleted as soon as the sheet
/// returns. On Android, share_plus copies every shared file again, into
/// `<cache>/share_plus/` (what the other app actually reads), and only
/// empties that at its next share; that folder is deleted when Usra comes
/// back to the front, before every share and on every start. (On iOS the
/// sheet reads our file directly and keeps no copy.)
class SharedPhotoCache {
  SharedPhotoCache(this._temporary, {bool? android})
    : _android = android ?? Platform.isAndroid;

  SharedPhotoCache.system()
    : _temporary = getTemporaryDirectory(),
      _android = Platform.isAndroid;

  final FutureOr<Directory> _temporary;
  final bool _android;

  static const folderName = 'usra-share';

  /// share_plus's own copies on Android (`Share.kt`, `shareCacheFolder`).
  static const sharePlusFolder = 'share_plus';

  Future<Directory> _folder(String name) async =>
      Directory(p.join((await _temporary).path, name));

  /// Decrypts stored photos into files to share, leaving out any that are
  /// missing or can't be opened.
  Future<List<XFile>> copyOut(PhotoStore store, Iterable<String> paths) async {
    final dir = await _folder(folderName);
    await dir.create(recursive: true);
    final files = <XFile>[];
    for (final path in paths) {
      final Uint8List bytes;
      try {
        bytes = await store.read(path);
      } on PhotoUnreadableException {
        continue;
      } on PhotoKeyUnavailableException {
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

  /// Deletes our decrypted copies.
  Future<void> clearCopies() => _delete(folderName);

  /// Deletes our copies and share_plus's.
  Future<void> clear() async {
    await _delete(folderName);
    await _delete(sharePlusFolder);
  }

  Future<void> _delete(String name) async {
    final dir = await _folder(name);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Once the sheet has returned: our copies go now (on Android share_plus
  /// has its own by then). share_plus's go when Usra is back in front, not
  /// now, since the app the user picked may still be reading them.
  /// Completes once our copies are gone.
  Future<void> clearAfterShare() {
    final ours = clearCopies().catchError((Object _) {});
    if (!_android) return ours;
    late final AppLifecycleListener listener;
    listener = AppLifecycleListener(
      onResume: () {
        listener.dispose();
        unawaited(clear().catchError((Object _) {}));
      },
    );
    return ours;
  }
}

/// Shares stored photos with [text] through the share sheet, decrypting
/// them to [SharedPhotoCache] for as long as the share takes. Warns first
/// that they leave the app's protection ([confirmShareOutside]).
Future<void> shareStoredPhotos(
  WidgetRef ref,
  PhotoStore store,
  Iterable<String> paths, {
  String? text,
  Rect? origin,
}) async {
  // Read now: the screen may be gone once the photos are decrypted.
  final (cache, share, prefs) = (
    ref.read(sharedPhotoCacheProvider),
    ref.read(shareProvider),
    ref.read(keyValueStoreProvider),
  );
  if (!ref.context.mounted || !await confirmShareOutside(ref.context, prefs)) {
    return;
  }
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
    unawaited(cache.clearAfterShare());
  }
}

/// The MIME type to share a stored photo with.
String photoMimeOf(String path) => switch (p.extension(path).toLowerCase()) {
  '.png' => 'image/png',
  '.heic' => 'image/heic',
  _ => 'image/jpeg',
};

/// Deletes what pickers and the camera left in [dir] (iOS `tmp/`, where
/// image_picker writes photos unencrypted): copies of photos whose form was
/// never closed, because the app was killed. Run at start-up, before any
/// form can be open; a form deletes its own copies when it closes.
Future<void> clearPickerLeftovers(Directory dir) async {
  if (!await dir.exists()) return;
  await for (final entity in dir.list(followLinks: false)) {
    try {
      await entity.delete(recursive: true);
    } on FileSystemException {
      // In use by the system; tried again next start.
    }
  }
}

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
    errorBuilder: (context, error, _) => SizedBox(
      height: height ?? 120,
      width: width,
      child: error is PhotoKeyUnavailableException
          // Not a damaged photo: none can be opened here, and a broken
          // image wouldn't say what to do about it.
          ? Tooltip(
              message: AppLocalizations.of(context).photosLocked,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 32),
                    if ((height ?? 120) >= 100)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          AppLocalizations.of(context).photosLocked,
                          key: const ValueKey('photos-locked'),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            )
          : const Center(child: Icon(Icons.broken_image_outlined, size: 40)),
    ),
  );
}
