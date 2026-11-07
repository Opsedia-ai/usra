import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/database/app_database.dart';
import '../../core/design/buttons.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/providers.dart';
import '../../core/util/dates.dart';
import '../../core/util/localized_digits.dart';
import '../../l10n/app_localizations.dart';
import '../children/egypt_vaccines.dart' show fullMonths;
import '../family/member_screen.dart' show profileProvider;
import '../medicines/medicines_providers.dart';
import 'episode_sheets.dart';
import 'fever.dart';
import '../medicines/min_hours.dart' show formatHours;
import 'next_dose.dart';
import 'sick_days_providers.dart';
import 'temperature_chart.dart';
import 'warning_signs_card.dart';

/// One sick day on one calm screen: who and since when, the latest reading
/// and its chart, what was given as recorded, then when to get help. The
/// fuller record (symptoms, every reading and dose, notes) folds away below.
///
/// It records and points to help. It never concludes that someone is fine:
/// a reading under the line is shown as a number, with nothing green.
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
    final person = ref.watch(profileProvider(profileId)).value;
    final episode = ref.watch(episodeProvider(episodeId));
    // Always with a way out: a reminder can open a sick day that's been
    // deleted, with nothing behind it to go back to.
    Widget bare(Widget child) => Scaffold(
      appBar: AppBar(
        leading: BackButton(
          key: const ValueKey('sick-day-bare-back'),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/family/$profileId/sick-days'),
        ),
      ),
      body: Center(child: child),
    );
    const waiting = CircularProgressIndicator();
    return episode.when(
      loading: () => bare(waiting),
      error: (_, _) => bare(Text(AppLocalizations.of(context).homeLoadError)),
      data: (e) => e == null || person == null
          ? bare(waiting)
          : _Body(person: person, episode: e),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.person, required this.episode});

  final Profile person;
  final SickEpisode episode;

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
    await ref.read(databaseProvider).softDeleteEpisode(episode.id);
    if (context.mounted) context.go('/family/${person.id}/sick-days');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final now = ref.watch(clockProvider)();
    final readings = ref.watch(readingsProvider(episode.id)).value ?? const [];
    final given =
        ref.watch(givenMedicinesProvider(episode.id)).value ?? const [];
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
    final db = ref.read(databaseProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            _gutter,
            UsraSpacing.s4,
            _gutter,
            UsraSpacing.s4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(person: person, episode: episode, now: now),
              const SizedBox(height: 12),
              // Anything logged that is a warning sign comes first.
              if (matched.isNotEmpty) ...[warnings, const SizedBox(height: 12)],
              _ReadingCard(
                episode: episode,
                readings: readings,
                given: given,
                now: now,
              ),
              const SizedBox(height: 12),
              if (matched.isEmpty) ...[warnings, const SizedBox(height: 12)],
              _Details(
                person: person,
                episode: episode,
                readings: readings,
                given: given,
              ),
              const SizedBox(height: 12),
              if (episode.endedAt == null)
                OutlinedButton.icon(
                  key: const ValueKey('sick-day-end'),
                  onPressed: () => db.setEpisodeEnded(
                    episode.id,
                    now.isBefore(episode.startedAt) ? episode.startedAt : now,
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
              const SizedBox(height: 4),
              TextButton(
                key: const ValueKey('sick-day-delete'),
                onPressed: () => _delete(context, ref),
                child: Text(l.sickDayDelete),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_gutter, 8, _gutter, 12),
          child: Row(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: const StadiumBorder(),
                    shadows: context.usra.shadowControl,
                  ),
                  child: FilledButton.icon(
                    key: const ValueKey('sick-day-add-reading'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    onPressed: () => showReadingSheet(
                      context,
                      episode: episode,
                      last: readings.isEmpty ? null : readings.last,
                    ),
                    // Very large text needs the room more than the icon.
                    icon: MediaQuery.textScalerOf(context).scale(16) > 24
                        ? null
                        : const Icon(Icons.add),
                    label: Text(l.sickDayAddReadingShort),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('sick-day-add-medicine'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: () => showGivenSheet(context, episode: episode),
                  child: Text(l.sickDayGivenShort),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _gutter = 20.0;

/// Back, then "يوسف تعبان" and "من امبارح ٩ م · ٦ سنين".
class _Header extends StatelessWidget {
  const _Header({
    required this.person,
    required this.episode,
    required this.now,
  });

  final Profile person;
  final SickEpisode episode;
  final DateTime now;

  String _age(BuildContext context, AppLocalizations l) {
    final birth = person.birthDate;
    if (birth == null) return '';
    final months = fullMonths(storedDay(birth), now);
    if (months < 0) return '';
    return localizedDigitsIn(
      context,
      months >= 1 && months < 24
          ? l.fuAgeMonths(months)
          : l.ageYears(months ~/ 12),
    );
  }

  String _since(BuildContext context, AppLocalizations l) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final started = episode.startedAt.toLocal();
    final ended = episode.endedAt?.toLocal();
    final dateTime = DateFormat.MMMd(locale).add_jm();
    if (ended != null) {
      return l.sickDayRange(dateTime.format(started), dateTime.format(ended));
    }
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(started.year, started.month, started.day);
    final time = DateFormat.jm(locale).format(started);
    if (day == today) return l.sickDaySinceToday(time);
    if (day == DateTime(today.year, today.month, today.day - 1)) {
      return l.sickDaySinceYesterday(time);
    }
    return l.sickDaySince(dateTime.format(started));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final sex = person.sex ?? 'other';
    final name = person.displayName;
    final age = _age(context, l);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UsraRoundIconButton(
          key: const ValueKey('sick-day-back'),
          // Mirrors itself, so it points the way back in both languages.
          icon: Icons.arrow_back,
          semanticLabel: l.sickDayBack,
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/family/${person.id}/sick-days'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  episode.endedAt == null
                      ? l.sickDayPersonUnwell(sex, name)
                      : l.sickDayPersonWasUnwell(sex, name),
                  key: const ValueKey('sick-day-title'),
                  style: text.headlineMedium,
                ),
              ),
              Text(
                [_since(context, l), if (age.isNotEmpty) age].join(' · '),
                key: const ValueKey('sick-day-since'),
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The latest reading, large, with its time and method, the chart, how long
/// a fever has been logged, and what was given as the family wrote it.
class _ReadingCard extends StatelessWidget {
  const _ReadingCard({
    required this.episode,
    required this.readings,
    required this.given,
    required this.now,
  });

  final SickEpisode episode;
  final List<TemperatureReading> readings;
  final List<GivenMedicine> given;
  final DateTime now;

  String _time(BuildContext context, DateTime at) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final local = at.toLocal();
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    return (sameDay ? DateFormat.jm(locale) : DateFormat.MMMd(locale).add_jm())
        .format(local);
  }

  String? _feverText(BuildContext context, AppLocalizations l) {
    final lasted = feverDuration(episode, readings, now);
    if (lasted == null) return null;
    String shown(int n) => localizedDigits(context, n);
    final days = lasted.inDays;
    final hours = lasted.inHours;
    final duration = hours < 1
        ? l.sickDayFeverUnderHour
        : hours < 48
        ? l.sickDayFeverHours(hours, shown(hours))
        : l.sickDayFeverDays(days, shown(days));
    return l.sickDayFeverLogged(duration);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final latest = readings.isEmpty ? null : readings.last;
    final fever = latest == null ? null : _feverText(context, l);
    final recorded = latestOfEach(given);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(UsraSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (latest == null)
              Text(l.sickDayNoReadings, style: text.bodyLarge)
            else ...[
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                children: [
                  Text(
                    readingText(context, latest),
                    key: const ValueKey('sick-day-latest'),
                    textDirection: TextDirection.ltr,
                    style: UsraType.numeral.copyWith(
                      fontSize: 32,
                      height: 44 / 32,
                      color: context.usra.ink,
                    ),
                  ),
                  Text(
                    [
                      l.sickDayLatestReading,
                      _time(context, latest.takenAt),
                      if (latest.site != null) l.readingSiteName(latest.site!),
                    ].join(' · '),
                    key: const ValueKey('sick-day-latest-meta'),
                    style: text.bodyLarge?.copyWith(
                      color: context.usra.inkMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TemperatureChart(readings: readings),
              if (fever != null) ...[
                const SizedBox(height: 4),
                Text(
                  fever,
                  key: const ValueKey('sick-day-fever-duration'),
                  style: text.bodyLarge,
                ),
              ],
            ],
            if (recorded.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              for (final g in recorded)
                _RecordedLine(
                  given: g,
                  time: _time(context, g.givenAt),
                  showNext: episode.endedAt == null && g.medicineId != null,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Newest entry of each medicine, newest first. [given] is newest first.
List<GivenMedicine> latestOfEach(List<GivenMedicine> given) {
  final seen = <String>{};
  return [
    for (final g in given)
      if (seen.add(g.medicineId ?? 'name:${g.name}')) g,
  ];
}

/// "مسجل: باراسيتامول شراب ٧٫٥ مل · ١٠:٠٠ ص", in the family's own words, and
/// when their own field says the next one may be given.
class _RecordedLine extends StatelessWidget {
  const _RecordedLine({
    required this.given,
    required this.time,
    required this.showNext,
  });

  final GivenMedicine given;
  final String time;
  final bool showNext;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final text = Theme.of(context).textTheme;
    // From the hours saved with this entry, never re-read or guessed.
    final next = showNext ? hoursAfter(given) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.sickDayRecordedGiven([given.name, ?given.amount].join(' '), time),
            key: ValueKey('given-recorded-${given.id}'),
            style: text.bodyLarge,
          ),
          if (next != null) ...[
            Text(
              l.givenHoursAfter(
                formatHours(given.intervalHours!, locale),
                DateFormat.MMMd(locale).add_jm().format(next.toLocal()),
              ),
              key: ValueKey('given-next-${given.id}'),
              style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(l.givenCheckIngredient, style: text.bodyLarge),
          ],
        ],
      ),
    );
  }
}

/// A reading as shown: ٣٧٫٦° in Celsius, ٩٩٫١ °ف in Fahrenheit.
String readingText(BuildContext context, TemperatureReading r) {
  final l = AppLocalizations.of(context);
  final value = localizedReading(context, r.value);
  return r.unit == TemperatureUnit.fahrenheit
      ? '$value ${l.readingFahrenheit}'
      : '$value°';
}

/// The rest of the record, folded so the screen stays calm: symptoms, which
/// feed the warning signs above, every reading and dose, and notes.
class _Details extends ConsumerWidget {
  const _Details({
    required this.person,
    required this.episode,
    required this.readings,
    required this.given,
  });

  final Profile person;
  final SickEpisode episode;
  final List<TemperatureReading> readings;
  final List<GivenMedicine> given;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final db = ref.read(databaseProvider);
    final dateTime = DateFormat.MMMd(locale).add_jm();
    final ticked = decodeSymptoms(episode.symptomsJson).toSet();
    final tickedNames = [
      for (final s in Symptom.all)
        if (ticked.contains(s)) l.symptomName(s),
    ];
    Widget section({
      required String key,
      required String title,
      String? summary,
      bool keepTyping = false,
      required List<Widget> children,
    }) => ExpansionTile(
      key: ValueKey(key),
      maintainState: keepTyping,
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: UsraSpacing.s4),
      childrenPadding: const EdgeInsets.fromLTRB(
        UsraSpacing.s4,
        0,
        UsraSpacing.s4,
        UsraSpacing.s4,
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      title: Text(title, style: text.bodyLarge),
      subtitle: summary == null
          ? null
          : Text(
              summary,
              style: text.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      children: children,
    );
    return Card(
      child: Column(
        children: [
          section(
            key: 'sick-day-symptoms',
            title: l.sickDaySymptoms,
            summary: tickedNames.isEmpty
                ? l.sickDayNoSymptoms
                : tickedNames.join('، '),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final s in Symptom.all)
                    FilterChip(
                      key: ValueKey('symptom-$s'),
                      label: Text(l.symptomName(s)),
                      selected: ticked.contains(s),
                      onSelected: (on) => db.setEpisodeSymptoms(episode.id, [
                        for (final k in Symptom.all)
                          if (k == s ? on : ticked.contains(k)) k,
                      ]),
                    ),
                ],
              ),
            ],
          ),
          const Divider(height: 1),
          section(
            key: 'sick-day-readings',
            title: l.sickDayAllReadings,
            summary: localizedDigits(context, readings.length),
            children: [
              if (readings.isEmpty) Text(l.sickDayNoReadings),
              for (final r in readings.reversed)
                ListTile(
                  key: ValueKey('reading-${r.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${localizedReading(context, r.value)} '
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
          ),
          const Divider(height: 1),
          section(
            key: 'sick-day-given',
            title: l.sickDayMedicines,
            summary: localizedDigits(context, given.length),
            children: [
              if (given.isEmpty) Text(l.sickDayNoMedicines),
              for (final g in given) _GivenTile(given: g),
            ],
          ),
          const Divider(height: 1),
          section(
            key: 'sick-day-notes-section',
            title: l.sickDayNotes,
            summary: episode.notes,
            // Folding it must not lose what's typed and not yet saved.
            keepTyping: true,
            children: [_Notes(episode: episode)],
          ),
        ],
      ),
    );
  }
}

class _GivenTile extends ConsumerWidget {
  const _GivenTile({required this.given});

  final GivenMedicine given;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateTime = DateFormat.MMMd(locale).add_jm();
    return ListTile(
      key: ValueKey('given-${given.id}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        given.remindNext
            ? Icons.notifications_active_outlined
            : Icons.medication,
      ),
      title: Text([given.name, ?given.amount].join(' · ')),
      subtitle: Text(dateTime.format(given.givenAt.toLocal())),
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
