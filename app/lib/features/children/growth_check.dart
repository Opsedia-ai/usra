import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/design/status_dot.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/providers.dart';
import '../../core/util/localized_digits.dart';
import '../../core/util/localized_numbers.dart';
import '../../l10n/app_localizations.dart';
import '../account/save_gate.dart';
import 'growth.dart';

/// Before saving a measurement: asks "is this number right?" when a value
/// is one WHO flags as implausible for the child's age and sex, so a typing
/// mistake (896 cm for 89.6) isn't saved unnoticed. True to save.
Future<bool> confirmPlausibleGrowth(
  BuildContext context,
  Profile profile,
  DateTime on,
  Map<String, Object?> data,
) async {
  final birth = profile.birthDate;
  if (birth == null) return true;
  final l = AppLocalizations.of(context);
  final months = ageInMonths(birth, on);
  final male = switch (profile.sex) {
    'male' => true,
    'female' => false,
    _ => null,
  };
  final odd = [
    for (final i in GrowthIndicator.values)
      if (data[GrowthFields.of(i)] case final num v)
        if (implausibleGrowth(
          i,
          male: male,
          months: months,
          value: v.toDouble(),
        ))
          '${switch (i) {
            GrowthIndicator.weight => l.fieldWeightKg,
            GrowthIndicator.height => l.fieldHeightCm,
            GrowthIndicator.head => l.fieldHeadCm,
          }} ${localizedDigitsIn(context, '$v')}',
  ];
  if (odd.isEmpty) return true;
  final keep = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      key: const ValueKey('growth-implausible'),
      title: Text(l.growthImplausibleTitle),
      content: Text(l.growthImplausibleBody(odd.join('، '))),
      actions: [
        TextButton(
          key: const ValueKey('growth-implausible-keep'),
          onPressed: () => Navigator.of(c).pop(true),
          child: Text(l.growthImplausibleKeep),
        ),
        FilledButton(
          key: const ValueKey('growth-implausible-fix'),
          onPressed: () => Navigator.of(c).pop(false),
          child: Text(l.growthImplausibleFix),
        ),
      ],
    ),
  );
  return keep ?? false;
}

/// Where a measurement sits against the WHO reference, in words. Outside
/// the usual range it takes the quiet amber dot; inside it stays plain muted
/// text, never a green "all is well".
class GrowthStatusText extends StatelessWidget {
  const GrowthStatusText({super.key, required this.reading});

  final GrowthReading reading;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final percentile = localizedDigitsIn(context, reading.percentileLabel);
    if (!reading.withinUsualRange) {
      return StatusDotText(label: l.growthOutsideRange(percentile));
    }
    return Text(
      l.growthWithinRange(percentile),
      style: UsraType.label.copyWith(
        color: context.usra.inkMuted,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

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
                  labelText: switch (i) {
                    GrowthIndicator.weight => l.fieldWeightKg,
                    GrowthIndicator.height => l.fieldHeightCm,
                    GrowthIndicator.head => l.fieldHeadCm,
                  },
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
                      child: GrowthStatusText(
                        key: ValueKey('check-status-${i.name}'),
                        reading: reading,
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
    final data = {
      for (final i in GrowthIndicator.values) GrowthFields.of(i): ?_value(i),
    };
    final today = DateUtils.dateOnly(DateTime.now());
    if (!await confirmPlausibleGrowth(context, widget.profile, today, data) ||
        !mounted) {
      return;
    }
    if (!await ref.read(saveGateProvider).allow() || !mounted) return;
    try {
      await ref
          .read(databaseProvider)
          .addEvent(
            profileId: widget.profile.id,
            type: 'growth',
            occurredAt: today,
            dataJson: jsonEncode(data),
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
