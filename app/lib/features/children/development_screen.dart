import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/database/app_database.dart';
import '../../core/design/status_dot.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/providers.dart';
import '../../core/util/dates.dart';
import '../../l10n/app_localizations.dart';
import '../account/save_gate.dart';
import '../family/member_screen.dart' show profileProvider, timelineProvider;
import 'growth.dart';
import 'milestones.dart';
import '../../core/util/date_picker.dart';

/// The CDC milestones checklist: tick what the child does, with the day it
/// was first seen. Informational only; the pediatrician assesses development.
class DevelopmentScreen extends ConsumerWidget {
  const DevelopmentScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider(profileId));
    final timeline = ref.watch(timelineProvider(profileId));
    return Scaffold(
      appBar: AppBar(
        title: Text(l.devTitle),
        leading: BackButton(onPressed: () => context.go('/family/$profileId')),
      ),
      body: switch ((profile, timeline)) {
        (AsyncError(:final error), _) ||
        (_, AsyncError(:final error)) => Center(child: Text('$error')),
        (AsyncValue(value: final p?), AsyncValue(value: final events?)) =>
          showsMilestones(p.birthDate, DateTime.now())
              ? _Body(profile: p, events: events)
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l.devUnderSixOnly, textAlign: TextAlign.center),
                  ),
                ),
        (AsyncData(value: null), _) => Center(child: Text(l.profileNotFound)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// "4 months", "2 years", "30 months".
String milestoneAgeLabel(AppLocalizations l, int months) =>
    months >= 12 && months % 12 == 0
    ? l.ageYears(months ~/ 12)
    : l.fuAgeMonths(months);

class _Body extends StatelessWidget {
  const _Body({required this.profile, required this.events});

  final Profile profile;
  final List<MedicalEvent> events;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final birth = profile.birthDate!;
    final age = ageInMonths(birth, DateTime.now());
    final ticked = tickedMilestones(events);
    final current = currentMilestoneAge(age);
    final next = milestoneAges.firstWhere(
      (a) => a > age,
      orElse: () => milestoneAges.last,
    );
    final late = [
      for (final m in cdcMilestones)
        if (milestoneState(m, ageMonths: age, ticked: ticked.containsKey(m.id))
            case MilestoneState.late)
          m,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(profile.displayName, style: text.titleLarge),
        const SizedBox(height: 6),
        Text(l.devIntro, style: text.bodyMedium),
        if (late.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            key: const ValueKey('dev-late-banner'),
            child: Padding(
              padding: const EdgeInsets.all(UsraSpacing.s4),
              child: StatusDotText(
                label: l.devLateBanner(milestoneAgeLabel(l, late.first.months)),
                style: UsraType.body,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (final months in milestoneAges)
          ExpansionTile(
            key: ValueKey('dev-age-$months'),
            tilePadding: EdgeInsets.zero,
            initiallyExpanded: months == current || months == next,
            title: Text(
              l.devByAge(milestoneAgeLabel(l, months)),
              style: text.titleMedium,
            ),
            subtitle: Text(
              l.devTickedCount(
                cdcMilestones
                    .where(
                      (m) => m.months == months && ticked.containsKey(m.id),
                    )
                    .length,
                cdcMilestones.where((m) => m.months == months).length,
              ),
            ),
            children: [
              for (final m in cdcMilestones)
                if (m.months == months)
                  _MilestoneTile(
                    profile: profile,
                    milestone: m,
                    ageMonths: age,
                    ticked: ticked[m.id],
                  ),
            ],
          ),
        const SizedBox(height: 16),
        Text(
          l.devSource,
          style: text.bodySmall?.copyWith(color: context.usra.inkMuted),
        ),
      ],
    );
  }
}

class _MilestoneTile extends ConsumerWidget {
  const _MilestoneTile({
    required this.profile,
    required this.milestone,
    required this.ageMonths,
    required this.ticked,
  });

  final Profile profile;
  final Milestone milestone;
  final double ageMonths;
  final ({DateTime date, List<String> eventIds})? ticked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final state = milestoneState(
      milestone,
      ageMonths: ageMonths,
      ticked: ticked != null,
    );
    final label = switch (state) {
      MilestoneState.done => l.devDone(
        DateFormat.yMMMd(locale).format(ticked!.date),
      ),
      MilestoneState.upcoming => l.devUpcoming,
      MilestoneState.watch => l.devWatch,
      MilestoneState.late => l.devLate,
      MilestoneState.notTicked => l.devNotTicked,
    };
    return ListTile(
      key: ValueKey('milestone-${milestone.id}'),
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        key: ValueKey('milestone-check-${milestone.id}'),
        value: ticked != null,
        onChanged: (_) => _toggle(context, ref),
      ),
      title: Text(l.milestone(milestone.id)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(milestoneAreaLabel(l, milestone.area)),
            if (state == MilestoneState.late)
              StatusDotText(label: label)
            else
              Text(
                label,
                style: UsraType.label.copyWith(
                  color: context.usra.inkMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
      ),
      onTap: () => _toggle(context, ref),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final failed = AppLocalizations.of(context).saveFailed;
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (ticked case final t?) {
        final l = AppLocalizations.of(context);
        final sure = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            content: Text(l.devUntickConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: Text(l.familyCancel),
              ),
              TextButton(
                key: const ValueKey('milestone-untick'),
                onPressed: () => Navigator.pop(dialog, true),
                child: Text(l.devUntick),
              ),
            ],
          ),
        );
        if (sure != true) return;
        for (final id in t.eventIds) {
          await db.softDeleteEvent(id);
        }
        return;
      }
      final today = DateUtils.dateOnly(DateTime.now());
      final birth = storedDay(profile.birthDate!);
      final picked = await pickDate(
        context,
        initialDate: today,
        firstDate: birth.isAfter(today) ? today : birth,
        lastDate: today,
        helpText: AppLocalizations.of(context).devWhenSeen,
      );
      if (picked == null) return;
      if (!await ref.read(saveGateProvider).allow()) return;
      await db.addEvent(
        profileId: profile.id,
        type: milestoneType,
        occurredAt: picked,
        dataJson: jsonEncode({milestoneField: milestone.id}),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }
}

String milestoneAreaLabel(AppLocalizations l, MilestoneArea area) =>
    switch (area) {
      MilestoneArea.social => l.devAreaSocial,
      MilestoneArea.language => l.devAreaLanguage,
      MilestoneArea.cognitive => l.devAreaCognitive,
      MilestoneArea.movement => l.devAreaMovement,
    };
