import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/database/app_database.dart';
import '../../core/design/list_row.dart' show IconBox;
import '../../core/design/status_dot.dart';
import '../../core/design/type.dart';
import '../../core/design/tokens.dart';
import '../../core/follow_ups/follow_up.dart';
import '../../l10n/app_localizations.dart';
import '../doctors/call_buttons.dart' show openContact;
import '../family/emergency_card_screen.dart' show ambulanceNumber;
import '../family/family_screen.dart' show profilesProvider;
import '../family/member_screen.dart' show timelineProvider;
import '../follow_ups/follow_ups_providers.dart' show todayProvider;
import 'pregnancy.dart';

/// [profile]'s pregnancy going on today, once their records have loaded.
Pregnancy? watchActivePregnancy(WidgetRef ref, Profile profile) {
  final today = ref.watch(todayProvider);
  if (!canBePregnant(profile, today)) return null;
  final events = ref.watch(timelineProvider(profile.id)).value;
  if (events == null) return null;
  return activePregnancy(FollowUpSubject(profile, events).records, today);
}

/// Week, trimester and due date at a glance; opens the pregnancy page.
class PregnancySummaryCard extends StatelessWidget {
  const PregnancySummaryCard({
    super.key,
    required this.profile,
    required this.pregnancy,
    required this.today,
    this.showName = false,
  });

  final Profile profile;
  final Pregnancy pregnancy;
  final DateTime today;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final age = pregnancy.ageOn(today);
    final left = pregnancy.daysLeft(today);
    final c = context.usra;
    final muted = UsraType.label.copyWith(
      color: c.inkMuted,
      fontWeight: FontWeight.w400,
    );
    final due = l.pregnancyDue(
      DateFormat.yMMMd(locale).format(pregnancy.dueDate),
    );
    return Card(
      key: ValueKey('pregnancy-summary-${profile.id}'),
      child: InkWell(
        borderRadius: BorderRadius.circular(UsraRadius.card),
        onTap: () => context.go('/family/${profile.id}/pregnancy'),
        child: Padding(
          padding: const EdgeInsets.all(UsraSpacing.s4),
          child: Row(
            children: [
              IconBox(icon: Icons.pregnant_woman, color: c.orchidInk),
              const SizedBox(width: UsraSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showName
                          ? '${profile.displayName} · ${l.pregnancyWeek(age.weeks, age.days)}'
                          : l.pregnancyWeek(age.weeks, age.days),
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: UsraSpacing.s1),
                    Text(
                      l.pregnancyTrimester(pregnancy.trimesterOn(today)),
                      style: muted,
                    ),
                    // Past the due date is the one thing here to notice.
                    if (left < 0)
                      StatusDotText(label: due)
                    else
                      Text(due, style: muted),
                  ],
                ),
              ),
              ExcludeSemantics(
                child: Icon(Icons.chevron_right, size: 20, color: c.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The pregnancy card on a woman's page, when she's pregnant.
class MemberPregnancy extends ConsumerWidget {
  const MemberPregnancy({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pregnancy = watchActivePregnancy(ref, profile);
    if (pregnancy == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PregnancySummaryCard(
        profile: profile,
        pregnancy: pregnancy,
        today: ref.watch(todayProvider),
      ),
    );
  }
}

/// Every pregnancy in the family, on Home.
class HomePregnancies extends ConsumerWidget {
  const HomePregnancies({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final people = ref.watch(profilesProvider).value ?? const <Profile>[];
    final cards = [
      for (final p in people)
        if (watchActivePregnancy(ref, p) case final pregnancy?)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: PregnancySummaryCard(
              profile: p,
              pregnancy: pregnancy,
              today: today,
              showName: true,
            ),
          ),
    ];
    return Column(mainAxisSize: MainAxisSize.min, children: cards);
  }
}

/// Signs that need a hospital now, with the ambulance button.
class DangerSignsCard extends StatelessWidget {
  const DangerSignsCard({super.key});

  static const signs = [
    'bleeding',
    'headache',
    'vision',
    'fits',
    'pain',
    'fever',
    'water',
    'movement',
    'swelling',
    'breathing',
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final color = Severity.urgent.foregroundOf(context);
    return Card(
      key: const ValueKey('pregnancy-danger-signs'),
      color: Severity.urgent.backgroundOf(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: context.usra.urgent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.pregDangerTitle,
                    style: text.titleMedium?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final s in signs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: text.bodyLarge?.copyWith(color: color)),
                    Expanded(
                      child: Text(l.pregDangerSign(s), style: text.bodyLarge),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('pregnancy-ambulance'),
              style: FilledButton.styleFrom(
                backgroundColor: context.usra.urgent,
                minimumSize: const Size.fromHeight(56),
                textStyle: text.titleMedium,
              ),
              onPressed: () => openContact(
                context,
                Uri(scheme: 'tel', path: ambulanceNumber),
              ),
              icon: const Icon(Icons.call),
              label: Text(l.emergencyCallAmbulance(ambulanceNumber)),
            ),
            const SizedBox(height: 8),
            Text(
              l.pregDangerSource,
              style: text.bodySmall?.copyWith(color: context.usra.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
