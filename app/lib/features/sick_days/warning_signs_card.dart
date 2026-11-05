import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../doctors/call_buttons.dart' show openContact;
import '../family/emergency_card_screen.dart' show ambulanceNumber;
import 'fever.dart';

/// Warning signs for the person's age, with sources, the ones what was
/// logged matches on top, and the ambulance button. Informational only.
class WarningSignsCard extends StatelessWidget {
  const WarningSignsCard({
    super.key,
    required this.person,
    required this.episode,
    required this.readings,
    required this.now,
  });

  final Profile person;
  final SickEpisode episode;
  final List<TemperatureReading> readings;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final age = ageGroupOf(person.birthDate, now);
    final signs = warningSignsFor(age);
    final matched = matchedWarnings(
      episode: episode,
      readings: readings,
      birthDate: person.birthDate,
      now: now,
    );
    final color = Severity.urgent.foreground;
    Widget bullet(WarningSign s, {bool strong = false}) => Padding(
      key: ValueKey('warning-${strong ? 'matched-' : ''}${s.key}'),
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: text.bodyLarge?.copyWith(color: color)),
          Expanded(
            child: Text(
              l.warnSign(s.key),
              style: strong
                  ? text.bodyLarge?.copyWith(fontWeight: FontWeight.w700)
                  : text.bodyLarge,
            ),
          ),
        ],
      ),
    );
    final sources = {for (final s in signs) ...s.sources}.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return Card(
      key: const ValueKey('sick-day-warnings'),
      color: Severity.urgent.background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: UsraColors.emergency,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.warnTitle,
                    style: text.titleMedium?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            if (age == AgeGroup.unknown) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                key: const ValueKey('warning-no-birth-date'),
                style: TextButton.styleFrom(
                  alignment: AlignmentDirectional.centerStart,
                  padding: EdgeInsets.zero,
                ),
                onPressed: () => context.go('/family/${person.id}/edit'),
                icon: const Icon(Icons.cake_outlined),
                label: Text(l.warnNoBirthDate),
              ),
            ],
            if (matched.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                key: const ValueKey('warning-matched'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: UsraColors.surface,
                  border: Border.all(color: UsraColors.emergency, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l.warnLogged, style: text.titleSmall),
                    for (final s in signs)
                      if (matched.contains(s.key)) bullet(s, strong: true),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              l.warnEmergency,
              style: text.titleSmall?.copyWith(color: color),
            ),
            for (final s in signs)
              if (s.level == WarningLevel.emergency) bullet(s),
            const SizedBox(height: 8),
            Text(
              l.warnDoctorNow,
              style: text.titleSmall?.copyWith(color: color),
            ),
            for (final s in signs)
              if (s.level == WarningLevel.doctorNow) bullet(s),
            if (age == AgeGroup.under3Months || age == AgeGroup.unknown) ...[
              const SizedBox(height: 8),
              Text(
                l.warnArmpitNote,
                key: const ValueKey('warning-armpit-note'),
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('sick-day-ambulance'),
              style: FilledButton.styleFrom(
                backgroundColor: UsraColors.emergency,
                minimumSize: const Size.fromHeight(56),
                textStyle: text.titleMedium,
              ),
              onPressed: () => openContact(
                context,
                Uri(scheme: 'tel', path: ambulanceNumber),
              ),
              icon: const Icon(Icons.call),
              label: Text(l.emergencyCallAmbulance(ambulanceNumber)),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('sick-day-doctors'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => context.go('/doctors'),
              icon: const Icon(Icons.medical_services_outlined),
              label: Text(l.warnCallDoctor),
            ),
            const SizedBox(height: 12),
            Text(l.warnFooter, style: text.bodyMedium),
            const SizedBox(height: 8),
            Text(
              l.warnSources,
              style: text.bodySmall?.copyWith(color: UsraColors.textMuted),
            ),
            for (final s in sources)
              TextButton(
                key: ValueKey('warning-source-${s.name}'),
                style: TextButton.styleFrom(
                  alignment: AlignmentDirectional.centerStart,
                  padding: EdgeInsets.zero,
                ),
                onPressed: () =>
                    openContact(context, Uri.parse(warningSourceUrls[s]!)),
                child: Text(l.warnSourceName(s.name)),
              ),
          ],
        ),
      ),
    );
  }
}
