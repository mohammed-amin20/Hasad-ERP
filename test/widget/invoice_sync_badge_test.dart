import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/widgets/status_badge.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_sync.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/domain/invoices/invoice_sync.dart';
import 'package:hasad_erp/domain/products/product.dart';
import 'package:hasad_erp/domain/statements/debts_repository.dart';
import 'package:hasad_erp/presentation/providers/inventory_providers.dart';
import 'package:hasad_erp/presentation/providers/offline_sync_providers.dart';
import 'package:hasad_erp/presentation/providers/products_providers.dart';
import 'package:hasad_erp/presentation/providers/purchases_providers.dart';
import 'package:hasad_erp/presentation/providers/sales_providers.dart';
import 'package:hasad_erp/presentation/providers/statements_providers.dart';
import 'package:hasad_erp/presentation/widgets/invoice_list.dart';

import '../data/offline/delegating_local_store.dart';
import '../tool/shell_stubs.dart';

const _tenant = 'tenant-a';
const _otherTenant = 'tenant-b';

Invoice _invoice(
  String id, {
  InvoiceOwnership ownership = InvoiceOwnership.owned,
}) => Invoice(
  id: id,
  type: 'sale',
  no: 'D-9Z8Y7X6W',
  partyId: 'c1',
  partyName: 'مؤسسة النخيل',
  date: DateTime.utc(2026, 1, 1),
  subtotal: 20000,
  total: 20000,
  paid: 0,
  remaining: 20000,
  status: InvoiceStatus.unpaid,
  ownership: ownership,
);

SyncQueueRow _leg(
  String id, {
  String? entity = 'invoices',
  String? localId,
  String status = 'pending',
  String tenantId = _tenant,
  DateTime? createdAt,
}) => SyncQueueRow(
  id: id,
  tenantId: tenantId,
  rpc: 'create_sale_invoice',
  op: 'rpc',
  params: jsonEncode(<String, dynamic>{'p_request_id': 'req-$id'}),
  requestId: 'req-$id',
  entity: entity,
  localId: localId,
  status: status,
  attempts: 0,
  lastError: null,
  createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
  updatedAt: createdAt ?? DateTime.utc(2026, 1, 1),
);

/// A store that blows up on the one call the indicator makes, to prove the
/// provider degrades instead of erroring.
class _ThrowingLegsStore extends DelegatingLocalStore {
  _ThrowingLegsStore(super.inner);

  @override
  Future<List<SyncQueueRow>> queueLegsFor(
    String tenantId, {
    String? entity,
  }) async =>
      throw StateError('queue unreadable');
}

/// Real notifier subclasses that count `build()` calls and never touch
/// Supabase, so "did the drain invalidate the list?" is observable without
/// standing up a repository.
class _CountingSaleInvoicesList extends SaleInvoicesList {
  _CountingSaleInvoicesList(this.onBuild);

  final void Function() onBuild;

  @override
  Future<List<Invoice>> build() {
    onBuild();
    return Future<List<Invoice>>.value(const []);
  }
}

class _CountingPurchaseInvoicesList extends PurchaseInvoicesList {
  _CountingPurchaseInvoicesList(this.onBuild);

  final void Function() onBuild;

  @override
  Future<List<Invoice>> build() {
    onBuild();
    return Future<List<Invoice>>.value(const []);
  }
}

/// Same trick for the product list: a real notifier subclass that counts
/// `build()` calls and never touches Supabase.
class _CountingProductsList extends ProductsList {
  _CountingProductsList(this.onBuild);

  final void Function() onBuild;

  @override
  Future<List<Product>> build() {
    onBuild();
    return Future<List<Product>>.value(const []);
  }
}

void main() {
  group('LocalStore.queueLegsFor', () {
    late AppDatabase db;
    late DriftLocalStore store;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      store = DriftLocalStore(db);
    });

    tearDown(() => db.close());

    // The whole reason this method exists: `pendingSync` omits everything that
    // is not 'pending', so it cannot tell "synced" from "failed".
    test('includes synced and failed legs, not just pending', () async {
      await store.enqueue(_leg('q-pending', localId: 'i-pending'));
      await store.enqueue(_leg('q-synced', localId: 'i-synced', status: 'synced'));
      await store.enqueue(_leg('q-failed', localId: 'i-failed', status: 'failed'));

      final legs = await store.queueLegsFor(_tenant, entity: 'invoices');

      expect(legs.map((l) => l.id).toSet(), {'q-pending', 'q-synced', 'q-failed'});
      expect(
        {for (final l in legs) l.id: l.status},
        {
          'q-pending': 'pending',
          'q-synced': 'synced',
          'q-failed': 'failed',
        },
      );
    });

    test('narrows to a single entity', () async {
      await store.enqueue(_leg('q-inv', entity: 'invoices', localId: 'i-1'));
      await store.enqueue(_leg('q-pay', entity: 'payments', localId: 'p-1'));
      await store.enqueue(_leg('q-null-entity', entity: null));

      final legs = await store.queueLegsFor(_tenant, entity: 'invoices');

      expect(legs.map((l) => l.id), ['q-inv']);
    });

    test('a null entity filter returns every leg', () async {
      await store.enqueue(_leg('q-inv', entity: 'invoices'));
      await store.enqueue(_leg('q-pay', entity: 'payments'));

      final legs = await store.queueLegsFor(_tenant);

      expect(legs.map((l) => l.id).toSet(), {'q-inv', 'q-pay'});
    });

    test('never crosses tenants', () async {
      await store.enqueue(_leg('q-a', localId: 'i-a', tenantId: _tenant));
      await store.enqueue(_leg('q-b', localId: 'i-b', tenantId: _otherTenant));

      final legs = await store.queueLegsFor(_tenant, entity: 'invoices');

      expect(legs.map((l) => l.id), ['q-a']);
    });

    test('orders oldest first', () async {
      await store.enqueue(
        _leg('q-new', localId: 'i', createdAt: DateTime.utc(2026, 3, 1)),
      );
      await store.enqueue(
        _leg('q-old', localId: 'i', createdAt: DateTime.utc(2026, 1, 1)),
      );

      final legs = await store.queueLegsFor(_tenant, entity: 'invoices');

      expect(legs.map((l) => l.id), ['q-old', 'q-new']);
    });

    test('NullLocalStore reports no legs instead of throwing', () async {
      expect(await const NullLocalStore().queueLegsFor(_tenant), isEmpty);
      expect(
        await const NullLocalStore().queueLegsFor(_tenant, entity: 'invoices'),
        isEmpty,
      );
    });
  });

  group('invoiceSyncStatesProvider', () {
    late AppDatabase db;
    late DriftLocalStore store;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      store = DriftLocalStore(db);
      container = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWith((ref) async => store),
          currentTenantIdProvider.overrideWithValue(_tenant),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      db.close();
    });

    test('keys each leg by its localId and maps the status', () async {
      await store.enqueue(_leg('q-1', localId: 'i-pending'));
      await store.enqueue(_leg('q-2', localId: 'i-failed', status: 'failed'));
      await store.enqueue(_leg('q-3', localId: 'i-staged', status: 'staged'));

      final states = await container.read(invoiceSyncStatesProvider.future);

      expect(states['i-pending'], InvoiceSyncState.pending);
      expect(states['i-failed'], InvoiceSyncState.failed);
      expect(states['i-staged'], InvoiceSyncState.pending);
    });

    test('a leg with no localId is skipped (the settle_supplier case)', () async {
      await store.enqueue(_leg('q-1', localId: null));

      expect(await container.read(invoiceSyncStatesProvider.future), isEmpty);
    });

    test('a synced leg is still mapped, so the UI can tell it apart', () async {
      await store.enqueue(_leg('q-1', localId: 'i-1', status: 'synced'));

      final states = await container.read(invoiceSyncStatesProvider.future);

      expect(states['i-1'], InvoiceSyncState.synced);
    });

    // A spread overwrite means the newest leg wins, which is the right
    // precedence when a retry re-enqueues work for the same local id.
    test('the newest leg for a local id wins', () async {
      await store.enqueue(
        _leg('q-old', localId: 'i-1', createdAt: DateTime.utc(2026, 1, 1)),
      );
      await store.enqueue(
        _leg('q-new', localId: 'i-1', createdAt: DateTime.utc(2026, 2, 1)),
      );

      final states = await container.read(invoiceSyncStatesProvider.future);

      expect(states.length, 1);
      expect(states['i-1'], InvoiceSyncState.pending);
    });

    test('another tenant\'s invoice never appears', () async {
      await store.enqueue(_leg('q-a', localId: 'i-a', tenantId: _tenant));
      await store.enqueue(_leg('q-b', localId: 'i-b', tenantId: _otherTenant));

      final states = await container.read(invoiceSyncStatesProvider.future);

      expect(states.keys, ['i-a']);
    });

    test('no tenant means no state rather than a throw', () async {
      await store.enqueue(_leg('q-1', localId: 'i-1'));
      container.dispose();
      container = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWith((ref) async => store),
          currentTenantIdProvider.overrideWithValue(''),
        ],
      );

      expect(await container.read(invoiceSyncStatesProvider.future), isEmpty);
    });

    // A sync indicator must never be able to take down the list it annotates.
    test('an unreadable queue degrades to no badges instead of erroring',
        () async {
      final broken = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWith(
            (ref) async => _ThrowingLegsStore(store),
          ),
          currentTenantIdProvider.overrideWithValue(_tenant),
        ],
      );
      addTearDown(broken.dispose);

      expect(await broken.read(invoiceSyncStatesProvider.future), isEmpty);
    });
  });

  group('InvoiceListView sync badge', () {
    Future<void> pumpList(
      WidgetTester tester, {
      required List<Invoice> invoices,
      Map<String, InvoiceSyncState> states = const {},
      Size size = const Size(1440, 900),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            invoiceSyncStatesProvider.overrideWith((ref) async => states),
          ],
          child: MaterialApp(
            home: Directionality(
              // Inside `home`, so the app's own Directionality is not re-asserted
              // over it from the locale.
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: InvoiceListView(
                  invoices: invoices,
                  onTap: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a pending invoice shows the pending badge', (tester) async {
      await pumpList(
        tester,
        invoices: [_invoice('i-1')],
        states: {'i-1': InvoiceSyncState.pending},
      );

      expect(find.text('بانتظار المزامنة'), findsOneWidget);
      // payment status + sync state
      expect(find.byType(StatusBadge), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed invoice shows the failed badge', (tester) async {
      await pumpList(
        tester,
        invoices: [_invoice('i-1')],
        states: {'i-1': InvoiceSyncState.failed},
      );

      expect(find.text('فشلت المزامنة'), findsOneWidget);
      expect(find.byType(StatusBadge), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    // Absence of a badge is the agreed "synced" signal, so a clean row must
    // show exactly the one payment-status badge and nothing else.
    testWidgets('a synced invoice shows no sync badge at all', (tester) async {
      await pumpList(
        tester,
        invoices: [_invoice('i-1')],
        states: {'i-1': InvoiceSyncState.synced},
      );

      expect(find.text('بانتظار المزامنة'), findsNothing);
      expect(find.text('فشلت المزامنة'), findsNothing);
      expect(find.text('مُزامنة'), findsNothing);
      expect(find.byType(StatusBadge), findsNWidgets(1));
    });

    testWidgets('an invoice with no queue leg reads as synced', (tester) async {
      await pumpList(tester, invoices: [_invoice('i-1')]);

      expect(find.byType(StatusBadge), findsNWidgets(1));
    });

    testWidgets('only the unsynced row in a list is badged', (tester) async {
      await pumpList(
        tester,
        invoices: [_invoice('i-synced'), _invoice('i-pending')],
        states: {
          'i-synced': InvoiceSyncState.synced,
          'i-pending': InvoiceSyncState.pending,
        },
      );

      expect(find.text('بانتظار المزامنة'), findsOneWidget);
      expect(find.byType(StatusBadge), findsNWidgets(3));
    });

    // The regression this whole layout choice exists for: three badges in a
    // `flex: 2` cell. 768 is the narrowest the table layout ever gets (the
    // card layout takes over below 700) and gives this cell ~155px, so a
    // `Row` would overflow there while 1440 and 375 would both pass.
    testWidgets('three badges in the status cell do not overflow at 768',
        (tester) async {
      await pumpList(
        tester,
        invoices: [
          _invoice('i-1', ownership: InvoiceOwnership.consignment),
        ],
        states: {'i-1': InvoiceSyncState.pending},
        size: const Size(768, 1024),
      );

      expect(find.byType(StatusBadge), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('three badges in the status cell do not overflow at 375',
        (tester) async {
      await pumpList(
        tester,
        invoices: [
          _invoice('i-1', ownership: InvoiceOwnership.consignment),
        ],
        states: {'i-1': InvoiceSyncState.pending},
        size: const Size(375, 667),
      );

      expect(find.byType(StatusBadge), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  });

  group('a completed drain', () {
    // The end-to-end proof of both halves of the change: the badge is driven by
    // the real queue, and a drain updates it (and the lists) in place.
    testWidgets('clears the badge and refreshes both invoice lists',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = DriftLocalStore(db);

      // A genuine offline draft: unsynced mirror row + a pending replay leg.
      await store.upsertInvoice(
        LocalInvoiceRow(
          id: 'draft-1',
          tenantId: _tenant,
          type: 'sale',
          no: 'D-9Z8Y7X6W',
          partyId: 'c1',
          partyName: 'مؤسسة النخيل',
          date: DateTime.utc(2026, 1, 1),
          subtotal: 20000,
          total: 20000,
          paid: 0,
          remaining: 20000,
          status: 'unpaid',
          ownership: 'owned',
          requestId: 'req-1',
          synced: false,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await store.enqueue(_leg('q-1', localId: 'draft-1'));

      var saleBuilds = 0;
      var purchaseBuilds = 0;
      final container = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWith((ref) async => store),
          currentTenantIdProvider.overrideWithValue(_tenant),
          // A real flusher over a no-op target: the leg genuinely drains.
          syncFlusherProvider.overrideWith(
            (ref) async => SyncFlusher(store, _tenant, ShellNoopSyncTarget()),
          ),
          saleInvoicesListProvider.overrideWith(
            () => _CountingSaleInvoicesList(() => saleBuilds++),
          ),
          purchaseInvoicesListProvider.overrideWith(
            () => _CountingPurchaseInvoicesList(() => purchaseBuilds++),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Listen so the list providers are actually built — invalidating a
      // provider nobody has read is not observable.
      final saleSub = container.listen(saleInvoicesListProvider, (_, _) {});
      final purchaseSub =
          container.listen(purchaseInvoicesListProvider, (_, _) {});
      addTearDown(saleSub.close);
      addTearDown(purchaseSub.close);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: InvoiceListView(
                  invoices: [_invoice('draft-1')],
                  onTap: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('بانتظار المزامنة'), findsOneWidget);
      final saleBuildsBefore = saleBuilds;
      final purchaseBuildsBefore = purchaseBuilds;
      expect(saleBuildsBefore, greaterThan(0));

      // `runAsync` because the drain does real (drift) async work, which
      // testWidgets' fake-async zone would otherwise never complete.
      await tester.runAsync(() async {
        final summary = await container.read(manualSyncNowProvider.future);
        expect(summary.synced, 1);
      });
      await tester.pumpAndSettle();

      // The leg really did drain, not just the badge changing.
      final legs = await store.queueLegsFor(_tenant, entity: 'invoices');
      expect(legs.single.status, 'synced');
      expect((await store.invoices(_tenant)).single.synced, isTrue);

      // The badge clears with no navigation and no manual rebuild.
      expect(find.text('بانتظار المزامنة'), findsNothing);
      expect(find.byType(StatusBadge), findsNWidgets(1));

      // And the placeholder-numbered row is no longer served from the mirror,
      // because the list was invalidated rather than left stale.
      expect(saleBuilds, greaterThan(saleBuildsBefore));
      expect(purchaseBuilds, greaterThan(purchaseBuildsBefore));
    });

    test(
        'also refreshes inventory products, the products list and supplier debts',
        () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = DriftLocalStore(db);

      // A genuine offline draft: unsynced mirror row + a pending replay leg.
      await store.upsertInvoice(
        LocalInvoiceRow(
          id: 'draft-h',
          tenantId: _tenant,
          type: 'sale',
          no: 'D-H0000001',
          partyId: 'c1',
          partyName: 'مؤسسة النخيل',
          date: DateTime.utc(2026, 1, 1),
          subtotal: 20000,
          total: 20000,
          paid: 0,
          remaining: 20000,
          status: 'unpaid',
          ownership: 'owned',
          requestId: 'req-h',
          synced: false,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await store.enqueue(_leg('q-h', localId: 'draft-h'));

      var productListBuilds = 0;
      var inventoryBuilds = 0;
      var debtsBuilds = 0;
      final container = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWith((ref) async => store),
          currentTenantIdProvider.overrideWithValue(_tenant),
          // A real flusher over a no-op target: the leg genuinely drains.
          syncFlusherProvider.overrideWith(
            (ref) async => SyncFlusher(store, _tenant, ShellNoopSyncTarget()),
          ),
          productsListProvider.overrideWith(
            () => _CountingProductsList(() => productListBuilds++),
          ),
          inventoryProductsProvider.overrideWith((ref) async {
            inventoryBuilds++;
            return const <Product>[];
          }),
          supplierDebtsProvider.overrideWith((ref) async {
            debtsBuilds++;
            return const <PartyBalance>[];
          }),
        ],
      );
      addTearDown(container.dispose);

      // Listen so the providers are actually built — invalidating a provider
      // nobody has read is not observable.
      final productListSub =
          container.listen(productsListProvider, (_, _) {});
      final inventorySub =
          container.listen(inventoryProductsProvider, (_, _) {});
      final debtsSub = container.listen(supplierDebtsProvider, (_, _) {});
      addTearDown(productListSub.close);
      addTearDown(inventorySub.close);
      addTearDown(debtsSub.close);

      // Let the initial builds land before snapshotting the counts.
      await container.read(productsListProvider.future);
      await container.read(inventoryProductsProvider.future);
      await container.read(supplierDebtsProvider.future);
      final before = (productListBuilds, inventoryBuilds, debtsBuilds);
      expect(before.$1, greaterThan(0));
      expect(before.$2, greaterThan(0));
      expect(before.$3, greaterThan(0));

      // A real drain (real drift async work, so this stays a plain test).
      final summary = await container.read(manualSyncNowProvider.future);
      expect(summary.synced, 1);

      // Re-reading an invalidated provider recomputes it, so the count grows.
      await container.read(productsListProvider.future);
      await container.read(inventoryProductsProvider.future);
      await container.read(supplierDebtsProvider.future);

      expect(productListBuilds, greaterThan(before.$1));
      expect(inventoryBuilds, greaterThan(before.$2));
      expect(debtsBuilds, greaterThan(before.$3));
    });
  });
}
