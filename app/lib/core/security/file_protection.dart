import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../log.dart';

/// iOS Data Protection classes the app uses (security plan S9). Android
/// keeps app data in credential-encrypted storage, which is like
/// [untilFirstUnlock]; there is nothing to set there.
enum FileProtection {
  /// `NSFileProtectionComplete`: unreadable from about 10 seconds after
  /// the phone locks until it's unlocked again. For photos, which are only
  /// ever opened on screen.
  complete,

  /// `NSFileProtectionCompleteUntilFirstUserAuthentication`: readable once
  /// the phone was unlocked after it started. For the database and the
  /// small files next to it: a reminder's Taken or Snooze can run while the
  /// phone is locked (it writes the dose inbox file, and the database if
  /// the app is still running), and iOS can start the app in the
  /// background for it. A database that can't be opened at start-up shows
  /// the unavailable screen instead of the app.
  untilFirstUnlock,
}

const _files = MethodChannel('usra/files');

/// Sets [level] on [dir] (new files in it inherit it) and, with
/// [contents], on everything already inside it. Best effort and iOS only:
/// a phone that's locked right now refuses, and the next start tries again.
Future<void> protectFiles(
  Directory dir,
  FileProtection level, {
  bool contents = true,
  bool skipFolders = false,
}) async {
  if (!Platform.isIOS) return;
  try {
    if (!await dir.exists()) return;
    await _files.invokeMethod<void>('protect', {
      'path': dir.path,
      'level': level.name,
      'contents': contents,
      'skipFolders': skipFolders,
    });
  } catch (e) {
    Log.error('File protection failed', e);
  }
}

/// The classes for the app's private folder: [FileProtection.untilFirstUnlock]
/// for the folder and the database, then [FileProtection.complete] for each
/// photo folder (in that order, so the photos end up complete). Run at
/// start-up and after anything that moves files in (a restore).
Future<void> protectAppFiles(
  Directory root,
  Iterable<String> photoFolders,
) async {
  // The folder and the files directly in it; the photo folders below get
  // their own class and are never downgraded, even for a moment.
  await protectFiles(root, FileProtection.untilFirstUnlock, skipFolders: true);
  for (final folder in photoFolders) {
    await protectFiles(
      Directory(p.join(root.path, folder)),
      FileProtection.complete,
    );
  }
}
