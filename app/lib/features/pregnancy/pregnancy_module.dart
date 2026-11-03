import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/follow_ups/follow_up.dart';
import '../../core/modules/feature_module.dart';
import '../../core/records/record_type.dart';
import '../../l10n/app_localizations.dart';
import 'antenatal_schedule.dart';
import 'pregnancy.dart';
import 'pregnancy_screen.dart';

/// Pregnancy follow-up: weeks and due date, WHO's antenatal schedule, danger
/// signs and a weight and blood-pressure log. Stored as ordinary records.
class PregnancyModule extends FeatureModule {
  const PregnancyModule();

  @override
  String get id => 'pregnancy';

  @override
  List<RouteBase> get routes => [
    // Opened from a woman's page, so it lives under the family tab.
    GoRoute(
      path: '/family/:id/pregnancy',
      builder: (_, s) => PregnancyScreen(profileId: s.pathParameters['id']!),
    ),
  ];

  @override
  List<FollowUpRule> get followUpRules => const [AncScheduleRule()];

  @override
  List<RecordTypeDefinition> get recordTypes => [
    RecordTypeDefinition(
      key: PregnancyTypes.start,
      icon: Icons.pregnant_woman,
      label: (c) => _l(c).recordPregnancy,
      hasCost: false,
      appliesTo: canBePregnant,
      requireOneOf: const [PregnancyFields.lmp, PregnancyFields.dueDate],
      fields: [
        FieldSpec(
          key: PregnancyFields.lmp,
          kind: FieldKind.date,
          label: (c) => _l(c).fieldLmp,
        ),
        FieldSpec(
          key: PregnancyFields.dueDate,
          kind: FieldKind.date,
          label: (c) => _l(c).fieldDueDate,
        ),
      ],
    ),
    RecordTypeDefinition(
      key: PregnancyTypes.check,
      icon: Icons.monitor_weight_outlined,
      label: (c) => _l(c).recordPregnancyCheck,
      hasCost: false,
      appliesTo: canBePregnant,
      requireOneOf: const [
        PregnancyFields.weightKg,
        PregnancyFields.systolic,
        PregnancyFields.diastolic,
      ],
      fields: [
        FieldSpec(
          key: PregnancyFields.weightKg,
          kind: FieldKind.number,
          label: (c) => _l(c).fieldWeightKg,
        ),
        FieldSpec(
          key: PregnancyFields.systolic,
          kind: FieldKind.number,
          label: (c) => _l(c).fieldSystolic,
        ),
        FieldSpec(
          key: PregnancyFields.diastolic,
          kind: FieldKind.number,
          label: (c) => _l(c).fieldDiastolic,
        ),
      ],
    ),
    RecordTypeDefinition(
      key: PregnancyTypes.end,
      icon: Icons.child_friendly_outlined,
      label: (c) => _l(c).recordPregnancyEnd,
      appliesTo: canBePregnant,
      fields: [
        FieldSpec(
          key: PregnancyFields.outcome,
          kind: FieldKind.choice,
          required: true,
          choices: const ['birth', 'loss', 'other'],
          label: (c) => _l(c).fieldOutcome,
          choiceLabel: (c, v) => switch (v) {
            'birth' => _l(c).outcomeBirth,
            'loss' => _l(c).outcomeLoss,
            _ => _l(c).outcomeOther,
          },
        ),
      ],
    ),
  ];
}

AppLocalizations _l(BuildContext c) => AppLocalizations.of(c);
