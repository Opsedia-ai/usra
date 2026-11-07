import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Shown instead of the app when the records can't be reached: the database
/// key can't be read (a Keystore error), or the database file can't be opened
/// for a reason other than the key (a full disk). The key and the records are
/// untouched, so trying again later may work. In both languages: settings
/// aren't open yet.
class DatabaseKeyUnavailable extends StatefulWidget {
  const DatabaseKeyUnavailable({super.key, required this.onRetry})
    : _message = _keyMessage;

  const DatabaseKeyUnavailable.openFailed({super.key, required this.onRetry})
    : _message = _openFailedMessage;

  /// Starts the app again. The button stays off until this finishes, so a
  /// double tap can't start it twice with two connections to one file.
  final Future<void> Function() onRetry;

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

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('database-key-unavailable'),
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_outline, size: 48),
        const SizedBox(height: 16),
        for (final code in ['ar', 'en'])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              widget._message(lookupAppLocalizations(Locale(code))),
              textAlign: TextAlign.center,
              textDirection: code == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
            ),
          ),
        FilledButton(
          key: const ValueKey('database-key-retry'),
          onPressed: _retrying ? null : () => unawaited(_retry()),
          child: Text(
            '${lookupAppLocalizations(const Locale('ar')).accountRetry} · '
            '${lookupAppLocalizations(const Locale('en')).accountRetry}',
          ),
        ),
      ],
    ),
  );
}
