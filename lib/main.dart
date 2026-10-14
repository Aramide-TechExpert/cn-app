import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config.dart';
import 'data/api_client.dart';
import 'data/reading_history.dart';
import 'data/refresh.dart';
import 'utils/remote_settings.dart';

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

  // Merge Control-panel classifier deltas + remote product settings over
  // the compiled-in defaults — fire and forget; offline keeps defaults.
  // (Also re-fetched on every foreground resume — see app.dart.)
  final api = ApiClient();
  unawaited(fetchAndApplyRemoteConfig(api));
  // Version telemetry for the Control panel's min-version gate.
  api.reportVersion(
    appVersion,
    defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
  );

  runApp(const ProviderScope(child: ClusterNewsApp()));
}
