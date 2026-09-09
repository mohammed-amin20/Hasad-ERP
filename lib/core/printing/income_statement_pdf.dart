import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/reports/income_statement.dart';
import 'report_pdf_helpers.dart';

/// Builds an A4, RTL Income Statement (P&L) PDF in Arabic.
abstract final class IncomeStatementPdf {
  static Future<Uint8List> build({
    required IncomeStatement statement,
    Uint8List? fontBytes,
  }) async {
    final body = <pw.Widget>[
      _summaryRow(statement),
      pw.SizedBox(height: 16),
      _section(
        title: 'الإيرادات',
        icon: '▲',
        color: ReportPdfHelpers.primary,
        rows: statement.revenues
            .map((r) => (
                  code: r.code,
                  name: r.name,
                  amount: ReportPdfHelpers.formatAmount(r.amount),
                ))
            .toList(),
        total: ReportPdfHelpers.formatAmount(statement.revenueTotal),
        totalColor: ReportPdfHelpers.primary,
      ),
      pw.SizedBox(height: 12),
      _section(
        title: 'المصاريف',
        icon: '▼',
        color: ReportPdfHelpers.warning,
        rows: statement.expenses
            .map((e) => (
                  code: e.code,
                  name: e.name,
                  amount: ReportPdfHelpers.formatAmount(e.amount),
                ))
            .toList(),
        total: ReportPdfHelpers.formatAmount(statement.expenseTotal),
        totalColor: ReportPdfHelpers.warning,
      ),
      pw.SizedBox(height: 16),
      _netCard(statement),
    ];

    return ReportPdfHelpers.buildReport(
      fontBytes: fontBytes,
      title: 'قائمة الدخل',
      subtitle: 'من ${ReportPdfHelpers.formatDate(statement.from)} '
          'إلى ${ReportPdfHelpers.formatDate(statement.to)}',
      bodyWidgets: body,
    );
  }

  static pw.Widget _summaryRow(IncomeStatement statement) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: _summaryBox(
            'إجمالي الإيرادات',
            ReportPdfHelpers.formatAmount(statement.revenueTotal),
            ReportPdfHelpers.primary,
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _summaryBox(
            'إجمالي المصاريف',
            ReportPdfHelpers.formatAmount(statement.expenseTotal),
            ReportPdfHelpers.warning,
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _summaryBox(
            'صافي الربح (الخسارة)',
            ReportPdfHelpers.formatAmount(statement.net),
            statement.net >= 0
                ? ReportPdfHelpers.success
                : ReportPdfHelpers.danger,
          ),
        ),
      ],
    );
  }

  static pw.Widget _summaryBox(String label, String amount, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: color == ReportPdfHelpers.primary
            ? const PdfColor.fromInt(0xFFEFF6FF)
            : color == ReportPdfHelpers.warning
                ? const PdfColor.fromInt(0xFFFEF3C7)
                : color == ReportPdfHelpers.success
                    ? const PdfColor.fromInt(0xFFECFDF5)
                    : color == ReportPdfHelpers.danger
                        ? const PdfColor.fromInt(0xFFFEF2F2)
                        : const PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: color, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: ReportPdfHelpers.muted),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            amount,
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

  static pw.Widget _section({
    required String title,
    required String icon,
    required PdfColor color,
    required List<({String code, String name, String amount})> rows,
    required String total,
    required PdfColor totalColor,
  }) {
    final tableRows = <pw.TableRow>[
      ReportPdfHelpers.tableHeaderRow(
        ['رقم الحساب', 'اسم الحساب', 'المبلغ'],
      ),
    ];

    if (rows.isEmpty) {
      tableRows.add(ReportPdfHelpers.emptyRow(3, 'لا توجد بنود'));
    } else {
      for (final row in rows) {
        tableRows.add(ReportPdfHelpers.tableDataRow(
          [row.code, row.name, row.amount],
        ));
      }
      // Total row
      tableRows.add(ReportPdfHelpers.tableDataRow(
        ['', 'الإجمالي', total],
        bold: true,
        colors: [null, totalColor, totalColor],
      ));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(title, icon, color),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder(
            horizontalInside: const pw.BorderSide(
              width: 0.4,
              color: ReportPdfHelpers.border,
            ),
            top: const pw.BorderSide(width: 0.8, color: ReportPdfHelpers.border),
            bottom: const pw.BorderSide(width: 0.8, color: ReportPdfHelpers.border),
          ),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.2),
            1: pw.FlexColumnWidth(3),
            2: pw.FlexColumnWidth(1.5),
          },
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: tableRows,
        ),
      ],
    );
  }

  static pw.Widget _sectionTitle(String title, String icon, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color == ReportPdfHelpers.primary
          ? const PdfColor.fromInt(0xFFEFF6FF)
          : color == ReportPdfHelpers.warning
              ? const PdfColor.fromInt(0xFFFEF3C7)
              : const PdfColor.fromInt(0xFFF8FAFC),
      child: pw.Row(
        children: [
          pw.Text(
            icon,
            style: const pw.TextStyle(fontSize: 14),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _netCard(IncomeStatement statement) {
    final isProfit = statement.net >= 0;
    // Create lighter version of color manually
    final lightColor = isProfit
        ? const PdfColor.fromInt(0xFFECFDF5) // light green
        : const PdfColor.fromInt(0xFFFEF2F2); // light red
    final borderColor = isProfit ? ReportPdfHelpers.success : ReportPdfHelpers.danger;
    final textColor = const PdfColor.fromInt(0xFFFFFFFF);

    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: lightColor,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: borderColor, width: 1.5),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            isProfit ? '✓' : '✗',
            style: pw.TextStyle(
              fontSize: 24,
              color: isProfit ? ReportPdfHelpers.success : ReportPdfHelpers.danger,
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Text(
              'صافي الربح (الخسارة)',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: ReportPdfHelpers.primary,
              ),
            ),
          ),
          pw.Text(
            ReportPdfHelpers.formatAmount(statement.net),
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: borderColor,
            ),
          ),
        ],
      ),
    );
  }
}