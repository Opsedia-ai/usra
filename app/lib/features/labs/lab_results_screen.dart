import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/design/list_row.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../l10n/app_localizations.dart';
import '../family/member_screen.dart' show timelineProvider, profileProvider;
import 'lab_report.dart';
import 'lab_widgets.dart';

/// A person's lab results by test: the latest of each, and its flag.
class LabResultsScreen extends ConsumerWidget {
  const LabResultsScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final name = ref.watch(profileProvider(profileId)).value?.displayName;
    final events = ref.watch(timelineProvider(profileId));
    return Scaffold(
      appBar: AppBar(title: Text([l.memberLabs, ?name].join(' · '))),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton.icon(
            key: const ValueKey('lab-add-report'),
            onPressed: () =>
                context.go('/family/$profileId/add/${LabFields.type}'),
            icon: const Icon(Icons.add),
            label: Text(l.labAddReport),
          ),
        ),
      ),
      body: events.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (events) {
          final series = labSeriesOf(events);
          if (series.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l.labNoResults,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const LabInfoNote(),
              const SizedBox(height: 12),
              UsraListCard(
                children: [
                  for (final s in series)
                    UsraListRow(
                      key: ValueKey('lab-series-${s.testKey}|${s.unit ?? ''}'),
                      onTap: () => context.go(labTrendPath(profileId, s.name)),
                      leading: const IconBox(icon: Icons.show_chart),
                      title: [
                        s.name,
                        if (s.unit != null) '(${s.unit})',
                      ].join(' '),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.labLatest(
                              '\u2066${formatLabNumber(s.latest.value)}\u2069',
                              DateFormat.yMMMd(locale).format(s.latest.date),
                            ),
                            style: UsraType.label.copyWith(
                              color: context.usra.inkMuted,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          LabFlagChip(flag: s.latest.flag),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One test over time for a person, one chart per unit.
class LabTrendScreen extends ConsumerWidget {
  const LabTrendScreen({
    super.key,
    required this.profileId,
    required this.routeId,
  });

  final String profileId;

  /// `LabSeries.routeId` of the test.
  final String routeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final events = ref.watch(timelineProvider(profileId)).value;
    final series = events == null
        ? const <LabSeries>[]
        : labSeriesOf(events).where((s) => s.routeId == routeId).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(series.isEmpty ? l.memberLabs : series.first.name),
      ),
      body: events == null
          ? const Center(child: CircularProgressIndicator())
          : series.isEmpty
          ? Center(child: Text(l.labNoResults))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const LabInfoNote(),
                if (series.length > 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    l.labUnitsApart,
                    key: const ValueKey('lab-units-apart'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 12),
                for (final s in series) ...[
                  _SeriesCard(profileId: profileId, series: s),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _SeriesCard extends StatelessWidget {
  const _SeriesCard({required this.profileId, required this.series});

  final String profileId;
  final LabSeries series;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final unit = series.unit;
    return Card(
      key: ValueKey('lab-trend-${unit ?? ''}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              [series.name, if (unit != null) '(\u2066$unit\u2069)'].join(' '),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            // Time runs left to right in both languages, like printed charts.
            Directionality(
              textDirection: TextDirection.ltr,
              child: AspectRatio(
                aspectRatio: 1.6,
                child: CustomPaint(
                  key: const ValueKey('lab-chart'),
                  painter: LabChartPainter(
                    colors: context.usra,
                    points: series.points,
                    locale: locale,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l.labAllResults,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final (i, p) in series.points.reversed.indexed)
              ListTile(
                key: ValueKey('lab-point-${unit ?? ''}-$i'),
                contentPadding: EdgeInsets.zero,
                onTap: () =>
                    context.go('/family/$profileId/record/${p.eventId}'),
                leading: Icon(
                  labFlagIcon(p.flag),
                  color: labFlagSeverity(p.flag).foregroundOf(context),
                ),
                title: Text(
                  '\u2066${[formatLabNumber(p.value), ?unit].join(' ')}\u2069',
                ),
                subtitle: Text(
                  [
                    DateFormat.yMMMd(locale).format(p.date),
                    if (!p.range.isEmpty)
                      l.labRangeLine('\u2066${p.range.format()}\u2069'),
                    labFlagLabel(l, p.flag),
                  ].join(' · '),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Values over time, with the latest report's printed range shaded.
/// Each point's shape says how it compared with its own report's range
/// (triangle up: above, down: below, circle: within or no range), so the
/// chart doesn't rely on colour alone.
class LabChartPainter extends CustomPainter {
  LabChartPainter({
    required this.colors,
    required this.points,
    required this.locale,
  });

  final UsraColors colors;
  final List<LabPoint> points;
  final String locale;

  String dateLabel(DateTime d) => DateFormat.yMMM(locale).format(d);

  static const _left = 44.0;
  static const _bottom = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final range = points.last.range;
    var low = points.map((p) => p.value).reduce(math.min);
    var high = points.map((p) => p.value).reduce(math.max);
    if (range.low != null) low = math.min(low, range.low!);
    if (range.high != null) high = math.max(high, range.high!);
    if (high == low) {
      final pad = high == 0 ? 1.0 : high.abs() * 0.2;
      low -= pad;
      high += pad;
    }
    final pad = (high - low) * 0.1;
    low -= pad;
    high += pad;
    if (low < 0 && points.every((p) => p.value >= 0)) low = 0;

    var first = points.first.date;
    var last = points.last.date;
    if (!last.isAfter(first)) {
      first = first.subtract(const Duration(days: 30));
      last = last.add(const Duration(days: 30));
    }
    final span = last.difference(first).inMinutes.toDouble();

    final chart = Rect.fromLTRB(
      _left,
      6,
      size.width - 12,
      size.height - _bottom,
    );
    double x(DateTime d) =>
        chart.left + chart.width * d.difference(first).inMinutes / span;
    double y(double v) =>
        chart.bottom - chart.height * (v - low) / (high - low);

    // The latest printed range.
    if (range.isNumeric) {
      final top = y(range.high ?? high);
      final bottom = y(range.low ?? low);
      canvas.drawRect(
        Rect.fromLTRB(chart.left, top, chart.right, bottom),
        Paint()..color = Severity.good.backgroundIn(colors),
      );
    }

    final grid = Paint()
      ..color = colors.line
      ..strokeWidth = 1;
    final step = _niceStep((high - low) / 4);
    for (var v = (low / step).ceil() * step; v <= high; v += step) {
      canvas.drawLine(
        Offset(chart.left, y(v)),
        Offset(chart.right, y(v)),
        grid,
      );
      _label(canvas, formatLabNumber(_round(v)), Offset(2, y(v) - 7));
    }
    canvas.drawLine(chart.bottomLeft, chart.bottomRight, grid);
    _label(
      canvas,
      dateLabel(points.first.date),
      Offset(chart.left, chart.bottom + 4),
    );
    if (points.length > 1) {
      _label(
        canvas,
        dateLabel(points.last.date),
        Offset(chart.right, chart.bottom + 4),
        end: true,
      );
    }

    final offsets = [for (final p in points) Offset(x(p.date), y(p.value))];
    if (offsets.length > 1) {
      canvas.drawPath(
        Path()..addPolygon(offsets, false),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = colors.primary,
      );
    }
    for (final (i, o) in offsets.indexed) {
      final flag = points[i].flag;
      final fill = Paint()
        ..color = flag == LabFlag.high || flag == LabFlag.low
            ? Severity.headsUp.foregroundIn(colors)
            : colors.primary;
      switch (flag) {
        case LabFlag.high:
          canvas.drawPath(_triangle(o, up: true), fill);
        case LabFlag.low:
          canvas.drawPath(_triangle(o, up: false), fill);
        case LabFlag.normal || LabFlag.unknown:
          canvas.drawCircle(o, 4.5, fill);
      }
    }
  }

  static Path _triangle(Offset c, {required bool up}) {
    const r = 6.0;
    final d = up ? -1 : 1;
    return Path()
      ..moveTo(c.dx, c.dy + d * r)
      ..lineTo(c.dx - r, c.dy - d * r * 0.7)
      ..lineTo(c.dx + r, c.dy - d * r * 0.7)
      ..close();
  }

  static double _round(double v) => (v * 1000).roundToDouble() / 1000;

  static double _niceStep(double raw) {
    if (raw <= 0) return 1;
    final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor());
    for (final m in [1, 2, 2.5, 5, 10]) {
      if (m * magnitude >= raw) return (m * magnitude).toDouble();
    }
    return (10 * magnitude).toDouble();
  }

  void _label(Canvas canvas, String text, Offset at, {bool end = false}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 10, color: colors.inkMuted),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, end ? at - Offset(painter.width, 0) : at);
    painter.dispose();
  }

  @override
  bool shouldRepaint(LabChartPainter old) =>
      old.colors != colors ||
      old.locale != locale ||
      !listEquals(old.points, points);
}
