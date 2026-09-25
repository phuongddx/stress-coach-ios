#!/bin/bash
# Bidirectional tests for verify-archive.sh.
#
# Golden-archive tests (1, 2, 3, 4) require the preserved build-13 archive at
# .asc/artifacts/StressMonitor.xcarchive — gitignored (*.xcarchive), so it
# exists only on machines that kept it manually; no CI workflow provisions
# it today. When it is absent those tests skip with a message below.
# Tests 5-7 run on planted temp archives and always execute.
#
# Proves the artifact gate detects what it claims to detect:
#   1. ENTITLEMENTS checks pass on the golden build-13 archive; MERGED PLISTS is
#               EXPECTED to FAIL there for the six legacy STOREKIT_* keys this frozen
#               build predates removing (plans/260925-0819-remove-iap-mentions) — also
#               asserts the exact "verify-archive: 1 check failure(s)" summary line, so
#               a mere nonzero exit can't hide some other check also failing.
#   2. RED    — a copy of the golden app binary with a planted JWT-shaped string
#               appended makes the credential scan (scan mode) exit non-zero.
#   3. ENTITLEMENTS — the per-bundle entitlements check reports PASS for all three
#               bundles (app, widget appex, watch app) of the golden archive.
#   4. GREEN  — a copy of the golden archive with the six legacy STOREKIT_* keys
#               deleted from its app Info.plist exits 0 and reports the
#               no-STOREKIT-keys PASS line — proves the gate can fully pass (11/11
#               internal checks, full mode — same mode Task 7's TestFlight gate
#               uses) on a real post-cleanup archive, not just a synthetic one.
#   5. RED    — a planted app Info.plist with an empty CFBundleURLSchemes array
#               makes the merged-plists URL-schemes check report FAIL, and the
#               PASS line must NOT appear (guards against the check passing on
#               the key line's own quotes). This same planted plist has no
#               STOREKIT_* keys (free-only release), so it must also report the
#               no-STOREKIT-keys PASS.
#   6. GREEN  — the same planted plist with one scheme entry reports PASS.
#   7. RED    — a planted plist with exactly one STOREKIT_* key present must FAIL
#               MERGED PLISTS naming that key, must NOT emit the no-STOREKIT-keys
#               PASS line, and must exit non-zero — proves the gate's bite does not
#               depend on the gitignored golden archive and can't be silently broken
#               to always-pass.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERIFY="$SCRIPT_DIR/verify-archive.sh"
GOLDEN_APP="$REPO_ROOT/.asc/artifacts/StressMonitor.xcarchive/Products/Applications/StressMonitor.app"
GOLDEN="$REPO_ROOT/.asc/artifacts/StressMonitor.xcarchive"
PLANTED="eyJhbGciOiJIUzI1NiJ9.PLANTEDSECRETVALUE.forTestingPurposes"

failures=0

expect_pass() { # name, condition already evaluated by caller via $?
    if [ "$1" -eq 0 ]; then
        echo "PASS $2"
    else
        echo "FAIL $2"
        failures=$((failures + 1))
    fi
}

# The golden archive is gitignored (*.xcarchive) and exists only on machines that
# preserved it manually — no CI workflow provisions it. Skip its four tests with
# a clear message instead of cascading failures; the planted-plist tests below
# still run because they need no golden.
GOLDEN_PRESENT=1
if [ ! -d "$GOLDEN" ]; then
    GOLDEN_PRESENT=0
    echo "SKIP: golden archive not present ($GOLDEN) — golden-archive tests (1,2,3,4) skipped; planted-plist tests still run"
fi

if [ "$GOLDEN_PRESENT" -eq 1 ]; then

    # Test 1: the gate's ENTITLEMENTS checks pass on the known-good build-13 archive.
    # NOTE: this frozen build predates the free-only-release IAP cleanup
    # (plans/260925-0819-remove-iap-mentions) and still bakes in the six legacy
    # STOREKIT_* keys, so under the inverted MERGED PLISTS check it is EXPECTED to
    # report FAIL MERGED PLISTS for them and exit non-zero overall — that failure
    # is correct, not a regression.
    bash "$VERIFY" "$GOLDEN" > /tmp/verify-archive-tests-green.$$ 2>&1
    rc=$?
    grep -q "PASS ENTITLEMENTS" /tmp/verify-archive-tests-green.$$
    a=$?
    grep -qF "FAIL MERGED PLISTS — this release ships no IAP — found STOREKIT keys that must not be present" /tmp/verify-archive-tests-green.$$
    s=$?
    grep -qF "verify-archive: 1 check failure(s)" /tmp/verify-archive-tests-green.$$
    f=$?
    [ "$rc" -ne 0 ] && [ "$a" -eq 0 ] && [ "$s" -eq 0 ] && [ "$f" -eq 0 ]
    expect_pass $? "test_entitlements_pass_and_legacy_storekit_fail_on_golden_archive (exit=$rc, entitlements=$a, expected-legacy-storekit-fail=$s, exactly-one-failure=$f)"
    rm -f /tmp/verify-archive-tests-green.$$

    # Test 2 (red direction): planted JWT-shaped string in a binary copy must trip the scan.
    # NOTE: macOS strings parses Mach-O and stops at the object's last section, so bytes appended
    # past EOF are invisible to it. The secret is planted by overwriting bytes at the file
    # midpoint: the copy remains a Mach-O and the unmodified `strings -a` pipeline detects it —
    # the same visibility a credential embedded in a shipped binary would have.
    TMPD=$(mktemp -d)
    cp "$GOLDEN_APP/StressMonitor" "$TMPD/tampered"
    TSIZE=$(stat -f%z "$TMPD/tampered")
    printf '%s' "$PLANTED" | dd of="$TMPD/tampered" bs=1 seek=$((TSIZE / 2)) conv=notrunc status=none
    planted_count=$(strings -a "$TMPD/tampered" | grep -c "PLANTEDSECRETVALUE" || true)
    bash "$VERIFY" --scan-binary "$TMPD/tampered" > /dev/null 2>&1
    rc=$?
    [ "$rc" -ne 0 ] && [ "$planted_count" -ge 1 ]
    expect_pass $? "test_red_on_planted_secret (scan exit=$rc, planted string visible via strings: $planted_count hit(s))"
    rm -rf "$TMPD"

    # Test 3 (entitlements direction): all three bundles report the app group.
    # NOTE: does not require overall exit=0 — this golden build predates the IAP
    # cleanup and legitimately fails MERGED PLISTS for legacy STOREKIT_* keys (see
    # Test 1 above); only the ENTITLEMENTS lines are asserted here.
    bash "$VERIFY" "$GOLDEN" > /tmp/verify-archive-tests-ent.$$ 2>&1
    rc=$?
    grep -q "PASS ENTITLEMENTS StressMonitor.app:" /tmp/verify-archive-tests-ent.$$
    a=$?
    grep -q "PASS ENTITLEMENTS PlugIns/StressMonitorWidgetExtension.appex:" /tmp/verify-archive-tests-ent.$$
    b=$?
    grep -q "PASS ENTITLEMENTS Watch/StressMonitorWatch Watch App.app:" /tmp/verify-archive-tests-ent.$$
    c=$?
    [ "$a" -eq 0 ] && [ "$b" -eq 0 ] && [ "$c" -eq 0 ]
    expect_pass $? "test_entitlements_all_three_bundles (app=$a widget=$b watch=$c)"
    rm -f /tmp/verify-archive-tests-ent.$$

    # Test 4 (green direction): a copy of the golden archive with the six legacy
    # STOREKIT_* keys deleted from its app Info.plist must fully pass (exit 0) —
    # proves the gate can pass end-to-end on a real archive, not only a synthetic
    # minimal one.
    TMPD4=$(mktemp -d)
    cp -RH "$GOLDEN" "$TMPD4/golden-copy"
    CLEAN_APP_PLIST="$TMPD4/golden-copy/Products/Applications/StressMonitor.app/Info.plist"
    /usr/libexec/PlistBuddy \
        -c 'Delete :STOREKIT_CREDITS_LARGE_PRODUCT_ID' \
        -c 'Delete :STOREKIT_CREDITS_SMALL_PRODUCT_ID' \
        -c 'Delete :STOREKIT_PREMIUM_ANNUAL_PRODUCT_ID' \
        -c 'Delete :STOREKIT_PREMIUM_MONTHLY_PRODUCT_ID' \
        -c 'Delete :STOREKIT_PREMIUM_WEEKLY_PRODUCT_ID' \
        -c 'Delete :STOREKIT_PREMIUM_SUBSCRIPTION_GROUP_ID' \
        "$CLEAN_APP_PLIST" >/dev/null 2>&1
    bash "$VERIFY" "$TMPD4/golden-copy" > "$TMPD4/golden-clean.log" 2>&1
    rc=$?
    grep -qF "PASS MERGED PLISTS — no STOREKIT_* keys present in app Info.plist" "$TMPD4/golden-clean.log"
    p=$?
    [ "$rc" -eq 0 ] && [ "$p" -eq 0 ]
    expect_pass $? "test_green_on_golden_archive_copy_with_storekit_keys_removed (exit=$rc, no-storekit-pass=$p)"
    rm -rf "$TMPD4"

fi

# Tests 5 & 6 (URL-schemes direction): the CFBundleURLSchemes check must FAIL on
# an empty array and PASS on a populated one. These run against a planted minimal
# archive, so they exercise the check without needing the golden.
TMPD2=$(mktemp -d)
PLANTED_APP="$TMPD2/planted/Products/Applications/StressMonitor.app"
mkdir -p "$PLANTED_APP"
PPLIST="$PLANTED_APP/Info.plist"
plutil -create xml1 "$PPLIST" >/dev/null
/usr/libexec/PlistBuddy \
    -c 'Add :CFBundleURLTypes array' \
    -c 'Add :CFBundleURLTypes:0 dict' \
    -c 'Add :CFBundleURLTypes:0:CFBundleURLSchemes array' \
    "$PPLIST" >/dev/null 2>&1

# Test 5 (red direction): empty CFBundleURLSchemes must FAIL — and must not emit
# the PASS line (the vacuous form that matched the key line's own quotes). This
# planted plist also has no STOREKIT_* keys (free-only release), so it must
# report PASS MERGED PLISTS for that check too.
bash "$VERIFY" --skip-entitlements "$TMPD2/planted" > "$TMPD2/red-urlschemes.log" 2>&1
grep -q "CFBundleURLSchemes missing or empty" "$TMPD2/red-urlschemes.log"
a=$?
grep -q "CFBundleURLSchemes has at least one entry" "$TMPD2/red-urlschemes.log"
b=$?
grep -qF "PASS MERGED PLISTS — no STOREKIT_* keys present in app Info.plist" "$TMPD2/red-urlschemes.log"
s=$?
[ "$a" -eq 0 ] && [ "$b" -ne 0 ] && [ "$s" -eq 0 ]
expect_pass $? "test_red_on_empty_cfbundleurlschemes (fail line present=$a, vacuous pass absent=$b, storekit-absent pass=$s)"

# Test 6 (green direction): one scheme entry must PASS — and must not emit the
# FAIL line.
/usr/libexec/PlistBuddy \
    -c 'Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string com.googleusercontent.apps.planted' \
    "$PPLIST" >/dev/null 2>&1
bash "$VERIFY" --skip-entitlements "$TMPD2/planted" > "$TMPD2/green-urlschemes.log" 2>&1
grep -q "CFBundleURLSchemes has at least one entry" "$TMPD2/green-urlschemes.log"
a=$?
grep -q "CFBundleURLSchemes missing or empty" "$TMPD2/green-urlschemes.log"
b=$?
[ "$a" -eq 0 ] && [ "$b" -ne 0 ]
expect_pass $? "test_green_on_populated_cfbundleurlschemes (pass line present=$a, fail line absent=$b)"
rm -rf "$TMPD2"

# Test 7 (red direction): exactly one STOREKIT_* key present in an otherwise-clean
# planted plist must FAIL MERGED PLISTS naming that key, must NOT emit the
# no-STOREKIT-keys PASS line, and must exit non-zero — proves the bite doesn't
# depend on the golden archive and can't be silently broken to always-pass.
TMPD3=$(mktemp -d)
SINGLE_KEY_APP="$TMPD3/singlekey/Products/Applications/StressMonitor.app"
mkdir -p "$SINGLE_KEY_APP"
SKPLIST="$SINGLE_KEY_APP/Info.plist"
plutil -create xml1 "$SKPLIST" >/dev/null
/usr/libexec/PlistBuddy \
    -c 'Add :STOREKIT_CREDITS_MEDIUM_PRODUCT_ID string credits.medium.reintroduced' \
    -c 'Add :CFBundleURLTypes array' \
    -c 'Add :CFBundleURLTypes:0 dict' \
    -c 'Add :CFBundleURLTypes:0:CFBundleURLSchemes array' \
    -c 'Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string com.googleusercontent.apps.singlekey' \
    "$SKPLIST" >/dev/null 2>&1
bash "$VERIFY" --skip-entitlements "$TMPD3/singlekey" > "$TMPD3/singlekey.log" 2>&1
rc=$?
grep -qF "FAIL MERGED PLISTS — this release ships no IAP — found STOREKIT keys that must not be present: STOREKIT_CREDITS_MEDIUM_PRODUCT_ID" "$TMPD3/singlekey.log"
a=$?
grep -qF "PASS MERGED PLISTS — no STOREKIT_* keys present" "$TMPD3/singlekey.log"
b=$?
[ "$rc" -ne 0 ] && [ "$a" -eq 0 ] && [ "$b" -ne 0 ]
expect_pass $? "test_red_on_single_storekit_key_present (exit=$rc, fail-names-key=$a, no-storekit-pass-absent=$b)"
rm -rf "$TMPD3"

echo "verify-archive tests: $failures failure(s)"
exit "$failures"
