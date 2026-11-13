import 'package:flutter/material.dart';

import 'tokens.dart';

/// The screen's one main action: a full-width button with 14 corners. Its height, including
/// Simple Mode's, comes from the theme.
class UsraPillButton extends StatelessWidget {
  const UsraPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;

  /// Null shows the button as disabled.
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // Flat, as every button since the November 2026 polish: no shadow.
    return icon == null
        ? FilledButton(onPressed: onPressed, child: Text(label))
        : FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          );
  }
}

enum UsraRoundIconStyle {
  /// White card colour with ink icon, as in Variation B's top bar.
  surface,

  /// The one accent per screen: the + button.
  accent,

  /// Emergency actions.
  urgent,
}

/// A round icon button, 48 or 60 across. [semanticLabel] is required because
/// an icon alone tells a screen reader nothing; it also shows as the tooltip.
class UsraRoundIconButton extends StatelessWidget {
  const UsraRoundIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.large = false,
    this.style = UsraRoundIconStyle.surface,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final bool large;
  final UsraRoundIconStyle style;

  @override
  Widget build(BuildContext context) {
    final c = context.usra;
    final (background, foreground) = switch (style) {
      UsraRoundIconStyle.surface => (c.surface, c.ink),
      UsraRoundIconStyle.accent => (c.orchid, c.onOrchid),
      UsraRoundIconStyle.urgent => (c.urgent, c.onUrgent),
    };
    final designed = large ? UsraSizes.roundIconLarge : UsraSizes.roundIcon;
    // Simple Mode's theme asks for bigger targets; never go below those.
    final themed =
        Theme.of(context).iconButtonTheme.style?.minimumSize
            ?.resolve(const {})
            ?.width ??
        0;
    final size = designed > themed ? designed : themed;
    // A hairline round the white one instead of a shadow; the coloured
    // ones stand out on their own.
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: CircleBorder(
          side: style == UsraRoundIconStyle.surface
              ? BorderSide(color: c.line)
              : BorderSide.none,
        ),
      ),
      child: Tooltip(
        message: semanticLabel,
        excludeFromSemantics: true,
        // Merged, so the label is on the button's own tap node: a screen
        // reader reads "Back, button", not an unlabelled button.
        child: MergeSemantics(
          child: Semantics(
            label: semanticLabel,
            child: IconButton(
              onPressed: onPressed,
              iconSize: large ? 28 : 22,
              icon: Icon(icon),
              style: IconButton.styleFrom(
                fixedSize: Size.square(size),
                minimumSize: Size.square(size),
                backgroundColor: background,
                foregroundColor: foreground,
                disabledBackgroundColor: c.surfaceSoft,
                disabledForegroundColor: c.inkMuted,
                shape: const CircleBorder(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
