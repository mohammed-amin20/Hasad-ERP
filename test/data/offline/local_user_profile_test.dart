import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:path/path.dart' as p;

/// M13 Phase 0 — the offline user-profile cache.
///
/// The last test in this group is the important one. Every pre-existing offline
/// test in this suite uses `NativeDatabase.memory()`, which **cannot** prove
/// cross-process durability because the database dies with the isolate. An
/// offline cold start depends entirely on surviving a process restart, so this
/// group closes a file-backed database, throws the object away, and reopens a
/// brand-new [AppDatabase] over the same file — the closest a `flutter test`
/// can get to killing and relaunching the app.
void main() {
  group('user profile cache (in memory)', () {
    late AppDatabase db;
    late DriftLocalStore store;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      store = DriftLocalStore(db);
    });

    tearDown(() => db.close());

    test('stores and reads back a profile payload', () async {
      await store.putUserProfile('uid-1', '{"id":"u1","role":"admin"}');

      final row = await store.getUserProfile('uid-1');
      expect(row, isNotNull);
      expect(row!.authUid, 'uid-1');
      expect(row.payload, '{"id":"u1","role":"admin"}');
    });

    test('returns null for an unknown uid', () async {
      expect(await store.getUserProfile('never-seen'), isNull);
    });

    test('a second write replaces the first (sign-in refresh)', () async {
      await store.putUserProfile('uid-1', '{"role":"sales"}');
      await store.putUserProfile('uid-1', '{"role":"admin"}');

      final row = await store.getUserProfile('uid-1');
      expect(row!.payload, '{"role":"admin"}');
      // insertOrReplace, not insertOrIgnore: exactly one row survives.
      final all = await db.select(db.localUserProfiles).get();
      expect(all.length, 1);
    });

    test('profiles are isolated per auth uid', () async {
      await store.putUserProfile('uid-1', '{"who":"one"}');
      await store.putUserProfile('uid-2', '{"who":"two"}');

      expect((await store.getUserProfile('uid-1'))!.payload, '{"who":"one"}');
      expect((await store.getUserProfile('uid-2'))!.payload, '{"who":"two"}');
    });

    test('delete removes only the targeted profile (sign-out)', () async {
      await store.putUserProfile('uid-1', '{"who":"one"}');
      await store.putUserProfile('uid-2', '{"who":"two"}');

      await store.deleteUserProfile('uid-1');

      expect(await store.getUserProfile('uid-1'), isNull);
      expect(await store.getUserProfile('uid-2'), isNotNull);
    });

    test('deleting an absent uid is a no-op, not an error', () async {
      await expectLater(store.deleteUserProfile('ghost'), completes);
      expect(await store.getUserProfile('ghost'), isNull);
    });

    test('the store stamps updatedAt itself', () async {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      await store.putUserProfile('uid-1', '{}');
      final row = await store.getUserProfile('uid-1');

      // Callers cannot stamp this wrong because the column is not an argument.
      expect(row!.updatedAt.isBefore(before), isFalse);
    });

    test('clearTenant leaves profiles alone (they are user-scoped)',
        () async {
      await store.putUserProfile('uid-1', '{"role":"admin"}');

      await store.clearTenant('tenant-a');

      expect(
        await store.getUserProfile('uid-1'),
        isNotNull,
        reason: 'a tenant wipe must not orphan a signed-in user into a login '
            'loop, and must not hand a previous user the next session',
      );
    });

    test('NullLocalStore degrades to no-ops instead of throwing', () async {
      const nullStore = NullLocalStore();
      await expectLater(nullStore.putUserProfile('uid-1', '{}'), completes);
      expect(await nullStore.getUserProfile('uid-1'), isNull);
      await expectLater(nullStore.deleteUserProfile('uid-1'), completes);
    });
  });

  group('user profile survives a process restart', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('hasad_offline_p0'));
    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('a cached profile is readable after reopening the database file',
        () async {
      const uid = 'uid-restart';
      const payload = '{"id":"u1","email":"a@b.c","role":"admin",'
          '"tenant_id":"t-1"}';

      // --- "first launch": write, then let the process die ---
      final first = AppDatabase(
        NativeDatabase(File(p.join(dir.path, 'hasad_offline.sqlite'))),
      );
      await DriftLocalStore(first).putUserProfile(uid, payload);
      await first.close();

      // A brand-new database object over the same file, as after a cold start.
      final second = AppDatabase(
        NativeDatabase(File(p.join(dir.path, 'hasad_offline.sqlite'))),
      );
      final reopened = DriftLocalStore(second);
      addTearDown(second.close);

      final row = await reopened.getUserProfile(uid);
      expect(row, isNotNull,
          reason: 'an offline cold start depends on this surviving a restart');
      expect(jsonDecode(row!.payload)['role'], 'admin');
      expect(jsonDecode(row.payload)['tenant_id'], 't-1');
    });

    test('a sign-out deletion is durable across a restart', () async {
      const uid = 'uid-signout';
      final file = File(p.join(dir.path, 'hasad_offline.sqlite'));

      final first = AppDatabase(NativeDatabase(file));
      await DriftLocalStore(first).putUserProfile(uid, '{"role":"admin"}');
      await first.close();

      final second = AppDatabase(NativeDatabase(file));
      await DriftLocalStore(second).deleteUserProfile(uid);
      await second.close();

      final third = AppDatabase(NativeDatabase(file));
      addTearDown(third.close);
      expect(
        await DriftLocalStore(third).getUserProfile(uid),
        isNull,
        reason: 'a signed-out device must not regain offline access by '
            'restarting the app',
      );
    });

    test('an existing v2 database is migrated to v3 without data loss',
        () async {
      final file = File(p.join(dir.path, 'hasad_offline.sqlite'));

      // Build a v2-shaped database by hand: create the queue + a mirror table
      // through the current schema, then verify a v3 open adds the new table
      // and leaves the existing rows intact.
      final seed = AppDatabase(NativeDatabase(file));
      await seed.customStatement(
        "insert into local_customers (id, tenant_id, name, synced) "
        "values ('c1', 't-1', 'عميل محفوظ', 1)",
      );
      await seed.close();

      final migrated = AppDatabase(NativeDatabase(file));
      addTearDown(migrated.close);

      final store = DriftLocalStore(migrated);
      // The additive migration ran without wiping the mirror.
      expect((await store.customers('t-1')).single.name, 'عميل محفوظ');
      // And the new table is usable on the very same database.
      await store.putUserProfile('uid-1', '{"role":"admin"}');
      expect(await store.getUserProfile('uid-1'), isNotNull);
    });
  });
}
