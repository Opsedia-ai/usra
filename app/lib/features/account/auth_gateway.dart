/// The signed-in person, as far as the app needs to know.
class AccountUser {
  const AccountUser({required this.id, this.phone});

  final String id;

  /// E.164 with a leading `+`.
  final String? phone;

  @override
  bool operator ==(Object other) =>
      other is AccountUser && other.id == id && other.phone == phone;

  @override
  int get hashCode => Object.hash(id, phone);
}

enum AccountErrorKind {
  invalidCode,
  tooManyRequests,
  network,

  /// The session is no longer valid: sign in again.
  sessionExpired,

  /// The account owns a family that has other members, so it can't be
  /// deleted yet (that would delete their shared records too).
  familyHasMembers,
  unknown,
}

/// What went wrong talking to the account backend, without its message
/// (which may echo the phone number).
class AccountException implements Exception {
  const AccountException(this.kind);

  final AccountErrorKind kind;

  @override
  String toString() => 'AccountException(${kind.name})';
}

/// The account backend. [SupabaseAuthGateway] in the app, a fake in tests.
///
/// Only account settings and the device's public key go through here,
/// never health records. Failures throw [AccountException].
abstract class AuthGateway {
  /// Loads any saved session and returns who is signed in, if anyone.
  Future<AccountUser?> restore();

  /// Fires when the session ends or changes outside the app's own calls
  /// (expired, revoked).
  Stream<AccountUser?> get userChanges;

  /// Texts a one-time code to [phone] (E.164).
  Future<void> sendCode(String phone);

  Future<AccountUser> verifyCode(String phone, String code);

  /// Saves the account's country (`EG`, `SA`, `AE`) and language (`ar`, `en`).
  Future<void> updateAccount({required String country, required String locale});

  /// Updates this phone's device row, or adds one if [deviceId] is null or
  /// gone. Returns the row's id.
  Future<String> registerDevice({
    String? deviceId,
    required String platform,
    required String appVersion,
    required List<int> publicKey,
  });

  /// Revokes this phone's device row, before signing out. Revoked is final:
  /// the row stays on the server (it may be listed in a family's log), its
  /// sessions end, and signing in again registers a new device.
  Future<void> revokeDevice(String deviceId);

  /// Ends the session and wipes it from the phone, even offline.
  Future<void> signOut();

  /// Drops this phone's copy of the session at once: no network, nothing
  /// that can time out, and no token refresh can write it back. For
  /// "Delete all my data", whatever the server sign-out did.
  Future<void> forgetLocalSession();

  /// Lets a later sign-in refresh its session again.
  Future<void> resumeSessionRefresh();

  /// Deletes the account and everything the server holds for it, and
  /// wipes the session from the phone. Succeeds if it was already deleted.
  Future<void> deleteAccount();
}
