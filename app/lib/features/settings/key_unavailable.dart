import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/security/data_wipe.dart';
import '../../l10n/app_localizations.dart';
import '../../core/util/separator.dart';

/// Shown instead of the app when the records can't be reached: the database
/// key can't be read (a Keystore error), or the database file can't be opened
/// for a reason other than the key (a full disk, damage). Trying again later
/// may work, so that comes first. When that doesn't help, a family with a
/// backup can restore it here, anyone can write to support, and the last
/// resort is starting fresh. In both languages: the language setting may not
/// be readable.
class DatabaseKeyUnavailable extends StatefulWidget {
  const DatabaseKeyUnavailable({
    super.key,
    required this.onRetry,
    this.onRestore,
    this.onStartFresh,
    this.restoreFailed = false,
    this.wipeOutcome,
  }) : _message = _keyMessage;

  const DatabaseKeyUnavailable.openFailed({
    super.key,
    required this.onRetry,
    this.onRestore,
    this.onStartFresh,
    this.restoreFailed = false,
    this.wipeOutcome,
  }) : _message = _openFailedMessage;

  /// Starts the app again. The button stays off until this finishes, so a
  /// double tap can't start it twice with two connections to one file.
  final Future<void> Function() onRetry;

  /// Opens Restore from backup.
  final Future<void> Function()? onRestore;

  /// Opens the warning and confirmation for starting fresh.
  final Future<void> Function()? onStartFresh;

  /// The last try to restore didn't go in.
  final bool restoreFailed;

  /// Starting fresh ran and the records still can't be reached, so "nothing was
  /// deleted" would be wrong.
  final WipeOutcome? wipeOutcome;

  final String Function(AppLocalizations) _message;

  static String _keyMessage(AppLocalizations l) => l.databaseKeyUnavailable;
  static String _openFailedMessage(AppLocalizations l) => l.databaseOpenFailed;

  @override
  State<DatabaseKeyUnavailable> createState() => _DatabaseKeyUnavailableState();
}

class _DatabaseKeyUnavailableState extends State<DatabaseKeyUnavailable> {
  bool _retrying = false;

  Future<void> _retry() async {
    // Not left to the rebuild: two taps can land before the next frame.
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } catch (e, s) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: s, library: 'database'),
      );
    } finally {
      // A retry that fails again shows this screen again, and runApp keeps
      // this State: the person must be able to try once more.
      if (mounted) setState(() => _retrying = false);
    }
  }

  /// [text] in both languages, Arabic first, on one button or line.
  static String _both(String Function(AppLocalizations) text) =>
      '${text(lookupAppLocalizations(const Locale('ar')))}$partSeparator'
      '${text(lookupAppLocalizations(const Locale('en')))}';

  Widget _inBoth(
    String Function(AppLocalizations) text, {
    Key? key,
    TextStyle? style,
  }) => Column(
    key: key,
    children: [
      for (final code in ['ar', 'en'])
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            text(lookupAppLocalizations(Locale(code))),
            style: style,
            textAlign: TextAlign.center,
            textDirection: code == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final onRestore = widget.onRestore;
    final onStartFresh = widget.onStartFresh;
    final theme = Theme.of(context);
    final danger = theme.colorScheme.error;
    return Padding(
      key: const ValueKey('database-key-unavailable'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.lock_outline, size: 48),
          const SizedBox(height: 16),
          if (widget.restoreFailed)
            _inBoth(
              (l) => l.restoreFailedNotice,
              key: const ValueKey('database-restore-failed'),
              style: TextStyle(color: danger, fontWeight: FontWeight.w600),
            ),
          switch (widget.wipeOutcome) {
            null => _inBoth(widget._message),
            WipeOutcome.done => _inBoth(
              (l) => l.wipeDoneNotice,
              key: const ValueKey('database-wipe-outcome'),
            ),
            WipeOutcome.incomplete => _inBoth(
              (l) => l.wipeIncompleteNotice,
              key: const ValueKey('database-wipe-outcome'),
            ),
          },
          FilledButton(
            key: const ValueKey('database-key-retry'),
            onPressed: _retrying ? null : () => unawaited(_retry()),
            child: Text(
              _both((l) => l.accountRetry),
              textAlign: TextAlign.center,
            ),
          ),
          if (onRestore != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              key: const ValueKey('database-restore'),
              onPressed: _retrying ? null : () => unawaited(onRestore()),
              child: Text(
                _both((l) => l.restoreTitle),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 24),
          _inBoth((l) => l.databaseSupportLabel),
          SelectableText(
            lookupAppLocalizations(const Locale('en')).databaseSupportAddress,
            key: const ValueKey('database-support-address'),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: theme.textTheme.titleMedium,
          ),
          if (onStartFresh != null) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            _inBoth((l) => l.databaseStartFreshHint),
            TextButton(
              key: const ValueKey('database-start-fresh'),
              style: TextButton.styleFrom(foregroundColor: danger),
              onPressed: _retrying ? null : () => unawaited(onStartFresh()),
              child: Text(
                _both((l) => l.databaseStartFresh),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
