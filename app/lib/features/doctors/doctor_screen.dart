import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/status_chip.dart';
import '../../core/design/tokens.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'call_buttons.dart';
import 'doctors_providers.dart';

/// One doctor: how to reach them, their fee, and every family visit.
class DoctorScreen extends ConsumerWidget {
  const DoctorScreen({super.key, required this.doctorId});

  final String doctorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final doctor = ref.watch(doctorProvider(doctorId));
    final visits = ref.watch(doctorVisitsProvider(doctorId));
    return Scaffold(
      appBar: AppBar(
        title: Text(doctor.value?.name ?? ''),
        actions: [
          if (doctor.value != null) ...[
            IconButton(
              tooltip: l.doctorEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.go('/doctors/$doctorId/edit'),
            ),
            IconButton(
              key: const ValueKey('doctor-delete'),
              tooltip: l.doctorDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref, doctor.value!),
            ),
          ],
        ],
      ),
      body: doctor.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (d) {
          if (d == null) return Center(child: Text(l.doctorNotFound));
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _Details(doctor: d),
              const SizedBox(height: 20),
              CallButtons(phone: d.phone),
              const SizedBox(height: 28),
              Text(
                l.doctorVisits,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...visits.when(
                loading: () => [const LinearProgressIndicator()],
                error: (e, _) => [Text('$e')],
                data: (list) => list.isEmpty
                    ? [Text(l.doctorNoVisits)]
                    : [for (final v in list) _VisitTile(visit: v)],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Doctor doctor,
  ) async {
    final l = AppLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(l.doctorDeleteConfirm(doctor.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l.familyCancel),
          ),
          FilledButton(
            key: const ValueKey('doctor-delete-confirm'),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l.doctorDelete),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await ref.read(databaseProvider).softDeleteDoctor(doctor.id);
    if (context.mounted) context.go('/doctors');
  }
}

String _money(BuildContext context, int minor, String currency) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return '${NumberFormat.decimalPattern(locale).format(minor / 100)} $currency';
}

class _Details extends StatelessWidget {
  const _Details({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final d = doctor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (d.specialty != null)
              StatusChip(severity: Severity.info, label: d.specialty!),
            if (d.feeMinor != null)
              StatusChip(
                severity: Severity.info,
                label:
                    '${l.doctorFee}: ${_money(context, d.feeMinor!, l.currencyEgp)}',
              ),
          ],
        ),
        for (final (icon, value) in [
          (Icons.phone_outlined, d.phone),
          (Icons.local_hospital_outlined, d.clinic),
          (Icons.place_outlined, d.address),
          (Icons.notes_outlined, d.notes),
        ])
          if (value != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(icon, color: context.usra.inkMuted),
                  const SizedBox(width: 10),
                  Expanded(child: Text(value, style: text.bodyLarge)),
                ],
              ),
            ),
      ],
    );
  }
}

class _VisitTile extends ConsumerWidget {
  const _VisitTile({required this.visit});

  final DoctorVisit visit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final e = visit.event;
    final type = ref.watch(moduleRegistryProvider).recordTypes[e.type];
    return Card(
      child: ListTile(
        onTap: () => context.go('/family/${visit.person.id}'),
        title: Text(
          '${visit.person.displayName} · ${type?.labelOf(context) ?? e.type}',
        ),
        subtitle: Text(
          [
            DateFormat.yMMMd(locale).format(e.occurredAt),
            if (e.costMinor != null)
              _money(context, e.costMinor!, e.currency ?? ''),
          ].join(' · '),
        ),
      ),
    );
  }
}
