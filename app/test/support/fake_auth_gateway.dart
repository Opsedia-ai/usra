import 'dart:async';

import 'package:usra/features/account/auth_gateway.dart';

/// An account backend in memory. Sign-in always works unless told otherwise.
class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.signedIn, this.nextUser = googleUser});

  static const googleUser = AccountUser(
    id: 'user-1',
    email: 'mona@example.com',
  );

  /// Deleting this one asks Apple again.
  static const appleUser = AccountUser(
    id: 'user-1',
    email: 'abc123@privaterelay.appleid.com',
    confirmsDeleteWithApple: true,
  );

  AccountUser? signedIn;

  /// Who signs in next.
  AccountUser nextUser;
  final signIns = <SignInMethod>[];
  final accountUpdates = <String>[];
  final devices =
      <String, ({String platform, String appVersion, List<int> key})>{};
  final registerCalls = <String?>[];
  var deleted = 0;
  var restores = 0;

  /// While set, sign-in / registerDevice wait for it.
  Completer<void>? holdSignIn, holdRegister;

  /// Thrown by the next call of that kind. A closed sheet is
  /// [AccountErrorKind.cancelled].
  AccountException? failSignIn, failSetUp, failDelete;

  final _changes = StreamController<AccountUser?>.broadcast();

  /// The server ended the session (expired or revoked).
  void endSession() {
    signedIn = null;
    _changes.add(null);
  }

  @override
  Future<AccountUser?> restore() async {
    restores++;
    return signedIn;
  }

  @override
  Stream<AccountUser?> get userChanges => _changes.stream;

  Future<AccountUser> _signIn(SignInMethod method) async {
    await holdSignIn?.future;
    if (failSignIn case final e?) {
      failSignIn = null;
      throw e;
    }
    signIns.add(method);
    return signedIn = nextUser;
  }

  @override
  Future<AccountUser> signInWithGoogle() => _signIn(SignInMethod.google);

  @override
  Future<AccountUser> signInWithApple() => _signIn(SignInMethod.apple);

  void _setUpCall() {
    if (signedIn == null) {
      throw const AccountException(AccountErrorKind.unknown);
    }
    if (failSetUp case final e?) {
      failSetUp = null;
      throw e;
    }
  }

  @override
  Future<void> updateAccount({required String locale}) async {
    _setUpCall();
    accountUpdates.add(locale);
  }

  @override
  Future<String> registerDevice({
    String? deviceId,
    required String platform,
    required String appVersion,
    required List<int> publicKey,
  }) async {
    _setUpCall();
    registerCalls.add(deviceId);
    await holdRegister?.future;
    final id = deviceId != null && devices.containsKey(deviceId)
        ? deviceId
        : 'device-${devices.length + 1}';
    devices[id] = (platform: platform, appVersion: appVersion, key: publicKey);
    return id;
  }

  final revokedDevices = <String>[];

  @override
  Future<void> revokeDevice(String deviceId) async {
    _setUpCall();
    revokedDevices.add(deviceId);
    // Revoked is final: the live list drops it and it is never reused.
    devices.remove(deviceId);
  }

  /// While set, signOut waits for it (a slow network).
  Completer<void>? holdSignOut;
  var localForgets = 0;
  var refreshResumed = 0;

  @override
  Future<void> signOut() async {
    await holdSignOut?.future;
    signedIn = null;
  }

  @override
  Future<void> forgetLocalSession() async {
    localForgets++;
    signedIn = null;
  }

  @override
  Future<void> resumeSessionRefresh() async => refreshResumed++;

  @override
  Future<void> deleteAccount() async {
    if (failDelete case final e?) {
      failDelete = null;
      throw e;
    }
    deleted++;
    signedIn = null;
    devices.clear();
  }
}
