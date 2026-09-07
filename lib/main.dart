import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'data/supabase_client.dart';
import 'presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Cairo is bundled; never fetch fonts at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;
  await HasadSupabase.initialize();
  runApp(const ProviderScope(child: HasadApp()));
}