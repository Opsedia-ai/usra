import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/dr_usra.dart';
import '../../core/design/pebble.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/design/usra_mark.dart';
import '../../core/preferences.dart';
import '../../core/util/localized_digits.dart';
import '../../l10n/app_localizations.dart';
import '../app_lock/app_lock_module.dart';
import '../backup/backup_notices.dart';
import '../backup/backup_providers.dart';
import '../children/vaccines_screen.dart' show HomeVaccines;
import '../family/family_screen.dart';
import '../family/person_status.dart';
import '../follow_ups/follow_ups_section.dart';
import '../medicines/dose_schedule.dart';
import '../medicines/medicine_text.dart';
import '../medicines/medicines_providers.dart';
import '../pregnancy/pregnancy_widgets.dart';
import 'home_setup_cards.dart';
import 'simple_home.dart';
import '../../core/util/separator.dart';

/// Up to this many people, everyone fits on Home without swiping.
const _flowingLimit = 4;

const _pageGutter = 20.0;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TodayRefresh<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    if (ref.watch(simpleModeProvider)) return const SimpleHome();
    final profiles = ref.watch(profilesProvider);
    if (profiles.hasError && !profiles.hasValue) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            AppLocalizations.of(context).homeLoadError,
            key: const ValueKey('home-load-error'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final people = profiles.value;
    if (people == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (people.isEmpty) return const _EmptyHome();
    final none = PersonStatus(
      severity: Severity.good,
      label: AppLocalizations.of(context).homeNothingNeeded,
      icon: Icons.check,
    );
    final statuses = {
      for (final p in people)
        p.id: watchPersonStatus(context, ref, p, none: none),
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(_pageGutter, 16, _pageGutter, 24),
      children: [
        _Header(people: people, statuses: statuses),
        const SizedBox(height: 12),
        if (people.length <= _flowingLimit)
          _FlowingFamily(people: people, statuses: statuses)
        else
          _ScrollingFamily(people: people, statuses: statuses),
        const SizedBox(height: UsraSpacing.s4),
        const _UpcomingDoses(),
        const BackupNotices(),
        const AppLockHomeNotice(),
        const HomePregnancies(),
        const HomeVaccines(),
        const HomeFollowUps(),
        HomeSetupCards(people: people),
        const _LastBackupLine(),
      ],
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        const BackupNotices(),
        Center(child: DrUsra(size: 180, semanticLabel: l.homeGreeting)),
        const SizedBox(height: 12),
        Text(
          l.homeGreeting,
          style: text.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l.homeIntro,
          style: text.bodyLarge?.copyWith(color: context.usra.inkMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const ValueKey('home-add-first'),
          onPressed: () => context.go('/family/new'),
          icon: const Icon(Icons.add),
          label: Text(l.familyAdd),
        ),
        const SizedBox(height: 16),
        Text(
          l.notMedicalDevice,
          style: text.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.people, required this.statuses});

  final List<Profile> people;
  final Map<String, PersonStatus?> statuses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final text = Theme.of(context).textTheme;
    final hour = ref.watch(clockProvider)().hour;
    final greeting = hour >= 4 && hour < 12 ? l.homeMorning : l.homeEvening;
    final meId = ref.watch(meProfileIdProvider);
    // The whole name as written: "عبد الرحمن" has no usable first word.
    final me = [
      for (final p in people)
        if (p.id == meId) p.displayName,
    ].firstOrNull;
    final attention = [
      for (final p in people)
        if (statuses[p.id]?.needsAttention ?? false) p,
    ];
    final greetingBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          // Dr. Usra's mark beside the greeting, as in the brand samples.
          child: UsraMarkTitle(
            me == null ? greeting : l.homeGreetingNamed(greeting, me),
            textKey: const ValueKey('home-greeting'),
            style: text.headlineMedium,
          ),
        ),
        if (attention.isNotEmpty) _AttentionLine(people: attention),
      ],
    );
    // With very large text the two don't fit side by side.
    final stacked = MediaQuery.textScalerOf(context).scale(16) > 24;
    final emergencyLabel = Text(
      l.homeEmergency,
      style: UsraType.body.copyWith(
        color: c.urgent,
        fontWeight: FontWeight.w600,
      ),
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(UsraRadius.button),
      side: BorderSide(color: c.line),
    );
    final emergency = Material(
      color: c.surface,
      shape: shape,
      child: InkWell(
        key: const ValueKey('home-emergency'),
        customBorder: shape,
        onTap: () => context.push('/family/${people.first.id}/emergency'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: UsraSizes.touchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_hospital_outlined, size: 20, color: c.urgent),
                const SizedBox(width: 6),
                if (stacked)
                  Flexible(child: emergencyLabel)
                else
                  emergencyLabel,
              ],
            ),
          ),
        ),
      ),
    );
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          greetingBlock,
          const SizedBox(height: UsraSpacing.s2),
          emergency,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: greetingBlock),
        const SizedBox(width: UsraSpacing.s2),
        emergency,
      ],
    );
  }
}

/// "Laila and Youssef need your attention". Each name opens that person,
/// even when their pebble is off screen. After three names, the family list
/// shows the rest.
class _AttentionLine extends StatelessWidget {
  const _AttentionLine({required this.people});

  final List<Profile> people;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final muted = UsraType.body.copyWith(color: context.usra.inkMuted);
    final shown = people.take(3).toList();
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        for (final (i, p) in shown.indexed) ...[
          if (i > 0) Text(l.homeNamesJoin, style: muted),
          InkWell(
            key: ValueKey('home-attention-${p.id}'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.push('/family/${p.id}'),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: UsraSizes.touchTarget,
                minHeight: UsraSizes.touchTarget,
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  p.displayName,
                  style: UsraType.body.copyWith(
                    color: context.usra.ink,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor: context.usra.ink,
                  ),
                ),
              ),
            ),
          ),
        ],
        if (people.length > shown.length)
          Text(
            '+${localizedDigits(context, people.length - shown.length)}',
            style: muted,
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            people.length == 1
                ? l.homeNeedsAttentionOne(people.single.sex ?? 'other')
                : l.homeNeedsAttentionMany,
            style: muted,
          ),
        ),
      ],
    );
  }
}

class _PersonPebble extends StatelessWidget {
  const _PersonPebble({
    required this.person,
    required this.status,
    this.height,
  });

  final Profile person;
  final PersonStatus? status;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final current = status;
    return Pebble(
      key: ValueKey('home-person-${person.id}'),
      seed: pebbleSeed(person.id),
      color: personColor(context, person.sex),
      height: height,
      onTap: () => context.push('/family/${person.id}'),
      child: Padding(
        padding: const EdgeInsets.all(8),
        // Long words at large text sizes wrap, then shrink to stay inside the
        // pebble rather than get cut off.
        child: LayoutBuilder(
          builder: (context, box) => FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    person.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: UsraType.heading.copyWith(
                      color: context.usra.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (current != null) PersonStatusLabel(status: current),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Four people or fewer: two staggered columns and a dashed "new person".
class _FlowingFamily extends StatelessWidget {
  const _FlowingFamily({required this.people, required this.statuses});

  final List<Profile> people;
  final Map<String, PersonStatus?> statuses;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.textScalerOf(context).scale(112);
    return Column(
      children: [
        for (var row = 0; row < people.length; row += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: UsraSpacing.s3),
            child: Row(
              children: [
                for (var i = row; i < row + 2; i++) ...[
                  if (i > row) const SizedBox(width: UsraSpacing.s3),
                  Expanded(
                    child: i < people.length
                        ? Padding(
                            // The stagger in the design.
                            padding: EdgeInsets.only(
                              top: i.isOdd ? UsraSpacing.s3 : 0,
                              bottom: i.isOdd ? 0 : UsraSpacing.s3,
                            ),
                            child: _PersonPebble(
                              person: people[i],
                              status: statuses[people[i].id],
                              height: height,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        const _NewPersonButton(),
      ],
    );
  }
}

class _NewPersonButton extends StatelessWidget {
  const _NewPersonButton();

  @override
  // A small orchid-ink accent: a secondary action, not the screen's main one.
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const ValueKey('home-new-person'),
    style: OutlinedButton.styleFrom(foregroundColor: context.usra.orchidInk),
    onPressed: () => context.go('/family/new'),
    icon: const Icon(Icons.add),
    label: Text(AppLocalizations.of(context).homeNewPerson),
  );
}

/// Five people or more: two rows that swipe sideways, with the next pebble
/// cut at the edge, and a button to see everyone in one list. The order
/// never changes with status, so people stay where the family expects them.
class _ScrollingFamily extends StatelessWidget {
  const _ScrollingFamily({required this.people, required this.statuses});

  final List<Profile> people;
  final Map<String, PersonStatus?> statuses;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final width = scaler.scale(136);
    final height = scaler.scale(100);
    final count = localizedDigits(context, people.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Wraps at large text sizes instead of overflowing.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l.homeFamily, style: Theme.of(context).textTheme.titleMedium),
            TextButton.icon(
              key: const ValueKey('home-all-family'),
              onPressed: () => context.push('/family'),
              icon: const Icon(Icons.chevron_right),
              iconAlignment: IconAlignment.end,
              label: Text(l.homeAllFamily(count)),
            ),
          ],
        ),
        const SizedBox(height: UsraSpacing.s2),
        // Starts on the page margin and runs out to the screen's edge, so the
        // next pebble is cut there.
        SizedBox(
          height: height * 2 + UsraSpacing.s3 + 14,
          child: LayoutBuilder(
            builder: (context, box) => OverflowBox(
              alignment: AlignmentDirectional.centerStart,
              minWidth: box.maxWidth + _pageGutter,
              maxWidth: box.maxWidth + _pageGutter,
              child: GridView.builder(
                key: const ValueKey('home-family-scroller'),
                scrollDirection: Axis.horizontal,
                // Keeps the pebbles' shadows; the page clips at the screen.
                clipBehavior: Clip.none,
                padding: const EdgeInsetsDirectional.only(
                  end: _pageGutter,
                  bottom: 14,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: UsraSpacing.s3,
                  crossAxisSpacing: UsraSpacing.s3,
                  mainAxisExtent: width,
                ),
                itemCount: people.length,
                itemBuilder: (_, i) => _PersonPebble(
                  person: people[i],
                  status: statuses[people[i].id],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The next doses still to come today. Taken is one tap, with Undo.
class _UpcomingDoses extends ConsumerWidget {
  const _UpcomingDoses();

  static const _shown = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final doses = ref.watch(todayDosesProvider).value ?? const <PlannedDose>[];
    final open = doses.where((d) => !d.isDone).take(_shown).toList();
    if (open.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: UsraSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.homeUpcoming, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: UsraSpacing.s2),
          for (final (i, d) in open.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: UsraSpacing.s2),
              child: _DoseRow(dose: d, canMark: i == 0),
            ),
        ],
      ),
    );
  }
}

class _DoseRow extends ConsumerWidget {
  const _DoseRow({required this.dose, required this.canMark});

  final PlannedDose dose;
  final bool canMark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final r = dose.regimen;
    final time = formatDoseTime(context, dose.at);
    final amount = r.schedule.amount;
    final id = '${r.medicine.id}-${dose.at.millisecondsSinceEpoch}';
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          medicineTitle(r.medicine),
          style: UsraType.body.copyWith(
            color: context.usra.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          amount == null ? time : '$time$partSeparator$amount',
          style: UsraType.body.copyWith(color: context.usra.inkMuted),
        ),
      ],
    );
    final taken = FilledButton.icon(
      key: ValueKey('home-dose-taken-$id'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, UsraSizes.touchTarget),
      ),
      onPressed: () => logDoseTaken(context, ref, dose),
      icon: const Icon(Icons.check),
      label: Text(l.doseTaken),
    );
    // Beside the name normally; underneath at large text, where it won't fit.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Card(
      key: ValueKey('home-dose-$id'),
      child: InkWell(
        onTap: () =>
            context.push('/family/${r.person.id}/medicines/${r.medicine.id}'),
        child: Padding(
          padding: const EdgeInsets.all(UsraSpacing.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  MiniPersonPebble(person: r.person),
                  const SizedBox(width: UsraSpacing.s3),
                  Expanded(child: details),
                  if (canMark && !stacked) ...[
                    const SizedBox(width: UsraSpacing.s2),
                    taken,
                  ],
                ],
              ),
              if (canMark && stacked) ...[
                const SizedBox(height: UsraSpacing.s2),
                taken,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LastBackupLine extends ConsumerWidget {
  const _LastBackupLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastBackupProvider);
    if (last == null) return const SizedBox.shrink();
    final now = ref.watch(clockProvider)();
    final days = now.difference(last).inDays.clamp(0, 100000);
    final color = Severity.good.foregroundOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: UsraSpacing.s1),
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(Icons.check, size: 18, color: color)),
          const SizedBox(width: UsraSpacing.s1),
          Expanded(
            child: Text(
              AppLocalizations.of(context)
                  .homeBackupAgoDays(days, localizedDigits(context, days)),
              key: const ValueKey('home-last-backup'),
              style: UsraType.label.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
