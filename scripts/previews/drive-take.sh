#!/bin/bash
# Plays the App Store preview storyboard in the booted simulator while
# OpenScreen records the Device Hub window. Logs each tap (epoch ms, x, y in
# simulator points) so the taps can be handed to OpenScreen's setPointerTrack.
#
# Usage: drive-take.sh <simulator-udid> [log-file]
# Needs AXe 2.x (brew install cameroncooke/axe/axe). Tap coordinates are for a
# 440x956 pt iPhone 17 Pro Max; re-read them with `axe describe-ui` on other sizes.
set -euo pipefail
U="$1"; L="${2:-taps.log}"; : > "$L"
ms(){ python3 -c 'import time;print(int(time.time()*1000))'; }
tap(){ echo "$(ms) $1 $2 $3" >> "$L"; axe tap -x "$1" -y "$2" --input-mode selected --udid "$U" >/dev/null 2>&1; }

echo "$(ms) 0 0 launch" >> "$L"
xcrun simctl launch "$U" stress.ai.com -demo-mode -hasCompletedOnboarding YES \
  -didShowOnboardingPaywall YES -preview-recording >/dev/null
sleep 5
tap 173 904 action;          sleep 3.5   # Action tab: Ripple's suggestion card
tap 248 326 startBreathing;  sleep 2.2   # "Start box breathing" -> intro
tap 220 799 begin;           sleep 7     # "Begin breathing session"
tap 115 746 endEarly;        sleep 0.9   # "End early" -> intro
tap 79 904 home;             sleep 3.2   # Home tab
echo "$(ms) 0 0 end" >> "$L"
