# Releasing Stress AI Coach

Release flow B: **release branches**. `main` keeps moving; every App Store
version is stabilised on its own `release/X.Y` branch and shipped from a `vX.Y.Z`
tag on that branch. Adopted 2026-11-25, first used for 1.1.0.

## Moving parts

| Piece | What it does | Where it is configured |
|---|---|---|
| `main` | Next minor version. Every merge goes to TestFlight (group Qa) through `build.yml` → `cd-testflight.yml` → Xcode Cloud `Beta`. | Branch protection on `main` (four `Lint & Build / *` checks) |
| `release/X.Y` | One branch per minor version, e.g. `release/1.1`. Release candidates and hotfixes for `X.Y.*`. Every push starts Xcode Cloud `Beta` → TestFlight (Qa). | Ruleset `release branches` on `release/*`: same four required checks, PR required, no bypass, no deletion, no force push. `ci.yml` runs on PRs into `release/**`. Beta branch start condition, prefix `release/`. |
| `vX.Y.Z` tag | The exact commit sent to App Review. Any pushed tag starting with `v` starts Xcode Cloud `Release` (Archive iOS, `APP_STORE_ELIGIBLE`), which uploads the build only. | Xcode Cloud `Release` tag start condition, prefix `v` |
| App Store Connect | Attach the build, validate, submit. Release type **Manual**, **phased release** (7 days) on. | `asc` CLI or the web UI |

Xcode Cloud workflow settings are not in git. Read them back with
`asc xcode-cloud workflows view --id <id>` (Beta `4dd7aa78-9f72-4aeb-a623-9ef28a36f840`,
Release `41c1098a-6173-4ef7-8ea3-d48d6a3aece7`). Rollback JSON lives in
`plans/260926-1046-cicd-testflight-cd/backup/`. A workflow `update` that sends
only some start conditions can drop the others: send every condition you want to
keep, then read the workflow back.

## Version rules

- **Marketing version** (`MARKETING_VERSION`, 6 entries in
  `StressMonitor/StressMonitor.xcodeproj/project.pbxproj`, all targets equal):
  semantic `MAJOR.MINOR.PATCH`, always three parts.
  - New features or visible changes: next **minor** (`1.1.0` → `1.2.0`).
  - Fixes only, shipped from a release branch: next **patch** (`1.1.0` → `1.1.1`).
  - Major only for a deliberate break (new data model users must migrate to, etc.).
- **Build number** (`CFBundleVersion`): owned by Xcode Cloud, one counter for all
  workflows of the product. Never edit `CURRENT_PROJECT_VERSION` by hand; the value
  in the project is ignored by Xcode Cloud builds. If the emergency
  `testflight.yml` upload is used, raise App Store Connect → Xcode Cloud →
  Settings → Build Number → Next Build Number above that upload afterwards.
- Once a version is released on the App Store its version train is closed: a
  release branch must bump to the next patch before its next TestFlight or App
  Store upload.

## Tags

- `vX.Y.Z` (full three-part version) **only** for App Store builds, created on the
  `release/X.Y` commit that goes to review. Never push any other tag starting with
  `v`: it starts an App Store build.
- Milestone / planning tags use `milestone/<name>` (e.g. `milestone/v1.4-design`).
- Older tags `v1.0`, `v1.1`, `v1.2`, `v1.3` are GSD milestones, not app versions;
  `release/1.0.0`, `release/1.0.1` and `v1.0.0` mark earlier App Store builds. They
  stay as they are.

## Shipping a new minor version (X.Y.0)

1. **Cut the branch** when `main` holds everything planned for X.Y and its
   TestFlight build has been checked:
   `git push origin <main-sha>:refs/heads/release/X.Y`.
   Xcode Cloud Beta builds the release candidate for TestFlight.
2. **Open main for the next version:** PR on `main` that bumps all six
   `MARKETING_VERSION` entries to `X.(Y+1).0`.
3. **Stabilise:** fixes for the release go in PRs **into `release/X.Y`** (CI must be
   green, merge commit, no admin override). Bring every such fix to `main` in its
   own PR, with `git cherry-pick -x <sha>` by default, or by merging `release/X.Y`
   into a branch off `main` when there is no version conflict. Never let a fix
   live only on the release branch.
4. **Tag** the release-branch commit to ship:
   `git tag -a vX.Y.0 -m "Stress AI Coach X.Y.0" <sha> && git push origin vX.Y.0`.
   Xcode Cloud Release uploads an `APP_STORE_ELIGIBLE` build.
5. **App Store Connect** (ask Phuong before step c):
   1. Attach the build: `asc versions attach-build --app 6778478266 --version-id <id> --build <buildId>`.
   2. `asc validate --app 6778478266 --version-id <id>` must report 0 blocking.
   3. Submit the review submission (add every in-app purchase / subscription
      item it needs; a subscription group with no approved version must be
      submitted together with its subscription group version).
   4. Release type **Manual**; phased release on:
      `asc versions phased-release create --version-id <id>`.
6. **After approval:** Phuong presses Release. Then:
   - GitHub Release `vX.Y.0` from the tag, notes generated from the previous
     App Store tag, marked Latest.
   - Move the `CHANGELOG.md` entry from submitted to its release date.
   - Check the landing page (`phuongddx/stress-coach-ai`) matches what shipped.

## Hotfix (X.Y.Z+1)

1. PR into `release/X.Y`: bump `MARKETING_VERSION` to the next patch and add the fix.
2. TestFlight build from the push to `release/X.Y`; verify it.
3. Tag `vX.Y.(Z+1)` on that commit, then App Store Connect steps above.
4. Cherry-pick (`-x`) the fix to `main` in a PR, without the version bump.

## Don'ts

- No direct pushes to `main` or `release/*`; no force pushes; release branches
  are never deleted.
- Don't submit to App Review, change prices or subscription products without
  Phuong's go-ahead.
- Don't tag from `main` for an App Store build: tag the release branch.
