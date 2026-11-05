import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/util/bidi.dart';
import '../../core/database/app_database.dart';
import '../../core/design/severity_chip.dart';
import '../../core/design/tokens.dart';
import '../../core/preferences.dart';
import '../../core/providers.dart';
import '../../core/records/record_type.dart';
import '../../core/util/localized_numbers.dart';
import '../../l10n/app_localizations.dart';
import '../children/growth.dart' show isUnderFive;
import '../children/infant_log.dart' show isUnderOne;
import '../children/milestones.dart' show showsMilestones;
import '../follow_ups/follow_ups_section.dart';
import '../insurance/insurance_section.dart';
import '../pregnancy/pregnancy.dart' show canBePregnant;
import '../pregnancy/pregnancy_widgets.dart';
import 'family_screen.dart';
import 'record_display.dart';

final profileProvider = StreamProvider.family<Profile?, String>(
  (ref, id) => ref.watch(databaseProvider).watchProfile(id),
);

final timelineProvider = StreamProvider.family<List<MedicalEvent>, String>(
  (ref, id) => ref.watch(databaseProvider).watchTimeline(id),
);

/// How many photos each of a person's records has.
final attachmentCountsProvider =
    StreamProvider.family<Map<String, int>, String>(
      (ref, id) => ref.watch(databaseProvider).watchAttachmentCounts(id),
    );

final eventProvider = StreamProvider.family<MedicalEvent?, String>(
  (ref, id) => ref.watch(databaseProvider).watchEvent(id),
);

final attachmentsProvider = StreamProvider.family<List<Attachment>, String>(
  (ref, eventId) => ref.watch(databaseProvider).watchAttachments(eventId),
);

/// One person: their health details and every record, newest first.
class MemberScreen extends ConsumerWidget {
  const MemberScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider(profileId));
    final timeline = ref.watch(timelineProvider(profileId));
    final types = ref.watch(moduleRegistryProvider).recordTypes;
    final photoCounts =
        ref.watch(attachmentCountsProvider(profileId)).value ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: Text(profile.value?.displayName ?? ''),
        actions: [
          IconButton(
            key: const ValueKey('open-emergency'),
            tooltip: l.emergencyTitle,
            color: UsraColors.emergency,
            icon: const Icon(Icons.emergency_outlined),
            onPressed: () => context.go('/family/$profileId/emergency'),
          ),
          IconButton(
            tooltip: l.familyEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.go('/family/$profileId/edit'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add-record'),
        onPressed: () => _chooseType(context, types, profile.value),
        icon: const Icon(Icons.add),
        label: Text(l.addRecord),
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (p) {
          if (p == null) return Center(child: Text(l.profileNotFound));
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            children: [
              _Header(profile: p),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // No spending charts in Simple Mode.
                  if (!ref.watch(simpleModeProvider))
                    OutlinedButton.icon(
                      key: const ValueKey('member-spending'),
                      onPressed: () => context.go('/money?person=$profileId'),
                      icon: const Icon(Icons.payments_outlined),
                      label: Text(l.memberSpending),
                    ),
                  OutlinedButton.icon(
                    key: const ValueKey('member-medicines'),
                    onPressed: () => context.go('/family/$profileId/medicines'),
                    icon: const Icon(Icons.medication_outlined),
                    label: Text(l.memberMedicines),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('member-sick-days'),
                    onPressed: () => context.go('/family/$profileId/sick-days'),
                    icon: const Icon(Icons.thermostat),
                    label: Text(l.memberSickDays),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('member-labs'),
                    onPressed: () => context.go('/family/$profileId/labs'),
                    icon: const Icon(Icons.science_outlined),
                    label: Text(l.memberLabs),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('member-doctor-summary'),
                    onPressed: () =>
                        context.go('/family/$profileId/doctor-summary'),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(l.memberDoctorSummary),
                  ),
                  if (isUnderFive(p.birthDate, clock.now()))
                    OutlinedButton.icon(
                      key: const ValueKey('member-growth'),
                      onPressed: () => context.go('/family/$profileId/growth'),
                      icon: const Icon(Icons.child_care_outlined),
                      label: Text(l.memberGrowth),
                    ),
                  if (isUnderFive(p.birthDate, clock.now()))
                    OutlinedButton.icon(
                      key: const ValueKey('member-vaccines'),
                      onPressed: () =>
                          context.go('/family/$profileId/vaccines'),
                      icon: const Icon(Icons.vaccines_outlined),
                      label: Text(l.memberVaccines),
                    ),
                  if (showsMilestones(p.birthDate, clock.now()))
                    OutlinedButton.icon(
                      key: const ValueKey('member-development'),
                      onPressed: () =>
                          context.go('/family/$profileId/development'),
                      icon: const Icon(Icons.emoji_events_outlined),
                      label: Text(l.memberDevelopment),
                    ),
                  if (isUnderOne(p.birthDate, clock.now()))
                    OutlinedButton.icon(
                      key: const ValueKey('member-baby-log'),
                      onPressed: () =>
                          context.go('/family/$profileId/baby-log'),
                      icon: const Icon(Icons.local_drink_outlined),
                      label: Text(l.memberBabyLog),
                    ),
                  if (canBePregnant(p, clock.now()))
                    OutlinedButton.icon(
                      key: const ValueKey('member-pregnancy'),
                      onPressed: () =>
                          context.go('/family/$profileId/pregnancy'),
                      icon: const Icon(Icons.pregnant_woman),
                      label: Text(l.memberPregnancy),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              MemberPregnancy(profile: p),
              InsuranceSection(profileId: profileId),
              const SizedBox(height: 28),
              MemberFollowUps(profileId: profileId),
              const SizedBox(height: 28),
              // Quick logs (feeds, diapers...) live on their own screens.
              // Types this version doesn't know (written by a newer one,
              // e.g. a restored backup) are hidden rather than shown raw.
              ...timeline
                  .whenData(
                    (all) => [
                      for (final e in all)
                        if (types[e.type]?.inTimeline ?? false) e,
                    ],
                  )
                  .when(
                    loading: () => [
                      const Center(child: CircularProgressIndicator()),
                    ],
                    error: (e, _) => [Text('$e')],
                    data: (events) => events.isEmpty
                        ? [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Text(
                                l.timelineEmpty,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          ]
                        : [
                            for (final e in events) ...[
                              _EventCard(
                                event: e,
                                type: types[e.type],
                                photos: photoCounts[e.id] ?? 0,
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                  ),
            ],
          );
        },
      ),
    );
  }

  void _chooseType(
    BuildContext context,
    RecordTypeRegistry types,
    Profile? profile,
  ) {
    final today = clock.now();
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l.chooseRecordType,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final t in types.all)
              if (profile == null || t.offeredFor(profile, today))
                ListTile(
                  key: ValueKey('type-${t.key}'),
                  leading: Icon(t.icon, color: UsraColors.primary),
                  title: Text(t.labelOf(context)),
                  onTap: () {
                    Navigator.pop(sheet);
                    context.go('/family/$profileId/add/${t.key}');
                  },
                ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final age = ageInYears(profile.birthDate);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: UsraColors.primaryTint,
          foregroundColor: UsraColors.primary,
          child: Text(
            initialOf(profile.displayName),
            style: const TextStyle(fontSize: 22),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (age != null)
                SeverityChip(severity: Severity.info, label: l.ageYears(age)),
              if (profile.bloodType != null)
                SeverityChip(
                  severity: Severity.info,
                  label: '${l.profileBloodType}: ${ltr(profile.bloodType!)}',
                ),
              if (profile.allergies != null)
                SeverityChip(
                  severity: Severity.urgent,
                  label: '${l.profileAllergies}: ${profile.allergies}',
                ),
              if (profile.conditions != null)
                SeverityChip(
                  severity: Severity.info,
                  label: profile.conditions!,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.type,
    required this.photos,
  });

  final MedicalEvent event;
  final RecordTypeDefinition? type;
  final int photos;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final l = AppLocalizations.of(context);
    final data = decodeRecordData(event.dataJson);
    final titleField = type?.titleField;
    final title = titleField == null ? null : data[titleField.key];
    final currency = event.currency;
    final money = event.costMinor == null
        ? null
        : formatMoney(
            event.costMinor!,
            locale: locale,
            currency: currency == null || currency == 'EGP'
                ? l.currencyEgp
                : currency,
          );

    return Card(
      child: ListTile(
        key: ValueKey('event-${event.id}'),
        onTap: () =>
            context.go('/family/${event.profileId}/record/${event.id}'),
        leading: CircleAvatar(
          backgroundColor: UsraColors.primaryTint,
          child: Icon(
            type?.icon ?? Icons.description_outlined,
            color: UsraColors.primary,
          ),
        ),
        title: Text(
          [
            type?.labelOf(context) ?? event.type,
            if (title != null) displayFieldValue(context, titleField!, title),
          ].join(' · '),
        ),
        subtitle: Text(
          [
            DateFormat.yMMMd(locale).format(event.occurredAt),
            ?money,
          ].join(' · '),
        ),
        trailing: photos == 0
            ? null
            : Semantics(
                label: l.recordPhotoCount(photos),
                excludeSemantics: true,
                child: Badge(
                  key: ValueKey('event-photos-${event.id}'),
                  label: Text('$photos'),
                  backgroundColor: UsraColors.primary,
                  child: const Icon(
                    Icons.photo_outlined,
                    color: UsraColors.primary,
                  ),
                ),
              ),
      ),
    );
  }
}
