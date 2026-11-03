import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../records/record_type.dart';

/// What a user has paid for. Paid modules check this, never purchase code.
enum Entitlement { free, aiCredits, plus }

/// A bottom-navigation tab contributed by a module.
class ModuleTab {
  const ModuleTab({
    required this.path,
    required this.icon,
    required this.label,
    this.order = 100,
    this.simple = false,
    this.simpleIcon,
    this.simpleLabel,
  });

  final String path;
  final IconData icon;
  final String Function(BuildContext context) label;

  /// Lower comes first in the navigation bar.
  final int order;

  /// Shown in Simple Mode too, which keeps at most three tabs.
  final bool simple;

  /// What the tab looks like in Simple Mode, when it should read differently.
  final IconData? simpleIcon;
  final String Function(BuildContext context)? simpleLabel;
}

/// Every feature plugs into the app through this contract.
///
/// The core never imports a feature: it only knows modules, their routes,
/// tabs and record types. Adding a feature = a new folder + one line in
/// `lib/modules.dart`.
abstract class FeatureModule {
  const FeatureModule();

  String get id;
  List<RouteBase> get routes => const [];

  /// Routes shown over the whole screen, without the bottom navigation.
  List<RouteBase> get fullScreenRoutes => const [];
  List<ModuleTab> get tabs => const [];
  List<RecordTypeDefinition> get recordTypes => const [];
  Entitlement get requires => Entitlement.free;
}
