import 'dart:io' show Platform;

/// Runtime config, injected via `--dart-define-from-file=env.json`.
/// The anon key is client-safe (RLS is the boundary); never put secrets here.
class Config {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    // New Vercel account (old clustez.vercel.app paused 2026-06-12).
    // Stable production alias of the arahm-s-projects/clustez deployment.
    defaultValue: 'https://clustez-mu.vercel.app/api/v1',
  );

  /// Google OAuth clients for NATIVE in-app sign-in (signInWithIdToken — no
  /// browser round-trip). Web client = the one in Supabase's Google provider
  /// (the id-token audience); iOS client = created in the same Google Cloud
  /// project. NOTE: the iOS OAuth client was registered for the old bundle id
  /// (app.clustez.clustez) — it must be updated/recreated for com.clusternews.app.
  static const String googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const String googleIosClientId =
      String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Android needs no client id in code — its OAuth client is discovered by
  /// package name + signing SHA-1 registered in the Google Cloud project.
  static bool get hasNativeGoogle =>
      googleWebClientId.isNotEmpty &&
      (!Platform.isIOS || googleIosClientId.isNotEmpty);
}
