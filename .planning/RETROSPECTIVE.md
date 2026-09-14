# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — App Store Submission Remediation

**Shipped:** 2026-08-12 (`override_closeout` — see PROJECT.md's "v1.0 Verification Reality Check")
**Phases:** 6 | **Plans:** 11 | **Sessions:** multiple (spanning 2026-08-08 → 2026-08-12)

### What Was Built
- Widget App Group entitlement + Privacy Manifest fixed across all 3 targets; widget resolves fresh/stale/empty via a tested resolver
- Non-fatal SwiftData `ModelContainer` recovery — no crash on any prior store schema state
- Deletion consolidated onto a single `DataDeleterService`; Delete All now actually clears Keychain JWT + App Group cache; CloudKit health fields encrypted via `encryptedValues`
- AI Chat honestly gated off for v1 via a compile-time flag rather than a silently-dead entry point
- IAP purchase flow fixed for Release-config compilation; accessibility gaps addressed in Phase 5

### What Worked
- Re-review after fix (running the code reviewer again against the fixer's own changes) caught two genuine regressions/pre-existing bugs that a single review+fix pass would have missed entirely: a cancel-mid-delete split-brain bug (introduced by the first fix) and a pre-existing "CloudKit delete reports success on failure" swallow. Three rounds of review→fix→re-review on Phase 2 alone.
- Independently re-running `xcodebuild build-for-testing` after every fix pass (rather than trusting the fixer/reviewer subagent's self-reported build status) caught nothing wrong this time, but is cheap insurance against a subagent's own build claim being stale or scoped wrong.
- Surfacing pre-flight/audit-gate conflicts to the user explicitly (rather than silently proceeding or silently blocking) let the user make an informed, fast call each time gaps were found.

### What Was Inefficient
- Phase 2's code review depth was set to `standard` throughout, yet needed 3 full review→fix cycles to reach a stable state on data-integrity-critical code — a `deep` first pass (cross-file, import-graph aware) might have surfaced the CloudKit batch-delete swallow and the cancellation-ordering issue in one pass instead of three.
- Phases 3, 4, and 5 were executed but never ran `verify_phase_goal` — the milestone reached "all plans have SUMMARY.md" without ever confirming any of them actually achieved their stated phase goal. REQUIREMENTS.md's traceability table marked most of their requirements "Complete" purely from plan-level self-report, not independent verification — this is the single biggest gap in this milestone's actual rigor.
- This development host has a persistent, reproducible CoreSimulator device-pairing failure (`No matching device ... in XCTestDevices`) blocking every `xcodebuild test` attempt, across every phase's verification session this milestone (4+ independent occurrences). No workaround was found; every test-execution claim in this milestone rests on compile-only (`build-for-testing`) success, never an actual pass/fail signal. This should be fixed or worked around (different host, CI runner) before it silently erodes confidence in future milestones' test claims.

### Patterns Established
- Independently re-verify a subagent's "build succeeded" / "tests pass" claim with a real command before trusting it in a report to the user — this session found the subagents' self-reports were accurate every time, but the SourceKit "new diagnostics" noise that appeared after several edits looked alarming and would have been mistaken for real errors without an independent build.
- When a pre-close audit or verification gate surfaces `gaps_found`/`human_needed`/unchecked-requirements, present the specific evidence (not just the verdict) before asking the user to decide — options without the underlying evidence invite an uninformed "proceed anyway."

### Key Lessons
1. "All plans have a SUMMARY.md" is not the same as "phase goal verified" — a milestone can look 100% executed while being far short of verified. Run `verify_phase_goal` (or `/gsd-verify-work`) for every phase before treating a milestone as close-ready, not just before `/gsd-complete-milestone` itself.
2. On data-integrity-critical code, budget for multiple review→fix→re-review cycles up front rather than assuming one pass suffices — each re-review in this milestone found something new the prior fix introduced or missed.
3. A host-level test-execution blocker (simulator device-pairing failure) that recurs across multiple phases' verification sessions is itself a project risk worth escalating and fixing, not just re-documenting each time as a one-off environment note.

### Cost Observations
- Sessions: multiple, spanning ~4 days of wall-clock time (2026-08-08 init → 2026-08-12 close)
- Notable: Phase 2 alone consumed 3 full agent-spawned review/fix cycles plus repeated independent build verification in a single session before verification — a disproportionate share of this milestone's total agent-time relative to its 1-plan phase size, driven by the review depth gap noted above.

---

## Milestone: v1.1 — Backend API Migration

**Shipped:** 2026-08-24 (`verified_closeout`)
**Phases:** 3 | **Plans:** 17 | **Tasks:** 25 | 164 commits over 12 days (2026-08-12 → 2026-08-23)

### What Was Built
- Firebase Auth (Anonymous + Google linking with account preservation) + `StressAPIClient`; chat migrated to the backend SSE protocol; Supabase fully removed
- Credits monetization: consumable packs + premium tier, Apple-JWS-verified server-side with idempotent grants, free-first consumption, refund demotion; 402 → paywall gating; live money path human-validated on Release build vs deployed backend
- Server-backed chat sessions with cross-relaunch restore, preferences round-trip shaping the coach's system prompt, server-driven quick-action chips (metered taps)
- Factory reset now wipes server history (live-verified with a pre-reset token)

### What Worked
- Every phase closed with `passed` verification + human-validated UAT — the exact rigor v1.0's retrospective demanded. v1.0's "9/26 unchecked" debt was fully answered; v1.1 closed `verified_closeout` with a same-day milestone audit (21/21 requirements, 7/7 seams, 4/4 E2E flows).
- TDD discipline held throughout: every plan led with RED tests (URLProtocol-pinned seams, Swift Testing), and the money path is pinned by behavioral suites that were independently re-run at verification.
- Gap-closure loop worked: plan 01-04 shipped the Google UI the base plans descoped; CR-01..CR-05 + WR-10 all closed with regression pins inside the milestone rather than deferred.
- Security reviews (retroactive secure-phase for Phases 2-3) reconciled cleanly because every plan carried a `<threat_model>` block authored at plan time — 54 threats classified, threats_open 0.

### What Was Inefficient
- The stale debug session (`google-signin-ui-entry-missing`) sat "open" for 8 days after its fix (plan 01-04, 2026-08-16) shipped — audit-open only surfaced it at milestone close. Re-run audit-open after gap-closure lands, not just at close.
- VALIDATION.md files for all 3 phases were seeded by plan-phase but never reconciled by validate-phase (Nyquist coverage TODO) — verify-work's checks didn't notice either.
- The v1.0-carryover submission blockers (BUILD-01, SHIP-01..03, A11Y-01..05) sat untouched through v1.1 — correct scoping, but they now form the entire critical path to submission and deserve a decision-forcing milestone (D3/D4) immediately.
- Phase 2 needed 2 gap-closure cycles (CR-04 build-settings, CR-01..CR-03 backend arithmetic/entitlements) after its base 4 plans — the initial plan set underweighted Release-config/build-settings risk on the money path.

### Patterns Established
- `<threat_model>` blocks authored at plan time make retroactive security review a reconciliation exercise instead of a fresh audit — keep this.
- Server-authoritative state + display-only client caches as the default posture for anything money- or integrity-bearing (balance, entitlements, sessions).
- Grep gates as regression fences for prohibitions (POST /quick-actions unwired, Supabase remnants, sentinel absence) — cheap, verifier-rerunnable, and they pin decisions that tests can't express.

### Key Lessons
1. Human-verification items with external lead time (ASC filing, sandbox testers, deployed infra) must be authored as UAT scenarios up front — Phase 3's scenario script made the end-of-phase human pass a 30-minute checklist instead of an open-ended session.
2. Cross-referencing the audit tool's open-items list against PROJECT.md's Validated entries before acting on it caught a stale "open" item that would have been wrongly deferred to v1.2.
3. A same-day milestone audit at close (before complete-milestone) is cheap and catches both stale state and score regressions — make it standard.

### Cost Observations
- Sessions: multiple, spanning 2026-08-12 → 2026-08-23 (12 days wall-clock; execution concentrated in 4 working days)
- Notable: Phase 2 consumed 8 of 17 plans (2 gap-closure cycles) — money-path correctness dominated cost, as expected; Phase 3 closed in one pass with zero gap cycles.

---

## Milestone: v1.2 — Submission Readiness

**Shipped:** 2026-09-05 (`override_closeout`, user-directed — Phase 4 deferred)
**Phases:** 3 executed of 4 planned | **Plans:** 18 | **Tasks:** 46 | 313 files, +17,871/−14,401 over 3 days (2026-09-03 → 2026-09-05)

### What Was Built

- Binary & manifest truth: privacy manifest ASC-valid on a real upload (TestFlight build 14), one canonical App Group, plist single-sourcing (empirical inversion — the Info.plist FILE is the live source, custom INFOPLIST_KEY_* never merge), zero extractable credentials, SPM proxy migration committed, CI fastlane-match readonly green
- Widget made true: the dead write path (WidgetPublisher.publish had zero callers since bba996a) discovered by evidence and wired TDD-first
- Delete correctness & test-suite trust: lying-delete regression pin via the CloudKitResetServiceProtocol seam, WR-03/WR-04 money-path fixes, WINDOWS #8 root-caused as a fixture container-lifetime bug, one canonical CI-parity test invocation
- Accessibility: machine-checked WCAG contrast suite (resolved-UIColor ratios, both appearances), Dynamic Type ramp across app + widget + watch (82 ScaledMetric anchors), single-owner Reduce Motion helper with DEBUG seam, 84-file orphan deletion proven by three-scheme builds
- Phase 3 code review fully remediated across three passes plus a final SDD subagent loop for the IN-finding residuals (9 commits, every task spec+quality reviewed, whole-branch review clean)

### What Worked

- TDD pins for every contrast/wiring/boundary claim — regressions are machine-caught now, not review-caught
- The pre-close artifact audit forced honest disposition of 16 open items instead of silent loss at archive time
- Plan-vs-repo divergence (parallel GSD fix stream closed 8 of 12 findings under a stalled plan) resolved by explicit user ruling — supersession, not blind re-execution

### What Was Inefficient

- The final remediation plan was drafted against a repo state the parallel GSD stream then changed under it; one stalled dispatch (fork exhaustion) lost a staged diff and cost a full resumption audit
- Two resource-exhaustion incidents (process/fork limits; an Argent tool-server storm) each stalled execution for tens of minutes
- Function-level `-only-testing` selects 0 tests on this toolchain — vacuous-pass traps, caught both times only by implementers verifying per-case output

### Patterns Established

- Contrast truth computed from resolved UIColor values, never screenshots
- Verification gates tested red AND green (anti-vacuous harness)
- Motion decisions owned by one helper; consumers fed via onMotionDecision — now change-fed (mid-session Reduce Motion toggles propagate)

### Key Lessons

- A plan's verbatim code can be provably unable to fix its own finding (IN-05: appear-time-only notification feeding a per-tick gate) — review the mechanism, not just diff-to-spec
- Archived milestones resurface their open items at every later close; the CLI acknowledge writer can hit the wrong same-numbered active phase — verify the gap_snapshot you actually suppressed

### Cost Observations

- Model mix: GSD phases on the balanced profile; the SDD loop used low-tier implementers for transcription tasks, standard tier for judgment, reviewer tier for gates
- Notable: the 42-minute first SDD dispatch was dominated by simulator boot and process storms, not agent work


## Milestone: v1.3 — Design Parity

**Shipped:** 2026-09-13 (`verified_closeout`)
**Phases:** 1 | **Plans:** 3 | 41 files, +3,918/−112, 28 commits on `v1.3-design-parity` (2026-09-12 → 2026-09-13)

### What Was Built

- The three designed-but-unbuilt screens (History Timeline, Measurement Result, Biological Age) shipped standalone with production navigation end-to-end — reviving the dead `Route.measurement(id:)` destination and rerouting the Settings Biological Age row off `.about`
- 17 new unit tests across three Swift Testing suites; full CI-parity gate green at 311 tests / 53 suites
- Bonus fix: HealthKit date-of-birth protocol-extension dead default (explicit protocol requirement dispatch)

### What Worked

- Screen census (`/gsd-explore`) as the scope instrument — "28 implemented vs 27 designed" named exactly three screens to build and nothing more
- The verifier earned its keep: initial `gaps_found` on a time-of-day fixture instability that runs before 10:00 local had hidden; closed in the fixture with a re-run inside the failing window
- One plan per screen over shared research — three plans, zero cross-plan conflicts

### What Was Inefficient

- The milestone bypassed `/gsd-new-milestone`: no REQUIREMENTS.md, STATE.md frontmatter never flipped to v1.3 — surfacing at close as a 0-phase manager dashboard and a verification report the tooling couldn't read (bare filename, `gaps_found` frontmatter, stale covered-digest). Manual state repair at close cost more than the skipped ceremony
- New test suites were silently absent from the test target until the 294→306 test-count jump exposed the missing pbxproj registration

### Patterns Established

- Explicit pbxproj A/B refs for every new test suite — app-target auto-registration does not apply
- Fixtures derive "today" via `min(requested, Date())` — never a fixed clock time

### Key Lessons

- Skipping milestone bootstrap trades minutes of ceremony for an hour of state forensics at close — machine state (frontmatter, filenames, digests) is the contract
- Tooling reads a verification report's frontmatter, not its body; a body-only "passed" note is invisible to every gate

### Cost Observations

- Single execution session (2026-09-12/13); the ~12.5 GB simulator-platform install was the longest single wait

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | multiple | 6 | First milestone. Established: independent build re-verification after every fixer pass; re-review after fix as standard practice for data-integrity code. |
| v1.1 | multiple | 3 | Verification-first close: every phase passed verification + human UAT; milestone audit before close; `<threat_model>` at plan time; grep-gate regression fences. |
| v1.2 | multiple | 3 (of 4) | Machine-gated quality (contrast + Dynamic Type suites, grep fences); `override_closeout` with Phase 4 deferred; pre-close artifact audit acknowledging 13 open items |
| v1.3 | 1 | 1 | `verified_closeout` on a single-phase milestone; screen-census-driven scoping; state-forensics lesson from skipping `/gsd-new-milestone` |

### Cumulative Quality

| Milestone | Tests | Coverage | Zero-Dep Additions |
|-----------|-------|----------|-------------------|
| v1.0 | Never executed (host CoreSimulator blocker) — compile-verified only | Unknown | 0 |
| v1.1 | 215 iOS tests green (host, `-parallel-testing-enabled NO`); backend 29 tests/100 steps green | Unknown (Nyquist TODO) | 0 new third-party beyond required Firebase/GoogleSignIn SDKs |
| v1.2 | 296 tests (285 pass / 0 fail / 11 pre-existing skips) | Unknown | 0 |
| v1.3 | 311 tests / 53 suites green (CI-parity gate) | Unknown | 0 |

### Top Lessons (Verified Across Milestones)

1. "Plans complete" ≠ "phase verified" — always run the verification gate explicitly, don't infer it from execution completion.
