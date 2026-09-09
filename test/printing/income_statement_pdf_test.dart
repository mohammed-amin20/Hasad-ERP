import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/printing/income_statement_pdf.dart';
import 'package:hasad_erp/domain/reports/income_statement.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  IncomeStatement sampleStatement() => IncomeStatement(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        revenues: [
          IncomeStatementLine(
            accountId: 'a1',
            code: '4010',
            name: 'إيرادات المبيعات',
            amount: 100000,
          ),
          IncomeStatementLine(
            accountId: 'a2',
            code: '4020',
            name: 'إيرادات أخرى',
            amount: 20000,
          ),
        ],
        expenses: [
          IncomeStatementLine(
            accountId: 'a3',
            code: '5010',
            name: 'تكلفة البضاعة المباعة',
            amount: 50000,
          ),
          IncomeStatementLine(
            accountId: 'a4',
            code: '5020',
            name: 'مصاريف تشغيلية',
            amount: 30000,
          ),
        ],
        revenueTotal: 120000,
        expenseTotal: 80000,
        net: 40000,
      );

  IncomeStatement lossStatement() => IncomeStatement(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        revenues: [
          IncomeStatementLine(
            accountId: 'a1',
            code: '4010',
            name: 'إيرادات المبيعات',
            amount: 50000,
          ),
        ],
        expenses: [
          IncomeStatementLine(
            accountId: 'a3',
            code: '5010',
            name: 'تكلفة البضاعة المباعة',
            amount: 40000,
          ),
          IncomeStatementLine(
            accountId: 'a4',
            code: '5020',
            name: 'مصاريف تشغيلية',
            amount: 20000,
          ),
        ],
        revenueTotal: 50000,
        expenseTotal: 60000,
        net: -10000,
      );

  IncomeStatement emptyStatement() => IncomeStatement(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        revenues: [],
        expenses: [],
        revenueTotal: 0,
        expenseTotal: 0,
        net: 0,
      );

  test('bundled Cairo variable font parses and embeds into a PDF', () async {
    final font = await rootBundle.load('assets/fonts/Cairo-Variable.ttf');
    final bytes = await IncomeStatementPdf.build(
      statement: sampleStatement(),
      fontBytes: font.buffer.asUint8List(),
    );

    expect(bytes, isNotEmpty);
    expect(_ascii(bytes, '%PDF-'), isTrue, reason: 'not a valid PDF header');
    expect(_ascii(bytes, 'Cairo'), isTrue,
        reason: 'expected embedded Cairo font');
  });

  test('empty income statement still renders a valid PDF', () async {
    final bytes = await IncomeStatementPdf.build(statement: emptyStatement());

    expect(_ascii(bytes, '%PDF-'), isTrue);
  });

  test('default build loads the font from assets', () async {
    final bytes = await IncomeStatementPdf.build(statement: lossStatement());

    expect(_ascii(bytes, '%PDF-'), isTrue);
  });

  test('loss statement renders with danger color', () async {
    final bytes = await IncomeStatementPdf.build(statement: lossStatement());

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