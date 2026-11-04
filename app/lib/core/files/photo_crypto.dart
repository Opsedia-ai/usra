import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A stored photo that can't be opened: changed, cut short, or sealed with
/// another phone's key.
class PhotoUnreadableException implements Exception {
  const PhotoUnreadableException(this.detail);

  final String detail;

  @override
  String toString() => 'PhotoUnreadableException($detail)';
}

/// Encrypts photos for this phone. Every photo file on disk is:
///
/// ```
/// "USRAPHO" 0x01      magic and format version
/// nonce (24 bytes)    random for each file
/// ciphertext          XChaCha20-Poly1305 of the photo's bytes
/// tag (16 bytes)
/// ```
///
/// The magic, version and nonce are authenticated too, so any change to the
/// file fails to open. The key is 256 random bits kept in [PhotoKeyStore];
/// it never leaves the phone (backups carry the photos decrypted, inside the
/// backup's own encryption, and a restore seals them again with the new
/// phone's key).
class PhotoCipher {
  PhotoCipher(List<int> key) : _key = SecretKeyData(List.unmodifiable(key)) {
    if (key.length != keyLength) {
      throw ArgumentError('Photo key must be $keyLength bytes');
    }
  }

  static const keyLength = 32;
  static const magic = [0x55, 0x53, 0x52, 0x41, 0x50, 0x48, 0x4F, 0x01];
  static const _nonceLength = 24;
  static const _tagLength = 16;
  static const headerLength = 8 + _nonceLength;
  // Synchronous, so it runs the same in an isolate and under a test's fake
  // clock.
  static const _aead = DartXchacha20.poly1305Aead();

  final SecretKeyData _key;

  /// The raw key, to hand to an isolate.
  List<int> get keyBytes => _key.bytes;

  /// True when [bytes] start like a sealed photo (they may still fail to
  /// open). Anything else is a photo from before encryption.
  static bool isSealed(List<int> bytes) {
    if (bytes.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return true;
  }

  Uint8List seal(List<int> photo, {Random? random}) {
    final rng = random ?? Random.secure();
    final header = Uint8List(headerLength)..setAll(0, magic);
    for (var i = magic.length; i < headerLength; i++) {
      header[i] = rng.nextInt(256);
    }
    final box = _aead.encryptSync(
      photo,
      secretKey: _key,
      nonce: header.sublist(magic.length),
      aad: header,
    );
    return (BytesBuilder(copy: false)
          ..add(header)
          ..add(box.cipherText)
          ..add(box.mac.bytes))
        .takeBytes();
  }

  /// The photo inside [sealed]. Throws [PhotoUnreadableException] if it
  /// isn't a sealed photo or doesn't open with this key.
  Uint8List open(List<int> sealed) {
    if (!isSealed(sealed)) {
      throw const PhotoUnreadableException('not a sealed photo');
    }
    if (sealed.length < headerLength + _tagLength) {
      throw const PhotoUnreadableException('cut short');
    }
    final header = sealed.sublist(0, headerLength);
    final box = SecretBox(
      sealed.sublist(headerLength, sealed.length - _tagLength),
      nonce: header.sublist(magic.length),
      mac: Mac(sealed.sublist(sealed.length - _tagLength)),
    );
    try {
      return Uint8List.fromList(
        _aead.decryptSync(box, secretKey: _key, aad: header),
      );
    } on SecretBoxAuthenticationError {
      throw const PhotoUnreadableException('changed, or another key');
    }
  }

  static Uint8List generateKey([Random? random]) {
    final rng = random ?? Random.secure();
    return Uint8List.fromList(
      List<int>.generate(keyLength, (_) => rng.nextInt(256)),
    );
  }
}

/// Keeps the photo key in Android Keystore / iOS Keychain, next to the
/// database key and stored the same way: this device only.
class PhotoKeyStore {
  PhotoKeyStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  static const _keyName = 'usra.photos.key.v1';
  final FlutterSecureStorage _storage;

  Future<PhotoCipher> readOrCreate() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null) return PhotoCipher(base64.decode(existing));
    final key = PhotoCipher.generateKey();
    await _storage.write(key: _keyName, value: base64.encode(key));
    return PhotoCipher(key);
  }
}
