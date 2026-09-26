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
