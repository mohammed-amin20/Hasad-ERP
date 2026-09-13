import 'local_database.dart';

/// Web (dev-only) fallback: drift native is unavailable, so no store exists.
Future<AppDatabase?> openAppDatabase({String? overrideDirectory}) async => null;