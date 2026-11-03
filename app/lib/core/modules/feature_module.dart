import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../follow_ups/follow_up.dart';
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
  });

  final String path;
  final IconData icon;
  final String Function(BuildContext context) label;

  /// Lower comes first in the navigation bar.
  final int order;
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
  List<ModuleTab> get tabs => const [];
  List<RecordTypeDefinition> get recordTypes => const [];

  /// Rules that suggest follow-ups (check-ups, tests, doses) from a person's
  /// age and records.
  List<FollowUpRule> get followUpRules => const [];
  Entitlement get requires => Entitlement.free;
}
