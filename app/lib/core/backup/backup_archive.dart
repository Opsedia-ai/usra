import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'backup_crypto.dart';

/// The inside of a backup: a plain POSIX (ustar) tar, so it can be read by
/// standard tools once decrypted. Only regular files with short relative
/// names are written or accepted.
class TarWriter {
  TarWriter(this._sink);

  final Future<void> Function(List<int> bytes) _sink;

  static const _block = 512;

  Future<void> addBytes(String name, List<int> bytes) async {
    await _sink(_header(name, bytes.length));
    await _sink(bytes);
    await _sink(Uint8List(_padding(bytes.length)));
  }

  Future<void> addFile(String name, File file) async {
    final size = await file.length();
    await _sink(_header(name, size));
    var written = 0;
    await for (final piece in file.openRead()) {
      await _sink(piece);
      written += piece.length;
    }
    if (written != size) {
      throw FileSystemException('File changed while backing up', file.path);
    }
    await _sink(Uint8List(_padding(size)));
  }

  /// The two empty blocks that end a tar.
  Future<void> finish() => _sink(Uint8List(_block * 2));

  static int _padding(int size) => (_block - size % _block) % _block;

  static Uint8List _header(String name, int size) {
    final nameBytes = utf8.encode(name);
    if (!isSafeEntryName(name) || nameBytes.length > 100) {
      throw ArgumentError.value(name, 'name', 'not a safe tar entry name');
    }
    final h = Uint8List(_block);
    void put(int offset, int length, String value) =>
        h.setRange(offset, offset + value.length, ascii.encode(value));
    void octal(int offset, int length, int value) => put(
      offset,
      length,
      '${value.toRadixString(8).padLeft(length - 1, '0')}\u0000',
    );
    h.setRange(0, nameBytes.length, nameBytes);
    octal(100, 8, 0x180); // 0600
    octal(108, 8, 0);
    octal(116, 8, 0);
    octal(124, 12, size);
    octal(136, 12, 0);
    h.fillRange(148, 156, 0x20); // checksum counts as spaces
    h[156] = 0x30; // regular file
    put(257, 6, 'ustar\u0000');
    put(263, 2, '00');
    final sum = h.fold<int>(0, (a, b) => a + b);
    put(148, 8, '${sum.toRadixString(8).padLeft(6, '0')}\u0000 ');
    return h;
  }
}

/// Relative, normalized, no `..`, no hidden or odd characters.
bool isSafeEntryName(String name) =>
    RegExp(
      r'^[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)*(/[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)*)?$',
    ).hasMatch(name) &&
    p.posix.normalize(name) == name;

/// Pulls exact byte counts out of the decrypted chunks.
class _Source {
  _Source(this._reader);

  final BackupFileReader _reader;
  Uint8List _buffer = Uint8List(0);
  var _offset = 0;

  int get _available => _buffer.length - _offset;

  /// Up to [max] bytes (at least one), or an empty list at the end.
  Future<Uint8List> some(int max) async {
    while (_available == 0) {
      final next = await _reader.next();
      if (next == null) return Uint8List(0);
      _buffer = next;
      _offset = 0;
    }
    final n = _available < max ? _available : max;
    final out = Uint8List.sublistView(_buffer, _offset, _offset + n);
    _offset += n;
    return out;
  }

  Future<Uint8List> exactly(int n) async {
    final out = BytesBuilder(copy: true);
    while (out.length < n) {
      final piece = await some(n - out.length);
      if (piece.isEmpty) {
        throw const BackupException(BackupFailure.damaged, 'tar cut short');
      }
      out.add(piece);
    }
    return out.takeBytes();
  }

  /// True when nothing at all is left after the tar's end.
  Future<bool> atEnd() async => (await some(1)).isEmpty;
}

/// Unpacks the tar inside [reader] into [into]. [accept] says, for each
/// entry name, whether to keep it; others are skipped. [transform] may give,
/// for an entry, a function its whole content goes through in memory
/// before it is written (photos are encrypted for this phone), or that
/// returns null to leave the entry out; such entries are limited to
/// [maxTransformedSize]. Returns the names written. Throws
/// [BackupException] on anything malformed.
Future<List<String>> extractTar(
  BackupFileReader reader,
  Directory into, {
  required bool Function(String name) accept,
  List<int>? Function(Uint8List content)? Function(String name)? transform,
}) async {
  final source = _Source(reader);
  final written = <String>[];
  while (true) {
    final header = await source.exactly(512);
    if (header.every((b) => b == 0)) {
      final second = await source.exactly(512);
      if (!second.every((b) => b == 0) || !await source.atEnd()) {
        throw const BackupException(BackupFailure.damaged, 'after tar end');
      }
      return written;
    }
    final (name, size) = _parseHeader(header);
    final padded = size + TarWriter._padding(size);
    if (!accept(name)) {
      var left = padded;
      while (left > 0) {
        final piece = await source.some(left);
        if (piece.isEmpty) {
          throw const BackupException(BackupFailure.damaged, 'tar cut short');
        }
        left -= piece.length;
      }
      continue;
    }
    final file = File(p.joinAll([into.path, ...name.split('/')]));
    await file.parent.create(recursive: true);
    final convert = transform?.call(name);
    if (convert != null) {
      if (size > maxTransformedSize) {
        throw const BackupException(BackupFailure.damaged, 'entry too big');
      }
      final converted = convert(await source.exactly(size));
      await source.exactly(padded - size);
      if (converted == null) continue;
      await file.writeAsBytes(converted);
      written.add(name);
      continue;
    }
    final sink = file.openWrite();
    try {
      var left = size;
      while (left > 0) {
        final piece = await source.some(left);
        if (piece.isEmpty) {
          throw const BackupException(BackupFailure.damaged, 'tar cut short');
        }
        sink.add(piece);
        left -= piece.length;
      }
    } finally {
      await sink.close();
    }
    await source.exactly(padded - size);
    written.add(name);
  }
}

/// The largest entry [extractTar] holds in memory to transform: far more
/// than any photo the app saves.
const maxTransformedSize = 64 << 20;

(String, int) _parseHeader(Uint8List h) {
  String field(int offset, int length) {
    var end = offset;
    while (end < offset + length && h[end] != 0) {
      end++;
    }
    return ascii.decode(h.sublist(offset, end), allowInvalid: true).trim();
  }

  final stored = int.tryParse(field(148, 8), radix: 8);
  var sum = 0;
  for (var i = 0; i < 512; i++) {
    sum += (i >= 148 && i < 156) ? 0x20 : h[i];
  }
  if (stored != sum) {
    throw const BackupException(BackupFailure.damaged, 'tar checksum');
  }
  if (h[156] != 0x30 && h[156] != 0) {
    throw const BackupException(BackupFailure.damaged, 'tar entry type');
  }
  final size = int.tryParse(field(124, 12), radix: 8);
  var nameEnd = 0;
  while (nameEnd < 100 && h[nameEnd] != 0) {
    nameEnd++;
  }
  final String name;
  try {
    name = utf8.decode(h.sublist(0, nameEnd));
  } on FormatException {
    throw const BackupException(BackupFailure.damaged, 'tar name');
  }
  if (size == null || size < 0 || !isSafeEntryName(name)) {
    throw const BackupException(BackupFailure.damaged, 'tar entry');
  }
  return (name, size);
}
