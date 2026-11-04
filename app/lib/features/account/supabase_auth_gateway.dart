import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'auth_gateway.dart';
import 'supabase_config.dart';

/// [AuthGateway] on Supabase Auth (phone OTP), the `accounts` and `devices`
/// tables and the `delete-account` function.
///
/// Supabase starts on the first call, not with the app, so nothing touches
/// the network until someone opens the account screen.
class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this.config);

  final SupabaseConfig config;

  // One client for the process: the app's provider container is rebuilt
  // after a restore, Supabase is not.
  static Future<sb.SupabaseClient>? _started;

  Future<sb.SupabaseClient> _client() => _started ??=
      sb.Supabase.initialize(
        url: config.url,
        // The anon key goes in the same `apikey` header.
        publishableKey: config.anonKey,
        // Supabase's debug log can include requests; never turn it on.
        debug: false,
        authOptions: const sb.FlutterAuthClientOptions(
          localStorage: SecureSessionStorage(),
          pkceAsyncStorage: SecureAuthItemStorage(),
          // Phone codes only: no magic links to catch.
          detectSessionInUri: false,
        ),
      ).then((s) => s.client).catchError((Object e) {
        _started = null;
        throw e;
      });

  static AccountUser? _user(sb.User? u) =>
      u == null ? null : AccountUser(id: u.id, phone: _plus(u.phone));

  // Supabase keeps phone numbers without the `+`.
  static String? _plus(String? phone) => phone == null || phone.isEmpty
      ? null
      : (phone.startsWith('+') ? phone : '+$phone');

  @override
  Future<AccountUser?> restore() => _guard(() async {
    final client = await _client();
    return _user(client.auth.currentUser);
  });

  @override
  Stream<AccountUser?> get userChanges async* {
    final client = await _client();
    yield* client.auth.onAuthStateChange
        .where(
          (s) =>
              s.event == sb.AuthChangeEvent.signedOut ||
              s.event == sb.AuthChangeEvent.userUpdated,
        )
        .map((s) => _user(s.session?.user));
  }

  @override
  Future<void> sendCode(String phone) => _guard(() async {
    final client = await _client();
    await client.auth.signInWithOtp(phone: phone);
  });

  @override
  Future<AccountUser> verifyCode(String phone, String code) => _guard(() async {
    final client = await _client();
    final res = await client.auth.verifyOTP(
      phone: phone,
      token: code,
      type: sb.OtpType.sms,
    );
    final user = _user(res.user ?? res.session?.user);
    if (user == null) {
      throw const AccountException(AccountErrorKind.invalidCode);
    }
    return user;
  });

  @override
  Future<void> updateAccount({
    required String country,
    required String locale,
  }) => _guard(() async {
    final client = await _client();
    final id = client.auth.currentUser?.id;
    if (id == null) throw const AccountException(AccountErrorKind.unknown);
    // The row is made by a trigger when the user is created; the app may
    // only change these two columns.
    await client
        .from('accounts')
        .update({'country': country, 'locale': locale})
        .eq('id', id);
  });

  @override
  Future<String> registerDevice({
    String? deviceId,
    required String platform,
    required String appVersion,
    required List<int> publicKey,
  }) => _guard(() async {
    final client = await _client();
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw const AccountException(AccountErrorKind.unknown);
    final key = _bytea(publicKey);
    final now = DateTime.now().toUtc().toIso8601String();
    if (deviceId != null) {
      final updated = await client
          .from('devices')
          .update({
            'app_version': appVersion,
            'public_key': key,
            'last_seen_at': now,
          })
          .eq('id', deviceId)
          .select('id');
      if (updated.isNotEmpty) return deviceId;
    }
    final row = await client
        .from('devices')
        .insert({
          'user_id': userId,
          'platform': platform,
          'app_version': appVersion,
          'public_key': key,
        })
        .select('id')
        .single();
    return row['id'] as String;
  });

  // PostgREST takes bytea as `\x` and hex.
  static String _bytea(List<int> bytes) =>
      '\\x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

  @override
  Future<void> deleteDevice(String deviceId) => _guard(() async {
    final client = await _client();
    await client.from('devices').delete().eq('id', deviceId);
  });

  @override
  Future<void> signOut() async {
    try {
      final client = await _client();
      await client.auth.signOut();
    } catch (_) {
      // Offline, the server's copy of the session just expires.
    } finally {
      await _wipeLocalSession();
    }
  }

  static Future<void> _wipeLocalSession() async {
    await const SecureSessionStorage().removePersistedSession();
    await const SecureAuthItemStorage().clear();
  }

  @override
  Future<void> deleteAccount() => _guard(() async {
    final client = await _client();
    await client.functions.invoke('delete-account', body: {'confirm': true});
    try {
      // The server session is gone with the user; drop the local copy.
      await client.auth.signOut(scope: sb.SignOutScope.local);
    } catch (_) {
    } finally {
      await _wipeLocalSession();
    }
  });

  /// Runs [call], turning failures into [AccountException]. Only the code
  /// check reads a rejection as a wrong code; elsewhere a 401/403 means the
  /// session is gone.
  static Future<T> _guard<T>(
    Future<T> Function() call, {
    bool verifying = false,
  }) async {
    try {
      return await call();
    } on AccountException {
      rethrow;
    } on sb.AuthRetryableFetchException {
      throw const AccountException(AccountErrorKind.network);
    } on sb.AuthException catch (e) {
      throw AccountException(_kind(e.statusCode, e.code, verifying));
    } on sb.FunctionException catch (e) {
      throw AccountException(_kind('${e.status}', null, verifying));
    } on sb.PostgrestException catch (e) {
      throw AccountException(_kind(null, e.code, verifying));
    } on SocketException {
      throw const AccountException(AccountErrorKind.network);
    } on ClientException {
      throw const AccountException(AccountErrorKind.network);
    } on TimeoutException {
      throw const AccountException(AccountErrorKind.network);
    } catch (_) {
      throw const AccountException(AccountErrorKind.unknown);
    }
  }

  @visibleForTesting
  static AccountErrorKind kindOf(
    String? status,
    String? code,
    bool verifying,
  ) => _kind(status, code, verifying);

  static AccountErrorKind _kind(String? status, String? code, bool verifying) {
    if (status == '429' || (code?.startsWith('over_') ?? false)) {
      return AccountErrorKind.tooManyRequests;
    }
    if (verifying &&
        (code == 'otp_expired' ||
            code == 'invalid_credentials' ||
            status == '403' ||
            status == '401')) {
      return AccountErrorKind.invalidCode;
    }
    if (status == '401' ||
        code == 'session_not_found' ||
        code == 'bad_jwt' ||
        code == 'PGRST301' ||
        code == 'PGRST303') {
      return AccountErrorKind.sessionExpired;
    }
    return AccountErrorKind.unknown;
  }

  @visibleForTesting
  static String bytea(List<int> bytes) => _bytea(bytes);
}

const _secure = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
  ),
);

/// Keeps the Supabase session (with its refresh token) in Android Keystore /
/// iOS Keychain, this device only, instead of shared preferences.
class SecureSessionStorage extends sb.LocalStorage {
  const SecureSessionStorage();

  static const _key = 'usra.account.session.v1';
  static const _storage = _secure;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: _key);

  @override
  Future<String?> accessToken() => _storage.read(key: _key);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _key, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _key);
}

/// Supabase Auth's other small items (PKCE verifiers), also kept out of
/// shared preferences.
class SecureAuthItemStorage extends sb.GotrueAsyncStorage {
  const SecureAuthItemStorage();

  static const _prefix = 'usra.account.auth.';

  @override
  Future<String?> getItem({required String key}) =>
      _secure.read(key: '$_prefix$key');

  @override
  Future<void> setItem({required String key, required String value}) =>
      _secure.write(key: '$_prefix$key', value: value);

  @override
  Future<void> removeItem({required String key}) =>
      _secure.delete(key: '$_prefix$key');

  Future<void> clear() async {
    final all = await _secure.readAll();
    for (final key in all.keys.where((k) => k.startsWith(_prefix))) {
      await _secure.delete(key: key);
    }
  }
}
