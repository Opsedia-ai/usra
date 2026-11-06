import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/preferences.dart';
import '../../core/providers.dart';
import '../backup/backup_providers.dart' show appVersionProvider;
import 'auth_gateway.dart';
import 'account_secure_storage.dart';
import 'device_identity.dart';
import 'login_config.dart';
import 'native_sign_in.dart';
import 'supabase_auth_gateway.dart';
import 'supabase_config.dart';

/// The cloud project from `--dart-define`; overridden in tests.
final supabaseConfigProvider = Provider<SupabaseConfig>(
  (ref) => SupabaseConfig.fromEnvironment,
);

/// The account backend, or null when no cloud is configured (accounts are
/// then hidden). Overridden in tests with a fake.
final authGatewayProvider = Provider<AuthGateway?>((ref) {
  final config = ref.watch(supabaseConfigProvider);
  if (!config.isConfigured) return null;
  return SupabaseAuthGateway(
    config,
    PluginNativeSignIn(ref.watch(loginConfigProvider)),
  );
});

/// The sign-in client ids from `--dart-define`; overridden in tests.
final loginConfigProvider = Provider<LoginConfig>(
  (ref) => LoginConfig.fromEnvironment,
);

/// The sign-in buttons on this phone, in order.
final signInMethodsProvider = Provider<List<SignInMethod>>(
  (ref) => ref
      .watch(loginConfigProvider)
      .methods(isIos: ref.watch(devicePlatformProvider) == 'ios'),
);

/// Runs before the account backend starts; see
/// [wipeAccountSecretsAfterReinstall]. Overridden in tests.
final accountReinstallCheckProvider = Provider<Future<void> Function()>(
  (ref) =>
      () => wipeAccountSecretsAfterReinstall(ref.read(keyValueStoreProvider)),
);

final deviceIdentityStoreProvider = Provider<DeviceIdentityStore>(
  (ref) => SecureDeviceIdentityStore(),
);

/// `android` or `ios`, as stored in `devices.platform`.
final devicePlatformProvider = Provider<String>(
  (ref) => Platform.isIOS ? 'ios' : 'android',
);

sealed class AccountState {
  const AccountState();
}

class AccountSignedOut extends AccountState {
  const AccountSignedOut();
}

class AccountSignedIn extends AccountState {
  const AccountSignedIn(this.user);

  final AccountUser user;
}

/// The optional account. Only touches the backend once read, i.e. when the
/// account screen opens.
final accountProvider = AsyncNotifierProvider<AccountController, AccountState>(
  AccountController.new,
);

class AccountController extends AsyncNotifier<AccountState> {
  AuthGateway get _gateway {
    final gateway = ref.read(authGatewayProvider);
    if (gateway == null) throw StateError('Accounts are not configured');
    return gateway;
  }

  @override
  Future<AccountState> build() async {
    final gateway = ref.watch(authGatewayProvider);
    if (gateway == null) return const AccountSignedOut();
    await ref.read(accountReinstallCheckProvider)();
    final user = await gateway.restore();
    final changes = gateway.userChanges.listen((changed) {
      if (changed == null && state.value is AccountSignedIn) {
        state = const AsyncData(AccountSignedOut());
      }
    }, onError: (_) {});
    ref.onDispose(changes.cancel);
    // The account's language follows the app's.
    ref.listen(localeProvider, (_, locale) {
      if (state.value is AccountSignedIn) {
        _saveAccount(locale).catchError((_) {});
      }
    });
    if (user == null) return const AccountSignedOut();
    // Signed in before but this phone isn't registered yet (it was offline).
    final ids = ref.read(deviceIdentityStoreProvider);
    if (await ids.deviceId(user.id) == null) unawaited(_startSetUp(user));
    return AccountSignedIn(user);
  }

  /// Opens the [method]'s sheet. Throws [AccountException], with
  /// [AccountErrorKind.cancelled] if the person closes the sheet; either way
  /// they stay signed out.
  Future<void> signIn(SignInMethod method) async {
    final user = await switch (method) {
      SignInMethod.google => _gateway.signInWithGoogle(),
      SignInMethod.apple => _gateway.signInWithApple(),
    };
    state = AsyncData(AccountSignedIn(user));
    await _startSetUp(user);
  }

  /// The setup after sign-in, while it runs. Sign-out and delete wait for
  /// it, so it can't save a key or device id after they wiped them.
  Future<bool>? _setUpRunning;

  Future<bool> _startSetUp(AccountUser user) {
    final running = _setUp(user);
    _setUpRunning = running;
    running.whenComplete(() {
      if (identical(_setUpRunning, running)) _setUpRunning = null;
    });
    return running;
  }

  Future<void> _settle() async => await _setUpRunning;

  /// Saves the account's language and registers this phone
  /// with its public key. Best effort: tried again the next time the
  /// account opens if it didn't get through.
  Future<bool> _setUp(AccountUser user) async {
    try {
      final ids = ref.read(deviceIdentityStoreProvider);
      final (_, (deviceId, publicKey)) = await (
        _saveAccount(ref.read(localeProvider)),
        (ids.deviceId(user.id), ids.publicKey(user.id)).wait,
      ).wait;
      final saved = await _gateway.registerDevice(
        deviceId: deviceId,
        platform: ref.read(devicePlatformProvider),
        appVersion: ref.read(appVersionProvider),
        publicKey: publicKey,
      );
      await ids.saveDeviceId(user.id, saved);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveAccount(Locale locale) =>
      _gateway.updateAccount(locale: locale.languageCode);

  /// Revokes this phone's device row (best effort; approved devices are
  /// never deleted on the server), ends the session and wipes the session and
  /// this account's device key from the phone.
  Future<void> signOut() async {
    await _settle();
    final current = state.value;
    if (current is AccountSignedIn) {
      final ids = ref.read(deviceIdentityStoreProvider);
      try {
        final deviceId = await ids.deviceId(current.user.id);
        if (deviceId != null) await _gateway.revokeDevice(deviceId);
      } catch (_) {
        // Offline: the row stays live, but its private key is wiped below,
        // so nothing wrapped to it can be opened and it can't be bound again.
      }
      await _gateway.signOut();
      await _forget(current.user.id);
    } else {
      await _gateway.signOut();
    }
    state = const AsyncData(AccountSignedOut());
  }

  Future<void> _forget(String userId) async {
    try {
      await ref.read(deviceIdentityStoreProvider).forget(userId);
    } catch (_) {
      // Keychain unavailable: tried again by the next sign-out or delete.
    }
  }

  /// Deletes the account on the server, then wipes this phone's session
  /// and device key. Records on the phone are not touched.
  Future<void> deleteAccount() async {
    await _settle();
    final current = state.value;
    if (current is! AccountSignedIn) return;
    try {
      await _gateway.deleteAccount();
    } on AccountException catch (e) {
      if (e.kind != AccountErrorKind.sessionExpired) rethrow;
      // The server no longer takes this session (revoked, or the account
      // is already gone). It's useless on this phone either way: wipe it
      // and the device key, and ask to sign in again to finish.
      await _gateway.signOut();
      await _forget(current.user.id);
      state = const AsyncData(AccountSignedOut());
      rethrow;
    }
    state = const AsyncData(AccountSignedOut());
    await _forget(current.user.id);
  }
}
