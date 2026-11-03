import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/design/severity_chip.dart';
import '../../core/providers.dart';
import '../../core/util/localized_numbers.dart';
import '../../l10n/app_localizations.dart';
import 'growth.dart';

/// "Tell me the weight and I'll check": today's weight or height against
/// the WHO curves for the child's age and sex, before deciding to save it.
class GrowthCheckCard extends ConsumerStatefulWidget {
  const GrowthCheckCard({super.key, required this.profile});

  /// A child under five with a known sex.
  final Profile profile;

  @override
  ConsumerState<GrowthCheckCard> createState() => _GrowthCheckCardState();
}

class _GrowthCheckCardState extends ConsumerState<GrowthCheckCard> {
  final _fields = {
    for (final i in GrowthIndicator.values) i: TextEditingController(),
  };

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  num? _value(GrowthIndicator i) =>
      switch (parseLocalizedNumber(_fields[i]!.text)) {
        final v? when v > 0 => v,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final months = ageInMonths(widget.profile.birthDate!, DateTime.now());
    final filled = GrowthIndicator.values.any((i) => _value(i) != null);
    return Card(
      key: const ValueKey('growth-check'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.growthCheckTitle, style: text.titleMedium),
            const SizedBox(height: 4),
            Text(l.growthCheckIntro(l.fuAgeMonths(months.floor()))),
            const SizedBox(height: 12),
            for (final i in GrowthIndicator.values) ...[
              TextField(
                key: ValueKey('check-${i.name}'),
                controller: _fields[i],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: i == GrowthIndicator.weight
                      ? l.fieldWeightKg
                      : l.fieldHeightCm,
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_value(i) case final v?)
                if (readGrowth(
                      i,
                      male: widget.profile.sex == 'male',
                      months: months,
                      value: v.toDouble(),
                    )
                    case final reading?)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: SeverityChip(
                        key: ValueKey('check-status-${i.name}'),
                        severity: reading.severity,
                        label: reading.withinUsualRange
                            ? l.growthWithinRange(reading.percentileLabel)
                            : l.growthOutsideRange(reading.percentileLabel),
                      ),
                    ),
                  ),
              const SizedBox(height: 8),
            ],
            if (filled)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  key: const ValueKey('check-save'),
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(l.growthCheckSave),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(databaseProvider)
          .addEvent(
            profileId: widget.profile.id,
            type: 'growth',
            occurredAt: DateUtils.dateOnly(DateTime.now()),
            dataJson: jsonEncode({
              for (final i in GrowthIndicator.values)
                GrowthFields.of(i): ?_value(i),
            }),
          );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.saveFailed)));
      return;
    }
    if (!mounted) return;
    for (final c in _fields.values) {
      c.clear();
    }
    setState(() {});
    messenger.showSnackBar(SnackBar(content: Text(l.logSaved)));
  }
}
