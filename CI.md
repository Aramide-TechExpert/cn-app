# CI — Cloud APK builds & releases

`.github/workflows/android-release.yml` builds the release APK on GitHub's
runners and publishes it as a Release asset. **No local 80-min build needed.**

## One-time setup (after the repo is pushed)
Add three **repository secrets** (Settings → Secrets and variables → Actions):

| Secret | Value |
| --- | --- |
| `SUPABASE_URL` | `https://rrxqvbpgfpaesitmgonc.supabase.co` |
| `SUPABASE_ANON_KEY` | the anon key (client-safe; also in local `env.json`) |
| `API_BASE` | `https://clustez.vercel.app/api/v1` (optional — has a default) |

## Cut a release
```bash
git tag v1.0.0
git push --tags
```
The workflow runs (`flutter create` → `pub get` → analyze + test (non-blocking)
→ `flutter build apk --release`) and creates **Release `v1.0.0`** with
`clustez-v1.0.0.apk` attached — a public direct-download link, same pattern as
the RN `clustez-mobile-dist` releases.

## Manual run (no release)
Actions → *Android Release APK* → **Run workflow**. The APK is uploaded as a
build **artifact** instead of a release.

## Notes
- `analyze` and `test` run but are **non-blocking** for now (the code hasn't had
  its first local `analyze` yet); tighten to blocking once it's green.
- The runner has Android SDK + Java 21 preinstalled — no flaky local toolchain.
- iOS release needs macOS runners + Apple signing (the parked membership).
