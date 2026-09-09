#!/bin/sh
# ci_post_clone.sh — Xcode Cloud post-clone provisioning.
#
# Restores the gitignored StressMonitor/GoogleService-Info.plist from the
# GOOGLE_SERVICE_INFO_PLIST_BASE64 workflow secret. The synchronized folder
# group picks the file up as a bundle resource automatically; without it
# FirebaseBootstrap no-ops and Chat / Auth / IAP ship dead in the build.
# A missing or corrupt secret must fail the build — never distribute a
# silently misconfigured binary.

set -e

DEST_DIR="$CI_PRIMARY_REPOSITORY_PATH/StressMonitor/StressMonitor"
DEST="$DEST_DIR/GoogleService-Info.plist"

if [ -z "${GOOGLE_SERVICE_INFO_PLIST_BASE64:-}" ]; then
    echo "error: GOOGLE_SERVICE_INFO_PLIST_BASE64 is not set." >&2
    echo "       Add it as a secret custom environment variable on the Xcode Cloud workflow." >&2
    exit 1
fi

mkdir -p "$DEST_DIR"
printf '%s' "$GOOGLE_SERVICE_INFO_PLIST_BASE64" | base64 --decode > "$DEST"

plutil -lint "$DEST"
plutil -extract CLIENT_ID raw "$DEST" > /dev/null

echo "Provisioned $DEST ($(wc -c < "$DEST" | tr -d ' ') bytes)"
