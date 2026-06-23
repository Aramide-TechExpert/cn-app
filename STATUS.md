# Clustez Flutter — Migration & Status

> Snapshot of the RN→Flutter pivot and where `clustez-flutter` stands.
> Companion to `README.md` (how to run) and `AUTH_SETUP.md` (providers).

## The pivot
Native mobile (iOS + Android) moved from **React Native/Expo → Flutter/Dart**
(team decision: native is the earnings priority). The RN app (`clustez-mobile`)
is **kept for web** and parked on branch `rn-native-v1`. The **backend is
unchanged and shared** — both clients talk to the same `/api/v1` + Supabase +
content pipeline (Next.js, in the private `Cluster` repo).

## What carried over vs. rebuilt
| Carried over 100% | Rebuilt in Dart |
| --- | --- |
| `/api/v1` backend (+ `dbId`/RLS) | All UI (screens + widgets) |
| Supabase data model + pipeline | Design tokens → `ClustezColors` ThemeExtension |
| 5-tab IA + design language | Models → Dart classes w/ `fromJson` |
| Link-out content model | Auth wiring → `supabase_flutter` |
| Feature set / UX decisions | State → Riverpod; nav → go_router |

## Architecture
```
lib/
├─ main.dart / app.dart / config.dart / router.dart
├─ theme/      tokens (ClustezColors) + app_theme (ThemeData, AppText)
├─ models/     Article, FeedPage, StoryCluster, TrendingTopic, ClusterDetail
├─ data/       api_client (dio /api/v1) + Riverpod controllers:
│              feed · auth · engagement · discover · watch · saved
├─ utils/      format · link_out · video
└─ features/   feed · discover · watch · saved · you · auth · shell
```
- **Channel 1 (Supabase direct, RLS):** auth + likes/bookmarks (keyed by `dbId`).
- **Channel 2 (`/api/v1`):** feed, clusters, trending, article, category feed.

## Status — v1 feature-complete (built offline, UNVERIFIED)
✅ Home feed · Discover + cluster/topic detail · Watch · Saved · You + auth
(email/password + Google) · likes/bookmarks · light/dark theming.

⚠️ **Authored ahead of the Flutter SDK** — not yet compiled. The first
`flutter analyze` is the source of truth; expect minor nits to clean up.

## Resume checklist (needs network + SDK)
1. Install Flutter (`~/development/flutter`, git clone stable) → `flutter doctor`.
2. `flutter create --platforms=android,ios --org app.clustez --project-name clustez .`
3. `flutter pub get` → **`flutter analyze`** → fix nits.
4. Add the `clustez://login-callback` deep link (Android manifest + iOS plist;
   see `AUTH_SETUP.md`) + allow-list it in Supabase.
5. `flutter run --dart-define-from-file=env.json` — verify Home feed + Google.
6. Push to a new public `clustez-flutter` repo.
7. Build Android APK → public GitHub Release (like RN v1).

## Deferred / next (after verification)
- Apple sign-in (needs Apple Developer membership + macOS/Xcode).
- Push notifications (Expo Push was RN-only → FCM/APNs via a Flutter plugin).
- Inline video players in Watch (currently link-out only).
- Offline persistence for Saved.
- Backend `dbId` change is committed in `Cluster` but **not deployed** — deploy
  it so likes/bookmarks light up (buttons show only when `dbId` is present).
- iOS build needs Xcode (not installed) + the parked Apple membership.

## Commit history (local, not pushed)
scaffold → auth → likes/bookmarks → Discover → Watch+Saved → self-review fix.

## Card-style parity pass (2026-06-23)
Audited web card/header/media components vs Flutter; ported the gaps the web feed
had that the app lacked. All verified via CI analyze (0 new issues).
- **Autoplay/loop spotlight header** (`spotlight_carousel.dart`) — 6s auto-advance,
  seamless loop, pause-on-touch + app-lifecycle pause, play/pause control, Ken
  Burns zoom (web HeroCarousel parity). Lands on the Home dashboard.
- **Card micro-features** (`card_extras.dart`) — animated pulsing `LiveBadge`,
  `GainingAttention` (comment-velocity), reading-time image overlay, `EngagementBar`
  (comment count + spring-animated like/bookmark). Wired into Default/Wide/Video/
  Magazine cards.
- **News Feed dynamic rhythm** (`discover_page.dart`) — replaced the thin 4-card
  logic with a position+trait cadence cycling Wide/Magazine/Overlay/Default/Video/
  Featured, plus skeleton (shimmer) loading and fade+slide card entry.
- **Motion/polish** — `FadeSlideIn` entry, `Shimmer`/`SkeletonCard` loaders, spring
  like/bookmark pops.
- **Bento mosaic** (`bento_mosaic.dart`) — overflow-safe 2-up "Top stories" grid in
  a fitted slot on Home.
Not ported (intentional): real inline video playback (still icon-overlay only;
YouTube/Vimeo ingestion was removed). Visual on-device check pending the local SDK.
