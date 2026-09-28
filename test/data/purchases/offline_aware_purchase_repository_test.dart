import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_write.dart';
import 'package:hasad_erp/data/purchases/offline_aware_purchase_repository.dart';
import 'package:hasad_erp/data/purchases/supabase_purchase_repository.dart';
import 'package:hasad_erp/data/supabase_client.dart';
import 'package:hasad_erp/domain/auth/app_role.dart';
import 'package:hasad_erp/domain/auth/app_user.dart';
import 'package:hasad_erp/domain/purchases/purchase_invoice_draft.dart';
import 'package:hasad_erp/presentation/providers/auth_providers.dart';
import 'package:hasad_erp/presentation/providers/purchases_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      id: 'a4', tenantId: tenant, code: '1030', name: 'مخزون',
      type: 'asset', parentCode: null,
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

  group('OfflineAwarePurchaseRepository', () {
    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      store = DriftLocalStore(db);
      coordinator = OfflineWriteCoordinator(store, tenant);
      await seed(store);
    });

    tearDown(() => db.close());

    test('create mirrors the purchase locally and queues a replay leg',
        () async {
      final repo = OfflineAwarePurchaseRepository(coordinator);

      final result = await repo.create(PurchaseInvoiceDraft(
        supplierId: 's1',
        lines: [PurchaseLineDraft(productId: 'p1', qty: 2, price: 6000)],
        date: DateTime.utc(2026, 9, 10),
        paid: 12000,
        paymentMethod: 'cash',
      ));

      expect(result.pending, isTrue);
      expect(result.total, 12000);
      expect(result.paid, 12000);
      expect(result.remaining, 0);

      final invoice = (await store.invoices(tenant)).single;
      expect(invoice.synced, isFalse);
      expect(invoice.requestId, isNotNull);

      final leg = (await store.pendingSync(tenant)).single;
      expect(leg.rpc, 'create_purchase_invoice');
      expect(leg.localId, result.invoiceId);
      final params = jsonDecode(leg.params) as Map<String, dynamic>;
      expect(params['p_request_id'], invoice.requestId);
      expect((params['p_items'] as List).single['product_id'], 'p1');
    });
  });

  group('purchaseRepositoryProvider wiring', () {
    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      store = DriftLocalStore(db);
      coordinator = OfflineWriteCoordinator(store, tenant);
      await seed(store);
    });

    tearDown(() => db.close());

    test('with a local store + tenant it returns the offline-aware wrapper',
        () async {
      final auth = StreamController<AppUser?>.broadcast();
      addTearDown(auth.close);
      final container = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWith((ref) async => store),
          authStateProvider.overrideWith((ref) => auth.stream),
        ],
      );
      addTearDown(container.dispose);

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

      final repo = container.read(purchaseRepositoryProvider);
      sub.close();

      expect(repo, isA<OfflineAwarePurchaseRepository>());
      expect(repo, isNot(isA<SupabasePurchaseRepository>()));
    });

    test('without a tenant it falls back to the live Supabase repository',
        () async {
      final auth = StreamController<AppUser?>.broadcast();
      addTearDown(auth.close);
      final container = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWith((ref) async => store),
          authStateProvider.overrideWith((ref) => auth.stream),
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

      final repo = container.read(purchaseRepositoryProvider);
      sub.close();
      expect(repo, isA<SupabasePurchaseRepository>());
    });
  });
}