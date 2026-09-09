import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/domain/journal/journal.dart';
import 'package:hasad_erp/domain/journal/journal_repository.dart';
import 'package:hasad_erp/domain/journal/manual_journal_draft.dart';

void main() {
  const entryId = '55555555-5555-4555-8555-555555555555';
  const cashId = '66666666-6666-4666-8666-666666666666';
  const revenueId = '77777777-7777-4777-8777-777777777777';

  group('JournalSourceType', () {
    test('manual vs automatic mapping', () {
      expect(JournalSourceType.from('manual'), JournalSourceType.manual);
      expect(JournalSourceType.from('invoice'), JournalSourceType.automatic);
      expect(JournalSourceType.from(''), JournalSourceType.automatic);
      expect(JournalSourceType.manual.label, 'يدوي');
      expect(JournalSourceType.automatic.label, 'آلي');
    });
  });

  group('JournalEntry', () {
    test('fromJson parses a balanced entry with lines', () {
      final entry = JournalEntry.fromJson({
        'entry_id': entryId,
        'entry_no': 1042,
        'date': '2026-09-09',
        'memo': 'قيد مصاريف',
        'source_type': 'manual',
        'total': 5000,
        'lines': [
          {
            'account_code': '5301',
            'account_name': 'إيجار',
            'account_type': 'expense',
            'debit': 5000,
            'credit': 0,
          },
          {
            'account_code': '1101',
            'account_name': 'الصندوق',
            'account_type': 'asset',
            'debit': 0,
            'credit': 5000,
          },
        ],
      });

      expect(entry.id, entryId);
      expect(entry.entryNo, 1042);
      expect(entry.date, DateTime(2026, 9, 9));
      expect(entry.sourceType, JournalSourceType.manual);
      expect(entry.total, 5000);
      expect(entry.lines.length, 2);
      expect(entry.lines[0].accountCode, '5301');
      expect(entry.lines[0].amount, 5000);
      expect(entry.lines[1].credit, 5000);
      expect(entry.lines[1].amount, 5000);
    });

    test('fromJson defaults memo/source and tolerates missing lines', () {
      final entry = JournalEntry.fromJson({
        'entry_id': entryId,
        'entry_no': 1040,
        'date': '2026-09-08',
        'source_type': 'invoice',
      });

      expect(entry.memo, '');
      expect(entry.sourceType, JournalSourceType.automatic);
      expect(entry.lines, isEmpty);
      expect(entry.total, 0);
    });
  });

  group('ManualJournalDraft', () {
    test('totals and balance detection', () {
      final draft = ManualJournalDraft(
        date: DateTime(2026, 9, 9),
        memo: 'سحب نقدي',
        lines: const [
          ManualJournalLineDraft(
            accountId: cashId,
            debit: 500,
            credit: 0,
          ),
          ManualJournalLineDraft(
            accountId: revenueId,
            debit: 0,
            credit: 500,
          ),
        ],
      );

      expect(draft.debitTotal, 500);
      expect(draft.creditTotal, 500);
      expect(draft.isBalanced, isTrue);
    });

    test('isBalanced false for unbalanced / single line', () {
      final unbalanced = ManualJournalDraft(
        date: DateTime(2026, 9, 9),
        memo: '',
        lines: const [
          ManualJournalLineDraft(accountId: cashId, debit: 100, credit: 0),
          ManualJournalLineDraft(accountId: revenueId, debit: 0, credit: 90),
        ],
      );
      expect(unbalanced.isBalanced, isFalse);

      final single = ManualJournalDraft(
        date: DateTime(2026, 9, 9),
        memo: '',
        lines: const [
          ManualJournalLineDraft(accountId: cashId, debit: 100, credit: 0),
        ],
      );
      expect(single.hasAtLeastTwoLines, isFalse);
      expect(single.isBalanced, isFalse);
    });

    test('toJson builds RPC params with request id and ISO date', () {
      final json = ManualJournalDraft(
        date: DateTime(2026, 9, 9),
        memo: 'إهلاك',
        lines: const [
          ManualJournalLineDraft(accountId: cashId, debit: 250, credit: 0),
          ManualJournalLineDraft(
            accountId: revenueId,
            debit: 0,
            credit: 250,
          ),
        ],
      ).toJson(requestId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');

      expect(json['p_request_id'], 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
      expect(json['p_date'], '2026-09-09');
      expect(json['p_memo'], 'إهلاك');
      expect(json['p_lines'], [
        {'account_id': cashId, 'debit': 250, 'credit': 0},
        {'account_id': revenueId, 'debit': 0, 'credit': 250},
      ]);
    });
  });

  group('JournalEntryResult', () {
    test('fromJson parses a posted entry', () {
      final result = JournalEntryResult.fromJson({
        'entry_id': entryId,
        'entry_no': 1042,
        'total': 5000,
        'lines_count': 2,
      });

      expect(result.entryId, entryId);
      expect(result.entryNo, 1042);
      expect(result.total, 5000);
    });
  });
}