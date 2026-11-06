import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'auth_gateway.dart';

/// A sign-in button in the brand's own colours, as Apple's and Google's
/// button guidelines ask: black or white with the Apple logo, white or dark
/// grey with the four-colour G. Grows with the text size (Simple Mode).
class SignInButton extends StatelessWidget {
  const SignInButton({
    super.key,
    required this.method,
    required this.onPressed,
  });

  final SignInMethod method;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final iconSize = MediaQuery.textScalerOf(context).scale(20);
    final (background, foreground, border) = switch ((method, dark)) {
      (SignInMethod.apple, false) => (Colors.black, Colors.white, Colors.black),
      (SignInMethod.apple, true) => (Colors.white, Colors.black, Colors.white),
      (SignInMethod.google, false) => (
        Colors.white,
        const Color(0xFF1F1F1F),
        const Color(0xFF747775),
      ),
      (SignInMethod.google, true) => (
        const Color(0xFF131314),
        const Color(0xFFE3E3E3),
        const Color(0xFF8E918F),
      ),
    };
    return OutlinedButton.icon(
      key: ValueKey('account-sign-in-${method.name}'),
      style: OutlinedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        // Disabled only while another sign-in runs; the brand colours stay.
        disabledBackgroundColor: background.withValues(alpha: 0.6),
        disabledForegroundColor: foreground.withValues(alpha: 0.6),
        side: BorderSide(color: border),
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onPressed: onPressed,
      icon: switch (method) {
        SignInMethod.apple => Icon(Icons.apple, size: iconSize),
        SignInMethod.google => SizedBox.square(
          dimension: iconSize,
          child: const CustomPaint(painter: _GoogleMarkPainter()),
        ),
      },
      label: Text(switch (method) {
        SignInMethod.apple => l.accountSignInWithApple,
        SignInMethod.google => l.accountSignInWithGoogle,
      }, textAlign: TextAlign.center),
    );
  }
}

/// Google's standard "G", from its sign-in branding guidelines (48×48).
class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  static final _red = Path()
    ..moveTo(24.00, 9.50)
    ..cubicTo(27.54, 9.50, 30.71, 10.72, 33.21, 13.10)
    ..lineTo(40.06, 6.25)
    ..cubicTo(35.90, 2.38, 30.47, 0.00, 24.00, 0.00)
    ..cubicTo(14.62, 0.00, 6.51, 5.38, 2.56, 13.22)
    ..lineTo(10.54, 19.41)
    ..cubicTo(12.43, 13.72, 17.74, 9.50, 24.00, 9.50)
    ..close();
  static final _blue = Path()
    ..moveTo(46.98, 24.55)
    ..cubicTo(46.98, 22.98, 46.83, 21.46, 46.60, 20.00)
    ..lineTo(24.00, 20.00)
    ..lineTo(24.00, 29.02)
    ..lineTo(36.94, 29.02)
    ..cubicTo(36.36, 31.98, 34.68, 34.50, 32.16, 36.20)
    ..lineTo(39.89, 42.20)
    ..cubicTo(44.40, 38.02, 46.98, 31.84, 46.98, 24.55)
    ..close();
  static final _yellow = Path()
    ..moveTo(10.53, 28.59)
    ..cubicTo(10.05, 27.14, 9.77, 25.60, 9.77, 24.00)
    ..cubicTo(9.77, 22.40, 10.04, 20.86, 10.53, 19.41)
    ..lineTo(2.55, 13.22)
    ..cubicTo(0.92, 16.46, 0.00, 20.12, 0.00, 24.00)
    ..cubicTo(0.00, 27.88, 0.92, 31.54, 2.56, 34.78)
    ..lineTo(10.53, 28.59)
    ..close();
  static final _green = Path()
    ..moveTo(24.00, 48.00)
    ..cubicTo(30.48, 48.00, 35.93, 45.87, 39.89, 42.19)
    ..lineTo(32.16, 36.19)
    ..cubicTo(30.01, 37.64, 27.24, 38.49, 24.00, 38.49)
    ..cubicTo(17.74, 38.49, 12.43, 34.27, 10.53, 28.58)
    ..lineTo(2.55, 34.77)
    ..cubicTo(6.51, 42.62, 14.62, 48.00, 24.00, 48.00)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48);
    final paint = Paint()..isAntiAlias = true;
    canvas
      ..drawPath(_red, paint..color = const Color(0xFFEA4335))
      ..drawPath(_blue, paint..color = const Color(0xFF4285F4))
      ..drawPath(_yellow, paint..color = const Color(0xFFFBBC05))
      ..drawPath(_green, paint..color = const Color(0xFF34A853));
  }

  @override
  bool shouldRepaint(_GoogleMarkPainter oldDelegate) => false;
}
