import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/design/tokens.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../add/add_sheet.dart';
import '../family/family_screen.dart';
import '../family/member_screen.dart';

/// Every record in the family, newest first, with a filter by person.
class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({super.key});

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  /// Null is everyone.
  String? _person;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final people = ref.watch(profilesProvider).value ?? const <Profile>[];
    final types = ref.watch(moduleRegistryProvider).recordTypes;
    final person = people.any((p) => p.id == _person) ? _person : null;
    final names = {for (final p in people) p.id: p.displayName};

    var loading = ref.watch(profilesProvider).isLoading;
    final events = <MedicalEvent>[];
    final photos = <String, int>{};
    for (final p in people) {
      final timeline = ref.watch(timelineProvider(p.id));
      photos.addAll(
        ref.watch(attachmentCountsProvider(p.id)).value ?? const {},
      );
      if (timeline.value == null) loading = true;
      if (person != null && p.id != person) continue;
      for (final e in timeline.value ?? const <MedicalEvent>[]) {
        // Quick logs and types from a newer version stay out, as on a
        // person's page.
        if (types[e.type]?.inTimeline ?? false) events.add(e);
      }
    }
    events.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    return Scaffold(
      appBar: AppBar(
        title: Text(l.recordsTitle),
        actions: [
          IconButton(
            key: const ValueKey('records-add'),
            tooltip: l.recordsAdd,
            onPressed: () => showAddSheet(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          if (people.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  for (final (id, name) in [
                    (null, l.recordsAll),
                    for (final p in people) (p.id, p.displayName),
                  ])
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: UsraSpacing.s2,
                      ),
                      child: ChoiceChip(
                        key: ValueKey('records-filter-${id ?? 'all'}'),
                        label: Text(name),
                        selected: person == id,
                        onSelected: (_) => setState(() => _person = id),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: UsraSpacing.s3),
          if (events.isEmpty && loading)
            const Center(child: CircularProgressIndicator())
          else if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Text(
                l.recordsEmpty,
                key: const ValueKey('records-empty'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          for (final e in events)
            Padding(
              padding: const EdgeInsets.only(bottom: UsraSpacing.s2),
              child: EventCard(
                event: e,
                type: types[e.type],
                photos: photos[e.id] ?? 0,
                personName: person == null ? names[e.profileId] : null,
              ),
            ),
        ],
      ),
    );
  }
}
