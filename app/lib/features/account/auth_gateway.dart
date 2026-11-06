/// The signed-in person, as far as the app needs to know.
class AccountUser {
  const AccountUser({
    required this.id,
    this.email,
    this.confirmsDeleteWithApple = false,
  });

  final String id;

  /// From Google or Apple; with Apple it may be a private relay address.
  /// Shown on the account screen, never logged.
  final String? email;

  /// Deleting this account opens Apple's sheet once more (see
  /// [AuthGateway.deleteAccount]), so the app warns first.
  final bool confirmsDeleteWithApple;

  @override
  bool operator ==(Object other) =>
      other is AccountUser &&
      other.id == id &&
      other.email == email &&
      other.confirmsDeleteWithApple == confirmsDeleteWithApple;

  @override
  int get hashCode => Object.hash(id, email, confirmsDeleteWithApple);
}

/// The ways to sign in.
enum SignInMethod { google, apple }

enum AccountErrorKind {
  /// The person closed Google's or Apple's sheet. Not a failure: nothing is
  /// shown for it.
  cancelled,
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
/// (which may echo the email address).
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

  /// Opens Google's sheet and signs in with what it returns. Throws
  /// [AccountErrorKind.cancelled] if the person closes it.
  Future<AccountUser> signInWithGoogle();

  /// As [signInWithGoogle], with Apple's sheet.
  Future<AccountUser> signInWithApple();

  /// Saves the account's language (`ar`, `en`).
  Future<void> updateAccount({required String locale});

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
  ///
  /// With Sign in with Apple on an iPhone, first opens Apple's sheet: the
  /// fresh code it gives lets the server revoke Apple's tokens, as Apple
  /// requires. Closing the sheet throws [AccountErrorKind.cancelled] and
  /// deletes nothing.
  Future<void> deleteAccount();
}
