import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

import '../log.dart';

/// Every Keystore / Keychain item the app writes. The account's items
/// (`usra.account.`) are found by prefix. Kept here so "Delete all my
/// data" can't miss one; `test/core/data_wipe_test.dart` checks it against
/// the code.
const appSecureKeys = [
  'usra.db.key.v1',
  'usra.photos.key.v1',
  'usra.backup.recovery_key.v1',
  'usra.app_lock.v1',
];

const appSecureKeyPrefix = 'usra.';

/// Deletes everything Usra keeps on this phone (security plan S10), for
/// "Delete all my data" and, when turned on, too many wrong PINs.
///
/// Keys go first: without them the database, photos and any leftover
/// file are unreadable, so even a wipe cut short has done the part that
/// matters. A marker file is written before anything is deleted and
/// removed only once every step worked; if the app is killed half way (or
/// a step fails), the next start runs the wipe again before opening
/// anything ([resumeIfInterrupted]), at most [maxAttempts] times.
///
/// Backup files the family saved elsewhere (Drive, WhatsApp) are not on
/// the phone's private storage and can't be reached; they still open with
/// the recovery key, which is the point of them.
class DataWiper {
  DataWiper({
    required this.root,
    required this.temporary,
    required this.secureStorage,
    required this.clearPreferences,
    this.cancelNotifications,
    this.clearWidget,
  });

  /// The app's private folder: database, photos, small files.
  final Directory root;

  /// The app's cache folder: backups made for sharing, decrypted share
  /// copies (ours and share_plus's).
  final Directory temporary;

  /// One per set of options the app uses (iOS Keychain items are looked up
  /// by their accessibility too).
  final List<FlutterSecureStorage> secureStorage;
  final Future<void> Function() clearPreferences;
  final Future<void> Function()? cancelNotifications;
  final Future<void> Function()? clearWidget;

  static const markerName = 'wipe-in-progress.json';
  static const maxAttempts = 3;

  File get _marker => File(p.join(root.path, markerName));

  /// A wipe was started and didn't finish.
  Future<bool> get interrupted => _marker.exists();

  /// At start-up, before any key is read: finishes a wipe that didn't.
  /// True when one ran.
  Future<bool> resumeIfInterrupted() async {
    if (!await interrupted) return false;
    await wipe();
    return true;
  }

  /// Deletes it all. True when every step worked. If keys or files
  /// couldn't be deleted the marker stays and the next start tries again.
  Future<bool> wipe() async {
    final attempt = await _readAttempt() + 1;
    await root.create(recursive: true);
    await _marker.writeAsString(jsonEncode({'attempt': attempt}), flush: true);
    var ok = true;
    // Only keys and files are worth running the whole wipe again for at the
    // next start: a reminder or the widget that can't be reached must not
    // erase records added since, start after start.
    var mustRetry = false;
    // Each step runs whatever the one before did; [report] logs a fixed
    // event (S5: never the error's text).
    Future<void> step(
      Future<void> Function()? run,
      void Function(Object e) report, {
      bool critical = false,
    }) async {
      if (run == null) return;
      try {
        await run();
      } catch (e) {
        ok = false;
        if (critical) mustRetry = true;
        report(e);
      }
    }

    await step(
      _deleteKeys,
      (e) => Log.error('Wipe keys failed', e),
      critical: true,
    );
    await step(
      cancelNotifications,
      (e) => Log.error('Wipe notifications failed', e),
    );
    await step(clearWidget, (e) => Log.error('Wipe widget failed', e));
    await step(
      () => _emptyFolder(root, keep: _marker),
      (e) => Log.error('Wipe files failed', e),
      critical: true,
    );
    await step(
      () => _emptyFolder(temporary),
      (e) => Log.error('Wipe cache failed', e),
      critical: true,
    );
    await step(clearPreferences, (e) => Log.error('Wipe settings failed', e));
    if (!mustRetry || attempt >= maxAttempts) {
      // Given up after a few tries: never wipe again on every start, over
      // records the family has added since.
      await _marker.delete();
    }
    return ok;
  }

  Future<int> _readAttempt() async {
    try {
      final json = jsonDecode(await _marker.readAsString());
      return (json as Map)['attempt'] as int;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _deleteKeys() async {
    Object? failure;
    for (final storage in secureStorage) {
      try {
        for (final key in appSecureKeys) {
          await storage.delete(key: key);
        }
        final all = await storage.readAll();
        for (final key in [...all.keys]) {
          if (key.startsWith(appSecureKeyPrefix)) {
            await storage.delete(key: key);
          }
        }
      } catch (e) {
        failure = e;
      }
    }
    if (failure != null) throw failure;
  }

  static Future<void> _emptyFolder(Directory dir, {File? keep}) async {
    if (!await dir.exists()) return;
    Object? failure;
    await for (final entity in dir.list(followLinks: false)) {
      if (keep != null && p.equals(entity.path, keep.path)) continue;
      try {
        await entity.delete(recursive: true);
      } catch (e) {
        failure = e;
      }
    }
    if (failure != null) throw failure;
  }
}

/// How "Delete all my data" ended. `main.dart` passes it to the fresh app.
enum WipeOutcome { done, incomplete }

final wipeOutcomeProvider = Provider<WipeOutcome?>((ref) => null);

/// Signs out, deletes everything and starts the app again as on first
/// run. Provided in `main.dart`, which owns the database.
final wipeAndRestartProvider = Provider<Future<void> Function()>(
  (ref) =>
      throw UnimplementedError('wipeAndRestartProvider must be overridden'),
);
