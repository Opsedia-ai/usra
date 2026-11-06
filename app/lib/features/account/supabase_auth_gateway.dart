import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'account_secure_storage.dart';
import 'auth_gateway.dart';
import 'native_sign_in.dart';
import 'supabase_config.dart';

/// [AuthGateway] on Supabase Auth (ID tokens from the system's Google and
/// Apple sheets), the `accounts` and `devices` tables and the `delete-account`
/// function.
///
/// Supabase starts on the first call, not with the app, so nothing touches
/// the network until someone opens the account screen.
class SupabaseAuthGateway implements AuthGateway {
  /// [client] and [wipeLocal] replace the real Supabase client and the
  /// secure-storage wipe in tests.
  SupabaseAuthGateway(
    this.config,
    this._native, {
    @visibleForTesting Future<sb.SupabaseClient> Function()? client,
    @visibleForTesting Future<void> Function()? wipeLocal,
  }) : _clientOverride = client,
       _wipe = wipeLocal ?? _wipeLocalSession;

  final SupabaseConfig config;
  final NativeSignIn _native;
  final Future<sb.SupabaseClient> Function()? _clientOverride;
  final Future<void> Function() _wipe;

  // One client for the process: the app's provider container is rebuilt
  // after a restore, Supabase is not.
  static Future<sb.SupabaseClient>? _started;

  Future<sb.SupabaseClient> _client() => _clientOverride?.call() ?? _start();

  Future<sb.SupabaseClient> _start() => _started ??=
      sb.Supabase.initialize(
        url: config.url,
        // The anon key goes in the same `apikey` header.
        publishableKey: config.anonKey,
        // Supabase's debug log can include requests; never turn it on.
        debug: false,
        authOptions: const sb.FlutterAuthClientOptions(
          localStorage: SecureSessionStorage(),
          pkceAsyncStorage: SecureAuthItemStorage(),
          // ID tokens only: no redirects or magic links to catch.
          detectSessionInUri: false,
        ),
      ).then((s) => s.client).catchError((Object e) {
        _started = null;
        throw e;
      });

  AccountUser? _user(sb.User? u) => u == null
      ? null
      : AccountUser(
          id: u.id,
          email: u.email == null || u.email!.isEmpty ? null : u.email,
          confirmsDeleteWithApple: _native.appleSupported && _usesApple(u),
        );

  // Linked identities too: Google and Apple with the same email are one user.
  static bool _usesApple(sb.User? u) => switch (u?.appMetadata['providers']) {
    final List<dynamic> providers => providers.contains('apple'),
    _ => u?.appMetadata['provider'] == 'apple',
  };

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
  Future<AccountUser> signInWithGoogle() => _guard(() async {
    final tokens = await _native.google();
    final client = await _client();
    final res = await client.auth.signInWithIdToken(
      provider: sb.OAuthProvider.google,
      idToken: tokens.idToken,
      accessToken: tokens.accessToken,
      nonce: tokens.nonce,
    );
    return _signedIn(res);
  });

  @override
  Future<AccountUser> signInWithApple() => _guard(() async {
    final tokens = await _native.apple();
    final client = await _client();
    final res = await client.auth.signInWithIdToken(
      provider: sb.OAuthProvider.apple,
      idToken: tokens.idToken,
      nonce: tokens.nonce,
    );
    return _signedIn(res);
  });

  AccountUser _signedIn(sb.AuthResponse res) {
    final user = _user(res.user ?? res.session?.user);
    if (user == null) throw const AccountException(AccountErrorKind.unknown);
    return user;
  }

  @override
  Future<void> updateAccount({required String locale}) => _guard(() async {
    final client = await _client();
    final id = client.auth.currentUser?.id;
    if (id == null) throw const AccountException(AccountErrorKind.unknown);
    // The row is made by a trigger when the user is created. Google and Apple
    // don't say where someone lives, so `country` stays empty.
    await client.from('accounts').update({'locale': locale}).eq('id', id);
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
      // A device's key never changes on the server (a new key is a new
      // device row), so only these two columns are sent. The update matches
      // nothing if this session didn't register the row; then it registers
      // a new one.
      final updated = await client
          .from('devices')
          .update({'app_version': appVersion, 'last_seen_at': now})
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
  Future<void> revokeDevice(String deviceId) => _guard(() async {
    final client = await _client();
    await client.rpc('revoke_own_device', params: {'p_device': deviceId});
  });

  @override
  Future<void> signOut() async {
    try {
      final client = await _client();
      await client.auth.signOut();
    } catch (_) {
      // Offline, the server's copy of the session just expires.
    } finally {
      await _wipe();
      await _native.forgetGoogle();
    }
  }

  /// Only touches a client that's already running: one that never started
  /// has no session in memory, and starting it now would use the network.
  Future<sb.SupabaseClient?> _running() async {
    final running = _clientOverride?.call() ?? _started;
    return running == null ? null : await running;
  }

  @override
  Future<void> forgetLocalSession() async {
    try {
      final client = await _running();
      if (client != null) {
        // No refresh may land after this and save the session again.
        client.auth.stopAutoRefresh();
        await client.auth.signOut(scope: sb.SignOutScope.local);
      }
    } catch (_) {
      // The stored copy goes below either way.
    } finally {
      await _wipe();
      // Not awaited: "Delete all my data" must not wait on Google's plugin.
      unawaited(_native.forgetGoogle());
    }
  }

  @override
  Future<void> resumeSessionRefresh() async {
    try {
      (await _running())?.auth.startAutoRefresh();
    } catch (_) {
      // Started again when the app next comes to the front.
    }
  }

  static Future<void> _wipeLocalSession() async {
    await const SecureSessionStorage().removePersistedSession();
    await const SecureAuthItemStorage().clear();
  }

  /// Succeeds also when the account was already deleted (a retry after a
  /// lost response answers `not_found`).
  @override
  Future<void> deleteAccount() => _guard(call: _Call.delete, () async {
    final client = await _client();
    final appleCode =
        _user(client.auth.currentUser)?.confirmsDeleteWithApple == true
        ? await _appleCodeForDelete()
        : null;
    await client.functions.invoke(
      'delete-account',
      body: {'confirm': true, 'apple_authorization_code': ?appleCode},
    );
    try {
      // The server session is gone with the user; drop the local copy.
      await client.auth.signOut(scope: sb.SignOutScope.local);
    } catch (_) {
    } finally {
      await _wipe();
      await _native.forgetGoogle();
    }
  });

  /// Apple's code to revoke with, or null if the sheet failed: deleting must
  /// still work then (Apple says so too, TN3194), only closing it stops it.
  Future<String?> _appleCodeForDelete() async {
    try {
      return (await _native.apple()).authorizationCode;
    } on AccountException catch (e) {
      if (e.kind == AccountErrorKind.cancelled) rethrow;
      return null;
    }
  }

  /// Runs [run], turning failures into [AccountException].
  static Future<T> _guard<T>(
    Future<T> Function() run, {
    _Call call = _Call.other,
  }) async {
    try {
      return await run();
    } on AccountException {
      rethrow;
    } on sb.AuthRetryableFetchException {
      throw const AccountException(AccountErrorKind.network);
    } on sb.AuthException catch (e) {
      throw AccountException(_kind(e.statusCode, e.code, call));
    } on sb.FunctionException catch (e) {
      throw AccountException(_kind('${e.status}', _errorCode(e.details), call));
    } on sb.PostgrestException catch (e) {
      throw AccountException(_kind(null, e.code, call));
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

  // Our functions answer `{ "error": { "code": ... } }`.
  static String? _errorCode(Object? details) => switch (details) {
    {'error': {'code': final String code}} => code,
    _ => null,
  };

  static AccountErrorKind _kind(String? status, String? code, _Call call) {
    if (status == '429' || (code?.startsWith('over_') ?? false)) {
      return AccountErrorKind.tooManyRequests;
    }
    if (call == _Call.delete && code == 'family_has_members') {
      return AccountErrorKind.familyHasMembers;
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

enum _Call { delete, other }

const _secure = accountSecureStorage;

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

  // The keys written, so clear() needn't read the rest of secure storage.
  static const _index = '${_prefix}index';

  Future<Set<String>> _keys() async =>
      (await _secure.read(key: _index))?.split('\n').toSet() ?? {};

  @override
  Future<String?> getItem({required String key}) =>
      _secure.read(key: '$_prefix$key');

  @override
  Future<void> setItem({required String key, required String value}) async {
    await _secure.write(
      key: _index,
      value: ({...await _keys(), key}).join('\n'),
    );
    await _secure.write(key: '$_prefix$key', value: value);
  }

  @override
  Future<void> removeItem({required String key}) =>
      _secure.delete(key: '$_prefix$key');

  Future<void> clear() async {
    for (final key in await _keys()) {
      await _secure.delete(key: '$_prefix$key');
    }
    await _secure.delete(key: _index);
  }
}
