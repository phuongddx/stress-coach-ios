# Releasing Stress AI Coach

Release flow A: **trunk + tags**. `main` is the trunk. Normally every App Store
version is shipped from an annotated `vX.Y.Z` tag on a chosen `main` commit. The
one exception: a hotfix while `main` holds code that must not ship yet is tagged
on a `release/X.Y` branch instead (see
[Hotfix exception](#hotfix-exception-release-branch)). Xcode Cloud `Release`
filters on the tag prefix `v` only, not on the branch. Adopted
2026-11-25 (replacing the short-lived release-branch flow B, used once for 1.1.0).

## Moving parts

| Piece | What it does | Where it is configured |
|---|---|---|
| `main` | The trunk. Every change lands through a PR. Every merge goes to TestFlight (group Qa) through `build.yml` → `cd-testflight.yml` → Xcode Cloud `Beta`. | Branch protection on `main` (four `Lint & Build / *` checks) |
| `vX.Y.Z` tag | The exact commit sent to App Review. Any pushed tag starting with `v` starts Xcode Cloud `Release` (Archive iOS, `APP_STORE_ELIGIBLE`), which uploads the build only. | Xcode Cloud `Release` tag start condition, prefix `v` |
| App Store Connect | Attach the build, validate, submit. Release type **Manual**, **phased release** (7 days) on. | `asc` CLI or the web UI |
| `release/X.Y` (exception only) | Temporary hotfix branch, see [Hotfix exception](#hotfix-exception-release-branch). | Kept ready: ruleset `release branches` on `release/*` (same four required checks, PR required, no bypass, no deletion, no force push), `ci.yml` runs on PRs into `release/**`, Xcode Cloud `Beta` starts automatically on pushes to `release/*`. |

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
  - Fixes only: next **patch** (`1.1.0` → `1.1.1`).
  - Major only for a deliberate break.
- **Build number** (`CFBundleVersion`): owned by Xcode Cloud, one counter for all
  workflows of the product. Never edit `CURRENT_PROJECT_VERSION` by hand; Xcode
  Cloud ignores it. If the emergency `testflight.yml` upload is used, raise App
  Store Connect → Xcode Cloud → Settings → Build Number → Next Build Number above
  that upload afterwards.
- Once a version is released its version train is closed: bump `main` to the next
  version right after tagging, so later TestFlight builds don't land on it.

## Tags

- `vX.Y.Z` (full three-part version, annotated) **only** for App Store builds.
  Never push any other tag starting with `v`: it starts an App Store build.
- Milestone / planning tags use `milestone/<name>` (e.g. `milestone/v1.4-design`).
- Older tags `v1.0`, `v1.1`, `v1.2`, `v1.3` are GSD milestones, not app versions;
  `release/1.0.0`, `release/1.0.1` and `v1.0.0` mark earlier App Store builds. They
  stay as they are.

## Shipping a version

1. **Choose the commit** on `main` whose TestFlight build (Qa) has been checked,
   with `MARKETING_VERSION` already at `X.Y.Z`.
2. **Tag it:**
   `git tag -a vX.Y.Z -m "Stress AI Coach X.Y.Z" <sha> && git push origin vX.Y.Z`.
   Xcode Cloud Release uploads an `APP_STORE_ELIGIBLE` build.
3. **Open main for the next version:** PR that bumps all six `MARKETING_VERSION`
   entries (next minor by default).
4. **App Store Connect** (ask Phuong before step c):
   1. Attach the build: `asc versions attach-build --app 6778478266 --version-id <id> --build <buildId>`.
   2. `asc validate --app 6778478266 --version-id <id>` must report 0 blocking.
   3. Submit the review submission (add every in-app purchase / subscription item
      it needs; a subscription group with no approved version must be submitted
      together with its subscription group version).
   4. Release type **Manual**; phased release on:
      `asc versions phased-release create --version-id <id>`.
5. **After approval:** Phuong presses Release. Then:
   - GitHub Release `vX.Y.Z` from the tag, notes generated from the previous App
     Store tag, marked Latest.
   - Move the `CHANGELOG.md` entry from submitted to its release date.
   - Check the landing page (`phuongddx/stress-coach-ai`) matches what shipped.

## Hotfix (normal case)

`main` holds nothing that isn't ready to ship:

1. PR into `main` with the fix and `MARKETING_VERSION` bumped to the next patch
   (`X.Y.(Z+1)`).
2. Verify the TestFlight build from that merge.
3. Tag `vX.Y.(Z+1)` on that `main` commit, then the App Store Connect steps above.

## Hotfix exception: release branch

Only when `main` already contains code that must not ship yet:

1. Cut a branch from the shipped tag:
   `git push origin vX.Y.Z^{commit}:refs/heads/release/X.Y` (skip if it exists).
   Pushes to `release/*` build to TestFlight automatically.
2. PR into `release/X.Y` with the fix and the patch bump (CI must be green, merge
   commit, no admin override).
3. Tag `vX.Y.(Z+1)` on the `release/X.Y` commit, then the App Store Connect steps.
4. Bring the fix back: PR merging `release/X.Y` into a branch off `main` (or
   `git cherry-pick -x`), without the version bump. Never let a fix live only on
   the release branch.
5. The branch can be left in place (the ruleset blocks deletion); it is no longer
   used once the next minor version is live.

`release/1.1` (from `v1.1.0`) is kept for 1.1.x hotfixes until 1.2.0 is live.

## Don'ts

- No direct pushes to `main` or `release/*`; no force pushes.
- Don't submit to App Review, change prices or subscription products without
  Phuong's go-ahead.
- Don't push a `v*` tag that isn't an App Store version.
