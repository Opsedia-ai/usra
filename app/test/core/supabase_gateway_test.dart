import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:usra/features/account/auth_gateway.dart';
import 'package:usra/features/account/native_sign_in.dart';
import 'package:usra/features/account/supabase_auth_gateway.dart';
import 'package:usra/features/account/supabase_config.dart';

String _appleToken(String sub) {
  String part(Object value) => base64Url.encode(utf8.encode(jsonEncode(value)));
  return '${part({'alg': 'ES256'})}.${part({'sub': sub})}.signature';
}

/// The system sheets, without the system.
class FakeNativeSignIn implements NativeSignIn {
  @override
  bool appleSupported = true;

  /// Thrown instead of a token, like closing the sheet.
  Object? failure;
  var appleCalls = 0;

  /// The Apple ID the sheet answers for.
  String appleSub = 'apple-sub-1';
  var googleForgets = 0;

  void _check() {
    if (failure case final e?) throw e;
  }

  @override
  Future<GoogleTokens> google() async {
    _check();
    return (idToken: 'google-id', accessToken: 'google-access', nonce: 'raw-g');
  }

  @override
  Future<AppleTokens> apple() async {
    appleCalls++;
    _check();
    return (
      idToken: _appleToken(appleSub),
      nonce: 'raw-a',
      authorizationCode: 'apple-code',
    );
  }

  @override
  Future<void> forgetGoogle() async => googleForgets++;
}

/// The real gateway on a real Supabase client, with the network replaced:
/// what the app sees for the answers Supabase actually gives.
void main() {
  const config = SupabaseConfig(
    url: 'https://test.supabase.co',
    anonKey: 'anon',
  );

  late List<http.Request> requests;
  late int wipes;
  late FakeNativeSignIn native;

  sb.SupabaseClient supabase(http.Response Function(http.Request) answer) =>
      sb.SupabaseClient(
        config.url,
        config.anonKey,
        httpClient: MockClient((r) async {
          requests.add(r);
          return answer(r);
        }),
        authOptions: const sb.AuthClientOptions(autoRefreshToken: false),
      );

  SupabaseAuthGateway gatewayOn(sb.SupabaseClient client) =>
      SupabaseAuthGateway(
        config,
        native,
        client: () async => client,
        wipeLocal: () async => wipes++,
      );

  SupabaseAuthGateway gateway(http.Response Function(http.Request) answer) =>
      gatewayOn(supabase(answer));

  // What Supabase answers a sign-in with; [providers] as in app_metadata.
  Map<String, Object> session(List<String> providers) => {
    'access_token': 'a.b.c',
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'r',
    'user': {
      'id': 'u1',
      'aud': 'authenticated',
      'email': 'mona@example.com',
      'created_at': '2026-11-06T00:00:00Z',
      'app_metadata': {'provider': providers.first, 'providers': providers},
      'identities': [
        for (final provider in providers)
          {
            'id': '$provider-sub-1',
            'user_id': 'u1',
            'identity_id': 'identity-$provider',
            'provider': provider,
            'identity_data': {'sub': '$provider-sub-1'},
          },
      ],
      'user_metadata': <String, Object>{},
    },
  };

  http.Response jsonAnswer(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {
      'content-type': 'application/json',
      'x-supabase-api-version': '2024-01-01',
    },
  );

  Matcher kind(AccountErrorKind k) =>
      throwsA(isA<AccountException>().having((e) => e.kind, 'kind', k));

  setUp(() {
    requests = [];
    wipes = 0;
    native = FakeNativeSignIn();
  });

  test('Google: the sheet\'s tokens and raw nonce go to Supabase', () async {
    final g = gateway((_) => jsonAnswer(200, session(['google'])));
    final user = await g.signInWithGoogle();
    expect(user.id, 'u1');
    expect(user.email, 'mona@example.com');
    expect(user.confirmsDeleteWithApple, isFalse);
    expect(requests.single.url.path, '/auth/v1/token');
    expect(requests.single.url.queryParameters['grant_type'], 'id_token');
    expect(
      jsonDecode(requests.single.body),
      containsPair('provider', 'google'),
    );
    expect(
      jsonDecode(requests.single.body),
      containsPair('id_token', 'google-id'),
    );
    expect(
      jsonDecode(requests.single.body),
      containsPair('access_token', 'google-access'),
    );
    expect(jsonDecode(requests.single.body), containsPair('nonce', 'raw-g'));
  });

  test('Apple: the sheet\'s token and raw nonce go to Supabase', () async {
    final g = gateway((_) => jsonAnswer(200, session(['apple'])));
    final user = await g.signInWithApple();
    expect(user.confirmsDeleteWithApple, isTrue);
    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['provider'], 'apple');
    expect(body['id_token'], _appleToken('apple-sub-1'));
    expect(body['nonce'], 'raw-a');
    // Used only when deleting, never sent to sign in.
    expect(requests.single.body, isNot(contains('apple-code')));
  });

  test('closing a sheet is a cancel and never reaches Supabase', () async {
    native.failure = const AccountException(AccountErrorKind.cancelled);
    final g = gateway((_) => jsonAnswer(200, session(['google'])));
    await expectLater(g.signInWithGoogle(), kind(AccountErrorKind.cancelled));
    await expectLater(g.signInWithApple(), kind(AccountErrorKind.cancelled));
    expect(requests, isEmpty);
  });

  test('a token Supabase refuses is a failed sign-in', () async {
    final g = gateway(
      (_) => jsonAnswer(400, {
        'code': 'validation_failed',
        'msg': 'Bad ID token for mona@example.com',
      }),
    );
    await expectLater(g.signInWithGoogle(), kind(AccountErrorKind.unknown));
  });

  test('too many sign-ins is rate limited', () async {
    final g = gateway(
      (_) => jsonAnswer(429, {'code': 'over_request_rate_limit', 'msg': '…'}),
    );
    await expectLater(
      g.signInWithApple(),
      kind(AccountErrorKind.tooManyRequests),
    );
  });

  group('delete with Sign in with Apple', () {
    // Signed in through the gateway, so the client has a session and user.
    Future<SupabaseAuthGateway> signedIn(
      List<String> providers,
      http.Response Function(http.Request) deleteAnswer,
    ) async {
      final g = gateway(
        (r) => r.url.path == '/auth/v1/token'
            ? jsonAnswer(200, session(providers))
            : deleteAnswer(r),
      );
      await (providers.first == 'apple'
          ? g.signInWithApple()
          : g.signInWithGoogle());
      native.appleCalls = 0;
      requests.clear();
      return g;
    }

    http.Response deleted(http.Request _) =>
        jsonAnswer(200, {'status': 'deleted'});

    Map<String, dynamic> deleteBody() => jsonDecode(
      requests.firstWhere((r) => r.url.path.endsWith('delete-account')).body,
    );

    test('sends a fresh code from Apple for the server to revoke', () async {
      final g = await signedIn(['apple'], deleted);
      await g.deleteAccount();
      expect(native.appleCalls, 1);
      expect(deleteBody(), {
        'confirm': true,
        'apple_authorization_code': 'apple-code',
      });
      expect(wipes, 1);
    });

    test('also when Apple is a linked identity', () async {
      final g = await signedIn(['google', 'apple'], deleted);
      await g.deleteAccount();
      expect(deleteBody()['apple_authorization_code'], 'apple-code');
    });

    test('closing the sheet stops it: nothing is deleted or wiped', () async {
      final g = await signedIn(['apple'], deleted);
      native.failure = const AccountException(AccountErrorKind.cancelled);
      await expectLater(g.deleteAccount(), kind(AccountErrorKind.cancelled));
      expect(requests, isEmpty);
      expect(wipes, 0);
    });

    test('a sheet that fails doesn\'t stop it, with no code to send', () async {
      final g = await signedIn(['apple'], deleted);
      native.failure = const AccountException(AccountErrorKind.unknown);
      await g.deleteAccount();
      expect(deleteBody(), {'confirm': true, 'apple_revoke_skipped': true});
      expect(wipes, 1);
    });

    test(
      'an unexpected error from the sheet doesn\'t stop it either',
      () async {
        final g = await signedIn(['apple'], deleted);
        native.failure = StateError('plugin error');
        await g.deleteAccount();
        expect(deleteBody(), {'confirm': true, 'apple_revoke_skipped': true});
        expect(wipes, 1);
      },
    );

    test('a different Apple ID on the phone is never revoked', () async {
      final g = await signedIn(['apple'], deleted);
      native.appleSub = 'someone-elses-apple-id';
      await g.deleteAccount();
      expect(native.appleCalls, 1);
      expect(deleteBody(), {'confirm': true, 'apple_revoke_skipped': true});
      expect(wipes, 1);
    });

    test('a phone without Apple\'s sheet just deletes', () async {
      final g = await signedIn(['google', 'apple'], deleted);
      native.appleSupported = false;
      await g.deleteAccount();
      expect(native.appleCalls, 0);
      expect(deleteBody(), {'confirm': true});
    });

    test('Google alone never opens Apple\'s sheet', () async {
      final g = await signedIn(['google'], deleted);
      await g.deleteAccount();
      expect(native.appleCalls, 0);
      expect(deleteBody(), {'confirm': true});
    });
  });

  test('signing out forgets the Google account chosen on this phone', () async {
    final g = gateway((r) => http.Response('', 204, request: r));
    await g.signOut();
    expect(native.googleForgets, 1);
    expect(wipes, 1);
    await g.forgetLocalSession();
    expect(native.googleForgets, 2);
    expect(wipes, 2);
  });

  test('delete: done or already gone wipes the session on the phone', () async {
    for (final status in ['deleted', 'not_found']) {
      wipes = 0;
      final g = gateway((_) => jsonAnswer(200, {'status': status}));
      await g.deleteAccount();
      expect(wipes, 1, reason: status);
      final body = jsonDecode(requests.last.body);
      expect(requests.last.url.path, '/functions/v1/delete-account');
      expect(body, {'confirm': true});
    }
  });

  test(
    'delete: a shared family blocks it; a dead session asks to sign in',
    () async {
      var g = gateway(
        (_) => jsonAnswer(409, {
          'error': {'code': 'family_has_members', 'message': '…'},
        }),
      );
      await expectLater(
        g.deleteAccount(),
        kind(AccountErrorKind.familyHasMembers),
      );
      g = gateway(
        (_) => jsonAnswer(401, {
          'error': {'code': 'unauthorized', 'message': '…'},
        }),
      );
      await expectLater(
        g.deleteAccount(),
        kind(AccountErrorKind.sessionExpired),
      );
      expect(wipes, 0);
    },
  );

  test('sign-out revokes the device through the RPC, never a delete', () async {
    // PostgREST answers a void function with 204 and no body.
    final g = gateway((r) => http.Response('', 204, request: r));
    await g.revokeDevice('d0000000-0000-4000-8000-0000000000a1');
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/rest/v1/rpc/revoke_own_device');
    expect(jsonDecode(requests.single.body), {
      'p_device': 'd0000000-0000-4000-8000-0000000000a1',
    });
  });

  test(
    'sign-out wipes the phone even when the server is unreachable',
    () async {
      final g = gateway((_) => throw http.ClientException('offline'));
      await g.signOut();
      expect(wipes, 1);
    },
  );

  test('public keys go to PostgREST as bytea hex', () {
    expect(SupabaseAuthGateway.bytea([0, 1, 171, 255]), r'\x0001abff');
  });
}
