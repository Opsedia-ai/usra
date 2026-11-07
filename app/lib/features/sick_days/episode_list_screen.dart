import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/tokens.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../family/member_screen.dart' show profileProvider;
import '../medicines/medicines_providers.dart' show clockProvider;
import 'sick_days_providers.dart';

/// A person's sick days, the latest first.
class EpisodeListScreen extends ConsumerWidget {
  const EpisodeListScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final person = ref.watch(profileProvider(profileId)).value;
    final episodes = ref.watch(episodesProvider(profileId));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          person == null
              ? l.sickDaysTitle
              : '${l.sickDaysTitle} · ${person.displayName}',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('sick-day-start'),
        onPressed: () => _start(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l.sickDayStart),
      ),
      body: episodes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l.sickDaysEmpty,
                  key: const ValueKey('sick-days-empty'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }
          final date = DateFormat.yMMMd(locale);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              for (final e in list)
                Card(
                  child: ListTile(
                    key: ValueKey('sick-day-${e.id}'),
                    minVerticalPadding: 14,
                    leading: Icon(
                      Icons.thermostat,
                      color: e.endedAt == null
                          ? Severity.actSoon.foregroundOf(context)
                          : context.usra.inkMuted,
                    ),
                    title: Text(
                      e.endedAt == null
                          ? l.sickDaySince(date.format(e.startedAt.toLocal()))
                          : l.sickDayRange(
                              date.format(e.startedAt.toLocal()),
                              date.format(e.endedAt!.toLocal()),
                            ),
                    ),
                    subtitle: Text(
                      e.endedAt == null ? l.sickDayOngoing : l.sickDayEnded,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.go('/family/$profileId/sick-days/${e.id}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final id = await ref
        .read(databaseProvider)
        .saveEpisode(
          profileId: profileId,
          startedAt: ref.read(clockProvider)(),
        );
    if (context.mounted) context.go('/family/$profileId/sick-days/$id');
  }
}
