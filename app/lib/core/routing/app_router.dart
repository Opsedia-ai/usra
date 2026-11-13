import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../consent.dart';
import '../design/bottom_bar.dart';
import '../design/tokens.dart';
import '../modules/feature_module.dart';
import '../modules/module_registry.dart';
import '../preferences.dart';
import '../providers.dart';

/// A route whose name starts with this draws without the tab bar: it has its
/// own actions and a way back.
const noTabBarRoute = 'no-tab-bar/';

final routerProvider = Provider<GoRouter>((ref) {
  final registry = ref.watch(moduleRegistryProvider);
  final hasTutorial = registry.fullScreenRoutes.any(
    (r) => r is GoRoute && r.path == tutorialPath,
  );
  final hasWelcome = registry.fullScreenRoutes.any(
    (r) => r is GoRoute && r.path == welcomePath,
  );
  final hasConsent = registry.fullScreenRoutes.any(
    (r) => r is GoRoute && r.path == consentPath,
  );
  final router = buildRouter(
    registry,
    // While the first run is pending, every page leads to it. Then, while the
    // Dr. Usra tour is pending, every page leads to that; it goes back to
    // where the user was once finished.
    //
    // Consent comes before any health data is saved: Welcome itself saves
    // nothing, but each step after it (country, About you, restoring a
    // backup) waits for it, and so does every page once the first run is
    // done (an older policy agreed to, or none on record).
    redirect: (_, state) {
      final path = state.uri.path;
      if (hasConsent && path == consentPath) return null;
      final needsConsent = hasConsent && ref.read(consentNeededProvider);
      String toConsent() => Uri(
        path: consentPath,
        queryParameters: {'next': state.uri.toString()},
      ).toString();
      if (hasWelcome) {
        final onWelcome = path.startsWith(welcomePath);
        if (ref.read(onboardingProvider)) {
          if (!onWelcome) return welcomePath;
          return needsConsent && path != welcomePath ? toConsent() : null;
        }
        if (onWelcome) return '/home';
      }
      // Declining an updated policy leaves deleting everything, which needs
      // no consent to reach.
      if (needsConsent && path != consentDeletePath) return toConsent();
      if (!hasTutorial || state.uri.path == tutorialPath) return null;
      if (!ref.read(tutorialProvider)) return null;
      return Uri(
        path: tutorialPath,
        queryParameters: {'from': state.uri.toString()},
      ).toString();
    },
  );
  ref.listen(tutorialProvider, (_, _) => router.refresh());
  ref.listen(onboardingProvider, (_, _) => router.refresh());
  ref.listen(consentNeededProvider, (_, _) => router.refresh());
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

/// The medicine form fills the screen, with its Save at the bottom: a tab tapped
/// by mistake there would lose what was typed.
final _medicineForm = RegExp(r'^/family/[^/]+/medicines/(new|[^/]+/edit)$');

/// Which tab [location] belongs to, or -1 for none. A tab's own path wins.
/// A page another tab shares (a person's records, under Home's `/family`)
/// stays with the tab it was opened from, [lastTab]. A tab of the other
/// bar (More in Simple Mode) lights no tab.
int selectedTab(
  List<ModuleTab> tabs,
  List<ModuleTab> allTabs,
  String location,
  String? lastTab,
) {
  bool under(String path) => location == path || location.startsWith('$path/');
  final own = tabs.indexWhere((t) => t.action == null && under(t.path));
  if (own >= 0) return own;
  final last = tabs.indexWhere((t) => t.path == lastTab);
  final shared = tabs.indexWhere(
    (t) => t.action == null && t.alsoFor.any(under),
  );
  if (shared >= 0) return last >= 0 ? last : shared;
  if (allTabs.any((t) => t.action == null && under(t.path))) return -1;
  return last;
}

/// Bottom navigation built from the modules' tabs; fewer and bigger in
/// Simple Mode.
class AppShell extends ConsumerStatefulWidget {
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
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// The tab last opened by its own path, which shared pages stay under.
  String? _lastTab;

  /// A pushed page isn't in this shell's own `location`, so this asks the
  /// router what's on top. Simple Mode keeps its big buttons everywhere.
  bool _noBar(BuildContext context) {
    final top = GoRouter.of(context).routerDelegate.currentConfiguration.last;
    return top.route.name?.startsWith(noTabBarRoute) ?? false;
  }

  /// Where the page on top is: a pushed page isn't in [AppShell.location].
  String _topLocation(BuildContext context) {
    final config = GoRouter.of(context).routerDelegate.currentConfiguration;
    return config.isEmpty ? widget.location : config.last.matchedLocation;
  }

  @override
  Widget build(BuildContext context) {
    final registry = widget.registry;
    final location = widget.location;
    final simple = ref.watch(simpleModeProvider);
    final tabs = simple ? registry.simpleTabs : registry.tabs;
    final all = [...registry.tabs, ...registry.simpleTabs];
    final top = _topLocation(context);
    final index = selectedTab(tabs, all, top, _lastTab);
    if (index >= 0 &&
        (top == tabs[index].path || top.startsWith('${tabs[index].path}/'))) {
      _lastTab = tabs[index].path;
    }
    return Scaffold(
      body: SafeArea(child: widget.child),
      bottomNavigationBar:
          tabs.length < 2 ||
              _medicineForm.hasMatch(location) ||
              (!simple && _noBar(context))
          ? null
          : !simple
          ? UsraBottomBar(tabs: tabs, selected: index)
          : _noneSelected(
              context,
              none: index < 0,
              child: NavigationBar(
                selectedIndex: index < 0 ? 0 : index,
                onDestinationSelected: (i) => context.go(tabs[i].path),
                destinations: [
                  for (final tab in tabs)
                    NavigationDestination(
                      icon: Icon(tab.simpleIcon ?? tab.icon),
                      label: (tab.simpleLabel ?? tab.label)(context),
                    ),
                ],
              ),
            ),
    );
  }

  /// NavigationBar always has a selected tab; on a page of none, its
  /// selected look is made the same as the others'.
  Widget _noneSelected(
    BuildContext context, {
    required bool none,
    required Widget child,
  }) {
    if (!none) return child;
    final theme = NavigationBarTheme.of(context);
    final muted = context.usra.inkMuted;
    return NavigationBarTheme(
      data: theme.copyWith(
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: muted)),
        labelTextStyle: WidgetStatePropertyAll(
          (theme.labelTextStyle?.resolve(const {}) ??
                  Theme.of(context).textTheme.labelMedium ??
                  const TextStyle())
              .copyWith(color: muted),
        ),
      ),
      child: child,
    );
  }
}
