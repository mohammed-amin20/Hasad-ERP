import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/supabase_client.dart';
import 'presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HasadSupabase.initialize();
  runApp(const ProviderScope(child: HasadApp()));
}
