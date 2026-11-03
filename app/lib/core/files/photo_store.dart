import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

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
/// kind in its own [folder].
///
/// Never in the photo gallery, and kept out of iCloud backup: the photos
/// are not encrypted like the database, so they must stay on this phone.
/// (Android backup is switched off for the whole app.)
class PhotoStore {
  PhotoStore(this.root, this.folder);

  /// The app's private folder; photos go in [folder] inside it.
  final Directory root;
  final String folder;

  static const cardsFolder = 'insurance_cards';
  static const attachmentsFolder = 'attachments';
  static const _uuid = Uuid();
  static const _files = MethodChannel('usra/files');

  static Future<PhotoStore> open(String folder) async =>
      PhotoStore(await getApplicationSupportDirectory(), folder);

  Directory get _dir => Directory(p.join(root.path, folder));

  /// The file for a path saved in the database.
  File fileOf(String relativePath) => File(p.join(root.path, relativePath));

  /// Copies a picked photo in and returns the path to save in the database.
  /// Throws, copying nothing, if the folder can't be kept out of backup.
  Future<String> import(String sourcePath) async {
    await _dir.create(recursive: true);
    if (Platform.isIOS) {
      // Cheap and idempotent, so done every time rather than trusting an
      // earlier call. Excluding the folder covers every file in it.
      await _files.invokeMethod<void>('excludeFromBackup', _dir.path);
    }
    final ext = p.extension(sourcePath).toLowerCase();
    final relative = p.join(
      folder,
      '${_uuid.v7()}${ext.isEmpty ? '.jpg' : ext}',
    );
    await File(sourcePath).copy(fileOf(relative).path);
    return relative;
  }

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

/// A stored photo, or a broken-image icon if the file can't be read.
class PhotoImage extends StatelessWidget {
  const PhotoImage({
    super.key,
    required this.file,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
    this.cacheWidth,
    this.semanticLabel,
  });

  final File file;
  final double? height;
  final double? width;
  final BoxFit fit;

  /// Decode at this width, so thumbnails don't hold full photos in memory.
  final int? cacheWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Image.file(
    file,
    height: height,
    width: width,
    fit: fit,
    cacheWidth: cacheWidth,
    semanticLabel: semanticLabel,
    errorBuilder: (_, _, _) => SizedBox(
      height: height ?? 120,
      width: width,
      child: const Center(child: Icon(Icons.broken_image_outlined, size: 40)),
    ),
  );
}
