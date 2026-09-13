---
gsd_state_version: "1.0"
milestone: v1.3
milestone_name: Design Parity (executed — pending milestone close)
status: Awaiting next milestone
stopped_at: Completed 01-03-PLAN.md (phase 1 complete — 3/3, verification passed)
last_updated: "2026-09-13T09:20:48.911Z"
last_activity: 2026-09-13
last_activity_desc: Milestone v1.3 completed and archived
state_head: bbc1eed48d5134e5a71e772eb76edd98f1eeb809
progress:
  total_phases: 1
  completed_phases: 1
  total_plans: 3
  completed_plans: 3
  percent: 100
current_phase: 1
current_phase_name: Missing Designed Screens
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-05 at v1.2 close)

**Core value:** Every feature that ships in the binary must actually work end-to-end for a real user — not just compile.
**Current focus:** v1.3 closeout (milestone close + PR of `v1.3-design-parity` to main)

## Current Position

Phase: Milestone v1.3 complete
Plan: —
Status: Awaiting next milestone
Last activity: 2026-09-13 — Milestone v1.3 completed and archived

## Performance Metrics

**Velocity:**

- Total plans completed: 6 (v1.0 + v1.1, both closed)
- Average duration: ~22 min/plan (v1.1 sample)
- Total execution time: not tracked cumulatively

**By Phase (v1.2):**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 6 | - | - |
| 2 | 0 | - | - |
| 3 | 0 | - | - |
| 4 | 0 | - | - |

Per-plan history for v1.0/v1.1 archived under `.planning/milestones/v1.0-phases/` and `.planning/milestones/v1.1-phases/`.

**Recent Trend:**

- Last 5 plans (v1.1 Phase 3): 2448s, 14min, 14min, 22min, 28min
- Trend: Stable

*Updated after each plan completion*
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 1 P01 | 40 min | 3 tasks | 11 files |
| Phase 1 P2 | 8 min | 2 tasks | 4 files |
| Phase 01 P03 | 22 min | 2 tasks | 1 files |
| Phase 01 P04 | 58 min | 3 tasks | 3 files |
| Phase 1 P05 | 87 min | 2 tasks | 13 files |
| Phase 1 P06 | 17 min | 2 tasks | 5 files |
| Phase 02 P01 | 10 min | 2 tasks | 2 files |
| Phase 02 P02 | 9 min | 2 tasks | 2 files |
| Phase 02 P03 | 6 min | 2 tasks | 4 files |
| Phase 02 P04 | 40min | 3 tasks | 7 files |
| Phase 02 P05 | 25min | 2 tasks | 2 files |
| Phase 02 P06 | 40min | 3 tasks | 5 files |
| Phase 3 P01 | 32 min | 3 tasks | 8 files |
| Phase 03 P02 | 34 min | 4 tasks | 41 files |
| Phase 03 P03 | 20 min | 3 tasks | 23 files |
| Phase 03 P04 | 10 min | 2 tasks | 8 files |
| Phase 03 P05 | 31 min | 3 tasks | 18 files |
| Phase 03 P06 | 28 min | 3 tasks | 86 files |

## Accumulated Context

### Decisions

Full log in PROJECT.md Key Decisions. v1.1 per-phase decisions archived with their phase artifacts. Carried forward because they constrain v1.2 work:

- [v1.1 P01, 2026-08-16]: `xcodebuild test` works only with `-parallel-testing-enabled NO` (parallel clones fail: XCTestDevices/Mach -308) — BUILD-04 codifies this in CI + dev docs
- [v1.1 P02, DEC-1/DEC-2]: monetization = server-authoritative credits + consumable packs + premium tier; this is the payload/entitlement shape SHIP-03's privacy answers and ENV-03's WR-03/WR-04 advisories describe
- [v1.1 P03]: chat payload carries derived stress scores (not raw HealthKit) under a Bearer-authenticated session — the factual basis D3 must be decided against
- [v1.1 P03-04]: in-memory `ModelContainer` must outlive its `mainContext` in tests; return-context-only fixtures are the WINDOWS.md #8 crash lineage (ENV-01 input)
- [v1.1 P03-05, ledger #12]: `RequestCaptureURLProtocol` statics leak across suites (order-dependent pollution) — relevant when ENV-01/ENV-02 make suite ordering deterministic
- [v1.2 roadmap, 2026-09-03]: phase numbering restarts at 1 for this milestone (project convention, matching v1.0 and v1.1)
- [Phase 1]: Proxy shim products MUST use _proxied-style names distinct from upstream (Xcode PIF registers both shim and upstream products — Firebase collided exactly like GoogleSignIn; A4 remedy applied in 1afb401)
- [Phase 1]: spm-cache/ package sources stay uncommitted by repo gitignore convention ('regenerated locally'); tracked migration artifacts = pbxproj + Package.resolved; ENV-04 bar = archive-from-working-tree (proven 01-01)
- [Phase 1]: Phase 1 P02: Watch UserDefaults reason set = CA92.1 + 1C8F.1, scan-verified at execution time (4 .standard files + 3 suite files; zero delta vs research §5.3) — scan-then-declare is the standing pattern for required-reason declarations
- [Phase 1]: Phase 1 P02 (D3 applied): CLAUDE.md + EN/VI privacy policies corrected to the real contract (StressLLMService/StressAPIClient → https://stress-api.dropitx.site chat endpoint, Firebase Auth anonymous-or-Google) with zero Swift churn — docs move toward code, never the reverse
- [Phase 1]: Phase 1 P03: Xcode merges only the documented closed set of INFOPLIST_KEY_* settings — custom INFOPLIST_KEY_STOREKIT_* never contributed to any merged plist; the app Info.plist file was the sole live source, so BUILD-03 landed inverted: file kept, 12 dead build settings deleted (388efe5)
- [Phase 1]: Phase 1 P03: widget Info.plist retained as one-key NSExtension file — delete branch disproven empirically (fresh .appex product lacks NSExtensionPointIdentifier without the file; auto-injection does not happen)
- [Phase 1]: Phase 1 P03: Giphy dSYM stub script phase removed (definition + reference + section markers, 4098d8b); zero live Giphy/Kingfisher/exyte/MediaPicker references remain — unused-media removal fully landed
- [Phase 01]: BUILD-02/AUTH-01 evidence-complete (plan 01-04): one suite group.stress.ai.com proven across entitlements+constants+tests+golden codesign dump; phase-final archive passes the credential gate with every strings hit dispositioned benign
- [Phase 01]: WIRE-01 RESOLVED per D4 — wire branch taken (plan 01-06): guarded save inside StressViewModel.loadCurrentStress (one StressMeasurement per new underlying HRV reading → repository.save → WidgetPublisher.publish → reloadAllTimelines) gives the widget its first live write path; every live foreground refresh now publishes the six latest_* keys. RED→GREEN proof in WidgetPublisherKeyMatchingTests (3 new tests, suite 5/5; full regression 217/217); simulator same-value evidence in 01-WIRE-01-EVIDENCE.md §8 (supersedes the 01-04 §2 empty-state pair). Physical-device confirmation remains the end-of-phase human item (§6).
- [Phase 1]: Phase 1 P05: deploy.yml dispatched only after explicit user approval recorded in 01-ENV-05-CI-RECORD.md before the dispatch timestamp — the standing gate for any TestFlight-visible action
- [Phase 1]: Phase 1 P05: ENV-05 GREEN — CI match(readonly) installs all three App Store profiles + K2TYLYAWMK Distribution cert with zero regeneration; readonly reads the match repo, never the portal dual-cert profiles, so the setup_match fallback stays unused and the path is idempotently repeatable
- [Phase 1]: Phase 1 P05: BUILD-01 SC-1 GREEN — TestFlight build 1.0.0 (14) from phase-final tree cleared ASC processing (state=VALID), no ITMS-91053 and no missing-SDK-manifest error; plan 02 manifest scan missed nothing
- [Phase 2]: [Phase 2 P01, DATA-04]: Ungated truthiness suite lands as a NEW sibling file (DataDeleterCloudKitTruthinessTests.swift), not inside the GSD_CI-gated DataDeletionConsolidationTests.swift — CI must see the CR-01 regression; registered in pbxproj (A026/B026)
- [Phase 2]: [Phase 2 P01]: One SeededCloudKitResetService double (.lying/.throwing/.draining) with exact-Int remainingRecords covers all three prongs — constructor-injected only, no statics (WINDOWS #12); emptiness asserted only by querying the store, never by the success return
- [Phase 2]: [Phase 2 P01]: Mutation run is the TDD red gate for regression suites guarding already-fixed bugs — suite green on HEAD, red under reintroduced CR-01 swallow (exit 65, prong-1 double detection: no-throw + local split-brain), green after revert (exit 0)
- [Phase 02]: [Phase 2 P02, WR-04]: Unverified transactions never finished — .unverified branch extracted to internal protocol-typed handleUnverifiedTransaction(_:) (VerificationResult<Transaction> is not test-constructible), finish deleted, redelivery-as-retry pinned red-first (finishCallCount == 0 single + redelivered)
- [Phase 02]: [Phase 2 P02]: The four completePurchase finish sites are verified-only by construction (checkVerified throws on .unverified before reach; handle(transaction:) entered only from .verified) — reachability note delivered, sites byte-unchanged; no runtime checks added inside the grant choke point
- [Phase 02]: [Phase 2 P03, WR-03]: DEBUG defaults to the real StoreKit service at BOTH wiring sites (app factory + StoreKitServiceKey.defaultValue) behind one shared MockIAPMode condition — mock resolves only via the -mock-iap launch arg (DemoMode shape, injectable arguments); pinned by StoreKitServiceWiringTests (RED 2 absent-flag failures, GREEN 16/16 with CreditPurchaseFlowTests); Release #else branches byte-unchanged
- [Phase 02]: [Phase 2 P03]: Minimal testability seam for a private factory — widen makeStoreKitService to internal static + an arguments parameter instead of extracting a resolver type; the pin asserts through the real factory, never by constructing services directly (Pitfall 4)
- [Phase 02]: [Phase 2 P04, ENV-01/ENV-02] WINDOWS #8 root cause found: fixture container-lifetime bug (return-context-only fixtures let the owning ModelContainer deallocate before the next SwiftData op), not a CI-host defect — fixed by converting to (ModelContainer, ModelContext) tuple fixtures; both #8-gated suites and CharacterEntitlementSyncTests permanently restored to the default run, GSD_CI/TEST_RUNNER_GSD_CI plumbing removed
- [Phase 02]: [Phase 2 P04] StoreKitServiceTests/EntitlementForegroundCorrectionTests productNotFound reproduces on TWO local simulators (not CI-runner-specific) — StoreKitTest daemon/session-isolation bug independent of IAP-01 product-ID registration (StoreKitProductCatalogLiveTests confirmed enabled+green, WINDOWS #7 closed); both suites stay dated-dispositioned (WINDOWS #6 open unchanged, #18 new entry), not re-enabled
- [Phase 2]: [Phase 02] [Phase 2 P05, BUILD-04] AGENTS.md is now the canonical CI-parity xcodebuild test invocation (flag-for-flag mirror of _test.yml's Run Tests step); docs/TESTING.md reduced to a pointer-only cross-reference (locked replace-not-extend decision) — zero divergence risk between what CI runs and what dev docs tell a human to run
- [Phase 2]: [Phase 02] [Phase 2 P05] INFOPLIST_KEY_* doc-truth note added to AGENTS.md folding in the Phase-1 UIBackgroundModes finding: custom INFOPLIST_KEY_* settings never merge into product plists on this toolchain — the Info.plist file is the source of truth
- [Phase 2]: [Phase 2 P06, DATA-01] performFactoryReset now deletes Habit (planner FIX decision, mirrors CharacterUnlock precedent) — closes the store-sweep completeness gap; TDD red-first pin in FactoryResetSweepCompletenessTests; deleteAllMeasurements stays byte-unchanged
- [Phase 2]: [Phase 2 P06] Assumption-delta: no-change (2026-09-03, orchestrator-resolved) — CloudKit's account-scoped CKRecord identity already generalizes to the second DATA-01 surface (console or second iPhone); no new identity axis
- [Phase 2]: [Phase 2 P06] DATA-01 stays Pending in REQUIREMENTS.md — only the automatable portion (sweep fix, evidence-note apparatus, trust gate) is done; the live two-surface verification is the explicit outstanding end-of-phase human item (no physical hardware/CloudKit Console reachable from this session; simulator evidence rejected per Pitfall 7)
- [Phase 3]: [Phase 3 P01, A11Y-02]: Contrast truth is machine-checked — ContrastComplianceTests (14 tests/36 cases) computes WCAG ratios from Theme tokens via UIColor.resolvedColor(with:) in both appearances; RED 4.242/4.318 at the old secondary hex, mutation red-proof, green at 6B6E7B
- [Phase 3]: [Phase 3 P01]: settingsRippleBlue/accentTeal = fixed 0891B2 (fill-safe both appearances) — accentTeal is a live white-text fill (AIChatCard/SelfNoteCard/WeekCalendarStrip) and white-on-4FC3F7 is 2.00:1, so the plan's recommended dark 4FC3F7 was overridden by the binding-judge clause; textTertiary/textDescriptive are now computed aliases of adaptiveSecondaryText; StressCategory.color pinned as the stress-hue source via Color.stressColor(for:)
- [Phase 03]: [Phase 3 P02, A11Y-04]: Dynamic Type anchor mechanism = per-view @ScaledMetric unit metrics (size: N * scale), because Font.system(size:weight:design:relativeTo:) does not exist in the iOS 26 SDK (SwiftUICore swiftinterface verified) — ramp is multiplicative so point sizes stay byte-identical at Large
- [Phase 03]: [Phase 3 P02]: accessibleDynamicType() reworked to a no-argument no-cap/no-shrink wrap contract; scalableText/AdaptiveTextSizeModifier/accessibleWellnessType* deleted zero-adopter; limitedDynamicType kept as the dated-exception escape hatch; D-03 manifest 14/14 adopted
- [Phase 03]: [Phase 3 P02]: WellnessType tokens ride the system text-style ramp (title/title2/body/headline/footnote/caption2) byte-identical at Large, pinned permanently by FontWellnessTypeParityTests (A029/B029) — A1 ramp assumption is now machine-checked; heroNumber/largeMetric stay fixed gauge class
- [Phase 03]: [Phase 3 P02, D-02]: widget+watch sweep = 82 ScaledMetric anchors + 58 inline dated exceptions (9 classes: accessory templates 26, lock-screen slots 5, LA system slots 6, LA banner SDK-gap 2, watch fixed hero 3, ring geometry 4, icon wells 2, chart geometry 3, N-across labels 4, breathing-ring 3); 1 shrink deleted, 8 kept behind markers
- [Phase 03]: Touch-target adoption wraps buttons from the outside (after buttonStyle) so visual glyphs stay small while contentShape covers 44pt; stressDualCoding gains showsCaption:false for name-bearing category sites — bare adoption duplicated the visible name
- [Phase 03]: D-09 value copy is 'Evolution stage n of 3' per EvolutionStage code truth (3 cases; in-app banner agrees) — UI-SPEC's 'of 5' contradicts the enum; StressHeroCard left readableTextColor #B8860B for category.color #8A5A00 (passes 4.5:1 at body size), making readableTextColor zero-adopter (03-06 deletion candidate)
- [Phase 3]: [Phase 3 P05, A11Y-03]: Motion optionality lives in one helper — Animation+Wellness.swift owns every accessibilityReduceMotion read (gate grep zero by construction); views needing the boolean capture it via onMotionDecision instead of reading the env
- [Phase 3]: [Phase 3 P05, D-11]: Breathing fallback = mode not stub — session defaults to HapticManager phase pulses + 'Inhale — 3' countdown under Reduce Motion via pure resolvedAnimationEnabled(motionReduced:userChoice:); 'Breathing animation' switch is in-session opt-in, nothing persists; scripted via the -a11y-reduce-motion DEBUG seam (simctl has no RM toggle on Xcode 26.3)
- [Phase 3]: [Phase 3 P05, D-11]: Breathing fallback = mode not stub — session defaults to HapticManager phase pulses + 'Inhale — 3' countdown under Reduce Motion via pure resolvedAnimationEnabled(motionReduced:userChoice:); 'Breathing animation' switch is in-session opt-in, nothing persists; scripted via the -a11y-reduce-motion DEBUG seam (simctl has no RM toggle on Xcode 26.3)
- [Phase 3]: [Phase 3 P05, D-13]: Re-baseline drift confirmed — research 66/13 and UI-SPEC 65/13 were stale; execution-time truth was 18 ref lines/13 files (17 env reads + 1 doc comment); gate must always enumerate by file+construct, never by count; 4 additional unguarded repeatForever loops found outside the plan set (deferred-items.md, several are 03-06 orphan candidates)
- [Phase 03]: 03-06 D-14 executed: approve-full-set deleted 84 orphan files + 2 zero-adopter members from disk behind the blocking decision — delete-compile (3-scheme clean builds + 280-test suite) is ground truth; the compiler now enforces the audit
- [Phase 03]: Relocation-first pattern institutionalized: live extension members inside orphan files (StressCategory.displayName/init(from:) in Badge.swift) move to the type home and build green BEFORE the file dies; audit record is amended on any break, never build settings

### Pending Todos

None yet.

### Blockers/Concerns

- ~~**D3 (Privacy contract authority)**~~ **RESOLVED (v1.2 P1)**: code is the contract — docs moved toward StressContextPayload, zero payload churn; gates BUILD-01 (validated) and SHIP-03 (Phase 4, unblocked).
- ~~**D4 (Widget in v1)**~~ **RESOLVED (v1.2 P1)**: keep the widget and make it true — write path wired (01-06), device-verified; WIRE-01 validated.
- D2 (CloudKit encryption) resolved in practice (encryptedValues shipped v1.0 Phase 2) but never recorded as a formal decision — close opportunistically.
- v1.1 Phase 2 advisory residue: WR-03 (DEBUG money path uses `MockStoreKitService`) and WR-04 (`.unverified` consumables finished) — ENV-03 (Phase 2).
- [Phase 2 input] `INFOPLIST_KEY_UIBackgroundModes` never merges into product plists (absent from build-13 too — pre-existing) — folds into BUILD-04 doc-truth work.
- [Phase 1 code review] 7 Info findings carried as documented debt (01-REVIEW.md): scan-pattern gaps (AKIA/ghp_/xox-), allowlist masking removed supabase literals, stale STOREKIT comment, widget-README/CLAUDE.md staleness, pbxproj churn, transitive-pin drift (GoogleUtilities 8.1.2→8.1.3).
- [Release] TestFlight 1.0.0 build 13 is BETA_APPROVED; build 14 (v1.2 P1, VALID) predates the WIRE-01 fix — its widget shows "No Data"; the next build carries the wiring. Build 12 shipped with no entitlements blob — dump entitlements per bundle before every publish (Phase 4).
- Pending from v1.1: Phase 03 drift re-test (5 UAT scenarios, `.planning/milestones/v1.1-phases/03-sessions-preferences-quick-actions-cleanup.1/03-UAT.md`) — candidate target now build 15+ (post-wiring) — not a v1.2 requirement, but the last open v1.1 item.
- StoreKitServiceTests + EntitlementForegroundCorrectionTests remain disabled (StoreKitTest session-isolation/productNotFound bug, dated disposition 2026-09-04 in file headers, WINDOWS #6/#18) — needs a working local CoreSimulator/XCTestDevices layer to diagnose the StoreKitTest daemon interaction further
- [Motion-family follow-up, v1.2 close] ChatBottomSheetView:541 decorative repeatForever unguarded under Reduce Motion; fidget timer does not restart when RM is disabled mid-session after being on at appear — motionReduced state is wired in CharacterAnimationModifier, both are ~two-line fixes

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|

## Deferred Items

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| uat_gaps | 02/02-UAT.md | testing (1 scenario) | 2026-09-05 | v1.2 |
| uat_gaps | 03/03-A11Y-UAT.md | unknown (walkthrough pending) | 2026-09-05 | v1.2 |
| uat_gaps | 03/03-UAT.md @ v1.1-phases (drift re-test) | testing (5 scenarios) | 2026-09-05 | v1.2 |
| uat_gaps | 01.1/01.1-UAT.md @ v1.0-phases | passed (0 pending) | 2026-09-05 | v1.2 |
| uat_gaps | 02/02-UAT.md @ v1.0-phases | testing (3 scenarios) | 2026-09-05 | v1.2 |
| verification_gaps | 02/02-VERIFICATION.md | human_needed | 2026-09-05 | v1.2 |
| verification_gaps | 03/03-VERIFICATION.md | human_needed | 2026-09-05 | v1.2 |
| verification_gaps | 01/01-VERIFICATION.md @ v1.0-phases | gaps_found | 2026-09-05 | v1.2 |
| verification_gaps | 02/02-VERIFICATION.md @ v1.0-phases | human_needed | 2026-09-05 | v1.2 |
| quick_tasks | 260902-wso-repo-hygiene-gitignore-agent-harness-dir | missing | 2026-09-05 | v1.2 |
| deferred_items | 01/deferred-items.md: INFOPLIST_KEY_UIBackgroundModes never merges into product plists | acknowledged | 2026-09-05 | v1.2 |
| deferred_items | 03/deferred-items.md @ v1.0-phases: MockStoreKitService Release-build blocker | acknowledged | 2026-09-05 | v1.2 |
| deferred_items | 03/deferred-items.md: ChatBottomSheetView decorative repeatForever | acknowledged | 2026-09-05 | v1.2 |
| deferred_items | 03/deferred-items.md: LoadingView/BioAgeCardView/SmartInsightsTeaser repeatForever loops | resolved (files deleted by redesign) | 2026-09-05 | v1.2 |

Earlier v1.0 deferrals (Phase 01/02 verification gaps, `MockStoreKitService` Release blocker) are all closed — see PROJECT.md Validated.

## Deferred Verification

| Phase | State | Resume |
|-------|-------|--------|
| 1 | ~~verification_deferred_human~~ **RESOLVED 2026-09-03** — /gsd-verify-work 1 passed 19/19 (both human items validated); phase marked complete | — |
| 2 | verification_deferred_human (deferred 2026-09-04) — DATA-01 live two-surface CloudKit delete test (physical iPhone + CloudKit Console). Automated 5/6 requirements verified (02-VERIFICATION.md), full suite green 0 failed, UAT 0/1 pending (`02-UAT.md`), evidence apparatus execution-ready (`02-DATA-01-EVIDENCE.md`, redaction rule in §3 step 7) | `/gsd-verify-work 2` |

| 3 | verification_deferred_human (deferred 2026-09-05 at milestone close) — machine gates green (contrast suite 28/28, all four a11y grep gates, code review clean after 3 passes + residual remediation); human A11Y walkthrough (03-A11Y-UAT.md, 14 surfaces) outstanding | `/gsd-verify-work 3` (walkthrough apparatus ready) |

## Session Continuity

Last session: 2026-09-13T08:58:24Z
Stopped at: v1.3 Phase 1 verified (3/3 plans); milestone closeout pending
Resume file: None

## Operator Next Steps

- Start the next milestone with /gsd-new-milestone

## 2026-09-13 — v1.3 Phase 1: Missing Designed Screens

- Status: **complete**, verification **passed** (VERIFICATION.md; 311 tests / 53 suites green, CI-parity build green).
- Branch `v1.3-design-parity` (15 implementation commits + docs). All commits authored Phuong Doan, no AI attribution.
- Screens delivered: History Timeline (+ live `Route.measurement` entry), Measurement Result, Biological Age (+ Settings reroute). Bonus fix: HealthKit DOB protocol-extension dead-default bug.
- Process discoveries: test target requires explicit pbxproj registration (app target auto-registers); `-only-testing` matches 0 Swift Testing suites on Xcode 26.6 — run full target; simulator platforms iOS/watchOS 26.5 installed locally.
- Pending: milestone close (audit/complete/cleanup) + PR to main.
