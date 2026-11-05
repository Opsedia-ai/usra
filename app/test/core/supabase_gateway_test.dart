import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:usra/features/account/auth_gateway.dart';
import 'package:usra/features/account/supabase_auth_gateway.dart';
import 'package:usra/features/account/supabase_config.dart';

/// The real gateway on a real Supabase client, with the network replaced:
/// what the app sees for the answers Supabase actually gives.
void main() {
  const config = SupabaseConfig(
    url: 'https://test.supabase.co',
    anonKey: 'anon',
  );

  late List<http.Request> requests;
  late int wipes;

  SupabaseAuthGateway gateway(http.Response Function(http.Request) answer) {
    final client = sb.SupabaseClient(
      config.url,
      config.anonKey,
      httpClient: MockClient((r) async {
        requests.add(r);
        return answer(r);
      }),
      authOptions: const sb.AuthClientOptions(autoRefreshToken: false),
    );
    return SupabaseAuthGateway(
      config,
      client: () async => client,
      wipeLocal: () async => wipes++,
    );
  }

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
  });

  test('a wrong or expired code is reported as a wrong code', () async {
    final g = gateway(
      (_) => jsonAnswer(403, {
        'code': 'otp_expired',
        'msg': 'Token has expired or is invalid',
      }),
    );
    await expectLater(
      g.verifyCode('+201001234567', '000000'),
      kind(AccountErrorKind.invalidCode),
    );
    expect(requests.single.url.path, '/auth/v1/verify');
  });

  test('a 403 when asking for a code is not a wrong code', () async {
    final g = gateway(
      (_) => jsonAnswer(403, {
        'code': 'otp_disabled',
        'msg': 'Signups not allowed',
      }),
    );
    await expectLater(
      g.sendCode('+201001234567'),
      kind(AccountErrorKind.unknown),
    );
  });

  test('too many SMS is rate limited', () async {
    final g = gateway(
      (_) => jsonAnswer(429, {'code': 'over_sms_send_rate_limit', 'msg': '…'}),
    );
    await expectLater(
      g.sendCode('+201001234567'),
      kind(AccountErrorKind.tooManyRequests),
    );
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
