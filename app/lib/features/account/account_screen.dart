import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'account_providers.dart';
import 'auth_gateway.dart';
import 'sign_in_buttons.dart';
import '../settings/about_privacy_screen.dart';

const accountPath = '/settings/account';

String accountErrorText(AppLocalizations l, Object error) => switch (error) {
  AccountException(kind: AccountErrorKind.tooManyRequests) =>
    l.accountErrorTooMany,
  AccountException(kind: AccountErrorKind.network) => l.accountErrorNetwork,
  AccountException(kind: AccountErrorKind.sessionExpired) =>
    l.accountErrorSignInAgain,
  AccountException(kind: AccountErrorKind.familyHasMembers) =>
    l.accountErrorFamilyHasMembers,
  AccountException(kind: AccountErrorKind.unknown) => l.accountErrorGeneric,
  _ => l.accountErrorGeneric,
};

/// The Settings entry; nothing at all when no cloud is configured.
class AccountSettingsTile extends ConsumerWidget {
  const AccountSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(supabaseConfigProvider).isConfigured) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          key: const ValueKey('settings-account'),
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(l.accountTitle),
          subtitle: Text(l.accountSettingsHint),
          onTap: () => context.go(accountPath),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

/// Sign in with Google or Apple, see who is signed in, sign out or delete
/// the account.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final account = ref.watch(accountProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.accountTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _PrivacyNote(),
          const SizedBox(height: 24),
          switch (account) {
            AsyncData(value: AccountSignedOut()) => const _SignInOptions(),
            AsyncData(value: AccountSignedIn(:final user)) => _SignedIn(
              user: user,
            ),
            AsyncError(:final error) => Column(
              children: [
                Text(accountErrorText(l, error), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const ValueKey('account-retry'),
                  onPressed: () => ref.invalidate(accountProvider),
                  child: Text(l.accountRetry),
                ),
              ],
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.phone_android, color: context.usra.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.accountPrivacy,
                key: const ValueKey('account-privacy'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Runs [action] with the button disabled, showing what went wrong.
mixin _Busy<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  var busy = false;

  /// Does nothing while another action runs, so a second tap can't get past
  /// the disabled button. Closing Google's or Apple's sheet shows nothing.
  Future<bool> run(Future<void> Function() action) async {
    if (busy) return false;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => busy = true);
    try {
      await action();
      return true;
    } on AccountException catch (e) {
      if (e.kind != AccountErrorKind.cancelled) {
        messenger.showSnackBar(SnackBar(content: Text(accountErrorText(l, e))));
      }
      return false;
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(accountErrorText(l, e))));
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _SignInOptions extends ConsumerStatefulWidget {
  const _SignInOptions();

  @override
  ConsumerState<_SignInOptions> createState() => _SignInOptionsState();
}

class _SignInOptionsState extends ConsumerState<_SignInOptions>
    with _Busy<_SignInOptions> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final methods = ref.watch(signInMethodsProvider);
    if (methods.isEmpty) {
      return Text(
        l.accountSignInUnavailable,
        key: const ValueKey('account-sign-in-unavailable'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.accountSignInIntro),
        const SizedBox(height: 8),
        Text(
          l.accountSignInConsent,
          key: const ValueKey('account-sign-in-consent'),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const ValueKey('account-privacy-link'),
            onPressed: () => context.push(aboutPath),
            child: Text(l.accountReadPrivacy),
          ),
        ),
        for (final method in methods) ...[
          const SizedBox(height: 16),
          SignInButton(
            method: method,
            onPressed: busy
                ? null
                : () => run(
                    () => ref.read(accountProvider.notifier).signIn(method),
                  ),
          ),
        ],
      ],
    );
  }
}

class _SignedIn extends ConsumerStatefulWidget {
  const _SignedIn({required this.user});

  final AccountUser user;

  @override
  ConsumerState<_SignedIn> createState() => _SignedInState();
}

class _SignedInState extends ConsumerState<_SignedIn> with _Busy<_SignedIn> {
  Future<bool> _confirm(String message, String action) async {
    final l = AppLocalizations.of(context);
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.familyCancel),
          ),
          TextButton(
            key: const ValueKey('account-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  Future<void> _signOut() async {
    final l = AppLocalizations.of(context);
    if (!await _confirm(l.accountSignOutConfirm, l.accountSignOut)) return;
    await run(ref.read(accountProvider.notifier).signOut);
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final message = widget.user.confirmsDeleteWithApple
        ? '${l.accountDeleteConfirm}\n\n${l.accountDeleteAppleNote}'
        : l.accountDeleteConfirm;
    if (!await _confirm(message, l.accountDelete)) return;
    if (await run(ref.read(accountProvider.notifier).deleteAccount)) {
      messenger.showSnackBar(SnackBar(content: Text(l.accountDeleted)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final email = widget.user.email;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.verified_user_outlined),
          title: Text(
            l.accountSignedIn,
            key: const ValueKey('account-signed-in'),
          ),
          subtitle: email == null
              ? null
              // An address reads left to right, also on the Arabic screen.
              : Text(
                  email,
                  key: const ValueKey('account-email'),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.start,
                ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          key: const ValueKey('account-sign-out'),
          onPressed: busy ? null : _signOut,
          child: Text(l.accountSignOut),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const ValueKey('account-delete'),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: busy ? null : _delete,
          child: Text(l.accountDelete),
        ),
      ],
    );
  }
}
