import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../l10n/app_localizations.dart';
import '../family/family_screen.dart';

/// Asks what to add and for whom. Opened from a person's page, it starts on
/// that person. From elsewhere with several people, nothing is chosen: the
/// family has to pick, so a record can't land on the wrong person by default.
/// [person] says who for, where the page knows better than its address.
Future<void> showAddSheet(BuildContext context, {String? person}) {
  final match = RegExp(r'^/family/([^/]+)')
      .firstMatch(GoRouterState.of(context).uri.path);
  final id = person ?? match?.group(1);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => AddSheet(initialPerson: id == 'new' ? null : id),
  );
}

class AddSheet extends ConsumerStatefulWidget {
  const AddSheet({super.key, this.initialPerson});

  final String? initialPerson;

  @override
  ConsumerState<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends ConsumerState<AddSheet> {
  late String? _person = widget.initialPerson;

  void _open(String path) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(path);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final people = ref.watch(profilesProvider).value ?? const <Profile>[];
    final person = people.length == 1
        ? people.single.id
        : people.any((p) => p.id == _person)
        ? _person
        : null;
    // Only what has a form. Vitals, an admission, an allergy or a condition
    // have no record form yet: allergies and conditions are on the person.
    final items = <(String, IconData, String)>[
      ('medicines/new', Icons.medication_outlined, l.addMedicine),
      ('add/vaccine', Icons.vaccines_outlined, l.addVaccine),
      ('add/visit', Icons.medical_services_outlined, l.addVisit),
      ('labs', Icons.science_outlined, l.addLab),
      ('add/scan', Icons.document_scanner_outlined, l.addScan),
      ('sick-days', Icons.thermostat, l.addFever),
      ('add/growth', Icons.monitor_weight_outlined, l.addGrowth),
      ('add/surgery', Icons.healing_outlined, l.addSurgery),
      ('insurance/new', Icons.badge_outlined, l.addInsurance),
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.addSheetTitle, style: text.headlineMedium),
            const SizedBox(height: UsraSpacing.s3),
            if (people.isEmpty) ...[
              Text(l.addSheetNoPeople, style: text.bodyLarge),
              const SizedBox(height: UsraSpacing.s3),
              FilledButton.icon(
                key: const ValueKey('add-first-person'),
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  router.go('/family/new');
                },
                icon: const Icon(Icons.add),
                label: Text(l.familyAdd),
              ),
            ] else ...[
              Text(l.addSheetFor, style: text.labelLarge),
              const SizedBox(height: UsraSpacing.s1),
              Wrap(
                spacing: UsraSpacing.s2,
                children: [
                  for (final p in people)
                    ChoiceChip(
                      key: ValueKey('add-person-${p.id}'),
                      label: Text(p.displayName),
                      selected: p.id == person,
                      onSelected: (_) => setState(() => _person = p.id),
                    ),
                ],
              ),
              if (person == null)
                Padding(
                  padding: const EdgeInsets.only(top: UsraSpacing.s1),
                  child: Text(
                    l.addSheetPickPerson,
                    key: const ValueKey('add-pick-person'),
                    style: UsraType.label.copyWith(
                      color: Severity.headsUp.foregroundOf(context),
                    ),
                  ),
                ),
              const SizedBox(height: UsraSpacing.s3),
              _PhotoCard(
                onTap: person == null
                    ? null
                    : () => _open('/family/$person/medicines/new?scan=1'),
              ),
              const SizedBox(height: UsraSpacing.s3),
              LayoutBuilder(
                builder: (context, box) {
                  final scale = MediaQuery.textScalerOf(context).scale(1);
                  // Big text gets fewer, wider tiles, never cut-off labels.
                  final columns = (box.maxWidth / (76 * scale)).floor().clamp(
                    2,
                    4,
                  );
                  final width =
                      (box.maxWidth - (columns - 1) * UsraSpacing.s2) / columns;
                  return Wrap(
                    spacing: UsraSpacing.s2,
                    runSpacing: UsraSpacing.s2,
                    children: [
                      for (final (path, icon, label) in items)
                        SizedBox(
                          width: width,
                          child: _AddTile(
                            key: ValueKey('add-$path'),
                            icon: icon,
                            label: label,
                            onTap: person == null
                                ? null
                                : () => _open('/family/$person/$path'),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The quickest way in, first: photograph a box. Says what the reading can do.
class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final enabled = onTap != null;
    return Material(
      color: c.primarySoft,
      borderRadius: BorderRadius.circular(UsraRadius.md),
      child: InkWell(
        key: const ValueKey('add-photo'),
        borderRadius: BorderRadius.circular(UsraRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(UsraSpacing.s3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.photo_camera_outlined,
                color: enabled ? c.primary : c.inkMuted,
              ),
              const SizedBox(width: UsraSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.addPhotoTitle,
                      style: UsraType.body.copyWith(
                        color: enabled ? c.ink : c.inkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: UsraSpacing.s1),
                    Text(
                      l.addPhotoHint,
                      style: UsraType.label.copyWith(color: c.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.usra;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: c.surfaceSoft,
        borderRadius: BorderRadius.circular(UsraRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(UsraRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: UsraSpacing.s1,
              vertical: UsraSpacing.s2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ExcludeSemantics(
                  child: Icon(icon, color: enabled ? c.primary : c.inkMuted),
                ),
                const SizedBox(height: UsraSpacing.s1),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: UsraType.label.copyWith(
                    color: enabled ? c.ink : c.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
