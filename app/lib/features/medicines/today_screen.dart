import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/pill_chip.dart';
import '../../core/design/status_chip.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../family/family_screen.dart' show profilesProvider;
import '../family/person_status.dart';
import 'dose_schedule.dart';
import 'medicine_text.dart';
import 'medicines_providers.dart';
import 'reminder_access_card.dart';
import 'reminders.dart' show snoozeDuration, snoozeIdFor;

/// How long before its time a dose already counts as "now", so nobody is told
/// they'd be taking it early when it's only minutes away.
const doseNowAhead = Duration(minutes: 15);

/// Where a dose sits on the Medicines tab.
enum DoseGroup { missed, now, later, done }

/// [isDoseMissed] decides "missed", so Home and this tab always agree.
DoseGroup doseGroupOf(PlannedDose dose, DateTime now) {
  if (dose.isDone) return DoseGroup.done;
  if (isDoseMissed(dose, now)) return DoseGroup.missed;
  if (dose.log != null || !dose.at.isAfter(now.add(doseNowAhead))) {
    return DoseGroup.now;
  }
  return DoseGroup.later;
}

/// "الصبح", "بالليل": the part of the day a later dose falls in.
String dosePartOfDay(AppLocalizations l, DateTime at) => switch (at.hour) {
  >= 5 && < 12 => l.dayPartMorning,
  >= 12 && < 15 => l.dayPartNoon,
  >= 15 && < 18 => l.dayPartAfternoon,
  _ => l.dayPartNight,
};

/// Text is big enough, or the phone narrow enough, that a card's buttons and
/// chips go on their own lines instead of squeezing.
bool _isCompact(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(16) > 20 ||
    MediaQuery.sizeOf(context).width < 360;

/// The Medicines tab: today's doses for the whole family or one person, with
/// what was missed first, then what's due now, then what's coming later.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  late final AppLifecycleListener _lifecycle;
  late final Timer _minute;
  late DateTime _day = _today();

  /// The person shown; null is everyone.
  String? _person;

  DateTime _today() {
    final now = ref.read(clockProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  /// Doses move between the groups with the clock, and today's doses change
  /// at midnight.
  void _tick() {
    final today = _today();
    if (today != _day) {
      _day = today;
      ref.invalidate(todayLogsProvider);
      ref.invalidate(todayDosesProvider);
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    // Back from the settings screens, or the next morning.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.invalidate(reminderAccessProvider);
        ref.invalidate(todayLogsProvider);
        ref.invalidate(todayDosesProvider);
      },
    );
    _minute = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _minute.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final doses = ref.watch(todayDosesProvider);
    final people = ref.watch(profilesProvider).value ?? const <Profile>[];
    final now = ref.watch(clockProvider)();
    final person = people.where((p) => p.id == _person).firstOrNull;
    return Scaffold(
      body: doses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(UsraSpacing.s6),
            child: Text(l.homeLoadError, textAlign: TextAlign.center),
          ),
        ),
        data: (all) {
          final list = person == null
              ? all
              : [
                  for (final d in all)
                    if (d.regimen.person.id == person.id) d,
                ];
          return ListView(
            padding: const EdgeInsets.only(
              top: UsraSpacing.s4,
              bottom: UsraSpacing.s5,
            ),
            children: [
              _Gutter(child: _Header(person: person)),
              const _Gutter(child: ReminderAccessCard()),
              if (people.length > 1)
                _PersonChips(
                  people: people,
                  selected: person?.id,
                  onSelected: (id) => setState(() => _person = id),
                ),
              if (list.isEmpty)
                _Gutter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: UsraSpacing.s7,
                    ),
                    child: Text(
                      person == null
                          ? l.medicinesTodayEmpty
                          : l.medicinesTodayEmptyFor(person.displayName),
                      key: const ValueKey('medicines-empty'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
              ..._groups(context, list, now),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _groups(
    BuildContext context,
    List<PlannedDose> list,
    DateTime now,
  ) {
    final l = AppLocalizations.of(context);
    List<PlannedDose> of(DoseGroup g) => [
      for (final d in list)
        if (doseGroupOf(d, now) == g) d,
    ];

    /// One heading per time: "دلوقتي · ٢:٠٠ م", "بالليل · ٨:٠٠ م".
    Iterable<Widget> byTime(
      List<PlannedDose> doses,
      String Function(DateTime) part,
    ) sync* {
      final times = <DateTime, List<PlannedDose>>{};
      for (final d in doses) {
        times.putIfAbsent(d.at, () => []).add(d);
      }
      for (final MapEntry(key: at, value: group) in times.entries) {
        yield _GroupTitle('${part(at)} · ${formatDoseTime(context, at)}');
        for (final d in group) {
          yield DoseCard(dose: d);
        }
      }
    }

    final missed = of(DoseGroup.missed);
    final done = of(DoseGroup.done);
    return [
      if (missed.isNotEmpty) ...[
        _GroupTitle(l.doseGroupMissed),
        for (final d in missed) DoseCard(dose: d),
      ],
      ...byTime(of(DoseGroup.now), (_) => l.doseGroupNow),
      ...byTime(of(DoseGroup.later), (at) => dosePartOfDay(l, at)),
      // Stays here so a wrong tap can be taken back after the snackbar goes.
      if (done.isNotEmpty) ...[
        _GroupTitle(l.doseGroupDone),
        for (final d in done) DoseCard(dose: d),
      ],
    ];
  }
}

class _Gutter extends StatelessWidget {
  const _Gutter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: child,
  );
}

/// The title, and a link to every medicine: the chosen person's, or everyone's.
class _Header extends StatelessWidget {
  const _Header({required this.person});

  final Profile? person;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final id = person?.id;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Semantics(
          header: true,
          child: Text(
            l.navMedicines,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        TextButton(
          key: const ValueKey('medicines-all'),
          onPressed: () => context.push(
            id == null ? '/medicines/all' : '/family/$id/medicines',
          ),
          child: Text(
            l.medicinesAll,
            style: UsraType.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// All, then each person, scrolling sideways.
class _PersonChips extends StatelessWidget {
  const _PersonChips({
    required this.people,
    required this.selected,
    required this.onSelected,
  });

  final List<Profile> people;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      key: const ValueKey('medicines-filter'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: UsraSpacing.s2,
      ),
      child: Row(
        children: [
          UsraPill(
            key: const ValueKey('medicines-filter-all'),
            label: l.medicinesFilterAll,
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final p in people) ...[
            const SizedBox(width: UsraSpacing.s2),
            UsraPill(
              key: ValueKey('medicines-filter-${p.id}'),
              label: p.displayName,
              selected: selected == p.id,
              onTap: () => onSelected(p.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => _Gutter(
    child: Padding(
      padding: const EdgeInsets.only(
        top: UsraSpacing.s3,
        bottom: UsraSpacing.s1,
      ),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: UsraType.label.copyWith(
            color: context.usra.inkMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

/// The snackbar's words for a dose just marked.
typedef _DoseMessage = String Function(
  AppLocalizations l,
  String medicine,
  String person,
);

/// Marks the dose, then says so in [_DoseMessage]'s words with an Undo.
typedef _Mark = void Function(String status, _DoseMessage message);

/// One dose: who, what, how much, and what can be done with it now. A missed
/// dose asks Taken or Not taken; one that's due, Taken or later; one still to
/// come can only be logged as taken early. Every mark can be undone.
class DoseCard extends ConsumerWidget {
  const DoseCard({super.key, required this.dose});

  final PlannedDose dose;

  String get _id =>
      '${dose.regimen.medicine.id}-${dose.at.millisecondsSinceEpoch}';

  /// Saves [status] and offers Undo, naming the medicine and the person.
  Future<void> _mark(
    BuildContext context,
    WidgetRef ref,
    String status,
    _DoseMessage message,
  ) async {
    final l = AppLocalizations.of(context);
    final db = ref.read(databaseProvider);
    final messenger = ScaffoldMessenger.of(context);
    // Read now: marking a dose can move its card, unmounting this context.
    final container = ProviderScope.containerOf(context, listen: false);
    final r = dose.regimen;
    final now = ref.read(clockProvider)();
    try {
      final saved = await db.logDose(
        r.medicine.id,
        dose.scheduledAt,
        status,
        at: now,
      );
      if (saved && status == DoseOutcome.snoozed) {
        await _scheduleSnooze(container, r, now);
      }
    } catch (_) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(_snackBar(Text(l.saveFailed)));
      return;
    }
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        _snackBar(
          Text(message(l, medicineTitle(r.medicine), r.person.displayName)),
          action: SnackBarAction(
            key: ValueKey('dose-snack-undo-$_id'),
            label: l.doseUndo,
            onPressed: () => db.clearDoseLog(r.medicine.id, dose.scheduledAt),
          ),
        ),
      );
  }

  /// A snoozed dose gets no planned reminder (see `planReminders`), so it
  /// needs its own, with the same wording rules as every other reminder,
  /// discreet ones included. If it can't be set the snooze doesn't stand, so
  /// the dose keeps its planned reminder.
  Future<void> _scheduleSnooze(
    ProviderContainer container,
    Regimen r,
    DateTime now,
  ) async {
    final rings = (now.isAfter(dose.at) ? now : dose.at).add(snoozeDuration);
    try {
      await container
          .read(reminderSchedulerProvider)
          .add(
            reminderTextsOf(container).reminder(
              r,
              id: snoozeIdFor(r.medicine.id, dose.scheduledAt),
              at: rings,
              scheduledAt: dose.scheduledAt,
            ),
          );
    } catch (_) {
      await container
          .read(databaseProvider)
          .clearDoseLog(r.medicine.id, dose.scheduledAt);
      rethrow;
    }
  }

  SnackBar _snackBar(Widget content, {SnackBarAction? action}) => SnackBar(
    content: content,
    action: action,
    behavior: SnackBarBehavior.floating,
    shape: const StadiumBorder(),
    duration: const Duration(seconds: 6),
    persist: false,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.usra;
    final group = doseGroupOf(dose, ref.watch(clockProvider)());
    final compact = _isCompact(context);
    void mark(String status, _DoseMessage message) =>
        unawaited(_mark(context, ref, status, message));
    final later = _LaterButton(id: _id, mark: mark);
    final actions = switch (group) {
      DoseGroup.missed => _MissedButtons(id: _id, mark: mark),
      DoseGroup.now => _DueButtons(id: _id, mark: mark),
      DoseGroup.later => compact ? later : null,
      DoseGroup.done => _Done(dose: dose, id: _id),
    };
    return _Gutter(
      child: Padding(
        padding: const EdgeInsets.only(top: UsraSpacing.s2),
        child: Card(
          key: ValueKey('dose-$_id'),
          color: group == DoseGroup.now ? c.primarySoft : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: UsraSpacing.s4,
              vertical: UsraSpacing.s3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Summary(
                  dose: dose,
                  id: _id,
                  group: group,
                  trailing: group == DoseGroup.later && !compact ? later : null,
                ),
                if (actions != null) ...[
                  const SizedBox(height: UsraSpacing.s2),
                  actions,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The person, the medicine and the doctor's words. Opens the medicine.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.dose,
    required this.id,
    required this.group,
    this.trailing,
  });

  final PlannedDose dose;
  final String id;
  final DoseGroup group;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final r = dose.regimen;
    final compact = _isCompact(context);
    final missed = group == DoseGroup.missed;
    final details = [
      // The other groups have the time in their heading.
      if (missed) formatDoseTime(context, dose.at),
      ?r.schedule.amount,
      ?r.medicine.instructions,
    ].join(' · ');
    final nameBeside = nameGoesBesidePebble(context, r.person);
    final chip = StatusChip(
      severity: Severity.actSoon,
      label: l.doseGroupMissed,
      icon: Icons.warning_amber_rounded,
    );
    final course = courseProgress(r.medicine, dose.at);
    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(UsraRadius.md),
            onTap: () => context.push(
              '/family/${r.person.id}/medicines/${r.medicine.id}',
            ),
            child: Row(
              children: [
                MiniPersonPebble(person: r.person, initialOnly: nameBeside),
                const SizedBox(width: UsraSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (nameBeside)
                        Text(
                          r.person.displayName,
                          key: ValueKey('dose-person-$id'),
                          style: UsraType.label.copyWith(
                            color: c.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      Text(
                        medicineTitle(r.medicine),
                        style: UsraType.body.copyWith(
                          color: c.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (details.isNotEmpty)
                        Text(
                          details,
                          style: UsraType.body.copyWith(color: c.inkMuted),
                        ),
                      if (course case final course?)
                        Text(
                          l.courseDayOf(course.day, course.total),
                          key: ValueKey('dose-course-$id'),
                          style: UsraType.label.copyWith(color: c.primary),
                        ),
                      if (missed && compact)
                        Padding(
                          padding: const EdgeInsets.only(top: UsraSpacing.s1),
                          child: chip,
                        ),
                      if (dose.log?.status == DoseOutcome.snoozed && !missed)
                        Padding(
                          padding: const EdgeInsets.only(top: UsraSpacing.s1),
                          child: StatusChip(
                            key: ValueKey('dose-snoozed-$id'),
                            severity: Severity.info,
                            icon: Icons.snooze,
                            label: l.doseSnoozedUntil(
                              formatDoseTime(context, doseSnoozedUntil(dose)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (missed && !compact) ...[
          const SizedBox(width: UsraSpacing.s2),
          chip,
        ],
        if (trailing case final trailing?) ...[
          const SizedBox(width: UsraSpacing.s2),
          trailing,
        ],
      ],
    );
  }
}

/// Two buttons side by side, or one above the other when text is large.
class _Buttons extends StatelessWidget {
  const _Buttons({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => _isCompact(context)
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            first,
            const SizedBox(height: UsraSpacing.s2),
            second,
          ],
        )
      : Row(
          children: [
            Expanded(child: first),
            const SizedBox(width: UsraSpacing.s2),
            Expanded(child: second),
          ],
        );
}

/// An outlined button that stays readable on the tinted "now" card.
ButtonStyle _outlined(BuildContext context) => OutlinedButton.styleFrom(
  backgroundColor: context.usra.surface,
  minimumSize: Size(
    0,
    Theme.of(context).filledButtonTheme.style?.minimumSize
            ?.resolve(const {})
            ?.height ??
        UsraSizes.touchTarget,
  ),
  textStyle: UsraType.body.copyWith(fontWeight: FontWeight.w600),
);

class _TakenButton extends StatelessWidget {
  const _TakenButton({required this.id, required this.mark});

  final String id;
  final _Mark mark;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    key: ValueKey('dose-taken-$id'),
    onPressed: () => mark(
      DoseOutcome.taken,
      (l, medicine, person) => l.homeDoseLogged(medicine, person),
    ),
    icon: const Icon(Icons.check),
    label: Text(AppLocalizations.of(context).doseTaken),
  );
}

void _markNotTaken(_Mark mark) => mark(
  DoseOutcome.skipped,
  (l, medicine, person) => l.doseLoggedNotTaken(medicine, person),
);

class _MissedButtons extends StatelessWidget {
  const _MissedButtons({required this.id, required this.mark});

  final String id;
  final _Mark mark;

  @override
  Widget build(BuildContext context) => _Buttons(
    first: _TakenButton(id: id, mark: mark),
    second: OutlinedButton(
      key: ValueKey('dose-skip-$id'),
      style: _outlined(context),
      onPressed: () => _markNotTaken(mark),
      child: Text(AppLocalizations.of(context).doseSkip),
    ),
  );
}

class _DueButtons extends StatelessWidget {
  const _DueButtons({required this.id, required this.mark});

  final String id;
  final _Mark mark;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Buttons(
          first: _TakenButton(id: id, mark: mark),
          second: OutlinedButton(
            key: ValueKey('dose-snooze-$id'),
            style: _outlined(context),
            onPressed: () => mark(
              DoseOutcome.snoozed,
              (l, medicine, person) => l.doseLoggedSnoozed(medicine, person),
            ),
            child: Text(l.doseSnoozeShort),
          ),
        ),
        // Sometimes a dose is left out on purpose: no need to wait an hour for
        // it to count as missed. Quieter than the two above.
        TextButton(
          key: ValueKey('dose-skip-$id'),
          onPressed: () => _markNotTaken(mark),
          child: Text(
            l.doseSkip,
            style: UsraType.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _LaterButton extends StatelessWidget {
  const _LaterButton({required this.id, required this.mark});

  final String id;
  final _Mark mark;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    key: ValueKey('dose-early-$id'),
    style: _outlined(context),
    onPressed: () => mark(
      DoseOutcome.taken,
      (l, medicine, person) => l.doseLoggedEarly(medicine, person),
    ),
    child: Text(AppLocalizations.of(context).doseTakenEarly),
  );
}

/// What was marked and when, with a way to take it back.
class _Done extends ConsumerWidget {
  const _Done({required this.dose, required this.id});

  final PlannedDose dose;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final log = dose.log!;
    final taken = log.status == DoseOutcome.taken;
    final at = log.at.toLocal();
    final status = !taken
        ? l.doseSkipped
        : at.isBefore(dose.at.subtract(doseNowAhead))
        ? l.doseTakenEarly
        : l.doseTaken;
    return Row(
      children: [
        ExcludeSemantics(
          child: Icon(
            taken ? Icons.check_circle : Icons.remove_circle_outline,
            color: taken
                ? Severity.good.foregroundOf(context)
                : context.usra.inkMuted,
          ),
        ),
        const SizedBox(width: UsraSpacing.s2),
        Expanded(
          child: Text(
            l.doseMarkedAt(status, formatDoseTime(context, at)),
            style: UsraType.body.copyWith(color: context.usra.ink),
          ),
        ),
        TextButton(
          key: ValueKey('dose-undo-$id'),
          onPressed: () => ref
              .read(databaseProvider)
              .clearDoseLog(dose.regimen.medicine.id, dose.scheduledAt),
          child: Text(l.doseUndo),
        ),
      ],
    );
  }
}
