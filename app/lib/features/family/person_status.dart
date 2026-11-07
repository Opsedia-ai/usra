import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/design/pebble.dart';
import '../../core/design/status_chip.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../children/vaccines_screen.dart' show watchChildVaccines;
import '../medicines/dose_schedule.dart';
import '../medicines/medicine_text.dart';
import '../medicines/medicines_providers.dart';
import '../sick_days/sick_days_providers.dart';

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
      label: l.statusSick,
      icon: Icons.thermostat,
      needsAttention: true,
    );
  }

  final open = <PlannedDose>[
    for (final d in doses)
      if (d.regimen.person.id == person.id && !d.isDone) d,
  ];
  if (open.any((d) => d.at.isBefore(now) && d.log == null)) {
    return PersonStatus(
      severity: Severity.actSoon,
      label: l.statusDoseMissed,
      icon: Icons.warning_amber_rounded,
      needsAttention: true,
    );
  }

  final vaccines = watchChildVaccines(ref, person);
  if (vaccines?.next.overdue.isNotEmpty ?? false) {
    return PersonStatus(
      severity: Severity.actSoon,
      label: l.statusVaccineOverdue,
      icon: Icons.warning_amber_rounded,
      needsAttention: true,
    );
  }

  for (final d in open) {
    if (!d.at.isBefore(now)) {
      return PersonStatus(
        severity: Severity.info,
        label: l.statusDoseNext(formatDoseTime(context, d.at)),
        icon: Icons.schedule,
      );
    }
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

/// A small person's pebble with a short name, for dose rows.
class MiniPersonPebble extends StatelessWidget {
  const MiniPersonPebble({super.key, required this.person});

  final Profile person;

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
          person.displayName,
          maxLines: 1,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    ),
  );
}
