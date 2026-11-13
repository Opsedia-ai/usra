import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/list_row.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../follow_ups/follow_ups_section.dart';
import '../insurance/insurance_section.dart';
import 'member_screen.dart'
    show attachmentCountsProvider, profileProvider, timelineProvider;
import 'record_display.dart';

/// What the Visits and labs page lists, and what its tile dates.
bool isVisitOrLab(MedicalEvent e) =>
    const {'visit', 'lab', 'scan'}.contains(e.type);

/// What the Documents page lists, and what its tile counts.
bool hasPhotos(MedicalEvent e, int photos) => photos > 0;

/// A page opened from a person's hub, with their name on top so it's clear
/// whose records these are.
class _PersonPage extends ConsumerWidget {
  const _PersonPage({required this.profileId, required this.children});

  final String profileId;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(profileProvider(profileId)).value?.displayName;
    return Scaffold(
      appBar: AppBar(title: Text(name ?? '')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: children,
      ),
    );
  }
}

class PersonInsuranceScreen extends StatelessWidget {
  const PersonInsuranceScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context) => _PersonPage(
    profileId: profileId,
    children: [InsuranceSection(profileId: profileId)],
  );
}

class PersonFollowUpsScreen extends StatelessWidget {
  const PersonFollowUpsScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context) => _PersonPage(
    profileId: profileId,
    children: [MemberFollowUps(profileId: profileId)],
  );
}

/// Visits, lab reports and scans, with the way into lab results and trends.
class PersonVisitsScreen extends ConsumerWidget {
  const PersonVisitsScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return _PersonPage(
      profileId: profileId,
      children: [
        Text(
          l.personTileVisits,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UsraSpacing.s2),
        OutlinedButton.icon(
          key: const ValueKey('member-labs'),
          onPressed: () => context.push('/family/$profileId/labs'),
          icon: const Icon(Icons.science_outlined),
          label: Text(l.memberLabs),
        ),
        const SizedBox(height: UsraSpacing.s3),
        _RecordList(
          profileId: profileId,
          emptyText: l.personVisitsEmpty,
          keep: (e, _) => isVisitOrLab(e),
        ),
      ],
    );
  }
}

/// Every record of this person that has a photo.
class PersonDocumentsScreen extends ConsumerWidget {
  const PersonDocumentsScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return _PersonPage(
      profileId: profileId,
      children: [
        Text(
          l.personTileDocuments,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UsraSpacing.s3),
        _RecordList(
          profileId: profileId,
          emptyText: l.personDocumentsEmpty,
          keep: hasPhotos,
        ),
      ],
    );
  }
}

class _RecordList extends ConsumerWidget {
  const _RecordList({
    required this.profileId,
    required this.emptyText,
    required this.keep,
  });

  final String profileId;
  final String emptyText;
  final bool Function(MedicalEvent event, int photos) keep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.watch(moduleRegistryProvider).recordTypes;
    final photos =
        ref.watch(attachmentCountsProvider(profileId)).value ?? const {};
    return ref
        .watch(timelineProvider(profileId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
          data: (all) {
            final events = [
              for (final e in all)
                if ((types[e.type]?.inTimeline ?? false) &&
                    keep(e, photos[e.id] ?? 0))
                  e,
            ];
            if (events.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  emptyText,
                  textAlign: TextAlign.center,
                  style: UsraType.body.copyWith(color: context.usra.inkMuted),
                ),
              );
            }
            return UsraListCard(
              children: [
                for (final e in events)
                  RecordRow(
                    event: e,
                    type: types[e.type],
                    photos: photos[e.id] ?? 0,
                  ),
              ],
            );
          },
        );
  }
}
