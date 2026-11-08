import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/modules/feature_module.dart';
import 'spending_screen.dart';

/// What the family spends on health, per week, month or year.
class SpendingModule extends FeatureModule {
  const SpendingModule();

  @override
  String get id => 'spending';

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: '/money',
      builder: (_, s) {
        // `?person=<id>` opens one person's spending (from their page).
        final person = s.uri.queryParameters['person'];
        return SpendingScreen(key: ValueKey(person), profileId: person);
      },
    ),
  ];
}
