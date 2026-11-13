import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/status_dot.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../l10n/app_localizations.dart';
import '../settings/about_privacy_screen.dart';
import 'account_providers.dart';
import 'account_screen.dart';
import 'auth_gateway.dart';
import 'save_gate.dart';
import 'sign_in_buttons.dart';

/// Asks for sign-in before a first save or a backup. Opened by [SaveGate] over
/// the form, which keeps what was typed. Closes with true once signed in.
class SignInRequiredScreen extends ConsumerStatefulWidget {
  const SignInRequiredScreen({
    super.key,
    required this.reason,
    required this.onGone,
  });

  final SaveGateReason reason;

  /// The page was taken away for any reason.
  final VoidCallback onGone;

  @override
  ConsumerState<SignInRequiredScreen> createState() =>
      _SignInRequiredScreenState();
}

class _SignInRequiredScreenState extends ConsumerState<SignInRequiredScreen> {
  var _busy = false;

  /// The error stays on the page, since a person with no network may need to
  /// read it twice. Closing Google's or Apple's sheet shows nothing.
  String? _error;

  @override
  void dispose() {
    widget.onGone();
    super.dispose();
  }

  Future<void> _signIn(SignInMethod method) async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(accountProvider.notifier)
          .signIn(method, waitForSetUp: false);
      if (mounted) Navigator.of(context).pop(true);
      return;
    } on AccountException catch (e) {
      if (e.kind != AccountErrorKind.cancelled) {
        _error = accountErrorText(l, e);
      }
    } catch (e) {
      _error = accountErrorText(l, e);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final methods = ref.watch(signInMethodsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          key: const ValueKey('sign-in-required-back'),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(l.accountGateTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              switch (widget.reason) {
                SaveGateReason.record => l.accountGateBody,
                SaveGateReason.backup => l.accountGateBackupBody,
              },
              key: const ValueKey('sign-in-required-body'),
              style: UsraType.bodyLg.copyWith(color: c.ink),
            ),
            const SizedBox(height: UsraSpacing.s3),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(UsraSpacing.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.accountGateKeepsTitle,
                      style: UsraType.body.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: UsraSpacing.s2),
                    Text(
                      l.accountSignInData,
                      key: const ValueKey('sign-in-required-data'),
                      style: UsraType.body.copyWith(color: c.inkMuted),
                    ),
                    const SizedBox(height: UsraSpacing.s2),
                    Text(
                      l.accountGateRecordsStay,
                      style: UsraType.body.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: UsraSpacing.s3),
              StatusDotText(
                key: const ValueKey('sign-in-required-error'),
                label: error,
                style: UsraType.body,
              ),
            ],
            for (final method in methods) ...[
              const SizedBox(height: UsraSpacing.s3),
              SignInButton(
                method: method,
                onPressed: _busy ? null : () => _signIn(method),
              ),
            ],
            const SizedBox(height: UsraSpacing.s3),
            Text(
              l.accountSignInConsent,
              key: const ValueKey('account-sign-in-consent'),
              style: UsraType.label.copyWith(color: c.inkMuted),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: const ValueKey('account-privacy-link'),
                // On this navigator, not the router's: the page must open
                // above this one, and the form underneath must stay as it is.
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const AboutPrivacyScreen(canDelete: false),
                        ),
                      ),
                child: Text(l.accountReadPrivacy),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
