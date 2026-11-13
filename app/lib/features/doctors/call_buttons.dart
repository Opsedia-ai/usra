import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/security/app_lock.dart';
import '../../l10n/app_localizations.dart';
import 'contact_links.dart';

/// Opens [uri] outside the app, with a message if nothing can handle it.
Future<void> openContact(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  final failed = AppLocalizations.of(context).contactFailed;
  var ok = false;
  try {
    ok = await whileInOtherApp(
      () => launchUrl(uri, mode: LaunchMode.externalApplication),
    );
  } catch (_) {
    ok = false;
  }
  if (!ok) messenger.showSnackBar(SnackBar(content: Text(failed)));
}

/// Big Call and WhatsApp buttons, sized for older hands.
class CallButtons extends StatelessWidget {
  const CallButtons({super.key, required this.phone});

  final String? phone;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final call = callUri(phone);
    final whatsapp = whatsappUri(phone);
    if (call == null) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('doctor-call'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
            onPressed: () => openContact(context, call),
            icon: const Icon(Icons.call),
            label: Text(l.doctorCall),
          ),
        ),
        if (whatsapp != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('doctor-whatsapp'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
              onPressed: () => openContact(context, whatsapp),
              icon: const Icon(Icons.chat_outlined),
              label: Text(l.doctorWhatsapp),
            ),
          ),
        ],
      ],
    );
  }
}
