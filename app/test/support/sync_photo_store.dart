import 'dart:io';

import 'package:usra/core/files/photo_store.dart';

/// Real file copies, but synchronous: async file I/O never finishes under
/// the fake clock of testWidgets.
class SyncPhotoStore extends PhotoStore {
  SyncPhotoStore(super.root, super.folder);

  var _n = 0;

  @override
  Future<String> import(String sourcePath) async {
    final relative = '$folder/${_n++}.jpg';
    fileOf(relative).parent.createSync(recursive: true);
    File(sourcePath).copySync(fileOf(relative).path);
    return relative;
  }

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
