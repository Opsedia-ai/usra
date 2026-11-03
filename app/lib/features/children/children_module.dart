import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/follow_ups/follow_up.dart';
import '../../core/modules/feature_module.dart';
import '../../core/records/record_type.dart';
import '../../l10n/app_localizations.dart';
import 'child_screen.dart';
import 'development_screen.dart';
import 'growth.dart';
import 'infant_log.dart';
import 'infant_log_screen.dart';
import 'milestones.dart';
import 'vaccine_follow_up.dart';

/// Under-fives: WHO growth charts, Egypt's mandatory vaccinations, CDC's
/// milestones checklist, and a feeds/sleep/diapers log for babies.
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
    GoRoute(
      path: '/family/:id/development',
      builder: (_, s) => DevelopmentScreen(profileId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/family/:id/baby-log',
      builder: (_, s) => InfantLogScreen(profileId: s.pathParameters['id']!),
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
    // Ticked on the development screen, never from the "add record" list.
    RecordTypeDefinition(
      key: milestoneType,
      icon: Icons.emoji_events_outlined,
      label: (c) => _l(c).recordMilestone,
      hasCost: false,
      appliesTo: (_, _) => false,
      inTimeline: false,
      fields: [
        FieldSpec(
          key: milestoneField,
          kind: FieldKind.choice,
          required: true,
          choices: [for (final m in cdcMilestones) m.id],
          label: (c) => _l(c).recordMilestone,
          choiceLabel: (c, id) => _l(c).milestone(id),
        ),
      ],
    ),
    RecordTypeDefinition(
      key: InfantLog.feed,
      icon: Icons.local_drink_outlined,
      label: (c) => _l(c).recordFeed,
      hasCost: false,
      appliesTo: _underOne,
      inTimeline: false,
      fields: [
        FieldSpec(
          key: InfantLog.kind,
          kind: FieldKind.choice,
          required: true,
          choices: InfantLog.feedKinds,
          label: (c) => _l(c).fieldFeedKind,
          choiceLabel: (c, k) => switch (k) {
            'breast' => _l(c).logBreast,
            'bottle' => _l(c).logBottle,
            _ => _l(c).logSolids,
          },
        ),
        FieldSpec(
          key: InfantLog.amountMl,
          kind: FieldKind.number,
          label: (c) => _l(c).fieldAmountMl,
        ),
      ],
    ),
    RecordTypeDefinition(
      key: InfantLog.sleep,
      icon: Icons.bedtime_outlined,
      label: (c) => _l(c).logSleep,
      hasCost: false,
      appliesTo: _underOne,
      inTimeline: false,
      fields: [
        FieldSpec(
          key: InfantLog.minutes,
          kind: FieldKind.number,
          required: true,
          label: (c) => _l(c).fieldMinutes,
        ),
      ],
    ),
    RecordTypeDefinition(
      key: InfantLog.diaper,
      icon: Icons.baby_changing_station_outlined,
      label: (c) => _l(c).recordDiaper,
      hasCost: false,
      appliesTo: _underOne,
      inTimeline: false,
      fields: [
        FieldSpec(
          key: InfantLog.kind,
          kind: FieldKind.choice,
          required: true,
          choices: InfantLog.diaperKinds,
          label: (c) => _l(c).fieldDiaperKind,
          choiceLabel: (c, k) => switch (k) {
            'wet' => _l(c).diaperWet,
            'dirty' => _l(c).diaperDirty,
            _ => _l(c).diaperBoth,
          },
        ),
      ],
    ),
  ];
}

bool _underOne(Profile p, DateTime today) => isUnderOne(p.birthDate, today);

AppLocalizations _l(BuildContext c) => AppLocalizations.of(c);
