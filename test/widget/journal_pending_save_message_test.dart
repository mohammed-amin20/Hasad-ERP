import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/theme/app_theme.dart';
import 'package:hasad_erp/domain/accounts/account.dart';
import 'package:hasad_erp/domain/accounts/account_draft.dart';
import 'package:hasad_erp/domain/accounts/account_repository.dart';
import 'package:hasad_erp/domain/journal/journal.dart';
import 'package:hasad_erp/domain/journal/journal_repository.dart';
import 'package:hasad_erp/domain/journal/manual_journal_draft.dart';
import 'package:hasad_erp/presentation/providers/accounts_providers.dart';
import 'package:hasad_erp/presentation/providers/journal_providers.dart';
import 'package:hasad_erp/presentation/screens/journal/journal_screen.dart';

class _FakeJournalRepository implements JournalRepository {
  const _FakeJournalRepository({required this.result});

  final JournalEntryResult result;

  @override
  Future<List<JournalEntry>> entries({
    required DateTime from,
    required DateTime to,
  }) async =>
      const [];

  @override
  Future<JournalEntryResult> createManual(ManualJournalDraft draft) async =>
      result;
}

class _FakeAccountRepository implements AccountRepository {
  const _FakeAccountRepository();

  static const _chart = [
    Account(
      id: 'acc-1010',
      code: '1010',
      name: 'النقدية',
      type: AccountType.asset,
      balance: 0,
    ),
    Account(
      id: 'acc-4010',
      code: '4010',
      name: 'إيرادات مبيعات',
      type: AccountType.revenue,
      balance: 0,
    ),
  ];

  @override
  Future<List<Account>> chart() async => _chart;

  @override
  Future<Account> create(AccountDraft draft) => throw UnimplementedError();
}

Widget _host(JournalEntryResult result) {
  return ProviderScope(
    overrides: [
      journalRepositoryProvider.overrideWithValue(
        _FakeJournalRepository(result: result),
      ),
      accountRepositoryProvider.overrideWithValue(
        const _FakeAccountRepository(),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: const JournalScreen()),
      ),
    ),
  );
}

/// `pumpAndSettle` cannot be used once an autofocused sheet is open: the
/// `EditableText` cursor blink reschedules frames forever.
Future<void> _pumpSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _selectAccount(
  WidgetTester tester, {
  required bool second,
  required String codeName,
}) async {
  await tester.tap(
    find
        .widgetWithText(DropdownButtonFormField<String>, 'الحساب')
        .at(second ? 1 : 0),
  );
  await _pumpSheet(tester);
  await tester.tap(find.text(codeName).last);
  await _pumpSheet(tester);
}

void main() {
  testWidgets(
      'an offline journal save pops the sheet and shows the sync-later message',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(const JournalEntryResult(
      entryId: 'je-pending',
      entryNo: 0,
      total: 200000,
      pending: true,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await _pumpSheet(tester);
    expect(find.text('قيد يدوي جديد'), findsOneWidget);

    await _selectAccount(tester, second: false, codeName: '1010 — النقدية');
    await _selectAccount(
      tester,
      second: true,
      codeName: '4010 — إيرادات مبيعات',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'مدين').first,
      '100000',
    );
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'دائن').last,
      '100000',
    );
    await tester.pump();

    await tester.ensureVisible(find.text('ترحيل القيد'));
    await _pumpSheet(tester);
    await tester.tap(find.text('ترحيل القيد'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.text('تم حفظ القيد محليًا وستتم مزامنته عند عودة الاتصال'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an online journal save pops the sheet and shows the entry number',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(const JournalEntryResult(
      entryId: 'je-7',
      entryNo: 7,
      total: 200000,
      pending: false,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await _pumpSheet(tester);

    await _selectAccount(tester, second: false, codeName: '1010 — النقدية');
    await _selectAccount(
      tester,
      second: true,
      codeName: '4010 — إيرادات مبيعات',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'مدين').first,
      '100000',
    );
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'دائن').last,
      '100000',
    );
    await tester.pump();

    await tester.ensureVisible(find.text('ترحيل القيد'));
    await _pumpSheet(tester);
    await tester.tap(find.text('ترحيل القيد'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('تم إضافة القيد رقم 7'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}