import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../preferences.dart';

/// Before an insurance card, record or photo leaves the app through the
/// share sheet (security plan S7): once it's in WhatsApp, email or Drive,
/// Usra's encryption and lock no longer protect it, and a wrong chat is
/// easy to pick. Says so, with "Don't ask again". True to go ahead.
Future<bool> confirmShareOutside(
  BuildContext context,
  KeyValueStore prefs,
) async {
  if (prefs.getBool(PrefKeys.shareWarningOff) == true) return true;
  var dontAsk = false;
  final go = await showDialog<bool>(
    context: context,
    builder: (context) {
      final l = AppLocalizations.of(context);
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          key: const ValueKey('share-warning'),
          icon: const Icon(Icons.share_outlined),
          title: Text(l.shareWarningTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.shareWarningBody),
                const SizedBox(height: 8),
                CheckboxListTile(
                  key: const ValueKey('share-warning-dont-ask'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: dontAsk,
                  onChanged: (v) => setState(() => dontAsk = v ?? false),
                  title: Text(l.shareWarningDontAsk),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('share-warning-cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l.shareWarningCancel),
            ),
            FilledButton(
              key: const ValueKey('share-warning-go'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l.shareWarningGo),
            ),
          ],
        ),
      );
    },
  );
  if (go != true) return false;
  if (dontAsk) {
    try {
      await prefs.setBool(PrefKeys.shareWarningOff, true);
    } catch (_) {
      // Asked again next time; the share still goes ahead.
    }
  }
  return true;
}
