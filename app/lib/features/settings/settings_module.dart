import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/severity_chip.dart';
import '../../core/design/tokens.dart';
import '../../core/modules/feature_module.dart';
import '../../core/preferences.dart';
import '../../core/providers.dart';
import '../../core/security/app_lock.dart';
import '../../l10n/app_localizations.dart';
import '../account/account_screen.dart';
import '../backup/backup_screen.dart';
import 'about_privacy_screen.dart';

class SettingsModule extends FeatureModule {
  const SettingsModule();

  @override
  String get id => 'settings';

  @override
  List<ModuleTab> get tabs => [
    ModuleTab(
      path: '/settings',
      icon: Icons.more_horiz,
      label: (c) => AppLocalizations.of(c).navSettings,
      order: 100,
    ),
  ];

  @override
  List<RouteBase> get routes => [
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    GoRoute(path: aboutPath, builder: (_, _) => const AboutPrivacyScreen()),
  ];
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            l.settingsLanguage,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'ar', label: Text(l.languageArabic)),
              ButtonSegment(value: 'en', label: Text(l.languageEnglish)),
            ],
            selected: {locale.languageCode},
            onSelectionChanged: (s) =>
                ref.read(localeProvider.notifier).change(Locale(s.first)),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  key: const ValueKey('settings-simple-mode'),
                  value: ref.watch(simpleModeProvider),
                  onChanged: (on) async {
                    try {
                      await ref.read(simpleModeProvider.notifier).set(on);
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(l.saveFailed)));
                    }
                  },
                  secondary: const Icon(Icons.accessibility_new),
                  title: Text(l.settingsSimpleMode),
                  subtitle: Text(l.settingsSimpleModeHint),
                ),
                const Divider(height: 1),
                ListenableBuilder(
                  listenable: ref.watch(appLockProvider),
                  builder: (context, _) => ListTile(
                    key: const ValueKey('settings-app-lock'),
                    leading: const Icon(Icons.lock_outline),
                    title: Text(l.settingsAppLock),
                    subtitle: Text(
                      ref.read(appLockProvider).enabled
                          ? l.settingsAppLockOn
                          : l.settingsAppLockOff,
                    ),
                    onTap: () => context.go(appLockSettingsPath),
                  ),
                ),
                const Divider(height: 1),
                _PreferenceSwitch(
                  key: const ValueKey('settings-discreet'),
                  preference: discreetNotificationsProvider,
                  icon: Icons.notifications_off_outlined,
                  title: l.settingsDiscreet,
                  subtitle: l.settingsDiscreetHint,
                ),
                const Divider(height: 1),
                const _VaccineReminderSettings(),
                const Divider(height: 1),
                // iOS can't block screenshots; the switcher is covered on
                // both.
                if (defaultTargetPlatform == TargetPlatform.android) ...[
                  _PreferenceSwitch(
                    key: const ValueKey('settings-block-screenshots'),
                    preference: blockScreenshotsProvider,
                    icon: Icons.screenshot_monitor_outlined,
                    title: l.settingsBlockScreenshots,
                    subtitle: l.settingsBlockScreenshotsHint,
                  ),
                  const Divider(height: 1),
                ],
                ListTile(
                  key: const ValueKey('settings-backup'),
                  leading: const Icon(Icons.backup_outlined),
                  title: Text(l.backupTitle),
                  subtitle: Text(l.settingsBackupHint),
                  onTap: () => context.go(backupPath),
                ),
                const Divider(height: 1),
                const AccountSettingsTile(),
                ListTile(
                  key: const ValueKey('settings-tutorial'),
                  leading: const Icon(Icons.school_outlined),
                  title: Text(l.settingsTutorial),
                  onTap: ref.read(tutorialProvider.notifier).reopen,
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('settings-about'),
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(l.aboutTitle),
                  subtitle: Text(l.aboutHint),
                  onTap: () => context.push(aboutPath),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SeverityChip(
              severity: Severity.good,
              label: l.settingsPrivacy,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l.notMedicalDevice,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// An on/off [BoolPreference]; says so if it couldn't be saved.
class _PreferenceSwitch extends ConsumerWidget {
  const _PreferenceSwitch({
    super.key,
    required this.preference,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final NotifierProvider<BoolPreference, bool> preference;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SwitchListTile(
    value: ref.watch(preference),
    onChanged: (on) async {
      try {
        await ref.read(preference.notifier).set(on);
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).saveFailed)),
        );
      }
    },
    secondary: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
  );
}

/// Vaccine visit reminders on or off, and their time of day.
class _VaccineReminderSettings extends ConsumerWidget {
  const _VaccineReminderSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final minutes = ref.watch(vaccineReminderMinutesProvider);
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    final on = ref.watch(vaccineRemindersProvider);
    Future<void> guarded(Future<void> Function() save) async {
      try {
        await save();
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.saveFailed)));
      }
    }

    return Column(
      children: [
        SwitchListTile(
          key: const ValueKey('settings-vaccine-reminders'),
          value: on,
          onChanged: (v) =>
              guarded(() => ref.read(vaccineRemindersProvider.notifier).set(v)),
          secondary: const Icon(Icons.vaccines_outlined),
          title: Text(l.settingsVaccineReminders),
          subtitle: Text(l.settingsVaccineRemindersHint(time.format(context))),
        ),
        if (on)
          ListTile(
            key: const ValueKey('settings-vaccine-time'),
            leading: const Icon(Icons.schedule),
            title: Text(l.settingsVaccineReminderTime),
            trailing: Text(time.format(context)),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: time,
              );
              if (picked == null) return;
              await guarded(
                () => ref
                    .read(vaccineReminderMinutesProvider.notifier)
                    .set(picked.hour * 60 + picked.minute),
              );
            },
          ),
      ],
    );
  }
}
