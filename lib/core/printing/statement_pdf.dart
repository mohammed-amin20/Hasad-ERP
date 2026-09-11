import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/statements/statement.dart';
import '../utils/money.dart';

/// Builds an A4, RTL account-statement PDF in Arabic.
///
/// Cairo is embedded from the app bundle (never fetched at runtime).
/// Arabic shaping is performed by the `pdf` package's `use_arabic` path, so
/// the app must be compiled with `--dart-define=use_arabic=true` (see
/// AGENTS.md) — otherwise letters render disconnected.
abstract final class StatementPdf {
  static const _cairoAsset = 'assets/fonts/Cairo-Variable.ttf';
  static const _danger = PdfColor.fromInt(0xFFDC2626);
  static const _primary = PdfColor.fromInt(0xFF2563EB);
  static const _muted = PdfColor.fromInt(0xFF64748B);

  /// Renders [statement] for [partyName] onto PDF bytes.
  ///
  /// [fontBytes] is injectable for tests; defaults to loading the bundled
  /// Cairo variable font.
  static Future<Uint8List> build({
    required PartyStatement statement,
    required String partyName,
    required String partyType,
    Uint8List? fontBytes,
  }) async {
    final font =
        fontBytes ?? (await rootBundle.load(_cairoAsset)).buffer.asUint8List();
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
            _header(statement, partyName, partyType),
            pw.SizedBox(height: 16),
            _summaryRow(statement),
            pw.SizedBox(height: 12),
            _movementsTable(statement),
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

  static pw.Widget _header(
    PartyStatement statement,
    String partyName,
    String partyType,
  ) {
    final typeLabel = partyType == 'supplier' ? 'مورد' : 'عميل';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'كشف حساب',
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
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '$typeLabel: $partyName',
              style: const pw.TextStyle(fontSize: 12),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'الفترة: ${_date(statement.from)} إلى ${_date(statement.to)}',
          style: const pw.TextStyle(fontSize: 10, color: _muted),
        ),
        pw.SizedBox(height: 8),
        pw.Divider(height: 1, color: const PdfColor.fromInt(0xFFE2E8F0)),
      ],
    );
  }

  static pw.Widget _summaryRow(PartyStatement statement) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: _summaryBox('الرصيد الافتتاحي', statement.opening, _muted),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _summaryBox('الرصيد الختامي', statement.closing, _primary),
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

  static pw.Widget _movementsTable(PartyStatement statement) {
    final rows = <pw.TableRow>[
      _tableHeaderRow(),
      _tableDataRow(
        date: null,
        label: 'رصيد سابق',
        debit: '',
        credit: '',
        balance: Money.format(statement.opening),
        bold: true,
      ),
      if (statement.lines.isEmpty)
        _tableDataRow(
          date: null,
          label: 'لا توجد حركات في هذه الفترة',
          debit: '',
          credit: '',
          balance: '',
        ),
      for (final entry in _runs(statement))
        _tableDataRow(
          date: _date(entry.line.date),
          label: _lineLabel(entry.line),
          debit: entry.line.debit > 0 ? Money.format(entry.line.debit) : '',
          credit: entry.line.credit > 0 ? Money.format(entry.line.credit) : '',
          balance: Money.format(entry.balance),
          debitColor: entry.line.debit > 0 ? _danger : null,
          creditColor: entry.line.credit > 0 ? _primary : null,
        ),
      _tableDataRow(
        date: null,
        label: 'الرصيد الختامي',
        debit: '',
        credit: '',
        balance: Money.format(statement.closing),
        bold: true,
      ),
    ];

    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: const pw.BorderSide(
          width: 0.4,
          color: PdfColor.fromInt(0xFFE2E8F0),
        ),
        top: const pw.BorderSide(
          width: 0.8,
          color: PdfColor.fromInt(0xFF94A3B8),
        ),
        bottom: const pw.BorderSide(
          width: 0.8,
          color: PdfColor.fromInt(0xFF94A3B8),
        ),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.1),
        1: pw.FlexColumnWidth(3),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(1.2),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: rows,
    );
  }

  static pw.TableRow _tableHeaderRow() {
    const style = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: _muted,
    );
    return pw.TableRow(
      children: [
        for (final header in ['التاريخ', 'البيان', 'مدين', 'دائن', 'الرصيد'])
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Text(header, textAlign: pw.TextAlign.end, style: style),
          ),
      ],
    );
  }

  static pw.TableRow _tableDataRow({
    required String? date,
    required String label,
    required String debit,
    required String credit,
    required String balance,
    bool bold = false,
    PdfColor? debitColor,
    PdfColor? creditColor,
  }) {
    final style = pw.TextStyle(
      fontSize: 9,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Text(
            date ?? '',
            textAlign: pw.TextAlign.end,
            style: pw.TextStyle(fontSize: 9, color: bold ? null : _muted),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Text(
            label,
            textAlign: pw.TextAlign.end,
            style: style.copyWith(fontSize: 10),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Text(
            debit,
            textAlign: pw.TextAlign.end,
            style: style.copyWith(color: debitColor ?? (bold ? null : _muted)),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Text(
            credit,
            textAlign: pw.TextAlign.end,
            style: style.copyWith(color: creditColor ?? (bold ? null : _muted)),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Text(
            balance,
            textAlign: pw.TextAlign.end,
            style: style.copyWith(fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    );
  }

  static Iterable<({StatementLine line, int balance})> _runs(
    PartyStatement statement,
  ) sync* {
    var running = statement.opening;
    for (final line in statement.lines) {
      running += line.balance;
      yield (line: line, balance: running);
    }
  }

  static String _lineLabel(StatementLine line) {
    final ref = line.ref;
    final refPart = ref != null ? ' ($ref)' : '';
    return switch (line.kind) {
      StatementLineKind.invoice => 'فاتورة$refPart',
      StatementLineKind.payment => 'دفعة$refPart',
      StatementLineKind.commission => 'عمولة$refPart',
    };
  }

  static String _date(DateTime? d) => d == null
      ? ''
      : '${d.year.toString().padLeft(4, '0')}/'
            '${d.month.toString().padLeft(2, '0')}/'
            '${d.day.toString().padLeft(2, '0')}';
}
