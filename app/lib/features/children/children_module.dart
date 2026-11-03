import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/follow_ups/follow_up.dart';
import '../../core/modules/feature_module.dart';
import '../../core/records/record_type.dart';
import '../../l10n/app_localizations.dart';
import 'child_screen.dart';
import 'growth.dart';
import 'vaccine_follow_up.dart';

/// Under-fives: WHO growth charts and Egypt's mandatory vaccinations.
class ChildrenModule extends FeatureModule {
  const ChildrenModule();

  @override
  String get id => 'children';

  @override
  List<RouteBase> get routes => [
    // Opened from a child's page, so it lives under the family tab.
    GoRoute(
      path: '/family/:id/growth',
      builder: (_, s) => ChildScreen(profileId: s.pathParameters['id']!),
    ),
  ];

  @override
  List<FollowUpRule> get followUpRules => const [EgyptVaccineRule()];

  @override
  List<RecordTypeDefinition> get recordTypes => [
    RecordTypeDefinition(
      key: 'growth',
      icon: Icons.straighten_outlined,
      label: (c) => _l(c).recordGrowth,
      hasCost: false,
      requireOneOf: const [
        GrowthFields.weightKg,
        GrowthFields.heightCm,
        GrowthFields.headCm,
      ],
      fields: [
        FieldSpec(
          key: GrowthFields.weightKg,
          kind: FieldKind.number,
          label: (c) => _l(c).fieldWeightKg,
        ),
        FieldSpec(
          key: GrowthFields.heightCm,
          kind: FieldKind.number,
          label: (c) => _l(c).fieldHeightCm,
        ),
        FieldSpec(
          key: GrowthFields.headCm,
          kind: FieldKind.number,
          label: (c) => _l(c).fieldHeadCm,
        ),
      ],
    ),
  ];
}

AppLocalizations _l(BuildContext c) => AppLocalizations.of(c);
