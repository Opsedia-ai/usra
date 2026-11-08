import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Android options for every `FlutterSecureStorage` in the app.
///
/// With the plugin's default (`resetOnError: true`), a Keystore or decrypt error
/// deletes data: a failed `read` deletes that key, a failed `readAll` deletes
/// every key, and a key mismatch on start deletes them all. For the database key
/// that loses every record. So errors must surface and leave the keys alone.
///
/// Use this everywhere, not only on the keys that matter: the plugin keeps one
/// storage per preferences name and prefix, and whichever call comes first in
/// the process sets the options for all of them.
const secureStorageAndroidOptions = AndroidOptions(resetOnError: false);
