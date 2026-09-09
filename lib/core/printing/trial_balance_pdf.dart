import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/reports/trial_balance.dart';
import '../../domain/accounts/account.dart';
import 'report_pdf_helpers.dart';

/// Builds an A4, RTL Trial Balance PDF in Arabic.
abstract final class TrialBalancePdf {
  static Future<Uint8List> build({
    required TrialBalanceReport report,
    Uint8List? fontBytes,
  }) async {
    final body = <pw.Widget>[
      _summaryRow(report),
      pw.SizedBox(height: 16),
      _accountsTable(report),
    ];

    return ReportPdfHelpers.buildReport(
      fontBytes: fontBytes,
      title: 'ميزان المراجعة',
      subtitle: 'حتى تاريخ ${ReportPdfHelpers.formatDate(report.asOf)}',
      bodyWidgets: body,
    );
  }

  static pw.Widget _summaryRow(TrialBalanceReport report) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: _summaryBox(
            'إجمالي المدين',
            ReportPdfHelpers.formatAmount(report.totalDebit),
            ReportPdfHelpers.danger,
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _summaryBox(
            'إجمالي الدائن',
            ReportPdfHelpers.formatAmount(report.totalCredit),
            ReportPdfHelpers.primary,
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _summaryBox(
            report.balanced ? 'متوازن' : 'غير متوازن',
            ReportPdfHelpers.formatAmount(report.totalDebit - report.totalCredit),
            report.balanced ? ReportPdfHelpers.success : ReportPdfHelpers.danger,
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
            : color == ReportPdfHelpers.danger
                ? const PdfColor.fromInt(0xFFFEF2F2)
                : color == ReportPdfHelpers.success
                    ? const PdfColor.fromInt(0xFFECFDF5)
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

  static pw.Widget _accountsTable(TrialBalanceReport report) {
    if (report.rows.isEmpty) {
      return pw.Center(
        child: pw.Text(
          'لا توجد حسابات',
          style: const pw.TextStyle(fontSize: 12, color: ReportPdfHelpers.muted),
        ),
      );
    }

    // Group rows by account type for better readability
    final grouped = <AccountType, List<TrialBalanceRow>>{};
    for (final row in report.rows) {
      grouped.putIfAbsent(row.type, () => []).add(row);
    }

    final typeOrder = [
      AccountType.asset,
      AccountType.liability,
      AccountType.equity,
      AccountType.revenue,
      AccountType.expense,
    ];

    final typeLabels = {
      AccountType.asset: 'الأصول',
      AccountType.liability: 'الخصوم',
      AccountType.equity: 'حقوق الملكية',
      AccountType.revenue: 'الإيرادات',
      AccountType.expense: 'المصاريف',
    };

    final typeColors = {
      AccountType.asset: ReportPdfHelpers.success,
      AccountType.liability: ReportPdfHelpers.danger,
      AccountType.equity: ReportPdfHelpers.secondary,
      AccountType.revenue: ReportPdfHelpers.primary,
      AccountType.expense: ReportPdfHelpers.warning,
    };

    final rows = <pw.TableRow>[
      ReportPdfHelpers.tableHeaderRow(
        ['رقم الحساب', 'اسم الحساب', 'النوع', 'مدين', 'دائن', 'الرصيد'],
      ),
    ];

    for (final type in typeOrder) {
      final typeRows = grouped[type];
      if (typeRows == null || typeRows.isEmpty) continue;

      // Section header row
      rows.add(
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              child: pw.Text(
                typeLabels[type] ?? type.name,
                textAlign: pw.TextAlign.end,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: typeColors[type] ?? ReportPdfHelpers.muted,
                ),
              ),
            ),
            for (int i = 1; i < 6; i++) pw.Container(),
          ],
        ),
      );

      for (final row in typeRows) {
        final balance = row.balance;
        final isDebit = balance >= 0;
        rows.add(ReportPdfHelpers.tableDataRow(
          [
            row.code,
            row.name,
            typeLabels[type] ?? type.name,
            row.debit > 0 ? ReportPdfHelpers.formatAmount(row.debit) : '',
            row.credit > 0 ? ReportPdfHelpers.formatAmount(row.credit) : '',
            ReportPdfHelpers.formatAmount(balance),
          ],
          bold: false,
          colors: [
            null, // code
            null, // name
            typeColors[type], // type
            row.debit > 0 ? ReportPdfHelpers.danger : null, // debit
            row.credit > 0 ? ReportPdfHelpers.primary : null, // credit
            isDebit ? ReportPdfHelpers.success : ReportPdfHelpers.danger, // balance
          ],
        ));
      }
    }

    // Totals row
    rows.add(ReportPdfHelpers.tableDataRow(
      [
        '',
        'الإجماليات',
        '',
        ReportPdfHelpers.formatAmount(report.totalDebit),
        ReportPdfHelpers.formatAmount(report.totalCredit),
        ReportPdfHelpers.formatAmount(report.totalDebit - report.totalCredit),
      ],
      bold: true,
      colors: [
        null,
        ReportPdfHelpers.muted,
        null,
        ReportPdfHelpers.danger,
        ReportPdfHelpers.primary,
        report.balanced ? ReportPdfHelpers.success : ReportPdfHelpers.danger,
      ],
    ));

    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: const pw.BorderSide(
          width: 0.4,
          color: ReportPdfHelpers.border,
        ),
        top: const pw.BorderSide(width: 0.8, color: ReportPdfHelpers.border),
        bottom: const pw.BorderSide(width: 0.8, color: ReportPdfHelpers.border),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.1),
        1: pw.FlexColumnWidth(2.5),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(1.2),
        5: pw.FlexColumnWidth(1.2),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: rows,
    );
  }
}