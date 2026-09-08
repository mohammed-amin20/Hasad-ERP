import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/salaries/salary_repository.dart';
import '../utils/money.dart';

/// Builds an A4, RTL monthly salary statement PDF in Arabic for one employee.
///
/// Same approach as `StatementPdf`: Cairo embedded from the app bundle and the
/// `pdf` package's Arabic shaping which only runs when the app is compiled
/// with `--dart-define=use_arabic=true` (see AGENTS.md).
abstract final class EmployeeSlipPdf {
  static const _cairoAsset = 'assets/fonts/Cairo-Variable.ttf';
  static const _danger = PdfColor.fromInt(0xFFDC2626);
  static const _primary = PdfColor.fromInt(0xFF2563EB);
  static const _muted = PdfColor.fromInt(0xFF64748B);
  static const _border = PdfColor.fromInt(0xFFE2E8F0);

  /// Renders [statement] for [employeeName] onto PDF bytes.
  ///
  /// [fontBytes] is injectable for tests; defaults to loading the bundled
  /// Cairo variable font.
  static Future<Uint8List> build({
    required EmployeeStatement statement,
    required String employeeName,
    Uint8List? fontBytes,
  }) async {
    final font = fontBytes ??
        (await rootBundle.load(_cairoAsset)).buffer.asUint8List();
    final data = font.buffer.asByteData();

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.ttf(data),
        bold: pw.Font.ttf(data),
      ),
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _header(statement, employeeName),
            pw.SizedBox(height: 14),
            _summaryRow(statement),
            pw.SizedBox(height: 12),
            _monthsTable(statement),
            pw.Spacer(),
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                'حصاد — برنامج إدارة الحسابات',
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  static pw.Widget _header(EmployeeStatement statement, String employeeName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'حركة رواتب الموظف',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: _primary,
              ),
            ),
            pw.Text(
              'حصاد',
              style: const pw.TextStyle(fontSize: 14, color: _muted),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Text('الموظف: $employeeName', style: const pw.TextStyle(fontSize: 12)),
        pw.SizedBox(height: 4),
        pw.Text(
          'الفترة: ${_month(statement.monthFrom)} إلى ${_month(statement.monthTo)}',
          style: const pw.TextStyle(fontSize: 10, color: _muted),
        ),
        pw.SizedBox(height: 8),
        pw.Divider(height: 1, color: _border),
      ],
    );
  }

  static pw.Widget _summaryRow(EmployeeStatement statement) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: _summaryBox('متبقٍ سابق (متأخرات)', statement.opening, _muted),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _summaryBox('إجمالي المتبقي الختامي', statement.closing, _primary),
        ),
      ],
    );
  }

  static pw.Widget _summaryBox(String label, int amount, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: color == _primary
            ? const PdfColor.fromInt(0xFFEFF6FF)
            : const PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _muted)),
          pw.SizedBox(height: 2),
          pw.Text(
            Money.format(amount),
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _monthsTable(EmployeeStatement statement) {
    const headers = [
      'الشهر',
      'الأساس',
      'متأخرات',
      'إضافات',
      'خصومات',
      'الصافي',
      'المدفوع',
      'المتبقي',
    ];
    final rows = <pw.TableRow>[
      pw.TableRow(
        children: [
          for (final h in headers)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 6),
              child: pw.Text(
                h,
                textAlign: pw.TextAlign.end,
                style: const pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: _muted,
                ),
              ),
            ),
        ],
      ),
      if (statement.lines.isEmpty)
        _dataRow(
          cells: ['لا توجد أشهر في هذه الفترة', '', '', '', '', '', '', ''],
        ),
      for (final line in statement.lines)
        _dataRow(
          cells: [
            _month(line.month),
            Money.format(line.baseSalary),
            Money.format(line.arrears),
            Money.format(line.entitlements),
            Money.format(line.deductions),
            Money.format(line.netDue),
            Money.format(line.paid),
            Money.format(line.remaining),
          ],
          remainingColor: line.remaining > 0 ? _danger : null,
        ),
    ];

    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: const pw.BorderSide(width: 0.4, color: _border),
        top: const pw.BorderSide(width: 0.8, color: PdfColor.fromInt(0xFF94A3B8)),
        bottom: const pw.BorderSide(
          width: 0.8,
          color: PdfColor.fromInt(0xFF94A3B8),
        ),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.5),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(1),
        4: pw.FlexColumnWidth(1),
        5: pw.FlexColumnWidth(1),
        6: pw.FlexColumnWidth(1),
        7: pw.FlexColumnWidth(1),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: rows,
    );
  }

  static pw.TableRow _dataRow({
    required List<String> cells,
    PdfColor? remainingColor,
  }) {
    return pw.TableRow(
      children: [
        for (var i = 0; i < cells.length; i++)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 5),
            child: pw.Text(
              cells[i],
              textAlign: pw.TextAlign.end,
              style: pw.TextStyle(
                fontSize: 8,
                color: (i == cells.length - 1 && remainingColor != null)
                    ? remainingColor
                    : null,
                fontWeight: i == cells.length - 1
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
            ),
          ),
      ],
    );
  }

  static String _month(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}/${d.month.toString().padLeft(2, '0')}';
}