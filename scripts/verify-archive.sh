#!/bin/bash
# Verify StressMonitor archive — entitlements, merged plists, credential scan, resource grep, SDK privacy manifests.
# Works locally and in CI. Read-only artifact inspection: this script never signs and never modifies the archive.
#
# Usage:
#   bash scripts/verify-archive.sh <path-to-.xcarchive | dir-containing-Payload> [--skip-entitlements]
#   bash scripts/verify-archive.sh --scan-binary <mach-o-file>   # AUTH-01 scan mode on a single binary
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

APP_GROUP="group.stress.ai.com"
WIDGET_POINT_ID="com.apple.widgetkit-extension"

# Merged-plist keys that must NOT be present in this free-only release — this app ships
# no IAP (see plans/260925-0819-remove-iap-mentions). A merged app Info.plist containing
# any of these keys means IAP evidence leaked back into the build. Kept for documentation
# only: the actual check below matches ANY key prefixed STOREKIT_, not just these six, so
# it also catches a future/renamed StoreKit key such as STOREKIT_CREDITS_MEDIUM_PRODUCT_ID.
STOREKIT_KEYS=(
    STOREKIT_CREDITS_LARGE_PRODUCT_ID
    STOREKIT_CREDITS_SMALL_PRODUCT_ID
    STOREKIT_PREMIUM_ANNUAL_PRODUCT_ID
    STOREKIT_PREMIUM_MONTHLY_PRODUCT_ID
    STOREKIT_PREMIUM_WEEKLY_PRODUCT_ID
    STOREKIT_PREMIUM_SUBSCRIPTION_GROUP_ID
)

# AUTH-01 credential-scan pattern set (case-insensitive): private-key material, sk- prefixed
# keys, anon keys, api secrets, PEM headers, Bearer tokens (20+ token chars), Supabase
# sb_publishable/sb_secret key forms, and the eyJ JWT shape.
SCAN_PATTERNS="PRIVATE KEY|sk-[A-Za-z0-9]|anon[_-]?key|api[_-]?secret|BEGIN RSA|BEGIN EC|Bearer [A-Za-z0-9._-]{20,}|sb_(publishable|secret)|eyJ"

# Benign allowlist (triage list — keep in sync with phase research §7). These known hits are
# subtracted before the verdict; each has a documented benign explanation:
#   - eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ==  — base64 {"error":"UNKNOWN_ERROR"}, a Google App
#     Check SDK error constant (adjacent strings: com.google.app_check_core.token_storage).
#   - supabaseAccessToken, supabaseRefreshToken, supabaseSessionExpiresAt, supabaseChatSessionId —
#     legacy Keychain account-name literals REMOVED by FirebaseAuthService.swift (~line 133).
#     Key names, not tokens.
#   - stress-api.dropitx.site — backend endpoint (StressAPIConfig.swift fallback URL).
#   - stress.ai.com — bundle-id fragments.
#   - com.googleusercontent.apps — GoogleSignIn URL-scheme prefix.
# Anything else matching SCAN_PATTERNS fails the gate. The script prints pattern names and
# files only — never the matched content; the operator re-runs strings manually to triage.
ALLOWLIST="eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ==|supabase(AccessToken|RefreshToken|SessionExpiresAt|ChatSessionId)|stress-api\.dropitx\.site|stress\.ai\.com|com\.googleusercontent\.apps"

FAILURES=0

note_fail() {
    echo "FAIL $1 — $2"
    FAILURES=$((FAILURES + 1))
}

note_pass() {
    echo "PASS $1 — $2"
}

usage() {
    sed -n '2,7p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

scan_binary() { # $1 = binary path, $2 = label; prints result, returns 1 on hits
    local bin="$1" label="$2"
    if [ ! -f "$bin" ]; then
        note_fail "CREDENTIAL SCAN $label" "binary not found: $bin"
        return 1
    fi
    local hits=""
    hits=$(strings -a "$bin" | grep -iE "$SCAN_PATTERNS" | grep -viE "$ALLOWLIST" || true)
    if [ -n "$hits" ]; then
        local names=""
        if grep -qi "PRIVATE KEY" <<<"$hits"; then names="${names}private-key "; fi
        if grep -qiE "sk-[A-Za-z0-9]" <<<"$hits"; then names="${names}sk-prefix "; fi
        if grep -qiE "anon[_-]?key" <<<"$hits"; then names="${names}anon-key "; fi
        if grep -qiE "api[_-]?secret" <<<"$hits"; then names="${names}api-secret "; fi
        if grep -qi "BEGIN RSA" <<<"$hits"; then names="${names}begin-rsa "; fi
        if grep -qi "BEGIN EC" <<<"$hits"; then names="${names}begin-ec "; fi
        if grep -qE "Bearer [A-Za-z0-9._-]{20,}" <<<"$hits"; then names="${names}bearer-token "; fi
        if grep -qiE "sb_(publishable|secret)" <<<"$hits"; then names="${names}sb-key "; fi
        if grep -q "eyJ" <<<"$hits"; then names="${names}jwt-shape "; fi
        note_fail "CREDENTIAL SCAN $label" "${names:-unknown}hit(s) in $(basename "$bin") — triage: strings -a '$bin' | grep -iE '<SCAN_PATTERNS>'"
        return 1
    fi
    note_pass "CREDENTIAL SCAN $label" "no hits after benign allowlist"
    return 0
}

# ---------------------------------------------------------------- argument parsing

SKIP_ENTITLEMENTS=0
SCAN_TARGET=""
ARCHIVE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --skip-entitlements)
            SKIP_ENTITLEMENTS=1
            ;;
        --scan-binary)
            if [ $# -lt 2 ]; then
                echo "ERROR: --scan-binary requires a file argument" >&2
                exit 2
            fi
            SCAN_TARGET="$2"
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        -*)
            echo "ERROR: unknown flag: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            if [ -n "$ARCHIVE" ]; then
                echo "ERROR: unexpected extra argument: $1" >&2
                exit 2
            fi
            ARCHIVE="$1"
            ;;
    esac
    shift
done

# Scan mode: AUTH-01 credential scan on a single Mach-O, nothing else.
if [ -n "$SCAN_TARGET" ]; then
    scan_binary "$SCAN_TARGET" "(scan mode: $(basename "$SCAN_TARGET"))"
    exit $((FAILURES > 0 ? 1 : 0))
fi

if [ -z "$ARCHIVE" ]; then
    echo "ERROR: pass a path to an .xcarchive or a directory containing Payload/" >&2
    usage >&2
    exit 2
fi

# ---------------------------------------------------------------- bundle resolution

if [ -d "$ARCHIVE/Payload/StressMonitor.app" ]; then
    APP_BUNDLE="$ARCHIVE/Payload/StressMonitor.app" # unzipped IPA
elif [ -d "$ARCHIVE/Products/Applications/StressMonitor.app" ]; then
    APP_BUNDLE="$ARCHIVE/Products/Applications/StressMonitor.app" # .xcarchive
else
    echo "ERROR: no StressMonitor.app under '$ARCHIVE' (expected Products/Applications/ or Payload/)" >&2
    exit 2
fi

WIDGET_APPEX="$APP_BUNDLE/PlugIns/StressMonitorWidgetExtension.appex"
WATCH_APP="$APP_BUNDLE/Watch/StressMonitorWatch Watch App.app"
WIDGET_PLIST="$WIDGET_APPEX/Info.plist"
APP_PLIST="$APP_BUNDLE/Info.plist"

# ---------------------------------------------------------------- check 1: entitlements x3

if [ "$SKIP_ENTITLEMENTS" -eq 1 ]; then
    echo "SKIP ENTITLEMENTS — --skip-entitlements set (unsigned archive; entitlements proven at source level / on the signed golden archive)"
else
    ENT_BUNDLES=("$APP_BUNDLE" "$WIDGET_APPEX" "$WATCH_APP")
    ENT_LABELS=("StressMonitor.app:" "PlugIns/StressMonitorWidgetExtension.appex:" "Watch/StressMonitorWatch Watch App.app:")
    for i in "${!ENT_BUNDLES[@]}"; do
        bundle="${ENT_BUNDLES[$i]}"
        label="${ENT_LABELS[$i]}"
        if [ ! -d "$bundle" ]; then
            note_fail "ENTITLEMENTS $label" "bundle not found: $bundle"
            continue
        fi
        dump=$(codesign -d --entitlements :- "$bundle" 2>/dev/null || true)
        if [ -z "$dump" ]; then
            note_fail "ENTITLEMENTS $label" "no entitlements blob (build-12 regression class)"
        elif grep -q "com.apple.security.application-groups" <<<"$dump" && grep -q "$APP_GROUP" <<<"$dump"; then
            note_pass "ENTITLEMENTS $label" "application-groups contains $APP_GROUP"
        else
            note_fail "ENTITLEMENTS $label" "application-groups/$APP_GROUP missing from entitlements"
        fi
    done
fi

# ---------------------------------------------------------------- check 2: merged plists

APP_PLIST_DUMP=""
if [ -f "$APP_PLIST" ]; then
    APP_PLIST_DUMP=$(plutil -p "$APP_PLIST")
else
    note_fail "MERGED PLISTS" "app Info.plist not found: $APP_PLIST"
fi

if [ -n "$APP_PLIST_DUMP" ]; then
    # Prefix match (not the STOREKIT_KEYS list above) so a renamed/new StoreKit key
    # is caught too. Anchored to the dump's "key" => line shape so a STOREKIT_-prefixed
    # *value* under an unrelated key can't produce a false positive.
    plist_present=""
    while IFS= read -r key; do
        [ -n "$key" ] && plist_present="$plist_present $key"
    done < <(grep -oE '^[[:space:]]*"STOREKIT_[^"]+"[[:space:]]*=>' <<<"$APP_PLIST_DUMP" \
        | grep -oE '"STOREKIT_[^"]+"' | tr -d '"' | sort -u)
    if [ -n "$plist_present" ]; then
        note_fail "MERGED PLISTS" "this release ships no IAP — found STOREKIT keys that must not be present:$plist_present"
    else
        note_pass "MERGED PLISTS" "no STOREKIT_* keys present in app Info.plist (expected for this free-only release)"
    fi

    # The URL-schemes check parses the canonical XML serialization instead of
    # grepping the human-readable dump: the dump's key line itself always
    # contains quotes, so an empty CFBundleURLSchemes array passed vacuously.
    # The check passes only when at least one <string> entry appears inside
    # the array that follows the key.
    app_plist_xml=$(plutil -convert xml1 -o - -- "$APP_PLIST" 2>/dev/null || true)
    if [ -n "$app_plist_xml" ] && awk '
        /<key>CFBundleURLSchemes<\/key>/ { in_schemes = 1; next }
        in_schemes && /<string>/ { found = 1; exit }
        in_schemes && /<\/array>|<array\/>/ { in_schemes = 0 }
        END { exit found ? 0 : 1 }
    ' <<<"$app_plist_xml"; then
        note_pass "MERGED PLISTS" "CFBundleURLSchemes has at least one entry (GoogleSignIn callback)"
    else
        note_fail "MERGED PLISTS" "CFBundleURLSchemes missing or empty in app Info.plist"
    fi
fi

if [ -f "$WIDGET_PLIST" ]; then
    if plutil -p "$WIDGET_PLIST" | grep '"NSExtensionPointIdentifier"' | grep -q "$WIDGET_POINT_ID"; then
        note_pass "MERGED PLISTS" "widget NSExtensionPointIdentifier = $WIDGET_POINT_ID"
    else
        note_fail "MERGED PLISTS" "widget NSExtensionPointIdentifier wrong/missing"
    fi
else
    note_fail "MERGED PLISTS" "widget Info.plist not found: $WIDGET_PLIST"
fi

# ---------------------------------------------------------------- check 3: credential scan x3

scan_binary "$APP_BUNDLE/StressMonitor" "app" || true
scan_binary "$WIDGET_APPEX/StressMonitorWidgetExtension" "widget" || true
scan_binary "$WATCH_APP/StressMonitorWatch Watch App" "watch" || true

# ---------------------------------------------------------------- check 4: AIza resource grep

aiza_matches=$(grep -rl "AIza" "$APP_BUNDLE" 2>/dev/null || true)
aiza_offender=""
if [ -n "$aiza_matches" ]; then
    while IFS= read -r f; do
        if [ "$(basename "$f")" != "GoogleService-Info.plist" ]; then
            aiza_offender="$aiza_offender $f"
        fi
    done <<<"$aiza_matches"
fi
if [ -n "$aiza_offender" ]; then
    note_fail "RESOURCE GREP" "AIza outside GoogleService-Info.plist:$aiza_offender (Firebase identifiers are public by Google's model; a Mach-O hit is a triage change)"
elif [ -n "$aiza_matches" ]; then
    note_pass "RESOURCE GREP" "AIza only in GoogleService-Info.plist (expected: Firebase identifiers, public by design)"
else
    note_fail "RESOURCE GREP" "no AIza anywhere — GoogleService-Info.plist missing from bundle?"
fi

# ---------------------------------------------------------------- check 5: SDK privacy manifests

firebase_manifests=$(find "$APP_BUNDLE" -path "*Firebase_FirebaseCore.bundle/PrivacyInfo.xcprivacy" 2>/dev/null || true)
googlesignin_manifests=$(find "$APP_BUNDLE" -path "*GoogleSignIn_GoogleSignIn.bundle/PrivacyInfo.xcprivacy" 2>/dev/null || true)

if [ -n "$firebase_manifests" ] && [ -n "$googlesignin_manifests" ]; then
    note_pass "SDK MANIFESTS" "Firebase_FirebaseCore + GoogleSignIn_GoogleSignIn PrivacyInfo.xcprivacy present"
else
    missing=""
    [ -z "$firebase_manifests" ] && missing="$missing Firebase_FirebaseCore.bundle/PrivacyInfo.xcprivacy"
    [ -z "$googlesignin_manifests" ] && missing="$missing GoogleSignIn_GoogleSignIn.bundle/PrivacyInfo.xcprivacy"
    note_fail "SDK MANIFESTS" "missing:$missing (third-party SDK resource bundles stopped flowing — check the SPM proxy graph)"
fi

# ---------------------------------------------------------------- verdict

if [ "$FAILURES" -gt 0 ]; then
    echo "verify-archive: $FAILURES check failure(s)"
    exit 1
fi
echo "verify-archive: all checks passed"
exit 0
