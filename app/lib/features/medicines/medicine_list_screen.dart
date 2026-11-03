import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/severity_chip.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../family/member_screen.dart' show profileProvider;
import 'medicine_text.dart';
import 'medicines_providers.dart';

/// One person's medicines: the ones taken now first, then stopped ones.
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
        data: (list) => list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    l.medicinesEmpty,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  for (final m in list)
                    _MedicineTile(profileId: profileId, medicine: m),
                ],
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
    final ended = medicineEnded(medicine, DateTime.now());
    return Card(
      child: ListTile(
        key: ValueKey('medicine-${medicine.id}'),
        onTap: () => context.go('/family/$profileId/medicines/${medicine.id}'),
        leading: CircleAvatar(
          backgroundColor: UsraColors.primaryTint,
          child: Icon(
            medicineFormIcon(medicine.form),
            color: UsraColors.primary,
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
                child: SeverityChip(
                  severity: Severity.info,
                  label: medicine.active ? l.medicineEnded : l.medicineStopped,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
