import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/utils/money.dart';

/// Shared helpers for all report PDF builders.
abstract final class ReportPdfHelpers {
  static const cairoAsset = 'assets/fonts/Cairo-Variable.ttf';
  static const primary = PdfColor.fromInt(0xFF2563EB);
  static const success = PdfColor.fromInt(0xFF16A34A);
  static const danger = PdfColor.fromInt(0xFFDC2626);
  static const warning = PdfColor.fromInt(0xFFF59E0B);
  static const secondary = PdfColor.fromInt(0xFF7C3AED);
  static const muted = PdfColor.fromInt(0xFF64748B);
  static const surface = PdfColor.fromInt(0xFFF0F2F5);
  static const border = PdfColor.fromInt(0xFFE2E8F0);
  static const cardBg = PdfColor.fromInt(0xFFFFFFFF);

  /// Load the bundled Cairo variable font.
  static Future<pw.Font> cairoFont([Uint8List? fontBytes]) async {
    final bytes = fontBytes ??
        (await rootBundle.load(cairoAsset)).buffer.asUint8List();
    final data = bytes.buffer.asByteData();
    return pw.Font.ttf(data);
  }

  /// Create a document with Cairo font and RTL direction.
  static Future<pw.Document> createDoc([Uint8List? fontBytes]) async {
    final font = await cairoFont(fontBytes);
    return pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: font,
      ),
    );
  }

  /// Common header for all reports.
  static pw.Widget buildHeader({
    required String title,
    required String subtitle,
    String? dateRange,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: primary,
              ),
            ),
            pw.Text(
              'حصاد',
              style: const pw.TextStyle(fontSize: 14, color: muted),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          subtitle,
          style: const pw.TextStyle(fontSize: 12, color: muted),
        ),
        if (dateRange != null) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            dateRange,
            style: const pw.TextStyle(fontSize: 10, color: muted),
          ),
        ],
        pw.SizedBox(height: 8),
        pw.Divider(height: 1, color: border),
        pw.SizedBox(height: 12),
      ],
    );
  }

  /// Standard table header row.
  static pw.TableRow tableHeaderRow(List<String> headers,
      {PdfColor color = muted}) {
    const style = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
    );
    return pw.TableRow(
      children: [
        for (final header in headers)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Text(header,
                textAlign: pw.TextAlign.end, style: style.copyWith(color: color)),
          ),
      ],
    );
  }

  /// Standard table data row.
  static pw.TableRow tableDataRow(List<String> cells,
      {bool bold = false,
      List<PdfColor?>? colors,
      PdfColor defaultColor = const PdfColor.fromInt(0xFF1E293B)}) {
    final style = pw.TextStyle(
      fontSize: 9,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.TableRow(
      children: List.generate(cells.length, (i) {
        final cellColor = (colors != null && i < colors.length && colors[i] != null)
            ? colors[i]!
            : defaultColor;
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Text(
            cells[i],
            textAlign: pw.TextAlign.end,
            style: style.copyWith(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: cellColor,
            ),
          ),
        );
      }),
    );
  }

  /// Empty state row spanning all columns.
  static pw.TableRow emptyRow(int columnCount, String message) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(20),
          child: pw.Text(
            message,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 10, color: muted),
          ),
        ),
        for (int i = 1; i < columnCount; i++)
          pw.Container(),
      ],
    );
  }

  /// Build a standard A4 RTL page.
  static Future<Uint8List> buildReport({
    required Uint8List? fontBytes,
    required String title,
    required String subtitle,
    String? dateRange,
    required List<pw.Widget> bodyWidgets,
  }) async {
    final doc = await createDoc(fontBytes);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            buildHeader(title: title, subtitle: subtitle, dateRange: dateRange),
            ...bodyWidgets,
            pw.Spacer(),
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                'حصاد — برنامج إدارة الحسابات',
                style: const pw.TextStyle(fontSize: 8, color: muted),
              ),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  /// Format amount with Money.format (returns String like '1,234.56').
  static String formatAmount(int amount) => Money.format(amount);

  /// Format date as yyyy/MM/dd.
  static String formatDate(DateTime? d) => d == null
      ? ''
      : '${d.year.toString().padLeft(4, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.day.toString().padLeft(2, '0')}';
}