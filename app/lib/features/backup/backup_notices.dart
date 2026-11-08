import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../core/providers.dart';
import '../../core/security/data_wipe.dart';
import '../../l10n/app_localizations.dart';
import '../../core/backup/auto_backup.dart';
import 'auto_backup_section.dart';
import 'backup_providers.dart';
import 'backup_screen.dart';

/// What Home says about backups: how a restore went, that old records
/// couldn't be opened (with a way to restore), that an automatic backup is
/// running or didn't finish (with a way to retry), and, outside Simple Mode,
/// a reminder when the last backup is missing or over a month old.
class BackupNotices extends ConsumerWidget {
  const BackupNotices({
    super.key,
    this.simple = false,
    this.outcomesOnly = false,
  });

  /// Only how a restore or a wipe went, for Welcome, which shows after both
  /// when there's no family yet.
  final bool outcomesOnly;

  final bool simple;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final outcome = ref.watch(restoreOutcomeProvider);
    final wipe = ref.watch(wipeOutcomeProvider);
    final last = ref.watch(lastBackupProvider);
    final auto = ref.watch(autoBackupProvider);
    final failure = autoBackupNoticeFailure(auto);
    final outcomes = [
      if (outcome != null)
        BackupNotice(
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
        BackupNotice(
          key: const ValueKey('wipe-outcome'),
          severity: wipe == WipeOutcome.done ? Severity.good : Severity.actSoon,
          body: wipe == WipeOutcome.done
              ? l.wipeDoneNotice
              : l.wipeIncompleteNotice,
          simple: simple,
        ),
    ];
    if (outcomesOnly) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: outcomes,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...outcomes,
        if (ref.watch(databaseRecoveredProvider))
          BackupNotice(
            key: const ValueKey('recovery-notice'),
            severity: Severity.actSoon,
            body: l.recoveryNotice,
            action: l.restoreTitle,
            onAction: () => context.go(restorePath),
            simple: simple,
          ),
        if (auto.running)
          Padding(
            key: const ValueKey('auto-backup-progress'),
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.backupAutoRunning,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                const LinearProgressIndicator(minHeight: 2),
              ],
            ),
          ),
        if (failure != null)
          BackupNotice(
            key: const ValueKey('auto-backup-failed'),
            severity: Severity.actSoon,
            icon: Icons.backup_outlined,
            title: failure == AutoBackupFailure.pausedForRecovery
                ? l.backupAutoPausedTitle
                : l.backupAutoFailedTitle,
            body: autoBackupFailureText(l, failure),
            action: autoBackupRecoverLabel(l, failure),
            onAction: () => recoverAutoBackup(context, ref, failure),
            simple: simple,
          ),
        if (auto.unreadable && !auto.settings.enabled)
          BackupNotice(
            key: const ValueKey('auto-backup-unreadable'),
            severity: Severity.headsUp,
            icon: Icons.backup_outlined,
            title: l.backupAutoUnreadableTitle,
            body: l.backupAutoUnreadableBody,
            action: l.backupAutoOpen,
            onAction: () => context.go(backupPath),
            simple: simple,
          ),
        if (auto.settings.contentDropped && !auto.running)
          BackupNotice(
            key: const ValueKey('auto-backup-content-dropped'),
            severity: Severity.actSoon,
            icon: Icons.backup_outlined,
            title: l.backupContentDroppedTitle,
            body: l.backupContentDroppedBody,
            action: l.backupAutoOpen,
            onAction: () => context.go(backupPath),
            simple: simple,
          ),
        if (!simple && ref.watch(backupDueProvider))
          BackupNotice(
            key: const ValueKey('backup-due'),
            severity: Severity.headsUp,
            icon: Icons.backup_outlined,
            title: l.backupDueTitle,
            body: auto.settings.enabled
                ? l.backupDueAuto
                : last == null
                ? l.backupDueNever
                : l.backupDueOld,
            action: l.backupNow,
            onAction: () => context.go(backupPath),
            simple: simple,
          ),
      ],
    );
  }
}

/// A coloured notice on Home or in settings, with an optional button.
class BackupNotice extends StatelessWidget {
  const BackupNotice({
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
    final color = severity.foregroundOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: severity.backgroundOf(context),
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
