import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/list_row.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/files/photo_store.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../doctors/doctors_providers.dart';
import '../family/family_screen.dart';
import 'dose_schedule.dart';
import 'medicine_text.dart';
import 'min_hours.dart';
import 'medicines_providers.dart';
import '../../core/util/separator.dart';
import '../../core/design/dialog.dart';
import 'prescription_screen.dart' show prescriptionTitle;

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
              icon: const Icon(Icons.mode_edit_outline_outlined),
              onPressed: () =>
                  context.go('/family/$profileId/medicines/$medicineId/edit'),
            ),
            // Only with someone to move it to.
            if ((ref.watch(profilesProvider).value?.length ?? 0) > 1)
              IconButton(
                key: const ValueKey('medicine-move'),
                tooltip: l.medicineMoveAction,
                icon: const Icon(Icons.swap_horiz),
                onPressed: () => context.push(
                  '/family/$profileId/medicines/$medicineId/move',
                ),
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
      builder: (dialog) => UsraAlertDialog(
        content: Text(l.medicineDeleteConfirm(m.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l.familyCancel),
          ),
          FilledButton(
            key: const ValueKey('medicine-delete-confirm'),
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
    final muted = UsraType.label.copyWith(
      color: context.usra.inkMuted,
      fontWeight: FontWeight.w400,
    );
    final schedule = ref.watch(doseScheduleProvider(m.id)).value;
    final logs = ref.watch(medicineDoseLogsProvider(m.id)).value ?? const [];
    final doctor = m.doctorId == null
        ? null
        : ref.watch(doctorProvider(m.doctorId!)).value;
    final photos = decodeMedicinePhotos(m.photosJson);
    final store = ref.watch(medicinePhotoStoreProvider);
    final now = ref.watch(clockProvider)();
    final prescription = m.prescriptionId == null
        ? null
        : ref.watch(prescriptionProvider(m.prescriptionId!)).value;
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
      if (m.minHoursBetweenDoses case final h?)
        (l.medicineMinHours, l.medicineMinHoursValue(formatHours(h, locale))),
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
              style: text.titleMedium?.copyWith(color: context.usra.inkMuted),
            ),
          ),
        if (courseProgress(m, now) case final c? when m.active)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l.courseDayOf(c.day, c.total),
              key: const ValueKey('medicine-course'),
              style: text.titleLarge,
            ),
          ),
        // A plain white card with an icon box, no tint.
        if (next != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(UsraSpacing.s4),
              child: Row(
                children: [
                  const IconBox(icon: Icons.schedule),
                  const SizedBox(width: UsraSpacing.s3),
                  Expanded(
                    child: Text(
                      l.medicineNextDose(
                        '${DateFormat.MMMEd(locale).format(next)} '
                        '${formatDoseTime(context, next)}',
                      ),
                      style: text.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (prescription != null)
          Padding(
            padding: const EdgeInsets.only(top: UsraSpacing.s3),
            child: UsraListCard(
              children: [
                UsraListRow(
                  key: const ValueKey('medicine-prescription'),
                  leading: const IconBox(icon: Icons.receipt_long_outlined),
                  title: l.prescriptionLink,
                  subtitleText: [
                    prescriptionTitle(context, prescription),
                    ?prescription.diagnosis,
                  ].join(partSeparator),
                  onTap: () => context.go(
                    '/family/${m.profileId}/prescriptions/${prescription.id}',
                  ),
                ),
              ],
            ),
          ),
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: muted),
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
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 56),
            foregroundColor: context.usra.ink,
            side: BorderSide(color: context.usra.lineStrong),
          ),
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
          UsraListCard(
            children: [for (final log in logs) _HistoryRow(log: log)],
          ),
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
        Severity.good.foregroundOf(context),
        l.doseTaken,
      ),
      DoseOutcome.snoozed => (
        Icons.snooze,
        context.usra.inkMuted,
        l.doseSnoozed,
      ),
      _ => (Icons.remove_circle_outline, context.usra.inkMuted, l.doseSkipped),
    };
    return UsraListRow(
      leading: ExcludeSemantics(child: Icon(icon, size: 20, color: color)),
      title:
          '${DateFormat.MMMEd(locale).format(planned)} '
          '${formatDoseTime(context, planned)}',
      subtitleText: l.doseMarkedAt(
        label,
        formatDoseTime(context, log.at.toLocal()),
      ),
    );
  }
}
