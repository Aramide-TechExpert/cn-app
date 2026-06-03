# Auth Setup (Flutter)

Email/password works as soon as Supabase is configured. **Google** needs the
provider enabled in Supabase **and** a deep-link registered in the native
platforms (added after `flutter create`). Apple comes later (Apple Developer
membership + macOS/Xcode).

The Google provider itself is already configured in this Supabase project (done
during the RN build). What's left for Flutter is the **redirect deep link**.

## Redirect
- App auth redirect (in `lib/data/auth_controller.dart`): `clustez://login-callback`
- Add it to **Supabase → Authentication → URL Configuration → Redirect URLs**.

## Android — register the scheme
After `flutter create`, add an intent-filter to
`android/app/src/main/AndroidManifest.xml` inside the main `<activity>`:
```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="clustez" android:host="login-callback" />
</intent-filter>
```

## iOS — register the scheme
In `ios/Runner/Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>clustez</string></array>
  </dict>
</array>
```

## Run
```bash
flutter run --dart-define-from-file=env.json
```
Then **You → Sign in → Continue with Google** opens the browser, returns to the
app via the deep link, and `supabase_flutter` completes the session.

> The Google **client/secret** and the Supabase callback
> (`https://rrxqvbpgfpaesitmgonc.supabase.co/auth/v1/callback`) are already set
> from the RN setup — no need to redo Google Cloud.
