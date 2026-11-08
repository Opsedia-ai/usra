import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/database/connection.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/core/security/secure_storage_options.dart';
import 'package:usra/features/account/account_secure_storage.dart';
import 'package:usra/features/account/account_providers.dart';
import 'package:usra/features/account/auth_gateway.dart';
import 'package:usra/features/account/device_identity.dart';
import 'package:usra/features/account/login_config.dart';
import 'package:usra/features/account/supabase_auth_gateway.dart';
import 'package:usra/features/account/supabase_config.dart';
import 'package:usra/features/backup/backup_providers.dart';

import '../support/fake_auth_gateway.dart';
import '../support/spy_secure_storage.dart';

int _closingParen(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '(') depth++;
    if (source[i] == ')' && --depth == 0) return i;
  }
  return source.length;
}

void main() {
  group('sign-in buttons', () {
    const google = LoginConfig(
      googleWebClientId: 'web',
      googleIosClientId: 'ios',
    );

    test('nothing configured: no buttons, also from the environment', () {
      for (final isIos in [true, false]) {
        expect(const LoginConfig().methods(isIos: isIos), isEmpty);
        expect(LoginConfig.fromEnvironment.methods(isIos: isIos), isEmpty);
      }
    });

    test('iOS shows Apple and Google, Apple first', () {
      expect(
        const LoginConfig(
          googleWebClientId: 'web',
          googleIosClientId: 'ios',
          appleEnabled: true,
        ).methods(isIos: true),
        [SignInMethod.apple, SignInMethod.google],
      );
    });

    test('Android shows Google only, and needs no iOS client', () {
      expect(
        const LoginConfig(
          googleWebClientId: 'web',
          appleEnabled: true,
        ).methods(isIos: false),
        [SignInMethod.google],
      );
    });

    test('each button hides when its setup is missing', () {
      expect(const LoginConfig(appleEnabled: true).methods(isIos: true), [
        SignInMethod.apple,
      ]);
      expect(
        const LoginConfig(googleWebClientId: 'web').methods(isIos: true),
        isEmpty,
      );
      expect(
        const LoginConfig(googleIosClientId: 'ios').methods(isIos: true),
        isEmpty,
      );
    });

    test('iOS never shows Google without Apple (guideline 4.8)', () {
      expect(google.methods(isIos: true), isEmpty);
      expect(google.methods(isIos: false), [SignInMethod.google]);
    });
  });

  group('a storage error never touches local records', () {
    const keys = {
      'usra.db.key.v1': 'database key',
      'usra.photos.key.v1': 'photo key',
      'usra.backup.recovery_key.v1': 'recovery key',
      'usra.app_lock.v1': 'lock',
      'usra.account.session.v1': 'session',
    };

    test('Android never reads all keys to check for a reinstall', () async {
      final storage = SpySecureStorage(values: Map.of(keys));
      final prefs = MemoryKeyValueStore();
      await wipeAccountSecretsAfterReinstall(
        prefs,
        storage: storage,
        isIos: false,
      );
      expect(storage.calls, isEmpty);
      expect(prefs.getBool(accountInstalledPref), isTrue);
    });

    test('a failed read on iOS wipes nothing and can be retried', () async {
      final storage = SpySecureStorage(values: Map.of(keys), failReads: true);
      final prefs = MemoryKeyValueStore();
      await expectLater(
        wipeAccountSecretsAfterReinstall(prefs, storage: storage, isIos: true),
        throwsStateError,
      );
      expect(storage.values, keys);
      expect(prefs.getBool(accountInstalledPref), isNull);
    });

    test('an unreadable session goes, and only the session', () async {
      final storage = SpySecureStorage(values: Map.of(keys), failReads: true);
      expect(await SecureSessionStorage(storage).accessToken(), isNull);
      expect(storage.values, {...keys}..remove('usra.account.session.v1'));
      expect(storage.calls, isNot(contains('deleteAll')));
    });

    test('an unreadable database key is never replaced', () async {
      final storage = SpySecureStorage(values: Map.of(keys), failReads: true);
      await expectLater(
        DatabaseKeyStore(storage).readOrCreate(beforeCreating: () {}),
        throwsStateError,
      );
      expect(storage.values, keys);
      expect(storage.calls, ['read']);
    });

    test('every secure storage in the app fails closed on Android', () {
      // The plugin's first caller in the process sets the options for all,
      // so one store left on the default would turn deleting back on.
      expect(secureStorageAndroidOptions.toMap()['resetOnError'], 'false');
      final call = RegExp(r'\bFlutterSecureStorage\(');
      var found = 0;
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        for (final match in call.allMatches(source)) {
          found++;
          final end = _closingParen(source, match.end - 1);
          expect(
            source.substring(match.start, end),
            contains('aOptions: secureStorageAndroidOptions'),
            reason: '${file.path} at offset ${match.start}',
          );
        }
      }
      expect(found, greaterThanOrEqualTo(6));
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

  test('the reinstall marker is in the real preferences allowlist', () {
    // The real store throws on any other key, which would break the account
    // screen on every phone. The in-memory store used in tests doesn't.
    expect(PrefKeys.all, contains(accountInstalledPref));
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
    await wipeAccountSecretsAfterReinstall(
      prefs,
      storage: storage,
      isIos: true,
    );
    expect(await storage.readAll(), {
      'usra.db.key.v1': 'database key',
      'usra.backup.recovery_key.v1': 'recovery key',
    });
    expect(prefs.getBool(accountInstalledPref), isTrue);

    // Same install later: what it saved since is kept.
    await storage.write(key: 'usra.account.session.v1', value: 'new');
    await wipeAccountSecretsAfterReinstall(
      prefs,
      storage: storage,
      isIos: true,
    );
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
      await account.signIn(SignInMethod.google);
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
      gateway.holdRegister = Completer();
      final signingIn = account.signIn(SignInMethod.google);
      await pumpEventQueue();
      expect(c.read(accountProvider).value, isA<AccountSignedIn>());
      expect(gateway.registerCalls, [null]);

      final signingOut = account.signOut();
      await pumpEventQueue();
      expect(ids.keys, isNotEmpty, reason: 'sign-out is still waiting');
      gateway.holdRegister!.complete();
      await (signingIn, signingOut).wait;

      // The row the setup made is revoked and nothing is left behind.
      expect(gateway.revokedDevices, ['device-1']);
      expect(gateway.devices, isEmpty);
      expect(ids.keys, isEmpty);
      expect(ids.devices, isEmpty);
      expect(c.read(accountProvider).value, isA<AccountSignedOut>());
    });

    test('delete waits for the setup still running after sign-in', () async {
      gateway.signedIn = const AccountUser(id: 'u1', email: 'mona@example.com');
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

    test('first sign-in saves the language and registers the phone', () async {
      final c = make();
      c.read(localeProvider.notifier).change(const Locale('en'));
      final account = c.read(accountProvider.notifier);
      await c.read(accountProvider.future);

      await account.signIn(SignInMethod.google);
      expect(gateway.signIns, [SignInMethod.google]);
      final state = c.read(accountProvider).value;
      expect(state, isA<AccountSignedIn>());
      expect((state as AccountSignedIn).user.email, 'mona@example.com');

      expect(gateway.accountUpdates.single, 'en');
      final device = gateway.devices['device-1']!;
      expect(device.platform, 'ios');
      expect(device.appVersion, '1.2.0+7');
      expect(device.key, await ids.publicKey(state.user.id));
      expect(await ids.deviceId(state.user.id), 'device-1');
    });

    test('Apple goes through its own sign-in', () async {
      final c = make();
      final account = c.read(accountProvider.notifier);
      await c.read(accountProvider.future);
      await account.signIn(SignInMethod.apple);
      expect(gateway.signIns, [SignInMethod.apple]);
      expect(c.read(accountProvider).value, isA<AccountSignedIn>());
    });

    test('closing the sheet stays signed out and sets nothing up', () async {
      final c = make();
      final account = c.read(accountProvider.notifier);
      await c.read(accountProvider.future);
      gateway.failSignIn = const AccountException(AccountErrorKind.cancelled);
      await expectLater(
        account.signIn(SignInMethod.google),
        throwsA(
          isA<AccountException>().having(
            (e) => e.kind,
            'kind',
            AccountErrorKind.cancelled,
          ),
        ),
      );
      expect(c.read(accountProvider).value, isA<AccountSignedOut>());
      expect(gateway.devices, isEmpty);
      expect(ids.keys, isEmpty);
    });

    test('a failed sign-in stays signed out; trying again works', () async {
      final c = make();
      final account = c.read(accountProvider.notifier);
      await c.read(accountProvider.future);
      gateway.failSignIn = const AccountException(AccountErrorKind.network);
      await expectLater(
        account.signIn(SignInMethod.apple),
        throwsA(isA<AccountException>()),
      );
      expect(c.read(accountProvider).value, isA<AccountSignedOut>());
      expect(gateway.devices, isEmpty);

      await account.signIn(SignInMethod.apple);
      expect(c.read(accountProvider).value, isA<AccountSignedIn>());
      expect(gateway.devices, hasLength(1));
    });

    test('closing Apple\'s sheet while deleting keeps the account', () async {
      gateway.nextUser = FakeAuthGateway.appleUser;
      final c = make();
      final account = await signedIn(c);
      gateway.failDelete = const AccountException(AccountErrorKind.cancelled);
      await expectLater(
        account.deleteAccount(),
        throwsA(isA<AccountException>()),
      );
      expect(gateway.deleted, 0);
      expect(c.read(accountProvider).value, isA<AccountSignedIn>());
      expect(ids.keys, isNotEmpty);
      expect(ids.devices, isNotEmpty);
    });

    test('signing out revokes the device row and wipes its key; signing in again makes new ones', () async {
      final c = make();
      final account = c.read(accountProvider.notifier);
      await c.read(accountProvider.future);
      await account.signIn(SignInMethod.google);
      const id = 'user-1';
      final firstKey = await ids.publicKey(id);
      await account.signOut();
      expect(c.read(accountProvider).value, isA<AccountSignedOut>());
      expect(gateway.revokedDevices, ['device-1']);
      expect(ids.devices, isEmpty);
      expect(ids.keys, isEmpty);

      await account.signIn(SignInMethod.google);
      expect(gateway.registerCalls, [null, null]);
      expect(await ids.publicKey(id), isNot(firstKey));
    });

    test('offline sign-out still wipes the key on the phone', () async {
      gateway.signedIn = const AccountUser(id: 'u1', email: 'mona@example.com');
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
      await account.signIn(SignInMethod.google);
      await account.signOut();
      gateway.nextUser = const AccountUser(id: 'user-2');
      await account.signIn(SignInMethod.google);
      final keys = gateway.devices.values.map((d) => d.key).toList();
      expect(keys, hasLength(1));
      expect(gateway.registerCalls, [null, null]);
      expect(ids.keys.keys, ['user-2']);
    });

    test('the account language follows the app language', () async {
      gateway.signedIn = const AccountUser(id: 'u1', email: 'mona@example.com');
      await ids.saveDeviceId('u1', 'device-9');
      final c = make();
      await c.read(accountProvider.future);
      c.read(localeProvider.notifier).change(const Locale('en'));
      await pumpEventQueue();
      expect(gateway.accountUpdates, ['en']);
    });

    test('if registering fails the person is still signed in, and it is retried later', () async {
      var c = make();
      final account = c.read(accountProvider.notifier);
      await c.read(accountProvider.future);
      gateway.failSetUp = const AccountException(AccountErrorKind.network);
      await account.signIn(SignInMethod.google);
      expect(c.read(accountProvider).value, isA<AccountSignedIn>());
      expect(gateway.devices, isEmpty);

      // Next app start: the saved session comes back and the phone registers.
      c = make();
      expect(await c.read(accountProvider.future), isA<AccountSignedIn>());
      await pumpEventQueue();
      expect(gateway.devices.keys, ['device-1']);
      expect(await ids.deviceId('user-1'), 'device-1');
    });

    test(
      'a restored session that is already registered does not call the backend',
      () async {
        gateway.signedIn = const AccountUser(
          id: 'u1',
          email: 'mona@example.com',
        );
        await ids.saveDeviceId('u1', 'device-9');
        final c = make();
        expect(await c.read(accountProvider.future), isA<AccountSignedIn>());
        await pumpEventQueue();
        expect(gateway.registerCalls, isEmpty);
        expect(gateway.accountUpdates, isEmpty);
      },
    );

    test('a session ended by the server signs out', () async {
      gateway.signedIn = const AccountUser(id: 'u1', email: 'mona@example.com');
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
      await account.signIn(SignInMethod.google);
      const id = 'user-1';
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
