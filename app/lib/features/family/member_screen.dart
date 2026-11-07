import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/buttons.dart';
import '../../core/design/pebble.dart';
import '../../core/design/status_chip.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/preferences.dart';
import '../../core/providers.dart';
import '../../core/records/record_type.dart';
import '../../core/util/localized_digits.dart';
import '../../core/util/localized_numbers.dart';
import '../../l10n/app_localizations.dart';
import '../add/add_sheet.dart';
import '../children/child_vaccines.dart';
import '../children/egypt_vaccines.dart';
import '../children/growth.dart' show GrowthFields, isUnderFive;
import '../children/infant_log.dart' show isUnderOne;
import '../children/milestones.dart' show showsMilestones;
import '../children/vaccines_screen.dart'
    show showDoseSheet, watchChildVaccines;
import '../follow_ups/follow_ups_providers.dart' show personFollowUpsProvider;
import '../insurance/insurance_info.dart' show ExpiryChip, expirySeverity;
import '../insurance/insurance_providers.dart' show insuranceCardsProvider;
import '../medicines/dose_schedule.dart' show PlannedDose;
import '../medicines/medicine_text.dart';
import '../medicines/medicines_providers.dart';
import '../pregnancy/pregnancy.dart' show canBePregnant;
import '../pregnancy/pregnancy_widgets.dart';
import '../sick_days/sick_days_providers.dart' show episodesProvider;
import 'family_screen.dart';
import 'person_sections_screen.dart' show hasPhotos, isVisitOrLab;
import 'person_status.dart';
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

/// Stacks two side-by-side things when large text would squeeze them.
bool _textIsLarge(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(100) >= 130;

/// The theme's button height (taller in Simple Mode), without its full width,
/// for a button that sits beside other things.
Size _buttonSize(BuildContext context) => Size(
  0,
  Theme.of(context).filledButtonTheme.style?.minimumSize
          ?.resolve(const {})
          ?.height ??
      UsraSizes.touchTarget,
);

/// One person's hub: what needs attention, the next dose, what the family
/// recorded, a way into everything about them, and every record.
class MemberScreen extends ConsumerStatefulWidget {
  const MemberScreen({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<MemberScreen> createState() => _MemberScreenState();
}

class _MemberScreenState extends ConsumerState<MemberScreen>
    with TodayRefresh<MemberScreen> {
  String get profileId => widget.profileId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider(profileId));
    final person = profile.value;
    // With large text or a short screen, pinned buttons would leave no room
    // for the page, so they scroll with it.
    final inline =
        MediaQuery.textScalerOf(context).scale(100) >= 150 ||
        MediaQuery.sizeOf(context).height < 600;

    final topBar = Padding(
      padding: EdgeInsets.fromLTRB(
        inline ? 0 : 20,
        inline ? 0 : 8,
        inline ? 0 : 20,
        UsraSpacing.s3,
      ),
      child: _TopBar(profileId: profileId, found: person != null),
    );

    return Scaffold(
      bottomNavigationBar: person == null || inline
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: _PersonActions(person: person),
              ),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Back and Edit stay in reach on a long page, unless large text
          // leaves no room for them.
          if (!inline) topBar,
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, inline ? 8 : 0, 20, 24),
              children: [
                if (inline) topBar,
                ...profile.when(
                  loading: () => [
                    const Center(child: CircularProgressIndicator()),
                  ],
                  error: (e, _) => [Center(child: Text('$e'))],
                  data: (p) => p == null
                      ? [Center(child: Text(l.profileNotFound))]
                      : [
                          _Identity(person: p),
                          const SizedBox(height: UsraSpacing.s3),
                          if (inline) ...[
                            _PersonActions(person: p),
                            const SizedBox(height: UsraSpacing.s3),
                          ],
                          _Attention(person: p),
                          _NextDose(person: p),
                          _RecordedFacts(person: p),
                          MemberPregnancy(profile: p),
                          _Tiles(person: p),
                          const SizedBox(height: UsraSpacing.s5),
                          _Timeline(person: p),
                        ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.profileId, required this.found});

  final String profileId;
  final bool found;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final router = GoRouter.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UsraRoundIconButton(
          key: const ValueKey('member-back'),
          icon: Icons.arrow_back,
          semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => router.canPop() ? router.pop() : router.go('/home'),
        ),
        if (found)
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: UsraSpacing.s2,
              runSpacing: UsraSpacing.s2,
              children: [
                _TopPill(
                  key: const ValueKey('open-emergency'),
                  icon: Icons.local_hospital_outlined,
                  label: l.homeEmergency,
                  color: c.urgent,
                  onPressed: () => context.push('/family/$profileId/emergency'),
                ),
                _TopPill(
                  key: const ValueKey('member-edit'),
                  label: l.familyEdit,
                  color: c.primary,
                  onPressed: () => context.push('/family/$profileId/edit'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TopPill extends StatelessWidget {
  const _TopPill({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      backgroundColor: context.usra.surface,
      foregroundColor: color,
      side: BorderSide(color: context.usra.line),
      textStyle: UsraType.body.copyWith(fontWeight: FontWeight.w600),
    );
    final text = Text(label);
    final image = icon;
    return image == null
        ? OutlinedButton(style: style, onPressed: onPressed, child: text)
        : OutlinedButton.icon(
            style: style,
            onPressed: onPressed,
            icon: Icon(image, size: 20),
            label: text,
          );
  }
}

/// The avatar pebble, the name once, and the age and relationship when they're
/// known.
class _Identity extends ConsumerWidget {
  const _Identity({required this.person});

  final Profile person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final isMe = person.id == ref.watch(meProfileIdProvider);
    final relationship = isMe ? null : person.relationship;
    final details = [
      ?ageLabel(l, person.birthDate, ref.watch(clockProvider)()),
      if (relationship != null) l.relationshipYours(relationship),
    ].where((part) => part.isNotEmpty).join(' · ');
    return Row(
      children: [
        Pebble(
          seed: pebbleSeed(person.id),
          color: personColor(context, person.sex),
          width: 72,
          height: 68,
          shadow: false,
          child: ExcludeSemantics(
            child: Text(
              initialOf(person.displayName),
              style: UsraType.title.copyWith(color: context.usra.ink),
              textScaler: TextScaler.noScaling,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  person.displayName,
                  key: const ValueKey('member-name'),
                  style: text.headlineMedium,
                ),
              ),
              if (details.isNotEmpty)
                Text(
                  details,
                  key: const ValueKey('member-details'),
                  style: UsraType.body.copyWith(color: context.usra.inkMuted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What needs attention. Silent when nothing does: the page never says all is
/// well, because the app can't know that.
class _Attention extends ConsumerWidget {
  const _Attention({required this.person});

  final Profile person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final episodes = ref.watch(episodesProvider(person.id)).value;
    final overdue = watchChildVaccines(ref, person);
    final today = ref.watch(clockProvider)();
    final cards = ref.watch(insuranceCardsProvider(person.id)).value;
    final expiring = [
      for (final c in cards ?? const <InsuranceCard>[])
        if (expirySeverity(c.expiresOn, today)
            case Severity.urgent || Severity.headsUp)
          c,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (episodes?.any((e) => e.endedAt == null) ?? false)
          Padding(
            padding: const EdgeInsets.only(bottom: UsraSpacing.s3),
            child: _AttentionCard(
              key: const ValueKey('person-sick'),
              chip: StatusChip(
                severity: Severity.headsUp,
                icon: Icons.thermostat,
                label: person.sex == 'female'
                    ? l.statusSickFemale
                    : l.statusSick,
              ),
              children: [
                OutlinedButton(
                  key: const ValueKey('person-sick-open'),
                  onPressed: () =>
                      context.push('/family/${person.id}/sick-days'),
                  child: Text(l.memberSickDays),
                ),
              ],
            ),
          ),
        if (overdue != null && overdue.next.overdue.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: UsraSpacing.s3),
            child: _OverdueVaccine(child: overdue),
          ),
        for (final c in expiring)
          Padding(
            padding: const EdgeInsets.only(bottom: UsraSpacing.s3),
            child: _AttentionCard(
              key: ValueKey('person-insurance-${c.id}'),
              chip: ExpiryChip(expiresOn: c.expiresOn),
              children: [
                Text(
                  c.label,
                  style: UsraType.body.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: context.usra.ink,
                  ),
                ),
                OutlinedButton(
                  onPressed: () =>
                      context.push('/family/${person.id}/insurance/${c.id}'),
                  child: Text(l.personInsuranceOpen),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({super.key, required this.chip, required this.children});

  final Widget chip;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(UsraSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [chip, ...children],
      ),
    ),
  );
}

/// The earliest overdue dose. The dose and its date come from the schedule, so
/// the reference is named under them; logging it is what the family records.
class _OverdueVaccine extends ConsumerWidget {
  const _OverdueVaccine({required this.child});

  final ChildVaccines child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final overdue = child.next.overdue;
    final first = overdue.first;
    final today = ref.watch(clockProvider)();
    final checked = DateFormat.yMMMd(locale)
        .format(DateTime.parse(egyptScheduleCheckedOn));
    final due = first.dueOn.year == today.year
        ? DateFormat.MMMMd(locale).format(first.dueOn)
        : DateFormat.yMMMMd(locale).format(first.dueOn);
    return _AttentionCard(
      key: const ValueKey('person-vaccine-overdue'),
      chip: StatusChip(
        severity: Severity.actSoon,
        icon: Icons.warning_amber_rounded,
        label: overdue.length == 1
            ? l.statusVaccineOverdue
            : digitsIn(
                Localizations.localeOf(context).languageCode,
                l.vaccineOverdueCount(overdue.length),
              ),
      ),
      children: [
        Text(
          doseName(l, first.dose),
          style: UsraType.body.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: context.usra.ink,
          ),
        ),
        Text(
          l.personVaccineWasDue(due),
          style: UsraType.body.copyWith(color: context.usra.inkMuted),
        ),
        Text(
          first.dose.required
              ? l.personVaccineSource(
                  child.plan.route == VaccineRoute.government
                      ? l.vaccineRouteGovernment
                      : l.vaccineRouteHexavalent,
                  checked,
                )
              : l.personVaccineSourceOptional(checked),
          key: const ValueKey('person-vaccine-source'),
          style: UsraType.label.copyWith(color: context.usra.inkMuted),
        ),
        Wrap(
          spacing: UsraSpacing.s2,
          runSpacing: UsraSpacing.s2,
          children: [
            FilledButton(
              key: const ValueKey('person-vaccine-log'),
              style: FilledButton.styleFrom(minimumSize: _buttonSize(context)),
              onPressed: () =>
                  showDoseSheet(context, ref, child, first, given: true),
              child: Text(l.personVaccineLog),
            ),
            if (overdue.length > 1)
              OutlinedButton(
                key: const ValueKey('person-vaccine-all'),
                onPressed: () =>
                    context.push('/family/${child.profile.id}/vaccines'),
                child: Text(l.vaccineOpenAll),
              ),
          ],
        ),
      ],
    );
  }
}

/// The next dose still open today, or the one that was missed, with one-tap
/// Taken and Undo. The amount and the words are what the family typed.
class _NextDose extends ConsumerWidget {
  const _NextDose({required this.person});

  final Profile person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final doses = ref.watch(todayDosesProvider).value ?? const <PlannedDose>[];
    final dose = doses
        .where((d) => d.regimen.person.id == person.id && !d.isDone)
        .firstOrNull;
    if (dose == null) return const SizedBox.shrink();
    final r = dose.regimen;
    final time = formatDoseTime(context, dose.at);
    final missed = isDoseMissed(dose, ref.watch(clockProvider)());
    final details = [?r.schedule.amount, ?r.medicine.instructions].join(' · ');
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (missed)
          Padding(
            padding: const EdgeInsets.only(bottom: UsraSpacing.s1),
            child: StatusChip(
              severity: Severity.actSoon,
              icon: Icons.warning_amber_rounded,
              label: l.statusDoseMissed,
            ),
          ),
        Text(
          missed ? l.personDoseWasAt(time) : l.personNextDose(time),
          style: UsraType.body.copyWith(color: c.inkMuted),
        ),
        Text(
          medicineTitle(r.medicine),
          style: UsraType.body.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: c.ink,
          ),
        ),
        if (details.isNotEmpty)
          Text(details, style: UsraType.body.copyWith(color: c.inkMuted)),
      ],
    );
    final taken = FilledButton.icon(
      key: const ValueKey('person-dose-taken'),
      style: FilledButton.styleFrom(minimumSize: _buttonSize(context)),
      onPressed: () => logDoseTaken(context, ref, dose),
      icon: const Icon(Icons.check),
      label: Text(l.doseTaken),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: UsraSpacing.s3),
      child: Card(
        key: const ValueKey('person-next-dose'),
        child: InkWell(
          onTap: () =>
              context.push('/family/${person.id}/medicines/${r.medicine.id}'),
          child: Padding(
            padding: const EdgeInsets.all(UsraSpacing.s4),
            child: _textIsLarge(context)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: UsraSpacing.s2,
                    children: [words, taken],
                  )
                : Row(
                    spacing: UsraSpacing.s3,
                    children: [
                      Expanded(child: words),
                      taken,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Allergies, blood type and conditions, always in view when recorded, and
/// labelled as the family's own words rather than anything the app worked out.
class _RecordedFacts extends StatelessWidget {
  const _RecordedFacts({required this.person});

  final Profile person;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final blood = person.bloodType;
    final facts = <(String, String, Color)>[
      if (person.allergies case final v?) (l.profileAllergies, v, c.urgent),
      // Isolated, or bidi would draw "O+" as "+O" in an Arabic sentence.
      if (blood != null) (l.profileBloodType, '\u2066$blood\u2069', c.ink),
      if (person.conditions case final v?) (l.profileConditions, v, c.ink),
    ];
    if (facts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: UsraSpacing.s3),
      child: Card(
        key: const ValueKey('person-recorded'),
        child: Padding(
          padding: const EdgeInsets.all(UsraSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: UsraSpacing.s1,
            children: [
              Text(
                l.personRecordedTitle,
                style: UsraType.label.copyWith(color: c.inkMuted),
              ),
              for (final (label, value, color) in facts)
                Text(
                  '$label: $value',
                  style: UsraType.body.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A way into everything about the person.
class _Tiles extends ConsumerWidget {
  const _Tiles({required this.person});

  final Profile person;

  /// The latest measurement as the family recorded it, without judging it.
  String? _growthLine(
    BuildContext context,
    List<MedicalEvent> events,
    String Function(DateTime) date,
  ) {
    final l = AppLocalizations.of(context);
    final code = Localizations.localeOf(context).languageCode;
    String? shown(Object? v) {
      final n = v == null ? null : parseLocalizedNumber('$v');
      if (n == null) return null;
      final whole = n == n.roundToDouble();
      return digitsIn(code, whole ? '${n.round()}' : '$n');
    }

    for (final e in events) {
      if (e.type != 'growth') continue;
      final data = decodeRecordData(e.dataJson);
      if (shown(data[GrowthFields.weightKg]) case final v?) {
        return l.personGrowthWeight(v, date(e.occurredAt));
      }
      if (shown(data[GrowthFields.heightCm]) case final v?) {
        return l.personGrowthHeight(v, date(e.occurredAt));
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final id = person.id;
    final now = ref.watch(clockProvider)();
    final locale = Localizations.localeOf(context).toLanguageTag();
    // With the year when it isn't this one, so an old value doesn't read as
    // current.
    String date(DateTime d) => d.year == now.year
        ? DateFormat.MMMd(locale).format(d)
        : DateFormat.yMMMd(locale).format(d);
    String count(int n) => localizedDigits(context, n);
    final events = ref.watch(timelineProvider(id)).value;
    final photos = ref.watch(attachmentCountsProvider(id)).value;
    final cards = ref.watch(insuranceCardsProvider(id)).value;
    final followUps = ref.watch(personFollowUpsProvider(id)).value;
    final medicines = ref.watch(medicinesProvider(id)).value;
    final sick =
        ref.watch(episodesProvider(id)).value?.any((e) => e.endedAt == null) ??
        false;
    final vaccines = watchChildVaccines(ref, person);
    final progress = vaccines?.progress;

    final current = medicines
        ?.where((m) => m.active && !medicineEnded(m, now))
        .length;
    final latestVisit = events?.where(isVisitOrLab).firstOrNull;
    final types = ref.watch(moduleRegistryProvider).recordTypes;
    final documents = events == null || photos == null
        ? null
        : events
              .where(
                (e) =>
                    (types[e.type]?.inTimeline ?? false) &&
                    hasPhotos(e, photos[e.id] ?? 0),
              )
              .length;

    void open(String path) => context.push('/family/$id$path');

    final tiles = <_TileData>[
      if (isUnderFive(person.birthDate, now))
        _TileData(
          'member-vaccines',
          l.memberVaccines,
          progress == null
              ? null
              : l.personVaccinesSummary(
                  count(progress.requiredDone + progress.optionalDone),
                  count(progress.requiredTotal + progress.optionalTotal),
                ),
          () => open('/vaccines'),
        ),
      if (isUnderFive(person.birthDate, now))
        _TileData(
          'member-growth',
          l.personTileGrowth,
          events == null ? null : _growthLine(context, events, date),
          () => open('/growth'),
        ),
      _TileData(
        'member-visits',
        l.personTileVisits,
        latestVisit == null
            ? null
            : l.personLatestOn(date(latestVisit.occurredAt)),
        () => open('/visits'),
      ),
      _TileData(
        'member-insurance',
        l.personTileInsurance,
        cards == null
            ? null
            : l.personInsuranceCount(cards.length, count(cards.length)),
        () => open('/insurance'),
      ),
      _TileData(
        'member-medicines',
        l.memberMedicines,
        current == null
            ? null
            : l.personMedicinesCount(current, count(current)),
        () => open('/medicines'),
      ),
      _TileData(
        'member-sick-days',
        l.memberSickDays,
        !sick
            ? null
            : person.sex == 'female'
            ? l.statusSickFemale
            : l.statusSick,
        () => open('/sick-days'),
      ),
      if (canBePregnant(person, now))
        _TileData(
          'member-pregnancy',
          l.memberPregnancy,
          null,
          () => open('/pregnancy'),
        ),
      if (showsMilestones(person.birthDate, now))
        _TileData(
          'member-development',
          l.memberDevelopment,
          null,
          () => open('/development'),
        ),
      if (isUnderOne(person.birthDate, now))
        _TileData(
          'member-baby-log',
          l.memberBabyLog,
          null,
          () => open('/baby-log'),
        ),
      _TileData(
        'member-follow-ups-open',
        l.followUpsTitle,
        followUps == null
            ? null
            : l.personFollowUpsCount(followUps.length, count(followUps.length)),
        () => open('/follow-ups'),
      ),
      _TileData(
        'member-documents',
        l.personTileDocuments,
        documents == null
            ? null
            : l.personDocumentsCount(documents, count(documents)),
        () => open('/documents'),
      ),
      // No spending charts in Simple Mode.
      if (!ref.watch(simpleModeProvider))
        _TileData(
          'member-spending',
          l.memberSpending,
          null,
          () => context.push('/money?person=$id'),
        ),
    ];

    // One column when large text or Simple Mode would crowd two.
    if (_textIsLarge(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [for (final t in tiles) _Tile(data: t)],
      );
    }
    return Column(
      spacing: 10,
      children: [
        for (var i = 0; i < tiles.length; i += 2)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                Expanded(child: _Tile(data: tiles[i])),
                Expanded(
                  child: i + 1 < tiles.length
                      ? _Tile(data: tiles[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TileData {
  const _TileData(this.key, this.title, this.subtitle, this.onTap);

  final String key;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
}

class _Tile extends StatelessWidget {
  const _Tile({required this.data});

  final _TileData data;

  @override
  Widget build(BuildContext context) {
    final c = context.usra;
    final subtitle = data.subtitle;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UsraRadius.lg),
        side: Theme.of(context).brightness == Brightness.dark
            ? BorderSide(color: c.line)
            : BorderSide.none,
      ),
      child: InkWell(
        key: ValueKey(data.key),
        onTap: data.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: UsraType.body.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: UsraType.label.copyWith(color: c.inkMuted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Every record, newest first, and the full list of record types to add.
class _Timeline extends ConsumerWidget {
  const _Timeline({required this.person});

  final Profile person;

  void _chooseType(BuildContext context, RecordTypeRegistry types) {
    final today = DateTime.now();
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
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
                if (t.offeredFor(person, today))
                  ListTile(
                    key: ValueKey('type-${t.key}'),
                    leading: Icon(t.icon, color: sheet.usra.primary),
                    title: Text(t.labelOf(context)),
                    onTap: () {
                      Navigator.pop(sheet);
                      context.push('/family/${person.id}/add/${t.key}');
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final types = ref.watch(moduleRegistryProvider).recordTypes;
    final photos =
        ref.watch(attachmentCountsProvider(person.id)).value ?? const {};
    // Quick logs (feeds, diapers...) live on their own screens. Types this
    // version doesn't know (written by a newer one, e.g. a restored backup)
    // are hidden rather than shown raw.
    final timeline = ref
        .watch(timelineProvider(person.id))
        .whenData(
          (all) => [
            for (final e in all)
              if (types[e.type]?.inTimeline ?? false) e,
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l.personTimelineTitle, style: text.titleMedium),
            TextButton.icon(
              key: const ValueKey('add-record'),
              onPressed: () => _chooseType(context, types),
              icon: const Icon(Icons.add),
              label: Text(l.addRecord),
            ),
          ],
        ),
        const SizedBox(height: UsraSpacing.s2),
        ...timeline.when(
          loading: () => [const Center(child: CircularProgressIndicator())],
          error: (e, _) => [Text('$e')],
          data: (events) => events.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      l.timelineEmpty,
                      textAlign: TextAlign.center,
                      style: text.bodyLarge,
                    ),
                  ),
                ]
              : [
                  for (final e in events) ...[
                    EventCard(
                      event: e,
                      type: types[e.type],
                      photos: photos[e.id] ?? 0,
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
        ),
      ],
    );
  }
}

/// "Add for Laila", already set on this person, and the doctor's summary.
class _PersonActions extends StatelessWidget {
  const _PersonActions({required this.person});

  final Profile person;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    // Simple Mode's theme may ask for more than the design's 60.
    final height = _buttonSize(context).height.clamp(60.0, double.infinity);
    final add = DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        shadows: c.shadowFloat,
      ),
      child: FilledButton.icon(
        key: const ValueKey('person-add'),
        style: FilledButton.styleFrom(
          minimumSize: Size(0, height),
          textStyle: UsraType.body.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: () => showAddSheet(context, person: person.id),
        icon: const Icon(Icons.add),
        label: Text(l.personAddFor(person.displayName)),
      ),
    );
    final summary = OutlinedButton(
      key: const ValueKey('member-doctor-summary'),
      style: OutlinedButton.styleFrom(
        minimumSize: Size(0, height),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        backgroundColor: c.surface,
        side: BorderSide(color: c.lineStrong),
        textStyle: UsraType.body.copyWith(fontWeight: FontWeight.w600),
      ),
      onPressed: () => context.push('/family/${person.id}/doctor-summary'),
      child: Text(l.personDoctorSummary),
    );
    if (_textIsLarge(context) || MediaQuery.sizeOf(context).width < 340) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [add, summary],
      );
    }
    return Row(
      spacing: 10,
      children: [
        Expanded(child: add),
        summary,
      ],
    );
  }
}

class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.type,
    required this.photos,
    this.personName,
  });

  final MedicalEvent event;
  final RecordTypeDefinition? type;
  final int photos;

  /// Shown first, where records of several people are listed together.
  final String? personName;

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
            context.push('/family/${event.profileId}/record/${event.id}'),
        leading: CircleAvatar(
          backgroundColor: context.usra.primarySoft,
          child: Icon(
            type?.icon ?? Icons.description_outlined,
            color: context.usra.primary,
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
            ?personName,
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
                  backgroundColor: context.usra.primary,
                  child: Icon(
                    Icons.photo_outlined,
                    color: context.usra.primary,
                  ),
                ),
              ),
      ),
    );
  }
}
