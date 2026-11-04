import 'dart:async';

import 'package:usra/features/account/auth_gateway.dart';

/// An account backend in memory. The right code is always [validCode].
class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.signedIn});

  static const validCode = '123456';

  AccountUser? signedIn;
  final codesSent = <String>[];
  final accountUpdates = <({String country, String locale})>[];
  final devices =
      <String, ({String platform, String appVersion, List<int> key})>{};
  final registerCalls = <String?>[];
  var deleted = 0;
  var restores = 0;

  /// Thrown by the next call of that kind.
  AccountException? failSend, failVerify, failSetUp, failDelete;

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

  @override
  Future<void> sendCode(String phone) async {
    if (failSend case final e?) {
      failSend = null;
      throw e;
    }
    codesSent.add(phone);
  }

  @override
  Future<AccountUser> verifyCode(String phone, String code) async {
    if (failVerify case final e?) {
      failVerify = null;
      throw e;
    }
    if (code != validCode || !codesSent.contains(phone)) {
      throw const AccountException(AccountErrorKind.invalidCode);
    }
    return signedIn = AccountUser(
      id: 'user-${phone.substring(1)}',
      phone: phone,
    );
  }

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
  Future<void> updateAccount({
    required String country,
    required String locale,
  }) async {
    _setUpCall();
    accountUpdates.add((country: country, locale: locale));
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
    final id = deviceId != null && devices.containsKey(deviceId)
        ? deviceId
        : 'device-${devices.length + 1}';
    devices[id] = (platform: platform, appVersion: appVersion, key: publicKey);
    return id;
  }

  final deletedDevices = <String>[];

  @override
  Future<void> deleteDevice(String deviceId) async {
    _setUpCall();
    deletedDevices.add(deviceId);
    devices.remove(deviceId);
  }

  @override
  Future<void> signOut() async => signedIn = null;

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
