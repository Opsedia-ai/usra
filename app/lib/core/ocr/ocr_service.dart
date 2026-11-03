import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as mlkit;

/// One line of recognised text and where it is in the photo, in the
/// photo's pixels (after its orientation is applied).
class OcrLine {
  const OcrLine(this.text, this.box);

  final String text;
  final Rect box;
}

/// A paragraph-like group of [lines], as the recogniser found it.
class OcrBlock {
  const OcrBlock(this.text, this.box, this.lines);

  final String text;
  final Rect box;
  final List<OcrLine> lines;
}

/// The text read from one photo.
class OcrResult {
  const OcrResult(this.blocks);

  static const empty = OcrResult([]);

  final List<OcrBlock> blocks;

  /// Every line, top to bottom block by block.
  List<OcrLine> get lines => [for (final b in blocks) ...b.lines];

  String get text => blocks.map((b) => b.text).join('\n');

  bool get isEmpty => blocks.isEmpty;
}

/// Reads printed text from a photo. Shared by every feature that scans
/// something; nothing leaves the phone.
abstract interface class OcrService {
  /// Reads the photo at [imagePath]. Returns [OcrResult.empty] when there's
  /// no text; throws if the photo can't be read.
  Future<OcrResult> recognise(String imagePath);

  Future<void> close();
}

/// Google ML Kit on the phone, Latin script only: it reads printed brand
/// names and strengths, not Arabic and not handwriting.
class MlKitOcrService implements OcrService {
  final _recognizer = mlkit.TextRecognizer(
    script: mlkit.TextRecognitionScript.latin,
  );

  @override
  Future<OcrResult> recognise(String imagePath) async {
    final text = await _recognizer.processImage(
      mlkit.InputImage.fromFilePath(imagePath),
    );
    return OcrResult([
      for (final b in text.blocks)
        OcrBlock(b.text, b.boundingBox, [
          for (final l in b.lines) OcrLine(l.text, l.boundingBox),
        ]),
    ]);
  }

  @override
  Future<void> close() => _recognizer.close();
}

/// The text recogniser, closed (freeing the model) once no screen watches
/// it. Overridden in tests.
final ocrServiceProvider = Provider.autoDispose<OcrService>((ref) {
  final service = MlKitOcrService();
  ref.onDispose(service.close);
  return service;
});
