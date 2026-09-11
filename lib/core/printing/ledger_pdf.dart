import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/reports/ledger.dart' show LedgerStatement;
import '../../domain/accounts/account.dart';
import 'report_pdf_helpers.dart';

/// Builds an A4, RTL General Ledger PDF in Arabic.
abstract final class LedgerPdf {
  static Future<Uint8List> build({
    required LedgerStatement statement,
    Uint8List? fontBytes,
  }) async {
    final body = <pw.Widget>[
      _accountHeader(statement),
      pw.SizedBox(height: 16),
      _movementsTable(statement),
    ];

    return ReportPdfHelpers.buildReport(
      fontBytes: fontBytes,
      title: 'الأستاذ العام',
      subtitle:
          'الحساب: ${statement.code} — ${statement.name} (${_typeLabel(statement.type)})',
      dateRange:
          'من ${ReportPdfHelpers.formatDate(statement.from)} '
          'إلى ${ReportPdfHelpers.formatDate(statement.to)}',
      bodyWidgets: body,
    );
  }

  static String _typeLabel(AccountType type) {
    return switch (type) {
      AccountType.asset => 'أصول',
      AccountType.liability => 'خصوم',
      AccountType.equity => 'حقوق ملكية',
      AccountType.revenue => 'إيرادات',
      AccountType.expense => 'مصاريف',
    };
  }

  static pw.Widget _accountHeader(LedgerStatement statement) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'رقم الحساب: ${statement.code}',
              style: const pw.TextStyle(
                fontSize: 11,
                color: ReportPdfHelpers.muted,
              ),
            ),
            pw.Text(
              'الرصيد الافتتاحي: ${ReportPdfHelpers.formatAmount(statement.opening)}',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: statement.opening >= 0
                    ? ReportPdfHelpers.success
                    : ReportPdfHelpers.danger,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Divider(height: 1, color: ReportPdfHelpers.border),
      ],
    );
  }

  static pw.Widget _movementsTable(LedgerStatement statement) {
    if (statement.lines.isEmpty) {
      return pw.Center(
        child: pw.Text(
          'لا توجد حركات في هذه الفترة',
          style: const pw.TextStyle(
            fontSize: 12,
            color: ReportPdfHelpers.muted,
          ),
        ),
      );
    }

    var running = statement.opening;
    final rows = <pw.TableRow>[
      ReportPdfHelpers.tableHeaderRow([
        'التاريخ',
        'رقم القيد',
        'البيان',
        'مدين',
        'دائن',
        'الرصيد',
      ]),
      ReportPdfHelpers.tableDataRow([
        '',
        '',
        'رصيد سابق',
        '',
        '',
        ReportPdfHelpers.formatAmount(running),
      ], bold: true),
    ];

    for (final line in statement.lines) {
      running += line.debit - line.credit;
      final isDebit = line.debit > 0;
      rows.add(
        ReportPdfHelpers.tableDataRow(
          [
            ReportPdfHelpers.formatDate(line.date),
            line.entryNo.toString(),
            line.memo.isEmpty ? '—' : line.memo,
            line.debit > 0 ? ReportPdfHelpers.formatAmount(line.debit) : '',
            line.credit > 0 ? ReportPdfHelpers.formatAmount(line.credit) : '',
            ReportPdfHelpers.formatAmount(running),
          ],
          colors: [
            null, // date
            null, // entryNo
            null, // memo
            isDebit ? ReportPdfHelpers.danger : null, // debit
            !isDebit ? ReportPdfHelpers.primary : null, // credit
            running >= 0
                ? ReportPdfHelpers.success
                : ReportPdfHelpers.danger, // balance
          ],
        ),
      );
    }

    // Closing balance row
    rows.add(
      ReportPdfHelpers.tableDataRow(
        [
          '',
          '',
          'الرصيد الختامي',
          '',
          '',
          ReportPdfHelpers.formatAmount(statement.closing),
        ],
        bold: true,
        colors: [
          null,
          null,
          null,
          null,
          null,
          statement.closing >= 0
              ? ReportPdfHelpers.success
              : ReportPdfHelpers.danger,
        ],
      ),
    );

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
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(1.2),
        5: pw.FlexColumnWidth(1.2),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: rows,
    );
  }
}
