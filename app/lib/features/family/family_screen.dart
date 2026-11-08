import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/pebble.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/preferences.dart';
import '../../core/providers.dart';
import '../../core/util/localized_digits.dart';
import '../../l10n/app_localizations.dart';
import 'person_status.dart';

final profilesProvider = StreamProvider<List<Profile>>(
  (ref) => ref.watch(databaseProvider).watchProfiles(),
);

/// Everyone in one list, each with their status, so nobody has to swipe.
class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profiles = ref.watch(profilesProvider);
    final simple = ref.watch(simpleModeProvider);
    final router = GoRouter.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: simple
            ? null
            : BackButton(
                onPressed: () =>
                    router.canPop() ? router.pop() : router.go('/home'),
              ),
        title: Text(l.familyAllTitle),
        actions: [
          if (profiles.value case final list? when list.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 16),
                child: Text(
                  l.familyCount(
                    list.length,
                    localizedDigits(context, list.length),
                  ),
                  key: const ValueKey('family-count'),
                  style: UsraType.body.copyWith(color: context.usra.inkMuted),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton.icon(
            key: const ValueKey('family-add'),
            onPressed: () => context.go('/family/new'),
            icon: const Icon(Icons.add),
            label: Text(l.familyAdd),
          ),
        ),
      ),
      body: profiles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    l.familyEmpty,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  Card(
                    child: Column(
                      children: [
                        for (final (i, p) in list.indexed) ...[
                          if (i > 0) const Divider(height: 1),
                          _FamilyRow(person: p),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FamilyRow extends ConsumerWidget {
  const _FamilyRow({required this.person});

  final Profile person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final status = watchPersonStatus(
      context,
      ref,
      person,
      none: PersonStatus(
        severity: Severity.good,
        label: l.homeNothingNeeded,
        icon: Icons.check,
      ),
    );
    final attention = status?.needsAttention ?? false;
    return ListTile(
      key: ValueKey('family-${person.id}'),
      minTileHeight: 64,
      onTap: () => context.go('/family/${person.id}'),
      leading: Pebble(
        seed: pebbleSeed(person.id),
        color: personColor(context, person.sex),
        width: 46,
        height: 42,
        shadow: false,
        child: ExcludeSemantics(
          child: Text(
            initialOf(person.displayName),
            style: UsraType.heading.copyWith(color: c.ink),
          ),
        ),
      ),
      title: Text(
        person.displayName,
        style: UsraType.body.copyWith(
          color: c.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: status == null
          ? null
          : Text(
              status.label,
              key: ValueKey('family-status-${person.id}'),
              style: UsraType.label.copyWith(
                color: attention
                    ? status.severity.foregroundOf(context)
                    : c.inkMuted,
                fontWeight: attention ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
      trailing: Icon(Icons.chevron_right, color: c.inkMuted),
    );
  }
}

/// First letter for an avatar; "?" if the name is blank.
String initialOf(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : trimmed.characters.first;
}

/// Whole years between [birthDate] and [now]; null if unknown or in the future.
int? ageInYears(DateTime? birthDate, [DateTime? now]) {
  if (birthDate == null) return null;
  final today = now ?? DateTime.now();
  var years = today.year - birthDate.year;
  if (today.month < birthDate.month ||
      (today.month == birthDate.month && today.day < birthDate.day)) {
    years--;
  }
  return years < 0 ? null : years;
}
