import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/tokens.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';

final profilesProvider = StreamProvider<List<Profile>>(
  (ref) => ref.watch(databaseProvider).watchProfiles(),
);

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profiles = ref.watch(profilesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.familyTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/family/new'),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(l.familyAdd),
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
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final p = list[i];
                  final age = ageInYears(p.birthDate);
                  return Card(
                    child: ListTile(
                      onTap: () => context.go('/family/${p.id}'),
                      leading: CircleAvatar(
                        backgroundColor: UsraColors.primaryTint,
                        foregroundColor: UsraColors.primary,
                        child: Text(initialOf(p.displayName)),
                      ),
                      title: Text(p.displayName),
                      subtitle: age == null ? null : Text(l.ageYears(age)),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                },
              ),
      ),
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
  final today = now ?? clock.now();
  var years = today.year - birthDate.year;
  if (today.month < birthDate.month ||
      (today.month == birthDate.month && today.day < birthDate.day)) {
    years--;
  }
  return years < 0 ? null : years;
}
