import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

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

/// The embedded fonts. Amiri (SIL Open Font License 1.1, licence next to
/// the files in `assets/fonts/amiri/`) has Arabic, with the presentation
/// forms the PDF library shapes Arabic into, and Latin, so one font draws
/// both languages and mixed lines.
class ReportFonts {
  const ReportFonts(this.regular, this.bold);

  final pw.Font regular;
  final pw.Font bold;

  static const regularAsset = 'assets/fonts/amiri/Amiri-Regular.ttf';
  static const boldAsset = 'assets/fonts/amiri/Amiri-Bold.ttf';
  static const licenseAsset = 'assets/fonts/amiri/OFL.txt';

  static Future<ReportFonts> load() async {
    final (regular, bold) = await (
      rootBundle.load(regularAsset),
      rootBundle.load(boldAsset),
    ).wait;
    return ReportFonts(pw.Font.ttf(regular), pw.Font.ttf(bold));
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

/// Whether [s] has Arabic letters (base or presentation forms).
bool hasArabic(String s) => s.runes.any(
  (c) =>
      (c >= 0x0600 && c <= 0x06FF) ||
      (c >= 0x0750 && c <= 0x077F) ||
      (c >= 0xFB50 && c <= 0xFDFF) ||
      (c >= 0xFE70 && c <= 0xFEFF),
);

/// Draws [report] as an A4 PDF. [compress] is off only in tests, to read
/// the text map back.
Future<Uint8List> renderReportPdf(
  Report report,
  ReportFonts fonts, {
  bool compress = true,
}) {
  final dir = report.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
  final align = report.rtl ? pw.TextAlign.right : pw.TextAlign.left;
  final doc = pw.Document(
    compress: compress,
    title: report.title,
    // No author, subject or keywords: the file's properties carry nothing
    // about the person.
    creator: 'Usra',
    producer: 'Usra',
    theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
  );

  pw.Widget text(
    String s, {
    double size = 10,
    bool bold = false,
    PdfColor color = _ink,
  }) => pw.Text(
    s,
    // The PDF library shapes Arabic only in right-to-left text, so a line
    // with Arabic in it (a name or the doctor's words in an English
    // report) is drawn right to left; Latin-only lines left to right, so
    // "Panadol 500 mg" keeps its order in the Arabic report.
    textDirection: hasArabic(s) ? pw.TextDirection.rtl : pw.TextDirection.ltr,
    textAlign: align,
    style: pw.TextStyle(
      fontSize: size,
      color: color,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    ),
  );

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
            '${report.appLine} · ${report.generated} · '
            '${report.pageLabel(context.pageNumber, context.pagesCount)}',
            size: 8,
            color: _muted,
          ),
        ],
      ),
      build: (context) => [
        text(report.title, size: 20, bold: true, color: _accent),
        pw.SizedBox(height: 2),
        text('${report.appLine} · ${report.generated}', color: _muted),
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
