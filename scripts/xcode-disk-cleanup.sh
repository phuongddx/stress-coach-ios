#!/usr/bin/env bash
# Reclaim disk space used by Xcode on a developer Mac.
# Dry run by default: it only reports sizes and prints what --delete would remove.
#
# Usage:
#   scripts/xcode-disk-cleanup.sh               # dry run (read-only)
#   scripts/xcode-disk-cleanup.sh --delete      # actually remove
#   scripts/xcode-disk-cleanup.sh --days 14     # DerivedData age threshold (default 7)
#
# With --delete it removes:
#   - unavailable simulators (`xcrun simctl delete unavailable`)
#   - top-level DerivedData folders not modified in the last N days
#   - the SwiftPM cache (~/Library/Caches/org.swift.swiftpm)
# It never removes simulator runtimes or available simulator devices.

set -euo pipefail

DELETE=0
DAYS=7

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --delete) DELETE=1; shift ;;
    --days)
      [[ $# -ge 2 ]] || { echo "error: --days needs a value" >&2; exit 2; }
      DAYS="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
  echo "error: --days must be a non-negative integer, got '$DAYS'" >&2
  exit 2
fi

DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
SIM_DEVICES="$HOME/Library/Developer/CoreSimulator/Devices"
XCTEST_DEVICES="$HOME/Library/Developer/XCTestDevices"
SPM_CACHE="$HOME/Library/Caches/org.swift.swiftpm"
SPM_CONFIG="$HOME/Library/org.swift.swiftpm"

HAVE_SIMCTL=0
if command -v xcrun >/dev/null 2>&1 && xcrun --find simctl >/dev/null 2>&1; then
  HAVE_SIMCTL=1
fi

dir_size() {
  if [[ -d "$1" ]]; then
    { du -sh "$1" 2>/dev/null || true; } | awk 'NR==1 { print $1 }'
  else
    echo "missing"
  fi
}

report_sizes() {
  echo "== Disk usage ($1) =="
  local d
  for d in "$DERIVED_DATA" "$SIM_DEVICES" "$XCTEST_DEVICES" "$SPM_CACHE" "$SPM_CONFIG"; do
    printf '  %-8s %s\n' "$(dir_size "$d")" "$d"
  done
  echo
}

report_runtimes() {
  echo "== Simulator runtimes (listed only, never removed) =="
  if [[ $HAVE_SIMCTL -eq 1 ]]; then
    xcrun simctl runtime list 2>/dev/null | sed 's/^/  /' || echo "  (could not list runtimes)"
  else
    echo "  (xcrun simctl not available; skipped)"
  fi
  echo
}

if [[ $DELETE -eq 1 ]]; then
  echo "Mode: DELETE (DerivedData older than $DAYS days)"
else
  echo "Mode: dry run (nothing will be removed; pass --delete to act; DerivedData older than $DAYS days)"
fi
echo

report_sizes "before"
report_runtimes

# --- Unavailable simulators -------------------------------------------------
echo "== Unavailable simulators =="
if [[ $HAVE_SIMCTL -eq 1 ]]; then
  unavailable=$(xcrun simctl list devices unavailable 2>/dev/null | grep -E '\(unavailable' || true)
  if [[ -z "$unavailable" ]]; then
    echo "  none"
  else
    printf '%s\n' "$unavailable" | sed 's/^ */  /'
    if [[ $DELETE -eq 1 ]]; then
      echo "  -> xcrun simctl delete unavailable"
      xcrun simctl delete unavailable
    else
      echo "  would run: xcrun simctl delete unavailable"
    fi
  fi
else
  echo "  (xcrun simctl not available; skipped)"
fi
echo

# --- Old DerivedData folders ------------------------------------------------
# A rebuild writes under Build/ or Logs/ without touching the project folder's own
# mtime, so a folder counts as old only when nothing inside it is newer either.
echo "== DerivedData folders with nothing modified in $DAYS+ days =="
if [[ -d "$DERIVED_DATA" ]]; then
  found=0
  while IFS= read -r -d '' entry; do
    if [[ -n "$(find "$entry" ! -mtime +"$DAYS" -print -quit 2>/dev/null)" ]]; then
      continue
    fi
    found=1
    printf '  %-8s %s\n' "$(dir_size "$entry")" "$(basename "$entry")"
    if [[ $DELETE -eq 1 ]]; then
      rm -rf -- "$entry"
    fi
  done < <(find "$DERIVED_DATA" -mindepth 1 -maxdepth 1 -type d -mtime +"$DAYS" -print0 2>/dev/null)
  if [[ $found -eq 0 ]]; then
    echo "  none"
  elif [[ $DELETE -eq 1 ]]; then
    echo "  -> removed"
  else
    echo "  would remove the folders above"
  fi
else
  echo "  (missing: $DERIVED_DATA)"
fi
echo

# --- SwiftPM cache ----------------------------------------------------------
echo "== SwiftPM cache =="
if [[ -d "$SPM_CACHE" ]]; then
  printf '  %-8s %s\n' "$(dir_size "$SPM_CACHE")" "$SPM_CACHE"
  if [[ $DELETE -eq 1 ]]; then
    rm -rf -- "$SPM_CACHE"
    echo "  -> removed"
  else
    echo "  would remove it"
  fi
else
  echo "  (missing: $SPM_CACHE)"
fi
echo

if [[ $DELETE -eq 1 ]]; then
  report_sizes "after"
else
  echo "Dry run complete. Re-run with --delete to remove the items above."
fi
