import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/backup/recovery_key.dart';
import '../../core/design/list_row.dart' show IconBox;
import '../../core/design/status_dot.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/screen_privacy.dart';
import '../../core/security/sensitive_clipboard.dart';
import '../../l10n/app_localizations.dart';
import 'backup_providers.dart';

/// Shows the recovery key saved on this phone or, if there is none yet,
/// makes one: shows it and asks for it to be written down, then saves it.
/// Pops `true` once a key is saved. No typing it back: the founder found
/// that step too heavy (13 Nov 2026).
class RecoveryKeyScreen extends ConsumerStatefulWidget {
  const RecoveryKeyScreen({super.key, this.random});

  /// For tests: picks the new key.
  final Random? random;

  @override
  ConsumerState<RecoveryKeyScreen> createState() => _RecoveryKeyScreenState();
}

class _RecoveryKeyScreenState extends ConsumerState<RecoveryKeyScreen> {
  late final RecoveryKey _fresh = RecoveryKey.generate(
    widget.random ?? Random.secure(),
  );
  var _saving = false;

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(recoveryKeyStoreProvider).write(_fresh);
      ref.invalidate(savedRecoveryKeyProvider);
      if (mounted) context.pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.saveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final saved = ref.watch(savedRecoveryKeyProvider);
    // The key opens every backup: no screenshots or screen recording.
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(title: Text(l.recoveryKeyTitle)),
        body: saved.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _create(l),
          // While saving, the saved key is the new one; stay on this flow.
          data: (key) => key == null || _saving ? _create(l) : _show(l, key),
        ),
      ),
    );
  }

  Widget _show(AppLocalizations l, RecoveryKey key) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        l.recoveryKeyShowIntro,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 16),
      RecoveryKeyGroups(groups: key.groups),
      const SizedBox(height: 8),
      _CopyKey(recoveryKey: key),
      const SizedBox(height: 16),
      _Warning(text: l.recoveryKeyLoseWarning),
    ],
  );

  Widget _create(AppLocalizations l) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(l.recoveryKeyIntro, style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 16),
      RecoveryKeyGroups(groups: _fresh.groups),
      const SizedBox(height: 8),
      _CopyKey(recoveryKey: _fresh),
      const SizedBox(height: 16),
      _Warning(text: l.recoveryKeyLoseWarning),
      const SizedBox(height: 24),
      FilledButton.icon(
        key: const ValueKey('recovery-key-written'),
        onPressed: _saving ? null : _save,
        icon: const Icon(Icons.arrow_forward),
        label: Text(l.recoveryKeyWrittenDown),
      ),
    ],
  );
}

TextStyle? _digitStyle(TextTheme text) => text.headlineSmall?.copyWith(
  fontFeatures: const [FontFeature.tabularFigures()],
  letterSpacing: 2,
);

/// Copies the key for a password manager. Only through here (the digits
/// aren't selectable): marked sensitive and cleared after a minute (S7).
class _CopyKey extends ConsumerWidget {
  const _CopyKey({required this.recoveryKey});

  final RecoveryKey recoveryKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Align(
      child: TextButton.icon(
        key: const ValueKey('recovery-key-copy'),
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final copied = await ref
              .read(sensitiveClipboardProvider)
              .copy(recoveryKey.groups.join(' '));
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                copied ? l.recoveryKeyCopied : l.recoveryKeyCopyFailed,
              ),
            ),
          );
        },
        icon: const Icon(Icons.copy_outlined),
        label: Text(l.recoveryKeyCopy),
      ),
    );
  }
}

/// The key's six groups, numbered, always left to right like on paper.
class RecoveryKeyGroups extends StatelessWidget {
  const RecoveryKeyGroups({super.key, required this.groups});

  final List<String> groups;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < groups.length; i++)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${i + 1}', style: text.labelLarge),
                    // Not selectable: the system's copy would skip the
                    // sensitive marking and the clearing.
                    Text(
                      groups[i],
                      key: ValueKey('recovery-group-${i + 1}'),
                      style: _digitStyle(text),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Losing the key loses the backup: a white card with a key icon and the
/// quiet amber dot, as the backup notices are since the polish.
class _Warning extends StatelessWidget {
  const _Warning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(UsraSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBox(icon: Icons.key_off_outlined),
          const SizedBox(width: UsraSpacing.s3),
          Expanded(
            child: StatusDotText(
              label: text,
              color: context.usra.ink,
              style: UsraType.body,
            ),
          ),
        ],
      ),
    ),
  );
}
