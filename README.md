# Clustez (Flutter)

Native **iOS + Android** app for Clustez — a news-intelligence reader
(link-out model: cards open the publisher's page; article bodies are never
reproduced). **Flutter/Dart** is the primary native stack; the React Native app
(`clustez-mobile`) is kept for **web**. Backend (the `/api/v1` layer + Supabase
+ content pipeline) is shared and unchanged — Flutter talks to the exact same
backend the RN app did.

> **Authored ahead of the SDK.** This `lib/` was hand-written before Flutter was
> installed, so it hasn't been compiled yet. Finishing setup (below) runs
> `flutter pub get` + `flutter analyze`, which will surface anything to fix.

## Finish setup (once Flutter is installed)
```bash
cd ~/Projects/clustez-flutter
# 1. Generate the native platform folders (does NOT touch lib/)
flutter create --platforms=android,ios --org app.clustez --project-name clustez .
# 2. Resolve dependencies
flutter pub get
# 3. Sanity check
flutter analyze
# 4. Run (inject config; anon key is client-safe)
flutter run --dart-define-from-file=env.json
```
`env.json` (gitignored) is already filled with the Supabase URL + anon key and
the `/api/v1` base. See `env.example.json`.

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
├─ theme/             tokens (ClustezColors ThemeExtension) + app_theme
├─ models/            Article + FeedPage (fromJson, mirrors /api/v1)
├─ data/              api_client (dio) + feed_controller (Riverpod)
├─ utils/             format (timeAgo/readTime/monogram) + link_out
└─ features/
   ├─ feed/          home_page + widgets/article_card  ← BUILT
   └─ shell/         scaffold_with_nav + placeholder_page
```

## Status
- **Built:** design system, `Article`/`FeedPage` models, `/api/v1` client,
  Riverpod feed controller (keyset infinite pagination), **Home feed**
  (infinite scroll + pull-to-refresh + link-out), 5-tab navigation shell.
- **Stubs:** Discover · Watch · Saved · You (placeholder screens).
- **Next:** `pub get`/analyze pass · auth (`supabase_flutter` + Google/email) ·
  likes/bookmarks (direct Supabase, keyed by `dbId`) · Discover/clusters ·
  Android APK + public release link.
