import 'local_database.dart';

/// The sqlite file name inside the directory. MUST match the native variant's.
const kLocalDatabaseFileName = 'hasad_offline.sqlite';

/// Web (dev-only) fallback: drift native is unavailable, so no store exists.
Future<AppDatabase?> openAppDatabase({String? overrideDirectory}) async => null;

/// Web (dev-only) fallback: there is no sqlite file to reset.
Future<String?> localDatabasePath({String? overrideDirectory}) async => null;

/// Web (dev-only) fallback: nothing to delete.
Future<void> resetLocalDatabase({String? overrideDirectory}) async {}