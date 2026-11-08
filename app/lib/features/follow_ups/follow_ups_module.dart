import 'package:go_router/go_router.dart';

import '../../core/follow_ups/follow_up.dart';
import '../../core/modules/feature_module.dart';
import 'follow_ups_section.dart';
import 'rules/record_rules.dart';
import 'rules/screening_rules.dart';

/// Automatic follow-ups from a person's records, conditions and age. The
/// Home and member screens show them; other modules add their own rules.
class FollowUpsModule extends FeatureModule {
  const FollowUpsModule();

  @override
  String get id => 'followUps';

  @override
  List<RouteBase> get routes => [
    GoRoute(path: '/follow-ups', builder: (_, _) => const FollowUpsScreen()),
  ];

  @override
  List<FollowUpRule> get followUpRules => const [
    NextVisitRule(),
    VaccineNextDueRule(),
    Hba1cRule(),
    LipidProfileRule(),
    KidneyCheckRule(),
    ScanFollowUpRule(),
    BloodPressureRule(),
    DiabetesScreeningRule(),
    BreastScreeningRule(),
    ColorectalScreeningRule(),
    DiabeticEyeExamRule(),
    DentalCheckupRule(),
    ChildCheckupRule(),
  ];
}
