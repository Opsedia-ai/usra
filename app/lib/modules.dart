import 'core/modules/feature_module.dart';
import 'features/children/children_module.dart';
import 'features/doctors/doctors_module.dart';
import 'features/family/family_module.dart';
import 'features/home/home_module.dart';
import 'features/scan/scan_module.dart';
import 'features/settings/settings_module.dart';
import 'features/spending/spending_module.dart';
import 'features/tutorial/tutorial_module.dart';

/// Every feature in the app. To add one: create `features/<name>/`,
/// implement [FeatureModule], and add it here.
const List<FeatureModule> appModules = [
  HomeModule(),
  FamilyModule(),
  ChildrenModule(),
  DoctorsModule(),
  SpendingModule(),
  ScanModule(),
  SettingsModule(),
  TutorialModule(),
];
