import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'tokens.dart';

/// A thin bar with "Done" above an iPhone's number pad.
///
/// iOS number and phone pads have no return key, so the pad stays up over
/// the form's Save (end-to-end test #9: growth, temperature, spending, dose
/// amounts). While such a field has focus, this bar sits on the keyboard and
/// closes it. The pages below are told the keyboard is that much taller, so
/// they scroll the field and their buttons above the bar too. Android's
/// number pads have their own Done key, so nothing shows there.
class KeyboardDoneBar extends StatefulWidget {
  const KeyboardDoneBar({super.key, required this.child});

  final Widget child;

  /// The bar's height, without the system's text scaling.
  static const height = 48.0;

  @override
  State<KeyboardDoneBar> createState() => _KeyboardDoneBarState();
}

class _KeyboardDoneBarState extends State<KeyboardDoneBar> {
  var _numberField = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_focusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_focusChanged);
    super.dispose();
  }

  void _focusChanged() {
    final now = _isNumberField(FocusManager.instance.primaryFocus?.context);
    if (now != _numberField && mounted) setState(() => _numberField = now);
  }

  static bool _isNumberField(BuildContext? context) {
    final field = context?.findAncestorWidgetOfExactType<EditableText>();
    if (field == null) return false;
    final type = field.keyboardType.index;
    return type == TextInputType.number.index ||
        type == TextInputType.phone.index;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final show =
        _numberField &&
        keyboard > 0 &&
        defaultTargetPlatform == TargetPlatform.iOS;
    final c = context.usra;
    // Always the same shape above the app, so showing the bar never rebuilds
    // the pages (and loses what was typed).
    return Stack(
      fit: StackFit.passthrough,
      textDirection: Directionality.maybeOf(context) ?? TextDirection.rtl,
      children: [
        MediaQuery(
          data: show
              ? media.copyWith(
                  viewInsets: media.viewInsets.copyWith(
                    bottom: keyboard + KeyboardDoneBar.height,
                  ),
                )
              : media,
          child: widget.child,
        ),
        if (show)
          Positioned(
            left: 0,
            right: 0,
            bottom: keyboard,
            height: KeyboardDoneBar.height,
            child: Material(
              key: const ValueKey('keyboard-done-bar'),
              color: c.surface,
              shape: Border(top: BorderSide(color: c.line)),
              child: MediaQuery.withNoTextScaling(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    key: const ValueKey('keyboard-done'),
                    onPressed: () =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    child: Text(
                      AppLocalizations.of(context).keyboardDone,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
