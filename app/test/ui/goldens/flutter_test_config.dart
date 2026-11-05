import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden tests draw real letters and icons (Flutter tests otherwise draw
/// every glyph as a box): Amiri, the app's own Arabic and Latin PDF font,
/// stands in for the phone's system font, plus the Material icons.
///
/// The images are made and compared on Linux only (CI's `goldens` job), as
/// text renders slightly differently on each OS. Elsewhere the comparison
/// is skipped; see test/ui/README.md to update them.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 'FlutterTest' is the font of text with no family set (e.g. buttons).
  for (final family in ['Roboto', 'FlutterTest']) {
    await _loadFont(family, [
      'assets/fonts/amiri/Amiri-Regular.ttf',
      'assets/fonts/amiri/Amiri-Bold.ttf',
    ]);
  }
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    await _loadFont('MaterialIcons', [
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]);
  }
  if (!Platform.isLinux && !autoUpdateGoldenFiles) {
    goldenFileComparator = _SkipComparator(
      Uri.parse('${Directory.current.path}/test/ui/goldens/x_test.dart'),
    );
  }
  await testMain();
}

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// Not on Linux: goldens are only checked where they were made.
class _SkipComparator extends LocalFileComparator {
  _SkipComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    markTestSkipped('Goldens are compared on Linux only ($golden)');
    return true;
  }
}
