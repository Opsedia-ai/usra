import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/buttons.dart';
import '../../core/design/tokens.dart';
import '../../core/util/localized_digits.dart';
import '../../l10n/app_localizations.dart';

/// The steps after Welcome.
const onboardingSteps = 2;

/// A step of the first run: back and how far along, the title and a line
/// under it, whatever the step asks, and its one button at the bottom.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.step,
    required this.title,
    required this.hint,
    required this.children,
    required this.button,
  });

  /// From 1.
  final int step;
  final String title;
  final String hint;
  final List<Widget> children;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.usra;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  UsraRoundIconButton(
                    key: const ValueKey('onboarding-back'),
                    // Mirrors itself, so it points the way back in both languages.
                    icon: Icons.arrow_back,
                    semanticLabel: l.onboardingBack,
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      label: l.onboardingStep(
                        localizedDigits(context, step),
                        localizedDigits(context, onboardingSteps),
                      ),
                      excludeSemantics: true,
                      child: Row(
                        children: [
                          for (var i = 1; i <= onboardingSteps; i++) ...[
                            if (i > 1) const SizedBox(width: 6),
                            Expanded(
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: i <= step ? c.primary : c.line,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(title, style: text.headlineMedium),
              ),
              const SizedBox(height: 4),
              Text(hint, style: text.bodyLarge?.copyWith(color: c.inkMuted)),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: button,
        ),
      ),
    );
  }
}

/// One choice in a list or a pair: a card with a tick when it's chosen.
/// Without [onTap] it's shown but can't be chosen.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.detail,
  });

  final String title;
  final String? detail;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.usra;
    final text = Theme.of(context).textTheme;
    final enabled = onTap != null;
    final radius = BorderRadius.circular(UsraRadius.lg);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      inMutuallyExclusiveGroup: true,
      excludeSemantics: true,
      label: [title, ?detail].join(' · '),
      onTap: onTap,
      child: Material(
        color: selected ? c.primarySoft : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? c.primary : c.lineStrong,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: text.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: enabled ? c.ink : c.inkMuted,
                          ),
                        ),
                        if (detail != null)
                          Text(detail!, style: text.bodySmall),
                      ],
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.check, color: c.primary),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
