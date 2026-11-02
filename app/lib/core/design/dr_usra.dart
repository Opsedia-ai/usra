import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Dr. Usra's poses. "caring" is for things that need attention; the
/// character is never shown on emergency screens.
enum DrUsraPose { hello, reminding, celebrating, caring, explaining }

/// Dr. Usra (دكتور أسرة), drawn from the approved character sheet.
class DrUsra extends StatelessWidget {
  const DrUsra({
    super.key,
    this.pose = DrUsraPose.hello,
    this.size = 160,
    this.semanticLabel,
  });

  final DrUsraPose pose;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size * _viewHeight / _viewWidth,
        child: CustomPaint(painter: DrUsraPainter(pose)),
      ),
    );
  }
}

const double _viewWidth = 228;
const double _viewHeight = 222;

class DrUsraPainter extends CustomPainter {
  DrUsraPainter(this.pose);

  final DrUsraPose pose;

  static const _ink = UsraColors.text;
  static const _blue = UsraColors.primary;
  static const _blueDark = UsraColors.primaryDark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _viewWidth, size.height / _viewHeight);
    canvas.translate(14, 0); // the drawing's view box starts at x = -14

    final fill = Paint()..style = PaintingStyle.fill;

    // Shadow.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(100, 212), width: 120, height: 12),
      fill..color = UsraColors.line,
    );

    _drawArms(canvas);

    // Feet.
    fill.color = _blueDark;
    canvas.drawRRect(
      RRect.fromLTRBR(62, 186, 90, 208, const Radius.circular(11)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(110, 186, 138, 208, const Radius.circular(11)),
      fill,
    );

    // Chimney, then the house-shaped body over it.
    canvas.drawRRect(
      RRect.fromLTRBR(136, 34, 152, 62, const Radius.circular(4)),
      fill,
    );
    final body = Path()
      ..moveTo(100, 20)
      ..quadraticBezierTo(106, 20, 111, 24)
      ..lineTo(168, 70)
      ..quadraticBezierTo(176, 77, 176, 87)
      ..lineTo(176, 176)
      ..quadraticBezierTo(176, 196, 156, 196)
      ..lineTo(44, 196)
      ..quadraticBezierTo(24, 196, 24, 176)
      ..lineTo(24, 87)
      ..quadraticBezierTo(24, 77, 32, 70)
      ..lineTo(89, 24)
      ..quadraticBezierTo(94, 20, 100, 20)
      ..close();
    canvas.drawPath(body, fill..color = _blue);

    // Face.
    canvas.drawRRect(
      RRect.fromLTRBR(48, 80, 152, 152, const Radius.circular(34)),
      fill..color = UsraColors.sand,
    );
    _drawFace(canvas);

    // Cheeks.
    fill.color = UsraColors.cheek;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(64, 128), width: 16, height: 10),
      fill,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(136, 128), width: 16, height: 10),
      fill,
    );

    // Heart.
    final heart = Path()
      ..moveTo(100, 186)
      ..cubicTo(88, 177, 84, 171, 84, 166)
      ..arcToPoint(const Offset(100, 164), radius: const Radius.circular(8))
      ..arcToPoint(const Offset(116, 166), radius: const Radius.circular(8))
      ..cubicTo(116, 171, 112, 177, 100, 186)
      ..close();
    canvas.drawPath(heart, fill..color = Colors.white);

    _drawBadge(canvas);
    canvas.restore();
  }

  void _arm(
    Canvas canvas,
    Offset from,
    Offset control,
    Offset to,
    Offset hand,
  ) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = _blue;
    canvas.drawPath(
      Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy),
      stroke,
    );
    canvas.drawCircle(hand, 9, Paint()..color = _blueDark);
  }

  void _drawArms(Canvas canvas) {
    const leftDown = [
      Offset(30, 134),
      Offset(10, 146),
      Offset(16, 168),
      Offset(16, 170),
    ];
    const leftUp = [
      Offset(30, 130),
      Offset(8, 112),
      Offset(14, 88),
      Offset(14, 84),
    ];
    const rightWave = [
      Offset(170, 130),
      Offset(192, 112),
      Offset(186, 88),
      Offset(186, 84),
    ];
    const rightDown = [
      Offset(170, 134),
      Offset(190, 146),
      Offset(184, 168),
      Offset(184, 170),
    ];
    const rightHold = [
      Offset(170, 136),
      Offset(194, 140),
      Offset(196, 120),
      Offset(196, 116),
    ];
    const rightPoint = [
      Offset(170, 128),
      Offset(196, 124),
      Offset(204, 104),
      Offset(205, 100),
    ];

    final (left, right) = switch (pose) {
      DrUsraPose.hello => (leftDown, rightWave),
      DrUsraPose.reminding => (leftDown, rightHold),
      DrUsraPose.celebrating => (leftUp, rightWave),
      DrUsraPose.caring => (leftDown, rightDown),
      DrUsraPose.explaining => (leftDown, rightPoint),
    };
    _arm(canvas, left[0], left[1], left[2], left[3]);
    _arm(canvas, right[0], right[1], right[2], right[3]);

    if (pose == DrUsraPose.reminding) _drawPill(canvas);
  }

  void _drawPill(Canvas canvas) {
    canvas.save();
    canvas.translate(198, 100);
    canvas.rotate(-35 * math.pi / 180);
    canvas.translate(-198, -100);
    const radius = Radius.circular(6.5);
    canvas.drawRRect(
      RRect.fromLTRBR(184, 93, 212, 106, radius),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(184, 93, 199, 106, radius),
      Paint()..color = const Color(0xFFE07B39),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(184, 93, 212, 106, radius),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _ink,
    );
    canvas.restore();
  }

  void _drawFace(Canvas canvas) {
    final ink = Paint()..color = _ink;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = _ink;

    void openEyes({
      double shift = 0,
      double width = 14,
      double height = 18,
      bool highlights = true,
    }) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(80 + shift, 112),
          width: width,
          height: height,
        ),
        ink,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(120 + shift, 112),
          width: width,
          height: height,
        ),
        ink,
      );
      if (highlights) {
        final white = Paint()..color = Colors.white;
        canvas.drawCircle(Offset(82.5 + shift, 108.5), 2.5, white);
        canvas.drawCircle(Offset(122.5 + shift, 108.5), 2.5, white);
      }
    }

    Path curve(
      double x1,
      double y1,
      double cx,
      double cy,
      double x2,
      double y2,
    ) => Path()
      ..moveTo(x1, y1)
      ..quadraticBezierTo(cx, cy, x2, y2);

    switch (pose) {
      case DrUsraPose.hello:
        openEyes();
        canvas.drawPath(curve(88, 130, 100, 142, 112, 130), line);
      case DrUsraPose.reminding:
        openEyes();
        canvas.drawPath(curve(90, 131, 100, 139, 110, 131), line);
      case DrUsraPose.explaining:
        openEyes(shift: 2);
        canvas.drawPath(curve(90, 130, 100, 140, 110, 130), line);
      case DrUsraPose.celebrating:
        canvas.drawPath(curve(72, 113, 80, 104, 88, 113), line);
        canvas.drawPath(curve(112, 113, 120, 104, 128, 113), line);
        canvas.drawPath(curve(86, 127, 100, 146, 114, 127)..close(), ink);
      case DrUsraPose.caring:
        final brow = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..color = _ink;
        canvas.drawLine(const Offset(70, 99), const Offset(88, 103), brow);
        canvas.drawLine(const Offset(130, 99), const Offset(112, 103), brow);
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(80, 114), width: 12, height: 16),
          ink,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: const Offset(120, 114),
            width: 12,
            height: 16,
          ),
          ink,
        );
        canvas.drawPath(curve(92, 135, 100, 130, 108, 135), line);
    }
  }

  void _drawBadge(Canvas canvas) {
    const center = Offset(40, 40);
    final white = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white;
    if (pose == DrUsraPose.celebrating) {
      canvas.drawCircle(center, 16, Paint()..color = Severity.good.foreground);
      canvas.drawPath(
        Path()
          ..moveTo(32, 40)
          ..lineTo(38, 46)
          ..lineTo(48, 34),
        white,
      );
    } else if (pose == DrUsraPose.caring) {
      canvas.drawCircle(
        center,
        16,
        Paint()..color = Severity.actSoon.foreground,
      );
      canvas.drawLine(
        const Offset(40, 31),
        const Offset(40, 43),
        white..strokeWidth = 4,
      );
      canvas.drawCircle(
        const Offset(40, 49),
        2.3,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(DrUsraPainter oldDelegate) => oldDelegate.pose != pose;
}
