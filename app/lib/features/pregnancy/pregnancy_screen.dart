import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../core/database/app_database.dart';
import '../../core/design/status_chip.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/follow_ups/follow_up.dart';
import '../../core/util/localized_digits.dart';
import '../../l10n/app_localizations.dart';
import '../add/add_sheet.dart';
import '../family/member_screen.dart' show profileProvider, timelineProvider;
import '../family/person_status.dart' show TodayRefresh;
import '../follow_ups/follow_ups_providers.dart' show todayProvider;
import '../medicines/medicines_providers.dart' show todayDosesProvider;
import '../medicines/today_screen.dart' show DoseCard;
import 'antenatal_schedule.dart';
import 'pregnancy.dart';
import 'pregnancy_widgets.dart';

/// A woman's pregnancy: week and due date, danger signs, the antenatal
/// schedule and her weight and blood pressure.
///
/// Informational only: it follows public guidance and her own records; it
/// never diagnoses.
class PregnancyScreen extends ConsumerWidget {
  const PregnancyScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider(profileId));
    final timeline = ref.watch(timelineProvider(profileId));
    final today = ref.watch(todayProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.pregnancyTitle),
        leading: BackButton(onPressed: () => context.go('/family/$profileId')),
      ),
      // Only while a pregnancy is being followed: before that, its main action
      // is starting one.
      bottomNavigationBar: switch ((profile.value, timeline.value)) {
        (final p?, final events?)
            when canBePregnant(p, today) &&
                activePregnancy(FollowUpSubject(p, events).records, today) !=
                    null =>
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: FilledButton.icon(
                key: const ValueKey('pregnancy-add'),
                onPressed: () => showAddSheet(context, person: profileId),
                icon: const Icon(Icons.add),
                label: Text(l.pregnancyAddRecord),
              ),
            ),
          ),
        _ => null,
      },
      body: switch ((profile, timeline)) {
        (AsyncError(:final error), _) ||
        (_, AsyncError(:final error)) => Center(child: Text('$error')),
        (AsyncValue(value: final p?), AsyncValue(value: final events?)) =>
          !canBePregnant(p, today)
              ? _Message(l.pregnancyNotEligible)
              : _Body(
                  profile: p,
                  records: FollowUpSubject(p, events).records,
                  today: today,
                ),
        (AsyncData(value: null), _) => _Message(l.profileNotFound),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

class _Body extends StatefulWidget {
  const _Body({
    required this.profile,
    required this.records,
    required this.today,
  });

  final Profile profile;
  final List<SubjectRecord> records;
  final DateTime today;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  var _doneOpen = false;

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final records = widget.records;
    final today = widget.today;
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: context.usra.inkMuted);
    final pregnancy = activePregnancy(records, today);
    final id = profile.id;

    if (pregnancy == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(Icons.pregnant_woman, size: 72, color: context.usra.primary),
          const SizedBox(height: 12),
          Text(l.pregnancyStartIntro, style: text.bodyLarge),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('pregnancy-start'),
            onPressed: () => context.go('/family/$id/add/pregnancy'),
            icon: const Icon(Icons.add),
            label: Text(l.pregnancyStart),
          ),
          const SizedBox(height: 24),
          Text(l.pregnancyDisclaimer, style: muted),
        ],
      );
    }

    final readings = pregnancyReadings(records, pregnancy);
    final left = pregnancy.daysLeft(today);
    final anc = ancStatuses(pregnancy, records, today);
    // A missed check stays in view: Home may be pointing at it.
    final open = [
      for (final s in anc)
        if (s.state != AncState.done) s,
    ];
    final past = [
      for (final s in anc)
        if (s.state == AncState.done) s,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(profile.displayName, style: text.titleLarge),
        const SizedBox(height: 12),
        PregnancySummaryCard(
          profile: profile,
          pregnancy: pregnancy,
          today: today,
        ),
        const SizedBox(height: 4),
        Text(
          left >= 0 ? l.pregnancyDaysLeft(left) : l.pregnancyPastDue,
          key: const ValueKey('pregnancy-days-left'),
          style: text.bodyMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('pregnancy-add-check'),
              onPressed: () =>
                  context.go('/family/$id/add/${PregnancyTypes.check}'),
              icon: const Icon(Icons.monitor_weight_outlined),
              label: Text(l.pregnancyAddCheck),
            ),
            OutlinedButton.icon(
              key: const ValueKey('pregnancy-end'),
              onPressed: () =>
                  context.go('/family/$id/add/${PregnancyTypes.end}'),
              icon: const Icon(Icons.child_friendly_outlined),
              label: Text(l.pregnancyEnd),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const DangerSignsCard(),
        const SizedBox(height: 24),
        _SupplementsCard(person: profile),
        const SizedBox(height: 24),
        Text(l.pregnancyScheduleTitle, style: text.titleLarge),
        const SizedBox(height: 4),
        if (open.isNotEmpty) ...[
          Text(
            l.pregnancyNextTitle,
            key: const ValueKey('pregnancy-next'),
            style: text.titleMedium,
          ),
          for (final s in open) _AncTile(status: s, today: today),
        ],
        if (past.isNotEmpty) ...[
          Semantics(
            button: true,
            expanded: _doneOpen,
            child: InkWell(
              key: const ValueKey('pregnancy-past-toggle'),
              onTap: () => setState(() => _doneOpen = !_doneOpen),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: UsraSizes.touchTarget,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.pregnancyPastTitle,
                        style: text.titleMedium,
                      ),
                    ),
                    Icon(
                      _doneOpen ? Icons.expand_less : Icons.expand_more,
                      color: context.usra.inkMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_doneOpen)
            for (final s in past) _AncTile(status: s, today: today),
        ],
        const SizedBox(height: 4),
        Text(l.pregnancyScheduleSource, style: muted),
        const SizedBox(height: 24),
        _ReadingsCard(
          key: const ValueKey('pregnancy-weight'),
          title: l.pregnancyWeightTitle,
          unit: 'kg',
          series: [
            [
              for (final r in readings)
                if (r.weightKg case final w?) (r.week, w),
            ],
          ],
          latest: _latestWeight(context, readings),
        ),
        const SizedBox(height: 12),
        _ReadingsCard(
          key: const ValueKey('pregnancy-bp'),
          title: l.pregnancyBpTitle,
          unit: 'mmHg',
          series: [
            [
              for (final r in readings)
                if (r.systolic case final s?) (r.week, s.toDouble()),
            ],
            [
              for (final r in readings)
                if (r.diastolic case final d?) (r.week, d.toDouble()),
            ],
          ],
          latest: _latestBp(context, readings),
        ),
        const SizedBox(height: 8),
        Text(l.pregnancyBpSource, style: muted),
        const SizedBox(height: 16),
        Text(l.pregnancyDisclaimer, style: muted),
      ],
    );
  }

  static Widget _latest(BuildContext context, String value, DateTime date) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Text(
      AppLocalizations.of(context)
          .growthLatest(value, DateFormat.yMMMd(locale).format(date)),
    );
  }

  static Widget? _latestWeight(
    BuildContext context,
    List<PregnancyReading> readings,
  ) {
    final r = readings.reversed.where((r) => r.weightKg != null).firstOrNull;
    final weight = r?.weightKg;
    if (r == null || weight == null) return null;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return _latest(
      context,
      '${NumberFormat.decimalPattern(locale).format(weight)} kg',
      r.date,
    );
  }

  static Widget? _latestBp(
    BuildContext context,
    List<PregnancyReading> readings,
  ) {
    final l = AppLocalizations.of(context);
    final r = readings.reversed
        .where((r) => r.systolic != null || r.diastolic != null)
        .firstOrNull;
    final level = BloodPressureLevel.of(r?.systolic, r?.diastolic);
    if (r == null || level == null) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _latest(context, '${r.systolic ?? '–'}/${r.diastolic ?? '–'}', r.date),
        const SizedBox(height: 6),
        StatusChip(
          key: const ValueKey('pregnancy-bp-status'),
          severity: level.severity,
          label: switch (level) {
            BloodPressureLevel.usual => l.bpUsual,
            BloodPressureLevel.high => l.bpHigh,
            BloodPressureLevel.veryHigh => l.bpVeryHigh,
          },
        ),
      ],
    );
  }
}

class _AncTile extends StatelessWidget {
  const _AncTile({required this.status, required this.today});

  final AncStatus status;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final item = status.item;
    final date = DateFormat.yMMMd(locale).format(status.dueOn);
    final (severity, label) = switch (status.state) {
      AncState.done => (Severity.good, l.ancDone),
      AncState.missed => (Severity.info, l.ancMissed),
      AncState.open => switch (followUpSeverity(
        status.dueOn,
        today,
        graceDays: item.graceDays,
      )) {
        Severity.actSoon => (Severity.actSoon, l.followUpOverdue(date)),
        final s => (s, l.followUpDue(date)),
      },
    };
    final c = context.usra;
    return Padding(
      key: ValueKey('anc-${item.id}'),
      padding: const EdgeInsets.symmetric(vertical: UsraSpacing.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(switch (item.kind) {
              AncKind.contact => Icons.medical_services_outlined,
              AncKind.scan => Icons.image_outlined,
              AncKind.lab => Icons.science_outlined,
            }, color: c.primary),
          ),
          const SizedBox(width: UsraSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ancTitle(l, item),
                  style: UsraType.body.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  ancReason(l, item),
                  style: UsraType.body.copyWith(color: c.inkMuted),
                ),
                const SizedBox(height: UsraSpacing.s1),
                StatusChip(severity: severity, label: label),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Today's doses for this person, each ticked on its own, with the same rules
/// and Undo as the Medicines tab. They're whatever the family added as a
/// medicine: the app names no supplement and suggests none.
class _SupplementsCard extends ConsumerStatefulWidget {
  const _SupplementsCard({required this.person});

  final Profile person;

  @override
  ConsumerState<_SupplementsCard> createState() => _SupplementsCardState();
}

class _SupplementsCardState extends ConsumerState<_SupplementsCard>
    with TodayRefresh<_SupplementsCard> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final person = widget.person;
    final doses = ref.watch(todayDosesProvider);
    final List<Widget> rows = switch (doses) {
      AsyncError() => [
        Text(
          l.homeLoadError,
          key: const ValueKey('pregnancy-supplements-error'),
          style: UsraType.body.copyWith(color: c.inkMuted),
        ),
      ],
      AsyncValue(value: final all?) => () {
        final mine = [
          for (final d in all)
            if (d.regimen.person.id == person.id) d,
        ];
        if (mine.isNotEmpty) {
          return <Widget>[
            for (final d in mine)
              DoseCard(
                key: ValueKey(
                  'pregnancy-dose-${d.regimen.medicine.id}-'
                  '${d.at.millisecondsSinceEpoch}',
                ),
                dose: d,
              ),
          ];
        }
        return <Widget>[
          Text(
            l.pregnancySupplementsEmpty,
            key: const ValueKey('pregnancy-supplements-empty'),
            style: UsraType.body.copyWith(color: c.inkMuted),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey('pregnancy-supplements-add'),
              onPressed: () =>
                  context.push('/family/${person.id}/medicines/new'),
              child: Text(l.pregnancySupplementsAdd),
            ),
          ),
        ];
      }(),
      // Says nothing until it knows: "nothing recorded" has to be true.
      _ => const [],
    };
    return Column(
      key: const ValueKey('pregnancy-supplements'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: UsraSpacing.s1,
      children: [
        Text(
          l.pregnancySupplementsTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        ...rows,
      ],
    );
  }
}

/// Up to two series of readings against the pregnancy week.
class _ReadingsCard extends StatelessWidget {
  const _ReadingsCard({
    super.key,
    required this.title,
    required this.unit,
    required this.series,
    required this.latest,
  });

  final String title;
  final String unit;
  final List<List<(double, double)>> series;
  final Widget? latest;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final empty = series.every((s) => s.isEmpty);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (empty) Text(l.pregnancyNoReadings) else ?latest,
            if (!empty) ...[
              const SizedBox(height: 12),
              Directionality(
                textDirection: TextDirection.ltr,
                child: AspectRatio(
                  aspectRatio: 1.8,
                  child: CustomPaint(
                    painter: _LinePainter(
                      colors: context.usra,
                      series: series,
                      unit: unit,
                      language: Localizations.localeOf(context).languageCode,
                    ),
                  ),
                ),
              ),
              Align(
                child: Text(
                  l.pregnancyWeekAxis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.colors,
    required this.series,
    required this.unit,
    required this.language,
  });

  final UsraColors colors;
  final List<List<(double, double)>> series;
  final String unit;
  final String language;

  static const _maxWeek = 42.0;
  static const _left = 40.0;
  static const _top = 22.0;
  static const _bottom = 24.0;
  List<Color> get _colors => [colors.primary, colors.orchidInk];

  @override
  void paint(Canvas canvas, Size size) {
    final values = [for (final s in series) ...s.map((p) => p.$2)];
    var low = values.reduce(math.min);
    var high = values.reduce(math.max);
    final pad = math.max((high - low) * 0.15, 2.0);
    low = (low - pad).floorToDouble();
    high = (high + pad).ceilToDouble();
    final chart = Rect.fromLTRB(
      _left,
      _top,
      size.width - 4,
      size.height - _bottom,
    );
    Offset at(double week, double v) => Offset(
      chart.left + chart.width * week.clamp(0, _maxWeek) / _maxWeek,
      chart.bottom - chart.height * (v - low) / (high - low),
    );

    final grid = Paint()
      ..color = colors.line
      ..strokeWidth = 1;
    for (var w = 0; w <= _maxWeek; w += 6) {
      final x = at(w.toDouble(), low).dx;
      canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), grid);
      _label(
        canvas,
        digitsIn(language, '$w'),
        Offset(x, chart.bottom + 2),
        center: true,
      );
    }
    for (final v in [low, (low + high) / 2, high]) {
      final y = at(0, v).dy;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      _label(canvas, digitsIn(language, '${v.round()}'), Offset(2, y - 9));
    }
    _label(canvas, unit, const Offset(2, 0));

    for (final (i, s) in series.indexed) {
      final color = _colors[i % _colors.length];
      final points = [for (final (w, v) in s) at(w, v)];
      if (points.length > 1) {
        canvas.drawPath(
          Path()..addPolygon(points, false),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = color,
        );
      }
      for (final o in points) {
        canvas.drawCircle(o, 4, Paint()..color = color);
      }
    }
  }

  void _label(Canvas canvas, String text, Offset at, {bool center = false}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 14, color: colors.inkMuted),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center ? at - Offset(painter.width / 2, 0) : at);
    painter.dispose();
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.colors != colors ||
      old.language != language ||
      old.unit != unit ||
      old.series.length != series.length ||
      [
        for (var i = 0; i < series.length; i++)
          listEquals(old.series[i], series[i]),
      ].contains(false);
}
