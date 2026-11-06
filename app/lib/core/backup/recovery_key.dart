import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../security/secure_storage_options.dart';

/// The key that opens backups: 6 groups of 6 digits, like
/// `482915 730264 ...`, written down on paper by the family.
///
/// Digits only, so it reads the same in Arabic and English and is typed on
/// a number pad. The last digit of each group is a check digit (Damm
/// algorithm, seeded with the group's position), so a mistyped digit, two
/// swapped digits or two swapped groups are caught before trying to open a
/// backup, and the app can say which group is wrong. That leaves 30 random
/// digits (about 100 bits), stretched further with Argon2id.
class RecoveryKey {
  RecoveryKey._(this.digits);

  static const groupCount = 6;
  static const groupLength = 6;

  /// The 36 digits, ASCII, without spaces.
  final String digits;

  factory RecoveryKey.generate([Random? random]) {
    final rng = random ?? Random.secure();
    final buffer = StringBuffer();
    for (var g = 0; g < groupCount; g++) {
      final body = [for (var i = 0; i < groupLength - 1; i++) rng.nextInt(10)];
      buffer
        ..writeAll(body)
        ..write(_damm([g + 1, ...body]));
    }
    return RecoveryKey._(buffer.toString());
  }

  /// The key typed by a person, with any spacing, dashes or Arabic digits;
  /// null unless every group is right.
  static RecoveryKey? tryParse(String input) {
    final digits = normalize(input);
    if (digits.length != groupCount * groupLength) return null;
    for (var g = 0; g < groupCount; g++) {
      final group = digits.substring(g * groupLength, (g + 1) * groupLength);
      if (!groupIsValid(g, group)) return null;
    }
    return RecoveryKey._(digits);
  }

  /// Positions (0-based) of the groups in [input] that are wrong or missing.
  static List<int> wrongGroups(String input) {
    final digits = normalize(input);
    return [
      for (var g = 0; g < groupCount; g++)
        if (digits.length < (g + 1) * groupLength ||
            !groupIsValid(
              g,
              digits.substring(g * groupLength, (g + 1) * groupLength),
            ))
          g,
    ];
  }

  /// Whether [group], typed as the group at [index], is well formed.
  static bool groupIsValid(int index, String group) {
    final digits = normalize(group);
    if (digits.length != groupLength) return false;
    return _damm([index + 1, ...digits.codeUnits.map((c) => c - 0x30)]) == 0;
  }

  /// Just the digits of [input], as ASCII (Arabic-Indic digits converted).
  static String normalize(String input) {
    final out = StringBuffer();
    for (final c in input.runes) {
      if (c >= 0x30 && c <= 0x39) {
        out.writeCharCode(c);
      } else if (c >= 0x0660 && c <= 0x0669) {
        out.writeCharCode(c - 0x0660 + 0x30);
      } else if (c >= 0x06F0 && c <= 0x06F9) {
        out.writeCharCode(c - 0x06F0 + 0x30);
      }
    }
    return out.toString();
  }

  List<String> get groups => [
    for (var g = 0; g < groupCount; g++)
      digits.substring(g * groupLength, (g + 1) * groupLength),
  ];

  /// What backups are encrypted with (after Argon2id).
  List<int> get secret => utf8.encode('usra-recovery-key:$digits');

  @override
  bool operator ==(Object other) =>
      other is RecoveryKey && other.digits == digits;

  @override
  int get hashCode => digits.hashCode;

  @override
  String toString() => 'RecoveryKey(******)';
}

/// The Damm check digit of [digits]: appending it makes the result 0.
int _damm(List<int> digits) {
  var interim = 0;
  for (final d in digits) {
    interim = _dammTable[interim][d];
  }
  return interim;
}

const _dammTable = [
  [0, 3, 1, 7, 5, 9, 8, 6, 4, 2],
  [7, 0, 9, 2, 1, 5, 4, 8, 6, 3],
  [4, 2, 0, 6, 8, 7, 1, 3, 5, 9],
  [1, 7, 5, 0, 9, 8, 3, 4, 2, 6],
  [6, 1, 2, 3, 0, 4, 5, 9, 7, 8],
  [3, 6, 7, 4, 2, 0, 9, 5, 8, 1],
  [5, 8, 6, 9, 7, 2, 0, 1, 3, 4],
  [8, 9, 4, 5, 3, 6, 2, 0, 1, 7],
  [9, 4, 3, 8, 6, 1, 7, 2, 0, 5],
  [2, 5, 8, 1, 4, 3, 6, 7, 9, 0],
];

/// Where the recovery key is kept on this phone, so later backups don't ask
/// for it again.
abstract class RecoveryKeyStore {
  Future<RecoveryKey?> read();
  Future<void> write(RecoveryKey key);
}

/// Kept only while the app runs; what tests use.
class MemoryRecoveryKeyStore implements RecoveryKeyStore {
  MemoryRecoveryKeyStore([this._key]);

  RecoveryKey? _key;

  @override
  Future<RecoveryKey?> read() async => _key;

  @override
  Future<void> write(RecoveryKey key) async => _key = key;
}

/// In Android Keystore / iOS Keychain, never copied to another device.
class SecureRecoveryKeyStore implements RecoveryKeyStore {
  SecureRecoveryKeyStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
            aOptions: secureStorageAndroidOptions,
          );

  static const _keyName = 'usra.backup.recovery_key.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<RecoveryKey?> read() async {
    final saved = await _storage.read(key: _keyName);
    return saved == null ? null : RecoveryKey.tryParse(saved);
  }

  @override
  Future<void> write(RecoveryKey key) =>
      _storage.write(key: _keyName, value: key.digits);
}
