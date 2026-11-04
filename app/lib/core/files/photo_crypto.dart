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

/// Why there is no photo key on this run.
enum PhotoKeyProblem {
  /// No key stored, but encrypted photos are: the key was lost (a Keystore
  /// reset, say). Those photos can't be opened; a backup brings them back.
  lost,

  /// A key is stored but isn't a valid key.
  corrupt,

  /// The key store couldn't be read (an error or no answer). The key may
  /// still be there, so it is never replaced; the next start tries again.
  unreadable,
}

/// Photos can't be opened or saved on this run: see [problem].
class PhotoKeyUnavailableException implements Exception {
  const PhotoKeyUnavailableException(this.problem);

  final PhotoKeyProblem problem;

  @override
  String toString() => 'PhotoKeyUnavailableException(${problem.name})';
}

/// The photo key for this run, shared by every photo folder: the cipher, or
/// the [problem] that left the app without one. A restore that brings a key
/// of its own back puts it here with [replace].
class PhotoKeys {
  PhotoKeys.ready(PhotoCipher this._cipher) : _problem = null;

  PhotoKeys.unavailable(PhotoKeyProblem this._problem) : _cipher = null;

  PhotoCipher? _cipher;
  PhotoKeyProblem? _problem;

  PhotoCipher? get cipher => _cipher;
  PhotoKeyProblem? get problem => _problem;

  /// The cipher, or throws [PhotoKeyUnavailableException].
  PhotoCipher get require =>
      _cipher ?? (throw PhotoKeyUnavailableException(_problem!));

  void replace(PhotoCipher cipher) {
    _cipher = cipher;
    _problem = null;
  }
}

/// Where the photo key is kept; [SecurePhotoKeyStore] in the app.
abstract class PhotoKeyStore {
  Future<String?> readRaw();
  Future<void> writeRaw(String value);

  /// Gives up on a key store that doesn't answer, so start-up never hangs.
  static const readTimeout = Duration(seconds: 10);

  /// The key, made on first use. A key is only ever made when no encrypted
  /// photo exists ([sealedPhotosExist]): otherwise a missing key means the
  /// old one was lost, and a new one would hide that for good.
  Future<PhotoKeys> load({
    required Future<bool> Function() sealedPhotosExist,
    Duration timeout = readTimeout,
  }) async {
    final String? stored;
    try {
      stored = await readRaw().timeout(timeout);
    } catch (_) {
      return PhotoKeys.unavailable(PhotoKeyProblem.unreadable);
    }
    if (stored != null) {
      try {
        return PhotoKeys.ready(PhotoCipher(base64.decode(stored)));
      } catch (_) {
        return PhotoKeys.unavailable(PhotoKeyProblem.corrupt);
      }
    }
    if (await sealedPhotosExist()) {
      return PhotoKeys.unavailable(PhotoKeyProblem.lost);
    }
    final cipher = PhotoCipher(PhotoCipher.generateKey());
    await save(cipher);
    return PhotoKeys.ready(cipher);
  }

  Future<void> save(PhotoCipher cipher) =>
      writeRaw(base64.encode(cipher.keyBytes));
}

/// Keeps the photo key in Android Keystore / iOS Keychain, next to the
/// database key and stored the same way: this device only.
class SecurePhotoKeyStore extends PhotoKeyStore {
  SecurePhotoKeyStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  static const _keyName = 'usra.photos.key.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readRaw() => _storage.read(key: _keyName);

  @override
  Future<void> writeRaw(String value) =>
      _storage.write(key: _keyName, value: value);
}

/// For tests.
class MemoryPhotoKeyStore extends PhotoKeyStore {
  MemoryPhotoKeyStore([this.value]);

  String? value;

  @override
  Future<String?> readRaw() async => value;

  @override
  Future<void> writeRaw(String value) async => this.value = value;
}
