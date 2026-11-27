# Cluster News Flutter — Live Status

> Last updated: 2026-11-19. This is the authoritative "where are we" document.
> Read CLAUDE.md first (architecture, critical rules, repo map).

## App is LIVE

- **iOS:** TestFlight, build 40 in CI pipeline (build 39 confirmed good on device)
- **Android:** Play Store internal track
- **Bundle ID:** `com.clusternews.app`
- **GitHub repo:** `Aramide-TechExpert/cn-app` (PUBLIC — free macOS CI minutes)
- **CI:** GitHub Actions, every push to `main` triggers TestFlight + Play build
- Always tell the owner the build number when asking him to test — TestFlight
  processing lag means he may still be on the previous build

## Repo map (which repos are active vs parked)

| Repo | Status | What it is |
|---|---|---|
| `Aramide-TechExpert/cn-app` | **ACTIVE** | This Flutter app (iOS + Android) |
| `Aramide-TechExpert/clustez` | **ACTIVE** | Backend (Node/TS, Vercel, Supabase pipeline) |
| `Aramide-TechExpert/clustez-pipeline` | **ACTIVE** | GitHub Actions content pipeline (hourly cron, separate public repo) |
| `Aramide-TechExpert/clustez-mobile` | **PARKED** | Old React Native app — superseded by Flutter; web may eventually retire too |

## What's working

### Content pipeline (backend)
- Supabase egress resolved — `missing_urls(urls text[])` RPC keeps dedup at
  ~0.9 MB/run (was 2 MB+), well inside the 5 GB free tier
- Major outlets flowing: BBC, CNN, NYT, WaPo (viaEdge Supabase proxy), Forbes,
  Politico, Guardian, Bloomberg, FT, WSJ, Reuters (via GDELT), AP (via GDELT),
  USAT/ESPN (Mac browser lane via Playwright + launchd)
- GDELT wire lane: covers AP/Reuters syndication stories (not direct feeds)
- Mac browser lane: Playwright headless Chrome on owner's Mac via launchd plist;
  if the Mac is off for days, USAT/ESPN go dark temporarily
- Excerpts: og:description fallback fills most cards
- Default feed: `WORLDWIDE_FLAGSHIPS` server set + `source_overrides` Supabase table
  enforce major outlets on the Worldwide feed without user preferences

### App features (all live)
- 5-tab shell: Home · Feed · Reel · Clusters · Briefing
- Push notifications: digest (multi-story) + single-story landings
- Auth: email + Google sign-in, hard setup gate on signup
- Likes, bookmarks (Supabase RLS, keyed by `dbId`)
- Light/dark theme, feed card rhythm, cluster detail, topic pages
- Onboarding + preferences flow (region scopes, favourite sources)

## Push notification landings (v6 — LOCKED)

**Single source of truth: CLAUDE.md → "Push notification landings — LOCKED
templates".** Not restated here — the old split between this file and CLAUDE.md
is exactly what let the landings drift. Summary only:

**Single story** (`/story/:id` → `StoryPage`, top-level route): shared
`landingHeader` ("Top Story" + source) → big hero (`newsFeedCard(0)`, no
"Continue reading") → Full Coverage if clustered → "More News" horizontal
`CompactCard` slider (homepage Trending style) → "More to read" as **2-up compact
pairs** (no trailing big card). Footer via `LandingBottomNav`.

**Digest** (`/digest?ids=` → `DigestPage`, top-level route): shared
`landingHeader` ("N stories" + "Fresh Stories") → `planFeedRows` + `newsFeedCard`
+ `feedPairRow` — identical to the Feed tab. Footer via `LandingBottomNav`.

Locked by `test/push_landing_template_test.dart` (CI fails on drift).

## ⚠️ The Feed tab incident — permanent rule
v4 attempt (commit `cbc4321`) routed push landings onto the real `DiscoverPage`.
On device: heading slides gone, feed not repopulating, one story stuck as hero.
Reverted immediately (`8082fa6`). **Never touch `DiscoverPage` for push landings.**
Full detail in CLAUDE.md.

## Open / next items

1. **Verify build 40 on TestFlight** — StoryPage redesign (v5); owner to confirm
   single-push landing looks correct
2. **AP/Reuters direct feeds** — still blocked (syndication-only); GDELT wire lane
   is the current workaround; no alternative found yet
3. **Mac browser lane resilience** — USAT/ESPN break if Mac is off; a cloud
   alternative was investigated but nothing free/reliable found; parked
4. **Store listings** — both Apple (P3H8DJ2SKU) and Google (5505414752076513868)
   org accounts verified; app records + screenshots + store descriptions pending
5. **GitHub Copilot handoff** — owner asked about this; deferred for now

## Local dev (Mac only — Flutter build requires macOS)

- Flutter pinned: `~/development/flutter` (3.32.8 / Dart 3.8.1) — do NOT upgrade
- Run: `flutter run --dart-define-from-file=env.json`
- iOS deploy: `flutter build ios` → IPA → `pymobiledevice3 install <ipa>`
  (`flutter run` dead: Xcode 15.2 vs iOS 26.6)
- env.json (gitignored): `{"API_BASE_URL": "...", "SUPABASE_URL": "...", "SUPABASE_ANON_KEY": "..."}`

## Key files to know

| File | Why it matters |
|---|---|
| `lib/router.dart` | All routes; shell branch layout; setup gate |
| `lib/features/feed/widgets/feed_pattern.dart` | THE card template — all surfaces use this |
| `lib/features/story/story_page.dart` | Single-push landing (v5) |
| `lib/features/story/digest_page.dart` | Multi-push landing |
| `lib/features/discover/discover_page.dart` | Feed tab — do NOT modify for push landings |
| `lib/features/feed/stack_feed_page.dart` | Reel tab (full-screen vertical swiper) |
| `CLAUDE.md` | Architecture, critical rules, full context for any Claude session |
