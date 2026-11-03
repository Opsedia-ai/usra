import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'recovery_key.dart';

/// Why a backup couldn't be made or opened.
enum BackupFailure {
  /// Not a Usra backup file at all.
  notABackup,

  /// The recovery key doesn't open this backup.
  wrongKey,

  /// Cut short or changed after it was made (an incomplete download, say).
  damaged,

  /// Made by a newer version of the app; update the app first.
  tooNew,
}

class BackupException implements Exception {
  const BackupException(this.failure, [this.detail]);

  final BackupFailure failure;
  final String? detail;

  @override
  String toString() =>
      'BackupException(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// Argon2id cost for turning the recovery key into the file key. Saved in
/// each file, so it can be raised later without breaking old backups.
class BackupKdf {
  const BackupKdf({
    required this.memory,
    required this.iterations,
    required this.parallelism,
  });

  /// OWASP's recommended minimum for Argon2id: 19 MiB, 2 passes.
  static const standard = BackupKdf(
    memory: 19456,
    iterations: 2,
    parallelism: 1,
  );

  /// In KiB.
  final int memory;
  final int iterations;
  final int parallelism;

  /// Refuses costs that would freeze or crash the phone (a hostile file).
  bool get isReasonable =>
      parallelism >= 1 &&
      parallelism <= 8 &&
      memory >= 8 * parallelism &&
      memory <= 256 * 1024 &&
      iterations >= 1 &&
      iterations <= 10;
}

/// The encrypted backup file:
///
/// ```
/// "USRABAK" 0x01                  magic and format version
/// uint32 big-endian               header length
/// header (UTF-8 JSON)             KDF, salt, nonce prefix, chunk size, key check
/// chunk 0, chunk 1, ... chunk n   XChaCha20-Poly1305, each with a 16-byte tag
/// ```
///
/// The payload is cut into chunks so photos never need to fit in memory.
/// Each chunk's nonce is the file's random prefix, the chunk number and a
/// "last chunk" flag, and every chunk authenticates the whole header, so
/// reordering, dropping, truncating or appending chunks, or editing the
/// header, all fail to decrypt. The key check (a tag over nothing, with its
/// own nonce) tells a wrong recovery key apart from a damaged file.
abstract final class BackupFileFormat {
  static const magic = [0x55, 0x53, 0x52, 0x41, 0x42, 0x41, 0x4B, 0x01];
  static const defaultChunkSize = 1 << 20;
  static const _maxHeader = 4096;
  static const _saltLength = 16;
  static const _prefixLength = 16;
  static const _tagLength = 16;
  static final _aead = Xchacha20.poly1305Aead();

  static Future<SecretKey> _deriveKey(
    RecoveryKey key,
    List<int> salt,
    BackupKdf kdf,
  ) => Argon2id(
    parallelism: kdf.parallelism,
    memory: kdf.memory,
    iterations: kdf.iterations,
    hashLength: 32,
  ).deriveKey(secretKey: SecretKey(key.secret), nonce: salt);

  static List<int> _nonce(List<int> prefix, int counter, {required bool last}) {
    final n = Uint8List(24)..setAll(0, prefix);
    var c = counter;
    for (var i = 22; i >= 16; i--) {
      n[i] = c & 0xff;
      c >>= 8;
    }
    n[23] = last ? 1 : 0;
    return n;
  }

  // All 0xff: never a chunk nonce (the counter would need 2^56 chunks).
  static List<int> _checkNonce(List<int> prefix) => Uint8List(24)
    ..setAll(0, prefix)
    ..fillRange(16, 24, 0xff);
}

/// Writes an encrypted backup file, chunk by chunk.
class BackupFileWriter {
  BackupFileWriter._(
    this._out,
    this._key,
    this._prefix,
    this._aad,
    this._chunk,
  );

  final RandomAccessFile _out;
  final SecretKey _key;
  final List<int> _prefix;
  final List<int> _aad;
  final int _chunk;
  final _buffer = BytesBuilder(copy: false);
  var _counter = 0;

  static Future<BackupFileWriter> create(
    File file,
    RecoveryKey key, {
    BackupKdf kdf = BackupKdf.standard,
    int chunkSize = BackupFileFormat.defaultChunkSize,
    Random? random,
  }) async {
    final rng = random ?? Random.secure();
    List<int> bytes(int n) => List<int>.generate(n, (_) => rng.nextInt(256));
    final salt = bytes(BackupFileFormat._saltLength);
    final prefix = bytes(BackupFileFormat._prefixLength);
    final secret = await BackupFileFormat._deriveKey(key, salt, kdf);
    final check = await BackupFileFormat._aead.encrypt(
      const <int>[],
      secretKey: secret,
      nonce: BackupFileFormat._checkNonce(prefix),
      aad: BackupFileFormat.magic,
    );
    final header = utf8.encode(
      jsonEncode({
        'kdf': {
          'name': 'argon2id',
          'memory': kdf.memory,
          'iterations': kdf.iterations,
          'parallelism': kdf.parallelism,
          'salt': base64Encode(salt),
        },
        'cipher': 'xchacha20-poly1305',
        'chunkSize': chunkSize,
        'noncePrefix': base64Encode(prefix),
        'keyCheck': base64Encode(check.mac.bytes),
      }),
    );
    final length = ByteData(4)..setUint32(0, header.length);
    final aad = [
      ...BackupFileFormat.magic,
      ...length.buffer.asUint8List(),
      ...header,
    ];
    final out = await file.open(mode: FileMode.writeOnly);
    try {
      await out.writeFrom(aad);
    } catch (_) {
      await out.close();
      rethrow;
    }
    return BackupFileWriter._(out, secret, prefix, aad, chunkSize);
  }

  Future<void> add(List<int> data) async {
    _buffer.add(data);
    // Keep at least one byte back: the last chunk is written by close().
    while (_buffer.length > _chunk) {
      final all = _buffer.takeBytes();
      await _write(Uint8List.sublistView(all, 0, _chunk), last: false);
      _buffer.add(Uint8List.sublistView(all, _chunk));
    }
  }

  Future<void> close() async {
    try {
      await _write(_buffer.takeBytes(), last: true);
      await _out.flush();
    } finally {
      await _out.close();
    }
  }

  Future<void> _write(List<int> plain, {required bool last}) async {
    final box = await BackupFileFormat._aead.encrypt(
      plain,
      secretKey: _key,
      nonce: BackupFileFormat._nonce(_prefix, _counter++, last: last),
      aad: _aad,
    );
    await _out.writeFrom(box.cipherText);
    await _out.writeFrom(box.mac.bytes);
  }
}

/// Reads an encrypted backup file back, chunk by chunk, checking each.
class BackupFileReader {
  BackupFileReader._(
    this._in,
    this._length,
    this._key,
    this._prefix,
    this._aad,
    this._chunk,
  );

  final RandomAccessFile _in;
  final int _length;
  final SecretKey _key;
  final List<int> _prefix;
  final List<int> _aad;
  final int _chunk;
  var _counter = 0;
  var _done = false;

  /// Opens [file] and checks [key] against it. Throws [BackupException].
  static Future<BackupFileReader> open(File file, RecoveryKey key) async {
    final RandomAccessFile input;
    try {
      input = await file.open();
    } on FileSystemException {
      throw const BackupException(BackupFailure.notABackup, 'unreadable');
    }
    try {
      return await _open(input, key);
    } catch (_) {
      await input.close();
      rethrow;
    }
  }

  static Future<BackupFileReader> _open(
    RandomAccessFile input,
    RecoveryKey key,
  ) async {
    final length = await input.length();
    final start = await input.read(BackupFileFormat.magic.length + 4);
    if (start.length < BackupFileFormat.magic.length + 4) {
      throw const BackupException(BackupFailure.notABackup);
    }
    for (var i = 0; i < 7; i++) {
      if (start[i] != BackupFileFormat.magic[i]) {
        throw const BackupException(BackupFailure.notABackup);
      }
    }
    if (start[7] != BackupFileFormat.magic[7]) {
      throw const BackupException(BackupFailure.tooNew, 'file format');
    }
    final headerLength = ByteData.sublistView(start, 8).getUint32(0);
    if (headerLength > BackupFileFormat._maxHeader) {
      throw const BackupException(BackupFailure.damaged, 'header size');
    }
    final headerBytes = await input.read(headerLength);
    if (headerBytes.length != headerLength) {
      throw const BackupException(BackupFailure.damaged, 'short header');
    }
    final Map<String, dynamic> header;
    final BackupKdf kdf;
    final List<int> salt, prefix, check;
    final int chunk;
    try {
      header = jsonDecode(utf8.decode(headerBytes)) as Map<String, dynamic>;
      final k = header['kdf'] as Map<String, dynamic>;
      if (k['name'] != 'argon2id' || header['cipher'] != 'xchacha20-poly1305') {
        throw const BackupException(BackupFailure.tooNew, 'algorithm');
      }
      kdf = BackupKdf(
        memory: k['memory'] as int,
        iterations: k['iterations'] as int,
        parallelism: k['parallelism'] as int,
      );
      salt = base64Decode(k['salt'] as String);
      prefix = base64Decode(header['noncePrefix'] as String);
      check = base64Decode(header['keyCheck'] as String);
      chunk = header['chunkSize'] as int;
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException(BackupFailure.damaged, 'header');
    }
    if (!kdf.isReasonable ||
        salt.length < 8 ||
        prefix.length != BackupFileFormat._prefixLength ||
        check.length != BackupFileFormat._tagLength ||
        chunk < 1024 ||
        chunk > 16 << 20) {
      throw const BackupException(BackupFailure.damaged, 'header values');
    }
    final secret = await BackupFileFormat._deriveKey(key, salt, kdf);
    try {
      await BackupFileFormat._aead.decrypt(
        SecretBox(
          const [],
          nonce: BackupFileFormat._checkNonce(prefix),
          mac: Mac(check),
        ),
        secretKey: secret,
        aad: BackupFileFormat.magic,
      );
    } on SecretBoxAuthenticationError {
      throw const BackupException(BackupFailure.wrongKey);
    }
    return BackupFileReader._(input, length, secret, prefix, [
      ...start,
      ...headerBytes,
    ], chunk);
  }

  /// The next piece of the payload, or null after the last one. Throws
  /// [BackupException] ([BackupFailure.damaged]) if anything doesn't check.
  Future<Uint8List?> next() async {
    if (_done) return null;
    final position = await _in.position();
    final remaining = _length - position;
    final full = _chunk + BackupFileFormat._tagLength;
    // The writer's last chunk is always shorter than a full one.
    final last = remaining <= full;
    final size = last ? remaining : full;
    if (size < BackupFileFormat._tagLength) {
      throw const BackupException(BackupFailure.damaged, 'truncated');
    }
    final bytes = await _in.read(size);
    if (bytes.length != size) {
      throw const BackupException(BackupFailure.damaged, 'short read');
    }
    final cut = size - BackupFileFormat._tagLength;
    try {
      final plain = await BackupFileFormat._aead.decrypt(
        SecretBox(
          Uint8List.sublistView(bytes, 0, cut),
          nonce: BackupFileFormat._nonce(_prefix, _counter++, last: last),
          mac: Mac(Uint8List.sublistView(bytes, cut)),
        ),
        secretKey: _key,
        aad: _aad,
      );
      if (last) _done = true;
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw const BackupException(BackupFailure.damaged, 'chunk');
    }
  }

  Future<void> close() => _in.close();
}
