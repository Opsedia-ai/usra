import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/list_row.dart';
import '../../core/design/pill_chip.dart';
import '../../core/design/type.dart';
import '../../core/design/tokens.dart';
import '../../core/providers.dart';
import '../../core/util/localized_numbers.dart';
import '../../core/util/periods.dart';
import '../../l10n/app_localizations.dart';
import '../family/family_screen.dart';
import 'spending_providers.dart';

/// The Money tab: how much went on health in a week, month or year, for the
/// whole family or one person, and where it went.
class SpendingScreen extends ConsumerStatefulWidget {
  const SpendingScreen({super.key, this.profileId, this.now});

  /// Shows this person's spending first instead of the whole family's.
  final String? profileId;

  /// Today; only tests pass it.
  final DateTime? now;

  @override
  ConsumerState<SpendingScreen> createState() => _SpendingScreenState();
}

class _SpendingScreenState extends ConsumerState<SpendingScreen> {
  // Read each time, so a screen left open past midnight stays right.
  DateTime get _now => widget.now ?? nowOf(context);
  var _period = SpendingPeriod.month;
  late DateTime _start = _period.startOf(_now);
  late String? _profileId = widget.profileId;

  /// The last totals shown, kept on screen while another period loads so
  /// the page doesn't jump on every tap.
  List<int>? _shownTotals;

  bool get _isCurrent => _start == _period.startOf(_now);

  void _setPeriod(SpendingPeriod period) => setState(() {
    // Keep today in view when looking at the current period, otherwise the
    // period around the one being looked at.
    _start = period.startOf(_isCurrent ? _now : _start);
    _period = period;
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final peopleAsync = ref.watch(profilesProvider);
    if (!peopleAsync.hasValue && !peopleAsync.hasError) {
      // Wait for the family, or a person's link would show everyone first.
      return Scaffold(
        appBar: AppBar(title: Text(l.spendingTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final people = peopleAsync.value ?? const <Profile>[];
    // A removed person's link falls back to the whole family.
    final profileId = people.any((p) => p.id == _profileId) ? _profileId : null;
    final view = (period: _period, start: _start, profileId: profileId);
    final trend = ref.watch(spendingTrendProvider(view));
    final totals = _shownTotals = trend.value ?? _shownTotals;

    return Scaffold(
      appBar: AppBar(title: Text(l.spendingTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (people.length > 1) ...[
            _PersonFilter(
              people: people,
              selected: profileId,
              onSelected: (id) => setState(() => _profileId = id),
            ),
            const SizedBox(height: 12),
          ],
          SegmentedButton<SpendingPeriod>(
            key: const ValueKey('spending-period'),
            showSelectedIcon: false,
            // Ink on the selected segment: the theme's primary on its soft
            // fill was too faint in dark mode.
            style: SegmentedButton.styleFrom(
              selectedForegroundColor: context.usra.ink,
            ),
            segments: [
              ButtonSegment(
                value: SpendingPeriod.week,
                label: Text(l.spendingWeek),
              ),
              ButtonSegment(
                value: SpendingPeriod.month,
                label: Text(l.spendingMonth),
              ),
              ButtonSegment(
                value: SpendingPeriod.year,
                label: Text(l.spendingYear),
              ),
            ],
            selected: {_period},
            onSelectionChanged: (s) => _setPeriod(s.first),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                key: const ValueKey('spending-previous'),
                tooltip: l.spendingPrevious,
                iconSize: 32,
                icon: const Icon(Icons.chevron_left),
                onPressed: () =>
                    setState(() => _start = _period.shift(_start, -1)),
              ),
              Expanded(
                child: Text(
                  _periodLabel(context, _period, _start),
                  key: const ValueKey('spending-period-label'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: const ValueKey('spending-next'),
                tooltip: l.spendingNext,
                iconSize: 32,
                icon: const Icon(Icons.chevron_right),
                // Not limited to today: records can be dated ahead.
                onPressed: () =>
                    setState(() => _start = _period.shift(_start, 1)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: switch (totals) {
                null when trend.hasError => Text('${trend.error}'),
                null => const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                ),
                final totals => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _money(context, totals.last),
                      key: const ValueKey('spending-total'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: context.usra.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l.spendingRecent,
                      style: UsraType.label.copyWith(
                        color: context.usra.inkMuted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _TrendBars(
                      totals: totals,
                      starts: [
                        for (var i = totals.length - 1; i >= 0; i--)
                          _period.shift(_start, -i),
                      ],
                      period: _period,
                      onTap: (start) => setState(() => _start = start),
                    ),
                  ],
                ),
              },
            ),
          ),
          if (totals?.last == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                l.spendingEmpty,
                textAlign: TextAlign.center,
                style: UsraType.body.copyWith(color: context.usra.inkMuted),
              ),
            )
          else ...[
            for (final group in [
              SpendingGroup.type,
              if (profileId == null) SpendingGroup.person,
              SpendingGroup.doctor,
            ])
              _Split(
                key: ValueKey(group),
                group: group,
                view: view,
                total: totals?.last,
              ),
          ],
        ],
      ),
    );
  }
}

String _money(BuildContext context, int minor) => formatMoney(
  minor,
  locale: Localizations.localeOf(context).toLanguageTag(),
  currency: AppLocalizations.of(context).currencyEgp,
);

String _periodLabel(BuildContext context, SpendingPeriod p, DateTime start) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return switch (p) {
    SpendingPeriod.week =>
      '${DateFormat.MMMd(locale).format(start)} – '
          '${DateFormat.yMMMd(locale).format(DateTime(start.year, start.month, start.day + 6))}',
    SpendingPeriod.month => DateFormat.yMMMM(locale).format(start),
    SpendingPeriod.year => DateFormat.y(locale).format(start),
  };
}

class _PersonFilter extends StatelessWidget {
  const _PersonFilter({
    required this.people,
    required this.selected,
    required this.onSelected,
  });

  final List<Profile> people;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (id, name) in [
            (null, l.spendingWholeFamily),
            for (final p in people) (p.id, p.displayName),
          ])
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: UsraPill(
                key: ValueKey('spending-person-${id ?? 'all'}'),
                label: name,
                selected: selected == id,
                onTap: () => onSelected(id),
              ),
            ),
        ],
      ),
    );
  }
}

/// One bar per period, the shown period highlighted. Tapping a bar shows it.
class _TrendBars extends StatelessWidget {
  const _TrendBars({
    required this.totals,
    required this.starts,
    required this.period,
    required this.onTap,
  });

  final List<int> totals;
  final List<DateTime> starts;
  final SpendingPeriod period;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final label = switch (period) {
      SpendingPeriod.week => DateFormat.Md(locale),
      SpendingPeriod.month => DateFormat.MMM(locale),
      SpendingPeriod.year => DateFormat.y(locale),
    };
    final highest = totals.fold(0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < totals.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                label:
                    '${label.format(starts[i])}: ${_money(context, totals[i])}',
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onTap(starts[i]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (_, box) => Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                // Empty periods still get a thin stub.
                                height: highest == 0
                                    ? 3
                                    : (box.maxHeight * totals[i] / highest)
                                          .clamp(3, box.maxHeight),
                                decoration: BoxDecoration(
                                  color: i == totals.length - 1
                                      ? context.usra.primary
                                      : context.usra.primarySoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Shrinks to fit rather than cutting "أغسطس" short.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label.format(starts[i]),
                            maxLines: 1,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The shown period's spending split by type, person or doctor.
class _Split extends ConsumerStatefulWidget {
  const _Split({
    super.key,
    required this.group,
    required this.view,
    required this.total,
  });

  final SpendingGroup group;
  final SpendingView view;

  /// The period's whole total. Shares are of this, since the doctor split
  /// leaves out records without a linked doctor.
  final int? total;

  @override
  ConsumerState<_Split> createState() => _SplitState();
}

class _SplitState extends ConsumerState<_Split> {
  /// Kept on screen while another period loads.
  List<SpendingSlice>? _shown;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final group = widget.group;
    final slices = _shown =
        ref.watch(spendingSplitProvider((group, widget.view))).value ?? _shown;
    if (slices == null || slices.isEmpty) return const SizedBox.shrink();
    final types = ref.watch(moduleRegistryProvider).recordTypes;
    final whole =
        widget.total ?? slices.fold<int>(0, (a, s) => a + s.totalMinor);

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(switch (group) {
              SpendingGroup.type => l.spendingByType,
              SpendingGroup.person => l.spendingByPerson,
              SpendingGroup.doctor => l.spendingByDoctor,
            }, style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 8),
          UsraListCard(
            key: ValueKey('spending-by-${group.name}'),
            children: [
              for (final s in slices)
                Padding(
                  key: ValueKey('spending-row-${group.name}-${s.key}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: UsraSpacing.s4,
                    vertical: UsraSpacing.s3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Amount drops under the name at large text.
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: UsraSpacing.s2,
                        children: [
                          Text(
                            group == SpendingGroup.type
                                ? (types[s.key]?.labelOf(context) ?? s.key)
                                : (s.label ?? '—'),
                            style: UsraType.body.copyWith(
                              color: context.usra.ink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _money(context, s.totalMinor),
                            style: UsraType.numeral.copyWith(
                              color: context.usra.ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: UsraSpacing.s1),
                      LinearProgressIndicator(
                        value: whole == 0
                            ? 0
                            : (s.totalMinor / whole).clamp(0, 1),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                        color: context.usra.primary,
                        backgroundColor: context.usra.primarySoft,
                        semanticsLabel: _money(context, s.totalMinor),
                      ),
                      const SizedBox(height: UsraSpacing.s1),
                      Text(
                        l.spendingRecords(s.count),
                        style: UsraType.label.copyWith(
                          color: context.usra.inkMuted,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
