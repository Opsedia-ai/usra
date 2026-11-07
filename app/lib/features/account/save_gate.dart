import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/routing/app_router.dart';
import 'account_providers.dart';
import 'sign_in_required_screen.dart';

/// Why the sign-in page is asking, for its wording.
enum SaveGateReason { record, backup }

/// Sign-in before the first save, once login is on (`docs/decisions.md`,
/// 7 November). Forms call [allow] at the start of a save for something new,
/// before anything else happens, so a refusal leaves them exactly as they
/// were: the page opens over the form, which stays mounted with what was typed,
/// and signing in carries on with the same save.
///
/// With no cloud configured this says yes at once and never starts the account
/// backend. So does anything that can't be answered, or not soon: this isn't a
/// security check, and a broken check mustn't stop a family saving a record. A
/// session already on the phone counts as signed in, with or without a network.
///
/// Later: seats and the trial or pass check belong here too, in one place.
class SaveGate {
  SaveGate(this._ref);

  final Ref _ref;
  Future<bool>? _asking;

  Future<bool> allow({SaveGateReason reason = SaveGateReason.record}) async {
    if (!_ref.read(supabaseConfigProvider).isConfigured) return true;
    final AccountState account;
    try {
      account = await _ref
          .read(accountProvider.future)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      return true;
    }
    if (account is AccountSignedIn) return true;
    if (_ref.read(signInMethodsProvider).isEmpty) return true;
    final navigator = _ref
        .read(routerProvider)
        .routerDelegate
        .navigatorKey
        .currentState;
    if (navigator == null) return true;
    return _asking ??= _ask(navigator, reason);
  }

  Future<bool> _ask(NavigatorState navigator, SaveGateReason reason) async {
    // If the page is ever taken away without being popped, that's a no, or
    // every later save would wait here for ever.
    final answer = Completer<bool>();
    void answerWith(bool yes) {
      if (answer.isCompleted) return;
      _asking = null;
      answer.complete(yes);
    }

    unawaited(
      navigator
          .push<bool>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => SignInRequiredScreen(
                reason: reason,
                onGone: () => answerWith(false),
              ),
            ),
          )
          .then((signedIn) => answerWith(signedIn ?? false)),
    );
    return answer.future;
  }
}

final saveGateProvider = Provider<SaveGate>(SaveGate.new);

/// The database's own last check, for a save that didn't go through [SaveGate]:
/// a new record is refused while the account is known to be signed out.
/// Watched by the app; does nothing at all with no cloud configured.
final saveGuardProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfigProvider).isConfigured) return;
  final db = ref.watch(databaseProvider);
  db.newRecordGuard = () {
    if (ref.read(accountProvider) case AsyncData(value: AccountSignedOut())) {
      if (ref.read(signInMethodsProvider).isNotEmpty) {
        throw const SignInRequiredException();
      }
    }
  };
  ref.onDispose(() => db.newRecordGuard = null);
});
