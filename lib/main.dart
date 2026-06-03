import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase = channel 1 (auth + direct RLS data). Only the anon key is used
  // here; RLS is the security boundary. Skipped gracefully if unconfigured.
  if (Config.hasSupabase) {
    await Supabase.initialize(
      url: Config.supabaseUrl,
      anonKey: Config.supabaseAnonKey,
    );
  }

  runApp(const ProviderScope(child: ClustezApp()));
}
