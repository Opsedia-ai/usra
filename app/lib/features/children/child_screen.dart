import 'package:clock/clock.dart';

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../core/database/app_database.dart';
import '../../core/design/severity_chip.dart';
import '../../core/design/tokens.dart';
import '../../core/records/record_type.dart' show decodeRecordData;
import '../../l10n/app_localizations.dart';
import '../family/member_screen.dart' show profileProvider, timelineProvider;
import 'growth.dart';
import 'growth_check.dart';
import 'vaccines_screen.dart' show VaccineSummaryCard;

/// One measurement on a chart: age in months and the value.
typedef GrowthPoint = ({double months, double value, DateTime date});

/// The child's measurements of [indicator], oldest first, within 0-60 months.
List<GrowthPoint> growthPoints(
  List<MedicalEvent> events,
  DateTime birthDate,
  GrowthIndicator indicator,
) {
  final key = GrowthFields.of(indicator);
  return [
    for (final e in events.reversed)
      if (e.type == 'growth')
        if (decodeRecordData(e.dataJson)[key] case final num v when v > 0)
          if (ageInMonths(birthDate, e.occurredAt) case final m
              when m >= 0 && m <= whoMaxMonths)
            (months: m, value: v.toDouble(), date: e.occurredAt),
  ];
}

/// Growth charts and the vaccination schedule for a child under five.
///
/// Informational only: it places measurements on the WHO curves and lists
/// the ministry's schedule; it never diagnoses.
class ChildScreen extends ConsumerWidget {
  const ChildScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider(profileId));
    final timeline = ref.watch(timelineProvider(profileId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l.growthTitle),
        leading: BackButton(onPressed: () => context.go('/family/$profileId')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('growth-add'),
        onPressed: () => context.go('/family/$profileId/add/growth'),
        icon: const Icon(Icons.add),
        label: Text(l.growthAdd),
      ),
      body: switch ((profile, timeline)) {
        (AsyncError(:final error), _) ||
        (_, AsyncError(:final error)) => Center(child: Text('$error')),
        // `.value` keeps the last data while a stream reloads.
        (AsyncValue(value: final p?), AsyncValue(value: final events?)) =>
          isUnderFive(p.birthDate, clock.now())
              ? _Body(profile: p, events: events)
              : Center(child: Text(l.growthUnderFiveOnly)),
        (AsyncData(value: null), _) => Center(child: Text(l.profileNotFound)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.profile, required this.events});

  final Profile profile;
  final List<MedicalEvent> events;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final birth = profile.birthDate!;
    final sex = profile.sex;
    final now = clock.now();
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      children: [
        Text(profile.displayName, style: text.titleLarge),
        const SizedBox(height: 16),
        if (sex != 'male' && sex != 'female')
          Text(l.growthNoSex, style: text.bodyLarge)
        else ...[
          GrowthCheckCard(profile: profile),
          const SizedBox(height: 12),
          for (final indicator in GrowthIndicator.values) ...[
            _GrowthCard(
              indicator: indicator,
              male: sex == 'male',
              points: growthPoints(events, birth, indicator),
              ageMonths: ageInMonths(birth, now),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            l.growthSource,
            style: text.bodySmall?.copyWith(color: UsraColors.textMuted),
          ),
        ],
        const SizedBox(height: 28),
        Text(l.vaccinesTitle, style: text.titleLarge),
        const SizedBox(height: 8),
        VaccineSummaryCard(profile: profile),
      ],
    );
  }
}

class _GrowthCard extends StatelessWidget {
  const _GrowthCard({
    required this.indicator,
    required this.male,
    required this.points,
    required this.ageMonths,
  });

  final GrowthIndicator indicator;
  final bool male;
  final List<GrowthPoint> points;
  final double ageMonths;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final unit = indicator == GrowthIndicator.weight ? 'kg' : 'cm';
    final latest = points.isEmpty ? null : points.last;
    final reading = latest == null
        ? null
        : readGrowth(
            indicator,
            male: male,
            months: latest.months,
            value: latest.value,
          );
    // Show at least a year, rounded up to the next half year, at most 5.
    final lastMonth = math.max(
      ageMonths,
      points.isEmpty ? 0.0 : points.last.months,
    );
    final maxMonths = math
        .max(12, ((lastMonth + 1) / 6).ceil() * 6)
        .clamp(12, whoMaxMonths)
        .toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(switch (indicator) {
              GrowthIndicator.weight => l.growthWeightForAge,
              GrowthIndicator.height => l.growthHeightForAge,
              GrowthIndicator.head => l.growthHeadForAge,
            }, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (latest == null)
              Text(l.growthNoData)
            else ...[
              Text(
                l.growthLatest(
                  '${NumberFormat.decimalPattern(locale).format(latest.value)} $unit',
                  DateFormat.yMMMd(locale).format(latest.date),
                ),
              ),
              if (reading != null) ...[
                const SizedBox(height: 6),
                SeverityChip(
                  key: ValueKey('growth-status-${indicator.name}'),
                  severity: reading.severity,
                  label: reading.withinUsualRange
                      ? l.growthWithinRange(reading.percentileLabel)
                      : l.growthOutsideRange(reading.percentileLabel),
                ),
              ],
            ],
            const SizedBox(height: 12),
            // Age runs left to right in both languages, like printed charts.
            Directionality(
              textDirection: TextDirection.ltr,
              child: AspectRatio(
                aspectRatio: 1.4,
                child: CustomPaint(
                  painter: _ChartPainter(
                    indicator: indicator,
                    male: male,
                    maxMonths: maxMonths,
                    points: points,
                    unit: unit,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Text(
                l.growthAgeAxis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (indicator == GrowthIndicator.head) ...[
              const SizedBox(height: 8),
              Text(
                l.growthNoPrematurity,
                key: const ValueKey('growth-head-note'),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: UsraColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.indicator,
    required this.male,
    required this.maxMonths,
    required this.points,
    required this.unit,
  });

  final GrowthIndicator indicator;
  final bool male;
  final double maxMonths;
  final List<GrowthPoint> points;
  final String unit;

  static const _step = 0.5;
  static const _left = 36.0;
  static const _bottom = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Percentile curves, sampled every half month.
    final curves = [
      for (final (_, z) in chartPercentiles)
        [
          for (var m = 0.0; m <= maxMonths + 1e-9; m += _step)
            (m, lmsValue(whoLms(indicator, male: male, months: m)!, z)),
        ],
    ];
    var low = curves.first.map((p) => p.$2).reduce(math.min);
    var high = curves.last.map((p) => p.$2).reduce(math.max);
    for (final p in points) {
      if (p.months > maxMonths) continue;
      low = math.min(low, p.value);
      high = math.max(high, p.value);
    }
    final pad = (high - low) * 0.05;
    low = (low - pad).floorToDouble();
    high = (high + pad).ceilToDouble();

    final chart = Rect.fromLTRB(
      _left,
      4,
      size.width - 4,
      size.height - _bottom,
    );
    Offset at(double months, double value) => Offset(
      chart.left + chart.width * months / maxMonths,
      chart.bottom - chart.height * (value - low) / (high - low),
    );

    // Grid and axis labels.
    final grid = Paint()
      ..color = UsraColors.line
      ..strokeWidth = 1;
    final xStep = maxMonths > 24 ? 12 : 3;
    for (var m = 0; m <= maxMonths; m += xStep) {
      final x = at(m.toDouble(), low).dx;
      canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), grid);
      _label(canvas, '$m', Offset(x, chart.bottom + 3), center: true);
    }
    final yStep = _niceStep((high - low) / 5);
    for (var v = (low / yStep).ceil() * yStep; v <= high; v += yStep) {
      final y = at(0, v).dy;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      _label(canvas, _number(v), Offset(2, y - 7));
    }
    _label(canvas, unit, Offset(2, chart.top - 2));

    // Usual range (3rd-97th) shaded, then the percentile lines.
    final band = Path()
      ..moveTo(
        at(0, curves.first.first.$2).dx,
        at(0, curves.first.first.$2).dy,
      );
    for (final (m, v) in curves.first) {
      band.lineTo(at(m, v).dx, at(m, v).dy);
    }
    for (final (m, v) in curves.last.reversed) {
      band.lineTo(at(m, v).dx, at(m, v).dy);
    }
    canvas.drawPath(band..close(), Paint()..color = Severity.good.background);
    for (var i = 0; i < curves.length; i++) {
      final median = chartPercentiles[i].$1 == 50;
      final line = Path();
      for (final (j, (m, v)) in curves[i].indexed) {
        final o = at(m, v);
        j == 0 ? line.moveTo(o.dx, o.dy) : line.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = median ? 2 : 1
          ..color = median ? Severity.good.foreground : UsraColors.textMuted,
      );
      final (end, endValue) = curves[i].last;
      _label(
        canvas,
        '${chartPercentiles[i].$1}',
        at(end, endValue) - const Offset(14, 14),
      );
    }

    // The child's measurements, joined in time order.
    final shown = [
      for (final p in points)
        if (p.months <= maxMonths) at(p.months, p.value),
    ];
    if (shown.length > 1) {
      canvas.drawPath(
        Path()..addPolygon(shown, false),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = UsraColors.primary,
      );
    }
    for (final o in shown) {
      canvas.drawCircle(o, 4.5, Paint()..color = UsraColors.primary);
      canvas.drawCircle(
        o,
        4.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = UsraColors.surface,
      );
    }
  }

  static double _niceStep(double raw) {
    for (final s in [0.5, 1.0, 2.0, 5.0, 10.0, 20.0]) {
      if (s >= raw) return s;
    }
    return 50;
  }

  static String _number(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

  static void _label(
    Canvas canvas,
    String text,
    Offset at, {
    bool center = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 10, color: UsraColors.textMuted),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center ? at - Offset(painter.width / 2, 0) : at);
    painter.dispose();
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      !listEquals(old.points, points) ||
      old.maxMonths != maxMonths ||
      old.male != male ||
      old.indicator != indicator;
}
