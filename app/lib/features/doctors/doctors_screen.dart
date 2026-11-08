import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'call_buttons.dart';
import 'contact_links.dart';
import 'doctors_providers.dart';

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
            onPressed: () => context.go('/doctors/new'),
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
                  Icon(
                    Icons.medical_services_outlined,
                    size: 48,
                    color: context.usra.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l.doctorsEmpty,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final d = list[i];
                  final call = callUri(d.phone);
                  return Card(
                    child: ListTile(
                      onTap: () => context.go('/doctors/${d.id}'),
                      leading: CircleAvatar(
                        backgroundColor: context.usra.primarySoft,
                        child: Icon(
                          Icons.medical_services_outlined,
                          color: context.usra.primary,
                        ),
                      ),
                      title: Text(d.name),
                      subtitle: Text([?d.specialty, ?d.clinic].join(' · ')),
                      trailing: call == null
                          ? const Icon(Icons.chevron_right)
                          : IconButton.filledTonal(
                              tooltip: l.doctorCall,
                              iconSize: 28,
                              icon: const Icon(Icons.call),
                              onPressed: () => openContact(context, call),
                            ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
