import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'account_secure_storage.dart';

/// Each account's X25519 key pair on this phone and its device row.
///
/// Only the public key is ever sent: family keys for sync will be wrapped
/// to it, so the private key must never leave the phone. Keys are per
/// account, so two people signing in on one phone never share one.
abstract class DeviceIdentityStore {
  /// The account's public key, making its key pair on first use.
  Future<List<int>> publicKey(String userId);

  Future<String?> deviceId(String userId);

  Future<void> saveDeviceId(String userId, String deviceId);

  /// Wipes the account's key pair and device row id, on sign-out or after
  /// the account is deleted.
  Future<void> forget(String userId);
}

/// In iOS Keychain (this device only, never synced) / Android Keystore.
/// The app opts out of Android backups, so these never leave the phone.
class SecureDeviceIdentityStore implements DeviceIdentityStore {
  SecureDeviceIdentityStore([FlutterSecureStorage? storage])
    : _storage = storage ?? accountSecureStorage;

  static String _privateKeyName(String userId) =>
      '$accountKeyPrefix$userId.device_key.private.v1';
  static String _publicKeyName(String userId) =>
      '$accountKeyPrefix$userId.device_key.public.v1';
  static String _deviceIdName(String userId) =>
      '$accountKeyPrefix$userId.device_id';

  final FlutterSecureStorage _storage;

  // One operation at a time, so forget() can't race a key being made.
  Future<void> _last = Future.value();

  Future<T> _serial<T>(Future<T> Function() op) {
    final result = _last.then((_) => op());
    _last = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<List<int>> publicKey(String userId) => _serial(() async {
    final saved = await _storage.read(key: _publicKeyName(userId));
    final hasPrivate = await _storage.containsKey(key: _privateKeyName(userId));
    if (saved != null && hasPrivate) return base64Decode(saved);
    final pair = await X25519().newKeyPair();
    final private = await pair.extractPrivateKeyBytes();
    final public = (await pair.extractPublicKey()).bytes;
    await _storage.write(
      key: _privateKeyName(userId),
      value: base64Encode(private),
    );
    await _storage.write(
      key: _publicKeyName(userId),
      value: base64Encode(public),
    );
    return public;
  });

  @override
  Future<String?> deviceId(String userId) =>
      _serial(() => _storage.read(key: _deviceIdName(userId)));

  @override
  Future<void> saveDeviceId(String userId, String deviceId) => _serial(
    () => _storage.write(key: _deviceIdName(userId), value: deviceId),
  );

  @override
  Future<void> forget(String userId) => _serial(() async {
    await _storage.delete(key: _deviceIdName(userId));
    await _storage.delete(key: _privateKeyName(userId));
    await _storage.delete(key: _publicKeyName(userId));
  });
}

/// For tests: a fixed key per account that changes after [forget].
class MemoryDeviceIdentityStore implements DeviceIdentityStore {
  var _generation = 1;
  final keys = <String, List<int>>{};
  final devices = <String, String>{};

  @override
  Future<List<int>> publicKey(String userId) async =>
      keys[userId] ??= List.filled(32, _generation++);

  @override
  Future<String?> deviceId(String userId) async => devices[userId];

  @override
  Future<void> saveDeviceId(String userId, String deviceId) async =>
      devices[userId] = deviceId;

  @override
  Future<void> forget(String userId) async {
    devices.remove(userId);
    keys.remove(userId);
  }
}
