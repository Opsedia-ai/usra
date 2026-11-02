import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Where insurance card photos live; provided in `main.dart`.
final cardPhotoStoreProvider = Provider<CardPhotoStore>(
  (ref) =>
      throw UnimplementedError('cardPhotoStoreProvider must be overridden'),
);

/// Keeps card photos in the app's private folder, next to the database.
///
/// Never in the photo gallery, and kept out of iCloud backup: the photos
/// are not encrypted like the database, so they must stay on this phone.
/// (Android backup is switched off for the whole app.)
class CardPhotoStore {
  CardPhotoStore(this.root);

  /// The app's private folder; photos go in [folder] inside it.
  final Directory root;

  static const folder = 'insurance_cards';
  static const _uuid = Uuid();
  static const _files = MethodChannel('usra/files');

  static Future<CardPhotoStore> open() async =>
      CardPhotoStore(await getApplicationSupportDirectory());

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

  /// Deletes every photo not in [keep] (replaced, or its card deleted).
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
