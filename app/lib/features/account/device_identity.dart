import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// This phone's X25519 key pair and its device row per account.
///
/// Only the public key is ever sent: family keys for sync will be wrapped
/// to it, so the private key must never leave the phone.
abstract class DeviceIdentityStore {
  /// The public key, making the key pair on first use.
  Future<List<int>> publicKey();

  Future<String?> deviceId(String userId);

  Future<void> saveDeviceId(String userId, String deviceId);

  /// Drops the device row id for [userId] and the key pair, after the
  /// account is deleted.
  Future<void> forget(String userId);
}

/// In Android Keystore / iOS Keychain, never copied to another device.
class SecureDeviceIdentityStore implements DeviceIdentityStore {
  SecureDeviceIdentityStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  static const _privateKeyName = 'usra.account.device_key.private.v1';
  static const _publicKeyName = 'usra.account.device_key.public.v1';
  static String _deviceIdName(String userId) => 'usra.account.device.$userId';

  final FlutterSecureStorage _storage;
  Future<List<int>>? _publicKey;

  @override
  Future<List<int>> publicKey() =>
      _publicKey ??= _readOrCreate().catchError((Object e) {
        _publicKey = null;
        throw e;
      });

  Future<List<int>> _readOrCreate() async {
    final saved = await _storage.read(key: _publicKeyName);
    final hasPrivate = await _storage.containsKey(key: _privateKeyName);
    if (saved != null && hasPrivate) return base64Decode(saved);
    final pair = await X25519().newKeyPair();
    final private = await pair.extractPrivateKeyBytes();
    final public = (await pair.extractPublicKey()).bytes;
    await _storage.write(key: _privateKeyName, value: base64Encode(private));
    await _storage.write(key: _publicKeyName, value: base64Encode(public));
    return public;
  }

  @override
  Future<String?> deviceId(String userId) =>
      _storage.read(key: _deviceIdName(userId));

  @override
  Future<void> saveDeviceId(String userId, String deviceId) =>
      _storage.write(key: _deviceIdName(userId), value: deviceId);

  @override
  Future<void> forget(String userId) async {
    _publicKey = null;
    await _storage.delete(key: _deviceIdName(userId));
    await _storage.delete(key: _privateKeyName);
    await _storage.delete(key: _publicKeyName);
  }
}

/// For tests: a fixed key that changes after [forget].
class MemoryDeviceIdentityStore implements DeviceIdentityStore {
  var _generation = 1;
  bool _made = false;
  final devices = <String, String>{};

  bool get hasKey => _made;

  @override
  Future<List<int>> publicKey() async {
    _made = true;
    return List.filled(32, _generation);
  }

  @override
  Future<String?> deviceId(String userId) async => devices[userId];

  @override
  Future<void> saveDeviceId(String userId, String deviceId) async =>
      devices[userId] = deviceId;

  @override
  Future<void> forget(String userId) async {
    devices.remove(userId);
    _made = false;
    _generation++;
  }
}
