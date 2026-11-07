import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/database/app_database.dart';
import '../../core/design/status_chip.dart';
import '../../core/design/tokens.dart';
import '../../core/preferences.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../family/family_screen.dart' show profilesProvider;
import '../family/member_screen.dart' show profileProvider, timelineProvider;
import '../follow_ups/follow_ups_providers.dart' show todayProvider;
import '../medicines/medicines_providers.dart' show reminderSchedulerProvider;
import '../reports/reports_screens.dart' show shareVaccinationRecord;
import 'child_vaccines.dart';
import 'egypt_vaccine_sources.dart';
import 'egypt_vaccines.dart';
import 'growth.dart' show isUnderFive;

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
  return showDatePicker(
    context: context,
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

/// Saves [changes] in one transaction; nothing when there are none.
Future<void> applyVaccineChanges(
  AppDatabase db,
  String profileId,
  VaccineRecordChanges changes,
) async {
  if (changes.add.isEmpty && changes.remove.isEmpty && changes.redate.isEmpty) {
    return;
  }
  await db.replaceEvents(
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

/// Which doses [filter] shows: "All" is the plan plus any optional dose
/// already given; "Optional" also lists the ones the family doesn't follow.
List<DoseStatus> filterDoses(List<DoseStatus> statuses, VaccineFilter filter) =>
    [
      for (final s in statuses)
        if (switch (filter) {
          VaccineFilter.all => s.followed || s.done,
          VaccineFilter.required => s.dose.required,
          VaccineFilter.optional => !s.dose.required,
          VaccineFilter.overdue => s.state == DoseState.overdue,
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
  var _filter = VaccineFilter.all;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider(widget.profileId));
    final id = widget.profileId;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.vaccinesTitle),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(c.profile.displayName, style: text.titleLarge),
        const SizedBox(height: 4),
        Text(
          c.plan.route == VaccineRoute.government
              ? l.vaccineRouteGovernment
              : l.vaccineRouteHexavalent,
          style: text.bodyMedium?.copyWith(color: context.usra.inkMuted),
        ),
        const SizedBox(height: 12),
        VaccineProgressSummary(child: c, today: today),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey('vaccine-setup-open'),
          onPressed: () => context.go('/family/${c.profile.id}/vaccines/setup'),
          icon: const Icon(Icons.checklist),
          label: Text(l.vaccineSetupOpen),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in VaccineFilter.values)
              ChoiceChip(
                key: ValueKey('vaccine-filter-${f.name}'),
                selected: _filter == f,
                onSelected: (_) => setState(() => _filter = f),
                label: Text(switch (f) {
                  VaccineFilter.all => l.vaccineFilterAll,
                  VaccineFilter.required => l.vaccineFilterRequired,
                  VaccineFilter.optional => l.vaccineFilterOptional,
                  VaccineFilter.overdue => l.vaccineFilterOverdue,
                }),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(l.vaccineFilterEmpty, textAlign: TextAlign.center),
          ),
        for (final s in shown)
          DoseTile(
            status: s,
            note: c.plan.notes[s.dose.key],
            onTap: () => showDoseSheet(context, ref, c, s),
          ),
        const SizedBox(height: 16),
        Text(
          l.vaccinesDisclaimer(egyptScheduleCheckedOn),
          style: text.bodySmall?.copyWith(color: context.usra.inkMuted),
        ),
        const _Sources(),
      ],
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
      DoseState.overdue => l.vaccineOverdue(date(status.dueOn)),
      DoseState.due => l.vaccineDue(date(status.dueOn)),
      DoseState.later => l.vaccineLater(date(status.dueOn)),
      DoseState.notFollowed => l.vaccineNotFollowed,
      DoseState.tooLate => l.vaccineTooLate,
      DoseState.notNeeded => l.vaccineNotNeeded,
    };
    final muted = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: context.usra.inkMuted);
    return ListTile(
      key: ValueKey('dose-${dose.kind.name}-${dose.dose}'),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      title: Text(doseName(l, dose)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${doseAge(l, dose)} · '
            '${dose.required ? l.vaccineRequired : l.vaccineOptional}',
          ),
          if (note != null) Text(note!, style: muted),
        ],
      ),
      trailing: StatusChip(severity: status.state.severity, label: label),
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
  // A dose not yet given defaults to its due date, never a future one; opened
  // to log it now, to today.
  late DateTime _date = givenDateOn(
    widget.status.givenOn ??
        (widget.given ? DateTime.now() : widget.status.dueOn),
    DateTime.now(),
  );
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
    try {
      final plan = child.plan.withNote(s.dose.key, _note.text);
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
            title: Text(l.vaccineDoseGiven),
          ),
          if (_given)
            ListTile(
              key: const ValueKey('dose-date'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(l.vaccineDoseDate),
              subtitle: Text(_fmtc(_date)),
              onTap: () async {
                final picked = await pickGivenDate(
                  context,
                  initial: _date,
                  birthDate: widget.child.profile.birthDate!,
                );
                if (picked != null) setState(() => _date = picked);
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
  });

  final String profileId;

  /// Right after the child was added: "Later" leads to their page.
  final bool first;

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
      body = _form(context, profile, plan, statuses, today);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l.vaccineSetupTitle),
        leading: BackButton(onPressed: () => context.go(_back)),
        actions: [
          if (widget.first)
            TextButton(
              key: const ValueKey('vaccine-setup-skip'),
              onPressed: () => context.go(_back),
              child: Text(l.vaccineSetupSkip),
            ),
        ],
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
        if (s.done || (s.followed && !s.dueOn.isAfter(soon))) s,
    ];
    bool ticked(DoseStatus s) => _toggled[s.dose.key] ?? s.done;
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
            if (r != null) setState(() => _plan = plan.copyWith(route: r));
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
        if (checklist.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(l.vaccineSetupNoneYet),
          ),
        for (final s in checklist)
          CheckboxListTile(
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
        const SizedBox(height: 24),
        FilledButton(
          key: const ValueKey('vaccine-setup-save'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: _saving
              ? null
              : () => _save(profile, plan, statuses, checklist),
          child: Text(l.familySave),
        ),
      ],
    );
  }

  /// The given date for a ticked dose: its record's, the one chosen, or
  /// the due date (never in the future).
  DateTime _dateOf(DoseStatus s) =>
      givenDateOn(s.givenOn ?? _dates[s.dose.key] ?? s.dueOn, DateTime.now());

  Future<void> _save(
    Profile profile,
    VaccinePlan plan,
    List<DoseStatus> statuses,
    List<DoseStatus> checklist,
  ) async {
    final l = AppLocalizations.of(context);
    final db = ref.read(databaseProvider);
    bool ticked(DoseStatus s) => _toggled[s.dose.key] ?? s.done;
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
