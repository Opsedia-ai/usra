import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/dr_usra.dart';
import '../../core/design/status_chip.dart';
import '../../core/design/tokens.dart';
import '../../core/modules/feature_module.dart';
import '../../core/preferences.dart';
import '../../l10n/app_localizations.dart';
import '../account/account_providers.dart';
import '../home/home_module.dart' show severityLabel;

/// The Dr. Usra walkthrough: Simple Mode's elder tour the first time, and from
/// Settings. The regular first run is the onboarding module.
class TutorialModule extends FeatureModule {
  const TutorialModule();

  @override
  String get id => 'tutorial';

  @override
  List<RouteBase> get fullScreenRoutes => [
    GoRoute(
      path: tutorialPath,
      builder: (_, s) => TutorialScreen(from: s.uri.queryParameters['from']),
    ),
  ];
}

class _Page {
  const _Page(this.pose, this.title, this.body, {this.extra});

  final DrUsraPose pose;
  final String title;
  final String body;
  final Widget? extra;
}

/// A few pages with Dr. Usra; a shorter, bigger elder version in Simple Mode.
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key, this.from});

  /// Where to go back to when done.
  final String? from;

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  List<_Page> _content(AppLocalizations l, bool elder) => elder
      ? [
          _Page(
            DrUsraPose.welcome,
            l.tutorialWelcomeTitle,
            l.tutorialElderWelcomeBody,
          ),
          _Page(
            DrUsraPose.explaining,
            l.tutorialElderButtonsTitle,
            l.tutorialElderButtonsBody,
          ),
          _Page(
            DrUsraPose.explaining,
            l.tutorialElderEmergencyTitle,
            l.tutorialElderEmergencyBody,
          ),
        ]
      : [
          _Page(
            DrUsraPose.welcome,
            l.tutorialWelcomeTitle,
            l.tutorialWelcomeBody,
          ),
          _Page(
            DrUsraPose.explaining,
            l.tutorialPrivacyTitle,
            ref.read(supabaseConfigProvider).isConfigured
                ? l.tutorialPrivacyBodyAccount
                : l.tutorialPrivacyBody,
          ),
          _Page(
            DrUsraPose.celebrating,
            l.tutorialFamilyTitle,
            l.tutorialFamilyBody,
          ),
          _Page(
            DrUsraPose.explaining,
            l.tutorialColorsTitle,
            l.tutorialColorsBody,
            extra: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in Severity.values)
                  StatusChip(severity: s, label: severityLabel(l, s)),
              ],
            ),
          ),
          _Page(
            DrUsraPose.explaining,
            l.tutorialEmergencyTitle,
            l.tutorialEmergencyBody,
          ),
        ];

  Future<void> _finish() async {
    await ref.read(tutorialProvider.notifier).finish();
    if (!mounted) return;
    final from = widget.from;
    final next = from == null || from.startsWith(tutorialPath) ? '/home' : from;
    context.go(next);
  }

  void _goTo(int index) => _pages.animateToPage(
    index,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final elder = ref.watch(simpleModeProvider);
    final pages = _content(l, elder);
    final last = _index == pages.length - 1;
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      // The system back button steps back through the pages. On the first
      // page it closes a reopened tour; the first-run one needs Skip, so a
      // stray press can't hide it for good.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_index > 0) {
          _goTo(_index - 1);
        } else if (ref.read(tutorialProvider.notifier).reopened) {
          _finish();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.tutorialStep(_index + 1, pages.length),
                        key: const ValueKey('tutorial-step'),
                        style: text.bodyMedium?.copyWith(
                          color: context.usra.inkMuted,
                        ),
                      ),
                    ),
                    if (!last)
                      TextButton(
                        key: const ValueKey('tutorial-skip'),
                        onPressed: _finish,
                        child: Text(l.tutorialSkip),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    for (final page in pages)
                      _TutorialPage(page: page, elder: elder),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  children: [
                    if (_index > 0) ...[
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey('tutorial-back'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size.fromHeight(elder ? 64 : 52),
                          ),
                          onPressed: () => _goTo(_index - 1),
                          child: Text(l.tutorialBack),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        key: const ValueKey('tutorial-next'),
                        onPressed: last ? _finish : () => _goTo(_index + 1),
                        child: Text(last ? l.tutorialStart : l.tutorialNext),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialPage extends StatelessWidget {
  const _TutorialPage({required this.page, required this.elder});

  final _Page page;
  final bool elder;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Smaller on short screens or with very large text.
              DrUsra(
                pose: page.pose,
                size: (box.maxHeight * 0.35).clamp(96.0, 200.0).toDouble(),
              ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  page.title,
                  style: elder ? text.headlineMedium : text.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                page.body,
                style: (elder ? text.titleLarge : text.bodyLarge)?.copyWith(
                  color: context.usra.ink,
                ),
                textAlign: TextAlign.center,
              ),
              if (page.extra != null) ...[
                const SizedBox(height: 20),
                page.extra!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
