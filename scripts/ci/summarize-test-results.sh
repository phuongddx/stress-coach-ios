#!/usr/bin/env bash
# Prints a Markdown summary of an .xcresult: passed, failed and skipped counts
# (XCTest and Swift Testing together), the names of failed and skipped tests
# with the skip reason when the bundle has one, and the test count per suite.
#
# Usage: scripts/ci/summarize-test-results.sh <path to .xcresult>
set -euo pipefail

RESULT="${1:?usage: $0 <path to .xcresult>}"
echo "### Tests"
if [ ! -d "$RESULT" ]; then
  echo
  echo "No result bundle at \`$RESULT\`: the tests did not run (see the build step)."
  exit 0
fi

SUMMARY=$(mktemp) TESTS=$(mktemp)
trap 'rm -f "$SUMMARY" "$TESTS"' EXIT
xcrun xcresulttool get test-results summary --path "$RESULT" > "$SUMMARY"
xcrun xcresulttool get test-results tests --path "$RESULT" > "$TESTS"

jq -r '"**\(.result)**: \(.passedTests) passed, \(.failedTests) failed, \(.skippedTests) skipped (\(.totalTestCount) total)"' "$SUMMARY"
echo
echo "| Result | Count |"
echo "|---|---|"
jq -r '"| Passed | \(.passedTests) |", "| Failed | \(.failedTests) |", "| Skipped | \(.skippedTests) |", "| Expected failures | \(.expectedFailures // 0) |"' "$SUMMARY"

# Test cases with their suite (the nearest "Test Suite" ancestor).
list() { # <result>
  jq -r --arg r "$1" '
    def cases($suite):
      if .nodeType == "Test Suite" then .name as $s | (.children[]? | cases($s))
      elif .nodeType == "Test Case" then
        select(.result == $r)
        | "- `\(.nodeIdentifier // .name)` (\($suite // "?")): "
          + ([.children[]? | select(.nodeType == "Failure Message" or .nodeType == "Skip Message") | .name] | if length > 0 then (join("; ") | gsub("\n"; " ")) else .name end)
      else (.children[]? | cases($suite)) end;
    .testNodes[] | cases(null)' "$TESTS"
}

for R in Failed Skipped; do
  NAMES=$(list "$R")
  if [ -n "$NAMES" ]; then
    echo
    echo "#### $R tests"
    echo "$NAMES"
  fi
done

echo
echo "<details><summary>Tests per suite</summary>"
echo
echo "| Suite | Tests |"
echo "|---|---|"
jq -r '[.. | objects | select(.nodeType == "Test Suite")] | sort_by(.name)[] | "| \(.name) | \([.children[]? | select(.nodeType == "Test Case")] | length) |"' "$TESTS"
echo
echo "</details>"
