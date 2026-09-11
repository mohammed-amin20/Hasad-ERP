import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/reports/balance_sheet.dart';
import 'report_pdf_helpers.dart';

/// Builds an A4, RTL Balance Sheet PDF in Arabic.
abstract final class BalanceSheetPdf {
  static Future<Uint8List> build({
    required BalanceSheet sheet,
    Uint8List? fontBytes,
  }) async {
    final body = <pw.Widget>[
      _summaryRow(sheet),
      pw.SizedBox(height: 16),
      _section(
        title: 'الأصول',
        icon: '[أ]',
        color: ReportPdfHelpers.success,
        rows: sheet.assets
            .map(
              (a) => (
                code: a.code,
                name: a.name,
                amount: ReportPdfHelpers.formatAmount(a.amount),
              ),
            )
            .toList(),
        total: ReportPdfHelpers.formatAmount(sheet.assetsTotal),
        totalColor: ReportPdfHelpers.success,
      ),
      pw.SizedBox(height: 12),
      _section(
        title: 'الخصوم',
        icon: '[خ]',
        color: ReportPdfHelpers.danger,
        rows: sheet.liabilities
            .map(
              (l) => (
                code: l.code,
                name: l.name,
                amount: ReportPdfHelpers.formatAmount(l.amount),
              ),
            )
            .toList(),
        total: ReportPdfHelpers.formatAmount(sheet.liabilitiesTotal),
        totalColor: ReportPdfHelpers.danger,
      ),
      pw.SizedBox(height: 12),
      _section(
        title: 'حقوق الملكية',
        icon: '[ح]',
        color: ReportPdfHelpers.secondary,
        rows: [
          ...sheet.equity.map(
            (e) => (
              code: e.code,
              name: e.name,
              amount: ReportPdfHelpers.formatAmount(e.amount),
            ),
          ),
          (
            code: '0001',
            name: 'صافي الدخل حتى اليوم',
            amount: ReportPdfHelpers.formatAmount(sheet.netIncomeYtd),
          ),
        ],
        total: ReportPdfHelpers.formatAmount(sheet.equityTotal),
        totalColor: ReportPdfHelpers.secondary,
      ),
      pw.SizedBox(height: 16),
      _checkCard(sheet),
    ];

    return ReportPdfHelpers.buildReport(
      fontBytes: fontBytes,
      title: 'الميزانية العمومية',
      subtitle: 'كالتاريخ ${ReportPdfHelpers.formatDate(sheet.asOf)}',
      bodyWidgets: body,
    );
  }

  static pw.Widget _summaryRow(BalanceSheet sheet) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: _summaryBox(
            'إجمالي الأصول',
            ReportPdfHelpers.formatAmount(sheet.assetsTotal),
            ReportPdfHelpers.success,
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _summaryBox(
            'إجمالي الخصوم',
            ReportPdfHelpers.formatAmount(sheet.liabilitiesTotal),
            ReportPdfHelpers.danger,
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _summaryBox(
            'إجمالي حقوق الملكية',
            ReportPdfHelpers.formatAmount(sheet.equityTotal),
            ReportPdfHelpers.secondary,
          ),
        ),
      ],
    );
  }

  static pw.Widget _summaryBox(String label, String amount, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: color == ReportPdfHelpers.success
            ? const PdfColor.fromInt(0xFFECFDF5)
            : color == ReportPdfHelpers.danger
            ? const PdfColor.fromInt(0xFFFEF2F2)
            : color == ReportPdfHelpers.secondary
            ? const PdfColor.fromInt(0xFFF5F0FF)
            : const PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: color, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 9,
              color: ReportPdfHelpers.muted,
            ),
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
      ReportPdfHelpers.tableHeaderRow(['رقم الحساب', 'اسم الحساب', 'المبلغ']),
    ];

    if (rows.isEmpty) {
      tableRows.add(ReportPdfHelpers.emptyRow(3, 'لا توجد بنود'));
    } else {
      for (final row in rows) {
        tableRows.add(
          ReportPdfHelpers.tableDataRow([row.code, row.name, row.amount]),
        );
      }
      // Total row
      tableRows.add(
        ReportPdfHelpers.tableDataRow(
          ['', 'الإجمالي', total],
          bold: true,
          colors: [null, totalColor, totalColor],
        ),
      );
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
            top: const pw.BorderSide(
              width: 0.8,
              color: ReportPdfHelpers.border,
            ),
            bottom: const pw.BorderSide(
              width: 0.8,
              color: ReportPdfHelpers.border,
            ),
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
      color: color == ReportPdfHelpers.success
          ? const PdfColor.fromInt(0xFFECFDF5)
          : color == ReportPdfHelpers.danger
          ? const PdfColor.fromInt(0xFFFEF2F2)
          : color == ReportPdfHelpers.secondary
          ? const PdfColor.fromInt(0xFFF5F0FF)
          : const PdfColor.fromInt(0xFFF8FAFC),
      child: pw.Row(
        children: [
          pw.Text(icon, style: const pw.TextStyle(fontSize: 14)),
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

  static pw.Widget _checkCard(BalanceSheet sheet) {
    final isBalanced = sheet.balanced;
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: ReportPdfHelpers.cardBg,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(
          color: isBalanced
              ? ReportPdfHelpers.success
              : ReportPdfHelpers.danger,
          width: 1.5,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            children: [
              pw.Text(
                'إجمالي الأصول',
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: ReportPdfHelpers.muted,
                ),
              ),
              pw.Spacer(),
              pw.Text(
                ReportPdfHelpers.formatAmount(sheet.assetsTotal),
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: ReportPdfHelpers.primary,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              pw.Text(
                'إجمالي الخصوم + حقوق الملكية',
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: ReportPdfHelpers.muted,
                ),
              ),
              pw.Spacer(),
              pw.Text(
                ReportPdfHelpers.formatAmount(
                  sheet.liabilitiesTotal + sheet.equityTotal,
                ),
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: ReportPdfHelpers.primary,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Text(
                isBalanced ? '✓' : '✗',
                style: pw.TextStyle(
                  fontSize: 16,
                  color: isBalanced
                      ? ReportPdfHelpers.success
                      : ReportPdfHelpers.danger,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                isBalanced
                    ? 'الميزانية متوازنة'
                    : 'الميزانية غير متوازنة (فرق ${ReportPdfHelpers.formatAmount(sheet.check)})',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: isBalanced
                      ? ReportPdfHelpers.success
                      : ReportPdfHelpers.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
