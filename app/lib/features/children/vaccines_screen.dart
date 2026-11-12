import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/database/app_database.dart';
import '../../core/design/pill_chip.dart';
import '../../core/design/status_chip.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/files/photo_store.dart';
import '../../core/log.dart';
import '../../core/ocr/ocr_service.dart';
import '../../core/preferences.dart';
import '../../core/providers.dart';
import '../../core/util/localized_digits.dart';
import '../../l10n/app_localizations.dart';
import '../account/save_gate.dart';
import '../family/family_screen.dart' show profilesProvider;
import '../family/member_screen.dart' show profileProvider, timelineProvider;
import '../follow_ups/follow_ups_providers.dart' show todayProvider;
import '../medicines/medicines_providers.dart' show reminderSchedulerProvider;
import '../reports/reports_screens.dart' show shareVaccinationRecord;
import '../scan/scan_widgets.dart';
import 'child_vaccines.dart';
import 'egypt_vaccine_sources.dart';
import 'egypt_vaccines.dart';
import 'growth.dart' show isUnderFive;
import 'vaccine_card_parser.dart';
import '../../core/util/date_picker.dart';

/// [profile]'s vaccines today, once their records have loaded; null for
/// anyone five or over.
ChildVaccines? watchChildVaccines(WidgetRef ref, Profile profile) {
  final today = ref.watch(todayProvider);
  if (!isUnderFive(profile.birthDate, today)) return null;
  final events = ref.watch(timelineProvider(profile.id)).value;
  if (events == null) return null;
  return childVaccines(profile, events, today);
}

String _fmt(BuildContext context, DateTime d) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(d);

/// Picks the day a dose was given: from the birth date (or the recorded
/// date, if a record says earlier) to today.
Future<DateTime?> pickGivenDate(
  BuildContext context, {
  required DateTime initial,
  required DateTime birthDate,
}) {
  final now = DateTime.now();
  final start = givenDateOn(initial, now);
  return pickDate(
    context,
    initialDate: start,
    firstDate: start.isBefore(birthDate) ? start : birthDate,
    lastDate: now,
  );
}

/// Vaccine reminders need notifications, which until now were only asked
/// for from the Medicines tab: ask once the family has a vaccine plan (the
/// phone shows its prompt only the first time). Never blocks saving.
Future<void> askForReminderAccess(WidgetRef ref) async {
  if (!ref.read(vaccineRemindersProvider)) return;
  try {
    final scheduler = ref.read(reminderSchedulerProvider);
    if ((await scheduler.access()).notifications) return;
    await scheduler.requestAccess(exactAlarms: false);
  } catch (_) {
    // No notifications on this phone; the vaccine page still works.
  }
}

/// Asks before unticking a dose would remove a record the family entered
/// by hand (it may hold a photo, doctor or cost); true to go ahead.
Future<bool> confirmRemovingUserRecords(
  BuildContext context,
  VaccineRecordChanges changes,
  Set<String> userRecordIds,
) async {
  if (!changes.remove.any(userRecordIds.contains)) return true;
  final l = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      key: const ValueKey('vaccine-remove-confirm'),
      title: Text(l.vaccineRemoveRecordTitle),
      content: Text(l.vaccineRemoveRecordBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: Text(l.familyCancel),
        ),
        FilledButton(
          key: const ValueKey('vaccine-remove-ok'),
          onPressed: () => Navigator.of(c).pop(true),
          child: Text(l.vaccineRemoveRecordConfirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// From this many open past doses, the vaccine page offers to mark them
/// all at once.
const markPastFrom = 3;

/// Asks before marking [required] (and, if ticked, [optional]) doses as
/// given on their schedule days: how many, up to which age, and to check
/// the card first. The doses to mark, or null when cancelled.
Future<List<DoseStatus>?> confirmMarkPast(
  BuildContext context, {
  required List<DoseStatus> required,
  required List<DoseStatus> optional,
}) async {
  final l = AppLocalizations.of(context);
  var withOptional = false;
  final upTo = [for (final s in required) s.dose.ageMonths]
      .fold(0, (a, b) => a > b ? a : b);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        key: const ValueKey('vaccine-mark-past-dialog'),
        title: Text(l.vaccineMarkPastTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                localizedDigitsIn(
                  context,
                  l.vaccineMarkPastBody(required.length, l.vaccineUpTo(upTo)),
                ),
                key: const ValueKey('vaccine-mark-past-body'),
              ),
              if (optional.isNotEmpty)
                CheckboxListTile(
                  key: const ValueKey('vaccine-mark-past-optional'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: withOptional,
                  onChanged: (v) => setState(() => withOptional = v == true),
                  title: Text(
                    localizedDigitsIn(
                      context,
                      l.vaccineMarkPastOptional(optional.length),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(l.familyCancel),
          ),
          FilledButton(
            key: const ValueKey('vaccine-mark-past-ok'),
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(l.vaccineMarkPastOk),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return null;
  return [...required, if (withOptional) ...optional];
}

/// Marks every dose due so far as given, each on its schedule day, after
/// asking; offers to undo. From the vaccine page.
Future<void> markPastDoses(
  BuildContext context,
  WidgetRef ref,
  ChildVaccines child,
) async {
  final l = AppLocalizations.of(context);
  final today = ref.read(todayProvider);
  final required = pastDosesToMark(child.statuses, today);
  final optional = [
    for (final s in pastDosesToMark(child.statuses, today, withOptional: true))
      if (!s.dose.required) s,
  ];
  final doses = await confirmMarkPast(
    context,
    required: required,
    optional: optional,
  );
  if (doses == null || doses.isEmpty || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final db = ref.read(databaseProvider);
  final id = child.profile.id;
  final changes = vaccineRecordChanges(l, child.statuses, {
    for (final s in doses) s.dose.key: givenDateOn(s.plannedOn, today),
  });
  if (!await ref.read(saveGateProvider).allow()) return;
  final List<String> added;
  try {
    added = await applyVaccineChanges(db, id, changes);
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.saveFailed)));
    return;
  }
  messenger.showSnackBar(
    SnackBar(
      key: const ValueKey('vaccine-mark-past-done'),
      content: Text(
        digitsIn(l.localeName, l.vaccineMarkPastDone(doses.length)),
      ),
      action: SnackBarAction(
        label: l.doseUndo,
        // Exactly the records just added.
        onPressed: () async {
          try {
            await db.replaceEvents(profileId: id, remove: added);
          } catch (_) {
            messenger.showSnackBar(SnackBar(content: Text(l.saveFailed)));
          }
        },
      ),
    ),
  );
}

/// Whether this child already has a saved plan, so saving only updates it.
Future<bool> _hasVaccinePlan(AppDatabase db, String profileId) async =>
    (await db.eventsOfTypes({VaccinePlanFields.type}))
        .any((e) => e.profileId == profileId);

/// Saves [changes] in one transaction; nothing when there are none. The
/// ids of the records added.
Future<List<String>> applyVaccineChanges(
  AppDatabase db,
  String profileId,
  VaccineRecordChanges changes,
) async {
  if (changes.add.isEmpty && changes.remove.isEmpty && changes.redate.isEmpty) {
    return const [];
  }
  return db.replaceEvents(
    profileId: profileId,
    add: changes.add,
    remove: changes.remove,
    redate: changes.redate,
  );
}

/// The next visit as a chip label and colour; null when nothing is left.
(String, Severity)? nextVisitChip(
  BuildContext context,
  ChildVaccines c,
  DateTime today,
) {
  final l = AppLocalizations.of(context);
  final days = c.next.daysFrom(today);
  if (days == null) {
    return c.next.overdue.isEmpty ? (l.vaccineAllDone, Severity.good) : null;
  }
  final when = days >= 0 ? l.vaccineInDays(days) : l.vaccineDaysAgo(-days);
  return (
    '$when · ${_fmt(context, c.next.date!)}',
    days <= dueSoonDays ? Severity.headsUp : Severity.info,
  );
}

/// The counter and the next visit, shared by the vaccine page, the growth
/// page and Home.
class VaccineProgressSummary extends StatelessWidget {
  const VaccineProgressSummary({
    super.key,
    required this.child,
    required this.today,
  });

  final ChildVaccines child;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = child.progress;
    final next = nextVisitChip(context, child, today);
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        StatusChip(
          key: ValueKey('vaccine-next-${child.profile.id}'),
          severity: next?.$2 ?? Severity.info,
          label: next?.$1 ?? l.vaccineNextVisit,
        ),
        if (child.next.overdue.isNotEmpty)
          StatusChip(
            key: ValueKey('vaccine-overdue-${child.profile.id}'),
            severity: Severity.actSoon,
            label: l.vaccineOverdueCount(child.next.overdue.length),
          ),
        StatusChip(
          key: ValueKey('vaccine-required-${child.profile.id}'),
          severity: p.requiredDone == p.requiredTotal
              ? Severity.good
              : Severity.info,
          label: l.vaccineRequiredDone(p.requiredDone, p.requiredTotal),
        ),
        if (p.optionalTotal > 0)
          StatusChip(
            key: ValueKey('vaccine-optional-${child.profile.id}'),
            severity: Severity.info,
            label: l.vaccineOptionalDone(p.optionalDone, p.optionalTotal),
          ),
      ],
    );
  }
}

/// On the growth page: the counter, the next visit, and the way in.
class VaccineSummaryCard extends ConsumerWidget {
  const VaccineSummaryCard({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = watchChildVaccines(ref, profile);
    if (child == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return Card(
      key: const ValueKey('vaccine-summary'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.vaccineNextVisit,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            VaccineProgressSummary(
              child: child,
              today: ref.watch(todayProvider),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: const ValueKey('vaccine-open-all'),
              onPressed: () => context.go('/family/${profile.id}/vaccines'),
              icon: const Icon(Icons.vaccines_outlined),
              label: Text(l.vaccineOpenAll),
            ),
          ],
        ),
      ),
    );
  }
}

/// Home: each child under five, with the days to their next vaccine visit
/// and any overdue doses. Hidden when there are no young children.
class HomeVaccines extends ConsumerWidget {
  const HomeVaccines({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final people = ref.watch(profilesProvider).value ?? const <Profile>[];
    final children = [
      for (final p in people)
        if (watchChildVaccines(ref, p) case final c? when !c.next.isEmpty) c,
    ];
    if (children.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        key: const ValueKey('home-vaccines'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Icon(Icons.vaccines_outlined, color: context.usra.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(l.homeVaccinesTitle, style: text.titleMedium),
                    ),
                  ],
                ),
              ),
              for (final c in children)
                ListTile(
                  key: ValueKey('home-vaccines-${c.profile.id}'),
                  title: Text(c.profile.displayName, style: text.titleMedium),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _HomeChips(child: c, today: today),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: context.usra.inkMuted,
                  ),
                  onTap: () => context.go('/family/${c.profile.id}/vaccines'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeChips extends StatelessWidget {
  const _HomeChips({required this.child, required this.today});

  final ChildVaccines child;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final next = nextVisitChip(context, child, today);
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (next != null)
          StatusChip(
            key: ValueKey('vaccine-next-${child.profile.id}'),
            severity: next.$2,
            label: next.$1,
          ),
        if (child.next.overdue.isNotEmpty)
          StatusChip(
            key: ValueKey('vaccine-overdue-${child.profile.id}'),
            severity: Severity.actSoon,
            label: l.vaccineOverdueCount(child.next.overdue.length),
          ),
      ],
    );
  }
}

enum VaccineFilter { all, required, optional, overdue }

/// Which doses [filter] shows: "All" is every dose, optional ones the
/// family doesn't follow too (marked optional), so their dates are always
/// there.
List<DoseStatus> filterDoses(List<DoseStatus> statuses, VaccineFilter filter) =>
    [
      for (final s in statuses)
        if (switch (filter) {
          VaccineFilter.all => true,
          VaccineFilter.required => s.dose.required,
          VaccineFilter.optional => !s.dose.required,
          // Only what's in the plan: an optional dose the family doesn't
          // follow is never "overdue".
          VaccineFilter.overdue => s.open && s.state == DoseState.overdue,
        })
          s,
    ];

/// A child's whole vaccine schedule: progress, filters, every dose with its
/// state and note. Informational only.
class VaccinesScreen extends ConsumerStatefulWidget {
  const VaccinesScreen({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<VaccinesScreen> createState() => _VaccinesScreenState();
}

class _VaccinesScreenState extends ConsumerState<VaccinesScreen> {
  static const _overdueCards = 3;

  var _filter = VaccineFilter.all;

  /// Marking past doses: the button waits until it's done.
  var _marking = false;
  var _doneOpen = false;
  var _allOverdue = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider(widget.profileId));
    final id = widget.profileId;
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (profile.value) {
          final p? => l.vaccinesTitleOf(p.displayName),
          null => l.vaccinesTitle,
        }),
        leading: BackButton(onPressed: () => context.go('/family/$id')),
        actions: [
          // Its own context, so an iPad's share sheet points at the button.
          Builder(
            builder: (button) => IconButton(
              key: const ValueKey('vaccines-share-pdf'),
              tooltip: l.reportVaccinationShare,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () => shareVaccinationRecord(button, ref, id),
            ),
          ),
        ],
      ),
      bottomNavigationBar: switch (profile.value) {
        final p? when watchChildVaccines(ref, p) != null => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: FilledButton.icon(
              key: const ValueKey('vaccine-new'),
              onPressed: () => context.push('/family/$id/add/vaccine'),
              icon: const Icon(Icons.add),
              label: Text(l.vaccineNewTitle),
            ),
          ),
        ),
        _ => null,
      },
      body: switch (profile) {
        AsyncError(:final error) => Center(child: Text('$error')),
        AsyncValue(value: final p?) => switch (watchChildVaccines(ref, p)) {
          final c? => _body(context, c),
          null when !isUnderFive(p.birthDate, ref.watch(todayProvider)) =>
            Center(child: Text(l.growthUnderFiveOnly)),
          null => const Center(child: CircularProgressIndicator()),
        },
        AsyncData(value: null) => Center(child: Text(l.profileNotFound)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _body(BuildContext context, ChildVaccines c) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final shown = filterDoses(c.statuses, _filter);
    // Whole ages already given fold away; only under "All", where nothing
    // else would hide them. An optional dose the family doesn't follow
    // never keeps an age open, and stays in the list.
    final byAge = <int, List<DoseStatus>>{};
    for (final s in shown) {
      if (s.followed || s.done) (byAge[s.dose.ageMonths] ??= []).add(s);
    }
    final doneAges = _filter == VaccineFilter.all
        ? [
            for (final e in byAge.entries)
              if (e.value.every((s) => s.done)) e.key,
          ]
        : const <int>[];
    final doneDoses = {for (final a in doneAges) ...byAge[a]!};
    final rest = [
      for (final s in shown)
        if (!doneDoses.contains(s)) s,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _ProgressCard(child: c),
        // A few cards, so a child with no records yet doesn't push everything
        // else away; the rest open from the count under them.
        for (final s
            in _allOverdue
                ? c.next.overdue
                : c.next.overdue.take(_overdueCards)) ...[
          const SizedBox(height: UsraSpacing.s3),
          _OverdueCard(
            status: s,
            onLog: () => showDoseSheet(context, ref, c, s, given: true),
          ),
        ],
        if (!_allOverdue && c.next.overdue.length > _overdueCards)
          TextButton(
            key: const ValueKey('vaccine-overdue-all'),
            onPressed: () => setState(() => _allOverdue = true),
            child: Text(
              localizedDigitsIn(
                context,
                l.vaccineOverdueCount(c.next.overdue.length),
              ),
            ),
          ),
        if (pastDosesToMark(c.statuses, today).length >= markPastFrom) ...[
          const SizedBox(height: UsraSpacing.s2),
          OutlinedButton.icon(
            key: const ValueKey('vaccine-mark-past'),
            onPressed: _marking
                ? null
                : () async {
                    setState(() => _marking = true);
                    try {
                      await markPastDoses(context, ref, c);
                    } finally {
                      if (mounted) setState(() => _marking = false);
                    }
                  },
            icon: const Icon(Icons.done_all),
            label: Text(l.vaccineMarkPast),
          ),
        ],
        const SizedBox(height: UsraSpacing.s3),
        _NextCard(child: c, today: today),
        const SizedBox(height: UsraSpacing.s3),
        OutlinedButton.icon(
          key: const ValueKey('vaccine-setup-open'),
          onPressed: () => context.go('/family/${c.profile.id}/vaccines/setup'),
          icon: const Icon(Icons.checklist),
          label: Text(l.vaccineSetupOpen),
        ),
        const SizedBox(height: UsraSpacing.s4),
        Wrap(
          spacing: UsraSpacing.s2,
          runSpacing: UsraSpacing.s2,
          children: [
            for (final f in VaccineFilter.values)
              UsraPill(
                key: ValueKey('vaccine-filter-${f.name}'),
                selected: _filter == f,
                onTap: () => setState(() => _filter = f),
                label: switch (f) {
                  VaccineFilter.all => l.vaccineFilterAll,
                  VaccineFilter.required => l.vaccineFilterRequired,
                  VaccineFilter.optional => l.vaccineFilterOptional,
                  VaccineFilter.overdue => l.vaccineFilterOverdue,
                },
              ),
          ],
        ),
        const SizedBox(height: UsraSpacing.s2),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(l.vaccineFilterEmpty, textAlign: TextAlign.center),
          ),
        if (doneDoses.isNotEmpty) ...[
          _DoneGroup(
            ages: {for (final s in doneDoses) doseAge(l, s.dose)}
                .join(_listComma(l)),
            last: doneDoses
                .map((s) => s.givenOn)
                .nonNulls
                .fold<DateTime?>(
                  null,
                  (a, b) => a == null || b.isAfter(a) ? b : a,
                ),
            open: _doneOpen,
            onTap: () => setState(() => _doneOpen = !_doneOpen),
          ),
          if (_doneOpen)
            for (final s in doneDoses)
              DoseTile(
                status: s,
                note: c.plan.notes[s.dose.key],
                onTap: () => showDoseSheet(context, ref, c, s),
              ),
        ],
        for (final s in rest)
          DoseTile(
            status: s,
            note: c.plan.notes[s.dose.key],
            onTap: () => showDoseSheet(context, ref, c, s),
          ),
        const SizedBox(height: UsraSpacing.s4),
        Text(
          l.vaccinesDisclaimer(egyptScheduleCheckedOn),
          style: text.bodySmall?.copyWith(color: context.usra.inkMuted),
        ),
        const _Sources(),
      ],
    );
  }
}

String _listComma(AppLocalizations l) =>
    l.localeName.startsWith('ar') ? '، ' : ', ';

/// How far along, as a bar, and which schedule that's counted against.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.child});

  final ChildVaccines child;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final p = child.progress;
    final done = p.requiredDone + p.optionalDone;
    final total = p.requiredTotal + p.optionalTotal;
    final line = localizedDigitsIn(context, l.vaccineProgressLine(done, total));
    final locale = Localizations.localeOf(context).toLanguageTag();
    final checked = DateFormat.yMMMd(locale)
        .format(DateTime.parse(egyptScheduleCheckedOn));
    return Card(
      key: const ValueKey('vaccine-progress'),
      child: Padding(
        padding: const EdgeInsets.all(UsraSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              line,
              key: const ValueKey('vaccine-progress-line'),
              style: UsraType.body.copyWith(
                color: c.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: UsraSpacing.s2),
            ClipRRect(
              borderRadius: BorderRadius.circular(UsraRadius.pill),
              child: LinearProgressIndicator(
                key: const ValueKey('vaccine-progress-bar'),
                minHeight: 10,
                value: total == 0 ? 0 : done / total,
                color: c.primary,
                backgroundColor: c.surfaceSoft,
                semanticsLabel: line,
              ),
            ),
            const SizedBox(height: UsraSpacing.s2),
            Wrap(
              spacing: UsraSpacing.s2,
              runSpacing: UsraSpacing.s1,
              children: [
                StatusChip(
                  key: ValueKey('vaccine-required-${child.profile.id}'),
                  severity: p.requiredDone == p.requiredTotal
                      ? Severity.good
                      : Severity.info,
                  label: localizedDigitsIn(
                    context,
                    l.vaccineRequiredDone(p.requiredDone, p.requiredTotal),
                  ),
                ),
                if (p.optionalTotal > 0)
                  StatusChip(
                    key: ValueKey('vaccine-optional-${child.profile.id}'),
                    severity: Severity.info,
                    label: localizedDigitsIn(
                      context,
                      l.vaccineOptionalDone(p.optionalDone, p.optionalTotal),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: UsraSpacing.s2),
            Text(
              l.personVaccineSource(
                child.plan.route == VaccineRoute.government
                    ? l.vaccineRouteGovernment
                    : l.vaccineRouteHexavalent,
                checked,
              ),
              key: const ValueKey('vaccine-schedule-source'),
              style: UsraType.label.copyWith(color: c.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// A dose past its date, and the way to say it was given after all.
class _OverdueCard extends StatelessWidget {
  const _OverdueCard({required this.status, required this.onLog});

  final DoseStatus status;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    return Card(
      key: ValueKey('vaccine-overdue-card-${status.dose.key}'),
      child: Padding(
        padding: const EdgeInsets.all(UsraSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusChip(
              severity: Severity.actSoon,
              label: l.statusVaccineOverdue,
            ),
            const SizedBox(height: UsraSpacing.s2),
            Text(
              doseName(l, status.dose),
              style: UsraType.body.copyWith(
                color: c.ink,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              l.personVaccineWasDue(_fmt(context, status.dueOn)),
              style: UsraType.body.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: UsraSpacing.s2),
            FilledButton(
              key: ValueKey('vaccine-log-${status.dose.key}'),
              onPressed: onLog,
              child: Text(l.personVaccineLog),
            ),
          ],
        ),
      ),
    );
  }
}

/// The next visit: when, and which doses.
class _NextCard extends StatelessWidget {
  const _NextCard({required this.child, required this.today});

  final ChildVaccines child;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final next = nextVisitChip(context, child, today);
    return Card(
      key: const ValueKey('vaccine-next-card'),
      child: Padding(
        padding: const EdgeInsets.all(UsraSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.vaccineNextVisit,
              style: UsraType.body.copyWith(
                color: c.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (child.next.doses.isNotEmpty) ...[
              const SizedBox(height: UsraSpacing.s1),
              Text(
                nextVisitDoses(l, child),
                key: const ValueKey('vaccine-next-doses'),
                style: UsraType.body.copyWith(color: c.ink),
              ),
            ],
            const SizedBox(height: UsraSpacing.s2),
            StatusChip(
              key: ValueKey('vaccine-next-${child.profile.id}'),
              severity: next?.$2 ?? Severity.info,
              label:
                  next?.$1 ??
                  localizedDigitsIn(
                    context,
                    l.vaccineOverdueCount(child.next.overdue.length),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The doses of the next visit, under their age when they share it: "At 4
/// months: …", or under "catch-up" when the child is past the age of every
/// one. Otherwise each dose carries its own age, or "catch-up".
String nextVisitDoses(AppLocalizations l, ChildVaccines child) {
  final comma = _listComma(l);
  final doses = child.next.doses;
  final catchUp = {
    for (final s in child.statuses)
      if (s.catchUp && doses.contains(s.dose)) s.dose,
  };
  final names = doses.map((d) => doseName(l, d)).join(comma);
  if (catchUp.length == doses.length) {
    return '${l.vaccineNextCatchUp}: $names';
  }
  if (catchUp.isEmpty && {for (final d in doses) d.ageMonths}.length == 1) {
    return '${doseAge(l, doses.first)}: $names';
  }
  return doses
      .map(
        (d) =>
            '${doseName(l, d)} '
            '(${catchUp.contains(d) ? l.vaccineCatchUpShort : doseAge(l, d)})',
      )
      .join(comma);
}

/// The ages already given, folded into one line.
class _DoneGroup extends StatelessWidget {
  const _DoneGroup({
    required this.ages,
    required this.last,
    required this.open,
    required this.onTap,
  });

  final String ages;
  final DateTime? last;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    return Semantics(
      button: true,
      expanded: open,
      child: InkWell(
        key: const ValueKey('vaccine-done-group'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: UsraSizes.touchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: UsraSpacing.s2),
            child: Row(
              children: [
                Icon(Icons.check, color: c.good),
                const SizedBox(width: UsraSpacing.s2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.vaccineDoneGroup,
                        style: UsraType.body.copyWith(
                          color: c.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(ages, style: UsraType.body.copyWith(color: c.ink)),
                      if (last != null)
                        Text(
                          l.vaccineDoneGroupLast(_fmt(context, last!)),
                          style: UsraType.label.copyWith(color: c.inkMuted),
                        ),
                    ],
                  ),
                ),
                Icon(
                  open ? Icons.expand_less : Icons.expand_more,
                  color: c.inkMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Sources extends StatelessWidget {
  const _Sources();

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: context.usra.inkMuted);
    return ExpansionTile(
      key: const ValueKey('vaccine-sources'),
      tilePadding: EdgeInsets.zero,
      title: Text(AppLocalizations.of(context).vaccineSources, style: small),
      children: [
        for (final s in egyptVaccineSources)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SelectableText(
              '${s.publisher}, ${s.date}: ${s.title}\n${s.url}',
              style: small,
              textDirection: TextDirection.ltr,
            ),
          ),
      ],
    );
  }
}

/// One dose: name, age, required or optional, state and the family's note.
class DoseTile extends StatelessWidget {
  const DoseTile({super.key, required this.status, this.note, this.onTap});

  final DoseStatus status;
  final String? note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String date(DateTime d) => _fmt(context, d);
    final dose = status.dose;
    final label = switch (status.state) {
      DoseState.done => l.vaccineDone(date(status.givenOn!)),
      // Optional and not followed: its date, but not "overdue".
      DoseState.overdue when !status.followed => l.vaccineOptionalWasDue(
        date(status.dueOn),
      ),
      DoseState.overdue => l.vaccineOverdue(date(status.dueOn)),
      DoseState.due || DoseState.later when status.catchUp => l.vaccineCatchUp(
        date(status.dueOn),
      ),
      DoseState.due => l.vaccineDue(date(status.dueOn)),
      DoseState.later => l.vaccineLater(date(status.dueOn)),
      DoseState.tooLate => l.vaccineTooLate,
      DoseState.notNeeded => l.vaccineNotNeeded,
    };
    final c = context.usra;
    return InkWell(
      key: ValueKey('dose-${dose.kind.name}-${dose.dose}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: UsraSpacing.s2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              doseName(l, dose),
              style: UsraType.body.copyWith(
                color: c.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${doseAge(l, dose)} · '
              '${dose.required ? l.vaccineRequired : l.vaccineOptional}',
              style: UsraType.label.copyWith(color: c.inkMuted),
            ),
            if (note != null)
              Text(note!, style: UsraType.label.copyWith(color: c.inkMuted)),
            const SizedBox(height: UsraSpacing.s1),
            StatusChip(
              key: ValueKey('dose-state-${dose.key}'),
              // Not followed: shown for its dates, never as something to do.
              severity: status.followed || status.done
                  ? status.state.severity
                  : Severity.info,
              label:
                  status.followed ||
                      status.done ||
                      status.state == DoseState.overdue
                  ? label
                  : '${l.vaccineOptional} · $label',
            ),
          ],
        ),
      ),
    );
  }
}

/// Mark one dose given (with its date) or not, and write a note.
Future<void> showDoseSheet(
  BuildContext context,
  WidgetRef ref,
  ChildVaccines child,
  DoseStatus status, {
  bool given = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _DoseSheet(child: child, status: status, given: given),
);

class _DoseSheet extends ConsumerStatefulWidget {
  const _DoseSheet({
    required this.child,
    required this.status,
    required this.given,
  });

  final ChildVaccines child;
  final DoseStatus status;

  /// Opened to log the dose, so "given" starts on.
  final bool given;

  @override
  ConsumerState<_DoseSheet> createState() => _DoseSheetState();
}

class _DoseSheetState extends ConsumerState<_DoseSheet> {
  late bool _given = widget.status.done || widget.given;
  // A dose not yet given defaults to the day it was planned for, never a
  // future one: a past dose logged late (from its overdue card too) was most
  // likely given on time, and the family can change it. Never today when
  // that's after the planned day.
  late DateTime _date = givenDateOn(
    widget.status.givenOn ?? widget.status.plannedOn,
    ref.read(todayProvider),
  );

  /// The date is the planned one, a past day, not one the family chose or
  /// saved.
  late bool _dateAssumed =
      widget.status.givenOn == null &&
      !widget.status.plannedOn.isAfter(ref.read(todayProvider));
  late final _note = TextEditingController(
    text: widget.child.plan.notes[widget.status.dose.key] ?? '',
  );
  var _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final db = ref.read(databaseProvider);
    final s = widget.status;
    final child = widget.child;
    // Asked first, before anything is saved.
    final changes = vaccineRecordChanges(l, child.statuses, {
      s.dose.key: _given ? _date : null,
    });
    if (!await confirmRemovingUserRecords(
      context,
      changes,
      child.userRecordIds,
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    final plan = child.plan.withNote(s.dose.key, _note.text);
    // Taking a tick off, changing a date or a saved plan's note corrects
    // what's there.
    final isNew =
        changes.add.isNotEmpty ||
        (plan != child.plan && !await _hasVaccinePlan(db, child.profile.id));
    if (isNew && !await ref.read(saveGateProvider).allow()) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (!mounted) return;
    try {
      if (plan != child.plan) {
        await db.saveSingletonEvent(
          profileId: child.profile.id,
          type: VaccinePlanFields.type,
          dataJson: plan.toJson(),
        );
      }
      await applyVaccineChanges(db, child.profile.id, changes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.saveFailed)));
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = widget.status;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(doseName(l, s.dose), style: text.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${widget.child.profile.displayName} · ${doseAge(l, s.dose)} · '
              '${l.vaccineDueOn(_fmtc(s.dueOn))}',
              style: text.bodyMedium?.copyWith(color: context.usra.inkMuted),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const ValueKey('dose-given'),
              contentPadding: EdgeInsets.zero,
              value: _given,
              onChanged: (v) => setState(() => _given = v),
              // Says what the switch shows: given, or not given.
              title: Text(_given ? l.vaccineDoseGiven : l.vaccineDoseNotGiven),
            ),
            if (_given)
              ListTile(
                key: const ValueKey('dose-date'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(l.vaccineDoseDate),
                subtitle: Text(
                  _dateAssumed
                      ? '${_fmtc(_date)}\n${l.vaccineDateAssumed}'
                      : _fmtc(_date),
                ),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () async {
                  final picked = await pickGivenDate(
                    context,
                    initial: _date,
                    birthDate: widget.child.profile.birthDate!,
                  );
                  if (picked != null) {
                    setState(() {
                      _date = picked;
                      _dateAssumed = false;
                    });
                  }
                },
              ),
            TextField(
              key: const ValueKey('dose-note'),
              controller: _note,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                labelText: l.vaccineDoseNote,
                hintText: l.vaccineDoseNoteHint,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('dose-save'),
              onPressed: _saving ? null : _save,
              child: Text(l.familySave),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtc(DateTime d) => _fmt(context, d);
}

/// The plan (route and optional vaccines) and a checklist of the doses
/// already given. Opened after adding a young child, and from the vaccine
/// page.
class VaccineSetupScreen extends ConsumerStatefulWidget {
  const VaccineSetupScreen({
    super.key,
    required this.profileId,
    this.first = false,
    this.startWithScan = false,
  });

  final String profileId;

  /// Right after the child was added: "Later" leads to their page.
  final bool first;

  /// Opens the camera on the card first, from the New vaccine form.
  final bool startWithScan;

  @override
  ConsumerState<VaccineSetupScreen> createState() => _VaccineSetupScreenState();
}

class _VaccineSetupScreenState extends ConsumerState<VaccineSetupScreen> {
  VaccinePlan? _plan;

  /// Doses ticked or unticked here, by [ScheduledDose.key]; the others
  /// stay as their records say.
  final _toggled = <String, bool>{};

  /// Dates the family changed, by [ScheduledDose.key].
  final _dates = <String, DateTime>{};
  var _saving = false;

  /// Reading a photo of the vaccination card.
  var _reading = false;
  List<String> _scanMessages = const [];

  /// Doses read from the card, by [ScheduledDose.key]: each is confirmed
  /// against the card (or unticked) before saving.
  final _fromCard = <String, CardDose>{};
  final _confirmed = <String>{};

  /// Dated rows of the card the phone couldn't name: the family says which
  /// dose each is, or skips it.
  final _unknown = <CardUnknownRow>[];

  bool _ticked(DoseStatus s) => _toggled[s.dose.key] ?? s.done;

  bool _startedScan = false;

  /// Something read from the card still waits for the family. Only doses
  /// still on the schedule count: one dropped since can't be confirmed.
  bool _needsCheck(List<DoseStatus> statuses) =>
      _unknown.isNotEmpty ||
      statuses.any(
        (s) =>
            _fromCard.containsKey(s.dose.key) &&
            (_toggled[s.dose.key] ?? false) &&
            !_confirmed.contains(s.dose.key),
      );

  /// Another route has other doses, so what the card matched no longer holds.
  void _forgetScan() {
    if (_fromCard.isEmpty && _unknown.isEmpty) return;
    final l = AppLocalizations.of(context);
    for (final key in _fromCard.keys) {
      _toggled.remove(key);
      _dates.remove(key);
    }
    _fromCard.clear();
    _confirmed.clear();
    _unknown.clear();
    _scanMessages = [l.vaccineScanRouteChanged];
  }

  /// Reads a photo of the card and ticks the dated doses on it, each to be
  /// confirmed. The photo is only read, on the phone, and then deleted.
  Future<void> _scan(
    ImageSource source,
    Profile profile,
    List<DoseStatus> statuses,
  ) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    String? path;
    try {
      path = await ref.read(photoPickerProvider)(source);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.photoFailed)));
      return;
    }
    if (path == null) return;
    if (!mounted) {
      discardPicked(path);
      return;
    }
    setState(() {
      _reading = true;
      _scanMessages = const [];
    });
    VaccineCardScan scan;
    // Keeps the recogniser open while it reads.
    final ocr = ref.listenManual(ocrServiceProvider, (_, _) {});
    try {
      final text = await ocr.read().recognise(path);
      scan = const VaccineCardParser().parse(
        text,
        today: ref.read(todayProvider),
        birthDate: profile.birthDate,
      );
    } catch (error) {
      Log.error('Vaccine card scan failed', error);
      if (mounted) {
        setState(() => _reading = false);
        messenger.showSnackBar(SnackBar(content: Text(l.vaccineScanFailed)));
      }
      return;
    } finally {
      ocr.close();
      // Not kept: the card's plain copy goes as soon as it's read.
      discardPicked(path);
    }
    if (!mounted) return;
    final byKey = {for (final s in statuses) s.dose.key: s};
    final birth = profile.birthDate!;
    setState(() {
      _reading = false;
      var added = 0;
      var already = 0;
      for (final d in scan.doses) {
        final keys = cardDoseKeys(d, byKey.keys);
        if (keys.isEmpty) {
          // Not on this child's schedule: the family says what it is.
          _unknown.add(CardUnknownRow(text: d.row, date: d.date));
          continue;
        }
        // Before the child was born: a misread, not a dose.
        if (d.date.isBefore(DateUtils.dateOnly(birth))) continue;
        for (final key in keys) {
          final s = byKey[key]!;
          if (s.done) {
            if (s.givenOn == null || !DateUtils.isSameDay(s.givenOn, d.date)) {
              already++;
            }
            continue;
          }
          _toggled[key] = true;
          _dates[key] = d.date;
          _fromCard[key] = d;
          _confirmed.remove(key);
          added++;
        }
      }
      // A second photo of the same card doesn't list its rows twice.
      for (final row in scan.unknown) {
        if (!_unknown.any((u) => u.text == row.text && u.date == row.date)) {
          _unknown.add(row);
        }
      }
      _scanMessages = [
        if (added > 0)
          l.vaccineScanFound(added)
        else if (_unknown.isEmpty)
          l.vaccineScanNothing,
        if (already > 0) l.vaccineScanAlready(already),
        if (scan.futureRows > 0) l.vaccineScanFutureRows(scan.futureRows),
      ];
    });
  }

  /// The family said which dose an unnamed row is.
  void _mapUnknown(int i, DoseStatus s) {
    setState(() {
      final row = _unknown.removeAt(i);
      final key = s.dose.key;
      _toggled[key] = true;
      _dates[key] = row.date;
      _fromCard[key] = CardDose(
        kinds: {s.dose.kind},
        dose: s.dose.dose,
        date: row.date,
        row: row.text,
      );
      _confirmed.remove(key);
    });
  }

  String get _back => widget.first
      ? '/family/${widget.profileId}'
      : '/family/${widget.profileId}/vaccines';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider(widget.profileId)).value;
    final events = ref.watch(timelineProvider(widget.profileId)).value;
    final today = ref.watch(todayProvider);
    Widget body;
    if (profile == null || events == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (!isUnderFive(profile.birthDate, today)) {
      body = Center(child: Text(l.growthUnderFiveOnly));
    } else {
      final plan = _plan ??= vaccinePlanOf(events);
      final statuses = matchSchedule(
        birthDate: profile.birthDate!,
        records: vaccineRecords(events),
        now: today,
        plan: plan,
      );
      if (widget.startWithScan && !_startedScan) {
        _startedScan = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scan(ImageSource.camera, profile, statuses);
        });
      }
      _statuses = statuses;
      body = _form(context, profile, plan, statuses, today);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l.vaccineSetupTitle),
        leading: BackButton(onPressed: () => context.go(_back)),
      ),
      body: body,
    );
  }

  Widget _form(
    BuildContext context,
    Profile profile,
    VaccinePlan plan,
    List<DoseStatus> statuses,
    DateTime today,
  ) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final muted = text.bodyMedium?.copyWith(color: context.usra.inkMuted);
    final soon = today.add(const Duration(days: dueSoonDays));
    final checklist = [
      for (final s in statuses)
        if (s.done ||
            (s.followed && !s.plannedOn.isAfter(soon)) ||
            _fromCard.containsKey(s.dose.key))
          s,
    ];
    final ticked = _ticked;
    final needsCheck = _needsCheck(statuses);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(profile.displayName, style: text.titleLarge),
        const SizedBox(height: 16),
        Text(l.vaccineRouteTitle, style: text.titleMedium),
        const SizedBox(height: 8),
        RadioGroup<VaccineRoute>(
          groupValue: plan.route,
          onChanged: (r) {
            if (r == null || r == plan.route) return;
            setState(() {
              _plan = plan.copyWith(route: r);
              _forgetScan();
            });
          },
          child: Column(
            children: [
              for (final r in VaccineRoute.values)
                RadioListTile<VaccineRoute>(
                  key: ValueKey('vaccine-route-${r.name}'),
                  value: r,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    r == VaccineRoute.government
                        ? l.vaccineRouteGovernment
                        : l.vaccineRouteHexavalent,
                  ),
                  subtitle: Text(
                    r == VaccineRoute.government
                        ? l.vaccineRouteGovernmentHint
                        : l.vaccineRouteHexavalentHint,
                  ),
                ),
            ],
          ),
        ),
        Text(
          l.personVaccineSource(
            plan.route == VaccineRoute.government
                ? l.vaccineRouteGovernment
                : l.vaccineRouteHexavalent,
            DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
                .format(DateTime.parse(egyptScheduleCheckedOn)),
          ),
          key: const ValueKey('vaccine-setup-source'),
          style: muted,
        ),
        const SizedBox(height: 16),
        Text(l.vaccineOptionalTitle, style: text.titleMedium),
        const SizedBox(height: 4),
        Text(l.vaccineOptionalHint, style: muted),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in optionalVaccines)
              FilterChip(
                key: ValueKey('vaccine-optional-${k.name}'),
                selected: plan.optional.contains(k),
                label: Text(vaccineName(l, k)),
                onSelected: (on) => setState(
                  () => _plan = plan.copyWith(
                    optional: on
                        ? {...plan.optional, k}
                        : ({...plan.optional}..remove(k)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text(l.vaccineSetupGiven, style: text.titleMedium),
        const SizedBox(height: 4),
        Text(l.vaccineSetupGivenHint, style: muted),
        const SizedBox(height: 12),
        DocumentScanCard(
          keyPrefix: 'vaccine-scan',
          title: l.vaccineScanTitle,
          help: l.vaccineScanHelp,
          readingText: l.vaccineScanReading,
          reading: _reading,
          messages: _scanMessages,
          onScan: _saving ? null : (source) => _scan(source, profile, statuses),
        ),
        const SizedBox(height: 8),
        if (_toMark(statuses, today).length >= markPastFrom)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('setup-mark-past'),
              onPressed: _saving ? null : () => _markPast(statuses, today),
              icon: const Icon(Icons.done_all),
              label: Text(l.vaccineMarkPast),
            ),
          ),
        if (checklist.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(l.vaccineSetupNoneYet),
          ),
        for (final age in {for (final s in checklist) s.dose.ageMonths}) ...[
          () {
            final group = [
              for (final s in checklist)
                if (s.dose.ageMonths == age) s,
            ];
            final done = group.where(ticked).length;
            return Padding(
              padding: const EdgeInsets.only(top: UsraSpacing.s3),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: UsraSpacing.s2,
                children: [
                  Text(
                    '${doseAge(l, group.first.dose)} · '
                    '${localizedDigitsIn(context, l.vaccineGroupCount(done, group.length))}',
                    key: ValueKey('setup-group-$age'),
                    style: text.titleMedium,
                  ),
                  if (done < group.length)
                    TextButton(
                      key: ValueKey('setup-all-$age'),
                      onPressed: () => setState(() {
                        for (final s in group) {
                          _toggled[s.dose.key] = true;
                        }
                      }),
                      child: Text(l.vaccineTickAll),
                    ),
                ],
              ),
            );
          }(),
          for (final s in checklist)
            if (s.dose.ageMonths == age)
              _CardCheck(
                card: ticked(s) ? _fromCard[s.dose.key] : null,
                confirmed: _confirmed.contains(s.dose.key),
                doseKey: s.dose.key,
                onConfirmed: (on) => setState(
                  () => on
                      ? _confirmed.add(s.dose.key)
                      : _confirmed.remove(s.dose.key),
                ),
                child: CheckboxListTile(
                  key: ValueKey('setup-${s.dose.key}'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: ticked(s),
                  onChanged: (on) =>
                      setState(() => _toggled[s.dose.key] = on == true),
                  title: Text(doseName(l, s.dose)),
                  subtitle: Text(
                    '${doseAge(l, s.dose)} · '
                    '${s.dose.required ? l.vaccineRequired : l.vaccineOptional}'
                    '${ticked(s) ? ' · ${_fmt(context, _dateOf(s))}' : ''}',
                  ),
                  secondary: ticked(s) && !s.done
                      ? IconButton(
                          key: ValueKey('setup-date-${s.dose.key}'),
                          tooltip: l.vaccineChangeDate,
                          icon: const Icon(Icons.edit_calendar_outlined),
                          onPressed: () async {
                            final picked = await pickGivenDate(
                              context,
                              initial: _dateOf(s),
                              birthDate: profile.birthDate!,
                            );
                            if (picked != null) {
                              setState(() => _dates[s.dose.key] = picked);
                            }
                          },
                        )
                      : null,
                ),
              ),
        ],
        if (_unknown.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l.vaccineUnknownTitle, style: text.titleMedium),
          for (final (i, row) in _unknown.indexed)
            _UnknownRow(
              key: ValueKey('setup-unknown-$i-${row.hashCode}'),
              index: i,
              label: row.text.isEmpty
                  ? l.vaccineUnknownDateOnly(_fmt(context, row.date))
                  : l.vaccineUnknownRow(row.text, _fmt(context, row.date)),
              choices: [
                for (final s in statuses)
                  if (!ticked(s)) s,
              ],
              onPick: (s) => _mapUnknown(i, s),
              onSkip: () => setState(() => _unknown.removeAt(i)),
            ),
        ],
        const SizedBox(height: 24),
        if (needsCheck)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l.vaccineConfirmNeeded,
              key: const ValueKey('vaccine-confirm-needed'),
              style: TextStyle(color: Severity.headsUp.foregroundOf(context)),
            ),
          ),
        FilledButton(
          key: const ValueKey('vaccine-setup-save'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: _saving || needsCheck
              ? null
              : () => _save(profile, plan, statuses, checklist),
          child: Text(l.familySave),
        ),
        if (widget.first) ...[
          const SizedBox(height: UsraSpacing.s2),
          TextButton(
            key: const ValueKey('vaccine-setup-skip'),
            onPressed: () => context.go(_back),
            child: Text(l.vaccineSetupSkipNow),
          ),
        ],
      ],
    );
  }

  /// Doses "mark everything due so far" would tick here: due so far and
  /// not ticked yet.
  List<DoseStatus> _toMark(
    List<DoseStatus> statuses,
    DateTime today, {
    bool withOptional = false,
  }) => [
    for (final s in pastDosesToMark(
      statuses,
      today,
      withOptional: withOptional,
    ))
      if (!_ticked(s)) s,
  ];

  /// Ticks every dose due so far, after asking; nothing is saved until
  /// Save, and the snack bar puts the ticks back as they were.
  Future<void> _markPast(List<DoseStatus> statuses, DateTime today) async {
    final l = AppLocalizations.of(context);
    final doses = await confirmMarkPast(
      context,
      required: _toMark(statuses, today),
      optional: [
        for (final s in _toMark(statuses, today, withOptional: true))
          if (!s.dose.required) s,
      ],
    );
    if (doses == null || doses.isEmpty || !mounted) return;
    final before = {
      for (final s in doses)
        s.dose.key: (
          ticked: _toggled[s.dose.key],
          date: _dates[s.dose.key],
          card: _fromCard[s.dose.key],
        ),
    };
    setState(() {
      // On its schedule day: not a date chosen or read for it before.
      for (final s in doses) {
        _toggled[s.dose.key] = true;
        _dates.remove(s.dose.key);
        _fromCard.remove(s.dose.key);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const ValueKey('setup-mark-past-done'),
        content: Text(
          localizedDigitsIn(context, l.vaccineMarkPastDone(doses.length)),
        ),
        action: SnackBarAction(
          label: l.doseUndo,
          onPressed: () {
            if (!mounted) return;
            setState(() {
              for (final MapEntry(:key, :value) in before.entries) {
                if (value.ticked case final t?) {
                  _toggled[key] = t;
                } else {
                  _toggled.remove(key);
                }
                if (value.date case final d?) _dates[key] = d;
                if (value.card case final c?) _fromCard[key] = c;
              }
            });
          },
        ),
      ),
    );
  }

  /// The checklist's doses, as last built.
  List<DoseStatus> _statuses = const [];

  /// The given date for a ticked dose: its record's, the one chosen, or
  /// the day it was planned for (never in the future, never moved to today
  /// by a missing earlier dose). Not before its minimum interval after the
  /// previous dose of the same vaccine ticked here, if that one was dated
  /// later.
  DateTime _dateOf(DoseStatus s) {
    final today = ref.read(todayProvider);
    final known = s.givenOn ?? _dates[s.dose.key];
    if (known != null) return givenDateOn(known, today);
    var date = s.plannedOn;
    final prev = _statuses
        .where(
          (p) =>
              p.dose.kind == s.dose.kind &&
              p.dose.dose < s.dose.dose &&
              _ticked(p),
        )
        .lastOrNull;
    if (prev != null && s.dose.hasInterval) {
      final after = s.dose.earliestAfter(_dateOf(prev));
      if (after.isAfter(date)) date = after;
    }
    return givenDateOn(date, today);
  }

  Future<void> _save(
    Profile profile,
    VaccinePlan plan,
    List<DoseStatus> statuses,
    List<DoseStatus> checklist,
  ) async {
    if (_needsCheck(statuses)) return;
    final l = AppLocalizations.of(context);
    final db = ref.read(databaseProvider);
    final ticked = _ticked;
    final changes = vaccineRecordChanges(l, statuses, {
      for (final s in checklist)
        if (ticked(s) != s.done) s.dose.key: ticked(s) ? _dateOf(s) : null,
    });
    final events = ref.read(timelineProvider(profile.id)).value ?? const [];
    if (!await confirmRemovingUserRecords(
      context,
      changes,
      userVaccineRecordIds(events),
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    final isNew =
        changes.add.isNotEmpty || !await _hasVaccinePlan(db, profile.id);
    if (isNew && !await ref.read(saveGateProvider).allow()) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (!mounted) return;
    try {
      await db.saveSingletonEvent(
        profileId: profile.id,
        type: VaccinePlanFields.type,
        dataJson: plan.toJson(),
      );
      await applyVaccineChanges(db, profile.id, changes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.saveFailed)));
      return;
    }
    if (!mounted) return;
    await askForReminderAccess(ref);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l.vaccineSetupSaved)));
    context.go('/family/${profile.id}/vaccines');
  }
}

/// A checklist row ticked from the card: marked until the family says it
/// matches the card, with what the card said and anything to look at.
class _CardCheck extends StatelessWidget {
  const _CardCheck({
    required this.card,
    required this.confirmed,
    required this.doseKey,
    required this.onConfirmed,
    required this.child,
  });

  /// What the card said; null for a row not read from it (or unticked).
  final CardDose? card;
  final bool confirmed;
  final String doseKey;
  final ValueChanged<bool> onConfirmed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final card = this.card;
    if (card == null) return child;
    final l = AppLocalizations.of(context);
    final style = TextStyle(color: Severity.headsUp.foregroundOf(context));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      // A Material, so the tiles' ink shows on the colour.
      child: Material(
        color: confirmed
            ? Theme.of(context).colorScheme.surface
            : Severity.headsUp.backgroundOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Severity.headsUp.foregroundOf(context).withAlpha(80),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              child,
              if (card.row.isNotEmpty)
                Text(l.vaccineFromCard(card.row), style: style),
              if (card.doseGuessed)
                Text(
                  l.vaccineDoseGuessed,
                  key: ValueKey('setup-guessed-$doseKey'),
                  style: style,
                ),
              if (card.dateUnsure)
                Text(
                  l.vaccineDateCheck,
                  key: ValueKey('setup-date-check-$doseKey'),
                  style: style,
                ),
              CheckboxListTile(
                key: ValueKey('setup-confirm-$doseKey'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: confirmed,
                title: Text(l.vaccineConfirmCard),
                onChanged: (on) => onConfirmed(on == true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dated row of the card the phone couldn't name: pick which dose it
/// is, or skip it.
class _UnknownRow extends StatelessWidget {
  const _UnknownRow({
    super.key,
    required this.index,
    required this.label,
    required this.choices,
    required this.onPick,
    required this.onSkip,
  });

  final int index;
  final String label;
  final List<DoseStatus> choices;
  final ValueChanged<DoseStatus> onPick;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      color: Severity.headsUp.backgroundOf(context),
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, key: ValueKey('setup-unknown-label-$index')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey('setup-unknown-pick-$index'),
              isExpanded: true,
              decoration: InputDecoration(labelText: l.vaccineUnknownPick),
              items: [
                for (final s in choices)
                  DropdownMenuItem(
                    value: s.dose.key,
                    child: Text(
                      '${doseName(l, s.dose)} · ${doseAge(l, s.dose)}',
                    ),
                  ),
              ],
              onChanged: (key) {
                final s = choices.where((c) => c.dose.key == key).firstOrNull;
                if (s != null) onPick(s);
              },
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                key: ValueKey('setup-unknown-skip-$index'),
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: onSkip,
                child: Text(l.vaccineUnknownSkip),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
