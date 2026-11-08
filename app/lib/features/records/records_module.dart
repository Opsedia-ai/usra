import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/modules/feature_module.dart';
import '../../l10n/app_localizations.dart';
import 'records_screen.dart';

class RecordsModule extends FeatureModule {
  const RecordsModule();

  @override
  String get id => 'records';

  @override
  List<ModuleTab> get tabs => [
    ModuleTab(
      path: '/records',
      icon: Icons.description_outlined,
      label: (c) => AppLocalizations.of(c).navRecords,
      order: 18,
    ),
  ];

  @override
  List<RouteBase> get routes => [
    GoRoute(path: '/records', builder: (_, _) => const RecordsScreen()),
  ];
}
