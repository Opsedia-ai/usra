import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/security/app_lock.dart';
import 'package:usra/core/security/pin_hasher.dart';

/// Argon2id at its smallest, so tests run fast; the app uses 19 MiB.
const fastHasher = PinHasher(memory: 64, iterations: 1);

void main() {
  late MemoryLockStore store;
  late DateTime now;

  setUp(() {
    store = MemoryLockStore();
    now = DateTime(2026, 11, 4, 9);
  });

  Future<AppLock> open({bool freshInstall = false}) => AppLock.open(
    store: store,
    hasher: fastHasher,
    clock: () => now,
    freshInstall: freshInstall,
  );

  Future<AppLock> withPin(String pin) async {
    final lock = await open();
    await lock.enable(pin);
    return open();
  }

  group('PIN hash', () {
    test('only a salted Argon2id hash is saved, never the PIN', () async {
      final lock = await open();
      await lock.enable('482915');

      final saved = store.value!;
      expect(saved, isNot(contains('482915')));
      final pin = (jsonDecode(saved) as Map)['pin'] as Map;
      expect(pin['kdf'], 'argon2id');
      expect(base64Decode(pin['salt'] as String), hasLength(16));
      expect(base64Decode(pin['hash'] as String), hasLength(32));

      // The same PIN twice gives different hashes (random salt).
      final again = await fastHasher.hash('482915');
      expect(again['hash'], isNot(pin['hash']));
      expect(await fastHasher.verify('482915', again), isTrue);
      expect(await fastHasher.verify('482916', again), isFalse);
    });

    test('the app default is the OWASP Argon2id minimum', () {
      const hasher = PinHasher();
      expect(hasher.memory, 19456);
      expect(hasher.iterations, 2);
    });

    test('a damaged record or unsafe cost never matches', () async {
      final good = await fastHasher.hash('1234');
      expect(await fastHasher.verify('1234', {...good, 'kdf': 'md5'}), false);
      expect(await fastHasher.verify('1234', {...good, 'memory': 1}), false);
      expect(await fastHasher.verify('1234', {...good, 'hash': '!!'}), false);
      expect(await fastHasher.verify('1234', {}), false);
    });

    test('constant-time compare', () {
      expect(constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
      expect(constantTimeEquals([1, 2, 3], [1, 2, 4]), isFalse);
      expect(constantTimeEquals([1, 2, 3], [1, 2]), isFalse);
    });
  });

  group('lock and unlock', () {
    test('off by default, and nothing is saved', () async {
      final lock = await open();
      expect(lock.enabled, isFalse);
      expect(lock.locked, isFalse);
      expect(store.value, isNull);
    });

    test('starts locked once a PIN is set; the right PIN opens', () async {
      final lock = await withPin('1234');
      expect(lock.locked, isTrue);

      expect(await lock.checkPin('9999'), PinCheck.wrong);
      expect(lock.locked, isTrue);
      expect(await lock.checkPin('1234'), PinCheck.ok);
      expect(lock.locked, isFalse);
      expect(lock.failures, 0);
    });

    test('biometrics unlock only when turned on and passed', () async {
      final face = _FakeBiometrics(pass: true);
      await (await open()).enable('1234');
      var lock = await AppLock.open(
        store: store,
        hasher: fastHasher,
        biometrics: face,
      );
      expect(await lock.checkBiometrics('why'), isFalse);
      expect(face.asked, 0);
      expect(lock.locked, isTrue);

      await lock.setBiometrics(true);
      lock = await AppLock.open(
        store: store,
        hasher: fastHasher,
        biometrics: face,
      );
      expect(await lock.checkBiometrics('why'), isTrue);
      expect(lock.locked, isFalse);

      face.pass = false;
      lock.lock();
      expect(await lock.checkBiometrics('why'), isFalse);
      expect(lock.locked, isTrue);
    });

    test('turning it off forgets the PIN', () async {
      final lock = await withPin('1234');
      await lock.disable();
      expect(store.value, isNull);
      expect((await open()).locked, isFalse);
    });

    test('a changed PIN replaces the old one', () async {
      final lock = await withPin('1234');
      await lock.checkPin('1234');
      await lock.changePin('56789');
      final reopened = await open();
      expect(await reopened.checkPin('1234'), PinCheck.wrong);
      expect(await reopened.checkPin('56789'), PinCheck.ok);
    });

    test('an unreadable saved lock stays locked', () async {
      store.value = '{not json';
      final lock = await open();
      expect(lock.locked, isTrue);
      expect(await lock.checkPin('1234'), PinCheck.wrong);
      expect(lock.locked, isTrue);
    });

    test('a fresh install drops a lock left by a deleted copy', () async {
      await (await open()).enable('1234');
      final lock = await open(freshInstall: true);
      expect(lock.enabled, isFalse);
      expect(store.value, isNull);
    });
  });

  group('wrong PINs', () {
    test('lockout grows from 30 s and is capped at an hour', () {
      expect(lockoutAfter(4), Duration.zero);
      expect(lockoutAfter(5), const Duration(seconds: 30));
      expect(lockoutAfter(6), const Duration(minutes: 1));
      expect(lockoutAfter(7), const Duration(minutes: 2));
      expect(lockoutAfter(50), const Duration(hours: 1));
    });

    test('5 wrong → wait 30 s, kept across a restart', () async {
      var lock = await withPin('1234');
      for (var i = 0; i < 4; i++) {
        expect(await lock.checkPin('0000'), PinCheck.wrong);
        expect(lock.waitRemaining, Duration.zero);
      }
      expect(await lock.checkPin('0000'), PinCheck.wrong);
      expect(lock.waitRemaining, const Duration(seconds: 30));

      // Closing and opening the app doesn't reset it.
      lock = await open();
      expect(lock.failures, 5);
      expect(lock.waitRemaining, const Duration(seconds: 30));
      // Even the right PIN waits.
      expect(await lock.checkPin('1234'), PinCheck.blocked);
      expect(lock.locked, isTrue);

      now = now.add(const Duration(seconds: 30));
      expect(await lock.checkPin('0000'), PinCheck.wrong);
      expect(lock.waitRemaining, const Duration(minutes: 1));

      now = now.add(const Duration(minutes: 1));
      expect(await lock.checkPin('1234'), PinCheck.ok);
      expect(lock.failures, 0);
      expect((await open()).failures, 0);
    });

    test('a try is counted before it is checked', () async {
      final lock = await withPin('1234');
      final check = lock.checkPin('0000');
      // Saved already, so killing the app mid-check isn't a free guess.
      expect((jsonDecode(store.value!) as Map)['failures'], 1);
      await check;
    });

    test('turning the clock back doesn\'t make the wait last forever, '
        'nor skip it', () async {
      final lock = await withPin('1234');
      for (var i = 0; i < 5; i++) {
        await lock.checkPin('0000');
      }
      now = now.subtract(const Duration(days: 1));
      expect(await lock.checkPin('1234'), PinCheck.blocked);
      expect(lock.waitRemaining, const Duration(seconds: 30));
      // The restarted wait is saved too.
      expect((await open()).waitRemaining, const Duration(seconds: 30));
      now = now.add(const Duration(seconds: 30));
      expect(await lock.checkPin('1234'), PinCheck.ok);
    });
  });

  group('background timeout', () {
    test('locks again only after the chosen time away', () async {
      final lock = await withPin('1234');
      await lock.checkPin('1234');
      expect(lock.timeout, LockTimeout.oneMinute);

      lock.movedToBackground();
      now = now.add(const Duration(seconds: 59));
      lock.movedToForeground();
      expect(lock.locked, isFalse);

      lock.movedToBackground();
      now = now.add(const Duration(minutes: 1));
      lock.movedToForeground();
      expect(lock.locked, isTrue);
    });

    test('"right away" locks on any trip to the background', () async {
      final lock = await withPin('1234');
      await lock.checkPin('1234');
      await lock.setTimeout(LockTimeout.immediately);
      lock.movedToBackground();
      lock.movedToForeground();
      expect(lock.locked, isTrue);
      expect((await open()).timeout, LockTimeout.immediately);
    });

    test(
      'the biometric prompt pausing the app doesn\'t start the clock',
      () async {
        final face = _FakeBiometrics(pass: true);
        await (await open()).enable('1234', biometrics: true);
        final lock = await AppLock.open(
          store: store,
          hasher: fastHasher,
          biometrics: face,
          clock: () => now,
        );
        await lock.setTimeout(LockTimeout.immediately);
        face.onPrompt = lock.movedToBackground;
        expect(await lock.checkBiometrics('why'), isTrue);
        lock.movedToForeground();
        expect(lock.locked, isFalse);
      },
    );

    test('never locks when off', () async {
      final lock = await open();
      lock.movedToBackground();
      now = now.add(const Duration(hours: 1));
      lock.movedToForeground();
      expect(lock.locked, isFalse);
    });
  });

  group('held deep links', () {
    test('run after unlocking; only the latest is kept', () async {
      final lock = await withPin('1234');
      final ran = <String>[];
      lock.runWhenUnlocked(() => ran.add('first'));
      lock.runWhenUnlocked(() => ran.add('medicines'));
      expect(ran, isEmpty);

      await lock.checkPin('0000');
      expect(ran, isEmpty);
      await lock.checkPin('1234');
      expect(ran, ['medicines']);

      lock.runWhenUnlocked(() => ran.add('now'));
      expect(ran, ['medicines', 'now']);
    });
  });

  test('emergency card on the lock screen is off by default', () async {
    final lock = await withPin('1234');
    expect(lock.emergencyOnLockScreen, isFalse);
    await lock.setEmergencyOnLockScreen(true);
    expect((await open()).emergencyOnLockScreen, isTrue);
  });
}

class _FakeBiometrics implements BiometricUnlock {
  _FakeBiometrics({required this.pass});

  bool pass;
  int asked = 0;
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
