# Cluster News — Flutter App

Cluster News (formerly Clustez) is a Flutter news aggregation app for iOS and
Android. This is the mobile client. The backend lives in the private `clustez`
repo (Node/TypeScript, Next.js, Supabase, Vercel).

## Repos
- **This app:** `Aramide-TechExpert/cn-app` (PUBLIC on GitHub — free macOS CI)
- **Backend:** `Aramide-TechExpert/clustez` (private; use `github.com` alias)
- GitHub account: **Aramide-TechExpert** — never use stackdbase accounts here

## Current state (as of 2026-11-19)
- **TestFlight build 40** in CI pipeline (just pushed); build 39 confirmed good
  by owner on device
- Both iOS (TestFlight) and Android (Play internal track) ship from CI
- Flutter **pinned to 3.32.8 / Dart 3.8.1** at `~/development/flutter` (Mac);
  macOS 13 Ventura cannot run later Flutter — do NOT upgrade past 3.32
- For iOS deploy on Mac, flutter run is dead (Xcode 15.2 vs iOS 26.6);
  use: `flutter build ios` → IPA → `pymobiledevice3` install

## ⚠️ Critical rule — Feed tab is untouchable
**NEVER modify `DiscoverPage` (`lib/features/discover/discover_page.dart`) for
push notification landings.** A previous attempt (v4, commit `cbc4321`) routed
push landings onto the real `DiscoverPage` with pinned stories — it broke the
Feed tab on device (heading slides gone, feed not repopulating, one story stuck
as the hero). It was reverted immediately (commit `8082fa6`).

Root cause: a landing stacked inside the Feed shell branch persists on the branch
stack — switching tabs and back shows it again. Any push landing that modifies
`DiscoverPage` risks the owner's most-guarded screen.

**Rule:** iterate push landings ONLY on screens outside `DiscoverPage`. The
`/story/:id` and `/digest` routes already handle this correctly.

## Push notification landing (current — v5 / build 40)
- **Single push** → `/story/:id` → `StoryPage` (top-level route, outside shell):
  renders via `newsFeedCard(0, article)` = Feed Overlay hero, then "Continue
  reading" CTA, Full Coverage row, MORE NEWS via `planFeedRows` + `newsFeedCard`
- **Digest (multi-push)** → `/digest?ids=` → `DigestPage` (inside Feed shell branch,
  stacks over `/discover` so footer nav stays): renders via `planFeedRows` +
  `newsFeedCard` + `feedPairRow` — identical to the Feed tab

## Feed template — single source of truth
`lib/features/feed/widgets/feed_pattern.dart` contains ALL card logic:
- `newsFeedCard(i, article)` — Feed tab's card cycle (Overlay hero at i=0, then
  Wide/Default/Overlay/Split/Magazine/Split at i%6)
- `planFeedRows(items)` — groups into singles + periodic 2-up compact pairs
- `feedPairRow(context, row)` — the 2-up pair widget
- `newsFeedFlushBelow(rows, i)` — band gap decision

**All story-list surfaces must use this template** (owner ruling 2026-10-27).
Never introduce a bespoke card cycle on any new surface — add new surfaces to
`feed_pattern.dart` instead.

## Architecture
```
lib/
├─ main.dart / app.dart / config.dart
├─ router.dart          ← GoRouter: 5-tab StatefulShellRoute + top-level routes
├─ theme/               tokens (ClusterNewsColors ThemeExtension) + AppText
├─ models/              Article, FeedPage, StoryCluster, TrendingTopic
├─ data/                api_client (Dio → /api/v1) + Riverpod providers:
│                       feed · auth · engagement · discover · saved · watch
├─ utils/               format · link_out · interleave · source_regions
└─ features/
   ├─ shell/            ScaffoldWithNav (5-tab footer)
   ├─ feed/             HomePage (tab 1) + StackFeedPage (Reel tab 3)
   │   └─ widgets/      feed_pattern · card_variants · overlay_card · magazine_card
   ├─ discover/         DiscoverPage (Feed tab 2) + ClusterDetailPage + TopicPage
   ├─ story/            DigestPage (multi-push) + StoryPage (single-push)
   ├─ briefing/         BriefingPage (tab 5)
   ├─ clusters/         ClustersPage (tab 4)
   ├─ auth/             SignInPage
   ├─ onboarding/       OnboardingPage + SetupFlowPage (hard-gated on signup)
   └─ you/ saved/ search/ settings/ alerts/ insights/ ...
```

## Router rules (router.dart)
- **Shell branches** (footer visible): `/` Home, `/discover` Feed, `/stack` Reel,
  `/clusters` + `/cluster/:id`, `/briefing`
- **Top-level routes** (no footer): `/story/:id`, `/sign-in`, `/search`, `/saved`,
  `/settings`, `/you`, `/interests`, `/watchlists`, `/alerts`, `/topic/:slug`, `/setup`
- `/digest` lives INSIDE the Feed shell branch (stacks over `/discover`) — footer
  stays visible per owner ruling 2026-10-27
- Hard setup gate in `redirect`: signed-in users without `setup_complete=true`
  are always routed to `/setup`

## State management
Riverpod throughout. Key providers:
- `feedControllerProvider` — the Feed tab's article list
- `engagementProvider` — likes + bookmarks (Supabase RLS, keyed by `dbId`)
- `apiClientProvider` — `ApiClient` (Dio, talks to `/api/v1`)
- `currentUserProvider` — Supabase auth user

## Backend connection
- API base URL set via `--dart-define-from-file=env.json`
  (`{"API_BASE_URL": "https://..."}`)
- Supabase keys also in `env.json`
- Backend repo `clustez` → `almanac/` for living docs

## CI / TestFlight
See `CI.md` and `IOS_TESTFLIGHT.md`. CI runs on GitHub Actions (macOS runner,
free because repo is public). Every push to `main` triggers a build. Tell the
owner the build number when asking them to test — TestFlight processing lag
means they may still be on the previous build.

## Key decisions / gotchas
- `hasPlayableVideo` ≠ `hasVideo` — only `hasPlayableVideo` is safe for inline play
- `throttleVideoCards` caps video cards at ~1 per 10 items to prevent autoplay
  overload
- `_worldwideFlagships` Dart set + `source_overrides` Supabase table enforce major
  outlet presence on the default Worldwide feed without user preferences
- `viaEdge` transport lane (Supabase Edge Function) proxies WaPo feeds
- Mac browser lane (Playwright + launchd) handles USAT/ESPN; if owner's Mac is
  off for days, those sources go dark temporarily
- Supabase `missing_urls(urls text[])` RPC keeps egress at ~0.9 MB/run (was 2 MB+)
