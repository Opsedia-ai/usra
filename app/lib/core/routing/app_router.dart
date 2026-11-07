import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/bottom_bar.dart';
import '../modules/module_registry.dart';
import '../preferences.dart';
import '../providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final registry = ref.watch(moduleRegistryProvider);
  final hasTutorial = registry.fullScreenRoutes.any(
    (r) => r is GoRoute && r.path == tutorialPath,
  );
  final router = buildRouter(
    registry,
    // While the Dr. Usra tour is pending, every page leads to it; it goes
    // back to where the user was once finished.
    redirect: (_, state) {
      if (!hasTutorial || state.uri.path == tutorialPath) return null;
      if (!ref.read(tutorialProvider)) return null;
      return Uri(
        path: tutorialPath,
        queryParameters: {'from': state.uri.toString()},
      ).toString();
    },
  );
  ref.listen(tutorialProvider, (_, _) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});

/// Builds navigation from whatever modules are registered.
GoRouter buildRouter(ModuleRegistry registry, {GoRouterRedirect? redirect}) {
  final tabs = registry.tabs;
  return GoRouter(
    initialLocation: tabs.isEmpty ? '/' : tabs.first.path,
    redirect: redirect,
    routes: [
      ...registry.fullScreenRoutes,
      ShellRoute(
        builder: (context, state, child) => AppShell(
          registry: registry,
          location: state.uri.path,
          child: child,
        ),
        routes: registry.routes,
      ),
    ],
  );
}

/// Bottom navigation built from the modules' tabs; fewer and bigger in
/// Simple Mode.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.registry,
    required this.location,
    required this.child,
  });

  final ModuleRegistry registry;
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simple = ref.watch(simpleModeProvider);
    final tabs = simple ? registry.simpleTabs : registry.tabs;
    final index = tabs.indexWhere(
      (t) =>
          t.action == null &&
          [t.path, ...t.alsoFor].any((p) => location.startsWith(p)),
    );
    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: tabs.length < 2
          ? null
          : !simple
          ? UsraBottomBar(tabs: tabs, selected: index < 0 ? 0 : index)
          : NavigationBar(
              selectedIndex: index < 0 ? 0 : index,
              onDestinationSelected: (i) => context.go(tabs[i].path),
              destinations: [
                for (final tab in tabs)
                  NavigationDestination(
                    icon: Icon(simple ? tab.simpleIcon ?? tab.icon : tab.icon),
                    label: (simple ? tab.simpleLabel ?? tab.label : tab.label)(
                      context,
                    ),
                  ),
              ],
            ),
    );
  }
}
