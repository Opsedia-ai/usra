import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../core/providers.dart';
import '../../core/security/data_wipe.dart';
import '../../l10n/app_localizations.dart';
import 'backup_providers.dart';
import 'backup_screen.dart';

/// What Home says about backups: how a restore went, that old records
/// couldn't be opened (with a way to restore), and, outside Simple Mode, a
/// reminder when the last backup is missing or over a month old.
class BackupNotices extends ConsumerWidget {
  const BackupNotices({super.key, this.simple = false});

  final bool simple;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final outcome = ref.watch(restoreOutcomeProvider);
    final wipe = ref.watch(wipeOutcomeProvider);
    final last = ref.watch(lastBackupProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (outcome != null)
          _Notice(
            key: const ValueKey('restore-outcome'),
            severity: outcome == RestoreOutcome.restored
                ? Severity.good
                : Severity.actSoon,
            body: outcome == RestoreOutcome.restored
                ? l.restoreDoneNotice
                : l.restoreFailedNotice,
            simple: simple,
          ),
        if (wipe != null)
          _Notice(
            key: const ValueKey('wipe-outcome'),
            severity: wipe == WipeOutcome.done
                ? Severity.good
                : Severity.actSoon,
            body: wipe == WipeOutcome.done
                ? l.wipeDoneNotice
                : l.wipeIncompleteNotice,
            simple: simple,
          ),
        if (ref.watch(databaseRecoveredProvider))
          _Notice(
            key: const ValueKey('recovery-notice'),
            severity: Severity.actSoon,
            body: l.recoveryNotice,
            action: l.restoreTitle,
            onAction: () => context.go(restorePath),
            simple: simple,
          ),
        if (!simple && ref.watch(backupDueProvider))
          _Notice(
            key: const ValueKey('backup-due'),
            severity: Severity.headsUp,
            icon: Icons.backup_outlined,
            title: l.backupDueTitle,
            body: last == null ? l.backupDueNever : l.backupDueOld,
            action: l.backupNow,
            onAction: () => context.go(backupPath),
            simple: simple,
          ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    super.key,
    required this.severity,
    required this.body,
    required this.simple,
    this.icon,
    this.title,
    this.action,
    this.onAction,
  });

  final Severity severity;
  final IconData? icon;
  final String? title;
  final String body;
  final String? action;
  final VoidCallback? onAction;
  final bool simple;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = severity.foreground;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: severity.background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: color),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title!,
                      style: text.titleMedium?.copyWith(color: color),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Text(
              body,
              style: (simple ? text.bodyLarge : text.bodyMedium)?.copyWith(
                color: color,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.tonal(
                  onPressed: onAction,
                  child: Text(action!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
