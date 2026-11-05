import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/tokens.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'dose_schedule.dart';
import 'medicine_text.dart';
import 'medicines_providers.dart';
import 'reminder_access_card.dart';

/// The Medicines tab: today's doses for the whole family, by time, each
/// with big Taken and Skip buttons.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Back from the settings screens, or the next morning.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.invalidate(reminderAccessProvider);
        ref.invalidate(todayLogsProvider);
        ref.invalidate(todayDosesProvider);
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final doses = ref.watch(todayDosesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.medicinesTodayTitle)),
      body: doses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          final groups = <DateTime, List<PlannedDose>>{};
          for (final d in list) {
            groups.putIfAbsent(d.at, () => []).add(d);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const ReminderAccessCard(),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Text(
                    l.medicinesTodayEmpty,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              for (final MapEntry(key: at, value: group) in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Text(
                    formatDoseTime(context, at),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                for (final d in group) DoseCard(dose: d),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// One dose: who, what, how much, and Taken / Skip, or what was marked
/// with a way to take it back.
class DoseCard extends ConsumerWidget {
  const DoseCard({super.key, required this.dose});

  final PlannedDose dose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final r = dose.regimen;
    final id = '${r.medicine.id}-${dose.at.millisecondsSinceEpoch}';
    final db = ref.read(databaseProvider);

    Future<void> mark(String status) async {
      try {
        await db.logDose(
          r.medicine.id,
          dose.scheduledAt,
          status,
          at: ref.read(clockProvider)(),
        );
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.saveFailed)));
      }
    }

    final log = dose.log;
    return Card(
      key: ValueKey('dose-$id'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => context.go(
                '/family/${r.person.id}/medicines/${r.medicine.id}',
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: UsraColors.primaryTint,
                    child: Icon(
                      medicineFormIcon(r.medicine.form),
                      color: UsraColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.person.displayName, style: text.labelLarge),
                        Text(
                          medicineTitle(r.medicine),
                          style: text.titleMedium,
                        ),
                        if (r.schedule.amount != null)
                          Text(r.schedule.amount!, style: text.bodyMedium),
                        if (r.medicine.instructions != null)
                          Text(r.medicine.instructions!, style: text.bodySmall),
                        if (courseProgress(r.medicine, dose.at) case final c?)
                          Text(
                            l.courseDayOf(c.day, c.total),
                            key: ValueKey('dose-course-$id'),
                            style: text.labelLarge?.copyWith(
                              color: UsraColors.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (dose.isDone)
              Row(
                children: [
                  Icon(
                    log!.status == DoseOutcome.taken
                        ? Icons.check_circle
                        : Icons.remove_circle_outline,
                    color: log.status == DoseOutcome.taken
                        ? Severity.good.foreground
                        : UsraColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.doseMarkedAt(
                        log.status == DoseOutcome.taken
                            ? l.doseTaken
                            : l.doseSkipped,
                        formatDoseTime(context, log.at.toLocal()),
                      ),
                      style: text.bodyLarge,
                    ),
                  ),
                  TextButton(
                    key: ValueKey('dose-undo-$id'),
                    onPressed: () =>
                        db.clearDoseLog(r.medicine.id, dose.scheduledAt),
                    child: Text(l.doseUndo),
                  ),
                ],
              )
            else ...[
              if (log?.status == DoseOutcome.snoozed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(l.doseSnoozed, style: text.bodyMedium),
                ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: ValueKey('dose-taken-$id'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 56),
                      ),
                      onPressed: () => mark(DoseOutcome.taken),
                      icon: const Icon(Icons.check),
                      label: Text(l.doseTaken),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: ValueKey('dose-skip-$id'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 56),
                      ),
                      onPressed: () => mark(DoseOutcome.skipped),
                      icon: const Icon(Icons.close),
                      label: Text(l.doseSkip),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
