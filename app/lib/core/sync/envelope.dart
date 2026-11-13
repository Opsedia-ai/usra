/// The encrypted, signed record envelope of docs/sync-design.md section 12.
///
/// ```
/// header    = "USR1" 0x00 | u8 format = 1 | family_id (16) | sync_id (16) | u32 key_version
/// plaintext = sig (64) | u8 flags | u32 stored_length | stored_body | zero padding
/// sig       = Ed25519(dsig, "usra/v1/record-sig" || 0x00 || header || body)
/// stored    = nonce (24) | XChaCha20-Poly1305(RK_v, nonce, aad = header, plaintext)
/// ```
///
/// Flag bit 0 means `stored_body` is raw DEFLATE of the body (section 22,
/// rule 5). The signature is always over the uncompressed body. Plaintext is
/// padded to a power of two between 256 bytes and 64 KiB.
library;

import 'dart:convert';
import 'dart:io' show ZLibCodec, ZLibDecoder;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'canonical_json.dart';
import 'hlc.dart';
import 'merge.dart';

const recordFormat = 1;
const minPadded = 256;
const maxPadded = 65536;
const maxBody = 65536;

/// Bodies above this are deflated before padding (section 22, rule 5).
const compressAbove = 1024;

const _flagDeflate = 1;
const _sigLength = 64;
const _prefixLength = _sigLength + 1 + 4;

List<int> _label(String label) => [...utf8.encode(label), 0];

/// 16 bytes of a UUID string.
Uint8List uuidBytes(String uuid) {
  final hex = uuid.replaceAll('-', '');
  if (!RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(hex)) {
    throw FormatException('bad uuid', uuid);
  }
  final out = Uint8List(16);
  for (var i = 0; i < 16; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

/// The 42-byte header a reader rebuilds from its own context (family,
/// the row's sync id and key version), never parsed from the row.
Uint8List recordHeader({
  required String familyId,
  required String syncId,
  required int keyVersion,
}) {
  final b = BytesBuilder(copy: false)
    ..add(const [0x55, 0x53, 0x52, 0x31, 0x00, recordFormat]) // "USR1" 0 format
    ..add(uuidBytes(familyId))
    ..add(uuidBytes(syncId))
    ..add(_u32(keyVersion));
  return b.toBytes();
}

Uint8List _u32(int v) => Uint8List(4)..buffer.asByteData().setUint32(0, v);

/// `RK_v = HKDF-SHA256(FK_v, salt = family_id, info = "usra/v1/record-key" 0x00)`.
Future<SecretKey> deriveRecordKey(List<int> familyKey, String familyId) =>
    Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: SecretKey(familyKey),
      nonce: uuidBytes(familyId),
      info: _label('usra/v1/record-key'),
    );

/// A record's signed body.
final class RecordBody {
  RecordBody({
    required this.id,
    required this.type,
    required this.by,
    required this.logSeq,
    required this.logHash,
    required this.groups,
  });

  /// The local record id (UUID v7), only ever inside the ciphertext.
  final String id;

  /// The record type, for example `medicine`.
  final String type;

  /// The writing device's id.
  final String by;

  /// The writer's family log head.
  final int logSeq;
  final String logHash;

  final Groups groups;

  /// The largest group clock; the body's `hlc` must equal it (reader rule 4).
  Hlc get hlc =>
      groups.values.fold(Hlc.zero, (m, g) => g.clock > m ? g.clock : m);

  Map<String, Object?> toJson() => {
    'id': id,
    't': type,
    'by': by,
    'log': {'seq': logSeq, 'h': logHash},
    'hlc': hlc.toHex(),
    'g': {for (final e in groups.entries) e.key: e.value.toJson()},
  };

  static RecordBody fromJson(Object? json) {
    if (json is! Map<String, Object?> ||
        !_sameKeys(json, const {'id', 't', 'by', 'log', 'hlc', 'g'})) {
      throw const FormatException('bad record body');
    }
    final log = json['log'];
    final g = json['g'];
    if (json['id'] is! String ||
        json['t'] is! String ||
        json['by'] is! String ||
        json['hlc'] is! String ||
        log is! Map<String, Object?> ||
        !_sameKeys(log, const {'seq', 'h'}) ||
        log['seq'] is! int ||
        log['h'] is! String ||
        g is! Map<String, Object?> ||
        g.isEmpty) {
      throw const FormatException('bad record body');
    }
    final body = RecordBody(
      id: json['id']! as String,
      type: json['t']! as String,
      by: json['by']! as String,
      logSeq: log['seq']! as int,
      logHash: log['h']! as String,
      groups: {for (final e in g.entries) e.key: GroupEntry.fromJson(e.value)},
    );
    if (Hlc.parse(json['hlc']! as String) != body.hlc) {
      throw const FormatException('body clock is not its largest group clock');
    }
    return body;
  }
}

bool _sameKeys(Map<String, Object?> map, Set<String> keys) =>
    map.length == keys.length && map.keys.every(keys.contains);

/// Why a record was refused. Any of these makes the family show the
/// security warning (reader rules 1–2), except where the caller decides
/// otherwise.
final class EnvelopeException implements Exception {
  const EnvelopeException(this.reason);
  final String reason;
  @override
  String toString() => 'EnvelopeException: $reason';
}

/// Signs, compresses if worth it, pads and encrypts [body].
Future<Uint8List> sealRecord({
  required Uint8List header,
  required RecordBody body,
  required SecretKey recordKey,
  required SimpleKeyPair signingKey,
}) async {
  final bodyBytes = Uint8List.fromList(canonicalJsonBytes(body.toJson()));
  if (bodyBytes.length > maxBody) {
    throw const EnvelopeException('body over 64 KiB');
  }
  final signature = await Ed25519().sign([
    ..._label('usra/v1/record-sig'),
    ...header,
    ...bodyBytes,
  ], keyPair: signingKey);
  var flags = 0;
  List<int> stored = bodyBytes;
  if (bodyBytes.length > compressAbove) {
    final deflated = ZLibCodec(raw: true, level: 9).encode(bodyBytes);
    if (deflated.length < bodyBytes.length) {
      stored = deflated;
      flags = _flagDeflate;
    }
  }
  final used = _prefixLength + stored.length;
  final padded = _paddedSize(used);
  final plaintext = Uint8List(padded)
    ..setRange(0, _sigLength, signature.bytes)
    ..[_sigLength] = flags
    ..setRange(_sigLength + 1, _prefixLength, _u32(stored.length))
    ..setRange(_prefixLength, used, stored);
  final aead = Xchacha20.poly1305Aead();
  final box = await aead.encrypt(
    plaintext,
    secretKey: recordKey,
    nonce: aead.newNonce(),
    aad: header,
  );
  return Uint8List.fromList([
    ...box.nonce,
    ...box.cipherText,
    ...box.mac.bytes,
  ]);
}

int _paddedSize(int used) {
  var size = minPadded;
  while (size < used) {
    size <<= 1;
  }
  if (size > maxPadded) throw const EnvelopeException('record over 64 KiB');
  return size;
}

bool _isAllowedSize(int padded) =>
    padded >= minPadded && padded <= maxPadded && (padded & (padded - 1)) == 0;

/// Opens a stored record. [signerKey] returns the Ed25519 public key of a
/// device id as the reader's verified family log knows it, or null for an
/// unknown device. Checks reader rules 1, 2 and 4; rules 3, 5, 6 and 7 need
/// the family log and the caller applies them to the returned body.
Future<RecordBody> openRecord({
  required Uint8List header,
  required List<int> stored,
  required SecretKey recordKey,
  required Future<SimplePublicKey?> Function(String deviceId) signerKey,
}) async {
  if (stored.length < 40 || !_isAllowedSize(stored.length - 40)) {
    throw const EnvelopeException('bad size');
  }
  final aead = Xchacha20.poly1305Aead();
  final List<int> plaintext;
  try {
    plaintext = await aead.decrypt(
      SecretBox(
        stored.sublist(24, stored.length - 16),
        nonce: stored.sublist(0, 24),
        mac: Mac(stored.sublist(stored.length - 16)),
      ),
      secretKey: recordKey,
      aad: header,
    );
  } on SecretBoxAuthenticationError {
    throw const EnvelopeException('does not open');
  }
  final bytes = Uint8List.fromList(plaintext);
  final flags = bytes[_sigLength];
  if (flags & ~_flagDeflate != 0) {
    throw const EnvelopeException('unknown flags');
  }
  final storedLength = ByteData.sublistView(
    bytes,
    _sigLength + 1,
    _prefixLength,
  ).getUint32(0);
  if (storedLength > bytes.length - _prefixLength) {
    throw const EnvelopeException('bad length');
  }
  final end = _prefixLength + storedLength;
  for (var i = end; i < bytes.length; i++) {
    if (bytes[i] != 0) throw const EnvelopeException('bad padding');
  }
  final storedBody = bytes.sublist(_prefixLength, end);
  final bodyBytes = flags & _flagDeflate != 0
      ? _inflateCapped(storedBody)
      : storedBody;

  final RecordBody body;
  try {
    body = RecordBody.fromJson(parseCanonicalJson(bodyBytes));
  } on FormatException catch (e) {
    throw EnvelopeException('bad body: ${e.message}');
  }
  final key = await signerKey(body.by);
  if (key == null) throw const EnvelopeException('unknown signer');
  final sig = bytes.sublist(0, _sigLength);
  if (!isCanonicalEd25519S(sig)) throw const EnvelopeException('bad signature');
  final ok = await Ed25519().verify([
    ..._label('usra/v1/record-sig'),
    ...header,
    ...bodyBytes,
  ], signature: Signature(sig, publicKey: key));
  if (!ok) throw const EnvelopeException('bad signature');
  return body;
}

Uint8List _inflateCapped(List<int> data) {
  final out = BytesBuilder(copy: false);
  final sink = _CappedSink(out);
  final conversion = ZLibDecoder(raw: true).startChunkedConversion(sink);
  try {
    conversion
      ..add(data)
      ..close();
  } on EnvelopeException {
    rethrow;
  } on Object {
    throw const EnvelopeException('bad compressed body');
  }
  return out.toBytes();
}

final class _CappedSink implements Sink<List<int>> {
  _CappedSink(this._out);
  final BytesBuilder _out;

  @override
  void add(List<int> data) {
    if (_out.length + data.length > maxBody) {
      throw const EnvelopeException('body over 64 KiB');
    }
    _out.add(data);
  }

  @override
  void close() {}
}

// L = 2^252 + 27742317777372353535851937790883648493, little-endian.
final _ed25519L = BigInt.parse(
  '7237005577332262213973186563042994240857116359379907606001950938285454250989',
);

/// RFC 8032 strict check that S < L (no malleable second encoding). The rest
/// of the strict rules of section 5 (canonical, non-small-order A and R) are
/// left to the crypto review's choice of library (Q2).
bool isCanonicalEd25519S(List<int> signature) {
  if (signature.length != 64) return false;
  var s = BigInt.zero;
  for (var i = 63; i >= 32; i--) {
    s = (s << 8) | BigInt.from(signature[i]);
  }
  return s < _ed25519L;
}
