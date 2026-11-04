import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/features/account/account_secure_storage.dart';
import 'package:usra/features/account/account_providers.dart';
import 'package:usra/features/account/auth_gateway.dart';
import 'package:usra/features/account/device_identity.dart';
import 'package:usra/features/account/phone_number.dart';
import 'package:usra/features/account/supabase_config.dart';
import 'package:usra/features/backup/backup_providers.dart';

import '../support/fake_auth_gateway.dart';

void main() {
  group('phone numbers', () {
    test('Egyptian mobiles in the ways people type them', () {
      const eg = AccountCountry.egypt;
      for (final typed in [
        '01001234567',
        '1001234567',
        '010 0123 4567',
        '+20 100 123 4567',
        '00201001234567',
        '201001234567',
        '٠١٠٠١٢٣٤٥٦٧',
        '۰۱۰۰۱۲۳۴۵۶۷',
      ]) {
        expect(eg.toE164(typed), '+201001234567', reason: typed);
      }
      expect(eg.toE164('01512345678'), '+201512345678');
    });

    test('rejects landlines, short numbers, letters and other countries', () {
      const eg = AccountCountry.egypt;
      for (final typed in [
        '',
        '0223456789',
        '0100123456',
        '010012345678',
        '0100abc4567',
        '+966501234567',
        '01301234567',
      ]) {
        expect(eg.toE164(typed), isNull, reason: typed);
      }
    });

    test('Saudi and UAE mobiles', () {
      expect(AccountCountry.saudiArabia.toE164('0501234567'), '+966501234567');
      expect(
        AccountCountry.saudiArabia.toE164('+966 50 123 4567'),
        '+966501234567',
      );
      expect(AccountCountry.uae.toE164('050 123 4567'), '+971501234567');
      expect(AccountCountry.uae.toE164('0401234567'), isNull);
      expect(AccountCountry.uae.toE164('0531234567'), isNull);
    });

    test('country of a number', () {
      expect(AccountCountry.ofE164('+201001234567'), AccountCountry.egypt);
      expect(AccountCountry.ofE164('966501234567'), AccountCountry.saudiArabia);
      expect(AccountCountry.ofE164('+971501234567'), AccountCountry.uae);
      expect(AccountCountry.ofE164('+14155550100'), isNull);
      expect(AccountCountry.ofE164(null), isNull);
    });
  });

  test('phone numbers are shown masked', () {
    expect(displayPhone('+201001234567'), '\u2066+20 10•••••567\u2069');
    expect(displayPhone('+966501234567'), '\u2066+966 50••••567\u2069');
  });

  test('cloud is configured only with a URL and an anon key', () {
    expect(SupabaseConfig.none.isConfigured, isFalse);
    expect(SupabaseConfig.fromEnvironment.isConfigured, isFalse);
    expect(
      const SupabaseConfig(
        url: 'https://x.supabase.co',
        anonKey: '',
      ).isConfigured,
      isFalse,
    );
    expect(
      const SupabaseConfig(url: 'not a url', anonKey: 'k').isConfigured,
      isFalse,
    );
    // HTTPS only.
    for (final url in ['http://x.supabase.co', 'http://127.0.0.1:54321']) {
      expect(SupabaseConfig(url: url, anonKey: 'k').isConfigured, isFalse);
    }
    expect(
      const SupabaseConfig(
        url: 'https://x.supabase.co',
        anonKey: 'k',
      ).isConfigured,
      isTrue,
    );
  });

  test('after a reinstall, only account secrets are wiped, once', () async {
    FlutterSecureStorage.setMockInitialValues({
      'usra.account.session.v1': 'old session',
      'usra.account.u1.device_key.private.v1': 'old key',
      'usra.account.u1.device_id': 'device-1',
      'usra.db.key.v1': 'database key',
      'usra.backup.recovery_key.v1': 'recovery key',
    });
    const storage = FlutterSecureStorage();
    final prefs = MemoryKeyValueStore();
    await wipeAccountSecretsAfterReinstall(prefs, storage);
    expect(await storage.readAll(), {
      'usra.db.key.v1': 'database key',
      'usra.backup.recovery_key.v1': 'recovery key',
    });
    expect(prefs.getBool(accountInstalledPref), isTrue);

    // Same install later: what it saved since is kept.
    await storage.write(key: 'usra.account.session.v1', value: 'new');
    await wipeAccountSecretsAfterReinstall(prefs, storage);
    expect(await storage.read(key: 'usra.account.session.v1'), 'new');
  });

  group('account controller', () {
    late FakeAuthGateway gateway;
    late MemoryDeviceIdentityStore ids;
    late List<int> reinstallChecks;

    ProviderContainer make({bool configured = true}) {
      final c = ProviderContainer(
        overrides: [
          authGatewayProvider.overrideWithValue(configured ? gateway : null),
          deviceIdentityStoreProvider.overrideWithValue(ids),
          devicePlatformProvider.overrideWithValue('ios'),
          appVersionProvider.overrideWithValue('1.2.0+7'),
          accountReinstallCheckProvider.overrideWithValue(() async {
            reinstallChecks.add(gateway.restores);
          }),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      gateway = FakeAuthGateway();
      ids = MemoryDeviceIdentityStore();
      reinstallChecks = [];
    });

    Future<AccountController> signedIn(ProviderContainer c) async {
      final account = c.read(accountProvider.notifier);
      await c.read(accountProvider.future);
      await account.sendCode(AccountCountry.egypt, '01001234567');
      await account.verifyCode(FakeAuthGateway.validCode);
      return account;
    }

    test('checks for a reinstall before restoring the session', () async {
      final c = make();
      await c.read(accountProvider.future);
      expect(reinstallChecks, [0]);
      expect(gateway.restores, 1);
    });

    test('sign-out waits for the setup still running after sign-in', () async {
      final c = make();
      final account = c.read(accountProvider.notifier);
      await c.read(accountProvider.future);
      await account.sendCode(AccountCountry.egypt, '01001234567');
      gateway.holdRegister = Completer();
      final verifying = account.verifyCode(FakeAuthGateway.validCode);
      await pumpEventQueue();
      expect(c.read(accountProvider).value, isA<AccountSignedIn>());
      expect(gateway.registerCalls, [null]);

      final signingOut = account.signOut();
      await pumpEventQueue();
      expect(ids.keys, isNotEmpty, reason: 'sign-out is still waiting');
      gateway.holdRegister!.complete();
      await (verifying, signingOut).wait;

      // The row the setup made is deleted and nothing is left behind.
      expect(gateway.deletedDevices, ['device-1']);
      expect(gateway.devices, isEmpty);
      expect(ids.keys, isEmpty);
      expect(ids.devices, isEmpty);
      expect(c.read(accountProvider).value, isA<AccountSignedOut>());
    });

    test('delete waits for the setup still running after sign-in', () async {
      gateway.signedIn = const AccountUser(id: 'u1', phone: '+201001234567');
      gateway.holdRegister = Completer();
      final c = make();
      // Restored but not registered yet: setup starts in the background.
      await c.read(accountProvider.future);
      await pumpEventQueue();
      final deleting = c.read(accountProvider.notifier).deleteAccount();
      await pumpEventQueue();
      expect(gateway.deleted, 0);
      gateway.holdRegister!.complete();
      await deleting;
      expect(gateway.deleted, 1);
      expect(ids.keys, isEmpty);
      expect(ids.devices, isEmpty);
    });

    test(
      'delete with a dead session wipes the phone and asks to sign in',
      () async {
        final c = make();
        final account = await signedIn(c);
        gateway.failDelete = const AccountException(
          AccountErrorKind.sessionExpired,
        );
        await expectLater(
          account.deleteAccount(),
          throwsA(
            isA<AccountException>().having(
              (e) => e.kind,
              'kind',
              AccountErrorKind.sessionExpired,
            ),
          ),
        );
        expect(c.read(accountProvider).value, isA<AccountSignedOut>());
        expect(gateway.signedIn, isNull);
        expect(ids.keys, isEmpty);
        expect(ids.devices, isEmpty);
      },
    );

    test('a shared family blocks delete and keeps everything', () async {
      final c = make();
      final account = await signedIn(c);
      gateway.failDelete = const AccountException(
        AccountErrorKind.familyHasMembers,
      );
      await expectLater(
        account.deleteAccount(),
        throwsA(isA<AccountException>()),
      );
      expect(c.read(accountProvider).value, isA<AccountSignedIn>());
      expect(ids.keys, isNotEmpty);
      expect(ids.devices, isNotEmpty);
    });

    test('without a cloud it stays signed out and calls nothing', () async {
      final c = make(configured: false);
      expect(await c.read(accountProvider.future), isA<AccountSignedOut>());
      expect(gateway.restores, 0);
      expect(c.read(authGatewayProvider), isNull);
    });

    test('default config has no gateway, so no network', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(authGatewayProvider), isNull);
    });

    test(
      'first sign-in saves country and language and registers the phone',
      () async {
        final c = make();
        c.read(localeProvider.notifier).change(const Locale('en'));
        final account = c.read(accountProvider.notifier);
        await c.read(accountProvider.future);

        await account.sendCode(AccountCountry.egypt, '0100 123 4567');
        expect(gateway.codesSent, ['+201001234567']);
        expect(c.read(accountProvider).value, isA<AccountCodeSent>());

        await account.verifyCode('١٢٣٤٥٦');
        final state = c.read(accountProvider).value;
        expect(state, isA<AccountSignedIn>());
        expect((state as AccountSignedIn).user.phone, '+201001234567');

        expect(gateway.accountUpdates.single, (country: 'EG', locale: 'en'));
        final device = gateway.devices['device-1']!;
        expect(device.platform, 'ios');
        expect(device.appVersion, '1.2.0+7');
        expect(device.key, await ids.publicKey(state.user.id));
        expect(await ids.deviceId(state.user.id), 'device-1');
      },
    );

    test('signing out removes the device row and wipes its key; signing in again makes new ones', () async {
      final c = make();
      final account = c.read(accountProvider.notifier);
      await c.read(accountProvider.future);
      await account.sendCode(AccountCountry.saudiArabia, '0501234567');
      await account.verifyCode(FakeAuthGateway.validCode);
      expect(gateway.accountUpdates.single.country, 'SA');
      const id = 'user-966501234567';
      final firstKey = await ids.publicKey(id);
      await account.signOut();
      expect(c.read(accountProvider).value, isA<AccountSignedOut>());
      expect(gateway.deletedDevices, ['device-1']);
      expect(ids.devices, isEmpty);
      expect(ids.keys, isEmpty);

      await account.sendCode(AccountCountry.saudiArabia, '0501234567');
      await account.verifyCode(FakeAuthGateway.validCode);
      expect(gateway.registerCalls, [null, null]);
      expect(await ids.publicKey(id), isNot(firstKey));
    });

    test('offline sign-out still wipes the key on the phone', () async {
      gateway.signedIn = const AccountUser(id: 'u1', phone: '+201001234567');
      await ids.saveDeviceId('u1', 'device-9');
      await ids.publicKey('u1');
      final c = make();
      await c.read(accountProvider.future);
      gateway.failSetUp = const AccountException(AccountErrorKind.network);
      await c.read(accountProvider.notifier).signOut();
      expect(c.read(accountProvider).value, isA<AccountSignedOut>());
      expect(ids.keys, isEmpty);
      expect(ids.devices, isEmpty);
    });

    test('two accounts on one phone get different device keys', () async {
      final c = make();
      final account = c.read(accountProvider.notifier);
      await c.read(accountProvider.future);
      await account.sendCode(AccountCountry.egypt, '01001234567');
      await account.verifyCode(FakeAuthGateway.validCode);
      await account.signOut();
      await account.sendCode(AccountCountry.egypt, '01001234568');
      await account.verifyCode(FakeAuthGateway.validCode);
      final keys = gateway.devices.values.map((d) => d.key).toList();
      expect(keys, hasLength(1));
      expect(gateway.registerCalls, [null, null]);
      expect(ids.keys.keys, ['user-201001234568']);
    });

    test('the account language follows the app language', () async {
      gateway.signedIn = const AccountUser(id: 'u1', phone: '+201001234567');
      await ids.saveDeviceId('u1', 'device-9');
      final c = make();
      await c.read(accountProvider.future);
      c.read(localeProvider.notifier).change(const Locale('en'));
      await pumpEventQueue();
      expect(gateway.accountUpdates, [(country: 'EG', locale: 'en')]);
    });

    test('a wrong or short code keeps waiting for the code', () async {
      final c = make();
      final account = c.read(accountProvider.notifier);
      await c.read(accountProvider.future);
      await account.sendCode(AccountCountry.egypt, '01001234567');
      await expectLater(
        account.verifyCode('000000'),
        throwsA(
          isA<AccountException>().having(
            (e) => e.kind,
            'kind',
            AccountErrorKind.invalidCode,
          ),
        ),
      );
      await expectLater(
        account.verifyCode('123'),
        throwsA(isA<AccountException>()),
      );
      expect(c.read(accountProvider).value, isA<AccountCodeSent>());
      expect(gateway.devices, isEmpty);
    });

    test('an invalid number is not sent', () async {
      final c = make();
      await c.read(accountProvider.future);
      await expectLater(
        c.read(accountProvider.notifier).sendCode(AccountCountry.egypt, '123'),
        throwsFormatException,
      );
      expect(gateway.codesSent, isEmpty);
    });

    test('if registering fails the person is still signed in, and it is retried later', () async {
      var c = make();
      final account = c.read(accountProvider.notifier);
      await c.read(accountProvider.future);
      await account.sendCode(AccountCountry.egypt, '01001234567');
      gateway.failSetUp = const AccountException(AccountErrorKind.network);
      await account.verifyCode(FakeAuthGateway.validCode);
      expect(c.read(accountProvider).value, isA<AccountSignedIn>());
      expect(gateway.devices, isEmpty);

      // Next app start: the saved session comes back and the phone registers.
      c = make();
      expect(await c.read(accountProvider.future), isA<AccountSignedIn>());
      await pumpEventQueue();
      expect(gateway.devices.keys, ['device-1']);
      expect(await ids.deviceId('user-201001234567'), 'device-1');
    });

    test(
      'a restored session that is already registered does not call the backend',
      () async {
        gateway.signedIn = const AccountUser(id: 'u1', phone: '+201001234567');
        await ids.saveDeviceId('u1', 'device-9');
        final c = make();
        expect(await c.read(accountProvider.future), isA<AccountSignedIn>());
        await pumpEventQueue();
        expect(gateway.registerCalls, isEmpty);
        expect(gateway.accountUpdates, isEmpty);
      },
    );

    test('a session ended by the server signs out', () async {
      gateway.signedIn = const AccountUser(id: 'u1', phone: '+201001234567');
      await ids.saveDeviceId('u1', 'device-9');
      final c = make();
      await c.read(accountProvider.future);
      gateway.endSession();
      await pumpEventQueue();
      expect(c.read(accountProvider).value, isA<AccountSignedOut>());
    });

    test('deleting the account forgets the device key', () async {
      final c = make();
      final account = c.read(accountProvider.notifier);
      await c.read(accountProvider.future);
      await account.sendCode(AccountCountry.egypt, '01001234567');
      await account.verifyCode(FakeAuthGateway.validCode);
      const id = 'user-201001234567';
      expect(ids.keys, contains(id));

      gateway.failDelete = const AccountException(AccountErrorKind.network);
      await expectLater(
        account.deleteAccount(),
        throwsA(isA<AccountException>()),
      );
      expect(c.read(accountProvider).value, isA<AccountSignedIn>());
      expect(ids.devices, isNotEmpty);

      await account.deleteAccount();
      expect(gateway.deleted, 1);
      expect(c.read(accountProvider).value, isA<AccountSignedOut>());
      expect(ids.devices, isEmpty);
      expect(ids.keys, isEmpty);
    });
  });
}
