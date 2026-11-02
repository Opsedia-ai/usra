import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../modules/feature_module.dart';
import '../modules/module_registry.dart';
import '../providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter(ref.watch(moduleRegistryProvider));
  ref.onDispose(router.dispose);
  return router;
});

/// Builds navigation from whatever modules are registered.
GoRouter buildRouter(ModuleRegistry registry) {
  final tabs = registry.tabs;
  return GoRouter(
    initialLocation: tabs.isEmpty ? '/' : tabs.first.path,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(tabs: tabs, location: state.uri.path, child: child),
        routes: registry.routes,
      ),
    ],
  );
}

/// Bottom navigation built from the modules' tabs.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.tabs,
    required this.location,
    required this.child,
  });

  final List<ModuleTab> tabs;
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final index = tabs.indexWhere((t) => location.startsWith(t.path));
    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: tabs.length < 2
          ? null
          : NavigationBar(
              selectedIndex: index < 0 ? 0 : index,
              onDestinationSelected: (i) => context.go(tabs[i].path),
              destinations: [
                for (final tab in tabs)
                  NavigationDestination(
                    icon: Icon(tab.icon),
                    label: tab.label(context),
                  ),
              ],
            ),
    );
  }
}
