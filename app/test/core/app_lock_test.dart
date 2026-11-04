import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/security/app_lock.dart';
import 'package:usra/core/security/pin_hasher.dart';

import '../support/fake_lock.dart';

void main() {
  late FlakyLockStore store;
  late FakeClocks clocks;

  setUp(() {
    store = FlakyLockStore();
    clocks = FakeClocks();
  });

  Future<AppLock> open({
    bool freshInstall = false,
    BiometricUnlock biometrics = const NoBiometrics(),
  }) => AppLock.open(
    store: store,
    hasher: fastHasher,
    biometrics: biometrics,
    clock: clocks.wall,
    ticks: clocks.ticks,
    uptime: clocks,
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

    test('constant-time compare looks at every byte', () {
      expect(constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
      expect(constantTimeEquals([1, 2, 3], [1, 2, 4]), isFalse);
      expect(constantTimeEquals([9, 2, 3], [1, 2, 3]), isFalse);
      expect(constantTimeEquals([1, 2, 3], [1, 2]), isFalse);
      // A list that counts reads: all of both are read even when the first
      // byte already differs.
      final a = CountingList([9, 2, 3, 4]);
      final b = CountingList([1, 2, 3, 4]);
      constantTimeEquals(a, b);
      expect((a.reads, b.reads), (4, 4));
    });
  });

  group('new PINs', () {
    test('6 digits, nothing a stranger would try first', () {
      for (final pin in [
        '000000',
        '999999',
        '123456',
        '012345',
        '987654',
        '654321',
        '121212',
        '123123',
        '112233',
        '159753',
        '12345',
        '1234567',
      ]) {
        expect(isTrivialPin(pin), isTrue, reason: pin);
      }
      for (final pin in ['482915', '730184', '258046', '135792']) {
        expect(isTrivialPin(pin), isFalse, reason: pin);
      }
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
      final lock = await withPin('482915');
      expect(lock.locked, isTrue);

      expect(await lock.checkPin('999999'), PinCheck.wrong);
      expect(lock.locked, isTrue);
      expect(await lock.checkPin('482915'), PinCheck.ok);
      expect(lock.locked, isFalse);
      expect(lock.failures, 0);
    });

    test('biometrics unlock only when turned on and passed', () async {
      final face = FakeBiometrics(pass: true);
      await (await open()).enable('482915');
      var lock = await open(biometrics: face);
      expect(await lock.checkBiometrics('why'), isFalse);
      expect(face.asked, 0);
      expect(lock.locked, isTrue);

      await lock.setBiometrics(true);
      lock = await open(biometrics: face);
      expect(await lock.checkBiometrics('why'), isTrue);
      expect(lock.locked, isFalse);

      face.pass = false;
      lock.lock();
      expect(await lock.checkBiometrics('why'), isFalse);
      expect(lock.locked, isTrue);
    });

    test('turning it off forgets the PIN', () async {
      final lock = await withPin('482915');
      await lock.disable();
      expect(store.value, isNull);
      expect((await open()).locked, isFalse);
    });

    test('a changed PIN replaces the old one', () async {
      final lock = await withPin('482915');
      await lock.checkPin('482915');
      await lock.changePin('730184');
      final reopened = await open();
      expect(await reopened.checkPin('482915'), PinCheck.wrong);
      expect(await reopened.checkPin('730184'), PinCheck.ok);
    });

    test('a fresh install drops a lock left by a deleted copy', () async {
      await (await open()).enable('482915');
      final lock = await open(freshInstall: true);
      expect(lock.enabled, isFalse);
      expect(store.value, isNull);
    });
  });

  group('unreadable storage', () {
    test(
      'a read error keeps it locked and never overwrites the hash',
      () async {
        await (await open()).enable('482915');
        final saved = store.value;
        store.failReads = 2;
        store.writes = 0;

        final lock = await open();
        expect(lock.locked, isTrue);
        expect(lock.unreadable, isTrue);
        // Still failing: nothing is checked, counted or saved.
        expect(await lock.checkPin('482915'), PinCheck.unavailable);
        expect(store.value, saved);
        expect(store.writes, 0);

        // Readable again on the next try: the real PIN works.
        expect(await lock.checkPin('000000'), PinCheck.wrong);
        expect(lock.unreadable, isFalse);
        expect(await lock.checkPin('482915'), PinCheck.ok);
        expect(lock.locked, isFalse);
      },
    );

    test('read again on coming back to the app', () async {
      await (await open()).enable('482915');
      store.failReads = 1;
      final lock = await open();
      expect(lock.unreadable, isTrue);
      await lock.movedToForeground();
      expect(lock.unreadable, isFalse);
      expect(lock.locked, isTrue);
    });

    test('a damaged record stays locked and is left as it is', () async {
      store.value = '{not json';
      final lock = await open();
      expect(lock.locked, isTrue);
      expect(await lock.checkPin('482915'), PinCheck.unavailable);
      expect(lock.locked, isTrue);
      expect(store.value, '{not json');
    });

    test('a write error still lets the owner in', () async {
      final lock = await withPin('482915');
      store.failWrites = true;
      expect(await lock.checkPin('000000'), PinCheck.wrong);
      expect(lock.failures, 1);
      expect(await lock.checkPin('482915'), PinCheck.ok);
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

    test('5 wrong → wait 30 s; a restart starts it again in full', () async {
      var lock = await withPin('482915');
      for (var i = 0; i < 4; i++) {
        expect(await lock.checkPin('000000'), PinCheck.wrong);
        expect(lock.waitRemaining, Duration.zero);
      }
      expect(await lock.checkPin('000000'), PinCheck.wrong);
      expect(lock.waitRemaining, const Duration(seconds: 30));

      clocks.pass(const Duration(seconds: 20));
      // Closing and opening the app never shortens it.
      lock = await open();
      expect(lock.failures, 5);
      expect(lock.waitRemaining, const Duration(seconds: 30));
      // Even the right PIN waits.
      expect(await lock.checkPin('482915'), PinCheck.blocked);
      expect(lock.locked, isTrue);

      clocks.pass(const Duration(seconds: 30));
      expect(await lock.checkPin('000000'), PinCheck.wrong);
      expect(lock.waitRemaining, const Duration(minutes: 1));

      clocks.pass(const Duration(minutes: 1));
      expect(await lock.checkPin('482915'), PinCheck.ok);
      expect(lock.failures, 0);
      expect((await open()).failures, 0);
    });

    test('a try is counted before it is checked', () async {
      final lock = await withPin('482915');
      final check = lock.checkPin('000000');
      // Saved already, so killing the app mid-check isn't a free guess.
      expect((jsonDecode(store.value!) as Map)['failures'], 1);
      await check;
    });

    test('turning the clock forward doesn\'t end the wait', () async {
      final lock = await withPin('482915');
      for (var i = 0; i < 5; i++) {
        await lock.checkPin('000000');
      }
      clocks.wallOnly(const Duration(hours: 2));
      expect(await lock.checkPin('482915'), PinCheck.blocked);
      expect(lock.waitRemaining, const Duration(seconds: 30));

      clocks.ticksOnly(const Duration(seconds: 30));
      expect(await lock.checkPin('482915'), PinCheck.ok);
    });

    test('turning the clock back restarts the wait, saved', () async {
      final lock = await withPin('482915');
      for (var i = 0; i < 5; i++) {
        await lock.checkPin('000000');
      }
      clocks.wallOnly(const Duration(days: -1));
      expect(await lock.checkPin('482915'), PinCheck.blocked);
      expect(lock.waitRemaining, const Duration(seconds: 30));
      expect((await open()).waitRemaining, const Duration(seconds: 30));
      clocks.pass(const Duration(seconds: 30));
      expect(await lock.checkPin('482915'), PinCheck.ok);
    });
  });

  group('background timeout', () {
    Future<AppLock> unlocked() async {
      final lock = await withPin('482915');
      await lock.checkPin('482915');
      return lock;
    }

    test('locks again only after the chosen time away', () async {
      final lock = await unlocked();
      expect(lock.timeout, LockTimeout.oneMinute);

      lock.movedToBackground();
      clocks.pass(const Duration(seconds: 59));
      await lock.movedToForeground();
      expect(lock.locked, isFalse);

      lock.movedToBackground();
      clocks.pass(const Duration(minutes: 1));
      await lock.movedToForeground();
      expect(lock.locked, isTrue);
    });

    test('"Right away" locks on any trip to the background', () async {
      final lock = await unlocked();
      await lock.setTimeout(LockTimeout.immediately);
      lock.movedToBackground();
      await lock.movedToForeground();
      expect(lock.locked, isTrue);
      expect((await open()).timeout, LockTimeout.immediately);
    });

    test('turning the clock back while away still locks', () async {
      final lock = await unlocked();
      lock.movedToBackground();
      // Ten minutes away, the phone asleep (the app's own ticks stop)…
      clocks.wallOnly(const Duration(minutes: 10));
      clocks.uptimeOnly(const Duration(minutes: 10));
      // …then someone sets the clock back 9½ minutes.
      clocks.wallOnly(const Duration(minutes: -9, seconds: -30));
      await lock.movedToForeground();
      expect(lock.locked, isTrue);
    });

    test('turning the clock back further than the absence locks', () async {
      final lock = await unlocked();
      lock.movedToBackground();
      clocks.wallOnly(const Duration(minutes: -5));
      await lock.movedToForeground();
      expect(lock.locked, isTrue);
    });

    test(
      'without a platform clock, the app\'s own time still counts',
      () async {
        final lock = await AppLock.open(
          store: store,
          hasher: fastHasher,
          clock: clocks.wall,
          ticks: clocks.ticks,
        );
        await lock.enable('482915');
        lock.movedToBackground();
        clocks.ticksOnly(const Duration(minutes: 2));
        await lock.movedToForeground();
        expect(lock.locked, isTrue);
      },
    );

    test('a biometric prompt gets a short grace, not a free pass', () async {
      final face = FakeBiometrics(pass: true);
      await (await open()).enable('482915', biometrics: true);
      final lock = await open(biometrics: face);
      await lock.checkPin('482915');
      await lock.setTimeout(LockTimeout.immediately);

      // The prompt pauses the app for a moment: no lock.
      face.onPrompt = () {
        lock.movedToBackground();
        clocks.pass(const Duration(seconds: 5));
      };
      expect(await lock.authenticate('why'), isTrue);
      await lock.movedToForeground();
      expect(lock.locked, isFalse);

      // Home pressed with the prompt up, back ten minutes later: locked,
      // whatever the prompt said.
      face.onPrompt = () {
        lock.movedToBackground();
        clocks.pass(const Duration(minutes: 10));
      };
      face.pass = false;
      await lock.authenticate('why');
      await lock.movedToForeground();
      expect(lock.locked, isTrue);
    });

    test(
      '"Right away" allows a short trip to the camera or share sheet',
      () async {
        final lock = await unlocked();
        await lock.setTimeout(LockTimeout.immediately);
        final camera = Completer<void>();
        final trip = whileInOtherApp(() => camera.future);
        lock.movedToBackground();
        clocks.pass(const Duration(seconds: 40));
        await lock.movedToForeground();
        camera.complete();
        await trip;
        expect(lock.locked, isFalse);

        // A long one still locks.
        final share = Completer<void>();
        final trip2 = whileInOtherApp(() => share.future);
        lock.movedToBackground();
        clocks.pass(const Duration(minutes: 3));
        await lock.movedToForeground();
        share.complete();
        await trip2;
        expect(lock.locked, isTrue);
      },
    );

    test('never locks when off', () async {
      final lock = await open();
      lock.movedToBackground();
      clocks.pass(const Duration(hours: 1));
      await lock.movedToForeground();
      expect(lock.locked, isFalse);
    });
  });

  group('held deep links', () {
    test('run after unlocking; only the latest is kept', () async {
      final lock = await withPin('482915');
      final ran = <String>[];
      lock.runWhenUnlocked(() => ran.add('first'));
      lock.runWhenUnlocked(() => ran.add('medicines'));
      expect(ran, isEmpty);

      await lock.checkPin('000000');
      expect(ran, isEmpty);
      await lock.checkPin('482915');
      expect(ran, ['medicines']);

      lock.runWhenUnlocked(() => ran.add('now'));
      expect(ran, ['medicines', 'now']);
    });
  });

  test('emergency cards on the lock screen: nobody unless chosen', () async {
    final lock = await withPin('482915');
    expect(lock.emergencyOnLockScreen, isFalse);
    await lock.setEmergencyProfile('grandpa', true);
    await lock.setEmergencyProfile('mona', true);
    await lock.setEmergencyProfile('mona', false);
    expect((await open()).emergencyProfiles, {'grandpa'});
  });
}
