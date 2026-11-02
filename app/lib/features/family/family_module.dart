import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/tokens.dart';
import '../../core/modules/feature_module.dart';
import '../../core/providers.dart';
import '../../core/records/record_type.dart';
import '../../l10n/app_localizations.dart';

class FamilyModule extends FeatureModule {
  const FamilyModule();

  @override
  String get id => 'family';

  @override
  List<ModuleTab> get tabs => [
    ModuleTab(
      path: '/family',
      icon: Icons.groups_outlined,
      label: (c) => AppLocalizations.of(c).navFamily,
      order: 10,
    ),
  ];

  @override
  List<RouteBase> get routes => [
    GoRoute(path: '/family', builder: (_, _) => const FamilyScreen()),
  ];

  /// The core record types; later modules add their own (pregnancy, growth...).
  @override
  List<RecordTypeDefinition> get recordTypes => const [
    RecordTypeDefinition(
      key: 'visit',
      icon: Icons.medical_services_outlined,
      fields: [
        FieldSpec(key: 'doctorName', kind: FieldKind.text, required: true),
        FieldSpec(key: 'reason', kind: FieldKind.text),
        FieldSpec(key: 'fee', kind: FieldKind.money),
        FieldSpec(key: 'nextVisit', kind: FieldKind.date),
      ],
    ),
    RecordTypeDefinition(
      key: 'scan',
      icon: Icons.image_outlined,
      fields: [
        FieldSpec(
          key: 'kind',
          kind: FieldKind.choice,
          required: true,
          choices: ['xray', 'ct', 'mri', 'ultrasound', 'other'],
        ),
        FieldSpec(key: 'center', kind: FieldKind.text),
      ],
    ),
    RecordTypeDefinition(
      key: 'lab',
      icon: Icons.science_outlined,
      fields: [
        FieldSpec(key: 'test', kind: FieldKind.text, required: true),
        FieldSpec(key: 'value', kind: FieldKind.number),
        FieldSpec(key: 'unit', kind: FieldKind.text),
      ],
    ),
    RecordTypeDefinition(
      key: 'vaccine',
      icon: Icons.vaccines_outlined,
      fields: [
        FieldSpec(key: 'vaccine', kind: FieldKind.text, required: true),
        FieldSpec(key: 'dose', kind: FieldKind.number),
        FieldSpec(key: 'nextDue', kind: FieldKind.date),
      ],
    ),
    RecordTypeDefinition(
      key: 'surgery',
      icon: Icons.local_hospital_outlined,
      fields: [
        FieldSpec(key: 'procedure', kind: FieldKind.text, required: true),
        FieldSpec(key: 'hospital', kind: FieldKind.text),
        FieldSpec(key: 'filmed', kind: FieldKind.boolean),
        FieldSpec(key: 'daysInHospital', kind: FieldKind.number),
      ],
    ),
  ];
}

final profilesProvider = StreamProvider<List<Profile>>(
  (ref) => ref.watch(databaseProvider).watchProfiles(),
);

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profiles = ref.watch(profilesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.familyTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPerson(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(l.familyAdd),
      ),
      body: profiles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    l.familyEmpty,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: UsraColors.primaryTint,
                      foregroundColor: UsraColors.primary,
                      child: Text(initialOf(list[i].displayName)),
                    ),
                    title: Text(list[i].displayName),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _addPerson(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _AddPersonDialog(),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(databaseProvider).addProfile(name);
    }
  }
}

/// Owns its text controller so it is disposed only after the dialog closes.
class _AddPersonDialog extends StatefulWidget {
  const _AddPersonDialog();

  @override
  State<_AddPersonDialog> createState() => _AddPersonDialogState();
}

class _AddPersonDialogState extends State<_AddPersonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.familyAdd),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l.familyNameLabel),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.familyCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(l.familySave),
        ),
      ],
    );
  }
}

/// First letter for an avatar; "?" if the name is blank.
String initialOf(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : trimmed.characters.first;
}
