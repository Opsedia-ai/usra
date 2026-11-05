import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/log.dart';
import '../../core/security/data_wipe.dart';
import '../../l10n/app_localizations.dart';
import '../account/auth_gateway.dart';

/// Shown instead of the app when it couldn't open again after a wipe.
/// Outside the app's providers, so in both languages.
class WipeReopenFailed extends StatelessWidget {
  const WipeReopenFailed({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('wipe-reopen-failed'),
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.restart_alt, size: 48),
        const SizedBox(height: 16),
        for (final code in ['ar', 'en'])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              lookupAppLocalizations(Locale(code)).wipeReopenFailed,
              textAlign: TextAlign.center,
              textDirection: code == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
            ),
          ),
      ],
    ),
  );
}

/// "Delete all my data" while the app runs (S10): signs out, takes the app
/// down, wipes and opens it again as on first run. The steps that touch the
/// database, keys and files are passed in by `main.dart`; this owns the
/// order and makes sure the app always comes back.
class WipeRestart {
  WipeRestart({
    required this.current,
    required this.setCurrent,
    required this.gatewayOf,
    required this.signOut,
    required this.close,
    required this.wipe,
    required this.reopen,
    required this.onReopenFailed,
    this.signOutTimeout = const Duration(seconds: 10),
  });

  /// The running app's providers, or null while it's being swapped.
  final ProviderContainer? Function() current;
  final void Function(ProviderContainer? container) setCurrent;

  /// The account backend, if accounts are on.
  final AuthGateway? Function(ProviderContainer container) gatewayOf;

  /// The normal sign-out (removes this phone's device row). Best effort
  /// and cut off after [signOutTimeout].
  final Future<void> Function(ProviderContainer container) signOut;

  /// Disposes [container] and closes what it used (the database).
  final Future<void> Function(ProviderContainer container) close;

  /// Deletes everything; true when every step worked.
  final Future<bool> Function() wipe;

  /// Opens the app again on new keys and an empty database.
  final Future<void> Function(WipeOutcome outcome) reopen;

  /// Reopening failed: the app can't show anything until it's restarted.
  final void Function() onReopenFailed;
  final Duration signOutTimeout;

  var _running = false;

  Future<void> call() async {
    final old = current();
    if (_running || old == null) return;
    _running = true;
    try {
      final gateway = gatewayOf(old);
      try {
        await signOut(old).timeout(signOutTimeout);
      } catch (e) {
        Log.error('Wipe sign-out failed', e);
      }
      // Whatever the sign-out managed (it may still be waiting on the
      // network): the session is dropped here, and its refresh stopped, so
      // it can't come back in the new app or after a restart.
      await _forget(gateway);
      setCurrent(null);
      try {
        await close(old);
      } catch (e) {
        Log.error('Wipe close failed', e);
      }
      var complete = false;
      try {
        complete = await wipe();
      } catch (e) {
        Log.error('Wipe failed', e);
      }
      // A refresh that was already in flight may have saved it again.
      await _forget(gateway);
      try {
        await gateway?.resumeSessionRefresh();
      } catch (e) {
        Log.error('Wipe refresh resume failed', e);
      }
      try {
        await reopen(complete ? WipeOutcome.done : WipeOutcome.incomplete);
      } catch (e) {
        Log.error('Wipe reopen failed', e);
        onReopenFailed();
      }
    } finally {
      _running = false;
    }
  }

  static Future<void> _forget(AuthGateway? gateway) async {
    try {
      await gateway?.forgetLocalSession();
    } catch (e) {
      Log.error('Wipe session forget failed', e);
    }
  }
}
