import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/list_row.dart' show IconBox;
import '../../core/design/status_dot.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
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

/// A white card with an icon box, an amber dot before the title, quiet body
/// text and an outlined button, like the backup notices on Home.
class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.usra;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(UsraSpacing.s4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBox(icon: icon),
            const SizedBox(width: UsraSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: UsraSpacing.s1,
                children: [
                  Semantics(
                    header: true,
                    child: StatusDotText(
                      label: title,
                      color: c.ink,
                      style: UsraType.body.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 24 / 16,
                      ),
                    ),
                  ),
                  Text(
                    body,
                    style: UsraType.label.copyWith(
                      color: c.inkMuted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: UsraSpacing.s2),
                    child: OutlinedButton(
                      onPressed: onAction,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.ink,
                        side: BorderSide(color: c.lineStrong),
                      ),
                      child: Text(action),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
