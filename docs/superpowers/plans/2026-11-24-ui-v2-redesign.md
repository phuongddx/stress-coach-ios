# UI V2 redesign: implementation plan

- **Spec:** [`docs/superpowers/specs/2026-11-24-ui-v2-redesign-design.md`](../specs/2026-11-24-ui-v2-redesign-design.md)
- **Shape:** 10 stacked PRs. Each branch is based on the one before it and merges in order. Nothing merges into `main` without Phuong's approval.
- **CI:** `ci.yml` only fires for PRs into `main`/`develop`, so stacked PRs (base = previous phase branch) get CI through `gh workflow run ci.yml --ref <branch>`; the check runs attach to the branch head commit and show on the PR. When a PR is retargeted to `main` after its parent merges, CI runs again on its own.

## Phases

| # | Branch | PR scope | Inventory rows |
|---|---|---|---|
| 0 | `feat/ui-v2-00-spec` | This spec and plan | — |
| 1 | `feat/ui-v2-01-foundation` | Colour sets (Any/Dark), `Color.V2`, tier `color`/`fillColor`, legacy tokens re-pointed to V2, `Views/DesignSystem/V2/` components (gauge, tier badge, card, section header, buttons, chip, Plus pill, Plus lock, factor row, delta pill, state view, skeleton), tab bar tint, contrast tests for V2 pairs | foundation for all rows |
| 2 | `feat/ui-v2-02-home` | Home hero gauge, Ripple card, vitals, quick actions, chart card, permission/no-reading/error states; History; Measurement Result; Measurement Detail; Health consent | 4, 8, 9, 10, 20 |
| 3 | `feat/ui-v2-03-action` | Action grouped lists and 44 pt steppers; Box Breathing intro, session (Reduce Motion ring), summary (shared Plus lock); Mini Walk all states | 5, 11, 12, 13, 14 |
| 4 | `feat/ui-v2-04-insights` | Trends (one locked preview + Plus list for Free, skeleton, empty); Characters; Character detail; Biological Age | 6, 15, 16, 17 |
| 5 | `feat/ui-v2-05-onboarding-chat` | Onboarding Welcome, Health Sync, Success; Ripple chat sheet; Health Coach agent chat | 1, 2, 3, 18, 19 |
| 6 | `feat/ui-v2-06-settings` | Settings (Me) grouped list with icon tiles and Health-off banner; Science & Sources; About; Appearance; Watch Face prefs; Manage, Export, Delete data | 7, 23, 24, 25, 26, 27, 28, 29 |
| 7 | `feat/ui-v2-07-paywall` | Paywall (StoreKit prices, skeleton/failure, auto-renew terms by the CTA, Restore/Manage/Terms/Privacy, footer above the home indicator, dark mode); Purchase success | 21, 22 |
| 8 | `feat/ui-v2-08-watch` | Watch tokens (dark), menu, home gauge, breathe, history, today, cycle, complications | W1–W7 |
| 9 | `feat/ui-v2-09-widgets` | Widget tokens, small/medium/large, lock screen (rectangular/circular/inline), stale and empty states | G1, G2 |

All 38 rows are covered exactly once across phases 2–9.

## Per-phase checklist

1. Branch from the previous phase branch.
2. Change only view and theme code for the rows in scope. View models, services, models and entitlement logic stay untouched; if a row needs new state, defer it and list it in the PR.
3. Replace legacy colour/typography usages in the touched views with `Color.V2`, tier colours and the V2 components. No hex literals, `Color.white` or `Color.black` in views.
4. Check each screen in light, dark, an accessibility text size and Reduce Motion.
5. Build locally (`StressMonitor` Debug and Release, watch and widget when touched) and run the unit tests.
6. Capture before/after simulator screenshots in light and dark with `-demo-mode` into `docs/screenshots/ui-v2/<phase>/` and link them in the PR body with the rows covered.
7. Push, open the PR against the previous phase branch, dispatch CI, and fix until `Lint & Build`, `Build watchOS`, `Build Widget` and `Test` are green.

## Tests

- `ContrastComplianceTests` (phase 1, both appearances): V2 text tokens (`ink`, `ink2`, `ink3`, `accent`, `danger`) on `bg`/`surface`/`surface2` ≥ 4.5:1; tier text colours on `bg`/`surface` ≥ 4.5:1; `onFillColor` on each tier `fillColor` ≥ 4.5:1; `onAccent` on `accent`, `onLime` on `lime`, `plus` on `plusBg` ≥ 4.5:1. Tier fills are not asserted against `surface`: the light Relaxed and Elevated fills sit below 3:1 there by design, so a fill is never the only cue (shape and name always accompany it).
- `StressCategoryAccessibilityTests`: every tier has a shape symbol and a distinct fill (phase 1).
- `PlusLockedModifierTests`, `HardcodedPricingGuardTests`, `PaywallPriceMathTests`, `TrendsRangeLockTests` must stay green unchanged; they pin the logic this redesign must not move.
- The repo has no snapshot or UI test target; screenshots are attached to PRs instead of adding a snapshot dependency.

## Risks

| Risk | Mitigation |
|---|---|
| Re-pointing legacy tokens changes contrast on screens not yet migrated | Contrast tests run on the re-pointed tokens in phase 1; remaining screens are migrated in phases 2–7 |
| Stacked PRs drift when an earlier one changes after review | Rebase the stack top-down and re-dispatch CI on each branch |
| Watch and widget have no local simulator runtime for screenshots | Build in CI; capture with a watchOS runtime if one can be installed, otherwise attach Xcode preview renders and say so in the PR |
| Local Xcode (27.1) differs from CI (26.3) | CI is the gate; local builds are a fast pre-check only |
