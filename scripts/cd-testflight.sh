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
