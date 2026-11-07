import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/status_chip.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../family/member_screen.dart' show profileProvider;
import 'medicine_text.dart';
import 'medicines_providers.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(person == null ? '' : l.medicinesTitle(person.displayName)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('medicine-add'),
        onPressed: () => context.go('/family/$profileId/medicines/new'),
        icon: const Icon(Icons.add),
        label: Text(l.medicineAdd),
      ),
      body: medicines.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          final prescriptions =
              ref.watch(prescriptionsProvider(profileId)).value ?? const [];
          final text = Theme.of(context).textTheme;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              FilledButton.tonalIcon(
                key: const ValueKey('prescription-add'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                onPressed: () =>
                    context.go('/family/$profileId/prescriptions/new'),
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text(l.prescriptionAdd),
              ),
              if (prescriptions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(l.prescriptionsSection, style: text.titleMedium),
                const SizedBox(height: 8),
                for (final p in prescriptions)
                  _PrescriptionTile(profileId: profileId, prescription: p),
              ],
              const SizedBox(height: 20),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l.medicinesEmpty,
                    textAlign: TextAlign.center,
                    style: text.bodyLarge,
                  ),
                )
              else
                for (final m in list)
                  _MedicineTile(profileId: profileId, medicine: m),
            ],
          );
        },
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
    return Card(
      child: ListTile(
        key: ValueKey('prescription-${p.id}'),
        onTap: () => context.go('/family/$profileId/prescriptions/${p.id}'),
        leading: CircleAvatar(
          backgroundColor: context.usra.primarySoft,
          child: Icon(Icons.receipt_long_outlined, color: context.usra.primary),
        ),
        title: Text(prescriptionTitle(context, p)),
        subtitle: Text(
          [
            ?p.diagnosis,
            l.prescriptionCount(count),
            if (!p.active) l.medicineStopped,
          ].join(' · '),
        ),
      ),
    );
  }
}

class _MedicineTile extends ConsumerWidget {
  const _MedicineTile({required this.profileId, required this.medicine});

  final String profileId;
  final Medicine medicine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final schedule = ref.watch(doseScheduleProvider(medicine.id)).value;
    final now = ref.watch(clockProvider)();
    final ended = medicineEnded(medicine, now);
    return Card(
      child: ListTile(
        key: ValueKey('medicine-${medicine.id}'),
        onTap: () => context.go('/family/$profileId/medicines/${medicine.id}'),
        leading: CircleAvatar(
          backgroundColor: context.usra.primarySoft,
          child: Icon(
            medicineFormIcon(medicine.form),
            color: context.usra.primary,
          ),
        ),
        title: Text(medicineTitle(medicine)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              schedule == null
                  ? l.medicineAsNeeded
                  : scheduleSummary(context, schedule),
            ),
            if (!medicine.active || ended)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: StatusChip(
                  severity: Severity.info,
                  label: medicine.active ? l.medicineEnded : l.medicineStopped,
                ),
              )
            else if (courseProgress(medicine, now) case final c?)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: StatusChip(
                  key: ValueKey('medicine-course-${medicine.id}'),
                  severity: Severity.good,
                  label: l.courseDayOf(c.day, c.total),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
