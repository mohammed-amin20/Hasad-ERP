import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_reads.dart';

void main() {
  late AppDatabase db;
  late DriftLocalStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
  });

  tearDown(() => db.close());

  const tenant = 'tenant-t';

  group('cacheDate', () {
    test('formats local yyyy-MM-dd with zero padding', () {
      expect(cacheDate(DateTime(2026, 9, 5)), '2026-09-05');
      expect(cacheDate(DateTime(2026, 12, 31)), '2026-12-31');
      expect(cacheDate(DateTime(2026, 1, 9)), '2026-01-09');
    });
  });

  group('cacheFirst', () {
    test('serves the local mirror immediately (cache-first, no verdict gate)', () async {
      var networkCalls = 0;
      final value = await cacheFirst(
        store: store,
        tenantId: tenant,
        network: () async {
          networkCalls++;
          return 'online';
        },
        local: () async => 'local',
      );
      // Cache-first: a non-empty local mirror is served immediately and NEVER
      // gated by the connectivity verdict. The live read fans out in the
      // background (best-effort refresh, mirror-on-success) — it does NOT gate
      // or serve the path.
      expect(value, 'local');
      // Background live refresh fires without blocking the served mirror.
      await Future<void>.delayed(Duration.zero);
      expect(networkCalls, 1);
    });

    test('falls back to the local read on a NetworkException (empty mirror)', () async {
      var localCalls = 0;
      final value = await cacheFirst(
        store: store,
        tenantId: tenant,
        network: () async => throw const NetworkException(),
        local: () async {
          localCalls++;
          return 'local';
        },
      );
      expect(value, 'local');
      expect(localCalls, 1);
    });

    test('an honest error over a silent [] when the mirror is empty and remote unreachable', () async {
      expect(
        () => cacheFirst(
          store: store,
          tenantId: tenant,
          network: () async => throw const NetworkException(),
          local: () async => const <String>[],
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('web/unstamped tenant degrades to a plain live read (never gates on verdict)', () async {
      var networkCalls = 0;
      final value = await cacheFirst(
        store: null,
        tenantId: null,
        network: () async {
          networkCalls++;
          return 'online';
        },
        local: () async => 'local',
      );
      expect(value, 'online');
      expect(networkCalls, 1);
    });

    test('a populated mirror with a transient blip is served immediately (no silent [])', () async {
      await store.mirrorCustomers(tenant, const []);
      final value = await cacheFirst(
        store: store,
        tenantId: tenant,
        network: () async => throw const NetworkException(),
        local: () async => ['populated'],
      );
      expect(value, ['populated']);
    });
  });

  group('cacheLast', () {
    test('online serves fresh data and refreshes the cache', () async {
      final value = await cacheLast(
        store: store,
        tenantId: tenant,
        key: 'k1',
        network: () async => 42,
        fromCached: int.parse,
        toPayload: (v) => '$v',
      );
      expect(value, 42);
      expect(await store.report(tenant, 'k1'), '42');
    });

    test('offline serves the last cached payload', () async {
      await store.putReport(tenant, 'k2', '{"n":7}');
      final value = await cacheLast(
        store: store,
        tenantId: tenant,
        key: 'k2',
        network: () async => throw const NetworkException(),
        fromCached: (p) => (jsonDecode(p) as Map).cast<String, dynamic>(),
        toPayload: (v) => jsonEncode(v),
      );
      expect(value['n'], 7);
    });

    test('offline without a cached payload rethrows (honest error, no silent [])', () async {
      expect(
        () => cacheLast(
          store: store,
          tenantId: tenant,
          key: 'missing',
          network: () async => throw const NetworkException(),
          fromCached: int.parse,
          toPayload: (v) => '$v',
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('a failing cache write never fails a successful read', () async {
      final value = await cacheLast(
        store: store,
        tenantId: tenant,
        key: 'k3',
        network: () async => 42,
        fromCached: int.parse,
        toPayload: (v) => throw StateError('serialize boom'),
      );
      expect(value, 42);
    });
  });
}
