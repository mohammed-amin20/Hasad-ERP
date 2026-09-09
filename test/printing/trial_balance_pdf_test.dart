import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/printing/trial_balance_pdf.dart';
import 'package:hasad_erp/domain/reports/trial_balance.dart';
import 'package:hasad_erp/domain/accounts/account.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TrialBalanceReport sampleReport() {
    return TrialBalanceReport(
      asOf: DateTime(2026, 9, 9),
      rows: [
        TrialBalanceRow(
          accountId: 'a1',
          code: '1010',
          name: 'النقدية',
          type: AccountType.asset,
          debit: 50000,
          credit: 0,
          balance: 50000,
        ),
        TrialBalanceRow(
          accountId: 'a2',
          code: '4010',
          name: 'إيرادات المبيعات',
          type: AccountType.revenue,
          debit: 0,
          credit: 30000,
          balance: -30000,
        ),
        TrialBalanceRow(
          accountId: 'a3',
          code: '5010',
          name: 'تكلفة البضاعة المباعة',
          type: AccountType.expense,
          debit: 20000,
          credit: 0,
          balance: 20000,
        ),
      ],
      totalDebit: 70000,
      totalCredit: 30000,
    );
  }

  TrialBalanceReport emptyReport() => TrialBalanceReport(
        asOf: DateTime(2026, 9, 9),
        rows: [],
        totalDebit: 0,
        totalCredit: 0,
      );

  test('bundled Cairo variable font parses and embeds into a PDF', () async {
    final font = await rootBundle.load('assets/fonts/Cairo-Variable.ttf');
    final bytes = await TrialBalancePdf.build(
      report: sampleReport(),
      fontBytes: font.buffer.asUint8List(),
    );

    expect(bytes, isNotEmpty);
    expect(_ascii(bytes, '%PDF-'), isTrue, reason: 'not a valid PDF header');
    expect(_ascii(bytes, 'Cairo'), isTrue,
        reason: 'expected embedded Cairo font');
  });

  test('empty trial balance still renders a valid PDF', () async {
    final bytes = await TrialBalancePdf.build(report: emptyReport());

    expect(_ascii(bytes, '%PDF-'), isTrue);
  });

  test('default build loads the font from assets', () async {
    final bytes = await TrialBalancePdf.build(report: sampleReport());

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