import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../preferences.dart';
import 'pin_hasher.dart';
import 'secure_storage_options.dart';

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
            // A read error must keep the app locked (fail closed), not turn
            // the lock off; AppLock retries it.
            aOptions: secureStorageAndroidOptions,
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

/// Time since the phone started, counting while it sleeps, which can't be
/// changed in the phone's settings (Android `elapsedRealtime`, iOS
/// `CLOCK_MONOTONIC`). Null when the platform can't tell.
abstract class Uptime {
  Future<Duration?> now();
}

class PlatformUptime implements Uptime {
  const PlatformUptime();

  static const channel = MethodChannel('usra/clock');

  @override
  Future<Duration?> now() async {
    try {
      final ms = await channel.invokeMethod<int>('elapsedRealtime');
      return ms == null ? null : Duration(milliseconds: ms);
    } catch (_) {
      return null;
    }
  }
}

/// For tests, and where there's no platform clock.
class NoUptime implements Uptime {
  const NoUptime();

  @override
  Future<Duration?> now() async => null;
}

final _ticks = Stopwatch()..start();

/// Time since the app started; can't be changed in the phone's settings,
/// but may stop while the phone sleeps (so it only ever makes waits longer).
Duration processTicks() => _ticks.elapsed;

var _tripsOpen = 0;
Duration? _tripStarted;

/// Wraps a trip the app itself starts to another app (camera, gallery,
/// file picker, share sheet, dialer), so coming back from it within
/// [tripGrace] doesn't lock with "Right away".
Future<T> whileInOtherApp<T>(Future<T> Function() trip) async {
  _tripsOpen++;
  _tripStarted = processTicks();
  try {
    return await trip();
  } finally {
    _tripsOpen--;
  }
}

/// A trip is open, or one was started moments ago (a dialer or settings
/// screen returns as soon as it's launched, before the app leaves).
bool get _onTrip {
  final started = _tripStarted;
  return _tripsOpen > 0 ||
      (started != null &&
          processTicks() - started < const Duration(seconds: 3));
}

/// How long a trip from [whileInOtherApp] may take with "Right away".
const tripGrace = Duration(minutes: 1);

/// How long the app may be away while a biometric prompt is up (some
/// phones pause the app for it).
const promptGrace = Duration(seconds: 15);

/// How long the app may stay in the background before it locks again.
enum LockTimeout {
  immediately(Duration.zero),
  oneMinute(Duration(minutes: 1)),
  fiveMinutes(Duration(minutes: 5));

  const LockTimeout(this.duration);

  final Duration duration;
}

/// The result of typing a PIN. [unavailable]: the saved lock can't be read
/// right now (try again; nothing was counted).
enum PinCheck { ok, wrong, blocked, unavailable }

/// Every PIN has 6 digits.
const pinLength = 6;

/// PINs a stranger would try first: one digit repeated, a run up or down
/// (123456, 987654), a repeated pair or triple (121212, 123123), and a few
/// keypad patterns.
bool isTrivialPin(String pin) {
  if (pin.length != pinLength) return true;
  final d = pin.codeUnits.map((c) => c - 0x30).toList();
  bool steps(int by) {
    for (var i = 1; i < d.length; i++) {
      if (d[i] - d[i - 1] != by) return false;
    }
    return true;
  }

  bool period(int n) {
    for (var i = n; i < d.length; i++) {
      if (d[i] != d[i - n]) return false;
    }
    return true;
  }

  return steps(0) ||
      steps(1) ||
      steps(-1) ||
      period(2) ||
      period(3) ||
      const {
        '112233',
        '147258',
        '159753',
        '258369',
        '369258',
        '852456',
      }.contains(pin);
}

/// Wrong PINs allowed before the app makes the person wait.
const freeAttempts = 5;

/// With "Erase after too many wrong PINs" on, this many wrong PINs in a
/// row delete all the app's data (S10). With the waits after
/// [freeAttempts], getting there takes at least a quarter of an hour.
const wipeAfterFailures = 10;

/// The wait after [failures] wrong PINs in a row: none for the first
/// [freeAttempts], then 30 s, doubling each time, at most an hour.
Duration lockoutAfter(int failures) {
  if (failures < freeAttempts) return Duration.zero;
  final steps = min(failures - freeAttempts, 7);
  return Duration(seconds: min(30 * (1 << steps), 3600));
}

/// When the app left the screen, by every clock.
class _Away {
  _Away(this.wall, this.ticks, this.uptime, this.grace);

  final DateTime wall;
  final Duration ticks;
  final Future<Duration?> uptime;
  final Duration grace;
}

/// The optional app lock: a PIN, with fingerprint or face as a shortcut.
///
/// Lives outside the provider container, so a backup restore (which builds
/// a new container) neither re-locks nor forgets a held deep link.
///
/// Waits and timeouts never trust the phone's clock alone: someone holding
/// the phone can change it. A wait after wrong PINs needs real time to
/// pass in this run of the app (and starts again in full after a restart);
/// the background timeout also measures with [Uptime] and [processTicks].
class AppLock extends ChangeNotifier {
  AppLock._({
    required this._store,
    required this._hasher,
    required this.biometrics,
    required this._clock,
    required this._ticks,
    required this._uptime,
  });

  /// Reads the saved lock. Starts locked whenever a PIN is set, and also
  /// when it can't be read.
  ///
  /// [freshInstall] drops a lock left in the iOS Keychain by an earlier
  /// install of the app, whose data is already gone.
  static Future<AppLock> open({
    required LockStore store,
    BiometricUnlock biometrics = const NoBiometrics(),
    PinHasher hasher = const PinHasher(),
    DateTime Function() clock = DateTime.now,
    Duration Function() ticks = processTicks,
    Uptime uptime = const NoUptime(),
    bool freshInstall = false,
  }) async {
    if (freshInstall) await store.delete();
    final lock = AppLock._(
      store: store,
      hasher: hasher,
      biometrics: biometrics,
      clock: clock,
      ticks: ticks,
      uptime: uptime,
    );
    lock._unreadable = true;
    await lock._reload();
    lock._locked = lock.enabled;
    return lock;
  }

  /// Off and unlocked, kept in memory: the default in tests.
  factory AppLock.off({
    LockStore? store,
    PinHasher hasher = const PinHasher(),
    BiometricUnlock biometrics = const NoBiometrics(),
    DateTime Function() clock = DateTime.now,
    Duration Function() ticks = processTicks,
    Uptime uptime = const NoUptime(),
  }) => AppLock._(
    store: store ?? MemoryLockStore(),
    hasher: hasher,
    biometrics: biometrics,
    clock: clock,
    ticks: ticks,
    uptime: uptime,
  );

  final LockStore _store;
  final PinHasher _hasher;
  final BiometricUnlock biometrics;
  final DateTime Function() _clock;
  final Duration Function() _ticks;
  final Uptime _uptime;
  _LockConfig? _config;

  /// The saved lock couldn't be read. Locked, nothing is saved over it
  /// (that would destroy the real PIN hash), and it's read again on each
  /// try and on coming back to the app.
  bool _unreadable = false;
  bool _locked = false;
  _Away? _away;
  VoidCallback? _pending;
  bool _prompting = false;

  /// [processTicks] when the current wait started in this run; null when
  /// it started in an earlier run (then it starts again in full).
  Duration? _waitStartedTicks;

  bool get enabled => _config != null || _unreadable;
  bool get locked => _locked;

  /// The saved lock can't be read right now.
  bool get unreadable => _unreadable;
  bool get biometricsEnabled => _config?.biometrics ?? false;

  /// "Erase after too many wrong PINs": off unless turned on.
  bool get wipeOnFailures => _config?.wipeOnFailures ?? false;

  /// Wrong PINs left before everything is erased, when that's on.
  int? get triesBeforeWipe =>
      wipeOnFailures ? max(0, wipeAfterFailures - failures) : null;

  /// Deletes all data when [wipeAfterFailures] wrong PINs are reached with
  /// [wipeOnFailures] on. Set in `main.dart`.
  Future<void> Function()? onTooManyFailures;
  LockTimeout get timeout => _config?.timeout ?? LockTimeout.oneMinute;

  /// People whose emergency card first responders may open from the lock
  /// screen without the PIN. Nobody unless the person adds them.
  Set<String> get emergencyProfiles => {...?_config?.emergency};
  bool get emergencyOnLockScreen => _config?.emergency.isNotEmpty ?? false;

  /// Wrong PINs in a row.
  int get failures => _config?.failures ?? 0;

  /// How long until the next PIN may be tried; zero when it may be now.
  /// Both the phone's clock and this run's own time must have passed.
  Duration get waitRemaining {
    final c = _config;
    final until = c?.blockedUntil;
    final at = c?.blockedAt;
    if (c == null || until == null || at == null) return Duration.zero;
    final wait = until.difference(at);
    final started = _waitStartedTicks;
    var left = until.difference(_clock());
    if (started == null) {
      left = wait;
    } else {
      final ran = wait - (_ticks() - started);
      if (ran > left) left = ran;
    }
    if (left > wait) left = wait;
    return left.isNegative ? Duration.zero : left;
  }

  /// Reads the saved lock again when it couldn't be read. True when it's
  /// readable now.
  Future<bool> _reload() async {
    if (!_unreadable) return true;
    try {
      final raw = await _store.read();
      _config = raw == null ? null : _LockConfig.fromJson(raw);
      _unreadable = false;
    } catch (_) {
      return false;
    }
    // A wait from an earlier run starts again in full: restarting the app
    // or the phone must never shorten it.
    final c = _config;
    if (c != null && c.failures >= freeAttempts) {
      final now = _clock();
      _config = c.copyWith(
        blockedAt: now,
        blockedUntil: now.add(lockoutAfter(c.failures)),
      );
      _waitStartedTicks = _ticks();
      await _trySave();
    }
    if (!enabled) _locked = false;
    notifyListeners();
    return true;
  }

  /// Turns the lock on with [pin]; the caller has already had it typed
  /// twice.
  Future<void> enable(String pin, {bool biometrics = false}) async {
    _config = _LockConfig(
      pin: await _hasher.hash(pin),
      biometrics: biometrics,
      timeout: _config?.timeout ?? LockTimeout.oneMinute,
      emergency: _config?.emergency ?? const [],
      wipeOnFailures: _config?.wipeOnFailures ?? false,
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
    await _store.delete();
    _config = null;
    _unreadable = false;
    _locked = false;
    _away = null;
    notifyListeners();
  }

  Future<void> setWipeOnFailures(bool on) =>
      _update((c) => c.copyWith(wipeOnFailures: on));

  /// After "Delete all my data": the lock is gone with everything else
  /// (its Keystore item too); nothing held from before runs.
  Future<void> forgetAfterWipe() async {
    try {
      await _store.delete();
    } catch (_) {
      // Already deleted with the other keys, or retried by the wipe.
    }
    _config = null;
    _unreadable = false;
    _locked = false;
    _away = null;
    _pending = null;
    _waitStartedTicks = null;
    notifyListeners();
  }

  Future<void> setBiometrics(bool on) =>
      _update((c) => c.copyWith(biometrics: on));

  Future<void> setTimeout(LockTimeout timeout) =>
      _update((c) => c.copyWith(timeout: timeout));

  Future<void> setEmergencyProfile(String profileId, bool on) => _update(
    (c) => c.copyWith(
      emergency: [
        for (final id in c.emergency)
          if (id != profileId) id,
        if (on) profileId,
      ],
    ),
  );

  /// Checks [pin]; on success the app unlocks and the wrong-PIN count
  /// starts again.
  Future<PinCheck> checkPin(String pin) async {
    if (_unreadable && !await _reload()) return PinCheck.unavailable;
    var c = _config;
    if (c == null) return PinCheck.ok;
    final before = c;
    c = _clockMovedBack(c);
    if (!identical(c, before)) await _trySave();
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
    _waitStartedTicks = wait == Duration.zero ? null : _ticks();
    // If it can't be saved, it still counts for as long as the app runs:
    // the owner must be able to unlock even with storage failing.
    await _trySave();
    if (!await _hasher.verify(pin, c.pin)) {
      notifyListeners();
      if (c.wipeOnFailures && failures >= wipeAfterFailures) {
        await onTooManyFailures?.call();
      }
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

  /// The system biometric prompt. Time away while it's up still counts;
  /// only [promptGrace] is allowed on top with "Right away".
  Future<bool> authenticate(String reason) async {
    _prompting = true;
    try {
      return await biometrics.authenticate(reason);
    } finally {
      _prompting = false;
    }
  }

  Future<void> _passed() async {
    final c = _config;
    if (c != null && (c.failures != 0 || c.blockedUntil != null)) {
      _config = c.copyWith(failures: 0, blockedUntil: null, blockedAt: null);
      _waitStartedTicks = null;
      await _trySave();
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
    if (_locked || !enabled || _away != null) return;
    _away = _Away(
      _clock(),
      _ticks(),
      _uptime.now(),
      _prompting
          ? promptGrace
          : _onTrip
          ? tripGrace
          : Duration.zero,
    );
  }

  /// The app is back. Locks when it was away for at least [timeout] by
  /// any clock, or the phone's clock was turned back.
  Future<void> movedToForeground() async {
    final away = _away;
    _away = null;
    if (_unreadable) await _reload();
    if (away == null || !enabled) return;
    final limit = timeout.duration > away.grace ? timeout.duration : away.grace;
    final wall = _clock().difference(away.wall);
    final ticks = _ticks() - away.ticks;
    if (wall.isNegative || wall >= limit || ticks >= limit) return lock();
    final (before, after) = (await away.uptime, await _uptime.now());
    if (before != null && after != null && after - before >= limit) lock();
  }

  /// A block set "in the future" means the clock was turned back: start
  /// the wait again from now rather than let it run for days.
  _LockConfig _clockMovedBack(_LockConfig c) {
    final at = c.blockedAt;
    final now = _clock();
    if (at == null || !now.isBefore(at)) return c;
    _waitStartedTicks = _ticks();
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
    // Never over a record that couldn't be read.
    if (c != null && !_unreadable) await _store.write(c.toJson());
    notifyListeners();
  }

  Future<void> _trySave() async {
    try {
      await _save();
    } catch (_) {
      notifyListeners();
    }
  }
}

/// Saved as one JSON value in secure storage.
class _LockConfig {
  const _LockConfig({
    required this.pin,
    this.biometrics = false,
    this.timeout = LockTimeout.oneMinute,
    this.emergency = const [],
    this.failures = 0,
    this.blockedAt,
    this.blockedUntil,
    this.wipeOnFailures = false,
  });

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
      emergency: [
        for (final id in j['emergency'] as List? ?? const [])
          if (id is String) id,
      ],
      failures: j['failures'] as int? ?? 0,
      blockedAt: time('blockedAt'),
      blockedUntil: time('blockedUntil'),
      wipeOnFailures: j['wipeOnFailures'] == true,
    );
  }

  final Map<String, Object?> pin;
  final bool biometrics;
  final LockTimeout timeout;

  /// Profile ids shown on the lock screen's emergency button.
  final List<String> emergency;
  final int failures;
  final DateTime? blockedAt;
  final DateTime? blockedUntil;
  final bool wipeOnFailures;

  static const _keep = Object();

  _LockConfig copyWith({
    Map<String, Object?>? pin,
    bool? biometrics,
    LockTimeout? timeout,
    List<String>? emergency,
    int? failures,
    Object? blockedAt = _keep,
    Object? blockedUntil = _keep,
    bool? wipeOnFailures,
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
    wipeOnFailures: wipeOnFailures ?? this.wipeOnFailures,
  );

  String toJson() => jsonEncode({
    'pin': pin,
    'biometrics': biometrics,
    'timeout': timeout.name,
    'emergency': emergency,
    'failures': failures,
    'blockedAt': blockedAt?.millisecondsSinceEpoch,
    'blockedUntil': blockedUntil?.millisecondsSinceEpoch,
    'wipeOnFailures': wipeOnFailures,
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
