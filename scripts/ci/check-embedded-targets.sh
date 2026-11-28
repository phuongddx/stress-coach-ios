#!/usr/bin/env bash
# After a StressMonitor scheme build, checks that the watch app and the widget
# extension were built and embedded in the iOS app, and writes the result as
# step outputs (watchos=success|failure, widget=success|failure) for the
# "Build watchOS" and "Build Widget" required checks.
#
# Usage: scripts/ci/check-embedded-targets.sh <path to StressMonitor.app> <build step outcome>
set -uo pipefail

APP="${1:?usage: $0 <path to StressMonitor.app> <build step outcome>}"
BUILD_OUTCOME="${2:-}"
OUT="${GITHUB_OUTPUT:-/dev/stdout}"

check() { # <label> <bundle path> <output name>
  local label=$1 bundle=$2 name=$3 exe
  exe=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$bundle/Info.plist" 2>/dev/null || true)
  if [ "$BUILD_OUTCOME" = "success" ] && [ -n "$exe" ] && [ -f "$bundle/$exe" ]; then
    echo "OK: $label built and embedded at $bundle"
    echo "$name=success" >> "$OUT"
    return 0
  fi
  if [ "$BUILD_OUTCOME" != "success" ]; then
    echo "::error::$label: the build step ended with '${BUILD_OUTCOME:-not run}'."
  else
    echo "::error::$label not embedded: no executable in $bundle"
    ls -la "$APP" "$(dirname "$bundle")" 2>&1 | sed 's/^/  /'
  fi
  echo "$name=failure" >> "$OUT"
  return 1
}

rc=0
check "Watch app" "$APP/Watch/StressMonitorWatch Watch App.app" watchos || rc=1
check "Widget extension" "$APP/PlugIns/StressMonitorWidgetExtension.appex" widget || rc=1
exit $rc
