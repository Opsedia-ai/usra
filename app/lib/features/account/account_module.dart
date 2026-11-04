import 'package:go_router/go_router.dart';

import '../../core/modules/feature_module.dart';
import 'account_screen.dart';

/// Optional account (phone number and a one-time code) for sync and AI
/// features later. Hidden unless the app was built with a cloud project.
class AccountModule extends FeatureModule {
  const AccountModule();

  @override
  String get id => 'account';

  @override
  List<RouteBase> get routes => [
    GoRoute(path: accountPath, builder: (_, _) => const AccountScreen()),
  ];
}
