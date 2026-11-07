import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../core/modules/feature_module.dart';
import '../../l10n/app_localizations.dart';
import 'home_screen.dart';

class HomeModule extends FeatureModule {
  const HomeModule();

  @override
  String get id => 'home';

  @override
  List<ModuleTab> get tabs => [
    ModuleTab(
      path: '/home',
      icon: Icons.home_outlined,
      label: (c) => AppLocalizations.of(c).navHome,
      order: 0,
      simple: true,
      alsoFor: const ['/family'],
    ),
  ];

  @override
  List<RouteBase> get routes => [
    GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
  ];
}

String severityLabel(AppLocalizations l, Severity s) => switch (s) {
  Severity.info => l.severityInfo,
  Severity.good => l.severityGood,
  Severity.headsUp => l.severityHeadsUp,
  Severity.actSoon => l.severityActSoon,
  Severity.urgent => l.severityUrgent,
};
