/// Device push registration — FCM token → Supabase `device_push_tokens`.
///
/// Flow: once a user is signed in we ask for notification permission, fetch
/// the FCM token, and upsert it (keyed on the token) with the user id and
/// platform. The breaking-news cron on the backend fans out to every row via
/// FCM HTTP v1. Tokens are best-effort end to end: any failure here must
/// never block or crash the app.
library;

import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../firebase_options.dart';

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _started = false;

  /// Call once from main() AFTER Supabase.initialize. Safe to call again.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // iOS: show the system banner even when the app is foregrounded
      // (Android foreground messages are intentionally silent for now).
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final auth = Supabase.instance.client.auth;
      if (auth.currentSession != null) unawaited(_register());
      auth.onAuthStateChange.listen((state) {
        if (state.event == AuthChangeEvent.signedIn) unawaited(_register());
      });
      FirebaseMessaging.instance.onTokenRefresh.listen(_save);
    } catch (e) {
      debugPrint('push: init skipped ($e)');
    }
  }

  Future<void> _register() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      // iOS: the FCM token derives from the APNs token, which can lag a
      // moment after permission — poll briefly instead of failing.
      if (Platform.isIOS) {
        for (var i = 0; i < 5; i++) {
          final apns = await FirebaseMessaging.instance.getAPNSToken();
          if (apns != null) break;
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _save(token);
    } catch (e) {
      debugPrint('push: register skipped ($e)');
    }
  }

  Future<void> _save(String token) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      await Supabase.instance.client.from('device_push_tokens').upsert({
        'user_id': user.id,
        'fcm_token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'fcm_token');
    } catch (e) {
      debugPrint('push: token save failed ($e)');
    }
  }
}
