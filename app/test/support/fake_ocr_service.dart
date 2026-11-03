import 'dart:ui';

import 'package:usra/core/ocr/ocr_service.dart';

/// Returns canned text instead of reading the photo.
class FakeOcrService implements OcrService {
  FakeOcrService(this.result);

  /// One block per line, stacked top to bottom; [heights] gives each line's
  /// print size (bigger = more prominent), 20 when not given.
  factory FakeOcrService.lines(List<String> lines, {List<double>? heights}) =>
      FakeOcrService(ocrOf(lines, heights: heights));

  OcrResult result;
  final read = <String>[];
  Object? error;

  @override
  Future<OcrResult> recognise(String imagePath) async {
    read.add(imagePath);
    if (error != null) throw error!;
    return result;
  }

  @override
  Future<void> close() async {}
}

/// Lines laid out top to bottom as an [OcrResult].
OcrResult ocrOf(List<String> lines, {List<double>? heights}) {
  var top = 10.0;
  final blocks = <OcrBlock>[];
  for (var i = 0; i < lines.length; i++) {
    final h = heights?[i] ?? 20;
    final box = Rect.fromLTWH(10, top, 300, h);
    blocks.add(OcrBlock(lines[i], box, [OcrLine(lines[i], box)]));
    top += h + 8;
  }
  return OcrResult(blocks);
}
