import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/backup/recovery_key.dart';
import '../../core/design/tokens.dart';
import '../../core/screen_privacy.dart';
import '../../l10n/app_localizations.dart';
import 'backup_providers.dart';

/// Shows the recovery key saved on this phone or, if there is none yet,
/// makes one: shows it, asks for it to be written down, then checks two
/// groups typed back before saving it. Pops `true` once a key is saved.
class RecoveryKeyScreen extends ConsumerStatefulWidget {
  const RecoveryKeyScreen({super.key, this.random});

  /// For tests: picks the new key and which groups are asked back.
  final Random? random;

  @override
  ConsumerState<RecoveryKeyScreen> createState() => _RecoveryKeyScreenState();
}

class _RecoveryKeyScreenState extends ConsumerState<RecoveryKeyScreen> {
  late final Random _random = widget.random ?? Random.secure();
  late final RecoveryKey _fresh = RecoveryKey.generate(_random);
  late final List<int> _asked = _pickTwo();
  final _typed = [TextEditingController(), TextEditingController()];
  var _confirming = false;
  var _saving = false;
  String? _error;

  List<int> _pickTwo() {
    final first = _random.nextInt(RecoveryKey.groupCount);
    var second = _random.nextInt(RecoveryKey.groupCount - 1);
    if (second >= first) second++;
    return first < second ? [first, second] : [second, first];
  }

  @override
  void dispose() {
    for (final c in _typed) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _confirm() async {
    final l = AppLocalizations.of(context);
    final wrong = [
      for (var i = 0; i < 2; i++)
        if (RecoveryKey.normalize(_typed[i].text) != _fresh.groups[_asked[i]])
          _asked[i] + 1,
    ];
    if (wrong.isNotEmpty) {
      setState(() => _error = l.recoveryKeyMismatch(wrong.join('، ')));
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
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
          // Once confirming, the saved key is the new one; stay on this flow.
          data: (key) => key == null || _saving || _confirming
              ? _create(l)
              : _show(l, key),
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
      const SizedBox(height: 16),
      _Warning(text: l.recoveryKeyLoseWarning),
    ],
  );

  Widget _create(AppLocalizations l) {
    final text = Theme.of(context).textTheme;
    if (!_confirming) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(l.recoveryKeyIntro, style: text.bodyLarge),
          const SizedBox(height: 16),
          RecoveryKeyGroups(groups: _fresh.groups),
          const SizedBox(height: 16),
          _Warning(text: l.recoveryKeyLoseWarning),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const ValueKey('recovery-key-written'),
            onPressed: () => setState(() => _confirming = true),
            icon: const Icon(Icons.edit_note),
            label: Text(l.recoveryKeyWrittenDown),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(l.recoveryKeyConfirmIntro, style: text.bodyLarge),
        const SizedBox(height: 16),
        for (var i = 0; i < 2; i++) ...[
          TextField(
            key: ValueKey('recovery-confirm-${_asked[i] + 1}'),
            controller: _typed[i],
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            style: _digitStyle(text),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩۰-۹]')),
              LengthLimitingTextInputFormatter(RecoveryKey.groupLength),
            ],
            decoration: InputDecoration(
              labelText: l.recoveryKeyGroupLabel(_asked[i] + 1),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_error != null) ...[
          Text(
            _error!,
            key: const ValueKey('recovery-confirm-error'),
            style: text.bodyMedium?.copyWith(
              color: Severity.actSoon.foreground,
            ),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton(
          key: const ValueKey('recovery-confirm'),
          onPressed: _saving ? null : _confirm,
          child: Text(l.recoveryKeyConfirm),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _saving
              ? null
              : () => setState(() {
                  _confirming = false;
                  _error = null;
                }),
          child: Text(l.recoveryKeyShowAgain),
        ),
      ],
    );
  }
}

TextStyle? _digitStyle(TextTheme text) => text.headlineSmall?.copyWith(
  fontFeatures: const [FontFeature.tabularFigures()],
  letterSpacing: 2,
);

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
                    Text('${i + 1}', style: text.labelMedium),
                    SelectableText(
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

class _Warning extends StatelessWidget {
  const _Warning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Severity.actSoon.background,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.key_off_outlined, color: Severity.actSoon.foreground),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: Severity.actSoon.foreground),
          ),
        ),
      ],
    ),
  );
}
