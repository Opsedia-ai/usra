import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../preferences.dart';
import 'pin_hasher.dart';

/// Where the app lock's settings and PIN hash are kept.
abstract class LockStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

/// Keystore / Keychain, this device only: never in a backup or on another
/// phone.
class SecureLockStore implements LockStore {
  SecureLockStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  static const _keyName = 'usra.app_lock.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _keyName);

  @override
  Future<void> write(String value) =>
      _storage.write(key: _keyName, value: value);

  @override
  Future<void> delete() => _storage.delete(key: _keyName);
}

/// Kept only while the app runs; what tests use.
class MemoryLockStore implements LockStore {
  MemoryLockStore([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;

  @override
  Future<void> delete() async => value = null;
}

/// The phone's fingerprint or face unlock.
abstract class BiometricUnlock {
  /// Whether the phone has biometrics set up that the app may use.
  Future<bool> available();

  /// Shows the system prompt; true only when the person passed it.
  Future<bool> authenticate(String reason);
}

/// local_auth, biometrics only: the phone's own PIN isn't accepted, since
/// family members nearby often know it.
class LocalAuthBiometrics implements BiometricUnlock {
  LocalAuthBiometrics([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> available() async {
    try {
      if (!await _auth.canCheckBiometrics) return false;
      final types = await _auth.getAvailableBiometrics();
      // Android only: weak (Class 2) sensors, such as camera face unlock on
      // budget phones, can be fooled by a photo. Offered only with a strong
      // one. (The system prompt itself can't be limited to strong.)
      return Platform.isAndroid
          ? types.contains(BiometricType.strong)
          : types.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      // Cancelled, locked out or not enrolled: the PIN pad is still there.
      return false;
    }
  }
}

/// For tests and phones without biometrics.
class NoBiometrics implements BiometricUnlock {
  const NoBiometrics();

  @override
  Future<bool> available() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;
}

/// How long the app may stay in the background before it locks again.
enum LockTimeout {
  immediately(Duration.zero),
  oneMinute(Duration(minutes: 1)),
  fiveMinutes(Duration(minutes: 5));

  const LockTimeout(this.duration);

  final Duration duration;
}

/// The result of typing a PIN.
enum PinCheck { ok, wrong, blocked }

/// Shortest and longest PIN.
const minPinLength = 4;
const maxPinLength = 6;

/// Wrong PINs allowed before the app makes the person wait.
const freeAttempts = 5;

/// The wait after [failures] wrong PINs in a row: none for the first
/// [freeAttempts], then 30 s, doubling each time, at most an hour.
Duration lockoutAfter(int failures) {
  if (failures < freeAttempts) return Duration.zero;
  final steps = min(failures - freeAttempts, 7);
  return Duration(seconds: min(30 * (1 << steps), 3600));
}

/// The optional app lock: a PIN, with fingerprint or face as a shortcut.
///
/// Lives outside the provider container, so a backup restore (which builds
/// a new container) neither re-locks nor forgets a held deep link.
class AppLock extends ChangeNotifier {
  AppLock._({
    required this._store,
    required this._hasher,
    required this.biometrics,
    required this._clock,
    _LockConfig? config,
  }) : _config = config,
       _locked = config != null;

  /// Reads the saved lock. Starts locked whenever a PIN is set.
  ///
  /// [freshInstall] drops a lock left in the iOS Keychain by an earlier
  /// install of the app, whose data is already gone.
  static Future<AppLock> open({
    required LockStore store,
    BiometricUnlock biometrics = const NoBiometrics(),
    PinHasher hasher = const PinHasher(),
    DateTime Function() clock = DateTime.now,
    bool freshInstall = false,
  }) async {
    if (freshInstall) await store.delete();
    _LockConfig? config;
    try {
      final raw = await store.read();
      if (raw != null) config = _LockConfig.fromJson(raw);
    } catch (_) {
      // Unreadable is not the same as off: fail closed with a lock nobody
      // can open, and say how to reset (wipe or restore a backup).
      config = _LockConfig.unreadable();
    }
    return AppLock._(
      store: store,
      hasher: hasher,
      biometrics: biometrics,
      clock: clock,
      config: config,
    );
  }

  /// Off and unlocked, kept in memory: the default in tests.
  factory AppLock.off({
    LockStore? store,
    PinHasher hasher = const PinHasher(),
    BiometricUnlock biometrics = const NoBiometrics(),
    DateTime Function() clock = DateTime.now,
  }) => AppLock._(
    store: store ?? MemoryLockStore(),
    hasher: hasher,
    biometrics: biometrics,
    clock: clock,
  );

  final LockStore _store;
  final PinHasher _hasher;
  final BiometricUnlock biometrics;
  final DateTime Function() _clock;
  _LockConfig? _config;
  bool _locked;
  DateTime? _backgroundAt;
  VoidCallback? _pending;

  bool get enabled => _config != null;
  bool get locked => _locked;
  bool get biometricsEnabled => _config?.biometrics ?? false;
  LockTimeout get timeout => _config?.timeout ?? LockTimeout.oneMinute;

  /// First responders may open the emergency card without the PIN. Off
  /// unless the person turns it on.
  bool get emergencyOnLockScreen => _config?.emergency ?? false;

  /// Wrong PINs in a row.
  int get failures => _config?.failures ?? 0;

  /// How long until the next PIN may be tried; zero when it may be now.
  Duration get waitRemaining {
    final until = _config?.blockedUntil;
    if (until == null) return Duration.zero;
    final left = until.difference(_clock());
    return left.isNegative ? Duration.zero : left;
  }

  /// Turns the lock on with [pin]; the caller has already had it typed
  /// twice.
  Future<void> enable(String pin, {bool biometrics = false}) async {
    _config = _LockConfig(
      pin: await _hasher.hash(pin),
      biometrics: biometrics,
      timeout: _config?.timeout ?? LockTimeout.oneMinute,
      emergency: _config?.emergency ?? false,
    );
    _locked = false;
    await _save();
  }

  /// A new PIN. The caller checks the current one first.
  Future<void> changePin(String pin) async {
    final c = _config;
    if (c == null) return enable(pin);
    _config = c.copyWith(
      pin: await _hasher.hash(pin),
      failures: 0,
      blockedUntil: null,
      blockedAt: null,
    );
    await _save();
  }

  /// Turns the lock off and forgets the PIN. The caller checks it first.
  Future<void> disable() async {
    _config = null;
    _locked = false;
    _backgroundAt = null;
    await _store.delete();
    notifyListeners();
  }

  Future<void> setBiometrics(bool on) =>
      _update((c) => c.copyWith(biometrics: on));

  Future<void> setTimeout(LockTimeout timeout) =>
      _update((c) => c.copyWith(timeout: timeout));

  Future<void> setEmergencyOnLockScreen(bool on) =>
      _update((c) => c.copyWith(emergency: on));

  /// Checks [pin]; on success the app unlocks and the wrong-PIN count
  /// starts again.
  Future<PinCheck> checkPin(String pin) async {
    var c = _config;
    if (c == null) return PinCheck.ok;
    final before = c;
    c = _clockMovedBack(c);
    if (!identical(c, before)) await _save();
    if (waitRemaining > Duration.zero) return PinCheck.blocked;
    // Counted before the slow check and saved, so closing the app in the
    // middle of it isn't a free guess.
    final now = _clock();
    final failures = c.failures + 1;
    final wait = lockoutAfter(failures);
    _config = c.copyWith(
      failures: failures,
      blockedAt: wait == Duration.zero ? null : now,
      blockedUntil: wait == Duration.zero ? null : now.add(wait),
    );
    await _save();
    if (!await _hasher.verify(pin, c.pin)) {
      notifyListeners();
      return PinCheck.wrong;
    }
    await _passed();
    return PinCheck.ok;
  }

  /// Fingerprint or face, when turned on. True when it unlocked.
  Future<bool> checkBiometrics(String reason) async {
    if (!biometricsEnabled) return false;
    if (!await authenticate(reason)) return false;
    await _passed();
    return true;
  }

  bool _prompting = false;

  /// The system biometric prompt. Some phones pause the app while it's up;
  /// that isn't leaving the app, so it doesn't start the lock timeout.
  Future<bool> authenticate(String reason) async {
    _prompting = true;
    try {
      return await biometrics.authenticate(reason);
    } finally {
      _prompting = false;
      _backgroundAt = null;
    }
  }

  Future<void> _passed() async {
    final c = _config;
    if (c != null && (c.failures != 0 || c.blockedUntil != null)) {
      _config = c.copyWith(failures: 0, blockedUntil: null, blockedAt: null);
      await _save();
    }
    _unlock();
  }

  void _unlock() {
    if (!_locked) return;
    _locked = false;
    notifyListeners();
    final pending = _pending;
    _pending = null;
    pending?.call();
  }

  /// Locks now (used on cold start and after the background timeout).
  void lock() {
    if (!enabled || _locked) return;
    _locked = true;
    notifyListeners();
  }

  /// Runs [action] now when unlocked, or right after the next unlock. Only
  /// the latest is kept: it's where the person last asked to go.
  void runWhenUnlocked(VoidCallback action) {
    if (_locked) {
      _pending = action;
    } else {
      action();
    }
  }

  /// The app left the screen.
  void movedToBackground() {
    if (_locked || _prompting) return;
    _backgroundAt ??= _clock();
  }

  /// The app is back; locks when it was away for at least [timeout].
  void movedToForeground() {
    final left = _backgroundAt;
    _backgroundAt = null;
    if (left == null || !enabled) return;
    if (_clock().difference(left) >= timeout.duration ||
        _clock().isBefore(left)) {
      lock();
    }
  }

  /// A block set "in the future" means the clock was turned back: start
  /// the wait again from now rather than let it run for days.
  _LockConfig _clockMovedBack(_LockConfig c) {
    final at = c.blockedAt;
    final now = _clock();
    if (at == null || !now.isBefore(at)) return c;
    return _config = c.copyWith(
      blockedAt: now,
      blockedUntil: now.add(c.blockedUntil!.difference(at)),
    );
  }

  Future<void> _update(_LockConfig Function(_LockConfig) change) async {
    final c = _config;
    if (c == null) return;
    _config = change(c);
    await _save();
  }

  Future<void> _save() async {
    final c = _config;
    if (c != null) await _store.write(c.toJson());
    notifyListeners();
  }
}

/// Saved as one JSON value in secure storage.
class _LockConfig {
  const _LockConfig({
    required this.pin,
    this.biometrics = false,
    this.timeout = LockTimeout.oneMinute,
    this.emergency = false,
    this.failures = 0,
    this.blockedAt,
    this.blockedUntil,
  });

  /// A lock no PIN opens.
  factory _LockConfig.unreadable() => const _LockConfig(pin: {});

  factory _LockConfig.fromJson(String raw) {
    final j = jsonDecode(raw) as Map<String, Object?>;
    DateTime? time(String key) => switch (j[key]) {
      final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
      _ => null,
    };
    return _LockConfig(
      pin: (j['pin'] as Map).cast<String, Object?>(),
      biometrics: j['biometrics'] == true,
      timeout: LockTimeout.values.firstWhere(
        (t) => t.name == j['timeout'],
        orElse: () => LockTimeout.oneMinute,
      ),
      emergency: j['emergency'] == true,
      failures: j['failures'] as int? ?? 0,
      blockedAt: time('blockedAt'),
      blockedUntil: time('blockedUntil'),
    );
  }

  final Map<String, Object?> pin;
  final bool biometrics;
  final LockTimeout timeout;
  final bool emergency;
  final int failures;
  final DateTime? blockedAt;
  final DateTime? blockedUntil;

  static const _keep = Object();

  _LockConfig copyWith({
    Map<String, Object?>? pin,
    bool? biometrics,
    LockTimeout? timeout,
    bool? emergency,
    int? failures,
    Object? blockedAt = _keep,
    Object? blockedUntil = _keep,
  }) => _LockConfig(
    pin: pin ?? this.pin,
    biometrics: biometrics ?? this.biometrics,
    timeout: timeout ?? this.timeout,
    emergency: emergency ?? this.emergency,
    failures: failures ?? this.failures,
    blockedAt: identical(blockedAt, _keep)
        ? this.blockedAt
        : blockedAt as DateTime?,
    blockedUntil: identical(blockedUntil, _keep)
        ? this.blockedUntil
        : blockedUntil as DateTime?,
  );

  String toJson() => jsonEncode({
    'pin': pin,
    'biometrics': biometrics,
    'timeout': timeout.name,
    'emergency': emergency,
    'failures': failures,
    'blockedAt': blockedAt?.millisecondsSinceEpoch,
    'blockedUntil': blockedUntil?.millisecondsSinceEpoch,
  });
}

/// Overridden in `main.dart` with the saved lock. Tests get it off.
final appLockProvider = Provider<AppLock>((ref) => AppLock.off());

/// Where the first-run offer to turn the lock on lives.
const appLockOfferPath = '/app-lock/offer';

/// Where the lock's settings live.
const appLockSettingsPath = '/settings/app-lock';

/// The lock is offered once, after the first-run tour.
bool appLockOfferPending(KeyValueStore store, AppLock lock) =>
    !lock.enabled && store.getBool(PrefKeys.appLockOffered) != true;
