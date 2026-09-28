import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_write.dart';
import 'package:hasad_erp/data/payments/offline_aware_payment_repository.dart';
import 'package:hasad_erp/data/payments/supabase_payment_repository.dart';
import 'package:hasad_erp/data/supabase_client.dart';
import 'package:hasad_erp/domain/auth/app_role.dart';
import 'package:hasad_erp/domain/auth/app_user.dart';
import 'package:hasad_erp/domain/payments/payment_repository.dart';
import 'package:hasad_erp/presentation/providers/auth_providers.dart';
import 'package:hasad_erp/presentation/providers/payments_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../offline/delegating_local_store.dart';

void main() {
  late AppDatabase db;
  late DriftLocalStore store;
  late OfflineWriteCoordinator coordinator;

  const tenant = 'tenant-a';

  Future<void> seed(DriftLocalStore target) async {
    await target.upsertAccount(LocalAccountRow(
      id: 'a1', tenantId: tenant, code: '1010', name: 'نقدية',
      type: 'asset', parentCode: null,
    ));
    await target.upsertAccount(LocalAccountRow(
      id: 'a2', tenantId: tenant, code: '1015', name: 'بنك',
      type: 'asset', parentCode: null,
    ));
    await target.upsertAccount(LocalAccountRow(
      id: 'a3', tenantId: tenant, code: '1020', name: 'ذمم مدينة',
      type: 'asset', parentCode: null,
    ));
    await target.upsertAccount(LocalAccountRow(
      id: 'a6', tenantId: tenant, code: '2010', name: 'ذمم دائنة',
      type: 'liability', parentCode: null,
    ));
    await target.upsertAccount(LocalAccountRow(
      id: 'a4', tenantId: tenant, code: '2030', name: 'مستحقات موظفين',
      type: 'liability', parentCode: null,
    ));
    await target.upsertAccount(LocalAccountRow(
      id: 'a5', tenantId: tenant, code: '4010', name: 'إيرادات مبيعات',
      type: 'revenue', parentCode: null,
    ));
    await target.upsertSupplier(LocalSupplierRow(
      id: 's1', tenantId: tenant, name: 'مورد مباشر', phone: null,
      notes: null, dealType: 'direct', commissionRate: null,
      createdAt: DateTime.utc(2026, 1, 1), synced: false,
    ));
    await target.upsertProduct(LocalProductRow(
      id: 'p1', tenantId: tenant, name: 'سلعة', barcode: null,
      unit: 'قطعة', unitType: 'count', salePrice: 10000,
      purchasePrice: 6000, qty: 100, reorderLevel: 10,
      supplierId: 's1', commissionRate: null,
      createdAt: DateTime.utc(2026, 1, 1), synced: false,
    ));
  }

  Future<void> seedSaleInvoice(DriftLocalStore target) async {
    await target.upsertInvoice(LocalInvoiceRow(
      id: 'inv-1', tenantId: tenant, type: 'sale', no: 'SAL-001',
      partyId: 'c1', partyName: 'عميل', date: DateTime.utc(2026, 9, 1),
      subtotal: 50000, total: 50000, paid: 0, remaining: 50000,
      status: 'unpaid', ownership: 'owned', requestId: 'r0', synced: true,
      createdAt: null,
    ));
  }

  Future<void> seedPurchaseAndDue(DriftLocalStore target) async {
    await target.upsertInvoice(LocalInvoiceRow(
      id: 'pi-1', tenantId: tenant, type: 'purchase', no: 'PUR-001',
      partyId: 's1', partyName: 'مورد مباشر', date: DateTime.utc(2026, 8, 1),
      subtotal: 40000, total: 40000, paid: 0, remaining: 40000,
      status: 'unpaid', ownership: 'owned', requestId: 'r1', synced: true,
      createdAt: DateTime.utc(2026, 8, 1),
    ));
    await target.upsertCommissionDue(LocalCommissionDueRow(
      id: 'due-1', tenantId: tenant, invoiceId: 'pi-1', productId: 'p1',
      supplierId: 's1', dueAmount: 15000, status: 'pending',
      createdAt: DateTime.utc(2026, 8, 10),
    ));
  }

  group('OfflineAwarePaymentRepository', () {
    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      store = DriftLocalStore(db);
      coordinator = OfflineWriteCoordinator(store, tenant);
      await seed(store);
    });

    tearDown(() => db.close());

    test('record mirrors the payment locally and queues a replay leg',
        () async {
      await seedSaleInvoice(store);
      final repo = OfflineAwarePaymentRepository(coordinator);

      final result = await repo.record(PaymentDraft(
        invoiceId: 'inv-1',
        amount: 20000,
        method: 'bank',
        date: DateTime.utc(2026, 9, 9),
      ));

      expect(result.pending, isTrue);
      expect(result.paid, 20000);
      expect(result.remaining, 30000);

      final payments = await store.payments(tenant);
      expect(payments.single.synced, isFalse);
      expect(payments.single.requestId, isNotNull);

      final leg = (await store.pendingSync(tenant)).single;
      expect(leg.rpc, 'record_payment');
      expect(leg.localId, result.paymentId);
      expect(jsonDecode(leg.params)['p_request_id'], payments.single.requestId);
    });

    test('settle mirrors the allocations locally and queues a replay leg',
        () async {
      await seedPurchaseAndDue(store);
      final repo = OfflineAwarePaymentRepository(coordinator);

      final result = await repo.settle(SettlementDraft(
        supplierId: 's1',
        amount: 50000,
        method: 'bank',
        date: DateTime.utc(2026, 9, 9),
      ));

      expect(result.pending, isTrue);
      expect(result.invoicesCount, 1);
      expect(result.duesCount, 1);

      final invoice = (await store.invoices(tenant)).single;
      expect(invoice.remaining, 0);

      final leg = (await store.pendingSync(tenant)).single;
      expect(leg.rpc, 'settle_supplier');
      // settle_supplier has no single local entity, so the leg carries no localId.
      expect(leg.localId, isNull);
    });

    test('an invalid record throws and commits nothing', () async {
      await seedSaleInvoice(store);
      final repo = OfflineAwarePaymentRepository(coordinator);

      await expectLater(
        repo.record(PaymentDraft(
          invoiceId: 'inv-1',
          amount: 99999, // overpayment
          method: 'cash',
        )),
        throwsA(isA<ValidationException>()),
      );

      final invoice = (await store.invoices(tenant)).single;
      expect(invoice.paid, 0);
      expect(invoice.remaining, 50000);
      expect(await store.payments(tenant), isEmpty);
      expect(await store.journalEntries(tenant), isEmpty);
      expect(await store.pendingSync(tenant), isEmpty);
    });

    test('recordPayment rolls back every staged effect when enqueue throws',
        () async {
      // Atomicity: the coordinator's FINAL step is the queue `enqueue`. When
      // that throws (after the invoice + payment + journal are already staged
      // in the transaction), nothing may survive. Without the transaction this
      // test sees a paid invoice with no way to reach the server.
      await seedSaleInvoice(store);
      final poisoning = OfflineWriteCoordinator(
        _ThrowOnEnqueueStore(store),
        tenant,
      );

      await expectLater(
        poisoning.recordPayment(PaymentDraft(
          invoiceId: 'inv-1',
          amount: 20000,
          method: 'cash',
        )),
        throwsA(isA<AppException>()),
      );

      final invoice = (await store.invoices(tenant)).single;
      expect(invoice.paid, 0);
      expect(invoice.remaining, 50000);
      expect(await store.payments(tenant), isEmpty);
      expect(await store.journalEntries(tenant), isEmpty);
      expect(await store.pendingSync(tenant), isEmpty);
    });

    test('settleSupplier rolls back every staged effect when enqueue throws',
        () async {
      await seedPurchaseAndDue(store);
      final poisoning = OfflineWriteCoordinator(
        _ThrowOnEnqueueStore(store),
        tenant,
      );

      await expectLater(
        poisoning.settleSupplier(SettlementDraft(
          supplierId: 's1',
          amount: 50000,
          method: 'bank',
        )),
        throwsA(isA<AppException>()),
      );

      final invoice = (await store.invoices(tenant)).single;
      expect(invoice.remaining, 40000);
      expect(invoice.status, 'unpaid');
      final due = (await store.commissionDues(tenant, supplierId: 's1')).single;
      expect(due.status, 'pending');
      expect(await store.payments(tenant), isEmpty);
      expect(await store.journalEntries(tenant), isEmpty);
      expect(await store.pendingSync(tenant), isEmpty);
    });
  });

  group('paymentRepositoryProvider wiring', () {
    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      store = DriftLocalStore(db);
      coordinator = OfflineWriteCoordinator(store, tenant);
      await seed(store);
    });

    tearDown(() => db.close());

    test('with a local store + tenant it returns the offline-aware wrapper',
        () async {
      // authState requires a full chart closure only be *callable*, never that
      // it fires for pure construction, so a real drift store suffices.
      final auth = StreamController<AppUser?>.broadcast();
      addTearDown(auth.close);
      final container = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWith((ref) async => store),
          authStateProvider.overrideWith((ref) => auth.stream),
        ],
      );
      addTearDown(container.dispose);

      // `localStoreProvider` is a future provider; let it resolve. Hold the
      // auth subscription open, emit the session, and pump the container so
      // the offline branch sees a non-null store + tenant.
      await container.read(localStoreProvider.future);
      final sub = container.listen<AsyncValue<AppUser?>>(
        authStateProvider,
        (_, _) {},
      );
      auth.add(const AppUser(
        id: 'u1',
        email: 'x@test.local',
        role: AppRole.admin,
        tenantId: tenant,
      ));
      await container.pump();

      final repo = container.read(paymentRepositoryProvider);
      sub.close();

      expect(repo, isA<OfflineAwarePaymentRepository>());
      expect(repo, isNot(isA<SupabasePaymentRepository>()));
    });

    test('without a tenant it falls back to the live Supabase repository',
        () async {
      final auth = StreamController<AppUser?>.broadcast();
      addTearDown(auth.close);
      final container = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWith((ref) async => store),
          authStateProvider.overrideWith((ref) => auth.stream),
          // The fallback branch constructs the Supabase repository — never
          // touches the network at construction, so a bare client suffices.
          supabaseClientProvider.overrideWithValue(
            SupabaseClient('http://localhost:54321', 'anon-key'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(localStoreProvider.future);
      final sub = container.listen<AsyncValue<AppUser?>>(
        authStateProvider,
        (_, _) {},
      );
      auth.add(null);
      await container.pump();

      final repo = container.read(paymentRepositoryProvider);
      sub.close();
      expect(repo, isA<SupabasePaymentRepository>());
    });
  });
}

/// Throws on the coordinator's final `enqueue`, after every other write in the
/// transaction has already been staged.
class _ThrowOnEnqueueStore extends DelegatingLocalStore {
  _ThrowOnEnqueueStore(super.inner);

  @override
  Future<void> enqueue(SyncQueueRow row) =>
      throw StateError('queue write failed after the write was staged');
}