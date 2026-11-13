import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../core/database/app_database.dart';
import '../../core/design/pill_chip.dart';
import '../../core/design/list_row.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/records/record_type.dart' show decodeRecordData;
import '../../core/util/localized_digits.dart';
import '../../l10n/app_localizations.dart';
import '../family/member_screen.dart' show profileProvider, timelineProvider;
import 'growth.dart';
import 'growth_check.dart';
import '../../core/util/separator.dart';
import 'vaccines_screen.dart' show VaccineSummaryCard;
import '../../core/providers.dart' show nowOf;

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

/// A growth record's measures with their units, in the app's digits:
/// "١٢ كجم – ٨٦ سم". Also the record's row in timelines and Records.
String growthLine(BuildContext context, Map<String, Object?> data) {
  final l = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toLanguageTag();
  final number = NumberFormat.decimalPattern(locale);
  String? part(String key, String unit) => switch (data[key]) {
    final num v when v > 0 =>
      '${localizedDigitsIn(context, number.format(v))} $unit',
    _ => null,
  };
  return [
    ?part(GrowthFields.weightKg, l.growthUnitKg),
    ?part(GrowthFields.heightCm, l.growthUnitCm),
    ?part(GrowthFields.headCm, l.growthUnitCm),
  ].join(partSeparator);
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
        title: Text(switch (profile.value) {
          final p? => l.growthTitleOf(p.displayName),
          null => l.growthTitle,
        }),
        leading: BackButton(onPressed: () => context.go('/family/$profileId')),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton.icon(
            key: const ValueKey('growth-add'),
            onPressed: () =>
                context.go('/family/$profileId/add/growth?back=growth'),
            icon: const Icon(Icons.add),
            label: Text(l.growthNew),
          ),
        ),
      ),
      body: switch ((profile, timeline)) {
        (AsyncError(:final error), _) ||
        (_, AsyncError(:final error)) => Center(child: Text('$error')),
        // `.value` keeps the last data while a stream reloads.
        (AsyncValue(value: final p?), AsyncValue(value: final events?)) =>
          isUnderFive(p.birthDate, nowOf(context))
              ? _Body(profile: p, events: events)
              : Center(child: Text(l.growthUnderFiveOnly)),
        (AsyncData(value: null), _) => Center(child: Text(l.profileNotFound)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.profile, required this.events});

  final Profile profile;
  final List<MedicalEvent> events;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  /// Null until chosen: starts on the first measure outside the range, so a
  /// reading to take to the doctor is never behind a tab nobody opens.
  GrowthIndicator? _chosen;

  bool _outside(GrowthIndicator i) {
    final birth = widget.profile.birthDate!;
    final points = growthPoints(widget.events, birth, i);
    if (points.isEmpty) return false;
    final reading = readGrowth(
      i,
      male: widget.profile.sex == 'male',
      months: points.last.months,
      value: points.last.value,
    );
    return reading != null && !reading.withinUsualRange;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final profile = widget.profile;
    final events = widget.events;
    final birth = profile.birthDate!;
    final sex = profile.sex;
    final now = nowOf(context);
    final text = Theme.of(context).textTheme;
    final known = sex == 'male' || sex == 'female';
    final outside = known
        ? {
            for (final i in GrowthIndicator.values)
              if (_outside(i)) i,
          }
        : const <GrowthIndicator>{};
    final indicator = _chosen ?? outside.firstOrNull ?? GrowthIndicator.weight;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        if (!known)
          Text(l.growthNoSex, style: text.bodyLarge)
        else ...[
          Wrap(
            spacing: UsraSpacing.s2,
            runSpacing: UsraSpacing.s2,
            children: [
              for (final i in GrowthIndicator.values)
                Semantics(
                  value: outside.contains(i) ? l.growthTabOutside : null,
                  child: UsraPill(
                    key: ValueKey('growth-tab-${i.name}'),
                    selected: indicator == i,
                    icon: outside.contains(i)
                        ? Icons.warning_amber_rounded
                        : null,
                    onTap: () => setState(() => _chosen = i),
                    label: switch (i) {
                      GrowthIndicator.weight => l.growthTabWeight,
                      GrowthIndicator.height => l.growthTabHeight,
                      GrowthIndicator.head => l.growthTabHead,
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: UsraSpacing.s3),
          _GrowthCard(
            key: ValueKey('growth-card-${indicator.name}'),
            indicator: indicator,
            male: sex == 'male',
            name: profile.displayName,
            points: growthPoints(events, birth, indicator),
            ageMonths: ageInMonths(birth, now),
          ),
          const SizedBox(height: UsraSpacing.s3),
          GrowthCheckCard(profile: profile),
        ],
        const SizedBox(height: UsraSpacing.s3),
        _History(profileId: profile.id, events: events),
        const SizedBox(height: UsraSpacing.s4),
        UsraGroupLabel(l.vaccinesTitle),
        VaccineSummaryCard(profile: profile),
      ],
    );
  }
}

/// Every measurement, newest first, each opening its record.
class _History extends StatelessWidget {
  const _History({required this.profileId, required this.events});

  final String profileId;
  final List<MedicalEvent> events;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final rows = [
      for (final e in events)
        if (e.type == 'growth') e,
    ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    String line(MedicalEvent e) =>
        growthLine(context, decodeRecordData(e.dataJson));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UsraGroupLabel(l.growthHistoryTitle),
        UsraListCard(
          key: const ValueKey('growth-history'),
          children: [
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(UsraSpacing.s4),
                child: Text(
                  l.growthNoData,
                  style: UsraType.body.copyWith(color: c.inkMuted),
                ),
              ),
            for (final e in rows)
              UsraListRow(
                key: ValueKey('growth-history-${e.id}'),
                title: line(e),
                subtitleText: DateFormat.yMMMd(locale).format(e.occurredAt),
                onTap: () => context.push('/family/$profileId/record/${e.id}'),
              ),
          ],
        ),
      ],
    );
  }
}

class _GrowthCard extends StatelessWidget {
  const _GrowthCard({
    super.key,
    required this.indicator,
    required this.male,
    required this.name,
    required this.points,
    required this.ageMonths,
  });

  final GrowthIndicator indicator;
  final bool male;
  final String name;
  final List<GrowthPoint> points;
  final double ageMonths;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final unit = indicator == GrowthIndicator.weight
        ? l.growthUnitKg
        : l.growthUnitCm;
    final c = context.usra;
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
                '${localizedDigitsIn(context, NumberFormat.decimalPattern(locale).format(latest.value))} $unit',
                key: ValueKey('growth-value-${indicator.name}'),
                style: UsraType.title.copyWith(color: c.heading),
              ),
              Text(
                l.growthLastOn(DateFormat.yMMMd(locale).format(latest.date)),
                style: UsraType.body.copyWith(color: c.inkMuted),
              ),
              if (reading != null) ...[
                const SizedBox(height: 6),
                GrowthStatusText(
                  key: ValueKey('growth-status-${indicator.name}'),
                  reading: reading,
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
                    colors: context.usra,
                    indicator: indicator,
                    male: male,
                    maxMonths: maxMonths,
                    points: points,
                    unit: unit,
                    language: Localizations.localeOf(context).languageCode,
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
            const SizedBox(height: UsraSpacing.s2),
            Wrap(
              spacing: UsraSpacing.s3,
              runSpacing: UsraSpacing.s1,
              children: [
                _Legend(color: c.heading, label: l.growthLegendOwn(name)),
                _Legend(
                  color: Severity.good.backgroundOf(context),
                  border: Severity.good.foregroundOf(context),
                  label: l.growthLegendReference,
                ),
              ],
            ),
            const SizedBox(height: UsraSpacing.s2),
            Text(
              l.growthSource,
              key: const ValueKey('growth-source'),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: c.inkMuted),
            ),
            if (indicator == GrowthIndicator.head) ...[
              const SizedBox(height: 8),
              Text(
                l.growthNoPrematurity,
                key: const ValueKey('growth-head-note'),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: context.usra.inkMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.border});

  final Color color;
  final Color? border;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: border == null ? null : Border.all(color: border!),
        ),
      ),
      const SizedBox(width: UsraSpacing.s1),
      Flexible(
        child: Text(
          label,
          style: UsraType.label.copyWith(color: context.usra.ink),
        ),
      ),
    ],
  );
}

/// The smallest text on a chart.
const growthAxisFontSize = 14.0;

/// One percentile label as last painted: the curve's end (y) and where the
/// label went. Tests check each label sits on its own curve.
typedef PercentileLabel = ({int percentile, double curveY, Rect label});

/// What the growth chart painted last: its labels, where every curve
/// ends, where the curves stop on the right and the chart's width. For
/// tests only.
@visibleForTesting
({
  List<PercentileLabel> labels,
  List<double> curveEnds,
  double curvesRight,
  double width,
})?
lastGrowthChart;

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.colors,
    required this.indicator,
    required this.male,
    required this.maxMonths,
    required this.points,
    required this.unit,
    required this.language,
  });

  final UsraColors colors;
  final GrowthIndicator indicator;
  final bool male;
  final double maxMonths;
  final List<GrowthPoint> points;
  final String unit;
  final String language;

  static const _step = 0.5;
  static const _left = 40.0;
  static const _top = 22.0;
  static const _bottom = 24.0;

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
    final curveLow = curves.first.map((p) => p.$2).reduce(math.min);
    final curveHigh = curves.last.map((p) => p.$2).reduce(math.max);
    // Measurements stretch the axis by a third of the curves' span at most:
    // a typing mistake (896 cm) keeps it readable, and its point sits on
    // the edge.
    final reach = (curveHigh - curveLow) / 3;
    var low = curveLow;
    var high = curveHigh;
    for (final p in points) {
      if (p.months > maxMonths) continue;
      low = math.min(low, math.max(p.value, curveLow - reach));
      high = math.max(high, math.min(p.value, curveHigh + reach));
    }
    final pad = (high - low) * 0.05;
    low = (low - pad).floorToDouble();
    high = (high + pad).ceilToDouble();

    // The percentile labels sit in their own strip right of the curves'
    // ends, so they cover no curve and nothing is cut at the edge.
    final gutter = _labelWidth(digitsIn(language, '97')) + 8;
    final chart = Rect.fromLTRB(
      _left,
      _top,
      size.width - gutter,
      size.height - _bottom,
    );
    Offset at(double months, double value) => Offset(
      chart.left + chart.width * months / maxMonths,
      chart.bottom - chart.height * (value - low) / (high - low),
    );

    // Grid and axis labels.
    final grid = Paint()
      ..color = colors.line
      ..strokeWidth = 1;
    final xStep = maxMonths > 24 ? 12 : 3;
    for (var m = 0; m <= maxMonths; m += xStep) {
      final x = at(m.toDouble(), low).dx;
      canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), grid);
      _label(
        canvas,
        digitsIn(language, '$m'),
        Offset(x, chart.bottom + 2),
        center: true,
      );
    }
    final yStep = _niceStep((high - low) / 5);
    // The unit sits above the axis labels; one that would run into it is
    // left out, its grid line kept (end-to-end test #14: "سم" over "١٠٠").
    final unitPainter = _painter(unit);
    final unitBottom = unitPainter.height + 2;
    unitPainter.dispose();
    for (var v = (low / yStep).ceil() * yStep; v <= high; v += yStep) {
      final y = at(0, v).dy;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      if (y - 9 < unitBottom) continue;
      _label(canvas, digitsIn(language, _number(v)), Offset(2, y - 9));
    }
    _label(canvas, unit, const Offset(2, 0));

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
    canvas.drawPath(
      band..close(),
      Paint()..color = Severity.good.backgroundIn(colors),
    );
    final labels = <PercentileLabel>[];
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
          ..color = median
              ? Severity.good.foregroundIn(colors)
              : colors.inkMuted,
      );
      // At 14 px all five would run together: the outer two and the middle.
      // Each sits just right of its curve's end, centred on it: placed above
      // the end, as before, it read as the next curve's label.
      if (i == 0 || median || i == curves.length - 1) {
        final (end, endValue) = curves[i].last;
        final tip = at(end, endValue);
        final rect = _label(
          canvas,
          digitsIn(language, '${chartPercentiles[i].$1}'),
          tip,
          afterEnd: true,
        );
        labels.add((
          percentile: chartPercentiles[i].$1,
          curveY: tip.dy,
          label: rect,
        ));
      }
    }
    lastGrowthChart = (
      labels: labels,
      curveEnds: [for (final c in curves) at(c.last.$1, c.last.$2).dy],
      curvesRight: chart.right,
      width: size.width,
    );

    // The child's measurements, joined in time order.
    final shown = [
      for (final p in points)
        if (p.months <= maxMonths) at(p.months, p.value.clamp(low, high)),
    ];
    if (shown.length > 1) {
      canvas.drawPath(
        Path()..addPolygon(shown, false),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = colors.heading,
      );
    }
    // Heading colour, not primary: in dark mode the primary blue was hard
    // to see on the green band. A surface ring keeps it off the curves.
    for (final o in shown) {
      canvas.drawCircle(o, 5, Paint()..color = colors.heading);
      canvas.drawCircle(
        o,
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = colors.surface,
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

  TextPainter _painter(String text) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: growthAxisFontSize, color: colors.inkMuted),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  double _labelWidth(String text) {
    final painter = _painter(text);
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// Paints [text] at [at] (its top left, or top centre with [center]); with
  /// [afterEnd], starting a little right of [at] and centred on it
  /// vertically, in the strip beside the curves. Where it went.
  Rect _label(
    Canvas canvas,
    String text,
    Offset at, {
    bool center = false,
    bool afterEnd = false,
  }) {
    final painter = _painter(text);
    final topLeft = afterEnd
        ? at + Offset(4, -painter.height / 2)
        : center
        ? at - Offset(painter.width / 2, 0)
        : at;
    final rect = topLeft & painter.size;
    painter.paint(canvas, topLeft);
    painter.dispose();
    return rect;
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.colors != colors ||
      old.language != language ||
      !listEquals(old.points, points) ||
      old.maxMonths != maxMonths ||
      old.male != male ||
      old.indicator != indicator;
}
