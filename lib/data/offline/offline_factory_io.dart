import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'local_database.dart';

/// The sqlite file name inside the directory. MUST match the web stub's.
const kLocalDatabaseFileName = 'hasad_offline.sqlite';

/// Resolves the sqlite file path (or null when the host has no native store).
Future<String?> localDatabasePath({String? overrideDirectory}) async {
  final directory =
      overrideDirectory ?? (await getApplicationDocumentsDirectory()).path;
  return p.join(directory, kLocalDatabaseFileName);
}

/// Deletes the on-disc sqlite file. Used by the destructive "Reset local data"
/// action after the user confirms — a silent auto-reset is never performed on a
/// first failure. Deleting an open file is allowed on Android (POSIX); the
/// caller (`resetLocalStore`) disposes the drift connection first so desktop
/// hosts work too.
Future<void> resetLocalDatabase({String? overrideDirectory}) async {
  final path = await localDatabasePath(overrideDirectory: overrideDirectory);
  if (path == null) return;
  final file = File(path);
  if (await file.exists()) {
    debugPrint('[offline:reset] deleting local sqlite ($path)');
    await file.delete();
  }
}

/// Opens the drift database backed by a sqlite3 file in the app documents
/// directory. Returns null when the host cannot provide sqlite3 (web dev).
///
/// A failure here is **not** silent: it is logged with the error and the path
/// that was tried, because the consequence is that `localStoreProvider`
/// resolves to `NullLocalStore` and the whole app quietly loses its offline
/// capability — which is indistinguishable from "the user has no cached data"
/// unless the reason is in the log. `overrideDirectory` exists so the file-
/// backed durability tests can point at a temp directory.
///
/// Note the open itself is lazy (`NativeDatabase.createInBackground`), so a
/// corrupt file is only detected on the first query — `openLocalStore` in
/// `local_store.dart` runs an immediate probe for exactly that reason.
Future<AppDatabase?> openAppDatabase({String? overrideDirectory}) async {
  try {
    final directory =
        overrideDirectory ?? (await getApplicationDocumentsDirectory()).path;
    final file = File(p.join(directory, kLocalDatabaseFileName));
    return AppDatabase(NativeDatabase.createInBackground(file));
  } on Object catch (error, stack) {
    debugPrint(
      '[offline:openAppDatabase] FAILED to open the local sqlite store — the '
      'app will run without any offline capability.\n'
      'directory: ${overrideDirectory ?? '<getApplicationDocumentsDirectory>'}\n'
      '$error\n$stack',
    );
    return null;
  }
}
