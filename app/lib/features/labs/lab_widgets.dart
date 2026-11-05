import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/design/severity_chip.dart';
import '../../core/design/tokens.dart';
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

class LabFlagChip extends StatelessWidget {
  const LabFlagChip({super.key, required this.flag});

  final LabFlag flag;

  @override
  Widget build(BuildContext context) => SeverityChip(
    severity: labFlagSeverity(flag),
    label: labFlagLabel(AppLocalizations.of(context), flag),
  );
}

/// Says what the flags are, every time they're shown.
class LabInfoNote extends StatelessWidget {
  const LabInfoNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsetsDirectional.only(end: 8, top: 2),
          child: Icon(
            Icons.info_outline,
            size: 18,
            color: UsraColors.textMuted,
          ),
        ),
        Expanded(
          child: Text(
            AppLocalizations.of(context).labInfoNote,
            key: const ValueKey('lab-info-note'),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: UsraColors.textMuted),
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
    '/family/$profileId/labs/test/${Uri.encodeComponent(labSeriesKey(testName))}';

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
            style: text.labelLarge?.copyWith(color: UsraColors.textMuted),
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
            child: ListTile(
              onTap: t.value == null
                  ? null
                  : () => context.go(labTrendPath(event.profileId, t.name)),
              title: Text(t.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(labValueText(t), style: text.titleMedium),
                  if (!t.range.isEmpty)
                    Text(l.labRangeLine('\u2066${t.range.format()}\u2069')),
                  const SizedBox(height: 6),
                  LabFlagChip(flag: t.flag),
                ],
              ),
              trailing: t.value == null
                  ? null
                  : const Icon(Icons.show_chart, color: UsraColors.primary),
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
