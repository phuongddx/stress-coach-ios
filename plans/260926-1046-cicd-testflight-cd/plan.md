# CI/CD TestFlight (GitHub Actions CI + Xcode Cloud CD) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use text2prod:subagent-driven-development (recommended) or text2prod:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every merge to `main` ships a TestFlight build to internal group `Qa` via Xcode Cloud, PRs are gated by GitHub Actions CI, and results land in Slack.

**Architecture:** GitHub Actions is the only orchestrator and Slack reporter. `ci.yml` gates PRs (required checks) and posts failures. After `build.yml` ("Build") succeeds on `main`, a new `cd-testflight.yml` runs `scripts/cd-testflight.sh`, which starts Xcode Cloud workflow `Beta` through the App Store Connect API (`asc xcode-cloud run --wait`), waits for TestFlight processing, and emits a Slack message. Xcode Cloud only archives/signs/uploads.

**Tech Stack:** GitHub Actions, `asc` CLI (App Store Connect API), Xcode Cloud, `slackapi/slack-github-action@v4.0.0` (incoming webhook), bash + jq, shellcheck, actionlint.

**Spec:** `docs/text2prod/specs/2026-09-26-cicd-testflight-design.md` (commit `919e789`, branch `codex/cicd-testflight-cd`)

## Global Constraints

- Work on branch `codex/cicd-testflight-cd`; public repo `phuongddx/stress-coach-ios`.
- App ID `6778478266`. Xcode Cloud workflows: `Beta` = `4dd7aa78-9f72-4aeb-a623-9ef28a36f840`, `PR Gate` = `9d278ac9-80ae-4589-822b-c57bb752042b`, `Release` = `41c1098a-6173-4ef7-8ea3-d48d6a3aece7` (never touch `Release`).
- Secret name `SLACK_WEBHOOK_URL`. **Never write the webhook URL into any file, commit, plan, log line, or PR text.**
- Reuse existing secrets `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_KEY_P8`, `APP_STORE_CONNECT_ISSUER_ID`; install `asc` exactly as `xcodecloud-image-guard.yml` does (`curl -fsSL https://asccli.sh/install | bash`).
- Slack action pinned to `slackapi/slack-github-action@v4.0.0`, `webhook-type: incoming-webhook`, `errors` left default (false) → Slack failures never fail CI/CD.
- Required checks on `main` (exact contexts): `Lint & Build / Lint & Build`, `Lint & Build / Build watchOS`, `Lint & Build / Build Widget`, `Lint & Build / Test`; non-strict.
- Do not modify `testflight.yml`, `build.yml`, `_test.yml`, Fastlane workflows, or `Release`.
- Tasks 4–7 mutate external systems (GitHub secrets/protection, App Store Connect, push/merge). **Each is a human gate: get explicit user confirmation before starting it.**
- Local tooling: `jq`, `shellcheck` present; `actionlint` via `brew install actionlint` (dev tool only).

## File Map

| File | Action | Responsibility |
|---|---|---|
| `scripts/cd-testflight.sh` | Create | Trigger Beta, wait, poll TestFlight processing, emit outputs + Slack text |
| `scripts/cd-testflight-tests.sh` | Create | 7 tests with a fake `asc`; no network |
| `.github/workflows/cd-testflight.yml` | Create | `workflow_run` of Build → run script → Slack |
| `.github/workflows/ci.yml` | Modify | add `notify-failure` job |
| `AGENTS.md` | Modify | Release + Scripts bullets reflect new pipeline |
| `plans/260926-1046-cicd-testflight-cd/backup/*.json` | Create (Tasks 5–6) | pre-change Xcode Cloud + branch-protection state for rollback |

---

### Task 1: CD helper script with tests

**Files:**
- Create: `scripts/cd-testflight.sh`
- Test: `scripts/cd-testflight-tests.sh`

**Interfaces:**
- Consumes: `asc xcode-cloud run ... --wait --output json` → flat JSON `{buildRunId, buildNumber, completionStatus, sourceCommit:{commitSha, message}}` (same shape as `asc xcode-cloud status`, verified on run 38); `asc builds list --build-number N --include preReleaseVersion --output json` → `.data[0].attributes.processingState`, `.included[type=="preReleaseVersions"].attributes.version`.
- Produces: script `scripts/cd-testflight.sh`; env in: `ASC_APP_ID` (required), `CD_WORKFLOW`=Beta, `CD_BRANCH`=main, `ASC_BIN`=asc, `RUN_TIMEOUT`=60m, `PROCESS_ATTEMPTS`=40, `PROCESS_SLEEP`=30, `RUN_URL`; outputs (to `$GITHUB_OUTPUT` + stdout, `key=value`): `status`, `build_number`, `commit`, `version`, `processing`, `slack_text`. Exit 0 iff run `SUCCEEDED` and processing not `FAILED`/`INVALID`.

- [ ] **Step 1: Write the failing tests** — create `scripts/cd-testflight-tests.sh`:

```bash
#!/bin/bash
# Tests for cd-testflight.sh with a fake `asc` (no network, no Xcode).
#   1. success: run SUCCEEDED + build VALID → exit 0, exact outputs + ✅ text
#   2. calls: triggers Beta on main with --wait; looks build up by run number
#   3. run FAILED → exit 1, ❌ text, TestFlight never polled
#   4. asc error (no JSON) → exit 1, status=ERROR, no stderr in Slack text
#   5. still processing after all attempts → exit 0, "still processing"
#   6. processing FAILED → exit 1, ❌ processing text
#   7. missing ASC_APP_ID → exit non-zero, asc never called, clear error
# shellcheck disable=SC2319  # `[ ... ]; expect_pass $?` is the intended pattern
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/cd-testflight.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAKE="$TMP/asc"
FAKE_LOG="$TMP/asc.log"
OUT="$TMP/out"
URL="https://example.test/run/1"
failures=0

expect_pass() {
    if [ "$1" -eq 0 ]; then echo "PASS $2"; else echo "FAIL $2"; failures=$((failures + 1)); fi
}

cat > "$FAKE" <<'EOF'
#!/bin/bash
echo "$*" >> "$FAKE_LOG"
case "$1 $2" in
  "xcode-cloud run") printf '%s' "${FAKE_RUN_JSON:-}"; exit "${FAKE_RUN_EXIT:-0}" ;;
  "builds list") printf '%s' "${FAKE_BUILD_JSON:-}" ;;
esac
EOF
chmod +x "$FAKE"

RUN_OK='{"buildRunId":"r1","buildNumber":48,"completionStatus":"SUCCEEDED","sourceCommit":{"commitSha":"abc1234def","message":"feat: x\n\nbody"}}'
RUN_FAILED='{"buildRunId":"r2","buildNumber":49,"completionStatus":"FAILED","sourceCommit":{"commitSha":"def5678aaa","message":"fix: y"}}'
build_json() { printf '{"data":[{"attributes":{"version":"48","processingState":"%s"}}],"included":[{"type":"preReleaseVersions","attributes":{"version":"1.0.1"}}]}' "$1"; }

# run_case RUN_JSON RUN_EXIT BUILD_JSON [APP_ID] → sets $rc
run_case() {
    : > "$FAKE_LOG"; : > "$OUT"
    env FAKE_LOG="$FAKE_LOG" FAKE_RUN_JSON="$1" FAKE_RUN_EXIT="$2" FAKE_BUILD_JSON="$3" \
        ASC_BIN="$FAKE" ASC_APP_ID="${4-123}" GITHUB_OUTPUT="$OUT" \
        PROCESS_ATTEMPTS=2 PROCESS_SLEEP=0 RUN_URL="$URL" \
        bash "$SCRIPT" > "$TMP/stdout" 2>&1
    rc=$?
}
out() { grep -F "$1=" "$OUT" | head -n1 | cut -d= -f2-; }

run_case "$RUN_OK" 0 "$(build_json VALID)"
[ "$rc" -eq 0 ] && [ "$(out status)" = "SUCCEEDED" ] && [ "$(out build_number)" = "48" ] \
  && [ "$(out version)" = "1.0.1" ] && [ "$(out processing)" = "VALID" ] \
  && [ "$(out slack_text)" = "✅ TestFlight 1.0.1 (48) ready for Qa · abc1234 feat: x · $URL" ]
expect_pass $? "test_success_valid_build (rc=$rc)"

grep -qF "xcode-cloud run --app 123 --workflow Beta --branch main --wait" "$FAKE_LOG" \
  && grep -qF "builds list --app 123 --build-number 48" "$FAKE_LOG"
expect_pass $? "test_triggers_beta_on_main_and_looks_up_run_number"

run_case "$RUN_FAILED" 0 "$(build_json VALID)"
[ "$rc" -ne 0 ] && [ "$(out status)" = "FAILED" ] \
  && [ "$(out slack_text)" = "❌ Xcode Cloud Beta FAILED · run 49 · def5678 fix: y · $URL" ] \
  && ! grep -q "builds list" "$FAKE_LOG"
expect_pass $? "test_run_failed_reports_and_skips_testflight (rc=$rc)"

run_case "" 1 ""
[ "$rc" -ne 0 ] && [ "$(out status)" = "ERROR" ] \
  && [ "$(out slack_text)" = "❌ Xcode Cloud Beta ERROR (see run log) · run ? · ? · $URL" ]
expect_pass $? "test_asc_error_without_json (rc=$rc)"

run_case "$RUN_OK" 0 "$(build_json PROCESSING)"
[ "$rc" -eq 0 ] && [ "$(out processing)" = "PROCESSING" ] \
  && [ "$(out slack_text)" = "✅ TestFlight 1.0.1 (48) uploaded, still processing · abc1234 feat: x · $URL" ] \
  && [ "$(grep -c 'builds list' "$FAKE_LOG")" -eq 2 ]
expect_pass $? "test_still_processing_after_attempts (rc=$rc)"

run_case "$RUN_OK" 0 "$(build_json FAILED)"
[ "$rc" -ne 0 ] && [ "$(out slack_text)" = "❌ TestFlight build 48 processing FAILED · abc1234 feat: x · $URL" ]
expect_pass $? "test_processing_failed (rc=$rc)"

run_case "$RUN_OK" 0 "$(build_json VALID)" ""
[ "$rc" -ne 0 ] && [ ! -s "$FAKE_LOG" ] && grep -qF "ASC_APP_ID is required" "$TMP/stdout"
expect_pass $? "test_requires_app_id (rc=$rc)"

echo "cd-testflight tests: $failures failure(s)"
exit "$failures"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash scripts/cd-testflight-tests.sh`
Expected: 7 `FAIL` lines (script missing), `cd-testflight tests: 7 failure(s)`, exit 7.

- [ ] **Step 3: Write the implementation** — create `scripts/cd-testflight.sh`:

```bash
#!/bin/bash
# CD step: start the Xcode Cloud workflow (default "Beta") on a branch (default
# "main") through the App Store Connect API, wait for it, then wait for the
# TestFlight build it uploaded to finish processing. Called by
# .github/workflows/cd-testflight.yml; tested by scripts/cd-testflight-tests.sh.
#
# Writes status, build_number, commit, version, processing, slack_text to
# $GITHUB_OUTPUT (when set) and stdout. Exit 0 only if the Xcode Cloud run
# SUCCEEDED and TestFlight processing did not fail.
#
# Env: ASC_APP_ID (required) · CD_WORKFLOW=Beta · CD_BRANCH=main · ASC_BIN=asc
#      RUN_TIMEOUT=60m · PROCESS_ATTEMPTS=40 · PROCESS_SLEEP=30 (~20 min) · RUN_URL
set -uo pipefail

: "${ASC_APP_ID:?ASC_APP_ID is required}"
ASC_BIN="${ASC_BIN:-asc}"
WORKFLOW="${CD_WORKFLOW:-Beta}"
BRANCH="${CD_BRANCH:-main}"
RUN_TIMEOUT="${RUN_TIMEOUT:-60m}"
PROCESS_ATTEMPTS="${PROCESS_ATTEMPTS:-40}"
PROCESS_SLEEP="${PROCESS_SLEEP:-30}"
RUN_URL="${RUN_URL:-}"

emit() {
    echo "$1=$2"
    if [ -n "${GITHUB_OUTPUT:-}" ]; then echo "$1=$2" >> "$GITHUB_OUTPUT"; fi
}
# field JSON FILTER → value, or empty when null/missing/invalid JSON.
field() { jq -r "$2 // empty" <<<"$1" 2>/dev/null || true; }

err_file="$(mktemp)"
trap 'rm -f "$err_file"' EXIT

# asc may exit non-zero for a failed build; the JSON status is the source of truth.
run_json="$("$ASC_BIN" xcode-cloud run --app "$ASC_APP_ID" --workflow "$WORKFLOW" \
    --branch "$BRANCH" --wait --poll-interval 30s --timeout "$RUN_TIMEOUT" \
    --output json 2>"$err_file")" || true

status="$(field "$run_json" .completionStatus)"
status="${status:-ERROR}"
build_number="$(field "$run_json" .buildNumber)"
commit="$(field "$run_json" .sourceCommit.commitSha)"
commit="${commit:0:7}"
title="$(field "$run_json" '.sourceCommit.message | split("\n")[0]')"

emit status "$status"
emit build_number "$build_number"
emit commit "$commit"

if [ "$status" != "SUCCEEDED" ]; then
    reason="$status"
    if [ "$status" = "ERROR" ]; then
        # stderr goes to the job log only, never to Slack.
        reason="ERROR (see run log)"
        echo "asc xcode-cloud run returned no status; stderr follows:" >&2
        cat "$err_file" >&2
    fi
    emit slack_text "❌ Xcode Cloud $WORKFLOW $reason · run ${build_number:-?} · ${commit:-?}${title:+ $title} · $RUN_URL"
    exit 1
fi

version=""
processing=""
for ((i = 1; i <= PROCESS_ATTEMPTS; i++)); do
    build_json="$("$ASC_BIN" builds list --app "$ASC_APP_ID" --build-number "$build_number" \
        --include preReleaseVersion --output json 2>/dev/null)" || true
    processing="$(field "$build_json" '.data[0].attributes.processingState')"
    version="$(field "$build_json" '[.included[]? | select(.type == "preReleaseVersions") | .attributes.version][0]')"
    case "$processing" in VALID | FAILED | INVALID) break ;; esac
    if [ "$i" -lt "$PROCESS_ATTEMPTS" ]; then sleep "$PROCESS_SLEEP"; fi
done

emit version "$version"
emit processing "${processing:-UNKNOWN}"

case "$processing" in
    VALID)
        emit slack_text "✅ TestFlight ${version:-?} ($build_number) ready for Qa · $commit${title:+ $title} · $RUN_URL" ;;
    FAILED | INVALID)
        emit slack_text "❌ TestFlight build $build_number processing $processing · $commit${title:+ $title} · $RUN_URL"
        exit 1 ;;
    *)
        emit slack_text "✅ TestFlight ${version:-?} ($build_number) uploaded, still processing · $commit${title:+ $title} · $RUN_URL" ;;
esac
```

Note: `FAILED`/`INVALID` processing → ❌ + exit 1 extends spec §4 (a processing failure is a failed delivery).

- [ ] **Step 4: Run tests to verify they pass**

Run: `chmod +x scripts/cd-testflight.sh scripts/cd-testflight-tests.sh && bash scripts/cd-testflight-tests.sh && shellcheck scripts/cd-testflight.sh scripts/cd-testflight-tests.sh`
Expected: 7 `PASS` lines, `cd-testflight tests: 0 failure(s)`, exit 0; shellcheck prints nothing.

- [ ] **Step 5: Commit**

```bash
git add scripts/cd-testflight.sh scripts/cd-testflight-tests.sh
git commit -m "feat(ci): cd-testflight script to run Xcode Cloud Beta and await TestFlight"
```

---

### Task 2: CD workflow + docs

**Files:**
- Create: `.github/workflows/cd-testflight.yml`
- Modify: `AGENTS.md` (Release bullet under "Runtime / Tooling Preferences"; Scripts bullet)

**Interfaces:**
- Consumes: `scripts/cd-testflight.sh` outputs `slack_text` (Task 1); workflow named exactly `Build` (`build.yml`).
- Produces: workflow `CD TestFlight`, job `deliver` (name `Xcode Cloud Beta → TestFlight`).

- [ ] **Step 1: Install linter and confirm the file is absent (red)**

Run: `brew install actionlint && actionlint .github/workflows/cd-testflight.yml`
Expected: error — file does not exist.

- [ ] **Step 2: Create `.github/workflows/cd-testflight.yml`**

```yaml
name: CD TestFlight

# After "Build" succeeds on main, start the Xcode Cloud "Beta" workflow through
# the App Store Connect API, wait for the TestFlight build, and report to Slack.
# Beta must have a Manual start condition on main (API builds count as manual).
# Design: docs/text2prod/specs/2026-09-26-cicd-testflight-design.md

on:
  workflow_run:
    workflows: [Build]
    types: [completed]
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: cd-testflight
  cancel-in-progress: false # never abandon a started Xcode Cloud run

jobs:
  deliver:
    name: Xcode Cloud Beta → TestFlight
    if: github.event_name == 'workflow_dispatch' || github.event.workflow_run.conclusion == 'success'
    runs-on: ubuntu-latest
    timeout-minutes: 90
    env:
      ASC_APP_ID: "6778478266"
      ASC_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}
      ASC_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
      ASC_PRIVATE_KEY: ${{ secrets.APP_STORE_CONNECT_API_KEY_P8 }}
      ASC_BYPASS_KEYCHAIN: "1"
      SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
      RUN_URL: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}

    steps:
      - uses: actions/checkout@v4

      - name: Install asc
        run: |
          curl -fsSL https://asccli.sh/install | bash
          asc version

      - name: Run Xcode Cloud Beta and wait for TestFlight
        id: cd
        run: bash scripts/cd-testflight.sh

      - name: Notify Slack
        if: always() && env.SLACK_WEBHOOK_URL != ''
        uses: slackapi/slack-github-action@v4.0.0
        with:
          webhook: ${{ secrets.SLACK_WEBHOOK_URL }}
          webhook-type: incoming-webhook
          payload: |
            text: ${{ toJSON(steps.cd.outputs.slack_text || format('❌ CD TestFlight failed before Xcode Cloud started · {0}', env.RUN_URL)) }}
```

- [ ] **Step 3: Lint (green)**

Run: `actionlint .github/workflows/cd-testflight.yml`
Expected: no output, exit 0.

- [ ] **Step 4: Update `AGENTS.md`** — replace the entire bullet beginning `- **Release:** \`deploy.yml\` was removed.` with:

```markdown
- **Release (CD):** merge to `main` → `build.yml` ("Build") → `.github/workflows/cd-testflight.yml` (ubuntu) runs `scripts/cd-testflight.sh`: starts Xcode Cloud workflow `Beta` via `asc xcode-cloud run --wait` (Beta has a Manual start condition on `main`; archives and uploads `INTERNAL_ONLY`; TestFlight group `Qa` gets all builds), waits for TestFlight processing, posts the result to Slack (repo secret `SLACK_WEBHOOK_URL`). PR CI failures also post to Slack (`ci.yml` job `notify-failure`). Xcode Cloud `PR Gate` is disabled; `main` requires the four `Lint & Build / *` checks. Xcode Cloud workflow settings are not in git — their written record is `docs/text2prod/specs/2026-09-26-cicd-testflight-design.md` §3.4 (rollback JSON in `plans/260926-1046-cicd-testflight-cd/backup/`). **Emergency fallback:** manual `.github/workflows/testflight.yml` (`asc` CLI + raw p12 cert `XPT2DHR688`; secrets `GOOGLE_SERVICE_INFO_PLIST_BASE64`, `BUILD_CERTIFICATE_P12_BASE64`, `P12_PASSWORD`; archive gate runs BEFORE Export IPA so a verify failure never uploads the signed IPA artifact on this public repo) — after using it, raise App Store Connect → Xcode Cloud → Settings → Build Number → Next Build Number above the uploaded number (web UI only), or the next Beta upload collides. Xcode Cloud also provisions Firebase config (`StressMonitor/ci_scripts/ci_post_clone.sh`); weekly `.github/workflows/xcodecloud-image-guard.yml` checks workflow image pairings. Other manual workflows: `distribute.yml` (`fastlane distribute_beta`), `release.yml` (`fastlane release`; `build_number`/`submit_for_review` inputs are ignored by the lane), `match.yml`. README's "How it ships" table is stale.
```

In the `- **Scripts:**` bullet, after `verify-archive-tests.sh` sentence, append: `` `scripts/cd-testflight.sh` + `cd-testflight-tests.sh` (7 tests with a fake `asc`, no network — run after touching the script). ``

- [ ] **Step 5: Verify docs + no secret leak**

Run: `grep -c "cd-testflight" AGENTS.md; git grep -nE 'hooks\.slack\.com/services/T' ; echo "leak-check-exit=$?"`
Expected: count ≥ 2; no grep hits; `leak-check-exit=1`.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/cd-testflight.yml AGENTS.md
git commit -m "ci: CD TestFlight workflow — Build success on main triggers Xcode Cloud Beta"
```

---

### Task 3: PR CI failure notification

**Files:**
- Modify: `.github/workflows/ci.yml` (append job after `build`)

**Interfaces:**
- Consumes: job id `build` (calls `_test.yml`), secret `SLACK_WEBHOOK_URL`.
- Produces: job `notify-failure` (name `Notify Slack on failure`) — not a required check.

- [ ] **Step 1: Append the job** — `ci.yml` becomes:

```yaml
name: CI

on:
  pull_request:
    branches: [main, develop]
  workflow_dispatch:

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build:
    name: Lint & Build
    uses: ./.github/workflows/_test.yml

  # Posts only on failure (passing PRs stay quiet). Fork PRs get no secrets,
  # so the step skips itself when the webhook is empty.
  notify-failure:
    name: Notify Slack on failure
    needs: build
    if: failure()
    runs-on: ubuntu-latest
    env:
      SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
    steps:
      - name: Post CI failure
        if: env.SLACK_WEBHOOK_URL != ''
        uses: slackapi/slack-github-action@v4.0.0
        with:
          webhook: ${{ secrets.SLACK_WEBHOOK_URL }}
          webhook-type: incoming-webhook
          payload: |
            text: ${{ toJSON(format('❌ CI failed · {0} · {1}/{2}/actions/runs/{3}', github.event.pull_request && format('PR #{0} {1}', github.event.pull_request.number, github.event.pull_request.title) || github.ref_name, github.server_url, github.repository, github.run_id)) }}
```

- [ ] **Step 2: Lint**

Run: `actionlint .github/workflows/ci.yml .github/workflows/cd-testflight.yml`
Expected: no output, exit 0.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: post PR CI failures to Slack"
```

---

### Task 4: ⛔ Human gate — Slack secret + webhook smoke test

**Files:** none (GitHub repo secret).

- [ ] **Step 1: Confirm with user** before writing the secret.

- [ ] **Step 2: Set the secret from the URL the user gave in chat** (stdin; never echo, never write to a file):

Run: `printf '%s' "$WEBHOOK" | gh secret set SLACK_WEBHOOK_URL` (with `WEBHOOK` set inline in the same command only)
Then: `gh secret list | grep SLACK_WEBHOOK_URL`
Expected: one line with today's date.

- [ ] **Step 3: Smoke test** (same inline variable):

Run: `curl -fsS -X POST -H 'Content-type: application/json' --data '{"text":"🔧 stress-coach-ios CI/CD webhook test"}' "$WEBHOOK"`
Expected: body `ok`. Ask the user to confirm the message appeared in the channel.

---

### Task 5: ⛔ Human gate — Xcode Cloud reconfiguration

**Files:**
- Create: `plans/260926-1046-cicd-testflight-cd/backup/xcode-cloud-beta-before.json`, `.../backup/xcode-cloud-pr-gate-before.json`

- [ ] **Step 1: Confirm with user.** Confirm no one merges to `main` between this task and Task 7 (Beta will not auto-build anymore).

- [ ] **Step 2: Back up current state**

```bash
B=plans/260926-1046-cicd-testflight-cd/backup; mkdir -p "$B"
asc xcode-cloud workflows view --id 4dd7aa78-9f72-4aeb-a623-9ef28a36f840 --output json > "$B/xcode-cloud-beta-before.json"
asc xcode-cloud workflows view --id 9d278ac9-80ae-4589-822b-c57bb752042b --output json > "$B/xcode-cloud-pr-gate-before.json"
jq -r '.data.attributes.name' "$B"/xcode-cloud-*-before.json
grep -ciE 'password|secret|token|private' "$B"/xcode-cloud-*-before.json
```
Expected: `Beta`, `PR Gate`; grep count `0` for both (safe to commit on a public repo).

- [ ] **Step 3: Disable PR Gate**

```bash
cat > "$TMPDIR/pr-gate.json" <<'EOF'
{"data":{"type":"ciWorkflows","id":"9d278ac9-80ae-4589-822b-c57bb752042b","attributes":{"isEnabled":false}}}
EOF
asc xcode-cloud workflows update --id 9d278ac9-80ae-4589-822b-c57bb752042b --file "$TMPDIR/pr-gate.json" --output json | jq -c '.data.attributes.isEnabled'
```
Expected: `false`. If asc rejects the payload shape, retry with `{"isEnabled":false}`; if still rejected, do it in App Store Connect → app → Xcode Cloud → Manage Workflows → PR Gate → Disable.

- [ ] **Step 4: Switch Beta to a Manual start condition on `main`**

```bash
cat > "$TMPDIR/beta.json" <<'EOF'
{"data":{"type":"ciWorkflows","id":"4dd7aa78-9f72-4aeb-a623-9ef28a36f840","attributes":{"branchStartCondition":null,"manualBranchStartCondition":{"source":{"patterns":[{"pattern":"main","isPrefix":false}]}}}}}
EOF
asc xcode-cloud workflows update --id 4dd7aa78-9f72-4aeb-a623-9ef28a36f840 --file "$TMPDIR/beta.json" --output json >/dev/null
asc xcode-cloud workflows view --id 4dd7aa78-9f72-4aeb-a623-9ef28a36f840 --output json \
  | jq -c '.data.attributes | {isEnabled, branchStartCondition, manual: .manualBranchStartCondition.source.patterns, actions: [.actions[] | {actionType, buildDistributionAudience}]}'
```
Expected: `{"isEnabled":true,"branchStartCondition":null,"manual":[{"pattern":"main",...}],"actions":[{"actionType":"ARCHIVE","buildDistributionAudience":"INTERNAL_ONLY"}]}`. Web-UI fallback: Beta → Start Conditions → delete "Branch Changes", add "Manual Start Condition" → Custom Branches `main` → Save.

- [ ] **Step 5: Commit backups**

```bash
git add plans/260926-1046-cicd-testflight-cd/backup/
git commit -m "chore(ci): back up Xcode Cloud Beta/PR Gate config before CD switch"
```

---

### Task 6: ⛔ Human gate — push, PR, required checks, negative CI test

**Files:**
- Create: `plans/260926-1046-cicd-testflight-cd/backup/branch-protection-main-before.json`

- [ ] **Step 1: Confirm with user**, then push and open the PR

```bash
git push -u origin codex/cicd-testflight-cd
gh pr create --base main --head codex/cicd-testflight-cd \
  --title "ci: GitHub Actions CI gate + Xcode Cloud TestFlight CD + Slack" \
  --body "Implements docs/text2prod/specs/2026-09-26-cicd-testflight-design.md (plan: plans/260926-1046-cicd-testflight-cd/plan.md)."
gh pr checks --watch
```
Expected: the four `Lint & Build / *` checks pass; `Notify Slack on failure` skipped; no `StressMonitor | PR Gate` check.

- [ ] **Step 2: Back up + set branch protection**

```bash
B=plans/260926-1046-cicd-testflight-cd/backup
gh api repos/{owner}/{repo}/branches/main/protection > "$B/branch-protection-main-before.json"
cat > "$TMPDIR/protection.json" <<'EOF'
{
  "required_status_checks": {"strict": false, "checks": [
    {"context": "Lint & Build / Lint & Build", "app_id": 15368},
    {"context": "Lint & Build / Build watchOS", "app_id": 15368},
    {"context": "Lint & Build / Build Widget", "app_id": 15368},
    {"context": "Lint & Build / Test", "app_id": 15368}]},
  "enforce_admins": true,
  "required_pull_request_reviews": {"dismiss_stale_reviews": false, "require_code_owner_reviews": false, "required_approving_review_count": 0, "require_last_push_approval": false},
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true,
  "lock_branch": false,
  "allow_fork_syncing": false
}
EOF
gh api -X PUT repos/{owner}/{repo}/branches/main/protection --input "$TMPDIR/protection.json" \
  | jq -c '{checks: [.required_status_checks.checks[].context], strict: .required_status_checks.strict, admins: .enforce_admins.enabled}'
```
Expected: the four contexts, `strict:false`, `admins:true` (15368 = GitHub Actions app id; prevents spoofed statuses). All other protection fields unchanged vs backup.

- [ ] **Step 3: Negative test PR** (based on the feature branch so its `ci.yml` has `notify-failure`)

```bash
git switch -c codex/ci-slack-negative-test
printf '\nlet ciNegativeTestBrokenOnPurpose: Int = "not an int"\n' >> StressMonitor/StressMonitor/StressMonitorApp.swift
git commit -am "test(ci): deliberate compile error — do not merge"
git push -u origin codex/ci-slack-negative-test
gh pr create --base main --head codex/ci-slack-negative-test --title "DO NOT MERGE: CI negative test" --body "Verifies red CI blocks merge and posts to Slack."
gh pr checks --watch; gh pr view --json mergeStateStatus -q .mergeStateStatus
```
Expected: `Lint & Build / Lint & Build` fails, `Notify Slack on failure` succeeds, merge state `BLOCKED`; user confirms the ❌ message in Slack.

- [ ] **Step 4: Clean up**

```bash
gh pr close codex/ci-slack-negative-test --delete-branch
git switch codex/cicd-testflight-cd && git branch -D codex/ci-slack-negative-test
git add plans/260926-1046-cicd-testflight-cd/backup/branch-protection-main-before.json
git commit -m "chore(ci): back up main branch protection before required checks"
git push
gh pr checks --watch
```
Expected: feature PR still green after the push.

---

### Task 7: ⛔ Human gate — merge and verify end-to-end CD

- [ ] **Step 1: Confirm with user**, then merge

Run: `gh pr merge codex/cicd-testflight-cd --squash --delete-branch`

- [ ] **Step 2: Watch Build → CD**

```bash
sleep 20; gh run list --workflow build.yml --limit 1
gh run watch "$(gh run list --workflow build.yml --limit 1 --json databaseId -q '.[0].databaseId')"
sleep 30; gh run watch "$(gh run list --workflow cd-testflight.yml --limit 1 --json databaseId -q '.[0].databaseId')"
gh run view "$(gh run list --workflow cd-testflight.yml --limit 1 --json databaseId -q '.[0].databaseId')" --log | grep -E '^.*(status|build_number|version|processing)='
```
Expected: Build success; CD success; `status=SUCCEEDED`, `build_number=N` with N > 40, `processing=VALID` (or `PROCESSING` if Apple is slow).

- [ ] **Step 3: Verify in App Store Connect**

```bash
asc builds list --app 6778478266 --limit 1 --output json | jq -c '.data[0].attributes | {version, processingState}'
asc xcode-cloud build-runs --workflow-id 4dd7aa78-9f72-4aeb-a623-9ef28a36f840 --limit 200 --paginate --output json \
  | jq -sc '[.[].data[]] | sort_by(.attributes.number) | .[-2:] | map({n: .attributes.number, reason: .attributes.startReason, status: .attributes.completionStatus})'
```
Expected: newest build = N, `VALID`; newest Beta run `startReason` = `MANUAL`, and no extra `GIT_REF_CHANGE` run for the merge commit (proves no double build). User confirms Slack ✅ and the build shows for `Qa` in TestFlight.

- [ ] **Step 4: Report** — results, run links, build N, and reminder to regenerate the Slack webhook (it was shared in chat) then update the secret with `gh secret set SLACK_WEBHOOK_URL`.

---

## Rollback

1. `gh workflow disable "CD TestFlight"`.
2. Restore Beta start condition: `branchStartCondition` = value from `backup/xcode-cloud-beta-before.json`, `manualBranchStartCondition: null`; re-enable PR Gate (`isEnabled: true`) — via `asc xcode-cloud workflows update` or web UI.
3. Branch protection: `gh api -X DELETE repos/{owner}/{repo}/branches/main/protection/required_status_checks`.
4. `testflight.yml` remains usable throughout.

## Self-Review

- Spec coverage: §3.1 → Task 3; §3.2 → Task 6; §3.3 → Tasks 1–2; §3.4 → Task 5; §3.5 → Task 4 (+ rotate reminder Task 7); §3.6 → Task 2 (AGENTS.md); §4 → Task 1 tests (+ processing FAILED addition); §5 → Tasks 4, 6, 7; §7 → Rollback.
- Names consistent: `scripts/cd-testflight.sh`, outputs `slack_text`/`status`/`build_number`/`version`/`processing`/`commit`, workflow `CD TestFlight`, job `notify-failure`, secret `SLACK_WEBHOOK_URL`.
- Known unknowns handled with explicit fallbacks: `asc workflows update` payload shape (Task 5 Steps 3–4), `asc run --wait` exit code (script ignores it; JSON is truth).
