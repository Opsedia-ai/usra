import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/modules/feature_module.dart';
import 'account_screen.dart';
import 'account_providers.dart';

/// Optional account (phone number and a one-time code) for sync and AI
/// features later. Hidden unless the app was built with a cloud project.
class AccountModule extends FeatureModule {
  const AccountModule();

  @override
  String get id => 'account';

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: accountPath,
      // Not reachable at all without a cloud, even by a saved location.
      redirect: (context, _) =>
          ProviderScope.containerOf(context)
              .read(supabaseConfigProvider)
              .isConfigured
          ? null
          : '/settings',
      builder: (_, _) => const AccountScreen(),
    ),
  ];
}
