import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'account_providers.dart';
import 'auth_gateway.dart';
import 'phone_number.dart';

const accountPath = '/settings/account';

String accountErrorText(AppLocalizations l, Object error) => switch (error) {
  FormatException() => l.accountPhoneInvalid,
  AccountException(kind: AccountErrorKind.invalidCode) =>
    l.accountErrorInvalidCode,
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

/// Sign in with a phone number and a texted code, see who is signed in,
/// sign out or delete the account.
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
            AsyncData(value: AccountSignedOut()) => const _PhoneForm(),
            AsyncData(value: AccountCodeSent(:final phone)) => _CodeForm(
              phone: phone,
            ),
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
            const Icon(Icons.phone_android, color: UsraColors.primary),
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

  /// Does nothing while another action runs, so a keyboard submit can't
  /// send twice past the disabled button.
  Future<bool> run(Future<void> Function() action) async {
    if (busy) return false;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => busy = true);
    try {
      await action();
      return true;
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(accountErrorText(l, e))));
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _PhoneForm extends ConsumerStatefulWidget {
  const _PhoneForm();

  @override
  ConsumerState<_PhoneForm> createState() => _PhoneFormState();
}

class _PhoneFormState extends ConsumerState<_PhoneForm> with _Busy<_PhoneForm> {
  final _phone = TextEditingController();
  var _country = AccountCountry.egypt;
  var _invalid = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (busy) return;
    if (_country.toE164(_phone.text) == null) {
      setState(() => _invalid = true);
      return;
    }
    setState(() => _invalid = false);
    await run(
      () => ref.read(accountProvider.notifier).sendCode(_country, _phone.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.accountSignInIntro),
        const SizedBox(height: 16),
        SegmentedButton<AccountCountry>(
          key: const ValueKey('account-country'),
          showSelectedIcon: false,
          segments: [
            for (final c in AccountCountry.values)
              ButtonSegment(value: c, label: Text(_countryName(l, c))),
          ],
          selected: {_country},
          onSelectionChanged: (s) => setState(() => _country = s.first),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('account-phone'),
          controller: _phone,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          autofillHints: const [AutofillHints.telephoneNumberNational],
          decoration: InputDecoration(
            labelText: l.accountPhone,
            prefixText: '+${_country.dialCode} ',
            errorText: _invalid ? l.accountPhoneInvalid : null,
          ),
          onSubmitted: (_) => _send(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('account-send-code'),
          onPressed: busy ? null : _send,
          child: Text(l.accountSendCode),
        ),
      ],
    );
  }
}

String _countryName(AppLocalizations l, AccountCountry c) => switch (c) {
  AccountCountry.egypt => l.countryEgypt,
  AccountCountry.saudiArabia => l.countrySaudiArabia,
  AccountCountry.uae => l.countryUae,
};

class _CodeForm extends ConsumerStatefulWidget {
  const _CodeForm({required this.phone});

  final String phone;

  @override
  ConsumerState<_CodeForm> createState() => _CodeFormState();
}

/// How long before another code can be asked for.
const resendWait = Duration(seconds: 60);

class _CodeFormState extends ConsumerState<_CodeForm> with _Busy<_CodeForm> {
  final _code = TextEditingController();
  Timer? _timer;
  var _wait = 0;

  @override
  void initState() {
    super.initState();
    _startWait();
  }

  void _startWait() {
    _timer?.cancel();
    setState(() => _wait = resendWait.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _wait--);
      if (_wait <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() =>
      run(() => ref.read(accountProvider.notifier).verifyCode(_code.text));

  Future<void> _resend() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (await run(ref.read(accountProvider.notifier).resendCode)) {
      if (mounted) _startWait();
      messenger.showSnackBar(SnackBar(content: Text(l.accountCodeResent)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.accountCodeSentTo(displayPhone(widget.phone))),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('account-code'),
          controller: _code,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          autofillHints: const [AutofillHints.oneTimeCode],
          maxLength: 6,
          decoration: InputDecoration(labelText: l.accountCode),
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const ValueKey('account-verify'),
          onPressed: busy ? null : _verify,
          child: Text(l.accountVerify),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const ValueKey('account-resend'),
          onPressed: busy || _wait > 0 ? null : _resend,
          child: Text(_wait > 0 ? l.accountResendIn(_wait) : l.accountResend),
        ),
        TextButton(
          key: const ValueKey('account-change-number'),
          onPressed: busy
              ? null
              : ref.read(accountProvider.notifier).changeNumber,
          child: Text(l.accountChangeNumber),
        ),
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
    if (!await _confirm(l.accountDeleteConfirm, l.accountDelete)) return;
    if (await run(ref.read(accountProvider.notifier).deleteAccount)) {
      messenger.showSnackBar(SnackBar(content: Text(l.accountDeleted)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final phone = widget.user.phone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.verified_user_outlined),
          title: Text(
            phone == null
                ? l.accountSignedIn
                : l.accountSignedInAs(displayPhone(phone)),
            key: const ValueKey('account-signed-in'),
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
