import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/providers.dart';
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
    });

    test('country of a number', () {
      expect(AccountCountry.ofE164('+201001234567'), AccountCountry.egypt);
      expect(AccountCountry.ofE164('966501234567'), AccountCountry.saudiArabia);
      expect(AccountCountry.ofE164('+971501234567'), AccountCountry.uae);
      expect(AccountCountry.ofE164('+14155550100'), isNull);
      expect(AccountCountry.ofE164(null), isNull);
    });
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
    expect(
      const SupabaseConfig(
        url: 'https://x.supabase.co',
        anonKey: 'k',
      ).isConfigured,
      isTrue,
    );
  });

  group('account controller', () {
    late FakeAuthGateway gateway;
    late MemoryDeviceIdentityStore ids;

    ProviderContainer make({bool configured = true}) {
      final c = ProviderContainer(
        overrides: [
          authGatewayProvider.overrideWithValue(configured ? gateway : null),
          deviceIdentityStoreProvider.overrideWithValue(ids),
          devicePlatformProvider.overrideWithValue('ios'),
          appVersionProvider.overrideWithValue('1.2.0+7'),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      gateway = FakeAuthGateway();
      ids = MemoryDeviceIdentityStore();
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
        expect(device.key, await ids.publicKey());
        expect(await ids.deviceId(state.user.id), 'device-1');
      },
    );

    test('signing in again on the same phone updates its device row', () async {
      final c = make();
      final account = c.read(accountProvider.notifier);
      await c.read(accountProvider.future);
      await account.sendCode(AccountCountry.saudiArabia, '0501234567');
      await account.verifyCode(FakeAuthGateway.validCode);
      expect(gateway.accountUpdates.single.country, 'SA');
      await account.signOut();
      expect(c.read(accountProvider).value, isA<AccountSignedOut>());

      await account.sendCode(AccountCountry.saudiArabia, '0501234567');
      await account.verifyCode(FakeAuthGateway.validCode);
      expect(gateway.registerCalls, [null, 'device-1']);
      expect(gateway.devices.keys, ['device-1']);
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
      final oldKey = await ids.publicKey();

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
      expect(await ids.publicKey(), isNot(oldKey));
    });
  });
}
