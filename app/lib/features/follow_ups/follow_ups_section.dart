import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/design/severity_chip.dart';
import '../../core/design/tokens.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../family/family_screen.dart' show profilesProvider;
import 'dismissals.dart';
import 'follow_ups_providers.dart';

/// How many follow-ups Home shows across the family.
const homeFollowUpCount = 3;

/// The family's next follow-ups on Home. Hidden until someone is added.
class HomeFollowUps extends ConsumerWidget {
  const HomeFollowUps({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(familyFollowUpsProvider).value;
    if (items == null) return const SizedBox.shrink();
    final people = ref.watch(profilesProvider).value ?? const [];
    if (people.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _Section(
        key: const ValueKey('home-follow-ups'),
        items: items.take(homeFollowUpCount).toList(),
        showNames: true,
      ),
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
  const _Section({super.key, required this.items, required this.showNames});

  final List<PersonFollowUp> items;
  final bool showNames;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.event_repeat_outlined, color: UsraColors.primary),
            const SizedBox(width: 8),
            Text(l.followUpsTitle, style: text.titleLarge),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l.followUpsEmpty, style: text.bodyMedium),
          )
        else
          for (final item in items) ...[
            FollowUpTile(item: item, showName: showNames),
            const SizedBox(height: 8),
          ],
        Text(
          l.followUpsDisclaimer,
          style: text.bodySmall?.copyWith(color: UsraColors.textMuted),
        ),
      ],
    );
  }
}

/// One follow-up: what, for whom, when (coloured by urgency) and why, with
/// a shortcut to record it and a way to hide it until next time.
class FollowUpTile extends ConsumerWidget {
  const FollowUpTile({super.key, required this.item, this.showName = false});

  final PersonFollowUp item;
  final bool showName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final f = item.followUp;
    final profile = item.profile;
    final severity = f.severityOn(ref.watch(todayProvider));
    final date = DateFormat.yMMMd(locale).format(f.dueOn);
    final overdue = severity == Severity.actSoon;
    final type = f.recordType == null
        ? null
        : ref.watch(moduleRegistryProvider).recordTypes[f.recordType!];

    return Card(
      key: ValueKey('follow-up-${f.cycleKey}'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: severity.foreground, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: showName ? () => context.go('/family/${profile.id}') : null,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          showName
                              ? '${profile.displayName} · ${f.title(context)}'
                              : f.title(context),
                          style: text.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        SeverityChip(
                          severity: severity,
                          label: overdue
                              ? l.followUpOverdue(date)
                              : l.followUpDue(date),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: ValueKey('dismiss-${f.cycleKey}'),
                    tooltip: l.followUpDismiss,
                    icon: const Icon(Icons.close),
                    onPressed: () => _dismiss(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: Text(f.reason(context), style: text.bodyMedium),
              ),
              if (f.source != null)
                Text(
                  l.followUpSource(f.source!),
                  style: text.bodySmall?.copyWith(color: UsraColors.textMuted),
                ),
              if (type != null)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    key: ValueKey('follow-up-add-${f.cycleKey}'),
                    onPressed: () =>
                        context.go('/family/${profile.id}/add/${type.key}'),
                    icon: Icon(type.icon),
                    label: Text(l.followUpAdd(type.labelOf(context))),
                  ),
                ),
            ],
          ),
        ),
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
