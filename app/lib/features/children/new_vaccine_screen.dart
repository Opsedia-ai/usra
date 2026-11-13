import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/list_row.dart';
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
import 'growth.dart' show isUnderFive;

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
    // Overdue and due now, then the next visit in case it's being given early.
    final waiting = child == null
        ? const <DoseStatus>[]
        : [
            for (final s in child.statuses)
              // In the plan only: an optional vaccine the family doesn't
              // follow is still there under "another vaccine".
              if (child.next.overdue.contains(s) ||
                  (s.followed && s.state == DoseState.due) ||
                  child.next.doses.contains(s.dose))
                s,
          ];
    // Never starts on a dose that isn't due yet: someone logging a travel or
    // private vaccine could save it as that dose without noticing.
    final choice =
        _choice ??
        waiting
            .where(
              (s) =>
                  s.followed &&
                  (s.state == DoseState.overdue || s.state == DoseState.due),
            )
            .firstOrNull
            ?.dose
            .key ??
        _other;
    final chosen = waiting.where((s) => s.dose.key == choice).firstOrNull;
    final name = person?.displayName ?? '';
    final strings = recordFormStrings(l);
    return Scaffold(
      appBar: AppBar(title: Text(l.vaccineNewTitle)),
      body: RecordForm(
        type: type,
        strings: strings.copyWith(
          save: name.isEmpty ? null : l.medicineSaveFor(name),
          photos: l.vaccineCardPhoto,
        ),
        lastOccurredAt: nowOf(context),
        firstOccurredAt: person?.birthDate,
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
            // The checklist, not this form: a card holds many doses, and each
            // one needs its own check. Only a child has a schedule to read to.
            if (child != null) ...[
              const SizedBox(height: UsraSpacing.s3),
              _CardScanLink(
                onTap: () =>
                    context.push('/family/$_person/vaccines/setup?scan=1'),
              ),
            ],
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
        onSubmit: (result) => _save(result, name, child, chosen),
      ),
    );
  }

  Future<void> _save(
    RecordFormResult result,
    String name,
    ChildVaccines? child,
    DoseStatus? chosen,
  ) async {
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
    final young = isUnderFive(
      ref
          .read(profilesProvider)
          .value
          ?.where((p) => p.id == person)
          .firstOrNull
          ?.birthDate,
      today,
    );
    // A scheduled dose's note lives on the plan, where the schedule shows it.
    final note = chosen == null ? null : result.data['note'] as String?;
    final data = {...result.data};
    if (note != null) data.remove('note');
    try {
      // Copied in first; the form deletes the picked originals.
      final photos = <String>[
        for (final path in result.photos) await store!.import(path),
      ];
      await db.addEvent(
        profileId: person,
        type: 'vaccine',
        occurredAt: result.occurredAt,
        dataJson: jsonEncode(data),
        costMinor: result.costMinor,
        currency: result.costMinor == null ? null : 'EGP',
        photos: photos,
      );
      if (note != null && chosen != null && child != null) {
        await db.saveSingletonEvent(
          profileId: person,
          type: VaccinePlanFields.type,
          dataJson: child.plan.withNote(chosen.dose.key, note).toJson(),
        );
      }
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
    if (!mounted) return;
    router.go(young ? '/family/$person/vaccines' : '/family/$person');
  }
}

/// The way in to reading a whole vaccination card.
class _CardScanLink extends StatelessWidget {
  const _CardScanLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return UsraListCard(
      children: [
        UsraListRow(
          key: const ValueKey('new-vaccine-scan'),
          icon: Icons.photo_camera_outlined,
          title: l.vaccineCardScanTitle,
          subtitleText: l.vaccineCardScanBody,
          onTap: onTap,
        ),
      ],
    );
  }
}
