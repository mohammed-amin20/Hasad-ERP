import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_factory.dart';
import 'package:path/path.dart' as p;

/// P0 issue 6 — the cold-start collapse's second half: `localStoreProvider`
/// used to resolve a failed open to `NullLocalStore`, which made every offline
/// screen quietly empty after a restart. These tests pin the loud-failure
/// contract of `openLocalStore`:
///
/// - A corrupt `hasad_offline.sqlite` must throw [LocalStoreOpenException] so
///   the app gate renders the repair UI — never a silent no-op store.
/// - A fresh (empty) directory still opens a working store (the probe query
///   materializes the schema without tripping the failure path).
/// - `resetLocalDatabase` deletes the on-disc file so the repair UI can wipe
///   and re-open a fresh database after the user confirms.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('hasad_store_open'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('a corrupt sqlite file fails loudly (LocalStoreOpenException, '
      'never a silent NullLocalStore)', () async {
    File(p.join(dir.path, kLocalDatabaseFileName))
        .writeAsBytesSync([1, 2, 3, 4, 5, 6, 7, 8]);

    await expectLater(
      openLocalStore(overrideDirectory: dir.path),
      throwsA(isA<LocalStoreOpenException>()),
    );
  });

  test('a fresh directory opens a working store and materializes the schema',
      () async {
    final store = await openLocalStore(overrideDirectory: dir.path);

    expect(store.isAvailable, isTrue);
    // the probe ran, so the tables exist and are queryable
    await expectLater(store.customers('tenant-x'), completion(isEmpty));

    await store.dispose();
  });

  test('resetLocalDatabase deletes the on-disc sqlite file', () async {
    final file = File(p.join(dir.path, kLocalDatabaseFileName));

    final store = await openLocalStore(overrideDirectory: dir.path);
    expect(await file.exists(), isTrue);

    // release the connection first (desktop hosts cannot delete an open file)
    await store.dispose();
    await resetLocalDatabase(overrideDirectory: dir.path);

    expect(await file.exists(), isFalse);
  });
}