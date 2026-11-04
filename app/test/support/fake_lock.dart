import 'dart:collection';

import 'package:usra/core/security/app_lock.dart';
import 'package:usra/core/security/pin_hasher.dart';

/// Argon2id at its smallest, so tests run fast; the app uses 19 MiB.
const fastHasher = PinHasher(memory: 64, iterations: 1);

/// A [MemoryLockStore] whose reads or writes can be made to fail.
class FlakyLockStore extends MemoryLockStore {
  /// The next this many reads throw.
  int failReads = 0;
  bool failWrites = false;
  int writes = 0;

  @override
  Future<String?> read() async {
    if (failReads > 0) {
      failReads--;
      throw StateError('keystore unavailable');
    }
    return super.read();
  }

  @override
  Future<void> write(String value) async {
    if (failWrites) throw StateError('keystore unavailable');
    writes++;
    await super.write(value);
  }
}

/// The phone's clock, the app's own ticks and the phone's uptime, moved
/// together or one at a time.
class FakeClocks implements Uptime {
  DateTime _wall = DateTime(2026, 11, 4, 9);
  Duration _ticks = Duration.zero;
  Duration _uptime = const Duration(hours: 3);

  DateTime wall() => _wall;
  Duration ticks() => _ticks;

  @override
  Future<Duration?> now() async => _uptime;

  /// Real time passes with the app running.
  void pass(Duration d) {
    _wall = _wall.add(d);
    _ticks += d;
    _uptime += d;
  }

  /// Someone changes the clock in the phone's settings.
  void wallOnly(Duration d) => _wall = _wall.add(d);

  void ticksOnly(Duration d) => _ticks += d;

  /// Time passes while the phone sleeps (the app's ticks stop).
  void uptimeOnly(Duration d) => _uptime += d;
}

class FakeBiometrics implements BiometricUnlock {
  FakeBiometrics({this.pass = false});

  bool pass;
  int asked = 0;

  /// Runs while the prompt is "up".
  void Function()? onPrompt;

  @override
  Future<bool> available() async => true;

  @override
  Future<bool> authenticate(String reason) async {
    asked++;
    onPrompt?.call();
    return pass;
  }
}

/// Counts how many elements were read.
class CountingList extends ListBase<int> {
  CountingList(this._items);

  final List<int> _items;
  int reads = 0;

  @override
  int get length => _items.length;

  @override
  set length(int value) => _items.length = value;

  @override
  int operator [](int index) {
    reads++;
    return _items[index];
  }

  @override
  void operator []=(int index, int value) => _items[index] = value;
}
