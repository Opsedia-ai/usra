import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/list_row.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../l10n/app_localizations.dart';
import 'call_buttons.dart';
import 'contact_links.dart';
import 'doctors_providers.dart';
import '../../core/util/separator.dart';

/// A doctor in the list, with a short "اتصل" when there's a number.
class _DoctorRow extends StatelessWidget {
  const _DoctorRow({required this.doctor, required this.call});

  final Doctor doctor;
  final Uri? call;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final d = doctor;
    final number = call;
    final details = [?d.specialty, ?d.clinic].join(partSeparator);
    return UsraListRow(
      key: ValueKey('doctor-${d.id}'),
      leading: const IconBox(icon: Icons.medical_services_outlined),
      title: d.name,
      emphasized: true,
      subtitleText: details.isEmpty ? null : details,
      onTap: () => context.push('/doctors/${d.id}'),
      trailing: number == null
          ? null
          : TextButton.icon(
              key: ValueKey('doctor-call-${d.id}'),
              onPressed: () => openContact(context, number),
              icon: const Icon(Icons.call, size: 20),
              label: Text(
                l.doctorCall,
                semanticsLabel: '${l.doctorCall} ${d.name}',
              ),
            ),
    );
  }
}

class DoctorsScreen extends ConsumerWidget {
  const DoctorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final doctors = ref.watch(doctorsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.doctorsTitle)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton.icon(
            key: const ValueKey('doctor-add'),
            onPressed: () => context.push('/doctors/new'),
            icon: const Icon(Icons.person_add_alt_1),
            label: Text(l.doctorsAdd),
          ),
        ),
      ),
      body: doctors.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? ListView(
                key: const ValueKey('doctors-empty'),
                padding: const EdgeInsets.all(32),
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.medical_services_outlined,
                      size: 48,
                      color: context.usra.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l.doctorsEmpty,
                    textAlign: TextAlign.center,
                    style: UsraType.body.copyWith(color: context.usra.inkMuted),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  UsraListCard(
                    children: [
                      for (final d in list)
                        _DoctorRow(doctor: d, call: callUri(d.phone)),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
