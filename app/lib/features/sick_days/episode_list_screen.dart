import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/list_row.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/providers.dart';
import '../../core/util/localized_digits.dart';
import '../../l10n/app_localizations.dart';
import '../doctors/call_buttons.dart' show openContact;
import '../family/emergency_card_screen.dart' show ambulanceNumber;
import '../family/member_screen.dart' show profileProvider;
import '../medicines/medicines_providers.dart' show clockProvider;
import 'episode_sheets.dart' show showReadingSheet;
import 'fever.dart';
import 'sick_days_providers.dart';

/// A person's sick days, the latest first. While one is going on it comes
/// first, with a reading button and when to call an ambulance.
class EpisodeListScreen extends ConsumerWidget {
  const EpisodeListScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final person = ref.watch(profileProvider(profileId)).value;
    final episodes = ref.watch(episodesProvider(profileId));
    final ongoing = episodes.value?.where((e) => e.endedAt == null).firstOrNull;
    final start = _StartButton(onPressed: () => _start(context, ref));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          person == null
              ? l.sickDaysTitle
              : '${l.sickDaysTitle} · ${person.displayName}',
        ),
      ),
      // Only when nothing is going on: otherwise the reading button is the
      // page's one main action, and starting another sits at the end.
      floatingActionButton: ongoing == null
          ? FloatingActionButton.extended(
              key: const ValueKey('sick-day-start'),
              onPressed: () => _start(context, ref),
              icon: const Icon(Icons.add),
              label: Text(l.sickDayStart),
            )
          : null,
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
          final past = [
            for (final e in list)
              if (e != ongoing) e,
          ];
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, ongoing == null ? 96 : 24),
            children: [
              if (ongoing != null) ...[
                _OngoingCard(
                  episode: ongoing,
                  sex: person?.sex ?? 'other',
                  // This year's days without the year, as on the person page.
                  since:
                      ongoing.startedAt.toLocal().year ==
                          ref.watch(clockProvider)().year
                      ? DateFormat.MMMd(locale)
                            .format(ongoing.startedAt.toLocal())
                      : date.format(ongoing.startedAt.toLocal()),
                  onTap: () => context.push(
                    '/family/$profileId/sick-days/${ongoing.id}',
                  ),
                ),
                const SizedBox(height: UsraSpacing.s3),
                _ReadingButton(episode: ongoing),
                const SizedBox(height: UsraSpacing.s3),
                if (person != null)
                  _AmbulanceCard(
                    person: person,
                    now: ref.watch(clockProvider)(),
                    onAllSigns: () => context.push(
                      '/family/$profileId/sick-days/${ongoing.id}',
                    ),
                  ),
                const SizedBox(height: UsraSpacing.s4),
              ],
              if (past.isEmpty)
                Text(
                  l.sickDaysPastHere,
                  key: const ValueKey('sick-days-past-empty'),
                  textAlign: TextAlign.center,
                  style: UsraType.label.copyWith(
                    color: context.usra.inkMuted,
                    fontWeight: FontWeight.w400,
                  ),
                )
              else
                UsraListCard(
                  children: [
                    for (final e in past)
                      UsraListRow(
                        key: ValueKey('sick-day-${e.id}'),
                        icon: Icons.thermostat,
                        title: e.endedAt == null
                            ? l.sickDaySince(date.format(e.startedAt.toLocal()))
                            : l.sickDayRange(
                                date.format(e.startedAt.toLocal()),
                                date.format(e.endedAt!.toLocal()),
                              ),
                        subtitleText: e.endedAt == null
                            ? l.sickDayOngoing(person?.sex ?? 'other')
                            : l.sickDayEnded,
                        onTap: () => context.push(
                          '/family/$profileId/sick-days/${e.id}',
                        ),
                      ),
                  ],
                ),
              if (ongoing != null) ...[
                const SizedBox(height: UsraSpacing.s4),
                Center(child: start),
              ],
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
    if (context.mounted) context.push('/family/$profileId/sick-days/$id');
  }
}

/// Starting another sick day while one is going on: a quiet button at the
/// end of the page, so the reading button stays the main action.
class _StartButton extends StatelessWidget {
  const _StartButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: const ValueKey('sick-day-start'),
    onPressed: onPressed,
    icon: const Icon(Icons.add),
    label: Text(AppLocalizations.of(context).sickDayStart),
  );
}

/// The sick day going on now: since when, and the latest reading or that
/// there isn't one yet.
class _OngoingCard extends ConsumerWidget {
  const _OngoingCard({
    required this.episode,
    required this.sex,
    required this.since,
    required this.onTap,
  });

  final SickEpisode episode;
  final String sex;
  final String since;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final readings = ref.watch(readingsProvider(episode.id)).value;
    return Card(
      child: UsraListRow(
        key: ValueKey('sick-day-${episode.id}'),
        leading: IconBox(icon: Icons.thermostat, color: context.usra.attention),
        title: l.sickDayOngoing(sex),
        emphasized: true,
        subtitleText: [
          l.sickDaySince(since),
          if (readings != null && readings.isEmpty) l.sickDayNoReadingsYet,
        ].join(' · '),
        onTap: onTap,
      ),
    );
  }
}

class _ReadingButton extends ConsumerWidget {
  const _ReadingButton({required this.episode});

  final SickEpisode episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readings = ref.watch(readingsProvider(episode.id)).value;
    return FilledButton.icon(
      key: const ValueKey('sick-days-add-reading'),
      onPressed: () => showReadingSheet(
        context,
        episode: episode,
        last: readings == null || readings.isEmpty ? null : readings.last,
      ),
      icon: const Icon(Icons.add),
      label: Text(AppLocalizations.of(context).sickDayAddReadingShort),
    );
  }
}

/// When to call an ambulance, with the call button. The signs are the same
/// as on the sick day's page, which has the rest: when to call the doctor,
/// and the sources.
class _AmbulanceCard extends StatelessWidget {
  const _AmbulanceCard({
    required this.person,
    required this.now,
    required this.onAllSigns,
  });

  final Profile person;
  final DateTime now;
  final VoidCallback onAllSigns;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final age = ageGroupOf(person.birthDate, now);
    final signs = [
      for (final s in warningSignsFor(age))
        if (s.level == WarningLevel.emergency) l.warnSign(s.key),
    ];
    return Card(
      key: const ValueKey('sick-days-ambulance-card'),
      child: Padding(
        padding: const EdgeInsets.all(UsraSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: UsraSpacing.s2,
          children: [
            Semantics(
              header: true,
              child: Text(
                l.warnEmergencyShort,
                style: UsraType.body.copyWith(
                  color: c.urgent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              signs.join(' · '),
              style: UsraType.body.copyWith(color: c.inkMuted, height: 1.5),
            ),
            OutlinedButton.icon(
              key: const ValueKey('sick-days-ambulance'),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.urgent,
                side: BorderSide(color: c.urgent.withValues(alpha: 0.5)),
              ),
              onPressed: () => openContact(
                context,
                Uri(scheme: 'tel', path: ambulanceNumber),
              ),
              icon: const Icon(Icons.call_outlined),
              label: Text(
                l.emergencyCallAmbulance(
                  localizedDigitsIn(context, ambulanceNumber),
                ),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('sick-days-all-signs'),
                style: TextButton.styleFrom(
                  foregroundColor: c.inkMuted,
                  padding: EdgeInsets.zero,
                ),
                onPressed: onAllSigns,
                icon: const Icon(Icons.chevron_right, size: 18),
                iconAlignment: IconAlignment.end,
                label: Text(l.sickDayAllSigns),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
