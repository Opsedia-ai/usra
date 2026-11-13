import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../modules/feature_module.dart';
import 'tokens.dart';
import 'type.dart';

/// The regular bottom bar: labelled tabs, the selected one on a soft
/// primary-soft pill, and a raised orchid + button in the middle.
class UsraBottomBar extends StatelessWidget {
  const UsraBottomBar({super.key, required this.tabs, required this.selected});

  final List<ModuleTab> tabs;
  final int selected;

  @override
  Widget build(BuildContext context) {
    final c = context.usra;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, tab) in tabs.indexed)
                Expanded(
                  child: tab.action == null
                      ? _Tab(tab: tab, selected: i == selected)
                      : _RaisedAction(tab: tab),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.tab, required this.selected});

  final ModuleTab tab;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.usra;
    final color = selected ? c.primary : c.inkMuted;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: ValueKey('tab-${tab.path}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go(tab.path),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: UsraSizes.touchTarget),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                decoration: ShapeDecoration(
                  color: selected ? c.primarySoft : null,
                  shape: const StadiumBorder(),
                ),
                child: ExcludeSemantics(
                  child: Icon(tab.icon, size: 24, color: color),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tab.label(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: UsraType.label.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaisedAction extends StatelessWidget {
  const _RaisedAction({required this.tab});

  final ModuleTab tab;

  @override
  Widget build(BuildContext context) {
    final c = context.usra;
    // Orchid against the white bar is 2.71:1, so in light a 1 px orchid-ink
    // ring (7.8:1) gives the circle a 3:1 edge. In dark orchid is 5.8:1.
    final light = Theme.of(context).brightness == Brightness.light;
    return Semantics(
      button: true,
      child: InkWell(
        key: ValueKey('tab-action-${tab.path}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => tab.action!(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Container(
                width: UsraSizes.touchTarget + 4,
                height: UsraSizes.touchTarget + 4,
                decoration: ShapeDecoration(
                  color: c.orchid,
                  shape: CircleBorder(
                    side: light
                        ? BorderSide(color: c.orchidInk)
                        : BorderSide.none,
                  ),
                  shadows: c.shadowFloat,
                ),
                child: Icon(Icons.add, size: 28, color: c.onOrchid),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tab.label(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: UsraType.label.copyWith(
                color: c.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
