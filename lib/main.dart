import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config.dart';
import 'data/api_client.dart';
import 'data/reading_history.dart';
import 'utils/source_regions.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ReadingHistory.init();

  // Supabase = channel 1 (auth + direct RLS data). Only the anon key is used
  // here; RLS is the security boundary. Skipped gracefully if unconfigured.
  if (Config.hasSupabase) {
    await Supabase.initialize(
      url: Config.supabaseUrl,
      anonKey: Config.supabaseAnonKey,
    );
  }

  // Merge Control-panel classifier deltas over the built-in gate — fire
  // and forget; offline keeps the compiled-in classifier.
  ApiClient()
      .sourceMap()
      .then(applyServedSourceMap)
      .catchError((_) {});

  runApp(const ProviderScope(child: ClustezApp()));
}
