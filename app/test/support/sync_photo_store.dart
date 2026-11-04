import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:usra/core/files/photo_store.dart';

/// Real encrypted files, but synchronous: async file I/O never finishes
/// under the fake clock of testWidgets.
class SyncPhotoStore extends PhotoStore {
  SyncPhotoStore(Directory root, String folder, [PhotoKeys? keys])
    : super(
        root,
        folder,
        keys ?? PhotoKeys.ready(PhotoCipher(PhotoCipher.generateKey())),
      );

  var _n = 0;

  @override
  Future<String> import(String sourcePath) async {
    final relative = '$folder/${_n++}.jpg';
    fileOf(relative).parent.createSync(recursive: true);
    fileOf(
      relative,
    ).writeAsBytesSync(keys.require.seal(File(sourcePath).readAsBytesSync()));
    return relative;
  }

  @override
  Future<Uint8List> read(String relativePath) async => readSync(relativePath);

  /// The photo decrypted.
  Uint8List readSync(String relativePath) =>
      keys.require.open(fileOf(relativePath).readAsBytesSync());

  @override
  Future<void> prune(Set<String> keep) async {
    final dir = Directory('${root.path}/$folder');
    if (!dir.existsSync()) return;
    for (final f in dir.listSync().whereType<File>()) {
      final relative = '$folder/${f.uri.pathSegments.last}';
      if (!keep.contains(relative)) f.deleteSync();
    }
  }
}

/// [SharedPhotoCache] with synchronous file I/O, for the same reason.
class SyncSharedPhotoCache extends SharedPhotoCache {
  SyncSharedPhotoCache(this.temporary) : super(temporary);

  final Directory temporary;

  Directory get dir =>
      Directory(p.join(temporary.path, SharedPhotoCache.folderName));

  @override
  Future<List<XFile>> copyOut(PhotoStore store, Iterable<String> paths) async {
    dir.createSync(recursive: true);
    return [
      for (final path in paths)
        if (store.fileOf(path).existsSync())
          XFile(
            (File(
              p.join(dir.path, p.basename(path)),
            )..writeAsBytesSync(await store.read(path))).path,
            mimeType: photoMimeOf(path),
          ),
    ];
  }

  @override
  Future<void> clearCopies() async {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  @override
  Future<void> clear() => clearCopies();
}
