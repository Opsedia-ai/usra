import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Shown instead of the app when the database key can't be read, for example
/// after a Keystore error. The key and the records are untouched, so trying
/// again later may work. In both languages: settings aren't open yet.
class DatabaseKeyUnavailable extends StatelessWidget {
  const DatabaseKeyUnavailable({super.key, required this.onRetry});

  final VoidCallback onRetry;

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
              lookupAppLocalizations(Locale(code)).databaseKeyUnavailable,
              textAlign: TextAlign.center,
              textDirection: code == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
            ),
          ),
        FilledButton(
          key: const ValueKey('database-key-retry'),
          onPressed: onRetry,
          child: Text(
            '${lookupAppLocalizations(const Locale('ar')).accountRetry} · '
            '${lookupAppLocalizations(const Locale('en')).accountRetry}',
          ),
        ),
      ],
    ),
  );
}
