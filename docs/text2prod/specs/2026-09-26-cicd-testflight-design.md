# CI/CD: PR CI on GitHub Actions, TestFlight CD on Xcode Cloud (Option B)

Status: design, awaiting review · Date: 2026-09-26 · Owner: ddphuong

## 1. Intent

Ship every merge to `main` to TestFlight internal testers with no manual step, keep
PR validation on GitHub Actions, and see the outcome of both in one Slack channel.
Simple first: reuse what already exists, add the minimum.

**Acceptance criteria**

1. A PR targeting `main` runs GitHub Actions CI; a red CI blocks the merge.
2. A merge to `main` produces a TestFlight build available to the internal group `Qa`.
3. Slack (incoming webhook) receives PR CI failures and every CD result
   (success with build number, or failure).
4. Nothing in git contains the webhook URL or any other secret.

## 2. Current state (verified 2026-09-26)

| Piece | State |
|---|---|
| `ci.yml` → `_test.yml` | PR to `main`/`develop`; 4 jobs; green on PR #61 |
| `build.yml` | push to `main`; build-for-testing; green on `cb6c403` |
| Branch protection `main` | exists, `enforce_admins=true`, **no required status checks** |
| Xcode Cloud `Beta` (`4dd7aa78-…`) | enabled, Branch Changes `main`, Archive iOS, `INTERNAL_ONLY`, Xcode 26.6; **did not fire for `cb6c403`** |
| Xcode Cloud `PR Gate` (`9d278ac9-…`) | enabled, fails on every PR (Test action); duplicates GitHub CI |
| Xcode Cloud `Release` (`41c1098a-…`) | untouched by this design |
| `testflight.yml` | manual GitHub Actions upload (asc + p12); latest ASC build `40` |
| TestFlight group `Qa` | internal, access to all builds (auto-distribution) |
| Secrets present | `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_KEY_P8`, `APP_STORE_CONNECT_ISSUER_ID`, signing/Firebase |

## 3. Design

```
PR ──► ci.yml (GitHub Actions: lint, iOS, watchOS, widget, test) ──fail──► Slack ❌
            │ required checks
            ▼ merge
main ──► build.yml (existing) ──success──► cd-testflight.yml (ubuntu)
                                            │ asc xcode-cloud run --workflow Beta --branch main --wait
                                            ▼
                                     Xcode Cloud Beta: archive → TestFlight (Qa)
                                            │ status + build number
                                            ▼
                                     Slack ✅ build N / ❌ failure
```

GitHub is the single orchestrator and the single Slack reporter. Xcode Cloud only
archives, signs and uploads; no secrets or scripts are added on the Xcode Cloud side.

### 3.1 PR CI: `ci.yml` (edit)

- Trigger unchanged.
- Add job `notify-failure`: `needs: build`, `if: failure()`, posts
  `❌ CI failed · PR #<n> <title> · <run url>` via `slackapi/slack-github-action@v4`
  (`webhook-type: incoming-webhook`, `webhook: secrets.SLACK_WEBHOOK_URL`).
- Fork PRs have no secrets: the step is skipped when the secret is empty (env check
  inside the step). Passing PRs post nothing (noise control).

### 3.2 Merge gate: branch protection (settings, no file)

Required status checks on `main`, non-strict ("branch up to date" not required):
`Lint & Build / Lint & Build`, `Lint & Build / Build watchOS`,
`Lint & Build / Build Widget`, `Lint & Build / Test`.
Merge skew (PR tested against an older `main`) is caught post-merge by `build.yml`,
which gates CD (3.3).

### 3.3 CD orchestrator: `.github/workflows/cd-testflight.yml` (new)

- Trigger: `workflow_run` of workflow `Build`, `types: [completed]`, `branches: [main]`;
  the job runs only if `conclusion == 'success'`. Plus `workflow_dispatch` for reruns.
  Effect: a broken `main` never ships; rapid merges batch naturally because
  `build.yml` cancels superseded runs.
- Runner: `ubuntu-latest`, `timeout-minutes: 90`, concurrency group `cd-testflight`,
  `cancel-in-progress: false` (never abandon a started Xcode Cloud run silently).
- Steps:
  1. Install `asc` (same install as `xcodecloud-image-guard.yml`); auth via the
     three existing ASC secrets.
  2. `asc xcode-cloud run --app 6778478266 --workflow Beta --branch main --wait
     --poll-interval 30s --timeout 60m --output json`; read run id, run number and
     `completionStatus` from the JSON (do not rely on the exit code alone).
  3. If `SUCCEEDED`: poll `asc builds list` for the build whose number equals the run
     number until `processingState == VALID` (max 20 min); read `<version>` from that build. Result: `processed` or
     `uploaded, still processing`.
  4. Always (`if: always()`), post to Slack:
     success `✅ TestFlight <version> (N) ready for Qa · <sha7> <commit title> · <gh run url>`;
     failure `❌ Xcode Cloud Beta <status> · run N · <sha7> · <gh run url>`
     (also covers trigger/auth/timeout errors in steps 1–2).
  5. The job fails if the Xcode Cloud run did not succeed (visible in the Actions tab).
- Superseded guard: CD checks out the commit `Build` validated (`workflow_run.head_sha`) and, before starting Xcode Cloud, compares it with the live `main` (`git ls-remote`). If `main` has moved on, the run skips Xcode Cloud and Slack (`::notice::` only, job green); the newer commit's own `Build` → CD run ships it. A small race remains between that check and the `asc xcode-cloud run --branch main` call.

### 3.4 Xcode Cloud configuration (ASC, via API or web UI)

Export each workflow's JSON before editing; keep it under the plan dir as the
rollback artifact.

- `Beta`: replace the Branch Changes start condition with a **Manual start condition
  for branch `main`** (API-started builds count as manual). Keep Archive iOS,
  `INTERNAL_ONLY`, clean build, Xcode 26.6 + latest macOS.
- `PR Gate`: `isEnabled = false`.
- `Release` and the image guard: unchanged.

These settings are not in git; this section is their written record.

### 3.5 Slack and secrets

- New repo secret `SLACK_WEBHOOK_URL` (value provided by the owner in chat; never
  written to any file). Regenerate the webhook in Slack after go-live, since it was
  shared in a chat transcript.
- One channel (the webhook's). Message formats as in 3.1 and 3.3.

### 3.6 Fallback and build numbers

- `testflight.yml` stays manual-only for emergencies. Xcode Cloud's counter (~47)
  is above ASC's latest (40), so there is no collision today. After any fallback
  upload, raise Xcode Cloud **Settings → Build Number → Next Build Number** above it
  (web UI only; no API). Record this in the `AGENTS.md`/`README.md` release notes.
- Fastlane workflows (`distribute.yml`, `release.yml`, `match.yml`): untouched.

## 4. Error handling

| Failure | Behavior |
|---|---|
| CI red on PR | merge blocked; Slack ❌ |
| `build.yml` red on `main` | CD not started; red run in Actions (no Slack in v1) |
| `main` moved past the validated commit | CD skips (notice only, no Slack); the newer Build's CD run ships |
| asc install/auth fails | CD job fails; Slack ❌ |
| Xcode Cloud run FAILED/ERRORED/CANCELED | CD job fails; Slack ❌ with status |
| Timeout (>60 min) | CD job fails; Slack ❌ "timeout"; the Xcode Cloud run keeps going |
| Uploaded but not VALID within 20 min | job succeeds; Slack ✅ "still processing" |
| Slack post fails | warning only (`errors: false`); never fails CI/CD |
| Xcode image pairing retired | weekly guard already alerts; CD fails fast → Slack ❌ |

## 5. Verification

1. Webhook smoke test: one test post appears in the channel.
2. PR path: throwaway PR with a deliberate compile error → CI red, Slack ❌, merge
   blocked; fix → green, mergeable.
3. CD path: merge a docs-only PR → `build.yml` green → `cd-testflight` starts `Beta` →
   new build N > 40 visible to `Qa` → Slack ✅ with N.
4. Confirm `PR Gate` no longer posts checks on the next PR.

## 6. Out of scope (v1)

External TestFlight groups, App Store submission, version bumping, dSYM upload,
Slack for `build.yml`/`testflight.yml`, docs-only path filtering, removing Fastlane.

## 7. Rollback

Disable `cd-testflight.yml`; restore `Beta`'s start condition and `PR Gate` from the
exported JSON; remove the required checks. `testflight.yml` stays available throughout.
