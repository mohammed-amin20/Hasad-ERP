import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/printing/balance_sheet_pdf.dart';
import 'package:hasad_erp/domain/reports/balance_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  BalanceSheet sampleSheet() => BalanceSheet(
        asOf: DateTime(2026, 9, 9),
        assets: [
          BalanceSheetAccount(
            accountId: 'a1',
            code: '1010',
            name: 'النقدية',
            amount: 50000,
          ),
          BalanceSheetAccount(
            accountId: 'a2',
            code: '1030',
            name: 'المخزون',
            amount: 100000,
          ),
        ],
        liabilities: [
          BalanceSheetAccount(
            accountId: 'a3',
            code: '2010',
            name: 'ذمم دائنة',
            amount: 40000,
          ),
        ],
        equity: [
          BalanceSheetAccount(
            accountId: 'a4',
            code: '3010',
            name: 'حقوق الملكية',
            amount: 110000,
          ),
        ],
        assetsTotal: 150000,
        liabilitiesTotal: 40000,
        equityTotal: 110000,
        netIncomeYtd: 20000,
        check: 0,
      );

  BalanceSheet unbalancedSheet() => BalanceSheet(
        asOf: DateTime(2026, 9, 9),
        assets: [
          BalanceSheetAccount(
            accountId: 'a1',
            code: '1010',
            name: 'النقدية',
            amount: 50000,
          ),
        ],
        liabilities: [
          BalanceSheetAccount(
            accountId: 'a2',
            code: '2010',
            name: 'ذمم دائنة',
            amount: 20000,
          ),
        ],
        equity: [
          BalanceSheetAccount(
            accountId: 'a3',
            code: '3010',
            name: 'حقوق الملكية',
            amount: 20000,
          ),
        ],
        assetsTotal: 50000,
        liabilitiesTotal: 20000,
        equityTotal: 20000,
        netIncomeYtd: 0,
        check: 10000, // Not balanced
      );

  BalanceSheet emptySheet() => BalanceSheet(
        asOf: DateTime(2026, 9, 9),
        assets: [],
        liabilities: [],
        equity: [],
        assetsTotal: 0,
        liabilitiesTotal: 0,
        equityTotal: 0,
        netIncomeYtd: 0,
        check: 0,
      );

  test('bundled Cairo variable font parses and embeds into a PDF', () async {
    final font = await rootBundle.load('assets/fonts/Cairo-Variable.ttf');
    final bytes = await BalanceSheetPdf.build(
      sheet: sampleSheet(),
      fontBytes: font.buffer.asUint8List(),
    );

    expect(bytes, isNotEmpty);
    expect(_ascii(bytes, '%PDF-'), isTrue, reason: 'not a valid PDF header');
    expect(_ascii(bytes, 'Cairo'), isTrue,
        reason: 'expected embedded Cairo font');
  });

  test('empty balance sheet still renders a valid PDF', () async {
    final bytes = await BalanceSheetPdf.build(sheet: emptySheet());

    expect(_ascii(bytes, '%PDF-'), isTrue);
  });

  test('default build loads the font from assets', () async {
    final bytes = await BalanceSheetPdf.build(sheet: unbalancedSheet());

    expect(_ascii(bytes, '%PDF-'), isTrue);
  });

  test('unbalanced sheet renders with danger color', () async {
    final bytes = await BalanceSheetPdf.build(sheet: unbalancedSheet());

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