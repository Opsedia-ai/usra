import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:share_plus/share_plus.dart';

import '../../core/backup/backup_crypto.dart';
import '../../core/backup/backup_service.dart';
import '../../core/backup/recovery_key.dart';
import '../../core/design/tokens.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'backup_providers.dart';

const backupPath = '/settings/backup';
const recoveryKeyPath = '/settings/backup/key';
const restorePath = '/settings/backup/restore';

String _day(BuildContext context, DateTime at) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(at);

/// Make a backup, see the recovery key, or restore from a backup.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  var _working = false;

  Future<void> _backUp() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final box = context.findRenderObject() as RenderBox?;
    var key = await ref.read(recoveryKeyStoreProvider).read();
    if (key == null) {
      if (!mounted) return;
      final made = await context.push<bool>(recoveryKeyPath);
      if (made != true) return;
      key = await ref.read(recoveryKeyStoreProvider).read();
      if (key == null) return;
    }
    setState(() => _working = true);
    try {
      final file = await ref
          .read(backupServiceProvider)
          .create(
            ref.read(databaseProvider),
            key,
            appVersion: ref.read(appVersionProvider),
          );
      final status = await ref.read(backupShareProvider)(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/octet-stream')],
          fileNameOverrides: [file.uri.pathSegments.last],
          subject: l.backupShareSubject,
          // iPad needs to know where to anchor the share sheet.
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
      if (status != ShareResultStatus.dismissed) {
        await ref.read(lastBackupProvider.notifier).set(DateTime.now());
        messenger.showSnackBar(SnackBar(content: Text(l.backupDone)));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.backupFailed)));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final last = ref.watch(lastBackupProvider);
    final hasKey = ref.watch(savedRecoveryKeyProvider).value != null;
    return Scaffold(
      appBar: AppBar(title: Text(l.backupTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(l.backupIntro, style: text.bodyLarge),
          const SizedBox(height: 16),
          Card(
            color: ref.watch(backupDueProvider)
                ? Severity.headsUp.background
                : null,
            child: ListTile(
              key: const ValueKey('backup-last'),
              leading: const Icon(Icons.history),
              title: Text(
                last == null
                    ? l.backupNever
                    : l.backupLast(_day(context, last)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('backup-now'),
            onPressed: _working ? null : _backUp,
            icon: _working
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.backup_outlined),
            label: Text(_working ? l.backupWorking : l.backupNow),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                if (hasKey) ...[
                  ListTile(
                    key: const ValueKey('backup-show-key'),
                    leading: const Icon(Icons.key_outlined),
                    title: Text(l.recoveryKeyShow),
                    onTap: () => context.push(recoveryKeyPath),
                  ),
                  const Divider(height: 1),
                ],
                ListTile(
                  key: const ValueKey('backup-restore'),
                  leading: const Icon(Icons.settings_backup_restore),
                  title: Text(l.restoreTitle),
                  subtitle: Text(l.restoreHint),
                  onTap: _working ? null : () => context.push(restorePath),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pick a backup file, type the recovery key, check what's inside, then
/// replace everything on this phone with it.
class RestoreScreen extends ConsumerStatefulWidget {
  const RestoreScreen({super.key});

  @override
  ConsumerState<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends ConsumerState<RestoreScreen> {
  final _key = TextEditingController();
  String? _file;
  StagedRestore? _staged;
  RecoveryKey? _usedKey;
  var _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Restoring on the same phone: the saved key is probably the one.
    ref.read(recoveryKeyStoreProvider).read().then((key) {
      if (key != null && mounted && _key.text.isEmpty) {
        _key.text = key.groups.join(' ');
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final path = await ref.read(backupFilePickerProvider)();
    if (path == null || !mounted) return;
    setState(() {
      _file = path;
      _staged = null;
      _error = null;
    });
  }

  Future<void> _open() async {
    final l = AppLocalizations.of(context);
    final wrong = RecoveryKey.wrongGroups(_key.text);
    final key = RecoveryKey.tryParse(_key.text);
    if (key == null) {
      setState(
        () => _error = l.restoreKeyGroupsWrong(
          wrong.map((g) => '${g + 1}').join('، '),
        ),
      );
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final staged = await ref
          .read(backupServiceProvider)
          .stage(
            File(_file!),
            key,
            currentSchema: ref.read(databaseProvider).schemaVersion,
          );
      if (!mounted) return;
      setState(() {
        _staged = staged;
        _usedKey = key;
      });
    } on BackupException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = switch (e.failure) {
          BackupFailure.notABackup => l.restoreNotABackup,
          BackupFailure.wrongKey => l.restoreWrongKey,
          BackupFailure.damaged => l.restoreDamaged,
          BackupFailure.tooNew => l.restoreTooNew,
        },
      );
    } catch (_) {
      if (mounted) setState(() => _error = l.restoreFailed);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _replace() async {
    setState(() => _working = true);
    // Restarts the app: this screen goes away with the old data.
    await ref.read(restoreAndRestartProvider)(_staged!, _usedKey!);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final staged = _staged;
    return Scaffold(
      appBar: AppBar(title: Text(l.restoreTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(l.restoreIntro, style: text.bodyLarge),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const ValueKey('restore-pick'),
            onPressed: _working ? null : _pick,
            icon: const Icon(Icons.folder_open_outlined),
            label: Text(
              _file == null ? l.restorePick : _file!.split('/').last,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_file != null && staged == null) ...[
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('restore-key'),
              controller: _key,
              enabled: !_working,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              inputFormatters: [_RecoveryKeyFormatter()],
              style: text.titleLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                labelText: l.restoreKeyLabel,
                hintText: '123456 123456 123456 123456 123456 123456',
              ),
              maxLines: null,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('restore-open'),
              onPressed: _working ? null : _open,
              child: _working
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.restoreOpen),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              key: const ValueKey('restore-error'),
              style: text.bodyMedium?.copyWith(
                color: Severity.actSoon.foreground,
              ),
            ),
          ],
          if (staged != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.restoreFrom(
                        _day(context, staged.manifest.createdAt.toLocal()),
                      ),
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.restoreContents(
                        staged.manifest.count('people'),
                        staged.manifest.count('records'),
                        staged.manifest.count('medicines'),
                        staged.manifest.count('photos'),
                      ),
                      key: const ValueKey('restore-contents'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Severity.actSoon.background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                l.restoreReplaceWarning,
                style: text.bodyMedium?.copyWith(
                  color: Severity.actSoon.foreground,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('restore-replace'),
              onPressed: _working ? null : _replace,
              icon: const Icon(Icons.settings_backup_restore),
              label: Text(l.restoreReplace),
            ),
          ],
        ],
      ),
    );
  }
}

/// Keeps only digits (Arabic ones too) and spaces them in groups of six.
class _RecoveryKeyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = RecoveryKey.normalize(newValue.text);
    final capped = digits.length > 36 ? digits.substring(0, 36) : digits;
    final grouped = [
      for (var i = 0; i < capped.length; i += RecoveryKey.groupLength)
        capped.substring(
          i,
          i + RecoveryKey.groupLength > capped.length
              ? capped.length
              : i + RecoveryKey.groupLength,
        ),
    ].join(' ');
    return TextEditingValue(
      text: grouped,
      selection: TextSelection.collapsed(offset: grouped.length),
    );
  }
}
