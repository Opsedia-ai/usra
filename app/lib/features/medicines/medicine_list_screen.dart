import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/buttons.dart';
import '../../core/design/list_row.dart';
import '../../core/design/tokens.dart';
import '../../core/design/usra_mark.dart';
import '../../core/design/type.dart';
import '../../core/util/localized_digits.dart';
import '../../l10n/app_localizations.dart';
import '../family/family_screen.dart' show profilesProvider;
import '../family/member_screen.dart' show profileProvider;
import 'medicine_text.dart';
import 'medicines_providers.dart';
import '../../core/util/separator.dart';
import 'prescription_screen.dart' show prescriptionTitle;

/// One person's prescriptions, newest first, then their medicines: the
/// ones taken now first, then stopped ones.
class MedicineListScreen extends ConsumerWidget {
  const MedicineListScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final person = ref.watch(profileProvider(profileId)).value;
    final medicines = ref.watch(medicinesProvider(profileId));
    final router = GoRouter.of(context);
    return Scaffold(
      appBar: AppBar(
        // Reached after saving a medicine with nothing under it in the
        // stack: back goes to the person's page then (e2e #5).
        leading: BackButton(
          key: const ValueKey('medicines-back'),
          onPressed: () =>
              router.canPop() ? router.pop() : router.go('/family/$profileId'),
        ),
        title: Text(person == null ? '' : l.medicinesTitle(person.displayName)),
      ),
      body: medicines.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          final prescriptions =
              ref.watch(prescriptionsProvider(profileId)).value ?? const [];
          return ListView(
            // The same 20 side margins as the Medicines tab.
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              // Adding a medicine is the page's one filled action; a
              // prescription is the outlined second.
              UsraPillButton(
                key: const ValueKey('medicine-add'),
                icon: Icons.add,
                label: l.medicineAdd,
                onPressed: () => context.go('/family/$profileId/medicines/new'),
              ),
              const SizedBox(height: UsraSpacing.s2),
              OutlinedButton.icon(
                key: const ValueKey('prescription-add'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.usra.ink,
                  side: BorderSide(color: context.usra.lineStrong),
                ),
                onPressed: () =>
                    context.go('/family/$profileId/prescriptions/new'),
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text(l.prescriptionAdd),
              ),
              if (prescriptions.isNotEmpty) ...[
                const SizedBox(height: UsraSpacing.s3),
                UsraGroupLabel(l.prescriptionsSection),
                UsraListCard(
                  children: [
                    for (final p in prescriptions)
                      _PrescriptionTile(profileId: profileId, prescription: p),
                  ],
                ),
              ],
              const SizedBox(height: UsraSpacing.s4),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: UsraMarkedEmpty(l.medicinesEmpty),
                )
              else
                UsraListCard(
                  children: [
                    for (final m in list)
                      _MedicineTile(profileId: profileId, medicine: m),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Everyone's medicines, person by person, from the Medicines tab's "All
/// medicines" link.
class AllMedicinesScreen extends ConsumerWidget {
  const AllMedicinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final people = ref.watch(profilesProvider).value ?? const <Profile>[];
    final all = [
      for (final p in people)
        (person: p, list: ref.watch(medicinesProvider(p.id))),
    ];
    final byPerson = [
      for (final e in all)
        if (e.list.value case final medicines? when medicines.isNotEmpty)
          (person: e.person, medicines: medicines),
    ];
    final profiles = ref.watch(profilesProvider);
    // "No medicines" is only ever said after reading everyone's.
    final failed = profiles.hasError || all.any((e) => e.list.hasError);
    final loading = !profiles.hasValue || all.any((e) => !e.list.hasValue);
    return Scaffold(
      appBar: AppBar(title: Text(l.medicinesAll)),
      body: failed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l.homeLoadError, textAlign: TextAlign.center),
              ),
            )
          : loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (byPerson.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: UsraMarkedEmpty(l.medicinesEmpty),
                  ),
                for (final (i, e) in byPerson.indexed) ...[
                  if (i > 0) const SizedBox(height: UsraSpacing.s2),
                  UsraGroupLabel(e.person.displayName),
                  UsraListCard(
                    children: [
                      for (final m in e.medicines)
                        _MedicineTile(profileId: e.person.id, medicine: m),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

class _PrescriptionTile extends ConsumerWidget {
  const _PrescriptionTile({
    required this.profileId,
    required this.prescription,
  });

  final String profileId;
  final Prescription prescription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = prescription;
    final count =
        ref.watch(prescriptionMedicinesProvider(p.id)).value?.length ?? 0;
    return UsraListRow(
      key: ValueKey('prescription-${p.id}'),
      onTap: () => context.go('/family/$profileId/prescriptions/${p.id}'),
      leading: const IconBox(icon: Icons.receipt_long_outlined),
      title: prescriptionTitle(context, p),
      subtitleText: [
        ?p.diagnosis,
        l.prescriptionCount(count),
        if (!p.active) l.prescriptionStopped,
      ].join(partSeparator),
    );
  }
}

/// A medicine: its schedule, then a muted "stopped", "finished" or course day.
class _MedicineTile extends ConsumerWidget {
  const _MedicineTile({required this.profileId, required this.medicine});

  final String profileId;
  final Medicine medicine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final schedule = ref.watch(doseScheduleProvider(medicine.id)).value;
    final now = ref.watch(clockProvider)();
    final ended = medicineEnded(medicine, now);
    final muted = UsraType.label.copyWith(
      color: c.inkMuted,
      fontWeight: FontWeight.w400,
    );
    final course = !medicine.active || ended
        ? null
        : courseProgress(medicine, now);
    return UsraListRow(
      key: ValueKey('medicine-${medicine.id}'),
      onTap: () => context.push('/family/$profileId/medicines/${medicine.id}'),
      leading: IconBox(
        icon: medicineFormIcon(medicine.form),
        tint: IconTint.medicines,
      ),
      title: medicineTitle(medicine),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            schedule == null
                ? l.medicineAsNeeded
                : scheduleSummary(context, schedule),
            style: muted,
          ),
          if (!medicine.active || ended)
            Text(
              medicine.active ? l.medicineEnded : l.medicineStopped,
              style: muted,
            )
          else if (course case final course?)
            Text(
              localizedDigitsIn(
                context,
                l.courseDayOf(course.day, course.total),
              ),
              key: ValueKey('medicine-course-${medicine.id}'),
              style: muted,
            ),
        ],
      ),
    );
  }
}
