import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/design/tokens.dart';
import '../../core/providers.dart';
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
  late final DateTime _now = widget.now ?? DateTime.now();
  var _period = SpendingPeriod.month;
  late DateTime _start = _period.startOf(_now);
  late String? _profileId = widget.profileId;

  bool get _isCurrent => !_start.isBefore(_period.startOf(_now));

  void _setPeriod(SpendingPeriod period) => setState(() {
    // Keep today in view when looking at the current period, otherwise the
    // period around the one being looked at.
    _start = period.startOf(_isCurrent ? _now : _start);
    _period = period;
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final people = ref.watch(profilesProvider).value ?? const <Profile>[];
    // A removed person's link falls back to the whole family.
    final profileId = people.any((p) => p.id == _profileId) ? _profileId : null;
    final view = (period: _period, start: _start, profileId: profileId);
    final trend = ref.watch(spendingTrendProvider(view));

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
                onPressed: _isCurrent
                    ? null
                    : () => setState(() => _start = _period.shift(_start, 1)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: trend.when(
                loading: () => const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('$e'),
                data: (totals) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      formatMoney(context, totals.last),
                      key: const ValueKey('spending-total'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: UsraColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l.spendingRecent,
                      style: Theme.of(context).textTheme.labelLarge,
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
              ),
            ),
          ),
          if (trend.value?.last == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                l.spendingEmpty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          else ...[
            _Split(group: SpendingGroup.type, view: view),
            if (profileId == null)
              _Split(group: SpendingGroup.person, view: view),
            _Split(group: SpendingGroup.doctor, view: view),
          ],
        ],
      ),
    );
  }
}

/// "350" or "350.50" with the currency, in the app's language.
String formatMoney(BuildContext context, int minor) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final amount = NumberFormat.decimalPatternDigits(
    locale: locale,
    decimalDigits: minor % 100 == 0 ? 0 : 2,
  ).format(minor / 100);
  return '$amount ${AppLocalizations.of(context).currencyEgp}';
}

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
              child: ChoiceChip(
                key: ValueKey('spending-person-${id ?? 'all'}'),
                label: Text(name),
                selected: selected == id,
                onSelected: (_) => onSelected(id),
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
                    '${label.format(starts[i])}: ${formatMoney(context, totals[i])}',
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onTap(starts[i]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: highest == 0
                                  ? 0
                                  : totals[i] / highest,
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 3),
                                decoration: BoxDecoration(
                                  color: i == totals.length - 1
                                      ? UsraColors.primary
                                      : UsraColors.primaryTint,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label.format(starts[i]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
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
class _Split extends ConsumerWidget {
  const _Split({required this.group, required this.view});

  final SpendingGroup group;
  final SpendingView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final slices = ref.watch(spendingSplitProvider((group, view))).value;
    if (slices == null || slices.isEmpty) return const SizedBox.shrink();
    final types = ref.watch(moduleRegistryProvider).recordTypes;
    final sum = slices.fold(0, (a, s) => a + s.totalMinor);

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(switch (group) {
            SpendingGroup.type => l.spendingByType,
            SpendingGroup.person => l.spendingByPerson,
            SpendingGroup.doctor => l.spendingByDoctor,
          }, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            key: ValueKey('spending-by-${group.name}'),
            child: Column(
              children: [
                for (final s in slices)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: UsraColors.primaryTint,
                      foregroundColor: UsraColors.primary,
                      child: switch (group) {
                        SpendingGroup.type => Icon(
                          types[s.key]?.icon ?? Icons.description_outlined,
                        ),
                        SpendingGroup.person => Text(initialOf(s.label ?? '')),
                        SpendingGroup.doctor => const Icon(
                          Icons.medical_services_outlined,
                        ),
                      },
                    ),
                    title: Text(
                      group == SpendingGroup.type
                          ? (types[s.key]?.labelOf(context) ?? s.key)
                          : (s.label ?? '—'),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.spendingRecords(s.count)),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: sum == 0 ? 0 : s.totalMinor / sum,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                          color: UsraColors.primary,
                          backgroundColor: UsraColors.primaryTint,
                        ),
                      ],
                    ),
                    trailing: Text(
                      formatMoney(context, s.totalMinor),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
