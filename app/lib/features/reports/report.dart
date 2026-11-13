import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/design/usra_mark_svg.dart';
import '../../core/util/localized_digits.dart';
import '../../core/util/separator.dart';

/// A report to print or share as a PDF (vaccination record, doctor
/// summary), already in its language. Built on the phone from the
/// family's own records; nothing is sent anywhere to make it.
///
/// Kept apart from the PDF drawing so tests can check exactly what goes
/// in, and so the same text can be shown on screen later.
class Report {
  const Report({
    required this.languageCode,
    required this.title,
    required this.appLine,
    required this.generated,
    required this.disclaimer,
    required this.pageLabel,
    this.fields = const [],
    this.sections = const [],
  });

  /// `ar` (drawn right to left) or `en`.
  final String languageCode;
  final String title;

  /// Which app made it, e.g. "Made with the Usra (أسرة) family health app".
  final String appLine;

  /// "Generated on 5 Nov 2026".
  final String generated;

  /// On every page: what this is and isn't.
  final String disclaimer;

  /// "Page 1 of 2".
  final String Function(int page, int total) pageLabel;

  /// Who it's about: name, date of birth...
  final List<ReportField> fields;
  final List<ReportSection> sections;

  bool get rtl => languageCode == 'ar';

  /// Every piece of text in the report, in order (for tests).
  Iterable<String> get allText sync* {
    yield title;
    yield appLine;
    yield generated;
    for (final f in fields) {
      yield f.label;
      yield f.value;
    }
    for (final s in sections) {
      yield* s.allText;
    }
    yield disclaimer;
  }
}

/// "Label: value".
class ReportField {
  const ReportField(this.label, this.value);

  final String label;
  final String value;
}

/// A heading with label/value [fields], a [table], or both. [empty] is
/// shown when there's nothing in either.
class ReportSection {
  const ReportSection({
    required this.id,
    required this.heading,
    this.fields = const [],
    this.columns = const [],
    this.rows = const [],
    this.empty,
    this.note,
  });

  /// Stable name for tests, e.g. `allergies`.
  final String id;
  final String heading;
  final List<ReportField> fields;
  final List<String> columns;
  final List<List<String>> rows;
  final String? empty;

  /// A line under the section, e.g. where percentiles come from.
  final String? note;

  bool get isEmpty => fields.isEmpty && rows.isEmpty;

  Iterable<String> get allText sync* {
    yield heading;
    for (final f in fields) {
      yield f.label;
      yield f.value;
    }
    yield* columns;
    for (final r in rows) {
      yield* r;
    }
    if (isEmpty && empty != null) yield empty!;
    if (note != null) yield note!;
  }
}

/// The embedded fonts' files. Amiri (SIL Open Font License 1.1, licence
/// next to the files in `assets/fonts/amiri/`) has Arabic, with the
/// presentation forms the PDF library shapes Arabic into, and Latin, so one
/// font draws both languages and mixed lines. Kept as bytes so the PDF can
/// be drawn in another isolate.
class ReportFonts {
  const ReportFonts(this.regular, this.bold);

  final ByteData regular;
  final ByteData bold;

  static const regularAsset = 'assets/fonts/amiri/Amiri-Regular.ttf';
  static const boldAsset = 'assets/fonts/amiri/Amiri-Bold.ttf';
  static const licenseAsset = 'assets/fonts/amiri/OFL.txt';

  static Future<ReportFonts> load() async {
    final (regular, bold) = await (
      rootBundle.load(regularAsset),
      rootBundle.load(boldAsset),
    ).wait;
    return ReportFonts(regular, bold);
  }
}

/// Lists the Amiri font's licence on the app's licences page, as the OFL
/// asks of anyone shipping the font.
void registerReportFontLicense() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Amiri',
    ], await rootBundle.loadString(ReportFonts.licenseAsset));
  });
}

const _ink = PdfColor.fromInt(0xFF1F2933);
const _muted = PdfColor.fromInt(0xFF5F6B76);
const _rule = PdfColor.fromInt(0xFFD5DADF);
const _band = PdfColor.fromInt(0xFFF1F4F6);
const _accent = PdfColor.fromInt(0xFF0F766E);

/// An Arabic-script letter (strongly right to left): not Arabic digits or
/// punctuation.
bool _isArabicLetter(int c) =>
    (c >= 0x0620 && c <= 0x064A) ||
    (c >= 0x066E && c <= 0x06D3) ||
    (c >= 0x06FA && c <= 0x06FF) ||
    (c >= 0x0750 && c <= 0x077F) ||
    (c >= 0xFB50 && c <= 0xFDFF) ||
    (c >= 0xFE70 && c <= 0xFEFC);

/// Whether [s] has Arabic letters (base or presentation forms).
bool hasArabic(String s) => s.runes.any(_isArabicLetter);

/// Left-to-right mark, embedding and pop. (Not the isolates U+2066-2069:
/// the font has no glyphs for them.)
const lrm = '\u200E';
const rlm = '\u200F';
const lre = '\u202A';
const pdfPop = '\u202C';

bool _isLtrStart(int c) =>
    (c >= 0x30 && c <= 0x39) ||
    (c >= 0x41 && c <= 0x5A) ||
    (c >= 0x61 && c <= 0x7A) ||
    (c >= 0xC0 && c <= 0x24F) ||
    (c >= 0x0660 && c <= 0x0669);

/// What may end a left-to-right run: a letter or digit, or a closing
/// bracket, percent, degree or plus ("38.5°C", "(70 - 100)", "O+").
bool _isLtrEnd(int c) =>
    _isLtrStart(c) || ')]%°+'.contains(String.fromCharCode(c));

/// Arabic punctuation and line breaks end a run too.
bool _endsRun(int c) =>
    _isArabicLetter(c) || c == 0x060C || c == 0x061B || c == 0x061F || c == 10;

/// For a right-to-left line: wraps each run of Latin letters and digits
/// (with the spaces, dots, units and brackets inside it) in LRM marks, so
/// "بنادول 500 mg", "2.5 ml", "38.5°C" and "(BCG)" keep their order instead
/// of being turned around by the bidi algorithm.
String isolateLtrRuns(String s) {
  final r = s.runes.toList();
  final out = StringBuffer();
  var i = 0;
  while (i < r.length) {
    if (!_isLtrStart(r[i])) {
      out.writeCharCode(r[i]);
      i++;
      continue;
    }
    var end = i;
    for (var j = i; j < r.length && !_endsRun(r[j]); j++) {
      if (_isLtrEnd(r[j])) end = j;
    }
    // An opening bracket right before the run belongs to it.
    var start = i;
    var text = out.toString();
    if (text.endsWith('(') || text.endsWith('[')) {
      text = text.substring(0, text.length - 1);
      start = i - 1;
      out
        ..clear()
        ..write(text);
    }
    out
      ..write(lrm)
      ..write(String.fromCharCodes(r, start, end + 1))
      ..write(lrm);
    i = end + 1;
  }
  return out.toString();
}

/// [s] ready for the PDF library, with the direction to draw it in. The
/// library shapes Arabic only in right-to-left text, so:
/// - no Arabic: as it is, left to right;
/// - Arabic report: right to left (from a leading RLM), Latin runs kept in
///   order
///   ([isolateLtrRuns]);
/// - English report with Arabic in a line (a name, the doctor's words):
///   right to left so the Arabic is shaped, inside a left-to-right
///   embedding so the line still reads left to right.
(String, pw.TextDirection) bidiLine(String s, {required bool rtlReport}) {
  if (!hasArabic(s)) return (s, pw.TextDirection.ltr);
  // A leading mark sets the paragraph's direction: the bidi algorithm takes
  // it from the first strong character, which would otherwise be the
  // LRM of a line starting with a number ("5 أبريل 2026").
  if (rtlReport) return ('$rlm${isolateLtrRuns(s)}', pw.TextDirection.rtl);
  return ('$lrm$lre$s$pdfPop', pw.TextDirection.rtl);
}

/// Characters the font lacks, written with ones it has.
const _substitutes = {
  '≤': '<=',
  '≥': '>=',
  '≠': '!=',
  '−': '-',
  '×': 'x',
  '\u2009': ' ',
  '\u202F': ' ',
  '\u00A0': ' ',
};

/// [s] with every character the font can draw: known stand-ins for a few
/// ([_substitutes]), and anything else (an emoji in a name) left out rather
/// than drawn as an empty box.
String pdfSafe(String s, Map<int, int> glyphs) {
  final out = StringBuffer();
  for (final c in s.runes) {
    final ch = String.fromCharCode(c);
    if (_substitutes[ch] case final sub?) {
      out.write(sub);
    } else if (glyphs.containsKey(c)) {
      out.writeCharCode(c);
    }
  }
  return out.toString();
}

/// Draws [report] as an A4 PDF in a background isolate, so a long report
/// never stalls the screen. [compress] is off only in tests, to read the
/// text back.
Future<Uint8List> renderReportPdf(
  Report report,
  ReportFonts fonts, {
  bool compress = true,
}) => Isolate.run(() {
  useArabicIndicNumbers();
  return drawReportPdf(report, fonts, compress: compress);
});

/// [renderReportPdf] on the calling isolate.
Future<Uint8List> drawReportPdf(
  Report report,
  ReportFonts fonts, {
  bool compress = true,
}) {
  final glyphs = TtfParser(fonts.regular).charToGlyphIndexMap;
  final dir = report.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
  final align = report.rtl ? pw.TextAlign.right : pw.TextAlign.left;
  final doc = pw.Document(
    compress: compress,
    title: report.title,
    // No author, subject or keywords: the file's properties carry nothing
    // about the person.
    creator: 'Usra',
    producer: 'Usra',
    theme: pw.ThemeData.withFont(
      base: pw.Font.ttf(fonts.regular),
      bold: pw.Font.ttf(fonts.bold),
    ),
  );

  pw.Widget text(
    String s, {
    double size = 10,
    bool bold = false,
    PdfColor color = _ink,
  }) {
    final (line, direction) = bidiLine(
      pdfSafe(s, glyphs),
      rtlReport: report.rtl,
    );
    return pw.Text(
      line,
      textDirection: direction,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: size,
        color: color,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    );
  }

  pw.Widget fieldTable(List<ReportField> fields) {
    List<pw.Widget> row(ReportField f) {
      final cells = [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: text(f.label, color: _muted),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: text(f.value),
        ),
      ];
      return report.rtl ? cells.reversed.toList() : cells;
    }

    final widths = {
      0: const pw.FlexColumnWidth(1),
      1: const pw.FlexColumnWidth(2.6),
    };
    return pw.Table(
      columnWidths: report.rtl ? {0: widths[1]!, 1: widths[0]!} : widths,
      children: [for (final f in fields) pw.TableRow(children: row(f))],
    );
  }

  pw.Widget rowTable(List<String> columns, List<List<String>> rows) {
    List<pw.Widget> cells(List<String> values, {bool header = false}) {
      final out = [
        for (final v in values)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
            child: text(v, bold: header, color: header ? _muted : _ink),
          ),
      ];
      return report.rtl ? out.reversed.toList() : out;
    }

    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _rule, width: 0.5),
        bottom: pw.BorderSide(color: _rule, width: 0.5),
      ),
      children: [
        if (columns.isNotEmpty)
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _band),
            children: cells(columns, header: true),
          ),
        for (final r in rows) pw.TableRow(children: cells(r)),
      ],
    );
  }

  final crossStart = pw.CrossAxisAlignment.start;
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
      textDirection: dir,
      crossAxisAlignment: crossStart,
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: text(report.title, size: 9, color: _muted),
            ),
      footer: (context) => pw.Column(
        crossAxisAlignment: crossStart,
        children: [
          pw.Divider(color: _rule, thickness: 0.5),
          text(report.disclaimer, size: 8.5, color: _muted),
          pw.SizedBox(height: 2),
          text(
            '${report.appLine}$partSeparator${report.generated}$partSeparator'
            '${report.pageLabel(context.pageNumber, context.pagesCount)}',
            size: 8,
            color: _muted,
          ),
        ],
      ),
      build: (context) => [
        // Dr. Usra's mark at the start of the title, as a vector.
        pw.Row(
          children: [
            pw.SvgImage(svg: usraMarkSvg, width: 20, height: 20),
            pw.SizedBox(width: 6),
            pw.Expanded(
              child: text(report.title, size: 20, bold: true, color: _accent),
            ),
          ],
        ),
        pw.SizedBox(height: 2),
        text(
          '${report.appLine}$partSeparator${report.generated}',
          color: _muted,
        ),
        pw.SizedBox(height: 10),
        if (report.fields.isNotEmpty) fieldTable(report.fields),
        for (final s in report.sections) ...[
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 2),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _accent)),
            ),
            child: text(s.heading, size: 13, bold: true, color: _accent),
          ),
          pw.SizedBox(height: 4),
          if (s.fields.isNotEmpty) fieldTable(s.fields),
          if (s.rows.isNotEmpty) rowTable(s.columns, s.rows),
          if (s.isEmpty && s.empty != null) text(s.empty!, color: _muted),
          if (s.note != null) ...[
            pw.SizedBox(height: 2),
            text(s.note!, size: 8.5, color: _muted),
          ],
        ],
      ],
    ),
  );
  return doc.save();
}
