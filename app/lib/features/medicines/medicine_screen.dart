import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/tokens.dart';
import '../../core/files/photo_store.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../doctors/doctors_providers.dart';
import 'dose_schedule.dart';
import 'medicine_text.dart';
import 'medicines_providers.dart';

/// One medicine: what the doctor prescribed, its photos, schedule and the
/// history of doses taken or skipped.
class MedicineScreen extends ConsumerWidget {
  const MedicineScreen({
    super.key,
    required this.profileId,
    required this.medicineId,
  });

  final String profileId;
  final String medicineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final medicine = ref.watch(medicineProvider(medicineId));
    final m = medicine.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(m == null ? '' : medicineTitle(m)),
        actions: [
          if (m != null) ...[
            IconButton(
              key: const ValueKey('medicine-edit'),
              tooltip: l.medicineEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.go('/family/$profileId/medicines/$medicineId/edit'),
            ),
            IconButton(
              key: const ValueKey('medicine-delete'),
              tooltip: l.medicineDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref, m),
            ),
          ],
        ],
      ),
      body: medicine.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (m) => m == null
            ? Center(child: Text(l.medicineNotFound))
            : _Details(medicine: m),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Medicine m,
  ) async {
    final l = AppLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(l.medicineDeleteConfirm(m.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l.familyCancel),
          ),
          FilledButton(
            key: const ValueKey('medicine-delete-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: UsraColors.emergency,
            ),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l.medicineDelete),
          ),
        ],
      ),
    );
    if (yes != true) return;
    final db = ref.read(databaseProvider);
    final photos = ref.read(medicinePhotoStoreProvider);
    try {
      await db.softDeleteMedicine(m.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.saveFailed)));
      }
      return;
    }
    try {
      await photos.prune(await db.liveMedicinePhotos());
    } catch (_) {
      // Left for the next save or delete to clean up.
    }
    if (context.mounted) context.go('/family/$profileId/medicines');
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.medicine});

  final Medicine medicine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMMMd(locale);
    final m = medicine;
    final schedule = ref.watch(doseScheduleProvider(m.id)).value;
    final logs = ref.watch(medicineDoseLogsProvider(m.id)).value ?? const [];
    final doctor = m.doctorId == null
        ? null
        : ref.watch(doctorProvider(m.doctorId!)).value;
    final photos = decodeMedicinePhotos(m.photosJson);
    final store = ref.watch(medicinePhotoStoreProvider);
    final now = ref.watch(clockProvider)();
    final next = schedule == null || !m.active
        ? null
        : DoseRule.of(m, schedule).nextAfter(now);

    final start = date.format(storedDay(m.startOn));
    final rows = <(String, String)>[
      if (m.form != null) (l.medicineForm, medicineFormLabel(l, m.form!)),
      (
        l.medicineSchedule,
        schedule == null
            ? l.medicineAsNeeded
            : scheduleSummary(context, schedule),
      ),
      if (m.instructions != null) (l.medicineInstructions, m.instructions!),
      if (doctor != null) (l.medicineDoctor, doctor.name),
      (
        l.medicineStart,
        m.endOn == null
            ? l.medicineFrom(start)
            : l.medicineFromTo(start, date.format(storedDay(m.endOn!))),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (!m.active || medicineEnded(m, now))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              m.active ? l.medicineEnded : l.medicineStopped,
              style: text.titleMedium?.copyWith(color: UsraColors.textMuted),
            ),
          ),
        if (next != null)
          Card(
            color: UsraColors.primaryTint,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l.medicineNextDose(
                  '${DateFormat.MMMEd(locale).format(next)} '
                  '${formatDoseTime(context, next)}',
                ),
                style: text.titleMedium,
              ),
            ),
          ),
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.labelLarge),
                Text(value, style: text.bodyLarge),
              ],
            ),
          ),
        if (photos.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(l.medicinePhotos, style: text.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final image = store.image(photos[i]);
                return GestureDetector(
                  key: ValueKey('medicine-photo-$i'),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (dialog) => Dialog.fullscreen(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(dialog),
                        child: InteractiveViewer(
                          child: Center(child: PhotoImage(image: image)),
                        ),
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: PhotoImage(
                      image: image,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      cacheWidth: 360,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 20),
        OutlinedButton.icon(
          key: const ValueKey('medicine-toggle-active'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
          onPressed: () =>
              ref.read(databaseProvider).setMedicineActive(m.id, !m.active),
          icon: Icon(
            m.active ? Icons.pause_circle_outline : Icons.play_circle_outline,
          ),
          label: Text(m.active ? l.medicineStop : l.medicineResume),
        ),
        const SizedBox(height: 28),
        Text(l.medicineHistory, style: text.titleMedium),
        const SizedBox(height: 8),
        if (logs.isEmpty)
          Text(l.medicineHistoryEmpty, style: text.bodyLarge)
        else
          for (final log in logs) _HistoryRow(log: log),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.log});

  final DoseLog log;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final planned = log.scheduledAt.toLocal();
    final (icon, color, label) = switch (log.status) {
      DoseOutcome.taken => (
        Icons.check_circle,
        Severity.good.foreground,
        l.doseTaken,
      ),
      DoseOutcome.snoozed => (
        Icons.snooze,
        Severity.headsUp.foreground,
        l.doseSnoozed,
      ),
      _ => (Icons.remove_circle_outline, UsraColors.textMuted, l.doseSkipped),
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        '${DateFormat.MMMEd(locale).format(planned)} '
        '${formatDoseTime(context, planned)}',
      ),
      subtitle: Text(
        l.doseMarkedAt(label, formatDoseTime(context, log.at.toLocal())),
      ),
    );
  }
}
