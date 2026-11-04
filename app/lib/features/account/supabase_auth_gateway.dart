import 'dart:async';
import 'dart:io' show SocketException;

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
        authOptions: const sb.FlutterAuthClientOptions(
          localStorage: SecureSessionStorage(),
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
  Future<void> signOut() async {
    final client = await _client();
    try {
      await client.auth.signOut();
    } catch (_) {
      // The local session is removed before the server is told; offline,
      // the server's copy just expires.
    }
  }

  @override
  Future<void> deleteAccount() => _guard(() async {
    final client = await _client();
    await client.functions.invoke('delete-account', body: {'confirm': true});
    try {
      // The server session is gone with the user; drop the local copy.
      await client.auth.signOut(scope: sb.SignOutScope.local);
    } catch (_) {}
  });

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on AccountException {
      rethrow;
    } on sb.AuthRetryableFetchException {
      throw const AccountException(AccountErrorKind.network);
    } on sb.AuthException catch (e) {
      throw AccountException(_kind(e.statusCode, e.code));
    } on sb.FunctionException catch (e) {
      throw AccountException(_kind('${e.status}', null));
    } on sb.PostgrestException catch (e) {
      throw AccountException(_kind(e.code, null));
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

  static AccountErrorKind _kind(String? status, String? code) {
    if (status == '429' || (code?.startsWith('over_') ?? false)) {
      return AccountErrorKind.tooManyRequests;
    }
    if (code == 'otp_expired' ||
        code == 'invalid_credentials' ||
        status == '403') {
      return AccountErrorKind.invalidCode;
    }
    return AccountErrorKind.unknown;
  }
}

/// Keeps the Supabase session in Android Keystore / iOS Keychain instead of
/// shared preferences.
class SecureSessionStorage extends sb.LocalStorage {
  const SecureSessionStorage();

  static const _key = 'usra.account.session.v1';
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

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
