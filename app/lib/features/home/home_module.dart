import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/dr_usra.dart';
import '../../core/design/severity_chip.dart';
import '../../core/design/tokens.dart';
import '../../core/modules/feature_module.dart';
import '../../core/preferences.dart';
import '../../l10n/app_localizations.dart';
import '../backup/backup_notices.dart';
import '../family/family_screen.dart';
import '../follow_ups/follow_ups_section.dart';
import 'simple_home.dart';

class HomeModule extends FeatureModule {
  const HomeModule();

  @override
  String get id => 'home';

  @override
  List<ModuleTab> get tabs => [
    ModuleTab(
      path: '/home',
      icon: Icons.home_outlined,
      label: (c) => AppLocalizations.of(c).navHome,
      order: 0,
      simple: true,
    ),
  ];

  @override
  List<RouteBase> get routes => [
    GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
  ];
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(simpleModeProvider)) return const SimpleHome();
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        const BackupNotices(),
        Center(child: DrUsra(size: 180, semanticLabel: l.homeGreeting)),
        const SizedBox(height: 12),
        Text(
          l.homeGreeting,
          style: text.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l.homeIntro,
          style: text.bodyLarge?.copyWith(color: UsraColors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        const _EmergencyCards(),
        const HomeFollowUps(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.homeColorGuide, style: text.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in Severity.values)
                      SeverityChip(severity: s, label: severityLabel(l, s)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l.notMedicalDevice,
          style: text.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// One tap from Home to anyone's emergency card. Hidden until the family
/// has at least one person.
class _EmergencyCards extends ConsumerWidget {
  const _EmergencyCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final people = ref.watch(profilesProvider).value ?? const [];
    if (people.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: Severity.urgent.background,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.emergency_outlined,
                    color: UsraColors.emergency,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l.homeEmergencyTitle,
                    style: text.titleMedium?.copyWith(
                      color: Severity.urgent.foreground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(l.homeEmergencyHint, style: text.bodyMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in people)
                    ActionChip(
                      key: ValueKey('home-emergency-${p.id}'),
                      avatar: const Icon(Icons.badge_outlined, size: 20),
                      label: Text(p.displayName),
                      labelStyle: text.titleMedium,
                      padding: const EdgeInsets.all(8),
                      onPressed: () => context.go('/family/${p.id}/emergency'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String severityLabel(AppLocalizations l, Severity s) => switch (s) {
  Severity.info => l.severityInfo,
  Severity.good => l.severityGood,
  Severity.headsUp => l.severityHeadsUp,
  Severity.actSoon => l.severityActSoon,
  Severity.urgent => l.severityUrgent,
};
