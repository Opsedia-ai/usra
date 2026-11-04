import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Turns the app-lock PIN into a salted Argon2id hash, and checks a PIN
/// against one. The PIN itself is never stored.
///
/// The cost is saved with each hash, so it can be raised later without
/// locking anyone out.
class PinHasher {
  /// OWASP's recommended minimum for Argon2id: 19 MiB, 2 passes (the same
  /// as backups).
  const PinHasher({
    this.memory = 19456,
    this.iterations = 2,
    this.parallelism = 1,
  });

  final int memory;
  final int iterations;
  final int parallelism;

  static const _saltLength = 16;
  static const _hashLength = 32;

  /// A new random salt and the PIN's hash, ready to save.
  Future<Map<String, Object>> hash(String pin) async {
    final random = Random.secure();
    final salt = [for (var i = 0; i < _saltLength; i++) random.nextInt(256)];
    final digest = await _derive(pin, salt, memory, iterations, parallelism);
    return {
      'kdf': 'argon2id',
      'memory': memory,
      'iterations': iterations,
      'parallelism': parallelism,
      'salt': base64Encode(salt),
      'hash': base64Encode(digest),
    };
  }

  /// Whether [pin] matches [saved], comparing in constant time. A damaged
  /// or unknown record never matches.
  Future<bool> verify(String pin, Map<String, Object?> saved) async {
    try {
      if (saved['kdf'] != 'argon2id') return false;
      final m = saved['memory'] as int;
      final t = saved['iterations'] as int;
      final p = saved['parallelism'] as int;
      // Refuse costs no phone could run, or so cheap they'd be guessable.
      if (p < 1 || p > 8 || m < 8 * p || m > 256 * 1024 || t < 1 || t > 10) {
        return false;
      }
      final salt = base64Decode(saved['salt'] as String);
      final expected = base64Decode(saved['hash'] as String);
      final actual = await _derive(pin, salt, m, t, p);
      return constantTimeEquals(actual, expected);
    } catch (_) {
      return false;
    }
  }

  /// Argon2 holds the CPU for most of a second; off the UI thread.
  static Future<List<int>> _derive(
    String pin,
    List<int> salt,
    int memory,
    int iterations,
    int parallelism,
  ) => Isolate.run(() async {
    final key = await Argon2id(
      parallelism: parallelism,
      memory: memory,
      iterations: iterations,
      hashLength: _hashLength,
    ).deriveKey(secretKey: SecretKey(utf8.encode(pin)), nonce: salt);
    return key.extractBytes();
  });
}

/// Compares every byte whatever the first difference, so the time taken
/// says nothing about how much of a guess was right.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
