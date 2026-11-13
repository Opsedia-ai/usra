import 'package:flutter/widgets.dart';

/// Tapping anywhere that isn't a button or a field closes the keyboard.
///
/// iOS number pads (hours, amounts, readings, the recovery-key check) have
/// no Done key, and Flutter only unfocuses on taps outside a field for a
/// mouse, so on an iPhone the pad otherwise stays up over the Save button.
/// Buttons and fields still get their own taps: the gesture arena gives a
/// tap to the deepest widget that wants it, and this one only wins on
/// empty space.
///
/// Screen readers don't see it: it's only for a finger on empty space, and an
/// unlabelled tap target the size of the screen would be announced as one.
class DismissKeyboardOnTap extends StatelessWidget {
  const DismissKeyboardOnTap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    excludeFromSemantics: true,
    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
    child: child,
  );
}
