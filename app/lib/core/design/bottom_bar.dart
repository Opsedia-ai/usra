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
      label: tab.label(context),
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
              _BarLabel(
                tab.label(context),
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
      label: tab.label(context),
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
            _BarLabel(
              tab.label(context),
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

/// Most a tab label grows with the phone's text size. Five labels share a
/// 320 px bar, so beyond this they'd be cut and run together; like the
/// system tab bars, they stop growing here. The page's own text keeps
/// growing.
const barLabelMaxScale = 1.3;

/// From this text size on, the bar shows icons only: the labels would have
/// to shrink below a readable size. Screen readers still read every label,
/// from the tab's own semantics.
const barIconsOnlyScale = 1.6;

/// A tab's label: grows up to [barLabelMaxScale], then shrinks to fit its
/// slot instead of being cut off; hidden at [barIconsOnlyScale] and above.
/// Screen readers get the label from the tab, not from this text.
class _BarLabel extends StatelessWidget {
  const _BarLabel(this.label, {required this.style});

  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    if (scaler.scale(1) >= barIconsOnlyScale) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: style,
            textScaler: scaler.clamp(maxScaleFactor: barLabelMaxScale),
          ),
        ),
      ),
    );
  }
}
