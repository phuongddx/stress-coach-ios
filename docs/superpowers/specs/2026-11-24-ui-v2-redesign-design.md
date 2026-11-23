# UI V2 redesign: spec

- **Status:** approved by Phuong Doan on 2026-11-23 ("I am happy with that new design")
- **Scope:** visual redesign of the iPhone app (29 screens), the Apple Watch app (W1–W7) and the widgets (G1–G2): 38 inventory rows
- **Plan:** [`docs/superpowers/plans/2026-11-24-ui-v2-redesign.md`](../plans/2026-11-24-ui-v2-redesign.md)

## 1. Source of truth

| What | Where |
|---|---|
| Clickable prototype, token sheet, handoff notes | `ui-v2-design/index.html` (outside this repo, in the project workspace) and the OpenDesign project `stress-ai-coach-ui-v2` |
| Before/after for all 38 rows | `ui-v2-design/before-after.html` |
| Prototype CSS (tokens, components) | `ui-v2-design/v2.css` |
| Screen markup per screen and state | `ui-v2-design/screens.js` (`V2.S.<screen>`, `V2.ROWS`) |
| Screen inventory (rows 1–29, W1–W7, G1–G2) | `ui-v2-audit/inventory.md`, `inventory-raw.md` |

When the prototype and this spec disagree, this spec wins for engineering rules (sections 4–6); the prototype wins for layout and copy.

## 2. Goal and non-goals

**Goal.** Every surface reads as one product: paper canvas, one forest-green accent for actions, lime only for progress, success and Plus, and warm colours as stress rises. Each screen has one hero, uses the shared components, and has designed loading, empty, error, Plus-locked and Health-denied states where the screen has data.

**Non-goals (hard rules).**

- No behaviour changes. Data flow, HealthKit queries, the stress algorithm, SwiftData models, CloudKit, the backend API, StoreKit purchase/restore logic, entitlements (`PlusAccess`, `PremiumState`, `PurchaseAvailability`) and navigation routes stay as they are. A view may only read state that already exists.
- No hardcoded prices, trial lengths or ratings. Prices and the introductory offer come from StoreKit `Product` values at runtime (`HardcodedPricingGuardTests` enforces this).
- No new dependencies (no snapshot-testing package).
- Companion art is unchanged; only backgrounds are re-tinted with the companion tokens.
- Out of scope: the unreachable `WatchWorkoutView`, credit packs (not live), App Store metadata and screenshots.

Prototype items that would need new behaviour are listed in section 8 and deferred.

## 3. Design tokens

Each colour token is a named colour set in the asset catalog with Any and Dark appearances, exposed in Swift as `Color.V2.<token>`.

| Token | Light | Dark | Use |
|---|---|---|---|
| `bg` | `#F1F1E8` | `#0B1411` | Screen canvas |
| `surface` | `#FCFCF8` | `#14201B` | Cards, grouped lists |
| `surface2` | `#E6EADC` | `#1C2A24` | Flat cards, chips, tracks, fields |
| `surface3` | `#D9DFCD` | `#26362F` | Toggles off, selected segment (dark) |
| `ink` | `#13211D` | `#EEF1E6` | Primary text |
| `ink2` | `#44524C` | `#B9C5B8` | Secondary text |
| `ink3` | `#5A6761` | `#8F9D94` | Tertiary text, captions, chevrons |
| `line` | `#13211D` 11% | `#EEF1E6` 9% | Hairlines |
| `accent` | `#206A5D` | `#5FBFA9` | Actions, links, selected tab |
| `onAccent` | `#FFFFFF` | `#062A22` | Text on `accent` |
| `accentSoft` | `#DCEBD2` | `#1F3830` | Secondary button, tinted cards, icon tiles |
| `accentTint` | `#BFDCAE` | `#2C6B5C` | Selected chip, sage surfaces |
| `lime` | `#81B214` | `#9CCB3A` | Progress fills, success |
| `onLime` | `#1A3006` | `#142605` | Text on `lime` |
| `limeInk` | `#3E6610` | `#9CCB3A` | Lime-coloured text |
| `plus` | `#3D5C0A` | `#B5DA62` | Plus pill text, lock icon |
| `plusBg` | `#E8F1CF` | `#1F2E17` | Plus pill and lock surfaces |
| `danger` | `#B42318` | `#FF7A6E` | Destructive text, errors |
| `dangerSoft` | `#FAE8E3` | `#FF7A6E` 12% | Destructive button background |

**Stress tiers.** Text colours pass 4.5:1 on `surface` and `bg`; fill colours are for shapes, arcs and bars. Every tier is dual-coded with a name and an SF Symbol shape.

| Tier (`StressCategory`) | Name | Shape | Text light | Fill light | Text and fill dark |
|---|---|---|---|---|---|
| `.relaxed` | Relaxed | `leaf.fill` | `#3E6610` | `#81B214` | `#9CCB3A` |
| `.mild` | Mild | `circle.fill` | `#1F6E66` | `#2F8A80` | `#74C3CE` |
| `.moderate` | Elevated | `triangle.fill` | `#835800` | `#F2BC50` | `#F2C46A` |
| `.high` | High | `square.fill` | `#AE3E17` | `#C2461F` | `#EE7448` |
| `.severe` | Severe | `octagon.fill` | `#8E2240` | `#8E2240` | `#F0788C` |

`StressCategory.color` returns the tier **text** colour (it is used for text across the app), and a new `StressCategory.fillColor` returns the fill. The tier boundaries do not change.

**Companion tints** (backgrounds only): ripple `#4E9FA6`/`#5FB3B9`, blossom `#9CC56B`/`#A6CF78`, ember `#EE9F78`/`#F2A984`, zephyr `#B4AEDB`/`#BDB7E3`, lumi `#5E7FB8`/`#7E9BD0`.

**Type.** System text styles only, so Dynamic Type works everywhere: largeTitle, title, title2, title3, headline, body, callout, subheadline, footnote, caption, caption2. Numbers (scores, vitals, timers) use `.rounded` design with `monospacedDigit()`. Eyebrows are footnote semibold, uppercase, `ink3`.

**Spacing** 4, 8, 12, 16, 20, 24, 32, 48. Screen margins 16. **Radii** 8, 12, 16, 22 (cards), 28, capsule. **Elevation:** light mode cards use a 1 pt soft shadow (`ink` at 6%); dark mode uses none.

## 4. Shared components (Phase 1)

Live in `StressMonitor/StressMonitor/Views/DesignSystem/V2/`. Screens use these instead of local copies.

| Component | Spec |
|---|---|
| `V2StressGauge` | 240° arc (from 150° to 30°, clockwise), 12 pt track in `surface2`, value arc in the tier fill, ticks at 25/50/75/90. Centre: score in `.rounded` 56 pt-equivalent scaled with Dynamic Type, tier shape + name under it. Accessibility: one element, label "Stress score 32 of 100, Mild". Animates the arc on appear and on change unless Reduce Motion is on. Empty state shows "—" and "No reading yet". |
| `V2TierBadge` | Tier shape + name in the tier text colour; `compact` variant is shape only with the name as the accessibility label. |
| `V2Card` | `surface`, radius 22, padding 16, light-mode e1 shadow. Variants `.flat` (`surface2`), `.tint` (`accentSoft`). |
| `V2SectionHeader` | title3 semibold title plus optional trailing accent link. |
| Buttons | `V2ButtonStyle(.primary / .secondary / .ghost / .destructive / .destructiveFill / .lime)`, capsule, 50 pt min height (44 for `.compact`), headline weight, 0.38 opacity when disabled, scale feedback off under Reduce Motion. |
| `V2Chip` | 32 pt min height capsule; selected uses `accentTint` (light) / `accent` (dark). Touch area padded to 44 pt. |
| `V2PlusPill` | "PLUS" pill: `plusBg`, `plus` text, `lock.fill` optional. |
| `V2PlusLock` | The one locked-content pattern: blurred preview of the real content, a lock tile, a one-line reason and "Try Plus free" (secondary button) that calls the existing `PaywallController.present(reason:)`. Replaces the visuals of `PlusLockedModifier`; the gating logic in `PlusLockedModifier`/`PlusAccess` does not change. |
| `V2FactorRow` | Factor icon tile, name, one accent bar (0–1), value + unit, and a one-line sentence. Missing factor shows "No data" in `ink3`. |
| `V2DeltaPill` | ▲/▼ + words ("4 lower than yesterday"); good uses relaxed text colour, bad uses high text colour. |
| `V2StateView` | Shared empty / error / Health-denied block: SF Symbol, title, one sentence, optional primary action (e.g. Retry, Open Settings). |
| `V2Skeleton` | Rounded `surface2` placeholders; shimmer only when Reduce Motion is off. |

The legacy tokens (`Color.Wellness.*`, `Color.adaptive*`, `Color.stress*`, `HomeCharacterDesignTokens`) are re-pointed at the V2 values in Phase 1, so screens not yet migrated still pick up the palette. Phases 2–5 then replace legacy usages screen by screen.

## 5. Platform rules

- **Light and dark:** every screen, including Breathing, Mini Walk, Paywall and Purchase success (today light-only), is built from tokens. No `Color.white`/`.black`/hex literals in views except inside the token layer and the shipped character art.
- **Dynamic Type:** text styles only; layouts reflow up to accessibility sizes (horizontal stacks become vertical with `ViewThatFits` or `dynamicTypeSize` checks where they would clip). Existing `.accessibleDynamicType()` stays where it is used.
- **Reduce Motion:** gauge and charts do not animate; breathing circle becomes a filling ring; no shimmer; no spring scale on buttons.
- **Touch targets:** at least 44×44 pt (habit steppers, chips, watch mood faces 32 pt+ with 44 pt hit area).
- **Accessibility:** tier colour is never the only cue; gauges and charts expose one summary label; decorative images are hidden.
- **Watch:** dark only, true black canvas, the V2 tier colours (dark values), one number per glance, lists scroll with the Digital Crown.
- **Widgets:** system backgrounds (`containerBackground`), tier shapes and colours as in the app, stale and empty states; lock screen uses "—" for no data (no emoji).

## 6. Paywall rules (rows 21–22)

- Plans and prices come from `StoreKitService` products (`displayPrice`, period, introductory offer). Loading shows a skeleton; failure shows `V2StateView` with Retry. No literal price or trial length in source.
- The auto-renew sentence sits next to the CTA, built from the selected product: price, period, trial length if any, "renews automatically unless cancelled at least 24 hours before the end of the period; manage or cancel in Settings › Apple ID › Subscriptions."
- Always visible: close button, Restore Purchases, Manage subscription (when subscribed), Terms of Use, Privacy Policy.
- The footer sits inside the safe area: the links are laid out above `safeAreaInsets.bottom` (the prototype clips them behind the home indicator; the build must not).
- Reason headline (`PaywallReason.headline`) and out-of-credits line keep their current logic.
- Purchase success states the trial end date when StoreKit reports one and lists what unlocked.

## 7. Verification

- CI on every PR: `Lint & Build / Lint & Build`, `/ Build watchOS`, `/ Build Widget`, `/ Test`. The `Release Build` check proposed in PR #73 is not on `main`; each phase is also built locally with `-configuration Release` so previews and debug-only code cannot break Release.
- Unit tests: `ContrastComplianceTests` gains V2 token pairs (text 4.5:1, UI 3:1, both appearances); `StressCategory` tests cover `fillColor`/shape; existing tests stay green and none are skipped or disabled.
- Screenshots: each PR attaches before/after iPhone simulator captures in light and dark (demo mode, `-demo-mode`), stored under `docs/screenshots/ui-v2/<phase>/` and linked from the PR body.

## 8. Deferred (needs behaviour, not in this redesign)

| Row | Prototype item | Why deferred |
|---|---|---|
| 11 | Breathing length picker, sound toggle | New settings and session logic |
| 19 | Agent chat starter prompts | New send behaviour on a feature-flagged screen |
| 27 | Storage summary (counts, size) | New data queries |
| 28 | Export size preview | New computation |
| 2 | Per-type Health purpose before the iOS sheet | Copy only is in scope; any new denied-state detection beyond existing authorization status is deferred |

Each phase PR lists anything else it could not do without a behaviour change.
