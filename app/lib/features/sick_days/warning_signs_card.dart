import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/tokens.dart';
import '../../core/util/localized_digits.dart';
import '../../l10n/app_localizations.dart';
import '../doctors/call_buttons.dart' show openContact;
import '../doctors/contact_links.dart';
import '../doctors/doctors_providers.dart';
import '../family/emergency_card_screen.dart' show ambulanceNumber;
import 'fever.dart';

/// When to get help, for the person's age: what was logged that matches,
/// call an ambulance if, call the doctor if, each with a button, then the
/// sources. Informational only. No Dr. Usra here (Product Definition).
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
    final urgent = context.usra.urgent;
    final heading = text.titleMedium?.copyWith(fontSize: 17, height: 24 / 17);
    Widget bullet(WarningSign s, {bool strong = false}) => Padding(
      key: ValueKey('warning-${strong ? 'matched-' : ''}${s.key}'),
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: text.bodyLarge),
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
      child: Padding(
        padding: const EdgeInsets.all(UsraSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (age == AgeGroup.unknown) ...[
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
              const SizedBox(height: UsraSpacing.s2),
            ],
            if (matched.isNotEmpty) ...[
              Container(
                key: const ValueKey('warning-matched'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.usra.urgentSoft,
                  border: Border.all(color: urgent, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l.warnLogged, style: heading),
                    for (final s in signs)
                      if (matched.contains(s.key)) bullet(s, strong: true),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Semantics(
              header: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: urgent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l.warnEmergency,
                      style: heading?.copyWith(color: urgent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            for (final s in signs)
              if (s.level == WarningLevel.emergency) bullet(s),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey('sick-day-ambulance'),
              style: FilledButton.styleFrom(
                backgroundColor: urgent,
                foregroundColor: context.usra.onUrgent,
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: () => openContact(
                context,
                Uri(scheme: 'tel', path: ambulanceNumber),
              ),
              icon: const Icon(Icons.call_outlined),
              label: Text(
                l.emergencyCallAmbulance(
                  localizedDigitsIn(context, ambulanceNumber),
                ),
              ),
            ),
            const SizedBox(height: UsraSpacing.s4),
            Semantics(
              header: true,
              child: Text(l.warnDoctorNow, style: heading),
            ),
            const SizedBox(height: 4),
            for (final s in signs)
              if (s.level == WarningLevel.doctorNow) bullet(s),
            if (age == AgeGroup.under3Months || age == AgeGroup.unknown) ...[
              const SizedBox(height: 8),
              Text(
                l.warnArmpitNote,
                key: const ValueKey('warning-armpit-note'),
                style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 8),
            const _DoctorButton(),
            const SizedBox(height: 12),
            Text(l.warnFooter, style: text.bodyLarge),
            const SizedBox(height: 8),
            Text(l.warnSources, style: text.bodySmall),
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

/// One doctor with a number: calls them, by name. Several: asks which, since
/// the app can't know who this person sees. None: the list, to add one.
class _DoctorButton extends ConsumerWidget {
  const _DoctorButton();

  Future<void> _choose(BuildContext context, List<Doctor> doctors) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheet) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final d in doctors)
                ListTile(
                  key: ValueKey('sick-day-doctor-${d.id}'),
                  minTileHeight: UsraSizes.touchTarget,
                  leading: const Icon(Icons.call_outlined),
                  title: Text(d.name),
                  subtitle: d.specialty == null ? null : Text(d.specialty!),
                  onTap: () {
                    Navigator.of(sheet).pop();
                    openContact(context, callUri(d.phone)!);
                  },
                ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final callable = [
      for (final d in ref.watch(doctorsProvider).value ?? const <Doctor>[])
        if (callUri(d.phone) != null) d,
    ];
    final only = callable.length == 1 ? callable.single : null;
    return OutlinedButton.icon(
      key: const ValueKey('sick-day-doctors'),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      onPressed: only != null
          ? () => openContact(context, callUri(only.phone)!)
          : callable.isEmpty
          ? () => context.push('/doctors')
          : () => _choose(context, callable),
      icon: Icon(
        callable.isEmpty
            ? Icons.medical_services_outlined
            : Icons.call_outlined,
      ),
      label: Text(
        only == null ? l.warnCallDoctor : l.sickDayCallDoctorNamed(only.name),
      ),
    );
  }
}
