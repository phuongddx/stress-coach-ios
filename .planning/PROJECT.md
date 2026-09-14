# StressMonitor — App Store Submission Remediation

## What This Is

StressMonitor is an iOS/watchOS app that scores stress 0–100 from HealthKit biometrics (HRV, heart rate, sleep, activity, recovery) via a five-factor algorithm, paired with an AI coaching chat, CloudKit sync, a gamified character system, and a credits-based monetization system (consumable credit packs + premium tier, server-verified against Apple JWS).

As of v1.1 close (2026-08-23) the app runs end-to-end against its own deployed backend (`stress-api.dropitx.site`): Firebase Auth (anonymous + Google linking with account preservation), credit-metered chat streaming with server-side session history, preferences that shape the coach's system prompt, Apple-verified purchases with idempotent grants and refund demotion, and a factory reset that wipes server history. The money path and all 4 E2E flows are live-verified against deployed infrastructure.

As of v1.2 close (2026-09-05, `override_closeout`, Phase 4 deferred): the remediation halves are done — binary/manifest truth (privacy manifest ASC-valid on build 14, one App Group, plist single-source, no extractable credentials), the widget's write path wired and device-verified, delete-correctness machinery with a mutation-proven regression pin, a trustworthy CI-parity test suite, and accessibility machine-gated and review-clean (contrast suite, Dynamic Type ramp, single-owner Reduce Motion, 84 orphan files deleted). What remains between the binary and App Review is deliberately small: the Phase-4 submission package (SHIP-01..03, never started), two human verification gates (DATA-01 live two-device CloudKit delete; Phase-3 A11Y walkthrough via `/gsd-verify-work 3`), and the v1.1 drift re-test against a post-wiring TestFlight build.

As of v1.3 close (2026-09-13, `verified_closeout`): design parity — every surface from the 27-screen design prototype now ships standalone. The three designed-but-unbuilt screens (History Timeline, Measurement Result, Biological Age) landed with production navigation end-to-end, reviving the previously-dead `Route.measurement(id:)` destination and rerouting the Settings Biological Age row off `.about`. Full CI-parity gate green at 311 tests / 53 suites; version 1.0.1 (26) on branch `v1.3-design-parity`, PR to `main` pending at close.

## Core Value

Every feature that ships in the binary must actually work end-to-end for a real user — not just compile. Chat must authenticate and respond, a purchase must actually complete, "delete all data" must actually delete, and the Privacy Manifest must pass Apple's automated validation. Feature-complete-on-paper is not the bar; submittable is.

## Business Context

- **Customer**: Individual consumers tracking personal stress/wellness via HRV.
- **Revenue model**: credits-based — server-authoritative credit balance (50 free/month, free-first consumption) spent by chat messages; consumable credit packs (`credits.small` $1.99/10, `credits.large` $19.99/150) redeem server-side against Apple-verified JWS; premium tier (subscription, `premium_until` expiry gating) = unlimited chat. Superseded the original weekly/monthly/annual subscription-only model in v1.1 Phase 2 (DEC-1/DEC-2); live money path human-verified 2026-08-23 against the deployed backend.
- **Success metric**: A release archive uploads to App Store Connect without manifest validation failure; a real purchase/restore/cancel/expiry cycle verifies against a local `.storekit` file; Chat reflects real auth state instead of a dead, expired credential.
- **Strategy notes**: `plans/0808-2042-appstore-submission-remediation/plan.md` (the authoritative scope for this milestone), `plans/reports/appstore-audit-0808-*.md` (6 source audits), `.planning/codebase/{ARCHITECTURE,STACK,TESTING,CONCERNS}.md` (codebase map, corroborates several findings), `docs/project-roadmap.md`, `docs/KANBAN-SHIP-READINESS.md` (both partially stale relative to the fresher audit).

## Next Milestone (candidate scope, from v1.2 close carryover)

**Goal:** The submission tail — finish what stands between the current binary and App Review.

- SHIP-01: App Store screenshot set captured from a real-data build (demo mode disabled)
- SHIP-02: Fastlane `release` lane that does exactly the metadata-only upload the first submission needs
- SHIP-03: ASC privacy questionnaire answered field-for-field per the D3 contract (code-is-the-contract, resolved v1.2 P1)
- Human gates: DATA-01 two-device CloudKit delete (`/gsd-verify-work 2`); Phase-3 A11Y walkthrough (`/gsd-verify-work 3`); v1.1 drift re-test vs build 15+
- Quick-task candidates: motion-family micro-fixes (ChatBottomSheetView loop guard; fidget resume on Reduce Motion disable — state already wired)

## Requirements

### Validated

<!-- Shipped AND independently verified by a gsd-verifier pass this milestone — not just self-reported "Complete" in REQUIREMENTS.md's traceability table. See "v1.0 Verification Reality Check" in Context below for why this list is deliberately shorter than REQUIREMENTS.md's Complete count. -->

- ✓ Multi-factor stress scoring algorithm (HRV · HR · Sleep · Activity · Recovery, weight redistribution) — existing, not flagged by any audit
- ✓ HealthKit integration, read-only, 7 data types — existing
- ✓ Networking layer — HTTPS-only, no ATS exceptions, correct Keychain accessibility, async/await `URLSession` — explicitly called out as solid
- ✓ StoreKit verification logic itself (`checkVerified` throws on `.unverified`, `.finish()` called on both paths) — existing, sound
- ✓ Apple Watch companion app with WidgetKit complications — existing
- ✓ Character collection gamification (5 creatures, evolution) — existing
- ✓ Breathing exercises and Mini Walk wellness tools — existing
- ✓ Haptic feedback — wired once, at the correct call site
- ✓ Non-fatal SwiftData `ModelContainer` recovery across any prior store schema state — v1.0 Phase 1.1, verification `passed`
- ✓ DATA-02: Export protection (size cap, `.completeFileProtection`, on-dismiss cleanup) — v1.0 Phase 2, independently verified in code + tests
- ✓ DATA-03: CloudKit field encryption via `encryptedValues` for hrv/restingHeartRate/stressLevel — v1.0 Phase 2, independently verified in code + tests
- ✓ WIRE-02: Single canonical data-management implementation (`DataDeleterService`); duplicate `DataExporter`/`ExportModels` stack deleted — v1.0 Phase 2, independently verified
- ✓ v1.1 D-01/D-02: Firebase Auth — Anonymous sign-in at launch + Google Sign-In with anonymous-account linking (uid/credits/history preserved) — v1.1 Phase 01, human-verified on simulator 2026-08-16 (UAT Test 2)
- ✓ v1.1 D-03/D-07: `StressAPIClient` with Bearer Firebase ID token + backend `/chat` SSE streaming (terminal metadata event, 402 → insufficient-credits) — v1.1 Phase 01, human-verified end-to-end (UAT Test 1) + 87-test suite green
- ✓ v1.1 D-04: Supabase fully removed from source tree (services, config, Keychain tokens) — v1.1 Phase 01, verified in code + 01-REVIEW.md
- ✓ v1.1 G-01-2: Google Sign-In reachable from app UI (Settings → Sync & devices) with post-link email display — v1.1 Phase 01 Plan 01-04, human-verified 2026-08-16
- ✓ v1.1 Phase 2: Credits system — server-authoritative balance (GET /credits + SSE terminal metadata), 402 INSUFFICIENT_CREDITS → outOfCredits paywall, balance at all DEC-2 placements — verification `passed` + live smoke human-validated 2026-08-23
- ✓ v1.1 Phase 2: Backend IAP — POST /credits/redeem with Apple JWS verification (@apple/app-store-server-library 3.1.0, embedded Apple Root CA G2+G3), idempotent on transaction id, purchase ledger — backend suite 17 tests / 50 steps green
- ✓ v1.1 Phase 2: CR-01 free-first consumption + purchased_credits bucket separation (monthly reset preserves purchased) — migration applied + test-pinned
- ✓ v1.1 Phase 2: CR-02/CR-03/CR-05 revocation & expiry semantics — expired/revoked never activate premium; effective premium enforced at deductCredit + chat gate; revoked subscription JWS demotes premium (replay-safe `least()`); WR-10 refunded pack finishes without redemption on both entry points — test-pinned
- ✓ v1.1 Phase 2, IAP-01: Pack + premium product IDs resolve from Bundle.main in both configurations — StoreKitProductCatalogLiveTests 6/6 on simulator (CR-04 closed)
- ✓ v1.1 Phase 2, IAP-02: `Transaction.updates` listener owned at app scope (StoreKitService init)
- ✓ v1.1 Phase 2, IAP-03: Foreground entitlement refresh reachable at entry points
- ✓ v1.1 Phase 2, IAP-04: Premium gating semantics intentional (DEC-1)
- ✓ v1.1 Phase 2, IAP-05: Pricing display accuracy — computed per-unit pack savings
- ✓ v1.1 Phase 2, IAP-06: Live purchase/restore/refund cycle — human-validated 2026-08-23 on Release build against deployed backend (balance +10 exactly once, server-persisted across relaunch, packs-era restore copy, refund demotion CR-05, refunded-pack one-pass clear WR-10)
- ✓ v1.1 Phase 2, BUILD-05: Release-configuration build compiles (`xcodebuild build -configuration Release` exit 0, re-run at verification)
- ✓ v1.1 Phase 2, AUTH-02 residual closed: live kill-check rode the validated live smoke (see Active note removed)
- ✓ v1.1 Phase 3, SES-01/02: Server-side chat history — titled POST /sessions strictly before first /chat (order-pinned), continuous history restore on open (no duplication, 404-tolerant, async no-clobber); UAT-validated on deployed backend 2026-08-23
- ✓ v1.1 Phase 3, PREF-01/02: Preferences sync — PreferencesService (seed-once at chat open + Settings, optimistic update w/ serialized reverts), AI Coach Settings section (en/vi + supportive/direct/educational), stress_context reads live prefs; round-trip UAT-validated
- ✓ v1.1 Phase 3, QA-01: Server-driven quick-action chips — instant local fallback → server swap on chat open, taps ride credit-metered /chat; POST /quick-actions prohibited (grep-gated) with backend metering issue phuongddx/stress-app-be#2 filed
- ✓ v1.1 Phase 3, SES-03 + CLEAN-01: Factory reset wipes ALL server sessions (page-1 re-query loop after CR-01 review fix, deletion-aware fake pins 42-session case) + stressChatSessionId cleared; Supabase remnants 0/0 with exactly 2 protected keep-sites
- ✓ v1.1 Phase 3, CR-02: Trend direction + window selection fixed in StressContextPayload.build (>5-element fixtures pin both directions)
- ✓ v1.1 Phase 3, integration gate: full suite 215 passed (only accepted #8 crash lineage), Release build green, backend deno 29/100 green, remnant/revenue/orphan/quarantine gates green
- ✓ v1.0 AUTH-02: Chat entry point reflects real auth state — closed via v1.1 Phase 2 verification (`passed`); live kill-check (typed 401 / stale-session) rode the human-validated live smoke of 2026-08-23
- ✓ v1.0 AUTH-03: Chat dismiss-mid-stream cancels SSE within one runloop, no credit charged — closed via v1.1 Phase 3: ChatLifecycleTests green in every Phase-3 fence run
- ✓ v1.0 TEST-01: Host CoreSimulator test execution — resolved 2026-08-16: full suite runs green with `-parallel-testing-enabled NO` (215 tests at v1.1 close); only parallel-testing clones fail
- ✓ v1.2 P1 BUILD-01: Privacy manifest passes ASC upload validation — watch `CA92.1` declared, unused media deps + dead Giphy phase removed, TestFlight build 14 processed VALID with 0×ITMS-91053 (deploy run 33749862925); EN/VI policies reconciled with the manifest (5 collection types both locales)
- ✓ v1.2 P1 BUILD-02: One canonical App Group suite `group.stress.ai.com` across all 3 targets — audit-only (CONTEXT's `group.com.stressmonitor.app` was a documented typo, never a repo value); entitlements gate PASS ×3 on the signed golden
- ✓ v1.2 P1 BUILD-03: Plist single-source — empirical inversion: Xcode merges only the documented `INFOPLIST_KEY_*` closed set, so custom `INFOPLIST_KEY_STOREKIT_*` settings never reached the product plist; the plist FILE is the sole live source (six keys byte-equal in the merged product; 12 dead settings deleted; build-13 key-set diff clean)
- ✓ v1.2 P1 AUTH-01: No extractable credential — hardened `verify-archive.sh` gate (CFBundleURLSchemes check fixed vacuous-true, red/green harness 5/5) green on the phase-final Release archive; benign allowlist documented (Google eyJ error constant, Keychain-cleanup literals)
- ✓ v1.2 P1 WIRE-01: Widget renders live data on device — write path was dead (`WidgetPublisher.publish` zero call sites since bba996a); gap-closure plan 01-06 wired a dedupe-guarded save into `StressViewModel.loadCurrentStress` (TDD RED→GREEN, frozen contracts 0-diff); same-tick machine-verified simulator evidence + physical-device parity UAT pass 2026-09-03
- ✓ v1.2 P1 ENV-04: SPM proxy migration complete in place — Release archive producible from the working tree; proxy sources committed behind a scoped `.gitignore` exception; clean-CI resolve green (runs 33745603902/33746936991)
- ✓ v1.2 P1 ENV-05: CI `fastlane match` readonly accepts the dual-cert world — 3 App Store profiles + K2TYLYAWMK Distribution cert installed with zero regeneration (run 33749862925); the documented `setup_match` fallback was never needed

- ✓ v1.2 P2 BUILD-04: one canonical CI-parity `xcodebuild test` invocation (AGENTS.md, `-parallel-testing-enabled NO`) — dev docs and CI cannot diverge; INFOPLIST_KEY doc-truth note folded in (phase automated verification 5/6; DATA-01 is the human half)
- ✓ v1.2 P2 DATA-04: CloudKit delete-truthiness spy suite via the `CloudKitResetServiceProtocol` seam — ungated, mutation-proven (a lying delete fails CI)
- ✓ v1.2 P2 ENV-01/ENV-02: WINDOWS #8 root-caused as a fixture container-lifetime bug and fixed (keep-alive `(ModelContainer, ModelContext)` tuples); `CharacterEntitlementSyncTests` restored to the default run
- ✓ v1.2 P2 ENV-03: WR-03 (DEBUG defaults to real StoreKit; mock via `-mock-iap` launch arg) + WR-04 (unverified transactions never finished) — both red-first pinned
- ✓ v1.2 P3 A11Y-01..05: 44pt hit areas, machine-checked WCAG AA contrast (resolved-UIColor ratios, both appearances), single-owner Reduce Motion helper, Dynamic Type ramp (14 manifest surfaces + 82 widget/watch anchors), 84 orphan files deleted behind three-scheme builds — machine gates green; human walkthrough pending (override recorded at close)

- ✓ v1.3 P1: Design parity — the three designed-but-unbuilt screens shipped standalone with production navigation (History Timeline via Home chart entry, rows push `Route.measurement(id:)` → `MeasurementDetailView`; Measurement Result via Home hero; Biological Age via Settings reroute `.about` → `.bioAge`) — verification `passed` 10/10, full CI-parity gate 311 tests / 53 suites green

### Active

<!-- Next-milestone scope: the v1.2 close carryover (submission tail). Status reflects honest per-requirement verification state, not self-reported marks. -->

**Carried to the next milestone — the submission tail**

- [ ] SHIP-01: App Store screenshot set captured with demo mode disabled
- [ ] SHIP-02: Fastlane `release` lane matches actual readiness (metadata-only upload)
- [ ] SHIP-03: ASC privacy questionnaire answered per the D3 contract
- [ ] DATA-01 residual: two-device CloudKit-propagation delete test (human-gated; evidence apparatus ready)
- [ ] Motion-family follow-up: ChatBottomSheetView:541 decorative `repeatForever` guard; fidget resume on Reduce Motion disable (both ~two-line; `motionReduced` state already wired)
- [ ] v1.3 residual: on-device visual/a11y walkthrough of the three new screens (recommended post-gate in the verification report)
- [ ] StoreKitServiceTests + EntitlementForegroundCorrectionTests re-enablement (StoreKitTest daemon productNotFound — needs a working XCTestDevices layer)
- [ ] v1.1 drift re-test: 5 UAT scenarios vs build 15+ (acknowledged at v1.2 close)
- [ ] (optional) Nyquist VALIDATION.md reconciliation for v1.1 phases 1-3 (coverage TODO, not compliance)
- [ ] Backend: POST /quick-actions unmetered completion route — phuongddx/stress-app-be#2 (iOS grep-gated against wiring it)

### Out of Scope

- **v1.1 product features** (coherent breathing patterns, stress-triggers tracking, weekly digest, localization) — per `docs/project-roadmap.md`; not a submission blocker.
- **v2.0 concept-phase features** (ML/CoreML stress prediction, iPad app, Siri Shortcuts) — explicitly future per roadmap.
- **Dedicated watchOS/Widget unit-test targets** — deferred unless trivially reachable while wiring BUILD-04.
- **Multi-locale App Store listing** — the remediation plan explicitly targets a single-locale first submission.
- **Automating Fastlane `deliver` for release submission** — SHIP-02 takes the manual ASC path for this first release deliberately; automating it is future work once the config has been exercised once by hand.
- **Legacy duplicate source tree / nested duplicate `.xcodeproj` cleanup** (~5k dead lines, flagged HIGH in `CONCERNS.md`) — real debt, but orthogonal to submission readiness. Candidate for a later milestone.

## Context

- Brownfield, previously believed feature-complete per `docs/project-roadmap.md` (Jul 19, 2026) and `docs/KANBAN-SHIP-READINESS.md` (Jun 12, 2026), both of which named the test suite as the sole remaining blocker.
- A same-day, far more thorough source (`plans/0808-2042-appstore-submission-remediation/plan.md`, 6 audits / 65 findings, generated 2026-08-08 20:42 — ~2.5h before this milestone's initialization) found the real gap: **a systemic integration pattern, not isolated bugs** — "correct code written, then never wired up," repeated across accessibility helpers, data-deletion services, the widget data provider, the data-management stack, and the StoreKit transaction listener. This document is the authoritative scope source for this milestone, superseding the older KANBAN/roadmap framing.
- `.planning/codebase/CONCERNS.md` (generated independently, same day) corroborates the auth/privacy findings from a different angle (static codebase analysis vs. targeted audit), which is why both agree D1/D3 are real and unresolved.
- **Decision status at v1.1 close**: D1 RESOLVED (real Firebase auth shipped, v1.1 Phase 01); D2 RESOLVED in practice (encryptedValues shipped, v1.0 Phase 2 — never formally recorded); D3 (privacy contract authority) and D4 (widget in v1) STILL OPEN and gate BUILD-01/SHIP-03 and WIRE-01 respectively — the two decisions v1.2 must make first. The two non-blocking product questions (7-day trial copy, premium character unlock semantics) also remain open.
- Repo state at v1.1 close: work shipped on milestone branch `gsd/v1.1-backend-api-migration` (branch created retroactively for Phase 02+; Phase 01 landed on `main`), tagged `v1.1` at close; backend lives in the separate `stress-app-be` repo, deployed at `stress-api.dropitx.site`.


- Repo state at v1.2 close: merged to `main` via merge commit `8d98697`, tagged `v1.2`, branch `v1.2-submission-readiness` preserved on origin; full suite 296 tests (285 pass / 0 fail / 11 pre-existing skips); ~763k Swift LOC in tree excluding spm-cache.
- Repo state at v1.3 close: work on branch `v1.3-design-parity` (28 commits; PR to `main` pending at close), version 1.0.1 (26); design-parity screens complete, full suite 311 tests / 53 suites green; the submission tail (SHIP-01..03 + the two human gates) remains the next milestone's scope.
- **v1.0 Verification Reality Check** (kept for history, from 2026-08-12 close): v1.0 was closed with `override_closeout` — 5/6 phases un-verified or partially verified, 9/26 requirements unchecked. **v1.1 answered that debt**: every v1.1 phase closed with `passed` verification + human-validated UAT, and v1.1 itself closed `verified_closeout` (milestone audit 21/21 requirements, 3/3 phases, 7/7 integration seams, 4/4 E2E flows; zero gaps, documented tech debt only).

## Constraints

- **Tech stack**: Swift 5.9+ (compiles at `SWIFT_VERSION = 5.0` under a Swift 6.x toolchain), iOS 18.6+ / watchOS 11.6+ deployment targets.
- **No shared framework**: iOS and watchOS duplicate algorithm/model code by file — a fix applied to one must be mirrored in the other where relevant.
- **External dependency with its own lead time**: ASC product/subscription-group creation for Phase 5 (IAP) should be filed the same day Phase 1 starts, independent of code sequencing.
- **`.storekit` local testing config**: `StressMonitorTests/StressMonitorProducts.storekit` now exists; ASC consumables (`credits.small` $1.99/10, `credits.large` $19.99/150) filed and sandbox-verified 2026-08-23.
- **`git.base_branch` is `main`**; milestone work rides `gsd/v1.1-*` branches (strategy: milestone). The v1.0-era `feature/spm-cache-integration` ambiguity is resolved — that work was absorbed.
- **Dependency policy**: 8 third-party SPM packages resolved (Chat, SwiftUICharts + transitive incl. Kingfisher, GiphySDK) + firebase-ios-sdk + GoogleSignIn added in v1.1; the unused-media evaluation (Giphy/Kingfisher/exyte) is still open and folds into BUILD-01's privacy-manifest work.
- **CI shape**: GitHub Actions on `macos-15`/Xcode 26.3 with SPM+DerivedData caching wired; the real test job must pin `-parallel-testing-enabled NO` (BUILD-04 residual).

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Replace the initially-scoped "test infra only" milestone with the full 7-phase App Store remediation plan | Discovered mid-setup that `plans/0808-2042-appstore-submission-remediation/plan.md` already exists — same-day, more thorough (65 findings vs. 1 KANBAN blocker), decision-gated, and ready to execute. Running a narrower parallel GSD track would duplicate/conflict on shared files (StoreKitService, SyncManager, PrivacyInfo.xcprivacy). User confirmed the replacement after reviewing the trade-off. | ✓ Good — plan executed across 6 phases |
| REQ-IDs map directly to the existing plan's phases rather than re-deriving requirements independently | The plan is already audit-grounded with file-level specificity; re-deriving from scratch would be lower-fidelity and duplicate work already done today | ✓ Good |
| D1–D4 (and the 2 non-blocking product questions) are deferred to `/gsd-discuss-phase` for the phases they gate, not resolved during project init | These are product decisions with real trade-offs (e.g., D1 affects submission date directly); premature resolution during setup risks a wrong call made under time pressure | ⚠️ Revisit — D1/D2/D3/D4 all remained open through v1.0 close; carry into v1.1 discuss-phase gates |
| Roadmap phase mode set to Horizontal Layers (`standard`), not the auto-mode default Vertical MVP | This is bug-fix/integration remediation across build config, data, auth, wiring, IAP, listing, and accessibility — not new user-facing feature slices. MVP/SPIDR framing doesn't fit; horizontal phases matching the plan's own structure do. | ✓ Good |
| Granularity: Coarse (3–5 phases) — set before the scope pivot, kept after | Still fits: the roadmapper may consolidate the plan's 7 phases toward the coarse end (e.g., Phase 6+7 are both explicitly parallelizable/non-blocking) without losing the plan's substance | ✓ Good — 7 phases consolidated to 6 (5 + a mid-milestone insert, 01.1) |
| v1.0 closed via `override_closeout` rather than blocking on full verification | 5/6 phases lacked a `passed` verification at close time; user explicitly chose to ship with gaps recorded as tech debt rather than block indefinitely on verification work (2 real devices, a CI host, test-seam design) this session couldn't perform | ⚠️ Revisit — re-verify Phases 3/4/5 and close Phase 02's 3 UAT items early in v1.1 |
| Phase 02's code review ran 3 rounds instead of 1 — each re-review found something the prior fix missed | Standard-depth review + fix is not exhaustive on data-integrity-critical code; a genuine "CloudKit delete reports success on failure" bug (CR-01) surfaced only on the 3rd pass | ✓ Good — process worked as designed (re-review after fix caught real regressions), but signals this subsystem specifically needs deeper review depth or dedicated test-seam work before being trusted |
| v1.1 Phase 01 executed directly on `main` (milestone branch `gsd/v1.1-backend-api-migration` never created) | Prior-session context exhaustion left work half-committed; adopting + committing on `main` was the pragmatic resume path; repo is now 27+ commits ahead of origin | ⚠️ Revisit — at Phase 02 start: create the milestone branch going forward or accept `main`; push before starting Phase 2 |
| D1 (ship real auth vs. stay gated off) resolved by execution — v1.1 Phase 01 shipped real Firebase auth | Gap-closure plan 01-04 made the Google flow user-reachable and UAT-verified it; staying gated off would have shipped dead code | ✓ Good |
| Test invocations pinned to `-parallel-testing-enabled NO` on this host | Parallel-testing clones fail to prepare (`No matching device ... in XCTestDevices`, Mach -308); disabling clones is the reliable workaround — suite runs green in ~60s | ✓ Good — codify in dev docs/CI |
| Plan 01-04 adopted prior-session uncommitted work instead of re-executing | Tasks 1-2 were fully implemented matching the plan; verification (build + 4/4 targeted + 87 full-suite tests) confirmed quality before committing per task | ✓ Good — safe-resume gate worked as designed |
| v1.1 Phase 2 DEC-1/DEC-2: monetization = credits (50 free/mo, free-first consumption) + consumable packs + premium tier for unlimited chat; subscriptions demoted to premium-until entitlement | Usage-based pricing fits an AI-coaching chat product better than subscription-only; server-authoritative balance removes client arithmetic entirely | ✓ Good — live money path human-validated 2026-08-23 |
| Purchased credits in a separate `purchased_credits` bucket (CHECK ≥ 0); `total_credits` stays the immutable free allotment; API contract preserved via derived-total SQL alias | Monthly reset must restore free allotment without clawing back paid credits; alias keeps iOS decode unchanged | ✓ Good — CR-01 closed, test-pinned |
| Refund policy split per route: revoked subscription JWS on /premium/verify = demotion signal (replay-safe `least(premium_until, revocationDate)`); /redeem keeps absolute revoked rejection; no clawback of granted pack credits | Refunds must demote server-side premium without double-grant risk; pack clawback would need ledger reversal complexity for marginal value | ✓ Good — 6-case demotion suite green; sandbox refund validated CR-05 |
| WR-10: refunded pack finished with zero redemption attempts on both entry points (purchase + updates listener) | A revoked pack can never grant credits; finishing it clears the queue so it isn't redelivered forever | ✓ Good — both flow tests green |
| v1.1 Phase 3: continuous history restore (single rolling session, fetch-on-open, no local cache) over a multi-session picker UI | Server-authoritative matches Phase 2's balance precedent; offline chat is impossible anyway (SSE needs network); titled sessions keep a future list trivial | ✓ Good — UAT-validated |
| v1.1 Phase 3: chip taps ride /chat; POST /quick-actions permanently unwired (grep-gated) | The POST route returns unmetered 512-token completions — wiring it would bypass the credits revenue model; metering note filed as phuongddx/stress-app-be#2 | ✓ Good — revenue gate green |
| v1.1 Phase 3 review CR-01: wipe loop re-queries page 1 instead of advancing offset | Backend paginates over live rows — advancing offset after deletion skips every page past the first (>20 sessions → residue while reset reports success) | ✓ Good — deletion-aware fake + 42-session regression pin it; caught only because review used a deletion-aware fake |
| v1.1 closed `verified_closeout` — audit full scores, zero gaps; v1.2 "submission readiness" recommended for the v1.0-carryover list | The v1.0 override debt (unverified phases, unchecked requirements) was fully answered: 3/3 v1.1 phases passed verification with human-validated UAT (live money-path smoke, 5 backend scenarios), milestone audit cross-checked 21/21 requirements | ✓ Good — carryover list is now purely submission-blocking items, not verification debt |
| Debug session `google-signin-ui-entry-missing` closed as stale-resolved at v1.1 close | audit-open flagged it open (status `diagnosed`, updated 2026-08-15), but gap-closure plan 01-04 had shipped the exact diagnosed fix on 2026-08-16 — the session was never re-checked. Lesson: re-run audit-open after gap-closure lands, not just at milestone close | ✓ Good — caught by cross-referencing PROJECT.md Validated entries before archiving |
| v1.2 P1 D3 resolved: code is the contract | `StressContextPayload`'s actual derived-score payload is the normative privacy statement; docs (root CLAUDE.md, EN/VI policies) move toward code, never the reverse; zero payload churn (byte-identical proof) | ✓ Good — build 14 ASC-valid, policies reconciled, UAT parity pass |
| v1.2 P1 D4 resolved: keep the widget and make it true | Removing a shipped TestFlight surface right after external beta is a user-visible regression; the gap was a dead call site (dropped at bba996a), not a design flaw | ✓ Good — wired via 01-06 (TDD), device-verified |
| v1.2 P1 ENV-05: CI surface made concrete — draft PR (ci.yml) + user-approved workflow_dispatch (deploy.yml) | A bare branch push triggers NO workflow (ci.yml=PRs, deploy.yml=main/release/dispatch); only deploy.yml runs fastlane match; the TestFlight dispatch is a one-way-ish external action, gated by a blocking checkpoint with the empty-widget caveat disclosed | ✓ Good — both surfaces green; approval recorded pre-timestamp |
| v1.2 P1 BUILD-03 inversion: plist FILE is the single source, not `INFOPLIST_KEY_*` | Empirically discovered mid-execution: Xcode merges only the documented closed set of `INFOPLIST_KEY_*` — custom `INFOPLIST_KEY_STOREKIT_*` settings were dead duplicates that never reached any product plist; deleting the file-side keys would have silently starved StoreKit config (T-03-01). Fixed from the opposite direction: file restored as source, 12 dead settings deleted | ✓ Good — verifier confirmed criterion substance (no duplicate contributions, every key resolves) |
| v1.2 P1: spm-cache proxy sources committed behind a scoped `.gitignore` exception | Clean CI checkout could not resolve the local proxy package (whole tree gitignored) — surfaced empirically by the draft-PR CI run; committing the 9 package files (caches still ignored) makes checkouts self-sufficient | ✓ Good — clean-CI resolve green |
| v1.2 P1: code review forced 3-pass iteration and found a vacuous gate (CR-01) | The AUTH-01 gate's CFBundleURLSchemes check passed on empty arrays (its own quotes satisfied the grep); plan-checker iterations 2–3 caught the `-A3` grep-window blocker empirically. Lesson: verify commands must be tested red, not just green — the harness now does both | ✓ Good — gate hardened with anti-vacuous red/green tests |

| v1.2 P2: WINDOWS #8 diagnosed as fixture container-lifetime, not a CI-host defect | Keep-alive `(ModelContainer, ModelContext)` tuple fixtures — returning a bare context let the owning container deallocate mid-op | ✓ Good — crash family gone, quarantined suite restored |
| v1.2 P3: contrast and Dynamic Type truth is machine-checked, not review-asserted | Resolved-UIColor ratio suites + `FontWellnessTypeParityTests` pin the tokens; regressions fail CI instead of awaiting a reviewer | ✓ Good |
| v1.2 close: a parallel GSD fix stream superseded a stalled plan's Tasks 1-8; user ruled accept-supersede + test-only pins | Re-executing the plan text would have downgraded stronger landed fixes (4.5:1 per-tier labels back to unconditional-white 3:1); only the genuinely-open IN residuals were executed (SDD subagent loop, 9 commits, whole-branch review clean) | ✓ Good |
| v1.2 closed `override_closeout` with Phase 4 deferred | Phase-4 prerequisites are green and its scope needs its own discuss/plan cycle; user directed the close to bank the remediation work | ⚠️ Revisit — SHIP-01..03 + the two human gates are the submission tail |
| v1.3 DEC-1: History Timeline is the production entry point for the dead `Route.measurement(id:)` route | The route existed only in the resolver docs; a standalone history screen gives every persisted reading a push destination | ✓ Good — link-wired and verified, 6-test suite green |
| v1.3 DEC-2: Settings "Biological Age" row reroutes `.about` → `.bioAge` | The row's label promises Biological Age; `.about` was a placeholder | ✓ Good — exact-row reroute verified |
| v1.3: HealthKit DOB fetched through an explicit protocol requirement, not a protocol-extension default | The extension default could never see the conformer's `dateOfBirth` — a silent 35-fallback dead default | ✓ Good — dispatch fix `692770f`, test-pinned |
| v1.3: new test suites need explicit pbxproj registration (app-target auto-registration does not apply) | A silently-uncompiled suite masquerades as green — surfaced as a 294→306 test-count jump mid-phase | ✓ Good — registered A035–A037, `plutil -lint` OK |
| v1.3: verifier-caught fixture instability fixed in the fixture, never by weakening production code | `BiologicalAgeViewModel.load()` correctly uses `Date()`; the test fixture future-dated today's sample before 10:00 | ✓ Good — `92d54fc` clamp + full gate re-run green in the failing window |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-09-13 after v1.3 milestone (Design Parity closed — verified_closeout; branch `v1.3-design-parity`, PR to main pending)*
