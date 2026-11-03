import 'package:go_router/go_router.dart';

import '../records/record_type.dart';
import 'feature_module.dart';

/// Collects routes, tabs and record types from all feature modules.
class ModuleRegistry {
  ModuleRegistry(List<FeatureModule> modules)
    : modules = List.unmodifiable(modules),
      recordTypes = RecordTypeRegistry([
        for (final m in modules) ...m.recordTypes,
      ]) {
    final ids = <String>{};
    for (final module in modules) {
      if (!ids.add(module.id)) {
        throw ArgumentError('Duplicate module id: ${module.id}');
      }
    }
  }

  final List<FeatureModule> modules;
  final RecordTypeRegistry recordTypes;

  List<RouteBase> get routes => [for (final m in modules) ...m.routes];

  List<RouteBase> get fullScreenRoutes => [
    for (final m in modules) ...m.fullScreenRoutes,
  ];

  List<ModuleTab> get tabs =>
      [for (final m in modules) ...m.tabs]
        ..sort((a, b) => a.order.compareTo(b.order));

  /// Simple Mode keeps this many tabs at most.
  static const maxSimpleTabs = 3;

  /// The tabs shown in Simple Mode.
  List<ModuleTab> get simpleTabs =>
      tabs.where((t) => t.simple).take(maxSimpleTabs).toList();

  /// Modules the user can use with what they own.
  List<FeatureModule> availableWith(Set<Entitlement> owned) => [
    for (final m in modules)
      if (m.requires == Entitlement.free || owned.contains(m.requires)) m,
  ];
}
