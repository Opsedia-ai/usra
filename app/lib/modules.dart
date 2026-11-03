import 'core/modules/feature_module.dart';
import 'features/children/children_module.dart';
import 'features/doctors/doctors_module.dart';
import 'features/family/family_module.dart';
import 'features/home/home_module.dart';
import 'features/medicines/medicines_module.dart';
import 'features/settings/settings_module.dart';
import 'features/spending/spending_module.dart';

/// Every feature in the app. To add one: create `features/<name>/`,
/// implement [FeatureModule], and add it here.
const List<FeatureModule> appModules = [
  HomeModule(),
  FamilyModule(),
  ChildrenModule(),
  MedicinesModule(),
  DoctorsModule(),
  SpendingModule(),
  SettingsModule(),
];
