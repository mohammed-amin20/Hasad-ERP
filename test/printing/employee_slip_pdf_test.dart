import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/printing/employee_slip_pdf.dart';
import 'package:hasad_erp/domain/salaries/salary_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const employeeId = 'dddddddd-dddd-dddd-dddd-dddddddddddd';

  EmployeeStatement sample() => EmployeeStatement(
        employeeId: employeeId,
        monthFrom: DateTime(2026, 9),
        monthTo: DateTime(2026, 10),
        opening: 150,
        lines: [
          EmployeeMonthLine(
            month: DateTime(2026, 9),
            baseSalary: 5000,
            arrears: 150,
            entitlements: 200,
            deductions: 100,
            netDue: 5250,
            paid: 5000,
            remaining: 250,
          ),
          EmployeeMonthLine(
            month: DateTime(2026, 10),
            baseSalary: 5000,
            arrears: 0,
            entitlements: 0,
            deductions: 300,
            netDue: 4700,
            paid: 4700,
            remaining: 0,
          ),
        ],
        closing: 0,
      );

  EmployeeStatement emptyStatement() => EmployeeStatement(
        employeeId: employeeId,
        monthFrom: DateTime(2026, 9),
        monthTo: DateTime(2026, 10),
        opening: 250,
        lines: const [],
        closing: 250,
      );

  test('bundled Cairo variable font parses and embeds into a PDF', () async {
    final font = await rootBundle.load('assets/fonts/Cairo-Variable.ttf');
    final bytes = await EmployeeSlipPdf.build(
      statement: sample(),
      employeeName: 'أحمد خالد',
      fontBytes: font.buffer.asUint8List(),
    );

    expect(bytes, isNotEmpty);
    expect(_ascii(bytes, '%PDF-'), isTrue, reason: 'not a valid PDF header');
    expect(_ascii(bytes, 'Cairo'), isTrue,
        reason: 'expected embedded Cairo font');
  });

  test('empty statement still renders a valid PDF', () async {
    final bytes = await EmployeeSlipPdf.build(
      statement: emptyStatement(),
      employeeName: 'سارة محمد',
    );

    expect(_ascii(bytes, '%PDF-'), isTrue);
  });

  test('default build loads the font from assets', () async {
    final bytes = await EmployeeSlipPdf.build(
      statement: sample(),
      employeeName: 'خالد العلي',
    );
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