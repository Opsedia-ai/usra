import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/status_dot.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../l10n/app_localizations.dart';
import 'lab_report.dart';
import 'lab_tests.dart';

/// Results outside the lab's range are worth a look, not an alarm: the
/// same soft colour either way, and always the words.
Severity labFlagSeverity(LabFlag flag) => switch (flag) {
  LabFlag.high || LabFlag.low => Severity.headsUp,
  LabFlag.normal => Severity.good,
  LabFlag.unknown => Severity.info,
};

String labFlagLabel(AppLocalizations l, LabFlag flag) => switch (flag) {
  LabFlag.high => l.labFlagHigh,
  LabFlag.low => l.labFlagLow,
  LabFlag.normal => l.labFlagNormal,
  LabFlag.unknown => l.labFlagUnknown,
};

IconData labFlagIcon(LabFlag flag) => switch (flag) {
  LabFlag.high => Icons.arrow_upward,
  LabFlag.low => Icons.arrow_downward,
  LabFlag.normal => Icons.check,
  LabFlag.unknown => Icons.remove,
};

/// How a result compares with its range, as a dot and words: amber when
/// above or below, green when within, muted when there's no range.
class LabFlagChip extends StatelessWidget {
  const LabFlagChip({super.key, required this.flag});

  final LabFlag flag;

  @override
  Widget build(BuildContext context) {
    final c = context.usra;
    final (dot, text) = switch (labFlagSeverity(flag)) {
      Severity.good => (c.good, c.inkMuted),
      Severity.headsUp || Severity.actSoon => (c.attentionDot, c.attention),
      Severity.urgent => (c.urgent, c.urgent),
      Severity.info => (c.lineStrong, c.inkMuted),
    };
    return StatusDotText(
      label: labFlagLabel(AppLocalizations.of(context), flag),
      color: text,
      dotColor: dot,
    );
  }
}

/// Says what the flags are, every time they're shown.
class LabInfoNote extends StatelessWidget {
  const LabInfoNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(end: 8, top: 2),
          child: Icon(
            Icons.info_outline,
            size: 18,
            color: context.usra.inkMuted,
          ),
        ),
        Expanded(
          child: Text(
            AppLocalizations.of(context).labInfoNote,
            key: const ValueKey('lab-info-note'),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: context.usra.inkMuted),
          ),
        ),
      ],
    );
  }
}

/// "13.5 g/dL": a result and its unit, kept left to right.
String labValueText(LabTest t) =>
    '\u2066${[t.shownValue, ?t.unit].join(' ')}\u2069';

/// Where a test's results over time are shown.
String labTrendPath(String profileId, String testName) =>
    '/family/$profileId/labs/test/${labRouteId(labSeriesKey(testName))}';

/// A lab record on its page: lab, doctor, and each result with the range
/// printed by the lab and the flag from it. Results with a number open
/// their trend.
class LabReportDetails extends StatelessWidget {
  const LabReportDetails({super.key, required this.event});

  final MedicalEvent event;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final report = LabReport.of(event);
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: text.labelLarge?.copyWith(color: context.usra.inkMuted),
          ),
          SelectableText(value, style: text.titleMedium),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (report.lab != null) line(l.fieldLab, report.lab!),
        if (report.orderedBy != null) line(l.fieldOrderedBy, report.orderedBy!),
        Text(l.labResultsTitle, style: text.titleMedium),
        const SizedBox(height: 4),
        const LabInfoNote(),
        const SizedBox(height: 8),
        for (final (i, t) in report.tests.indexed)
          Card(
            key: ValueKey('lab-result-$i'),
            child: InkWell(
              onTap: t.value == null
                  ? null
                  : () => context.go(labTrendPath(event.profileId, t.name)),
              child: Padding(
                padding: const EdgeInsets.all(UsraSpacing.s3),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name, style: text.titleMedium),
                          Text(
                            labValueText(t),
                            style: UsraType.numeral.copyWith(
                              color: context.usra.ink,
                            ),
                          ),
                          if (!t.range.isEmpty)
                            Text(
                              l.labRangeLine('\u2066${t.range.format()}\u2069'),
                              style: UsraType.label.copyWith(
                                color: context.usra.inkMuted,
                              ),
                            ),
                          const SizedBox(height: UsraSpacing.s1),
                          LabFlagChip(flag: t.flag),
                        ],
                      ),
                    ),
                    if (t.value != null)
                      ExcludeSemantics(
                        child: Icon(
                          Icons.show_chart,
                          color: context.usra.inkMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The report as lines of text for the share sheet.
List<String> labShareLines(BuildContext context, MedicalEvent event) {
  final l = AppLocalizations.of(context);
  final report = LabReport.of(event);
  return [
    if (report.lab != null) '${l.fieldLab}: ${report.lab}',
    if (report.orderedBy != null) '${l.fieldOrderedBy}: ${report.orderedBy}',
    for (final t in report.tests)
      [
        '${t.name}: ${[t.shownValue, ?t.unit].join(' ')}',
        if (!t.range.isEmpty) '(${l.labRangeLine(t.range.format())})',
        if (t.flag != LabFlag.unknown) '- ${labFlagLabel(l, t.flag)}',
      ].join(' '),
    l.labInfoNote,
  ];
}
