import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../backup/backup_providers.dart' show appVersionProvider;
import 'auth_gateway.dart';
import 'device_identity.dart';
import 'phone_number.dart';
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
  return config.isConfigured ? SupabaseAuthGateway(config) : null;
});

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

/// A code was texted to [phone] (E.164) and is waiting to be typed.
class AccountCodeSent extends AccountState {
  const AccountCodeSent(this.phone);

  final String phone;
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
    final user = await gateway.restore();
    final changes = gateway.userChanges.listen((changed) {
      if (changed == null && state.value is AccountSignedIn) {
        state = const AsyncData(AccountSignedOut());
      }
    }, onError: (_) {});
    ref.onDispose(changes.cancel);
    // The account's language follows the app's.
    ref.listen(localeProvider, (_, locale) {
      if (state.value case AccountSignedIn(:final user)) {
        _saveAccount(user, locale).catchError((_) {});
      }
    });
    if (user == null) return const AccountSignedOut();
    // Signed in before but this phone isn't registered yet (it was offline).
    final ids = ref.read(deviceIdentityStoreProvider);
    if (await ids.deviceId(user.id) == null) unawaited(_setUp(user));
    return AccountSignedIn(user);
  }

  /// Texts a code to the number typed for [country]. Throws
  /// [FormatException] if it isn't a mobile number there.
  Future<void> sendCode(AccountCountry country, String typed) async {
    final phone = country.toE164(typed);
    if (phone == null) throw const FormatException('Not a mobile number');
    await _gateway.sendCode(phone);
    state = AsyncData(AccountCodeSent(phone));
  }

  Future<void> resendCode() async {
    final current = state.value;
    if (current is AccountCodeSent) await _gateway.sendCode(current.phone);
  }

  /// Back to typing the number.
  void changeNumber() => state = const AsyncData(AccountSignedOut());

  Future<void> verifyCode(String typed) async {
    final current = state.value;
    if (current is! AccountCodeSent) return;
    final code = asciiDigits(typed) ?? '';
    if (code.length != 6) {
      throw const AccountException(AccountErrorKind.invalidCode);
    }
    final user = await _gateway.verifyCode(current.phone, code);
    state = AsyncData(AccountSignedIn(user));
    await _setUp(user);
  }

  /// Saves the account's country and language and registers this phone
  /// with its public key. Best effort: tried again the next time the
  /// account opens if it didn't get through.
  Future<bool> _setUp(AccountUser user) async {
    try {
      final ids = ref.read(deviceIdentityStoreProvider);
      final (_, (deviceId, publicKey)) = await (
        _saveAccount(user, ref.read(localeProvider)),
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

  Future<void> _saveAccount(AccountUser user, Locale locale) async {
    final country = AccountCountry.ofE164(user.phone);
    if (country == null) return;
    await _gateway.updateAccount(
      country: country.code,
      locale: locale.languageCode,
    );
  }

  /// Removes this phone's device row (best effort), ends the session and
  /// wipes the session and this account's device key from the phone.
  Future<void> signOut() async {
    final current = state.value;
    if (current is AccountSignedIn) {
      final ids = ref.read(deviceIdentityStoreProvider);
      try {
        final deviceId = await ids.deviceId(current.user.id);
        if (deviceId != null) await _gateway.deleteDevice(deviceId);
      } catch (_) {
        // Offline: the row stays, but its private key is wiped below, so
        // nothing wrapped to it can be opened.
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
    final current = state.value;
    if (current is! AccountSignedIn) return;
    await _gateway.deleteAccount();
    state = const AsyncData(AccountSignedOut());
    await _forget(current.user.id);
  }
}
