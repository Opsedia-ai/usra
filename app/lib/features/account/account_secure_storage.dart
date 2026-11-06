import 'dart:io' show Platform;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/preferences.dart';
import '../../core/security/secure_storage_options.dart';

/// Where account secrets live: iOS Keychain (this device only, never
/// synced) / Android Keystore. Every key starts with [accountKeyPrefix].
const accountSecureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
  ),
  aOptions: secureStorageAndroidOptions,
);

/// All account keys (session, auth items, device keys and ids). The
/// database key (`usra.db.`) and the recovery key (`usra.backup.`) are
/// outside it.
const accountKeyPrefix = 'usra.account.';

/// Set in shared preferences once this install has checked for leftovers.
const accountInstalledPref = PrefKeys.accountInstalled;

/// iOS keeps Keychain items after the app is deleted, but not shared
/// preferences. On the first run of an install, wipe any account secrets
/// a previous install left, so a reinstalled app never comes back signed
/// in or with an old private key.
///
/// iOS only. Android deletes its secure storage with the app, and `readAll`
/// there decrypts every key in the app, the database key included, so account
/// code must never depend on it.
Future<void> wipeAccountSecretsAfterReinstall(
  KeyValueStore prefs, {
  FlutterSecureStorage storage = accountSecureStorage,
  bool? isIos,
}) async {
  if (prefs.getBool(accountInstalledPref) ?? false) return;
  if (isIos ?? Platform.isIOS) {
    final all = await storage.readAll();
    final left = [...all.keys.where((k) => k.startsWith(accountKeyPrefix))];
    for (final key in left) {
      await storage.delete(key: key);
    }
  }
  await prefs.setBool(accountInstalledPref, true);
}
