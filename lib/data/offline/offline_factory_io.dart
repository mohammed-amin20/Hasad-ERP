import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'local_database.dart';

/// Opens the drift database backed by a sqlite3 file in the app documents
/// directory. Returns null when the host cannot provide sqlite3 (web dev).
Future<AppDatabase?> openAppDatabase({String? overrideDirectory}) async {
  try {
    final directory =
        overrideDirectory ?? (await getApplicationDocumentsDirectory()).path;
    final file = File(p.join(directory, 'hasad_offline.sqlite'));
    return AppDatabase(NativeDatabase.createInBackground(file));
  } catch (_) {
    return null;
  }
}