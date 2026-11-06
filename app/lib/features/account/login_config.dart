import 'auth_gateway.dart';

/// Which sign-in buttons this build can offer, from `--dart-define`. These
/// are client ids, not secrets, but they stay out of the repo so that a build
/// without them simply has no button. See docs/login-setup.md.
class LoginConfig {
  const LoginConfig({
    this.googleWebClientId = '',
    this.googleIosClientId = '',
    this.appleEnabled = false,
  });

  static const fromEnvironment = LoginConfig(
    googleWebClientId: String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
    googleIosClientId: String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
    appleEnabled: bool.fromEnvironment('SIGN_IN_WITH_APPLE'),
  );

  /// The audience of Google's ID token, on both platforms.
  final String googleWebClientId;

  /// iOS only; Android finds its client from the package name and signature.
  final String googleIosClientId;

  /// Sign in with Apple has no client id on iOS: the app's bundle id is it.
  final bool appleEnabled;

  /// The buttons to show, in order. Apple is iOS only: on Android it would
  /// need a web redirect through a server of ours, for no store requirement.
  List<SignInMethod> methods({required bool isIos}) => [
    if (isIos && appleEnabled) SignInMethod.apple,
    if (googleWebClientId.isNotEmpty &&
        (!isIos || googleIosClientId.isNotEmpty))
      SignInMethod.google,
  ];
}
