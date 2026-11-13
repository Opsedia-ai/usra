import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/list_row.dart';
import '../../core/design/status_dot.dart';
import '../../core/design/tokens.dart';
import '../../core/design/usra_mark.dart';
import '../../core/design/type.dart';
import '../../core/modules/feature_module.dart';
import '../../core/preferences.dart';
import '../../core/providers.dart';
import '../../core/security/app_lock.dart';
import '../../core/util/localized_digits.dart';
import '../../l10n/app_localizations.dart';
import '../account/account_providers.dart';
import '../account/account_screen.dart';
import '../backup/backup_providers.dart';
import '../family/family_screen.dart' show profilesProvider;
import '../backup/backup_screen.dart';
import '../children/vaccines_screen.dart' show askForReminderAccess;
import '../medicines/medicines_providers.dart'
    show reminderAccessProvider, reminderSchedulerProvider;
import '../medicines/reminder_permission.dart';
import 'about_privacy_screen.dart';
import 'delete_data_screen.dart';
import 'dr_usra_ai_screen.dart';
import '../home/simple_home.dart' show leaveSimpleMode;
import '../../core/util/time_picker.dart';

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
    GoRoute(path: drUsraAiPath, builder: (_, _) => const DrUsraAiScreen()),
  ];
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final last = ref.watch(lastBackupProvider);
    final people = ref.watch(profilesProvider).value;
    return Scaffold(
      appBar: AppBar(title: UsraMarkTitle(l.settingsTitle)),
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
                UsraListRow(
                  key: const ValueKey('more-family'),
                  icon: Icons.groups_outlined,
                  title: l.moreFamily,
                  subtitleText: people == null
                      ? null
                      : l.familyCount(
                          people.length,
                          localizedDigits(context, people.length),
                        ),
                  onTap: () => context.push('/family'),
                ),
                UsraListRow(
                  key: const ValueKey('more-doctors'),
                  icon: Icons.medical_services_outlined,
                  title: l.navDoctors,
                  onTap: () => context.push('/doctors'),
                ),
                UsraListRow(
                  key: const ValueKey('more-money'),
                  icon: Icons.account_balance_wallet_outlined,
                  title: l.memberSpending,
                  onTap: () => context.push('/money'),
                ),
              ],
            ),
          _Group(
            title: l.moreGroupSafety,
            children: [
              UsraListRow(
                key: const ValueKey('settings-backup'),
                icon: Icons.cloud_outlined,
                title: l.backupTitle,
                subtitle: last == null
                    ? StatusDotText(label: l.backupNeverShort)
                    : null,
                subtitleText: last == null
                    ? null
                    : l.backupLast(backupDay(context, last)),
                onTap: () => context.push(backupPath),
              ),
              ListenableBuilder(
                listenable: ref.watch(appLockProvider),
                builder: (context, _) => UsraListRow(
                  key: const ValueKey('settings-app-lock'),
                  icon: Icons.lock_outline,
                  title: l.settingsAppLock,
                  subtitleText: ref.read(appLockProvider).enabled
                      ? l.settingsStateOn
                      : l.settingsStateOff,
                  // The long form says what being off means.
                  semanticLabel:
                      '${l.settingsAppLock}، ${ref.read(appLockProvider).enabled ? l.settingsAppLockOn : l.settingsAppLockOff}',
                  onTap: () => context.push(appLockSettingsPath),
                ),
              ),
              _PreferenceSwitch(
                key: const ValueKey('settings-discreet'),
                preference: discreetNotificationsProvider,
                icon: Icons.notifications_off_outlined,
                title: l.settingsDiscreet,
                subtitle: l.settingsDiscreetHintShort,
              ),
              const _VaccineReminderSettings(),
              // iOS can't block screenshots; the switcher is covered on both.
              if (defaultTargetPlatform == TargetPlatform.android)
                _PreferenceSwitch(
                  key: const ValueKey('settings-block-screenshots'),
                  preference: blockScreenshotsProvider,
                  icon: Icons.screenshot_monitor_outlined,
                  title: l.settingsBlockScreenshots,
                  subtitle: l.settingsBlockScreenshotsHintShort,
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
                subtitle: Text(
                  ref.watch(simpleModeProvider)
                      ? l.settingsStateOn
                      : l.settingsStateOff,
                ),
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
                      key: const ValueKey('settings-language'),
                      // Ink on the selected segment: the theme's primary on
                      // its soft fill was too faint in dark mode.
                      style: SegmentedButton.styleFrom(
                        selectedForegroundColor: context.usra.ink,
                      ),
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
              UsraListRow(
                key: const ValueKey('settings-tutorial'),
                icon: Icons.school_outlined,
                title: l.settingsTutorial,
                onTap: ref.read(tutorialProvider.notifier).reopen,
              ),
              // Planned, informational only. Simple Mode leaves it out.
              if (!ref.watch(simpleModeProvider))
                UsraListRow(
                  key: const ValueKey('settings-dr-ai'),
                  leading: const UsraMark(),
                  title: l.drAiTitle,
                  subtitle: const Padding(
                    padding: EdgeInsets.only(top: UsraSpacing.s1),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ComingSoonPill(),
                    ),
                  ),
                  semanticLabel: '${l.drAiTitle}، ${l.drAiSoon}',
                  onTap: () => context.push(drUsraAiPath),
                ),
              UsraListRow(
                key: const ValueKey('settings-about'),
                icon: Icons.privacy_tip_outlined,
                title: l.aboutTitle,
                subtitleText: l.aboutHint,
                onTap: () => context.push(aboutPath),
              ),
            ],
          ),
          UsraListCard(
            children: [
              UsraListRow(
                key: const ValueKey('settings-delete-all'),
                icon: Icons.delete_forever_outlined,
                title: l.settingsDeleteAll,
                subtitleText: l.settingsDeleteAllHint,
                onTap: () => context.push(deleteDataPath),
              ),
            ],
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

/// A heading and its rows in one card, with hairlines between them.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: UsraSpacing.s2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UsraGroupLabel(title),
        UsraListCard(children: children),
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
    final access = ref.watch(reminderAccessProvider).value;
    final noNotifications = access?.notifications == false;
    final blocked =
        access != null &&
        notificationsBlocked(access, ref.read(keyValueStoreProvider));
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
            if (v && context.mounted) await askForReminderAccess(context, ref);
            ref.invalidate(reminderAccessProvider);
          }),
          secondary: const Icon(Icons.vaccines_outlined),
          title: Text(l.settingsVaccineReminders),
          subtitle: Text(l.settingsVaccineRemindersHint(time.format(context))),
        ),
        // On here, but off on the phone: say so, with the way to fix it,
        // rather than a switch that looks on (e2e #24).
        if (on && noNotifications)
          Padding(
            key: const ValueKey('settings-vaccine-blocked'),
            padding: const EdgeInsetsDirectional.fromSTEB(72, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusDotText(label: l.settingsNotificationsOffPhone),
                TextButton(
                  key: const ValueKey('settings-vaccine-allow'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () async {
                    await allowReminders(
                      ref.read(reminderSchedulerProvider),
                      ref.read(keyValueStoreProvider),
                      exactAlarms: false,
                    );
                    ref.invalidate(reminderAccessProvider);
                  },
                  child: Text(
                    blocked ? l.reminderOpenSettings : l.reminderAllow,
                  ),
                ),
              ],
            ),
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
              final picked = await pickTime(context, initialTime: time);
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
