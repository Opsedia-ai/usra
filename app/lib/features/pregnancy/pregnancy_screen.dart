import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../core/database/app_database.dart';
import '../../core/design/status_chip.dart';
import '../../core/design/tokens.dart';
import '../../core/follow_ups/follow_up.dart';
import '../../l10n/app_localizations.dart';
import '../family/member_screen.dart' show profileProvider, timelineProvider;
import '../follow_ups/follow_ups_providers.dart' show todayProvider;
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

class _Body extends StatelessWidget {
  const _Body({
    required this.profile,
    required this.records,
    required this.today,
  });

  final Profile profile;
  final List<SubjectRecord> records;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
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
        Text(l.pregnancyScheduleTitle, style: text.titleLarge),
        const SizedBox(height: 4),
        for (final s in ancStatuses(pregnancy, records, today))
          _AncTile(status: s, today: today),
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
    return ListTile(
      key: ValueKey('anc-${item.id}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(switch (item.kind) {
        AncKind.contact => Icons.medical_services_outlined,
        AncKind.scan => Icons.image_outlined,
        AncKind.lab => Icons.science_outlined,
      }, color: context.usra.primary),
      title: Text(ancTitle(l, item)),
      subtitle: Text(ancReason(l, item)),
      trailing: StatusChip(severity: severity, label: label),
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
  });

  final UsraColors colors;
  final List<List<(double, double)>> series;
  final String unit;

  static const _maxWeek = 42.0;
  static const _left = 36.0;
  static const _bottom = 20.0;
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
      4,
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
      _label(canvas, '$w', Offset(x, chart.bottom + 3), center: true);
    }
    for (final v in [low, (low + high) / 2, high]) {
      final y = at(0, v).dy;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      _label(canvas, '${v.round()}', Offset(2, y - 7));
    }
    _label(canvas, unit, Offset(chart.left + 4, chart.top));

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
        style: TextStyle(fontSize: 10, color: colors.inkMuted),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center ? at - Offset(painter.width / 2, 0) : at);
    painter.dispose();
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.colors != colors ||
      old.unit != unit ||
      old.series.length != series.length ||
      [
        for (var i = 0; i < series.length; i++)
          listEquals(old.series[i], series[i]),
      ].contains(false);
}
