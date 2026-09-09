import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/printing/ledger_pdf.dart';
import 'package:hasad_erp/domain/reports/ledger.dart'
    show LedgerStatement, LedgerLine;
import 'package:hasad_erp/domain/accounts/account.dart'
    show AccountType;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LedgerStatement sampleStatement() => LedgerStatement(
        accountId: 'a1',
        code: '1010',
        name: 'النقدية',
        type: AccountType.asset,
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        opening: 50000,
        lines: [
          LedgerLine(
            date: DateTime(2026, 9, 5),
            entryNo: 1001,
            memo: 'فاتورة مبيعات S-001',
            debit: 20000,
            credit: 0,
            balance: 70000,
          ),
          LedgerLine(
            date: DateTime(2026, 9, 10),
            entryNo: 1002,
            memo: 'دفع مورد P-001',
            debit: 0,
            credit: 15000,
            balance: 55000,
          ),
        ],
        closing: 55000,
      );

  LedgerStatement emptyStatement() => LedgerStatement(
        accountId: 'a2',
        code: '4010',
        name: 'إيرادات المبيعات',
        type: AccountType.revenue,
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        opening: 0,
        lines: [],
        closing: 0,
      );

  test('bundled Cairo variable font parses and embeds into a PDF', () async {
    final font = await rootBundle.load('assets/fonts/Cairo-Variable.ttf');
    final bytes = await LedgerPdf.build(
      statement: sampleStatement(),
      fontBytes: font.buffer.asUint8List(),
    );

    expect(bytes, isNotEmpty);
    expect(_ascii(bytes, '%PDF-'), isTrue, reason: 'not a valid PDF header');
    expect(_ascii(bytes, 'Cairo'), isTrue,
        reason: 'expected embedded Cairo font');
  });

  test('empty ledger still renders a valid PDF', () async {
    final bytes = await LedgerPdf.build(statement: emptyStatement());

    expect(_ascii(bytes, '%PDF-'), isTrue);
  });

  test('default build loads the font from assets', () async {
    final bytes = await LedgerPdf.build(statement: sampleStatement());

    expect(_ascii(bytes, '%PDF-'), isTrue);
  });
}

bool _ascii(Uint8List bytes, String needle) {
  final target = needle.codeUnits;
  for (var i = 0; i + target.length <= bytes.length; i++) {
    var match = true;
    for (var j = 0; j < target.length; j++) {
      if (bytes[i + j] != target[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}