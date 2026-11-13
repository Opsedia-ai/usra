import 'package:flutter/material.dart';

import 'tokens.dart';
import 'type.dart';

/// Rows in a [UsraListCard] are at least this tall (more in Simple Mode).
const listRowMinHeight = 56.0;

/// One row of a grouped list: an icon or dot, a title, an optional one-line
/// subtitle, and a chevron or a small action at the end. Follows the
/// November 2026 polish: plain text, muted icons, hairlines between rows.
class UsraListRow extends StatelessWidget {
  const UsraListRow({
    super.key,
    required this.title,
    this.leading,
    this.icon,
    this.iconTint,
    this.subtitle,
    this.subtitleText,
    this.trailing,
    this.onTap,
    this.emphasized = false,
    this.semanticLabel,
  });

  final String title;

  /// Shown at the start instead of [icon], such as a [StatusDot].
  final Widget? leading;

  /// A muted line icon at the start.
  final IconData? icon;

  /// Draws [icon] in a small box: neutral, or tinted by the section's
  /// meaning (see [IconTint]). Null keeps the bare muted icon.
  final IconTint? iconTint;

  /// A custom second line, such as a [StatusDotText].
  final Widget? subtitle;

  /// A plain muted second line.
  final String? subtitleText;

  /// Replaces the chevron, such as a switch or a text action.
  final Widget? trailing;

  final VoidCallback? onTap;

  /// Bolder title, for rows that need attention.
  final bool emphasized;

  /// What a screen reader says for the whole row, when the visible words
  /// aren't enough.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.usra;
    final minHeight =
        Theme.of(context).listTileTheme.minTileHeight ?? listRowMinHeight;
    final start =
        leading ??
        (icon == null
            ? null
            : iconTint == null
            ? ExcludeSemantics(child: Icon(icon, size: 20, color: c.inkMuted))
            : IconBox(icon: icon!, tint: iconTint, size: 32));
    final end =
        trailing ??
        (onTap == null
            ? null
            : ExcludeSemantics(
                child: Icon(Icons.chevron_right, size: 20, color: c.inkMuted),
              ));
    final second =
        subtitle ??
        (subtitleText == null
            ? null
            : Text(
                subtitleText!,
                style: UsraType.label.copyWith(
                  color: c.inkMuted,
                  fontWeight: FontWeight.w400,
                ),
              ));
    Widget row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: UsraSpacing.s4,
          vertical: UsraSpacing.s2,
        ),
        child: Row(
          children: [
            if (start != null) ...[
              start,
              const SizedBox(width: UsraSpacing.s3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: UsraType.body.copyWith(
                      color: c.ink,
                      height: 24 / 16,
                      fontWeight: emphasized
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  ?second,
                ],
              ),
            ),
            if (end != null) ...[const SizedBox(width: UsraSpacing.s3), end],
          ],
        ),
      ),
    );
    if (semanticLabel != null) {
      row = Semantics(
        label: semanticLabel,
        child: ExcludeSemantics(child: row),
      );
    }
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// A card holding [UsraListRow]s, with hairlines between them. Rows bring
/// their own 16 side padding, so their tap area reaches the card's edges.
class UsraListCard extends StatelessWidget {
  const UsraListCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final line = context.usra.line;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: UsraSpacing.s4),
                child: Divider(height: 1, thickness: 1, color: line),
              ),
            child,
          ],
        ],
      ),
    );
  }
}

/// The muted label over a group of rows, such as "العيلة" on More.
class UsraGroupLabel extends StatelessWidget {
  const UsraGroupLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: UsraSpacing.s3, bottom: UsraSpacing.s2),
    child: Semantics(
      header: true,
      child: Text(
        label,
        style: UsraType.label.copyWith(
          color: context.usra.inkMuted,
          fontWeight: FontWeight.w400,
        ),
      ),
    ),
  );
}

/// A section's icon-box colours, by meaning (brand touch, 13 Nov 2026):
/// vaccines and pregnancy orchid, medicines sky, everything else neutral.
/// Never for a box that shows a status: those keep [IconBox.color], such as
/// amber for someone who's unwell.
enum IconTint {
  neutral,
  vaccines,
  medicines,
  pregnancy;

  /// The box's fill.
  Color fillIn(UsraColors c) => switch (this) {
    IconTint.neutral => c.surfaceSoft,
    IconTint.vaccines || IconTint.pregnancy => c.orchidSoft,
    IconTint.medicines => c.skySoft,
  };

  /// The icon's colour on [fillIn]: 3:1 or more in both themes.
  Color inkIn(UsraColors c) => switch (this) {
    IconTint.neutral => c.inkMuted,
    IconTint.vaccines || IconTint.pregnancy => c.orchidInk,
    IconTint.medicines => c.skyInk,
  };
}

/// A 36 square with 10 corners holding a muted icon, at the start of a card
/// or row. [color] tints it for a status, such as amber for someone who's
/// unwell; [tint] colours it by the section's meaning instead.
class IconBox extends StatelessWidget {
  const IconBox({
    super.key,
    required this.icon,
    this.color,
    this.tint,
    this.size = 36,
  });

  final IconData icon;
  final Color? color;
  final IconTint? tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.usra;
    final status = color;
    final section = tint;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: status != null
              ? status.withValues(alpha: 0.14)
              : section?.fillIn(c) ?? c.surfaceSoft,
          borderRadius: BorderRadius.circular(UsraRadius.iconBox),
        ),
        child: Icon(
          icon,
          size: size * 5 / 9,
          color: status ?? section?.inkIn(c) ?? c.inkMuted,
        ),
      ),
    );
  }
}
