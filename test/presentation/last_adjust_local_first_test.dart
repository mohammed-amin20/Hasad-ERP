import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_inventory_repository.dart';
import 'package:hasad_erp/data/supabase_client.dart' as data;
import 'package:hasad_erp/domain/auth/app_role.dart';
import 'package:hasad_erp/domain/auth/app_user.dart';
import 'package:hasad_erp/domain/inventory/inventory.dart';
import 'package:hasad_erp/presentation/providers/auth_providers.dart';
import 'package:hasad_erp/presentation/providers/inventory_providers.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Regression for the physical-device M15 failure: the first physical count
/// committed locally and then reported «حدث خطأ غير متوقع».
///
/// [LastAdjust.adjust] is reached only through `ref.read`, so nothing ever
/// listens to `lastAdjustProvider`. An auto-dispose provider with no listener is
/// torn down as soon as the read returns, and the very first thing `adjust` does
/// after its `await` is write `state` — which uses the now-disposed provider and
/// throws `UnmountedRefException`. That is an `Object` the UI's
/// `mapErrorToAppException` does not recognise, so the SnackBar showed the
/// generic [UnknownException] message for a write that had already committed.
///
/// These cases drive the real provider graph with a real drift store, so they
/// also pin *which* repository ran: a count is local-first whenever the store and
/// the tenant are available, even with the network up.
void main() {
  late Directory dir;
  late AppDatabase db;
  late DriftLocalStore store;

  const tenant = 'tenant-a';

  setUp(() {
    dir = Directory.systemTemp.createTempSync('hasad_last_adjust');
    // `NativeDatabase.createInBackground`, exactly as `openAppDatabase` builds
    // it on a device — a background isolate, so every query crosses a real
    // event-loop turn. `NativeDatabase.memory()` answers in microtasks and
    // therefore CANNOT reproduce a defect that only appears across a real await;
    // it passes against the broken provider, which is what made this file's
    // first version vacuous.
    db = AppDatabase(
      NativeDatabase.createInBackground(File(p.join(dir.path, 'offline.sqlite'))),
    );
    store = DriftLocalStore(db);
  });

  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<void> seed() => store.upsertProduct(LocalProductRow(
        id: 'p1',
        tenantId: tenant,
        name: 'سلعة',
        barcode: null,
        unit: 'قطعة',
        unitType: 'count',
        salePrice: 10000,
        purchasePrice: 6000,
        qty: 100,
        reorderLevel: 10,
        supplierId: null,
        commissionRate: null,
        createdAt: DateTime(2026, 1, 1),
        synced: true,
      ));

  Future<LocalProductRow> product() async =>
      (await store.products(tenant)).singleWhere((r) => r.id == 'p1');

  Future<List<SyncQueueRow>> pending() => store.pendingSync(tenant);

  /// The graph exactly as the app builds it: a real local store and a signed-in
  /// user with a tenant, which is the state the device was in after the 8→9
  /// upgrade. The client is a bare stub — a count must never reach it on this
  /// path, and its construction is what `inventoryRepositoryProvider` needs.
  Future<ProviderContainer> container() async {
    final c = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWith((ref) async => store),
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            AppUser(
              id: 'u1',
              email: 'owner@test.local',
              role: AppRole.admin,
              tenantId: tenant,
            ),
          ),
        ),
        data.supabaseClientProvider.overrideWithValue(
          SupabaseClient('https://stub.supabase.co', 'stub-anon-key'),
        ),
      ],
    );
    addTearDown(c.dispose);
    // Settle both writes inputs so the tenant and the store are visible to the
    // write providers; one pump is not enough for a future provider and a stream.
    c.listen(localStoreProvider, (_, _) {});
    c.listen(authStateProvider, (_, _) {});
    await c.pump();
    await c.pump();
    return c;
  }

  group('a physical count through the inventory screen provider', () {
    test('runs the local-first coordinator, not the Supabase fallback',
        () async {
      await seed();
      final c = await container();

      expect(c.read(inventoryWritesLocalFirstProvider), isTrue);
      final repo = c.read(inventoryRepositoryProvider);
      expect(repo, isA<OfflineInventoryRepository>());
      expect((repo as OfflineInventoryRepository).writesAreLocalFirst, isTrue);
    });

    test('commits the local count and returns its result to the UI', () async {
      await seed();
      final c = await container();

      // Exactly what `inventory_screen.dart` does: `ref.read`, never `ref.watch`.
      final notifier = c.read(lastAdjustProvider.notifier);

      final StockAdjustResult result = await notifier.adjust(
        const StockAdjustDraft(productId: 'p1', countedQty: 90),
      );

      expect(result.changed, isTrue);
      expect(result.oldQty, 100);
      expect(result.newQty, 90);

      // The local write really happened, so the UI's success branch is truthful.
      expect((await product()).qty, 90);

      final leg = (await pending()).single;
      expect(leg.rpc, 'adjust_inventory');
      expect(leg.status, 'pending');
      expect(leg.entity, isNull);
      expect(leg.localId, 'p1');
      expect(LocalStore.parseProductAttribution(leg.affectsProductIds), ['p1']);
      // The stable idempotency key must survive the round trip through the
      // stored params (replay re-sends these exact bytes).
      expect(leg.params, contains('"p_request_id":"${leg.requestId}"'));
    });

    test('two counts in a row both commit', () async {
      await seed();
      final c = await container();

      await c.read(lastAdjustProvider.notifier).adjust(
        const StockAdjustDraft(productId: 'p1', countedQty: 90),
      );
      await c.read(lastAdjustProvider.notifier).adjust(
        const StockAdjustDraft(productId: 'p1', countedQty: 80),
      );

      expect((await product()).qty, 80);
      expect(await pending(), hasLength(2));
    });
  });
}