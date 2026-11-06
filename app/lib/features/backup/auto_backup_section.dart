import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../core/backup/auto_backup.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'backup_providers.dart';
import 'backup_screen.dart';

String _frequencyText(AppLocalizations l, BackupFrequency frequency) =>
    switch (frequency) {
      BackupFrequency.daily => l.backupFrequencyDaily,
      BackupFrequency.weekly => l.backupFrequencyWeekly,
      BackupFrequency.monthly => l.backupFrequencyMonthly,
    };

/// A file size for people: "850 KB", "12.4 MB".
String formatBackupSize(BuildContext context, int bytes) {
  final l = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toString();
  String number(double n, String pattern) =>
      NumberFormat(pattern, locale).format(n);
  const kb = 1024.0;
  if (bytes < kb * kb) return l.backupSizeKb(number(bytes / kb, '0'));
  if (bytes < kb * kb * kb) {
    return l.backupSizeMb(number(bytes / (kb * kb), '0.0'));
  }
  return l.backupSizeGb(number(bytes / (kb * kb * kb), '0.0'));
}

/// The failure worth a notice, if any: never while a new try is running, or
/// once automatic backup is off, unless it's what turned it off.
AutoBackupFailure? autoBackupNoticeFailure(AutoBackupStatus status) {
  final failure = status.settings.failure;
  if (status.running) return null;
  if (failure == AutoBackupFailure.pausedForRecovery) return failure;
  return status.settings.enabled ? failure : null;
}

String autoBackupFailureText(AppLocalizations l, AutoBackupFailure failure) =>
    switch (failure) {
      AutoBackupFailure.folderMissing => l.backupAutoFailFolder,
      AutoBackupFailure.iCloudFolder => l.backupAutoFailICloud,
      AutoBackupFailure.noSpace => l.backupAutoFailSpace,
      AutoBackupFailure.phoneLocked => l.backupAutoFailLocked,
      AutoBackupFailure.noRecoveryKey => l.backupAutoFailKey,
      AutoBackupFailure.interrupted => l.backupAutoFailInterrupted,
      AutoBackupFailure.pausedForRecovery => l.backupAutoPaused,
      AutoBackupFailure.failed => l.backupAutoFailOther,
    };

/// What the notice's button says.
String autoBackupRecoverLabel(AppLocalizations l, AutoBackupFailure failure) =>
    switch (failure) {
      AutoBackupFailure.folderMissing ||
      AutoBackupFailure.iCloudFolder => l.backupAutoChooseFolder,
      AutoBackupFailure.noRecoveryKey => l.backupAutoSetKey,
      AutoBackupFailure.pausedForRecovery => l.backupAutoOpen,
      _ => l.backupAutoRetry,
    };

/// The notice's button: fixes what it can, then backs up again.
Future<void> recoverAutoBackup(
  BuildContext context,
  WidgetRef ref,
  AutoBackupFailure failure,
) async {
  final controller = ref.read(autoBackupProvider.notifier);
  switch (failure) {
    case AutoBackupFailure.pausedForRecovery:
      // The person decides there: restore, or turn it back on.
      context.go(backupPath);
      return;
    case AutoBackupFailure.folderMissing || AutoBackupFailure.iCloudFolder:
      if (!await _chooseFolder(context, ref)) return;
    case AutoBackupFailure.noRecoveryKey:
      final made = await context.push<bool>(recoveryKeyPath);
      if (made != true) return;
    default:
      break;
  }
  await controller.runNow();
}

/// The system picker, and a plain explanation if the place is refused. True
/// when a folder was saved.
Future<bool> _chooseFolder(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final choice = await ref.read(autoBackupProvider.notifier).chooseFolder();
  if (!context.mounted) return false;
  switch (choice) {
    case FolderChoice.chosen:
      return true;
    case FolderChoice.cancelled:
      return false;
    case FolderChoice.inICloud:
      await _explain(
        context,
        const ValueKey('backup-icloud-refused'),
        l.backupICloudTitle,
        l.backupICloudBody,
      );
    case FolderChoice.cantUse:
      await _explain(
        context,
        const ValueKey('backup-folder-refused'),
        l.backupFolderCantUseTitle,
        l.backupFolderCantUseBody,
      );
  }
  return false;
}

Future<void> _explain(
  BuildContext context,
  Key key,
  String title,
  String body,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    key: key,
    title: Text(title),
    content: Text(body),
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: Text(MaterialLocalizations.of(context).okButtonLabel),
      ),
    ],
  ),
);

/// Turning it on, picking the folder, how often, how it went, "Back up now".
class AutoBackupSection extends ConsumerWidget {
  const AutoBackupSection({super.key});

  /// The recovery key first, then the folder, then the first backup. Backing
  /// out of any step leaves automatic backup off.
  Future<void> _turnOn(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(autoBackupProvider.notifier);
    try {
      if (await ref.read(recoveryKeyStoreProvider).read() == null) {
        if (!context.mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.backupAutoKeyFirstTitle),
            content: Text(l.backupAutoKeyFirstBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              FilledButton(
                key: const ValueKey('backup-auto-key-continue'),
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.backupAutoKeyFirstContinue),
              ),
            ],
          ),
        );
        if (proceed != true || !context.mounted) return;
        final made = await context.push<bool>(recoveryKeyPath);
        if (made != true || !context.mounted) return;
      }
      final settings = ref.read(autoBackupProvider).settings;
      if (settings.folder == null) {
        if (!context.mounted || !await _chooseFolder(context, ref)) return;
      }
      await controller.enable();
      await controller.runNow();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.backupFailed)));
    }
  }

  /// A new folder gets a backup now, so it isn't empty until the next one
  /// is due while the screen shows the old folder's date beside its name.
  Future<void> _changeFolder(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(autoBackupProvider.notifier);
    if (await _chooseFolder(context, ref)) await controller.runNow();
  }

  Future<void> _pickFrequency(
    BuildContext context,
    WidgetRef ref,
    BackupFrequency current,
  ) async {
    final l = AppLocalizations.of(context);
    final picked = await showDialog<BackupFrequency>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l.backupAutoFrequency),
        children: [
          for (final frequency in BackupFrequency.values)
            SimpleDialogOption(
              key: ValueKey('backup-frequency-${frequency.name}'),
              onPressed: () => Navigator.pop(context, frequency),
              child: Row(
                children: [
                  Icon(
                    frequency == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_frequencyText(l, frequency))),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked != null) {
      await ref.read(autoBackupProvider.notifier).setFrequency(picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final status = ref.watch(autoBackupProvider);
    final settings = status.settings;
    final controller = ref.read(autoBackupProvider.notifier);
    final folder = settings.folder;
    final last = settings.lastAt;
    final failure = settings.enabled ? autoBackupNoticeFailure(status) : null;
    final paused = settings.failure == AutoBackupFailure.pausedForRecovery;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            key: const ValueKey('backup-auto-toggle'),
            secondary: const Icon(Icons.schedule),
            title: Text(l.backupAutoTitle),
            subtitle: Text(l.backupAutoHint),
            value: settings.enabled,
            onChanged: status.running
                ? null
                : (on) => on ? _turnOn(context, ref) : controller.disable(),
          ),
          if (paused)
            _Message(
              key: const ValueKey('backup-auto-paused'),
              severity: Severity.headsUp,
              text: l.backupAutoPaused,
            ),
          if (settings.contentDropped && !status.running) ...[
            _Message(
              key: const ValueKey('backup-content-dropped'),
              severity: Severity.actSoon,
              text: l.backupContentDroppedBody,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    key: const ValueKey('backup-content-accept'),
                    onPressed: controller.acceptContentChange,
                    child: Text(l.backupContentDroppedAccept),
                  ),
                  FilledButton.tonal(
                    key: const ValueKey('backup-content-restore'),
                    onPressed: () => context.push(restorePath),
                    child: Text(l.restoreTitle),
                  ),
                ],
              ),
            ),
          ],
          if (settings.enabled) ...[
            const Divider(height: 1),
            ListTile(
              key: const ValueKey('backup-auto-folder'),
              leading: const Icon(Icons.folder_outlined),
              title: Text(l.backupAutoFolder),
              subtitle: Text(
                folder == null
                    ? l.backupAutoChooseFolder
                    : folder.name.isEmpty
                    ? l.backupAutoFolderTop
                    : folder.name,
              ),
              onTap: status.running ? null : () => _changeFolder(context, ref),
            ),
            if (folder?.onThisPhone == true)
              _Message(
                key: const ValueKey('backup-auto-on-phone'),
                severity: Severity.headsUp,
                text: l.backupAutoOnPhone,
              ),
            const _PlatformHint(),
            ListTile(
              key: const ValueKey('backup-auto-frequency'),
              leading: const Icon(Icons.event_repeat),
              title: Text(l.backupAutoFrequency),
              subtitle: Text(_frequencyText(l, settings.frequency)),
              onTap: status.running
                  ? null
                  : () => _pickFrequency(context, ref, settings.frequency),
            ),
            ListTile(
              key: const ValueKey('backup-auto-last'),
              leading: const Icon(Icons.history),
              title: Text(
                last == null
                    ? l.backupAutoNever
                    : l.backupAutoLast(
                        backupDay(context, last),
                        formatBackupSize(context, settings.lastSize ?? 0),
                      ),
              ),
              subtitle: settings.lastSkippedPhotos > 0
                  ? Text(
                      l.backupAutoPhotosSkipped(settings.lastSkippedPhotos),
                      key: const ValueKey('backup-auto-photos-skipped'),
                    )
                  : null,
            ),
            if (failure != null)
              _Message(
                key: const ValueKey('backup-auto-failure'),
                severity: Severity.actSoon,
                text: autoBackupFailureText(l, failure),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: status.running
                  ? Column(
                      key: const ValueKey('backup-auto-progress'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.backupAutoRunning, style: text.bodyMedium),
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(minHeight: 2),
                      ],
                    )
                  : FilledButton.icon(
                      key: const ValueKey('backup-auto-now'),
                      onPressed: () => failure == null
                          ? unawaited(controller.runNow())
                          : recoverAutoBackup(context, ref, failure),
                      icon: const Icon(Icons.backup_outlined),
                      label: Text(
                        failure == null
                            ? l.backupNow
                            : autoBackupRecoverLabel(l, failure),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What this platform's picker can't do, said where the folder is chosen.
class _PlatformHint extends StatelessWidget {
  const _PlatformHint();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hint = switch (defaultTargetPlatform) {
      TargetPlatform.android => l.backupAutoDriveHint,
      TargetPlatform.iOS => l.backupAutoIosHint,
      _ => null,
    };
    if (hint == null) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('backup-auto-hint'),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
      child: Text(hint, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.severity, required this.text});

  final Severity severity;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: severity.background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: severity.foreground),
    ),
  );
}
