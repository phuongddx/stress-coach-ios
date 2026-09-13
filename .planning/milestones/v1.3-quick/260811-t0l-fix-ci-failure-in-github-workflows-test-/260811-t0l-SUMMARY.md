---
task: 260811-t0l
subsystem: ci
tags: [github-actions, ci, simulator, workflows]
dependency-graph:
  requires: []
  provides: [dynamic-simulator-resolution-in-test-job]
  affects: [.github/workflows/_test.yml]
tech-stack:
  added: []
  patterns: [runtime-resolved-simulator-udid, loud-failure-with-full-dump]
key-files:
  created: []
  modified:
    - .github/workflows/_test.yml
decisions:
  - "Resolve iPhone Simulator UDID at runtime via `xcrun simctl list devices available` instead of hardcoding `name=iPhone 16,OS=latest`, since that device name doesn't exist on the current macos-15-arm64/Xcode 26.3 runner image."
metrics:
  duration: "2m"
  completed: 2026-08-11
actuals:
  tokens: 1200
  tasks: 1
  commits: 1
status: complete
---

# Quick Task 260811-t0l: Fix CI failure in `_test.yml` test job Summary

Replaced the hardcoded `-destination 'platform=iOS Simulator,name=iPhone 16,OS=latest'` in the `test` job's "Run Tests" step with a dynamically resolved simulator UDID, fixing the "device not found" CI failure (GitHub Actions run 31493553791, job 93785581970).

## What Changed

Added a new step, "Resolve available iPhone Simulator" (`id: simulator`), immediately before "Run Tests" in the `test` job of `.github/workflows/_test.yml`:

- Runs `xcrun simctl list devices available`, greps for the first line containing `iPhone`.
- If no match: prints an error, dumps the full device list to stderr, and exits 1 (loud failure, mirroring the existing `-showdestinations`-check-then-act pattern already used in `build-watchos`/`build-widget`).
- Extracts the UDID from the matched line via `grep -oE` with the standard UUID pattern and writes it to `$GITHUB_OUTPUT` as `udid=<value>`.
- If UDID extraction fails (empty result), also errors and exits 1 rather than proceeding with an empty destination.
- Uses `set -o pipefail`, matching every other multi-command step in the file.

The "Run Tests" step's `xcodebuild test -destination` argument now reads `"platform=iOS Simulator,id=${{ steps.simulator.outputs.udid }}"` instead of the hardcoded device name. No other flag on that command changed.

## Deviations from Plan

None - plan executed exactly as written.

## Verification

- `git diff .github/workflows/_test.yml` confirms changes are scoped entirely to the `test` job (one new step + one modified `-destination` line).
- YAML re-parses cleanly; automated verify script from the plan passed (`OK`).
- `lint-and-build`, `build-watchos`, `build-widget` jobs are untouched (confirmed via diff — no hunks outside the `test` job).

## Self-Check: PASSED

- FOUND: `.github/workflows/_test.yml` contains the "Resolve available iPhone Simulator" step and the updated `-destination` line.
- FOUND: commit `7864b95` exists in git log.
