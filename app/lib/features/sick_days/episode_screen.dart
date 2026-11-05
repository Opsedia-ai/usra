import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/util/bidi.dart';
import '../../core/database/app_database.dart';
import '../../core/design/tokens.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../family/member_screen.dart' show profileProvider;
import '../medicines/medicines_providers.dart';
import 'episode_sheets.dart';
import 'fever.dart';
import '../medicines/min_hours.dart' show formatHours;
import 'next_dose.dart';
import 'sick_days_providers.dart';
import 'temperature_chart.dart';
import 'warning_signs_card.dart';

/// One sick day: warning signs, temperatures and their chart, symptoms,
/// medicines given and notes.
class EpisodeScreen extends ConsumerWidget {
  const EpisodeScreen({
    super.key,
    required this.profileId,
    required this.episodeId,
  });

  final String profileId;
  final String episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final person = ref.watch(profileProvider(profileId)).value;
    final episode = ref.watch(episodeProvider(episodeId));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          person == null
              ? l.sickDayTitle
              : '${l.sickDayTitle} · ${isolate(person.displayName)}',
        ),
        actions: [
          IconButton(
            key: const ValueKey('sick-day-delete'),
            tooltip: l.sickDayDelete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: episode.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (e) {
          if (e == null || person == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _Body(person: person, episode: e);
        },
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(l.sickDayDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.familyCancel),
          ),
          FilledButton(
            key: const ValueKey('sick-day-delete-confirm'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.recordDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(databaseProvider).softDeleteEpisode(episodeId);
    if (context.mounted) context.go('/family/$profileId/sick-days');
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.person, required this.episode});

  final Profile person;
  final SickEpisode episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final now = ref.watch(clockProvider)();
    final readings = ref.watch(readingsProvider(episode.id)).value ?? const [];
    final given =
        ref.watch(givenMedicinesProvider(episode.id)).value ?? const [];
    final medicines = {
      for (final m
          in ref.watch(medicinesProvider(person.id)).value ??
              const <Medicine>[])
        m.id: m,
    };
    final symptoms = decodeSymptoms(episode.symptomsJson).toSet();
    final matched = matchedWarnings(
      episode: episode,
      readings: readings,
      birthDate: person.birthDate,
      now: now,
    );
    final warnings = WarningSignsCard(
      person: person,
      episode: episode,
      readings: readings,
      now: now,
    );
    final dateTime = DateFormat.MMMd(locale).add_jm();
    final db = ref.read(databaseProvider);

    // The latest entry of each saved medicine shows when the next dose is
    // allowed, from that medicine's own instructions.
    final latestOf = <String, String>{};
    for (final g in given) {
      if (g.medicineId != null) latestOf.putIfAbsent(g.medicineId!, () => g.id);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  episode.endedAt == null
                      ? l.sickDaySince(
                          dateTime.format(episode.startedAt.toLocal()),
                        )
                      : l.sickDayRange(
                          dateTime.format(episode.startedAt.toLocal()),
                          dateTime.format(episode.endedAt!.toLocal()),
                        ),
                  style: text.titleMedium,
                ),
                const SizedBox(height: 8),
                if (episode.endedAt == null)
                  OutlinedButton.icon(
                    key: const ValueKey('sick-day-end'),
                    onPressed: () => db.setEpisodeEnded(
                      episode.id,
                      _notBefore(now, episode.startedAt),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(l.sickDayEnd),
                  )
                else
                  OutlinedButton.icon(
                    key: const ValueKey('sick-day-reopen'),
                    onPressed: () => db.setEpisodeEnded(episode.id, null),
                    icon: const Icon(Icons.replay),
                    label: Text(l.sickDayReopen),
                  ),
              ],
            ),
          ),
        ),
        // Anything logged that is a warning sign comes first.
        if (matched.isNotEmpty) warnings,
        const SizedBox(height: 12),
        _SectionTitle(l.sickDayTemperatures),
        FilledButton.icon(
          key: const ValueKey('sick-day-add-reading'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: () => showReadingSheet(
            context,
            episode: episode,
            last: readings.isEmpty ? null : readings.last,
          ),
          icon: const Icon(Icons.thermostat),
          label: Text(l.sickDayAddReading),
        ),
        const SizedBox(height: 8),
        if (readings.isEmpty)
          Text(l.sickDayNoReadings)
        else ...[
          TemperatureChart(readings: readings),
          for (final r in readings.reversed)
            ListTile(
              key: ValueKey('reading-${r.id}'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.thermostat,
                color: isFever(r)
                    ? Severity.urgent.foreground
                    : UsraColors.textMuted,
              ),
              title: Text(
                '${NumberFormat('0.0', locale).format(r.value)} '
                '${r.unit == TemperatureUnit.fahrenheit ? l.readingFahrenheit : l.readingCelsius}'
                '${isFever(r) ? ' · ${l.readingFever}' : ''}',
              ),
              subtitle: Text(
                [
                  dateTime.format(r.takenAt.toLocal()),
                  if (r.site != null) l.readingSiteName(r.site!),
                ].join(' · '),
              ),
              trailing: IconButton(
                tooltip: l.readingDelete,
                icon: const Icon(Icons.close),
                onPressed: () => db.softDeleteReading(r.id),
              ),
            ),
        ],
        const SizedBox(height: 16),
        _SectionTitle(l.sickDaySymptoms),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final s in Symptom.all)
              FilterChip(
                key: ValueKey('symptom-$s'),
                label: Text(l.symptomName(s)),
                selected: symptoms.contains(s),
                onSelected: (on) => db.setEpisodeSymptoms(episode.id, [
                  for (final k in Symptom.all)
                    if (k == s ? on : symptoms.contains(k)) k,
                ]),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionTitle(l.sickDayMedicines),
        FilledButton.tonalIcon(
          key: const ValueKey('sick-day-add-medicine'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: () => showGivenSheet(context, episode: episode),
          icon: const Icon(Icons.medication_outlined),
          label: Text(l.sickDayAddMedicine),
        ),
        const SizedBox(height: 8),
        if (given.isEmpty) Text(l.sickDayNoMedicines),
        for (final g in given)
          _GivenTile(
            given: g,
            medicine: medicines[g.medicineId],
            showNext: episode.endedAt == null && latestOf[g.medicineId] == g.id,
          ),
        const SizedBox(height: 16),
        _SectionTitle(l.sickDayNotes),
        _Notes(episode: episode),
        const SizedBox(height: 16),
        if (matched.isEmpty) warnings,
      ],
    );
  }

  static DateTime _notBefore(DateTime now, DateTime start) =>
      now.isBefore(start) ? start : now;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
}

class _GivenTile extends ConsumerWidget {
  const _GivenTile({
    required this.given,
    required this.medicine,
    required this.showNext,
  });

  final GivenMedicine given;
  final Medicine? medicine;
  final bool showNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateTime = DateFormat.MMMd(locale).add_jm();
    // From the hours saved with this entry, never re-read or guessed.
    final next = showNext ? hoursAfter(given) : null;
    return ListTile(
      key: ValueKey('given-${given.id}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        given.remindNext
            ? Icons.notifications_active_outlined
            : Icons.medication,
      ),
      title: Text([given.name, ?given.amount].join(' · ')),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateTime.format(given.givenAt.toLocal())),
          if (next != null) ...[
            Text(
              l.givenHoursAfter(
                formatHours(given.intervalHours!, locale),
                dateTime.format(next.toLocal()),
              ),
              key: ValueKey('given-next-${given.id}'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(l.givenCheckIngredient),
          ],
        ],
      ),
      trailing: IconButton(
        tooltip: l.givenDelete,
        icon: const Icon(Icons.close),
        onPressed: () =>
            ref.read(databaseProvider).softDeleteGivenMedicine(given.id),
      ),
    );
  }
}

class _Notes extends ConsumerStatefulWidget {
  const _Notes({required this.episode});

  final SickEpisode episode;

  @override
  ConsumerState<_Notes> createState() => _NotesState();
}

class _NotesState extends ConsumerState<_Notes> {
  late final _notes = TextEditingController(text: widget.episode.notes ?? '');

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final e = widget.episode;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(databaseProvider)
        .saveEpisode(
          id: e.id,
          profileId: e.profileId,
          startedAt: e.startedAt,
          endedAt: e.endedAt,
          symptoms: decodeSymptoms(e.symptomsJson),
          notes: _notes.text,
        );
    messenger.showSnackBar(SnackBar(content: Text(l.sickDayNotesSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('sick-day-notes'),
          controller: _notes,
          minLines: 2,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: l.sickDayNotes),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            key: const ValueKey('sick-day-notes-save'),
            onPressed: _save,
            child: Text(l.familySave),
          ),
        ),
      ],
    );
  }
}
