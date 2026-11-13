import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/list_row.dart';
import '../../core/design/pill_chip.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/files/photo_store.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../add/add_sheet.dart';
import '../family/family_screen.dart';
import '../family/member_screen.dart';
import '../family/record_display.dart';

/// Every record in the family, newest first and by month, with filters by
/// person and by type.
class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({super.key});

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  /// Null is everyone.
  String? _person;

  /// Null is every type.
  String? _type;

  Widget _chips(
    String prefix,
    String? selected,
    List<(String?, String)> options,
    void Function(String?) onSelected,
  ) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    clipBehavior: Clip.none,
    child: Row(
      children: [
        for (final (id, name) in options)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: UsraSpacing.s2),
            child: UsraPill(
              key: ValueKey('records-$prefix-${id ?? 'all'}'),
              label: name,
              selected: selected == id,
              onTap: () => onSelected(id),
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final people = ref.watch(profilesProvider).value ?? const <Profile>[];
    final types = ref.watch(moduleRegistryProvider).recordTypes;
    final person = people.any((p) => p.id == _person) ? _person : null;
    final names = {for (final p in people) p.id: p.displayName};

    final locale = Localizations.localeOf(context).toLanguageTag();

    var loading = ref.watch(profilesProvider).isLoading;
    final all = <MedicalEvent>[];
    final photos = <String, int>{};
    final thumbs = <String, String>{};
    for (final p in people) {
      final timeline = ref.watch(timelineProvider(p.id));
      photos.addAll(
        ref.watch(attachmentCountsProvider(p.id)).value ?? const {},
      );
      thumbs.addAll(ref.watch(firstPhotosProvider(p.id)).value ?? const {});
      if (timeline.value == null) loading = true;
      if (person != null && p.id != person) continue;
      for (final e in timeline.value ?? const <MedicalEvent>[]) {
        // Quick logs and types from a newer version stay out, as on a
        // person's page.
        if (types[e.type]?.inTimeline ?? false) all.add(e);
      }
    }
    // Only the types this person has. One they don't have falls back to all.
    final present = [
      for (final key in {for (final e in all) e.type}) key,
    ]..sort();
    final type = present.contains(_type) ? _type : null;
    final events = type == null
        ? all
        : [
            for (final e in all)
              if (e.type == type) e,
          ];
    events.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final month = DateFormat.yMMMM(locale);

    return Scaffold(
      appBar: AppBar(title: Text(l.recordsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          FilledButton.icon(
            key: const ValueKey('records-add'),
            onPressed: () => showAddSheet(context, person: person),
            icon: const Icon(Icons.add),
            label: Text(l.recordsAdd),
          ),
          if (people.length > 1) ...[
            const SizedBox(height: UsraSpacing.s3),
            _chips('filter', person, [
              (null, l.recordsAll),
              for (final p in people) (p.id, p.displayName),
            ], (id) => setState(() => _person = id)),
          ],
          if (present.length > 1) ...[
            const SizedBox(height: UsraSpacing.s2),
            _chips('type', type, [
              (null, l.recordsAll),
              for (final key in present)
                (key, types[key]?.labelOf(context) ?? key),
            ], (id) => setState(() => _type = id)),
          ],
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
                style: UsraType.body.copyWith(color: context.usra.inkMuted),
              ),
            ),
          // One card per month, under its muted label.
          for (final (i, group) in recordsByMonth(events, month).indexed) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: UsraSpacing.s2,
                bottom: UsraSpacing.s2,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  month.format(group.first.occurredAt),
                  key: ValueKey('records-month-$i'),
                  style: UsraType.label.copyWith(
                    color: context.usra.inkMuted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            UsraListCard(
              children: [
                for (final e in group)
                  RecordRow(
                    event: e,
                    type: types[e.type],
                    photos: photos[e.id] ?? 0,
                    personName: person == null ? names[e.profileId] : null,
                    thumbnail: thumbs[e.id] == null
                        ? null
                        : _Thumbnail(event: e.id, path: thumbs[e.id]!),
                  ),
              ],
            ),
            const SizedBox(height: UsraSpacing.s2),
          ],
        ],
      ),
    );
  }
}

class _Thumbnail extends ConsumerWidget {
  const _Thumbnail({required this.event, required this.path});

  final String event;
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ClipRRect(
    borderRadius: BorderRadius.circular(UsraRadius.sm),
    child: PhotoImage(
      key: ValueKey('event-thumb-$event'),
      image: ref.watch(attachmentStoreProvider).image(path),
      width: 36,
      height: 36,
      fit: BoxFit.cover,
      cacheWidth: (36 * MediaQuery.devicePixelRatioOf(context)).round(),
    ),
  );
}
