import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/design/pebble.dart';
import '../../core/design/status_chip.dart';
import '../../core/design/tokens.dart';
import '../../core/providers.dart';
import '../../core/util/localized_digits.dart';
import '../../l10n/app_localizations.dart';
import '../children/growth.dart' show addMonths, isUnderFive;
import '../children/vaccines_screen.dart' show watchChildVaccines;
import '../medicines/dose_schedule.dart';
import '../medicines/medicine_text.dart';
import '../medicines/medicines_providers.dart';
import '../medicines/reminders.dart' show snoozeDuration;
import '../sick_days/sick_days_providers.dart';
import '../../core/design/undo_snack_bar.dart';

/// The one thing to show for a person on Home and the family list.
class PersonStatus {
  const PersonStatus({
    required this.severity,
    required this.label,
    required this.icon,
    this.needsAttention = false,
  });

  final Severity severity;
  final String label;
  final IconData icon;

  /// Named in Home's "needs your attention" line.
  final bool needsAttention;
}

/// How long after its time a dose still counts as just due, so nobody is told
/// a dose was missed while they're about to give it.
const doseMissedAfter = Duration(hours: 1);

/// When a snoozed [dose]'s reminder rings: ten minutes after it was snoozed,
/// or after its time if it was snoozed a little before that.
DateTime doseSnoozedUntil(PlannedDose dose) =>
    snoozeRingsAt(dose, dose.log!.at.toLocal());

/// When a snooze of [dose] made at [snoozedAt] rings.
DateTime snoozeRingsAt(PlannedDose dose, DateTime snoozedAt) =>
    (snoozedAt.isAfter(dose.at) ? snoozedAt : dose.at).add(snoozeDuration);

/// Not marked, and past due by more than [doseMissedAfter]. A snooze only puts
/// that off: the hour counts from when its reminder rang.
bool isDoseMissed(PlannedDose dose, DateTime now) {
  if (dose.isDone) return false;
  final due = dose.log == null ? dose.at : doseSnoozedUntil(dose);
  return now.isAfter(due.add(doseMissedAfter));
}

/// Keeps a page that shows today's doses honest while it stays open: statuses
/// depend on the time, so they move on, and today's doses change at midnight.
mixin TodayRefresh<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  late final AppLifecycleListener _lifecycle;
  late final Timer _minute;
  late DateTime _day;

  DateTime _today() {
    final now = ref.read(clockProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  void _refresh() {
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
    _day = _today();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _minute = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _minute.cancel();
    _lifecycle.dispose();
    super.dispose();
  }
}

/// Marks [dose] taken now, with Undo in the confirmation that names the
/// medicine and the person.
Future<void> logDoseTaken(
  BuildContext context,
  WidgetRef ref,
  PlannedDose dose,
) async {
  final l = AppLocalizations.of(context);
  final db = ref.read(databaseProvider);
  final r = dose.regimen;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await db.logDose(
      r.medicine.id,
      dose.scheduledAt,
      DoseOutcome.taken,
      at: ref.read(clockProvider)(),
    );
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.saveFailed)));
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      undoSnackBar(
        content: Text(
          l.homeDoseLogged(medicineTitle(r.medicine), r.person.displayName),
        ),
        actionKey: ValueKey('home-dose-undo-${r.medicine.id}'),
        label: l.doseUndo,
        onUndo: () => db.clearDoseLog(r.medicine.id, dose.scheduledAt),
      ),
    );
}

/// "8 months" under two years, "68 years" after, in [l]'s language and digits;
/// null without a birth date, or for one in the future.
String? ageLabel(AppLocalizations l, DateTime? birthDate, DateTime now) {
  if (birthDate == null) return null;
  final today = DateTime(now.year, now.month, now.day);
  final birth = DateTime(birthDate.year, birthDate.month, birthDate.day);
  if (birth.isAfter(today)) return null;
  var months = (today.year - birth.year) * 12 + today.month - birth.month;
  if (addMonths(birth, months).isAfter(today)) months--;
  String shown(int n) => digitsIn(l.localeName, '$n');
  if (months < 24) return l.personAgeMonths(months, shown(months));
  final years = months ~/ 12;
  return l.personAgeYears(years, shown(years));
}

/// The person's status; null while something it depends on is loading or
/// failed, so "nothing needed" is only ever said after checking everything.
/// [none] is returned when everything was checked and nothing is due.
PersonStatus? watchPersonStatus(
  BuildContext context,
  WidgetRef ref,
  Profile person, {
  required PersonStatus none,
}) {
  final l = AppLocalizations.of(context);
  final episodes = ref.watch(episodesProvider(person.id)).value;
  final doses = ref.watch(todayDosesProvider).value;
  if (episodes == null || doses == null) return null;
  final now = ref.watch(clockProvider)();

  if (episodes.any((e) => e.endedAt == null)) {
    return PersonStatus(
      severity: Severity.headsUp,
      label: person.sex == 'female' ? l.statusSickFemale : l.statusSick,
      icon: Icons.thermostat,
      needsAttention: true,
    );
  }

  final open = <PlannedDose>[
    for (final d in doses)
      if (d.regimen.person.id == person.id && !d.isDone) d,
  ];
  if (open.any((d) => isDoseMissed(d, now))) {
    return PersonStatus(
      severity: Severity.actSoon,
      label: l.statusDoseMissed,
      icon: Icons.warning_amber_rounded,
      needsAttention: true,
    );
  }

  // Null for over-fives, and for a child while their records load: only say
  // "nothing needed" once those are in.
  final vaccines = watchChildVaccines(ref, person);
  if (vaccines == null && isUnderFive(person.birthDate, now)) return null;
  if (vaccines?.next.overdue.isNotEmpty ?? false) {
    return PersonStatus(
      severity: Severity.actSoon,
      label: l.statusVaccineOverdue,
      icon: Icons.warning_amber_rounded,
      needsAttention: true,
    );
  }

  // Anything still open and not missed: coming up, just due, or snoozed.
  if (open.isNotEmpty) {
    return PersonStatus(
      severity: Severity.info,
      label: l.statusDoseNext(formatDoseTime(context, open.first.at)),
      icon: Icons.schedule,
    );
  }
  return none;
}

/// A person's colour. By sex, as the Product Definition says; neutral when
/// it isn't known. Changing this one function recolours every person.
Color personColor(BuildContext context, String? sex) => switch (sex) {
  'female' => context.usra.orchidSoft,
  'male' => context.usra.skySoft,
  _ => context.usra.surfaceSoft,
};

/// A seed that stays the same for an id across runs, unlike String.hashCode,
/// so a person keeps their pebble's shape.
int pebbleSeed(String id) {
  var hash = 0x811C9DC5;
  for (final unit in id.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// The status as a chip, or quiet text when nothing is needed.
class PersonStatusLabel extends StatelessWidget {
  const PersonStatusLabel({super.key, required this.status});

  final PersonStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.severity == Severity.good) {
      return Text(
        status.label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelLarge,
      );
    }
    return StatusChip(
      severity: status.severity,
      label: status.label,
      icon: status.icon,
    );
  }
}

/// A longer name would shrink below readable inside [MiniPersonPebble], which
/// doesn't grow with the phone's text size either, so write it out beside the
/// pebble instead.
bool nameGoesBesidePebble(BuildContext context, Profile person) =>
    person.displayName.characters.length > 4 ||
    MediaQuery.textScalerOf(context).scale(1) > 1;

/// A small person's pebble with a short name, for dose rows. [initialOnly]
/// shows just the first letter, for when the full name is written beside it
/// because it would shrink too far to read in here.
class MiniPersonPebble extends StatelessWidget {
  const MiniPersonPebble({
    super.key,
    required this.person,
    this.initialOnly = false,
  });

  final Profile person;
  final bool initialOnly;

  @override
  Widget build(BuildContext context) => Pebble(
    seed: pebbleSeed(person.id),
    color: personColor(context, person.sex),
    width: 48,
    height: 48,
    shadow: false,
    child: Padding(
      padding: const EdgeInsets.all(2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          initialOnly
              ? person.displayName.characters.first
              : person.displayName,
          maxLines: 1,
          semanticsLabel: person.displayName,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    ),
  );
}
