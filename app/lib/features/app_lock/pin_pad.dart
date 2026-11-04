import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/preferences.dart';
import '../../core/security/app_lock.dart';
import '../../l10n/app_localizations.dart';

/// Number keys for a 4–6 digit PIN, with dots for what's typed. Bigger in
/// Simple Mode. Clears itself after each [onSubmit].
class PinPad extends ConsumerStatefulWidget {
  const PinPad({
    super.key,
    required this.onSubmit,
    this.enabled = true,
    this.busy = false,
  });

  final void Function(String pin) onSubmit;

  /// Off while a wait after wrong PINs runs.
  final bool enabled;

  /// While a PIN is being checked.
  final bool busy;

  @override
  ConsumerState<PinPad> createState() => _PinPadState();
}

class _PinPadState extends ConsumerState<PinPad> {
  String _pin = '';

  bool get _active => widget.enabled && !widget.busy;

  void _type(String digit) {
    if (!_active || _pin.length >= pinLength) return;
    setState(() => _pin += digit);
  }

  void _delete() {
    if (!_active || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _submit() {
    if (!_active || _pin.length < pinLength) return;
    final pin = _pin;
    setState(() => _pin = '');
    widget.onSubmit(pin);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final simple = ref.watch(simpleModeProvider);
    final key = simple ? 84.0 : 68.0;
    final digitStyle = (simple
        ? Theme.of(context).textTheme.headlineMedium
        : Theme.of(context).textTheme.headlineSmall);
    Widget button(
      String id,
      Widget child,
      VoidCallback? onTap, {
      String? label,
    }) => Padding(
      padding: const EdgeInsets.all(6),
      child: SizedBox.square(
        dimension: key,
        child: Semantics(
          label: label,
          button: true,
          excludeSemantics: label != null,
          child: Material(
            color: UsraColors.surface,
            shape: const CircleBorder(side: BorderSide(color: UsraColors.line)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('pin-$id'),
              onTap: _active ? onTap : null,
              child: Center(child: FittedBox(child: child)),
            ),
          ),
        ),
      ),
    );
    Widget digit(String d) =>
        button(d, Text(d, style: digitStyle), () => _type(d));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          label: l.pinEntered(_pin.length),
          excludeSemantics: true,
          child: Row(
            key: const ValueKey('pin-dots'),
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < pinLength; i++)
                Container(
                  margin: const EdgeInsets.all(6),
                  width: simple ? 20 : 16,
                  height: simple ? 20 : 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length
                        ? UsraColors.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: i < pinLength
                          ? UsraColors.primary
                          : UsraColors.line,
                      width: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l.pinLengthHint,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: UsraColors.textMuted),
        ),
        const SizedBox(height: 12),
        if (widget.busy)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
        // Phone keypads read left to right in Arabic too.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in const [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
              ])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [for (final d in row) digit(d)],
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  button(
                    'delete',
                    const Icon(Icons.backspace_outlined),
                    _delete,
                    label: l.pinDelete,
                  ),
                  digit('0'),
                  button(
                    'ok',
                    Icon(
                      Icons.check,
                      color: _pin.length >= pinLength
                          ? UsraColors.primary
                          : UsraColors.textMuted,
                    ),
                    _submit,
                    label: l.pinOk,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
