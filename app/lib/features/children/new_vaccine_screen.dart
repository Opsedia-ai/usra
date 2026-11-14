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
import '../../core/util/localized_digits.dart';
import '../../l10n/app_localizations.dart';
import '../account/save_gate.dart';
import '../family/family_screen.dart' show profilesProvider;
import '../family/member_screen.dart' show timelineProvider;
import '../family/record_form_screen.dart';
import '../follow_ups/follow_ups_providers.dart' show todayProvider;
import 'child_vaccines.dart';
import 'egypt_vaccines.dart';
import 'growth.dart' show isUnderFive;

/// Logs vaccines given at one visit: whose, which (the doses the schedule is
/// waiting for, ticked, or one picked from a list), and when. Place, photo,
/// note and cost wait under "more details" so the form stays short
/// (founder, 14 Nov 2026). A dose from the list counts towards the schedule
/// exactly as the checklist's do, but it's the family's own record: it can
/// hold a photo and a cost, so unticking it later warns first.
class NewVaccineScreen extends ConsumerStatefulWidget {
  const NewVaccineScreen({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<NewVaccineScreen> createState() => _NewVaccineScreenState();
}

const _other = 'other';

/// Vaccines offered by name for "another vaccine" and for anyone without a
/// schedule, so the name is picked rather than typed.
List<String> commonVaccineNames(AppLocalizations l) => [
  for (final k in VaccineKind.values)
    // One name each: hexavalent and pentavalent stay, as cards print them.
    vaccineName(l, k),
  l.vaccineTetanus,
  l.vaccineHpv,
  l.vaccineTyphoid,
  l.vaccineCovid,
];

class _NewVaccineScreenState extends ConsumerState<NewVaccineScreen> {
  late String _person = widget.profileId;

  /// Ticked doses' keys, or just [_other]; null until the family picks, which
  /// starts on the doses due now.
  Set<String>? _picked;

  /// For another vaccine: the name picked from the list (null: typed) and
  /// the dose number tapped.
  String? _otherName;
  int? _otherDose;

  void _reset() {
    _picked = null;
    _otherName = null;
    _otherDose = null;
  }

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
    final picked = _picked ?? _startingPick(waiting);
    final doses = [
      for (final s in waiting)
        if (picked.contains(s.dose.key)) s,
    ];
    final other = doses.isEmpty;
    final name = person?.displayName ?? '';
    final strings = recordFormStrings(l);
    final heading = UsraType.body.copyWith(
      color: c.ink,
      fontWeight: FontWeight.w600,
    );
    final save = name.isEmpty
        ? null
        : doses.length > 1
        ? l.vaccineSaveCount(
            doses.length,
            localizedDigits(context, doses.length),
          )
        : l.medicineSaveFor(name);
    return Scaffold(
      appBar: AppBar(title: Text(l.vaccineNewTitle)),
      body: RecordForm(
        type: type,
        strings: strings.copyWith(
          save: save,
          photos: l.vaccineCardPhoto,
          moreDetails: l.vaccineMoreDetails,
        ),
        lastOccurredAt: nowOf(context),
        firstOccurredAt: person?.birthDate,
        foldedFields: const {'nextDue', 'place', 'note'},
        foldExtras: true,
        hiddenFields: !other
            ? const {'vaccine', 'dose', 'nextDue'}
            : _otherName != null
            ? const {'vaccine', 'dose'}
            : const {'dose'},
        presetData: !other
            ? {
                'vaccine': vaccineName(l, doses.first.dose.kind),
                'dose': doses.first.dose.dose,
              }
            : {'vaccine': ?_otherName, 'dose': ?_otherDose},
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (people.length > 1) ...[
              Text(l.vaccineWhoFor, style: heading),
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
                        _reset();
                      }),
                    ),
                ],
              ),
              const SizedBox(height: UsraSpacing.s3),
            ],
            Text(l.vaccineWhich, style: heading),
            const SizedBox(height: UsraSpacing.s1),
            if (waiting.isNotEmpty)
              UsraListCard(
                children: [
                  for (final s in waiting)
                    CheckboxListTile(
                      key: ValueKey('new-vaccine-${s.dose.key}'),
                      value: picked.contains(s.dose.key),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        s.state == DoseState.overdue
                            ? l.vaccineChoiceOverdue(doseName(l, s.dose))
                            : doseName(l, s.dose),
                      ),
                      onChanged: (on) => setState(() {
                        final next = {...picked}..remove(_other);
                        on == true
                            ? next.add(s.dose.key)
                            : next.remove(s.dose.key);
                        _picked = next.isEmpty ? {_other} : next;
                      }),
                    ),
                  CheckboxListTile(
                    key: const ValueKey('new-vaccine-other'),
                    value: other,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l.vaccineOtherChoice),
                    onChanged: (_) => setState(() => _picked = {_other}),
                  ),
                ],
              ),
            if (other) ...[
              if (waiting.isNotEmpty) const SizedBox(height: UsraSpacing.s3),
              Wrap(
                spacing: UsraSpacing.s2,
                runSpacing: UsraSpacing.s2,
                children: [
                  for (final (i, n) in commonVaccineNames(l).indexed)
                    UsraPill(
                      key: ValueKey('new-vaccine-name-$i'),
                      label: n,
                      selected: _otherName == n,
                      onTap: () => setState(() => _otherName = n),
                    ),
                  UsraPill(
                    key: const ValueKey('new-vaccine-name-typed'),
                    label: l.vaccineSomethingElse,
                    selected: _otherName == null,
                    onTap: () => setState(() => _otherName = null),
                  ),
                ],
              ),
              const SizedBox(height: UsraSpacing.s3),
              Text(l.fieldDose, style: heading),
              const SizedBox(height: UsraSpacing.s1),
              Wrap(
                spacing: UsraSpacing.s2,
                runSpacing: UsraSpacing.s2,
                children: [
                  for (final n in [1, 2, 3, 4])
                    UsraPill(
                      key: ValueKey('new-vaccine-dose-$n'),
                      label: localizedDigits(context, n),
                      selected: _otherDose == n,
                      // Tapping it again clears it: the number is optional.
                      onTap: () => setState(
                        () => _otherDose = _otherDose == n ? null : n,
                      ),
                    ),
                ],
              ),
            ],
            // The checklist, not this form: a card holds many doses, and each
            // one needs its own check. Only a child has a schedule to read to.
            if (child != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const ValueKey('new-vaccine-scan'),
                  onPressed: () =>
                      context.push('/family/$_person/vaccines/setup?scan=1'),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(l.vaccineCardScanTitle),
                ),
              ),
          ],
        ),
        pickPhotos: (source) => pickRecordPhotos(context, ref, source),
        onSubmit: (result) => _save(result, name, child, doses),
      ),
    );
  }

  /// Starts on the doses due now that the family follows; with none, on the
  /// first overdue one. Never on a dose that isn't due yet: someone logging a
  /// travel or private vaccine could save it as that dose without noticing.
  Set<String> _startingPick(List<DoseStatus> waiting) {
    final followed = waiting.where((s) => s.followed);
    final due = {
      for (final s in followed)
        if (s.state == DoseState.due) s.dose.key,
    };
    if (due.isNotEmpty) return due;
    final late = followed
        .where((s) => s.state == DoseState.overdue)
        .firstOrNull;
    return late == null ? {_other} : {late.dose.key};
  }

  Future<void> _save(
    RecordFormResult result,
    String name,
    ChildVaccines? child,
    List<DoseStatus> doses,
  ) async {
    if (!await ref.read(saveGateProvider).allow()) return;
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final countText = localizedDigits(context, doses.length);
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
    final note = doses.isEmpty ? null : result.data['note'] as String?;
    final base = {...result.data};
    if (note != null) base.remove('note');
    // One record for each dose ticked; with none, the one typed or picked.
    final records = doses.isEmpty
        ? [base]
        : [
            for (final s in doses)
              {
                ...base,
                'vaccine': vaccineName(l, s.dose.kind),
                'dose': s.dose.dose,
              },
          ];
    try {
      for (final (i, data) in records.indexed) {
        // Copied in first; the form deletes the picked originals. Each record
        // keeps its own copy, so deleting one never takes another's photo.
        final photos = <String>[
          for (final path in result.photos) await store!.import(path),
        ];
        await db.addEvent(
          profileId: person,
          type: 'vaccine',
          occurredAt: result.occurredAt,
          dataJson: jsonEncode(data),
          // The visit's cost once, not once per shot.
          costMinor: i == 0 ? result.costMinor : null,
          currency: i == 0 && result.costMinor != null ? 'EGP' : null,
          photos: photos,
        );
      }
      if (note != null && child != null) {
        var plan = child.plan;
        for (final s in doses) {
          plan = plan.withNote(s.dose.key, note);
        }
        await db.saveSingletonEvent(
          profileId: person,
          type: VaccinePlanFields.type,
          dataJson: plan.toJson(),
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
          records.length > 1
              ? l.vaccineSavedManyFor(records.length, countText, name)
              : l.vaccineSavedFor(records.single['vaccine'].toString(), name),
        ),
      ),
    );
    if (!mounted) return;
    router.go(young ? '/family/$person/vaccines' : '/family/$person');
  }
}
