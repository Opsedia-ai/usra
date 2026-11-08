import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/status_chip.dart';
import '../../core/design/tokens.dart';
import '../../core/files/photo_store.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../doctors/doctors_providers.dart';
import 'dose_schedule.dart';
import 'medicine_text.dart';
import 'medicines_providers.dart';

/// "Prescription of 5 Nov 2026".
String prescriptionTitle(BuildContext context, Prescription p) =>
    AppLocalizations.of(context).prescriptionTitle(
      DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
          .format(storedDay(p.prescribedOn)),
    );

/// A course's state for a chip: "Day 3 of 7", Ended or Stopped; null for
/// a medicine that goes on.
String? courseLabel(AppLocalizations l, Medicine m, DateTime now) {
  if (!m.active) return l.medicineStopped;
  if (medicineEnded(m, now)) return l.medicineEnded;
  final progress = courseProgress(m, now);
  return progress == null ? null : l.courseDayOf(progress.day, progress.total);
}

/// One prescription: date, doctor, reason, photo and its medicines with how
/// far each course has gone. Stop, edit or delete it as a whole.
class PrescriptionScreen extends ConsumerWidget {
  const PrescriptionScreen({
    super.key,
    required this.profileId,
    required this.prescriptionId,
  });

  final String profileId;
  final String prescriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final prescription = ref.watch(prescriptionProvider(prescriptionId));
    final p = prescription.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(p == null ? '' : prescriptionTitle(context, p)),
        actions: [
          if (p != null) ...[
            IconButton(
              key: const ValueKey('rx-edit'),
              tooltip: l.prescriptionEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.go(
                '/family/$profileId/prescriptions/$prescriptionId/edit',
              ),
            ),
            IconButton(
              key: const ValueKey('rx-delete'),
              tooltip: l.medicineDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ],
      ),
      body: prescription.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (p) => p == null
            ? Center(child: Text(l.prescriptionNotFound))
            : _Details(profileId: profileId, prescription: p),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(l.prescriptionDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l.familyCancel),
          ),
          FilledButton(
            key: const ValueKey('rx-delete-confirm'),
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
      await db.softDeletePrescription(prescriptionId);
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
  const _Details({required this.profileId, required this.prescription});

  final String profileId;
  final Prescription prescription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final p = prescription;
    final doctor = p.doctorId == null
        ? null
        : ref.watch(doctorProvider(p.doctorId!)).value;
    final medicines =
        ref.watch(prescriptionMedicinesProvider(p.id)).value ?? const [];
    final photos = decodeMedicinePhotos(p.photosJson);
    final store = ref.watch(medicinePhotoStoreProvider);
    final now = ref.watch(clockProvider)();

    final rows = <(String, String)>[
      if (doctor != null) (l.medicineDoctor, doctor.name),
      if (p.diagnosis != null) (l.prescriptionDiagnosis, p.diagnosis!),
      if (p.notes != null) (l.prescriptionNotes, p.notes!),
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (!p.active)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l.medicineStopped,
              style: text.titleMedium?.copyWith(color: context.usra.inkMuted),
            ),
          ),
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.labelLarge),
                Text(value, style: text.bodyLarge),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(l.prescriptionMedicines, style: text.titleMedium),
        const SizedBox(height: 8),
        for (final m in medicines)
          _MedicineTile(profileId: profileId, medicine: m, now: now),
        if (photos.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(l.prescriptionPhotos, style: text.titleSmall),
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
                  key: ValueKey('rx-photo-$i'),
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
        // Resume only brings back what Stop stopped; medicines stopped on
        // their own are restarted from their own page.
        if (p.active || medicines.any((m) => m.stoppedWithPrescription))
          OutlinedButton.icon(
            key: const ValueKey('rx-toggle-active'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
            onPressed: () async {
              try {
                await ref
                    .read(databaseProvider)
                    .setPrescriptionActive(p.id, !p.active);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(l.saveFailed)));
                }
              }
            },
            icon: Icon(
              p.active ? Icons.pause_circle_outline : Icons.play_circle_outline,
            ),
            label: Text(p.active ? l.prescriptionStop : l.prescriptionResume),
          ),
      ],
    );
  }
}

class _MedicineTile extends ConsumerWidget {
  const _MedicineTile({
    required this.profileId,
    required this.medicine,
    required this.now,
  });

  final String profileId;
  final Medicine medicine;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final m = medicine;
    final schedule = ref.watch(doseScheduleProvider(m.id)).value;
    final course = courseLabel(l, m, now);
    final running = m.active && !medicineEnded(m, now);
    return Card(
      child: ListTile(
        key: ValueKey('rx-medicine-${m.id}'),
        onTap: () => context.go('/family/$profileId/medicines/${m.id}'),
        leading: CircleAvatar(
          backgroundColor: context.usra.primarySoft,
          child: Icon(medicineFormIcon(m.form), color: context.usra.primary),
        ),
        title: Text(medicineTitle(m)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.instructions != null) Text(m.instructions!),
            Text(
              schedule == null
                  ? l.medicineAsNeeded
                  : scheduleSummary(context, schedule),
            ),
            if (courseDays(m) case final days? when course == null)
              Text(l.prescriptionDaysCount(days)),
            if (course != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: StatusChip(
                  key: ValueKey('rx-course-${m.id}'),
                  severity: running ? Severity.good : Severity.info,
                  label: course,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
