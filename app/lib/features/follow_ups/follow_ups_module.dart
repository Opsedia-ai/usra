import '../../core/follow_ups/follow_up.dart';
import '../../core/modules/feature_module.dart';
import 'rules/record_rules.dart';
import 'rules/screening_rules.dart';

/// Automatic follow-ups from a person's records, conditions and age. The
/// Home and member screens show them; other modules add their own rules.
class FollowUpsModule extends FeatureModule {
  const FollowUpsModule();

  @override
  String get id => 'followUps';

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
