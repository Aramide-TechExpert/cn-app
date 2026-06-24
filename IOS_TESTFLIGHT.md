# iOS testing via cloud build → TestFlight

Ventura (macOS 13) can't run current Xcode/iOS-18 tooling, so we build iOS in the
cloud (`.github/workflows/ios-testflight.yml`, a `macos-15` runner with Xcode 16 +
iOS 18 SDK) and deliver to the iPhone through **TestFlight**. No local Xcode,
CocoaPods, or macOS upgrade needed — the Ventura machine just pushes code.

## One-time setup (your side, in Apple's portals)

0. **Paid Apple Developer Program** — https://developer.apple.com/programs/ ($99/yr).
   **Required** — TestFlight/ad-hoc cloud delivery does not work on a free account.
1. **Register the bundle id** `app.clustez.clustez` — Developer portal →
   Certificates, IDs & Profiles → Identifiers → +.
2. **Create the app record** — App Store Connect → Apps → + → New App, pick the
   `app.clustez.clustez` bundle id, name "Clustez".
3. **App Store Connect API key** — App Store Connect → Users and Access → Integrations
   → App Store Connect API → + → role **App Manager** (or Admin). Download the
   `AuthKey_XXXXXX.p8` (one-time download). Note the **Key ID** and **Issuer ID**.
4. **Team ID** — Developer portal → Membership → 10-character Team ID.

## GitHub secrets to add
Repo → Settings → Secrets and variables → Actions → New repository secret:

| Secret | Value |
| --- | --- |
| `ASC_KEY_ID` | the API key's Key ID |
| `ASC_ISSUER_ID` | the API key's Issuer ID |
| `ASC_API_KEY_P8` | `base64 -i AuthKey_XXXX.p8` output (whole thing) |
| `APPLE_TEAM_ID` | your 10-char Team ID |

To base64 the key on the Mac: `base64 -i ~/Downloads/AuthKey_XXXX.p8 | pbcopy`.

## Run it
Actions → **iOS TestFlight** → Run workflow. It builds, signs (automatic cloud
signing via the API key), and uploads. After ~10–15 min the build appears in
TestFlight → install the **TestFlight** app on the iPhone, accept the invite, and
the build installs. Every push of new card-style work → re-run → updated build.

First runs often need 1–2 tweaks (signing/provisioning quirks) — normal for iOS CI.
