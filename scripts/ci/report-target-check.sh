#!/usr/bin/env bash
# Body of the "Build watchOS" and "Build Widget" required checks. They run no
# build: they pass only when both macOS jobs built the target and embedded it,
# Lint & Build (Release, device) and Test (Debug, simulator).
#
# Usage: scripts/ci/report-target-check.sh <label> <release outcome> <debug outcome> <upstream results>
# An empty outcome means the macOS job never reached its check; that is
# reported as "upstream-not-run" so scripts/ci-rerun-infra.sh can re-run it.
set -uo pipefail

LABEL=$1 RELEASE=$2 DEBUG=$3 UPSTREAM=$4

if [ "$RELEASE" = "success" ] && [ "$DEBUG" = "success" ]; then
  echo "The $LABEL built and was embedded in both Release (device, Lint & Build) and Debug (simulator, Test)."
  exit 0
fi
if [ "$RELEASE" = "failure" ] || [ "$DEBUG" = "failure" ]; then
  [ "$RELEASE" = "failure" ] && echo "::error::The $LABEL failed in Release (device): see Lint & Build, steps \"Build Release (Xcode 26.3)\" and \"Check the watch app and widget are embedded\"."
  [ "$DEBUG" = "failure" ] && echo "::error::The $LABEL failed in Debug (simulator): see Test, steps \"Build iOS, watchOS and widget\" and \"Check the watch app and widget are embedded\"."
  exit 1
fi
echo "::error title=upstream-not-run::A macOS job did not report the $LABEL build ($UPSTREAM)."
exit 1
