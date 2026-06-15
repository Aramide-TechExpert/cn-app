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

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
