import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/design/list_row.dart';
import '../../core/design/status_dot.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/follow_ups/follow_up.dart' show dayOf;
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../family/family_screen.dart' show profilesProvider;
import 'dismissals.dart';
import 'follow_ups_providers.dart';
import '../../core/util/separator.dart';

/// How many follow-ups Home shows across the family.
const homeFollowUpCount = 3;

/// The children module's schedule rule (`EgyptVaccineRule`), whose
/// follow-ups Home leaves to its vaccine card.
const homeVaccineRulePrefix = 'vaccines.egypt.';

/// The family's next follow-ups on Home. Hidden until someone is added.
class HomeFollowUps extends ConsumerWidget {
  const HomeFollowUps({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(familyFollowUpsProvider).value;
    if (items == null) return const SizedBox.shrink();
    final people = ref.watch(profilesProvider).value ?? const [];
    if (people.isEmpty) return const SizedBox.shrink();
    // Home has its own vaccine card with the countdown.
    final shown = items
        .where((i) => !i.followUp.ruleId.startsWith(homeVaccineRulePrefix))
        .take(homeFollowUpCount)
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _Section(
        key: const ValueKey('home-follow-ups'),
        items: shown,
        showNames: true,
        // Not when Home says there's nothing: its vaccine card covers those.
        allLink: shown.isNotEmpty && items.length > shown.length,
      ),
    );
  }
}

/// Every follow-up in the family: this week first, then later.
class FollowUpsScreen extends ConsumerWidget {
  const FollowUpsScreen({super.key});

  /// How far "this week" looks ahead.
  static const weekDays = 7;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final items = ref.watch(familyFollowUpsProvider);
    // Due dates are calendar days at UTC midnight.
    final soon = dayOf(today).add(const Duration(days: weekDays));
    return Scaffold(
      appBar: AppBar(title: Text(l.followUpsTitle)),
      body: switch (items) {
        AsyncError(:final error) => Center(child: Text('$error')),
        AsyncValue(value: final list?) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  l.followUpsEmpty,
                  key: const ValueKey('follow-ups-empty'),
                  textAlign: TextAlign.center,
                  style: text.bodyLarge,
                ),
              ),
            for (final (title, group) in [
              (
                l.followUpsThisWeek,
                [
                  for (final i in list)
                    if (!i.followUp.dueOn.isAfter(soon)) i,
                ],
              ),
              (
                l.followUpsLater,
                [
                  for (final i in list)
                    if (i.followUp.dueOn.isAfter(soon)) i,
                ],
              ),
            ])
              if (group.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Semantics(
                    header: true,
                    child: Text(title, style: text.titleMedium),
                  ),
                ),
                UsraListCard(
                  children: [
                    for (final item in group)
                      FollowUpTile(item: item, showName: true),
                  ],
                ),
                const SizedBox(height: UsraSpacing.s2),
              ],
            const SizedBox(height: 8),
            Text(
              l.followUpsDisclaimer,
              style: text.bodySmall?.copyWith(color: context.usra.inkMuted),
            ),
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Everything coming up for one person, on their page.
class MemberFollowUps extends ConsumerWidget {
  const MemberFollowUps({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(personFollowUpsProvider(profileId)).value;
    if (items == null) return const SizedBox.shrink();
    return _Section(
      key: const ValueKey('member-follow-ups'),
      items: items,
      showNames: false,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.items,
    required this.showNames,
    this.allLink = false,
  });

  final List<PersonFollowUp> items;
  final bool showNames;

  /// There are more than shown here: a way to the whole list.
  final bool allLink;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l.followUpsTitle, style: text.titleMedium),
        ),
        const SizedBox(height: UsraSpacing.s2),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: UsraSpacing.s2),
            child: Text(
              l.followUpsEmpty,
              style: UsraType.body.copyWith(color: context.usra.inkMuted),
            ),
          )
        else
          UsraListCard(
            children: [
              for (final item in items)
                FollowUpTile(item: item, showName: showNames),
            ],
          ),
        if (allLink)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey('follow-ups-all'),
              onPressed: () => context.push('/follow-ups'),
              child: Text(l.followUpsAll),
            ),
          )
        else
          const SizedBox(height: UsraSpacing.s2),
        Text(
          l.followUpsDisclaimer,
          style: UsraType.label.copyWith(
            color: context.usra.inkMuted,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// One follow-up as a row of a [UsraListCard]: what, for whom, when (with an
/// amber dot once it's due soon or late) and why, with a short "تسجيل" to
/// record it and a way to hide it until next time.
class FollowUpTile extends ConsumerWidget {
  const FollowUpTile({super.key, required this.item, this.showName = false});

  final PersonFollowUp item;
  final bool showName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final f = item.followUp;
    final profile = item.profile;
    final severity = f.severityOn(ref.watch(todayProvider));
    final date = DateFormat.yMMMd(locale).format(f.dueOn);
    final when = severity == Severity.actSoon
        ? l.followUpOverdue(date)
        : l.followUpDue(date);
    final type = f.recordType == null
        ? null
        : ref.watch(moduleRegistryProvider).recordTypes[f.recordType!];
    final muted = UsraType.label.copyWith(
      color: c.inkMuted,
      fontWeight: FontWeight.w400,
    );

    final add = type == null
        ? null
        : TextButton(
            key: ValueKey('follow-up-add-${f.cycleKey}'),
            onPressed: () =>
                context.go('/family/${profile.id}/add/${type.key}'),
            child: Text(
              l.vaccineLogShort,
              semanticsLabel: l.followUpAdd(type.labelOf(context)),
            ),
          );
    final dismiss = IconButton(
      key: ValueKey('dismiss-${f.cycleKey}'),
      tooltip: l.followUpDismiss,
      color: c.inkMuted,
      icon: const Icon(Icons.close, size: 20),
      onPressed: () => _dismiss(context, ref),
    );
    // Beside the words normally; under them at large text, where two
    // actions would squeeze the reason into a narrow column.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    return UsraListRow(
      key: ValueKey('follow-up-${f.cycleKey}'),
      title: showName
          ? '${profile.displayName}$partSeparator${f.title(context)}'
          : f.title(context),
      emphasized: true,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (severity == Severity.info)
            Text(when, key: const ValueKey('follow-up-when'), style: muted)
          else
            StatusDotText(key: const ValueKey('follow-up-when'), label: when),
          const SizedBox(height: UsraSpacing.s1),
          Text(f.reason(context), style: muted.copyWith(color: c.ink)),
          if (f.source != null) Text(l.followUpSource(f.source!), style: muted),
          if (stacked && add != null)
            Align(alignment: AlignmentDirectional.centerStart, child: add),
        ],
      ),
      onTap: showName ? () => context.go('/family/${profile.id}') : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [if (!stacked) ?add, dismiss],
      ),
    );
  }

  void _dismiss(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final key = item.followUp.cycleKey;
    final dismissed = ref.read(dismissedFollowUpsProvider.notifier);
    dismissed.dismiss(key);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l.followUpDismissed),
          action: SnackBarAction(
            label: l.followUpUndo,
            onPressed: () => dismissed.restore(key),
          ),
        ),
      );
  }
}
