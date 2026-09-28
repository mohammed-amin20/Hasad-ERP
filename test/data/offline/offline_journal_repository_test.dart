import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_journal_repository.dart';
import 'package:hasad_erp/data/offline/offline_write.dart';
import 'package:hasad_erp/domain/accounts/account.dart';
import 'package:hasad_erp/domain/journal/journal.dart';
import 'package:hasad_erp/domain/journal/journal_repository.dart';
import 'package:hasad_erp/domain/journal/manual_journal_draft.dart';

/// Configurable inner repo so the wrapper's cache-last reads are deterministic.
class _FakeJournalRepository implements JournalRepository {
  _FakeJournalRepository({this.entriesResult, this.failWith});

  List<JournalEntry>? entriesResult;
  NetworkException? failWith;
  JournalEntryResult? createManualResult;
  int entriesCalls = 0;
  int createManualCalls = 0;

  @override
  Future<List<JournalEntry>> entries({
    required DateTime from,
    required DateTime to,
  }) async {
    entriesCalls++;
    final f = failWith;
    if (f != null) throw f;
    return entriesResult ?? const [];
  }

  @override
  Future<JournalEntryResult> createManual(ManualJournalDraft draft) async {
    createManualCalls++;
    final result = createManualResult;
    if (result != null) return result;
    throw UnimplementedError();
  }
}

JournalEntry _serverEntry(String id, DateTime date) => JournalEntry(
      id: id,
      entryNo: 42,
      date: date,
      memo: 'قيد خادم',
      sourceType: JournalSourceType.automatic,
      total: 1000,
      lines: const [
        JournalLine(
          accountCode: '1010',
          accountName: 'نقدية',
          accountType: AccountType.asset,
          debit: 1000,
          credit: 0,
        ),
      ],
    );

List<Map<String, dynamic>> _lines() => const [
      {
        'account_code': '1010',
        'account_name': 'نقدية',
        'account_type': 'asset',
        'debit': 500,
        'credit': 0,
      },
      {
        'account_code': '4010',
        'account_name': 'إيرادات مبيعات',
        'account_type': 'revenue',
        'debit': 0,
        'credit': 500,
      },
    ];

void main() {
  const tenant = 'tenant-a';

  late AppDatabase db;
  late DriftLocalStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
  });

  tearDown(() => db.close());

  Future<void> insertDraft(
    String id, {
    DateTime? date,
    bool synced = false,
    String sourceType = 'manual',
  }) =>
      store.insertJournalEntry(LocalJournalEntryRow(
        id: id,
        tenantId: tenant,
        date: date ?? DateTime(2026, 9, 9),
        memo: 'قيد محلي',
        lines: jsonEncode(_lines()),
        sourceType: sourceType,
        sourceId: null,
        requestId: 'req-$id',
        synced: synced,
        createdAt: DateTime(2026, 9, 9, 10),
      ));

  OfflineJournalRepository repo([_FakeJournalRepository? inner]) =>
      OfflineJournalRepository(
        inner ?? _FakeJournalRepository(),
        store: store,
        tenantId: tenant,
      );

  group('OfflineJournalRepository.entries (local draft merge)', () {
    test('merges unsynced manual drafts into the served list', () async {
      await insertDraft('draft-1');
      final inner = _FakeJournalRepository(
        entriesResult: [_serverEntry('server-1', DateTime(2026, 9, 1))],
      );

      final list = await repo(inner).entries(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
      );

      expect(inner.entriesCalls, 1);
      expect(list, hasLength(2));
      final draft = list.singleWhere((e) => e.id == 'draft-1');
      expect(draft.entryNo, 0, reason: 'local placeholder until sync');
      expect(draft.total, 500);
      expect(draft.sourceType, JournalSourceType.manual);
      expect(draft.lines.first.accountCode, '1010');
      expect(draft.lines.last.credit, 500);
    });

    test('merges only unsynced MANUAL rows (never auto or synced)', () async {
      await insertDraft('manual-draft');
      await insertDraft('auto-draft', sourceType: 'auto');
      await insertDraft('synced-draft', synced: true);

      final list = await repo().entries(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
      );

      expect(list.map((e) => e.id), ['manual-draft']);
    });

    test('applies the requested date range to local drafts', () async {
      await insertDraft('in-range', date: DateTime(2026, 9, 9));
      await insertDraft('before-from', date: DateTime(2026, 8, 20));
      await insertDraft('after-to', date: DateTime(2026, 10, 5));
      await insertDraft('edge-to', date: DateTime(2026, 9, 30));

      final list = await repo().entries(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
      );

      expect(list.map((e) => e.id), containsAll(['in-range', 'edge-to']));
      expect(list.map((e) => e.id), isNot(contains('before-from')));
      expect(list.map((e) => e.id), isNot(contains('after-to')));
    });

    test('a draft that already matches a served id is not duplicated',
        () async {
      await insertDraft('draft-1');
      final inner = _FakeJournalRepository(
        entriesResult: [_serverEntry('draft-1', DateTime(2026, 9, 9))],
      );

      final list = await repo(inner).entries(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
      );

      expect(list.where((e) => e.id == 'draft-1'), hasLength(1));
    });

    test('is newest-first after a merge', () async {
      await insertDraft('older-draft', date: DateTime(2026, 9, 2));
      await insertDraft('newer-draft', date: DateTime(2026, 9, 20));

      final list = await repo().entries(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
      );

      expect(list.first.id, 'newer-draft');
    });

    test('serves merged drafts on NetworkException, else rethrows', () async {
      final empty = _FakeJournalRepository(failWith: const NetworkException());
      await expectLater(
        repo(empty).entries(
          from: DateTime(2026, 9, 1),
          to: DateTime(2026, 9, 30),
        ),
        throwsA(isA<NetworkException>()),
      );

      await insertDraft('draft-1');
      final offliner =
          _FakeJournalRepository(failWith: const NetworkException());
      final served = await repo(offliner).entries(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
      );
      expect(served.map((e) => e.id), ['draft-1']);
    });

    test('no local store degrades to a plain live read', () async {
      await insertDraft('draft-1');
      final inner = _FakeJournalRepository(
        entriesResult: [_serverEntry('server-1', DateTime(2026, 9, 1))],
      );
      final webRepo = OfflineJournalRepository(
        inner,
        store: null,
        tenantId: null,
      );

      final list = await webRepo.entries(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
      );

      expect(list, hasLength(1));
      expect(list.single.id, 'server-1');
    });

    test('createManual routes through the coordinator when one is present',
        () async {
      await store.upsertAccount(LocalAccountRow(
        id: 'a1', tenantId: tenant, code: '1010', name: 'نقدية',
        type: 'asset', parentCode: null,
      ));
      await store.upsertAccount(LocalAccountRow(
        id: 'a5', tenantId: tenant, code: '2010', name: 'ذمم دائنة',
        type: 'liability', parentCode: null,
      ));
      final routed = OfflineJournalRepository(
        _FakeJournalRepository(),
        store: store,
        tenantId: tenant,
        coordinator: OfflineWriteCoordinator(store, tenant),
      );

      final result = await routed.createManual(ManualJournalDraft(
        date: DateTime(2026, 9, 9),
        memo: 'قيد',
        lines: const [
          ManualJournalLineDraft(accountId: 'a1', debit: 100),
          ManualJournalLineDraft(accountId: 'a5', credit: 100),
        ],
      ));

      expect(result.pending, isTrue);
      final mirror = (await store.journalEntries(tenant)).single;
      expect(mirror.sourceType, 'manual');
      expect(mirror.synced, isFalse);
      expect(await store.pendingSync(tenant), hasLength(1));
    });

    test('createManual falls back to the inner repo without a coordinator',
        () async {
      final inner = _FakeJournalRepository()
        ..createManualResult = JournalEntryResult(
          entryId: 'server-1',
          entryNo: 7,
          total: 0,
          pending: false,
        );
      final repo = OfflineJournalRepository(
        inner,
        store: store,
        tenantId: tenant,
      );

      final result = await repo.createManual(ManualJournalDraft(
        date: DateTime(2026, 9, 9),
        memo: 'قيد',
        lines: const [ManualJournalLineDraft(accountId: 'a1', debit: 100)],
      ));

      expect(inner.createManualCalls, 1);
      expect(result.entryNo, 7);
      expect(result.pending, isFalse);
      expect(await store.pendingSync(tenant), isEmpty);
    });
  });
}