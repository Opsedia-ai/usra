import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/status_dot.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/security/app_lock.dart';
import '../../core/security/data_wipe.dart';
import '../../l10n/app_localizations.dart';
import '../app_lock/app_lock_module.dart';
import '../backup/backup_screen.dart';

/// Where "Delete all my data" lives.
const deleteDataPath = '/settings/delete-all';

/// "Delete all my data" (security plan S10): says what goes and what
/// stays, then asks for a typed word, and the PIN (or fingerprint / face)
/// too when the app lock is on, so it can't happen by a slip or from a
/// phone left unlocked for a moment.
class DeleteDataScreen extends ConsumerStatefulWidget {
  const DeleteDataScreen({super.key, this.startFresh = false});

  /// Reached from the screen for records that can't be reached: says so, and
  /// has no "make a backup first", since no backup can be made from here.
  final bool startFresh;

  @override
  ConsumerState<DeleteDataScreen> createState() => _DeleteDataScreenState();
}

class _DeleteDataScreenState extends ConsumerState<DeleteDataScreen> {
  final _typed = TextEditingController();
  var _working = false;

  @override
  void initState() {
    super.initState();
    _typed.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  /// The word in either language, any case, spaces around it ignored.
  bool _confirmed(AppLocalizations l) {
    final typed = _typed.text.trim().toLowerCase();
    return typed.isNotEmpty &&
        {
          l.wipeConfirmWord.toLowerCase(),
          lookupAppLocalizations(const Locale('en')).wipeConfirmWord
              .toLowerCase(),
          lookupAppLocalizations(const Locale('ar')).wipeConfirmWord,
        }.contains(typed);
  }

  Future<void> _wipe() async {
    if (ref.read(appLockProvider).enabled && !await confirmItsYou(context)) {
      return;
    }
    if (!mounted) return;
    setState(() => _working = true);
    // Replaces the whole app; this screen normally goes with it.
    try {
      await ref.read(wipeAndRestartProvider)();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.startFresh ? l.databaseStartFresh : l.wipeTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.startFresh) ...[
            Text(
              l.databaseStartFreshIntro,
              key: const ValueKey('start-fresh-intro'),
              style: text.bodyLarge,
            ),
            const SizedBox(height: 12),
          ],
          Text(l.wipeIntro, style: text.bodyLarge),
          const SizedBox(height: 12),
          // One row per line, with the bullet set apart: a "•" typed into
          // the sentence ran into the Arabic word after it.
          for (final item in l.wipeList.split('\n'))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(child: Text('•', style: text.bodyLarge)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.replaceFirst(RegExp(r'^\s*•\s*'), ''),
                      style: text.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text(l.wipeKeeps, style: text.bodyMedium),
          const SizedBox(height: 16),
          Card(
            key: const ValueKey('wipe-no-undo'),
            child: Padding(
              padding: const EdgeInsets.all(UsraSpacing.s4),
              child: StatusDotText(
                label: l.wipeNoUndo,
                color: context.usra.ink,
                style: UsraType.body,
              ),
            ),
          ),
          if (!widget.startFresh) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('wipe-backup-first'),
                onPressed: _working ? null : () => context.go(backupPath),
                icon: const Icon(Icons.backup_outlined),
                label: Text(l.wipeBackupFirst),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('wipe-confirm-word'),
            controller: _typed,
            enabled: !_working,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l.wipeTypeLabel(l.wipeConfirmWord),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('wipe-confirm'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
            onPressed: _working || !_confirmed(l) ? null : _wipe,
            icon: _working
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_forever_outlined),
            label: Text(_working ? l.wipeWorking : l.wipeButton),
          ),
        ],
      ),
    );
  }
}
