import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Deep-link the OAuth redirect returns to. Must be allow-listed in Supabase
/// (Authentication → URL Configuration) AND registered as an intent-filter /
/// URL scheme in the native platform config (added after `flutter create`).
const String kAuthRedirect = 'clustez://login-callback';

final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// Emits on every sign-in/out/refresh so dependents rebuild.
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseProvider).auth.onAuthStateChange,
);

/// The current user (null = signed out). Rebuilds when [authStateProvider] ticks.
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseProvider).auth.currentUser;
});

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(supabaseProvider)),
);

class AuthService {
  AuthService(this._client);
  final SupabaseClient _client;

  Future<void> signInWithEmail(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Returns true if a session was created immediately (i.e. email confirmation
  /// is off). When confirmation is on, the caller prompts to check the inbox.
  Future<bool> signUpWithEmail(String email, String password) async {
    final res = await _client.auth.signUp(email: email, password: password);
    return res.session != null;
  }

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kAuthRedirect,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}
