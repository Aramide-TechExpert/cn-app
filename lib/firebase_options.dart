/// Firebase config for News Loop (project central-catcher-479022-r6).
/// Hand-derived from google-services.json / GoogleService-Info.plist so the
/// app initializes from Dart on both platforms — no google-services Gradle
/// plugin and no plist resource wiring needed. Regenerate with
/// `flutterfire configure` if the Firebase apps ever change.
library;

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
            'DefaultFirebaseOptions are only configured for iOS/Android.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAaWqr8cV0h45fCgOTxpqniZiI-3ZuTzuk',
    appId: '1:1198287548:android:7b2ffaa96b423452433eb9',
    messagingSenderId: '1198287548',
    projectId: 'central-catcher-479022-r6',
    storageBucket: 'central-catcher-479022-r6.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDvsZIGXVIZb3xTNvwe0Ds-x_cU7H7nIkw',
    appId: '1:1198287548:ios:7c3894e0ed522ee4433eb9',
    messagingSenderId: '1198287548',
    projectId: 'central-catcher-479022-r6',
    storageBucket: 'central-catcher-479022-r6.firebasestorage.app',
    iosBundleId: 'com.newsloop.app',
  );
}
