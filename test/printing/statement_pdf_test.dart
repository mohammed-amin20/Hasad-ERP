import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/printing/statement_pdf.dart';
import 'package:hasad_erp/domain/statements/statement.dart';

const _partyId = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PartyStatement sample() => PartyStatement.fromJson({
        'party_type': 'customer',
        'party_id': _partyId,
        'from': '2026-09-01',
        'to': '2026-09-30',
        'opening': 0,
        'closing': 120,
        'lines': [
          {
            'date': '2026-09-01',
            'kind': 'invoice',
            'ref': 'S-100',
            'note': null,
            'debit': 200,
            'credit': 0,
          },
          {
            'date': '2026-09-05',
            'kind': 'payment',
            'ref': 'S-100',
            'note': null,
            'debit': 0,
            'credit': 80,
          },
        ],
      });

  PartyStatement emptyStatement() => PartyStatement.fromJson({
        'party_type': 'customer',
        'party_id': _partyId,
        'from': '2026-09-01',
        'to': '2026-09-30',
        'opening': 500,
        'closing': 500,
        'lines': <Object?>[],
      });

  test('bundled Cairo variable font parses and embeds into a PDF', () async {
    final font = await rootBundle.load('assets/fonts/Cairo-Variable.ttf');
    final bytes = await StatementPdf.build(
      statement: sample(),
      partyName: 'محمد الأحمد',
      partyType: 'customer',
      fontBytes: font.buffer.asUint8List(),
    );

    expect(bytes, isNotEmpty);
    expect(_ascii(bytes, '%PDF-'), isTrue, reason: 'not a valid PDF header');
    expect(_ascii(bytes, 'Cairo'), isTrue,
        reason: 'expected embedded Cairo font');
  });

  test('empty statement still renders a valid PDF', () async {
    final bytes = await StatementPdf.build(
      statement: emptyStatement(),
      partyName: 'محمد الأحمد',
      partyType: 'customer',
    );

    expect(_ascii(bytes, '%PDF-'), isTrue);
  });

  test('default build loads the font from assets', () async {
    final bytes = await StatementPdf.build(
      statement: sample(),
      partyName: 'مورد الورق',
      partyType: 'supplier',
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