import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/domain/statements/statement.dart';

void main() {
  const partyId = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';

  group('StatementRequest', () {
    test('toJson sends RPC params with ISO dates', () {
      final req = StatementRequest(
        partyType: 'supplier',
        partyId: partyId,
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
      ).toJson();

      expect(req['p_party_type'], 'supplier');
      expect(req['p_party_id'], partyId);
      expect(req['p_from'], '2026-09-01');
      expect(req['p_to'], '2026-09-30');
    });
  });

  group('PartyStatement', () {
    test('fromJson parses a full statement', () {
      final st = PartyStatement.fromJson({
        'party_type': 'customer',
        'party_id': partyId,
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

      expect(st.opening, 0);
      expect(st.closing, 120);
      expect(st.lines.length, 2);
      expect(st.lines[0].kind, StatementLineKind.invoice);
      expect(st.lines[0].debit, 200);
      expect(st.lines[0].balance, 200);
      expect(st.lines[1].kind, StatementLineKind.payment);
      expect(st.lines[1].credit, 80);
      expect(st.lines[1].balance, -80);
    });

    test('fromJson parses a commission line for suppliers', () {
      final st = PartyStatement.fromJson({
        'party_type': 'supplier',
        'party_id': partyId,
        'from': '2026-09-01',
        'to': '2026-09-30',
        'opening': 0,
        'closing': 180,
        'lines': [
          {
            'date': '2026-09-03',
            'kind': 'commission',
            'ref': 'P-5',
            'note': 'عمولة 10%',
            'debit': 0,
            'credit': 180,
          },
        ],
      });

      final line = st.lines.single;
      expect(line.kind, StatementLineKind.commission);
      expect(line.kind.label, 'عمولة');
      expect(line.credit, 180);
      expect(line.balance, -180);
    });

    test('kind defaults to invoice for unknown values', () {
      final st = PartyStatement.fromJson({
        'party_type': 'customer',
        'party_id': partyId,
        'from': '2026-09-01',
        'to': '2026-09-30',
        'opening': 0,
        'closing': 0,
        'lines': [
          {'date': '2026-09-01', 'kind': 'whatever', 'debit': 0, 'credit': 0},
        ],
      });

      expect(st.lines.single.kind, StatementLineKind.invoice);
    });
  });
}