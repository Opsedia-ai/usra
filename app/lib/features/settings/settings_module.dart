import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/modules/feature_module.dart';
import '../../core/preferences.dart';
import '../../core/providers.dart';
import '../../core/security/app_lock.dart';
import '../../l10n/app_localizations.dart';
import '../account/account_providers.dart';
import '../account/account_screen.dart';
import '../backup/backup_providers.dart';
import '../backup/backup_screen.dart';
import '../children/vaccines_screen.dart' show askForReminderAccess;
import 'about_privacy_screen.dart';
import 'delete_data_screen.dart';
import '../home/simple_home.dart' show leaveSimpleMode;

class SettingsModule extends FeatureModule {
  const SettingsModule();

  @override
  String get id => 'settings';

  @override
  List<ModuleTab> get tabs => [
    ModuleTab(
      path: '/settings',
      icon: Icons.menu,
      label: (c) => AppLocalizations.of(c).navSettings,
      order: 100,
      alsoFor: const ['/doctors', '/money'],
    ),
  ];

  @override
  List<RouteBase> get routes => [
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    GoRoute(path: aboutPath, builder: (_, _) => const AboutPrivacyScreen()),
    GoRoute(path: deleteDataPath, builder: (_, _) => const DeleteDataScreen()),
  ];
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final last = ref.watch(lastBackupProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (ref.watch(supabaseConfigProvider).isConfigured) ...[
            const Card(child: AccountSettingsTile()),
            const SizedBox(height: UsraSpacing.s4),
          ],
          // Simple Mode keeps Family and Doctors as tabs, and leaves Money out.
          if (!ref.watch(simpleModeProvider))
            _Group(
              title: l.moreGroupFamily,
              children: [
                ListTile(
                  key: const ValueKey('more-family'),
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(l.moreFamily),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/family'),
                ),
                ListTile(
                  key: const ValueKey('more-doctors'),
                  leading: const Icon(Icons.medical_services_outlined),
                  title: Text(l.navDoctors),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/doctors'),
                ),
                ListTile(
                  key: const ValueKey('more-money'),
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: Text(l.navMoney),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/money'),
                ),
              ],
            ),
          _Group(
            title: l.moreGroupSafety,
            children: [
              ListTile(
                key: const ValueKey('settings-backup'),
                leading: const Icon(Icons.backup_outlined),
                title: Text(l.backupTitle),
                subtitle: Text(
                  last == null
                      ? l.backupNever
                      : l.backupLast(backupDay(context, last)),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(backupPath),
              ),
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
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(appLockSettingsPath),
                ),
              ),
              _PreferenceSwitch(
                key: const ValueKey('settings-discreet'),
                preference: discreetNotificationsProvider,
                icon: Icons.notifications_off_outlined,
                title: l.settingsDiscreet,
                subtitle: l.settingsDiscreetHint,
              ),
              const _VaccineReminderSettings(),
              // iOS can't block screenshots; the switcher is covered on both.
              if (defaultTargetPlatform == TargetPlatform.android)
                _PreferenceSwitch(
                  key: const ValueKey('settings-block-screenshots'),
                  preference: blockScreenshotsProvider,
                  icon: Icons.screenshot_monitor_outlined,
                  title: l.settingsBlockScreenshots,
                  subtitle: l.settingsBlockScreenshotsHint,
                ),
            ],
          ),
          _Group(
            title: l.moreGroupApp,
            children: [
              SwitchListTile(
                key: const ValueKey('settings-simple-mode'),
                value: ref.watch(simpleModeProvider),
                onChanged: (on) async {
                  // Going out asks first, here as on its own page.
                  if (!on) {
                    await leaveSimpleMode(context, ref);
                    return;
                  }
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
              Padding(
                padding: const EdgeInsets.all(UsraSpacing.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.settingsLanguage,
                      style: UsraType.body.copyWith(color: context.usra.ink),
                    ),
                    const SizedBox(height: UsraSpacing.s2),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'ar',
                          label: Text(l.languageArabic),
                        ),
                        ButtonSegment(
                          value: 'en',
                          label: Text(l.languageEnglish),
                        ),
                      ],
                      selected: {locale.languageCode},
                      onSelectionChanged: (s) => ref
                          .read(localeProvider.notifier)
                          .change(Locale(s.first)),
                    ),
                  ],
                ),
              ),
              const _ThemeModeTile(),
              ListTile(
                key: const ValueKey('settings-tutorial'),
                leading: const Icon(Icons.school_outlined),
                title: Text(l.settingsTutorial),
                trailing: const Icon(Icons.chevron_right),
                onTap: ref.read(tutorialProvider.notifier).reopen,
              ),
              ListTile(
                key: const ValueKey('settings-ai-soon'),
                enabled: false,
                leading: const Icon(Icons.auto_awesome_outlined),
                title: Text(l.settingsAiTitle),
                subtitle: Text(l.settingsAiSoon),
              ),
              ListTile(
                key: const ValueKey('settings-about'),
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(l.aboutTitle),
                subtitle: Text(l.aboutHint),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(aboutPath),
              ),
            ],
          ),
          Card(
            child: ListTile(
              key: const ValueKey('settings-delete-all'),
              leading: Icon(
                Icons.delete_forever_outlined,
                color: Severity.actSoon.foregroundOf(context),
              ),
              title: Text(
                l.settingsDeleteAll,
                style: TextStyle(color: Severity.actSoon.foregroundOf(context)),
              ),
              subtitle: Text(l.settingsDeleteAllHint),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(deleteDataPath),
            ),
          ),
          const SizedBox(height: UsraSpacing.s5),
          Text(
            l.notMedicalDevice,
            key: const ValueKey('more-footer'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// A heading and its rows in one card, with lines between them.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: UsraSpacing.s4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: UsraSpacing.s1,
              bottom: UsraSpacing.s2,
            ),
            child: Text(
              title,
              style: UsraType.label.copyWith(color: context.usra.inkMuted),
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, row) in children.indexed) ...[
                if (i > 0) const Divider(height: 1),
                row,
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

String _themeModeName(AppLocalizations l, ThemeMode mode) => switch (mode) {
  ThemeMode.system => l.settingsThemeSystem,
  ThemeMode.light => l.settingsThemeLight,
  ThemeMode.dark => l.settingsThemeDark,
};

/// Shows the current look; tapping offers system, light and dark.
class _ThemeModeTile extends ConsumerWidget {
  const _ThemeModeTile();

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final current = ref.read(themeModeProvider);
    final picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      // Over the tab bar, which is the same colour as the sheet.
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in ThemeMode.values)
                ListTile(
                  key: ValueKey('settings-theme-${mode.name}'),
                  selected: mode == current,
                  selectedColor: context.usra.primary,
                  title: Text(_themeModeName(l, mode)),
                  trailing: mode == current ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.of(context).pop(mode),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    try {
      await ref.read(themeModeProvider.notifier).set(picked);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.saveFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return ListTile(
      key: const ValueKey('settings-theme'),
      leading: const Icon(Icons.contrast),
      title: Text(l.settingsTheme),
      subtitle: Text(_themeModeName(l, ref.watch(themeModeProvider))),
      onTap: () => _choose(context, ref),
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
          onChanged: (v) => guarded(() async {
            await ref.read(vaccineRemindersProvider.notifier).set(v);
            if (v) await askForReminderAccess(ref);
          }),
          secondary: const Icon(Icons.vaccines_outlined),
          title: Text(l.settingsVaccineReminders),
          subtitle: Text(l.settingsVaccineRemindersHint(time.format(context))),
        ),
        if (on)
          ListTile(
            key: const ValueKey('settings-vaccine-time'),
            leading: const Icon(Icons.schedule),
            title: Text(l.settingsVaccineReminderTime),
            trailing: Text(
              time.format(context),
              style: UsraType.label.copyWith(color: context.usra.inkMuted),
            ),
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
