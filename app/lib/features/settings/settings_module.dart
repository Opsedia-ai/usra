import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/severity_chip.dart';
import '../../core/design/tokens.dart';
import '../../core/modules/feature_module.dart';
import '../../core/preferences.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
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
                ListTile(
                  key: const ValueKey('settings-backup'),
                  leading: const Icon(Icons.backup_outlined),
                  title: Text(l.backupTitle),
                  subtitle: Text(l.settingsBackupHint),
                  onTap: () => context.go(backupPath),
                ),
                const Divider(height: 1),
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
                  onTap: () => context.go(aboutPath),
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
