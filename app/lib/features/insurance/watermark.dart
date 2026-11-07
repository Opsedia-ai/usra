import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Writes [text] across a photo, for a card leaving the phone. It's replaceable
/// so tests can run without decoding real images.
typedef PhotoWatermarker = Future<Uint8List> Function(
  Uint8List photo,
  String text,
);

final photoWatermarkerProvider = Provider<PhotoWatermarker>(
  (ref) => watermarkPhoto,
);

/// [photo] as a PNG with [text] drawn across it. Throws if the photo can't be
/// read, so the caller doesn't send it unmarked.
Future<Uint8List> watermarkPhoto(Uint8List photo, String text) async {
  final codec = await ui.instantiateImageCodec(photo);
  final frame = await codec.getNextFrame();
  codec.dispose();
  final image = frame.image;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImage(image, Offset.zero, Paint());
  final size = Size(image.width.toDouble(), image.height.toDouble());
  WatermarkPainter(text).paint(canvas, size);
  final picture = recorder.endRecording();
  final out = await picture.toImage(image.width, image.height);
  picture.dispose();
  image.dispose();
  final data = await out.toByteData(format: ui.ImageByteFormat.png);
  out.dispose();
  if (data == null) throw StateError('watermark failed');
  return data.buffer.asUint8List();
}

/// The mark itself: the same on the preview and on the photo sent.
class WatermarkPainter extends CustomPainter {
  WatermarkPainter(this.text, {this.textDirection = TextDirection.rtl});

  final String text;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final fontSize = math.max(14.0, size.shortestSide / 12);
    TextPainter layer(Paint foreground) => TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          foreground: foreground,
        ),
      ),
      textDirection: textDirection,
    )..layout();
    // Readable on a light card or a dark one: white over a dark outline.
    final outline = layer(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = fontSize / 8
        ..color = const Color(0x8C000000),
    );
    final fill = layer(Paint()..color = const Color(0xB3FFFFFF));
    final diagonal = size.longestSide * 1.5;
    final stepY = fontSize * 4;
    final stepX = math.max(outline.width * 1.4, fontSize * 4);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 6);
    var row = 0;
    for (var y = -diagonal / 2; y < diagonal / 2; y += stepY, row++) {
      final start = -diagonal / 2 + (row.isOdd ? stepX / 2 : 0);
      for (var x = start; x < diagonal / 2; x += stepX) {
        outline.paint(canvas, Offset(x, y));
        fill.paint(canvas, Offset(x, y));
      }
    }
    canvas.restore();
    outline.dispose();
    fill.dispose();
  }

  @override
  bool shouldRepaint(WatermarkPainter old) =>
      old.text != text || old.textDirection != textDirection;
}
