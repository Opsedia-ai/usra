import 'dart:convert';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:usra/features/reports/report.dart';

/// Draws [line] alone, as the report renderer does (one font, [bidiLine]),
/// in an uncompressed PDF, and reads back what a reader sees from left to
/// right: each drawn word's characters through the font's ToUnicode map,
/// words ordered by their x position. Arabic letters (any form) come back
/// as "ع", so tests compare the order of runs, not the shaping.
Future<String> visualLine(
  String line,
  ReportFonts fonts, {
  required bool rtlReport,
}) async {
  final glyphs = TtfParser(fonts.regular).charToGlyphIndexMap;
  final (text, direction) = bidiLine(
    pdfSafe(line, glyphs),
    rtlReport: rtlReport,
  );
  final doc = pw.Document(
    compress: false,
    theme: pw.ThemeData.withFont(base: pw.Font.ttf(fonts.regular)),
  );
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => pw.Text(text, textDirection: direction),
    ),
  );
  final pdf = latin1.decode(await doc.save());

  final unicode = <int, int>{};
  final cmap = RegExp(r'beginbfchar(.*?)endbfchar', dotAll: true);
  for (final block in cmap.allMatches(pdf)) {
    for (final m in RegExp(
      r'<([0-9A-F]{4})> <([0-9A-F]{4})>',
    ).allMatches(block[1]!)) {
      unicode[int.parse(m[1]!, radix: 16)] = int.parse(m[2]!, radix: 16);
    }
  }
  final words = <(double, String)>[];
  final op = RegExp(
    r'BT /F\d+ [\d.]+ Tf [\d.-]+ Tc ([\d.-]+) [\d.-]+ Td \[(.*?)\]TJ ET',
  );
  for (final m in op.allMatches(pdf)) {
    final chars = StringBuffer();
    for (final hex in RegExp(r'<([0-9a-fA-F]+)>').allMatches(m[2]!)) {
      final h = hex[1]!;
      for (var i = 0; i + 4 <= h.length; i += 4) {
        final c = unicode[int.parse(h.substring(i, i + 4), radix: 16)] ?? 0;
        final arabic =
            (c >= 0x0620 && c <= 0x06FF) || (c >= 0xFB50 && c <= 0xFEFC);
        if (c == 0x200E || c == 0x202A || c == 0x202C || c == 0) continue;
        chars.write(arabic ? 'ع' : String.fromCharCode(c));
      }
    }
    words.add((double.parse(m[1]!), chars.toString()));
  }
  words.sort((a, b) => a.$1.compareTo(b.$1));
  return words
      .map((w) => w.$2.replaceAll(RegExp('ع+'), 'ع'))
      .where((w) => w.isNotEmpty)
      .join(' ');
}
