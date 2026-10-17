# News reader (Flutter)

Native **iOS + Android** news-intelligence reader (link-out model: cards open
the publisher's page; article bodies are never reproduced). **Flutter/Dart** is
the primary native stack. The backend (`/api/v1` layer + Supabase + content
pipeline) lives in a separate private repo — this app is the client.

## Setup
```bash
# 1. Resolve dependencies
flutter pub get
# 2. Sanity check
flutter analyze
# 3. Run (inject config; anon key is client-safe)
flutter run --dart-define-from-file=env.json
```
`env.json` (gitignored) holds the Supabase URL + anon key and the `/api/v1`
base. See `env.example.json`.

## Stack
- **Flutter** (Material 3) · **Riverpod** (state) · **go_router** (5-tab shell)
- **supabase_flutter** (auth + direct RLS data — channel 1)
- **dio** (`/api/v1` — channel 2) · **cached_network_image** · **url_launcher** (link-out)

## Layout
```
lib/
├─ main.dart            Supabase init + ProviderScope
├─ app.dart            MaterialApp.router (light/dark themes)
├─ config.dart         env via --dart-define-from-file
├─ router.dart         5-tab StatefulShellRoute
├─ theme/             design tokens (ThemeExtension) + app_theme
├─ models/            Article + FeedPage (fromJson, mirrors /api/v1)
├─ data/              api_client (dio) + feed_controller (Riverpod)
├─ utils/             format (timeAgo/readTime/monogram) + link_out
└─ features/
   ├─ feed/          home_page + widgets/article_card
   └─ shell/         scaffold_with_nav + placeholder_page
```

## CI
GitHub Actions builds and verifies everything (`flutter-ci.yml` for Android
analysis/APK, `ios-testflight.yml` for the signed iOS build) — no local
Flutter SDK required. See `CI.md` and `IOS_TESTFLIGHT.md`.
