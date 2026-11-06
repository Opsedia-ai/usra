import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/security/app_lock.dart' show whileInOtherApp;
import 'auth_gateway.dart';
import 'login_config.dart';

/// What Google's sheet gave us. [nonce] is the raw value whose hash is in
/// [idToken].
typedef GoogleTokens = ({String idToken, String? accessToken, String nonce});

/// What Apple's sheet gave us. [nonce] is as above; [authorizationCode] is
/// used once, to revoke Apple's tokens when the account is deleted.
typedef AppleTokens = ({
  String idToken,
  String nonce,
  String authorizationCode,
});

/// The system sign-in sheets, with no web redirect. Throws [AccountException]:
/// [AccountErrorKind.cancelled] when the person closes the sheet, otherwise
/// [AccountErrorKind.unknown]. The plugins' messages are never kept, as they
/// may name the account.
abstract class NativeSignIn {
  /// Whether this phone has Apple's sheet at all.
  bool get appleSupported;

  Future<GoogleTokens> google();

  Future<AppleTokens> apple();

  /// Forgets the Google account chosen on this phone, so the next sign-in
  /// asks again. Local only, never throws.
  Future<void> forgetGoogle();
}

/// [NativeSignIn] on `google_sign_in` and `sign_in_with_apple`.
class PluginNativeSignIn implements NativeSignIn {
  const PluginNativeSignIn(this.config);

  final LoginConfig config;

  // GoogleSignIn takes its settings, nonce included, once per process, so the
  // nonce lasts as long as the process rather than one sign-in.
  static Future<void>? _googleReady;
  static String? _googleNonce;

  static const _googleScopes = ['email', 'profile'];

  bool get _googleConfigured =>
      config.methods(isIos: Platform.isIOS).contains(SignInMethod.google);

  Future<String> _startGoogle() async {
    final raw = _googleNonce ??= _rawNonce();
    await (_googleReady ??= _initializeGoogle(raw).catchError((Object e) {
      _googleReady = null;
      throw e;
    }));
    return raw;
  }

  Future<void> _initializeGoogle(String rawNonce) async =>
      GoogleSignIn.instance.initialize(
        clientId: Platform.isIOS ? config.googleIosClientId : null,
        serverClientId: config.googleWebClientId,
        nonce: await _sha256Hex(rawNonce),
      );

  @override
  bool get appleSupported => Platform.isIOS;

  @override
  Future<GoogleTokens> google() async {
    try {
      final nonce = await _startGoogle();
      // Some phones pause the app for the sheet: don't lock it behind it.
      final account = await whileInOtherApp(
        () => GoogleSignIn.instance.authenticate(scopeHint: _googleScopes),
      );
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AccountException(AccountErrorKind.unknown);
      }
      return (
        idToken: idToken,
        accessToken: await _googleAccessToken(account),
        nonce: nonce,
      );
    } on GoogleSignInException catch (e) {
      throw AccountException(switch (e.code) {
        GoogleSignInExceptionCode.canceled ||
        GoogleSignInExceptionCode.interrupted => AccountErrorKind.cancelled,
        _ => AccountErrorKind.unknown,
      });
    }
  }

  /// iOS ID tokens carry a hash of the access token, which Supabase checks when
  /// it's there. Android's don't, and may have no token without asking again.
  /// So a failure here doesn't end the sign-in: Supabase decides.
  Future<String?> _googleAccessToken(GoogleSignInAccount account) async {
    try {
      final authorization = await account.authorizationClient
          .authorizationForScopes(_googleScopes);
      return authorization?.accessToken;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppleTokens> apple() async {
    final nonce = _rawNonce();
    try {
      final hashed = await _sha256Hex(nonce);
      final credential = await whileInOtherApp(
        () => SignInWithApple.getAppleIDCredential(
          // Email only: the app has no use for a name, and Apple never puts
          // it in the ID token.
          scopes: const [AppleIDAuthorizationScopes.email],
          nonce: hashed,
        ),
      );
      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const AccountException(AccountErrorKind.unknown);
      }
      return (
        idToken: idToken,
        nonce: nonce,
        authorizationCode: credential.authorizationCode,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      throw AccountException(switch (e.code) {
        AuthorizationErrorCode.canceled => AccountErrorKind.cancelled,
        _ => AccountErrorKind.unknown,
      });
    }
  }

  @override
  Future<void> forgetGoogle() async {
    if (!_googleConfigured) return;
    try {
      await _startGoogle();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // It only decides whether the next sign-in asks which account.
    }
  }

  static String _rawNonce() {
    final random = Random.secure();
    return base64UrlEncode([for (var i = 0; i < 32; i++) random.nextInt(256)]);
  }

  static Future<String> _sha256Hex(String value) async {
    final hash = await Sha256().hash(utf8.encode(value));
    return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
