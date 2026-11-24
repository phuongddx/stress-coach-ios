#!/usr/bin/env bash
# Rebuild the README screenshots from a simulator build, driven by AXe.
#
#   scripts/screenshots/capture.sh <udid> <path to StressMonitor.app>
#
# The simulator must be booted. The app is launched in demo mode (simulated
# HealthKit data, DEBUG builds only) with onboarding marked done, then each
# screen is opened through its accessibility identifier or label and captured.
#
#   OUT_DIR   where the PNGs go             (default docs/screenshots)
#   WIDTH     width of the saved PNGs in px (default: the simulator's own pixels)
#   DEBUG_DIR full-size captures and UI dumps for every step (default build/screenshots)
set -euo pipefail

UDID="${1:?usage: capture.sh <udid> <app path>}"
APP="${2:?usage: capture.sh <udid> <app path>}"
BUNDLE_ID="stress.ai.com"
OUT_DIR="${OUT_DIR:-docs/screenshots}"
WIDTH="${WIDTH:-}"
DEBUG_DIR="${DEBUG_DIR:-build/screenshots}"
HERE="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$OUT_DIR" "$DEBUG_DIR"

ui() { axe describe-ui --udid "$UDID" 2>/dev/null; }

# wait_for <label> [seconds]: until an element with this label is on screen.
wait_for() {
  local label="$1" deadline=$((SECONDS + ${2:-30}))
  until ui | python3 "$HERE/axe_ui.py" has "$label"; do
    if [ "$SECONDS" -ge "$deadline" ]; then
      echo "error: \"$label\" did not appear within ${2:-30}s" >&2
      dump "missing-$(echo "$label" | tr -c 'A-Za-z0-9' '-')"
      return 1
    fi
    sleep 1
  done
}

# tap <label> [--lowest]: tap the centre of the element with this label.
tap() {
  local point
  point="$(ui | python3 "$HERE/axe_ui.py" find "$@")" || {
    echo "error: nothing to tap with label \"$1\"" >&2
    dump "missing-$(echo "$1" | tr -c 'A-Za-z0-9' '-')"
    return 1
  }
  # shellcheck disable=SC2086
  set -- $point
  axe tap -x "$1" -y "$2" --udid "$UDID" >/dev/null
}

# dump <name>: keep what the screen shows, for the workflow's artifact.
dump() {
  ui > "$DEBUG_DIR/$1.json" || true
  python3 "$HERE/axe_ui.py" list < "$DEBUG_DIR/$1.json" > "$DEBUG_DIR/$1.txt" 2>/dev/null || true
  axe screenshot --udid "$UDID" --output "$DEBUG_DIR/$1.png" >/dev/null 2>&1 || true
}

# shot <name>: capture the settled screen into OUT_DIR.
shot() {
  sleep "${SETTLE:-3}"
  dump "$1"
  cp "$DEBUG_DIR/$1.png" "$OUT_DIR/$1.png"
  [ -z "$WIDTH" ] || sips --resampleWidth "$WIDTH" "$OUT_DIR/$1.png" >/dev/null
  echo "captured $OUT_DIR/$1.png"
}

# open_tab <name>: tap a tab bar item and wait until that tab is selected.
open_tab() {
  local deadline=$((SECONDS + 15))
  tap "$1" --lowest
  until ui | python3 "$HERE/axe_ui.py" selected "$1"; do
    if [ "$SECONDS" -ge "$deadline" ]; then
      echo "error: the \"$1\" tab did not open" >&2
      dump "tab-$1"
      return 1
    fi
    sleep 1
  done
}

# The system Health Access sheet runs in another process, so AXe cannot see it
# or tap it. Demo mode never asks for Health access in DEBUG builds
# (HealthKitManager.requestAuthorization), so the sheet does not appear here.

launch() {
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  # -didShowOnboardingPaywall YES (OnboardingPaywallGate.didShowKey): the
  # one-time Plus paywall would otherwise cover Home on a fresh simulator.
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -demo-mode -hasCompletedOnboarding YES \
    -didShowOnboardingPaywall YES
  wait_for "Trends" 90        # the tab bar is up
}

xcrun simctl status_bar "$UDID" override \
  --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl ui "$UDID" appearance light
xcrun simctl install "$UDID" "$APP"

launch
SETTLE=8 shot "1-home"        # demo data loads and the gauge animates in

open_tab "Trends"
shot "2-trends"

open_tab "Action"
wait_for "action.card.talkToRipple" 20   # on Ripple's card, top of Action
tap "action.card.talkToRipple"
wait_for "Sees your scores" 20  # the Ripple chat sheet is up
SETTLE=6 shot "3-chat"

launch                        # drops the chat sheet
open_tab "Action"
wait_for "action.boxBreathing" 20
tap "action.boxBreathing"
wait_for "Breathe in, hold" 20  # the Box breathing intro
shot "4-breathing"

# 5-premium.png is not rebuilt: purchases are switched off in this build, so
# Settings has no "StressMonitor Plus" row to open the paywall from.
