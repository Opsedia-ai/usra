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
            : ExcludeSemantics(child: Icon(icon, size: 20, color: c.inkMuted)));
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
