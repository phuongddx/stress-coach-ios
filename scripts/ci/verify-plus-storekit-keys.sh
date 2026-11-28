#!/usr/bin/env bash
# Checks the merged Info.plist of a built StressMonitor.app: the three Plus
# StoreKit keys are present with com.stressmonitor.app.plus.* product IDs, and
# no credit-pack keys are left (1.1 sells StressMonitor Plus only).
#
# Usage: scripts/ci/verify-plus-storekit-keys.sh <path to StressMonitor.app>
set -euo pipefail

APP="${1:?usage: $0 <path to StressMonitor.app>}"
PLIST="$APP/Info.plist"
if [ ! -f "$PLIST" ]; then
  echo "error: merged Info.plist not found at $PLIST" >&2
  exit 1
fi

# Device builds write a binary plist; convert a copy so grep sees the keys.
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
plutil -convert xml1 -o "$TMP" "$PLIST"

HITS=$(grep -c STOREKIT_CREDITS "$TMP") || [ $? -eq 1 ]
if [ "$HITS" -ne 0 ]; then
  echo "error: found $HITS STOREKIT_CREDITS_* reference(s) in $PLIST — credit packs are not sold in 1.1." >&2
  exit 1
fi
for KEY in STOREKIT_PREMIUM_MONTHLY_PRODUCT_ID STOREKIT_PREMIUM_ANNUAL_PRODUCT_ID STOREKIT_PREMIUM_SUBSCRIPTION_GROUP_ID; do
  VALUE=$(/usr/libexec/PlistBuddy -c "Print :$KEY" "$PLIST" 2>/dev/null || true)
  if [ -z "$VALUE" ]; then
    echo "error: $KEY missing or empty in $PLIST." >&2
    exit 1
  fi
  case "$KEY" in
    *_PRODUCT_ID)
      case "$VALUE" in
        com.stressmonitor.app.plus.*) ;;
        *) echo "error: $KEY=$VALUE must start with com.stressmonitor.app.plus." >&2; exit 1 ;;
      esac ;;
  esac
done
echo "OK: Plus StoreKit keys present with plus.* product IDs; no credit-pack keys ($PLIST)"
