import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import 'push_service.dart';

/// Deep-link the OAuth redirect returns to (web-browser OAuth FALLBACK only —
/// the primary Google path is native signInWithIdToken, no browser). Must be
/// allow-listed in Supabase (Authentication → URL Configuration) AND
/// registered as a URL scheme in the native platform config.
const String kAuthRedirect = 'clusternews://login-callback';

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
  Future<bool> signUpWithEmail(String email, String password,
      {String? displayName}) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        if (displayName != null && displayName.isNotEmpty)
          'display_name': displayName,
      },
    );
    // Supabase anti-enumeration: signing up an EXISTING email "succeeds"
    // with a user that has no identities — surface the truth instead of a
    // bogus "check your inbox" (which sends no email and dead-ends the user).
    if (res.user != null && (res.user!.identities?.isEmpty ?? false)) {
      throw const AuthException(
          'This email already has an account. Sign in instead.');
    }
    return res.session != null;
  }

  /// Merge keys into the user's metadata (display_name, preferred_sources,
  /// alert prefs, setup_complete…) — synced across devices by Supabase auth.
  Future<void> updateProfile(Map<String, dynamic> data) async {
    await _client.auth.updateUser(UserAttributes(data: data));
  }

  /// NATIVE in-app Google sign-in: the iOS account sheet produces an id
  /// token that Supabase verifies directly (signInWithIdToken) — no browser,
  /// no redirect round-trip. Falls back to browser OAuth only when the
  /// native client ids aren't configured. Requires "skip nonce check" ON in
  /// Supabase's Google provider (Google's iOS SDK owns the nonce).
  Future<void> signInWithGoogle() async {
    if (!Config.hasNativeGoogle) {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kAuthRedirect,
      );
      return;
    }
    // iOS identifies via its own client id; Android resolves its OAuth client
    // by package + SHA-1, so only the web (audience) id is passed there.
    final google = GoogleSignIn(
      clientId: Platform.isIOS ? Config.googleIosClientId : null,
      serverClientId: Config.googleWebClientId,
    );
    final account = await google.signIn();
    if (account == null) return; // user dismissed the sheet
    final tokens = await account.authentication;
    final idToken = tokens.idToken;
    if (idToken == null) {
      throw const AuthException(
          'Google did not return an ID token. Please try again.');
    }
    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: tokens.accessToken,
    );
  }

  Future<void> signOut() async {
    // Release the device push token FIRST (needs the live session to prove
    // ownership) — otherwise this device keeps getting the signed-out
    // account's pushes until another account claims it.
    await PushService.instance.unregister();
    await _client.auth.signOut();
  }
}
