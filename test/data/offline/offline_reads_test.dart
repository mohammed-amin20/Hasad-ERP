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
    test('serves the network value and mirrors it', () async {
      final mirrored = <String>[];
      final value = await cacheFirst(
        store: store,
        tenantId: tenant,
        network: () async => 'online',
        mirror: (v) async => mirrored.add(v),
        local: () async => 'local',
      );
      expect(value, 'online');
      expect(mirrored, ['online']);
    });

    test('falls back to the local read on a NetworkException', () async {
      var localCalls = 0;
      final value = await cacheFirst(
        store: store,
        tenantId: tenant,
        network: () async => throw const NetworkException(),
        mirror: (v) async {},
        local: () async {
          localCalls++;
          return 'local';
        },
      );
      expect(value, 'local');
      expect(localCalls, 1);
    });

    test('a failing mirror never fails an otherwise successful read', () async {
      final value = await cacheFirst(
        store: store,
        tenantId: tenant,
        network: () async => 'online',
        mirror: (v) async => throw StateError('mirror boom'),
        local: () async => 'local',
      );
      expect(value, 'online');
    });

    test('without a store the local read still decides the fallback', () async {
      final value = await cacheFirst(
        store: null,
        tenantId: null,
        network: () async => throw const NetworkException(),
        local: () async => 'local',
      );
      expect(value, 'local');
    });
  });

  group('cacheLast', () {
    test('caches the serialized payload on a successful read', () async {
      await cacheLast(
        store: store,
        tenantId: tenant,
        key: 'k1',
        network: () async => 42,
        fromCached: int.parse,
        toPayload: (v) => '$v',
      );
      expect(await store.report(tenant, 'k1'), '42');
    });

    test('offline serves the last cached payload', () async {
      await store.putReport(tenant, 'k2', '{"n":7}');
      final value = await cacheLast<Map<String, dynamic>>(
        store: store,
        tenantId: tenant,
        key: 'k2',
        network: () async => throw const NetworkException(),
        fromCached: (p) => (jsonDecode(p) as Map).cast<String, dynamic>(),
        toPayload: (v) => jsonEncode(v),
      );
      expect(value['n'], 7);
    });

    test('offline without a cached payload rethrows', () async {
      expect(
        () => cacheLast(
          store: store,
          tenantId: tenant,
          key: 'missing',
          network: () async => throw const NetworkException(),
          fromCached: (p) => p,
          toPayload: (v) => v,
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('a failing cache write never fails a successful read', () async {
      final value = await cacheLast(
        store: store,
        tenantId: tenant,
        key: 'ro',
        network: () async => 1,
        fromCached: int.parse,
        toPayload: (v) => throw StateError('serialize boom'),
      );
      expect(value, 1);
    });
  });
}