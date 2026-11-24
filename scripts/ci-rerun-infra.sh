#!/usr/bin/env bash
# Re-runs the failed jobs of a CI run when, and only when, GitHub could not give
# a job a runner ("The job was not acquired by Runner of type hosted even after
# multiple attempts"). Genuine build or test failures are never re-run.
#
# Called by .github/workflows/ci-rerun-infra.yml (workflow_run of CI).
# Usage: scripts/ci-rerun-infra.sh <run-id> <run-attempt>
# Env:   GH_REPO (owner/name), GH_TOKEN, DRY_RUN=1 to only print the decision,
#        MAX_ATTEMPT (default 3: the first run plus at most 2 re-runs).
#
# A job counts as "not run" (re-runnable) only when its annotations say
# "not acquired by Runner". Two kinds of failed/cancelled jobs are neutral:
#   - a result shim (_test.yml) that reported "upstream-not-run" because the
#     macOS job it mirrors never ran, and
#   - a job cancelled by concurrency ("higher priority waiting request").
# Every other failed or cancelled job blocks the re-run: a real build or test
# failure, or a run cancelled by hand. A job cancelled by hand while still
# queued has no runner_name and no annotation, so a missing runner alone never
# makes a job re-runnable.
set -euo pipefail

run_id=${1:?run id}
attempt=${2:?run attempt}
max_attempt=${MAX_ATTEMPT:-3}

say() { echo "$*"; [ -n "${GITHUB_STEP_SUMMARY:-}" ] && echo "$*" >>"$GITHUB_STEP_SUMMARY" || true; }

if [ "$attempt" -ge "$max_attempt" ]; then
  say "Run $run_id is on attempt $attempt (limit $max_attempt): not re-running."
  exit 0
fi

run=$(gh api "repos/$GH_REPO/actions/runs/$run_id")
branch=$(jq -r .head_branch <<<"$run")
workflow_id=$(jq -r .workflow_id <<<"$run")
event=$(jq -r .event <<<"$run")

# A newer run on the same branch supersedes this one (a later push): leave it.
latest=$(gh api "repos/$GH_REPO/actions/workflows/$workflow_id/runs?branch=$(jq -rn --arg b "$branch" '$b|@uri')&event=$event&per_page=1" --jq '.workflow_runs[0].id')
if [ "$latest" != "$run_id" ]; then
  say "Run $run_id is superseded by run $latest on $branch: not re-running."
  exit 0
fi

jobs=$(gh api "repos/$GH_REPO/actions/runs/$run_id/attempts/$attempt/jobs?per_page=100" --jq '.jobs')

not_run=0
genuine=0
while IFS=$'\t' read -r id name conclusion runner; do
  case "$conclusion" in failure|cancelled|timed_out) ;; *) continue ;; esac
  notes=$(gh api "repos/$GH_REPO/check-runs/$id/annotations" --jq '[.[] | "\(.title // "")|\(.message)"] | join("\n")')
  if grep -q "not acquired by Runner" <<<"$notes"; then
    say "- $name: no runner acquired"; not_run=$((not_run + 1))
  elif grep -q "^upstream-not-run|" <<<"$notes"; then
    say "- $name: mirrors a job that never ran"
  elif [ "$conclusion" = "cancelled" ] && grep -q "higher priority waiting request" <<<"$notes"; then
    say "- $name: cancelled by concurrency"
  elif [ -z "$runner" ]; then
    say "- $name: $conclusion before getting a runner, without a runner-acquire note (cancelled by hand?)"; genuine=$((genuine + 1))
  else
    say "- $name: ran and ended $conclusion"; genuine=$((genuine + 1))
  fi
done < <(jq -r '.[] | [.id, .name, (.conclusion // ""), (.runner_name // "")] | @tsv' <<<"$jobs")

if [ "$genuine" -gt 0 ]; then
  say "Run $run_id has $genuine job(s) that failed or were cancelled on purpose: not re-running."
  exit 0
fi
if [ "$not_run" -eq 0 ]; then
  say "Run $run_id has no runner-acquire failure: not re-running."
  exit 0
fi

say "Run $run_id (attempt $attempt): $not_run job(s) never got a runner. Re-running failed jobs."
if [ "${DRY_RUN:-0}" = "1" ]; then
  echo "DRY_RUN: gh run rerun $run_id --failed"
else
  gh run rerun "$run_id" --failed --repo "$GH_REPO"
fi
