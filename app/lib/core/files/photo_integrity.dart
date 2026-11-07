import '../database/app_database.dart';
import '../log.dart';
import 'photo_store.dart';

/// What [checkPhotoIntegrity] found. Counts only: never which photos, whose,
/// or where they are.
class PhotoIntegrity {
  const PhotoIntegrity({required this.missing, required this.unused});

  /// Photos a live row points at with no file on this phone.
  final int missing;

  /// Files no live row uses; the next prune in their folder deletes them.
  final int unused;
}

/// Compares what the live rows point at with the files on this phone. Only
/// reads: it never deletes or changes anything, whatever it finds. It looks
/// at whether files exist, not inside them, so it needs no photo key and
/// says nothing about what a file shows or whose it is.
///
/// Uses the sets `PhotoStore.prune` is given, folder by folder, so it sees
/// what a prune would see. `test/core/photo_safety_test.dart` checks it
/// agrees with what a backup finds missing.
Future<PhotoIntegrity> checkPhotoIntegrity(
  AppDatabase db, {
  required PhotoStore cards,
  required PhotoStore attachments,
  required PhotoStore medicines,
}) async {
  var missing = 0;
  var unused = 0;
  for (final (store, live) in [
    (cards, await db.liveInsurancePhotos()),
    (attachments, await db.liveAttachmentPaths()),
    (medicines, await db.liveMedicinePhotos()),
  ]) {
    final files = await store.storedPaths();
    missing += live.difference(files).length;
    unused += files.difference(live).length;
  }
  Log.photoCheck(missing: missing, unused: unused);
  return PhotoIntegrity(missing: missing, unused: unused);
}
