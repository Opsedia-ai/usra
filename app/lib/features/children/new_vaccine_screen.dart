import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/pill_chip.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/files/photo_store.dart';
import '../../core/providers.dart';
import '../../core/records/record_form.dart';
import '../../l10n/app_localizations.dart';
import '../account/save_gate.dart';
import '../family/family_screen.dart' show profilesProvider;
import '../family/member_screen.dart' show timelineProvider;
import '../family/record_form_screen.dart';
import '../follow_ups/follow_ups_providers.dart' show todayProvider;
import 'child_vaccines.dart';
import 'egypt_vaccines.dart';

/// Logs one vaccine: whose it is, which (a dose the schedule is waiting for, or
/// anything else), when and where. A dose from the list counts towards the
/// schedule exactly as the checklist's do, but it's the family's own record: it
/// can hold a photo and a cost, so unticking it later warns first.
class NewVaccineScreen extends ConsumerStatefulWidget {
  const NewVaccineScreen({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<NewVaccineScreen> createState() => _NewVaccineScreenState();
}

const _other = 'other';

class _NewVaccineScreenState extends ConsumerState<NewVaccineScreen> {
  late String _person = widget.profileId;

  /// A dose's key or [_other]; null until the family picks, which starts on
  /// the first dose waiting.
  String? _choice;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final type = ref.watch(moduleRegistryProvider).recordTypes['vaccine']!;
    final people = ref.watch(profilesProvider).value ?? const <Profile>[];
    final person = people.where((p) => p.id == _person).firstOrNull;
    final events = ref.watch(timelineProvider(_person)).value;
    final child = person == null || events == null
        ? null
        : childVaccines(person, events, ref.watch(todayProvider));
    final waiting = child == null
        ? const <DoseStatus>[]
        : [
            ...child.next.overdue,
            for (final s in child.statuses)
              if (child.next.doses.contains(s.dose)) s,
          ];
    final choice = _choice ?? waiting.firstOrNull?.dose.key ?? _other;
    final chosen = waiting.where((s) => s.dose.key == choice).firstOrNull;
    final name = person?.displayName ?? '';
    final strings = recordFormStrings(l);
    return Scaffold(
      appBar: AppBar(title: Text(l.vaccineNewTitle)),
      body: RecordForm(
        type: type,
        strings: RecordFormStrings(
          clearDate: strings.clearDate,
          date: strings.date,
          cost: strings.cost,
          currency: strings.currency,
          save: name.isEmpty ? strings.save : l.medicineSaveFor(name),
          required: strings.required,
          invalid: strings.invalid,
          pickDate: strings.pickDate,
          photos: l.vaccineCardPhoto,
          photoCamera: strings.photoCamera,
          photoGallery: strings.photoGallery,
          photoRemove: strings.photoRemove,
        ),
        photosFirst: true,
        hiddenFields: chosen == null
            ? const {}
            : const {'vaccine', 'dose', 'nextDue'},
        presetData: chosen == null
            ? const {}
            : {
                'vaccine': vaccineName(l, chosen.dose.kind),
                'dose': chosen.dose.dose,
              },
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.vaccineWhoFor,
              style: UsraType.body.copyWith(
                color: c.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: UsraSpacing.s1),
            Wrap(
              spacing: UsraSpacing.s2,
              runSpacing: UsraSpacing.s2,
              children: [
                for (final p in people)
                  UsraPill(
                    key: ValueKey('new-vaccine-person-${p.id}'),
                    label: p.displayName,
                    selected: p.id == _person,
                    onTap: () => setState(() {
                      _person = p.id;
                      // The other person's schedule has other doses.
                      _choice = null;
                    }),
                  ),
              ],
            ),
            if (waiting.isNotEmpty) ...[
              const SizedBox(height: UsraSpacing.s3),
              Text(
                l.vaccineWhich,
                style: UsraType.body.copyWith(
                  color: c.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: UsraSpacing.s1),
              Wrap(
                spacing: UsraSpacing.s2,
                runSpacing: UsraSpacing.s2,
                children: [
                  for (final s in waiting)
                    UsraPill(
                      key: ValueKey('new-vaccine-${s.dose.key}'),
                      label: s.state == DoseState.overdue
                          ? l.vaccineChoiceOverdue(doseName(l, s.dose))
                          : doseName(l, s.dose),
                      selected: s.dose.key == choice,
                      onTap: () => setState(() => _choice = s.dose.key),
                    ),
                  UsraPill(
                    key: const ValueKey('new-vaccine-other'),
                    label: l.vaccineOtherChoice,
                    selected: choice == _other,
                    onTap: () => setState(() => _choice = _other),
                  ),
                ],
              ),
            ],
          ],
        ),
        pickPhotos: (source) => pickRecordPhotos(context, ref, source),
        onSubmit: (result) => _save(result, name),
      ),
    );
  }

  Future<void> _save(RecordFormResult result, String name) async {
    if (!await ref.read(saveGateProvider).allow()) return;
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final db = ref.read(databaseProvider);
    final store = result.photos.isEmpty
        ? null
        : ref.read(attachmentStoreProvider);
    final person = _person;
    final today = ref.read(todayProvider);
    try {
      // Copied in first; the form deletes the picked originals.
      final photos = <String>[
        for (final path in result.photos) await store!.import(path),
      ];
      await db.addEvent(
        profileId: person,
        type: 'vaccine',
        occurredAt: result.occurredAt,
        dataJson: jsonEncode(result.data),
        costMinor: result.costMinor,
        currency: result.costMinor == null ? null : 'EGP',
        photos: photos,
      );
    } catch (_) {
      try {
        await store?.prune(await db.liveAttachmentPaths());
      } catch (_) {
        // Left for the next save or delete to clean up.
      }
      messenger.showSnackBar(SnackBar(content: Text(l.saveFailed)));
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        key: const ValueKey('new-vaccine-saved'),
        content: Text(
          l.vaccineSavedFor(result.data['vaccine'].toString(), name),
        ),
      ),
    );
    final p = ref
        .read(profilesProvider)
        .value
        ?.where((p) => p.id == person)
        .firstOrNull;
    final young = p != null && childVaccines(p, const [], today) != null;
    router.go(young ? '/family/$person/vaccines' : '/family/$person');
  }
}
