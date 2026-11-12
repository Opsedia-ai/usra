import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'medicines_providers.dart';

/// Asks for what reminders need when something is missing: notifications,
/// exact alarms (Android 12+), and battery optimisation switched off on
/// phones that stop apps in the background.
class ReminderAccessCard extends ConsumerWidget {
  const ReminderAccessCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final access = ref.watch(reminderAccessProvider).value;
    if (access == null) return const SizedBox.shrink();
    final scheduler = ref.read(reminderSchedulerProvider);

    Future<void> allow() async {
      await scheduler.requestAccess();
      ref.invalidate(reminderAccessProvider);
    }

    if (!access.complete) {
      return _Banner(
        key: const ValueKey('reminders-off'),
        severity: Severity.actSoon,
        icon: Icons.notifications_off_outlined,
        // Allowed, but without exact alarms: on, possibly late, not off.
        title: access.notifications
            ? l.reminderExactOffTitle
            : l.reminderOffTitle,
        body: access.notifications ? l.reminderExactOff : l.reminderOffBody,
        action: l.reminderAllow,
        onAction: allow,
      );
    }
    if (access.batteryUnrestricted == false) {
      return _Banner(
        key: const ValueKey('reminders-battery'),
        severity: Severity.headsUp,
        icon: Icons.battery_alert_outlined,
        title: l.reminderBatteryTitle,
        body: l.reminderBatteryBody,
        action: l.reminderBatteryOpen,
        onAction: () async {
          await scheduler.openBatterySettings();
          ref.invalidate(reminderAccessProvider);
        },
      );
    }
    return const SizedBox.shrink();
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.severity,
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final Severity severity;
  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      color: severity.backgroundOf(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: severity.foregroundOf(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: text.titleMedium?.copyWith(
                      color: severity.foregroundOf(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(body, style: text.bodyMedium),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(onPressed: onAction, child: Text(action)),
            ),
          ],
        ),
      ),
    );
  }
}
