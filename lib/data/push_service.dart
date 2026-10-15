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
import '../utils/link_out.dart';

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _started = false;

  /// Call once from main() AFTER Supabase.initialize. Safe to call again.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      if (Platform.isIOS) {
        // iOS is configured NATIVELY in AppDelegate (FirebaseApp.configure from
        // GoogleService-Info.plist) so APNs registration happens at launch;
        // here we just bind to that existing default app.
        await Firebase.initializeApp();
      } else {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
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
        // initialSession = restored session on app relaunch — must register
        // there too, not only on fresh sign-ins (APNs token often isn't
        // ready during the very first post-permission attempt).
        final signedIn = state.event == AuthChangeEvent.signedIn ||
            (state.event == AuthChangeEvent.initialSession &&
                state.session != null);
        if (signedIn) unawaited(_register());
      });
      FirebaseMessaging.instance.onTokenRefresh.listen(_save);

      // Tap-through: a notification carries the story's publisher link in
      // data.link — open it in the in-app browser, exactly like tapping the
      // story's card in the feed.
      FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _openFromMessage(initial);
    } catch (e) {
      debugPrint('push: init skipped ($e)');
    }
  }

  bool _registering = false;

  Future<void> _register() async {
    if (_registering) return;
    _registering = true;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      // iOS: the FCM token derives from the APNs token, which can lag well
      // behind the permission grant — wait patiently, then retry getToken
      // itself (it throws "apns-token-not-set" when called too early).
      if (Platform.isIOS) {
        for (var i = 0; i < 15; i++) {
          final apns = await FirebaseMessaging.instance.getAPNSToken();
          if (apns != null) break;
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
      for (var i = 0; i < 3; i++) {
        try {
          final token = await FirebaseMessaging.instance.getToken();
          if (token != null) {
            await _save(token);
            return;
          }
        } catch (e) {
          debugPrint('push: getToken attempt ${i + 1} failed ($e)');
        }
        await Future<void>.delayed(const Duration(seconds: 3));
      }
    } catch (e) {
      debugPrint('push: register skipped ($e)');
    } finally {
      _registering = false;
    }
  }

  void _openFromMessage(RemoteMessage message) {
    final link = message.data['link'];
    if (link is String && link.isNotEmpty) {
      // Small delay so the app shell finishes building on cold start.
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        openArticle(link);
      });
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
