# Ripple v2 rollout: mascot states and app icon

- **Status:** Approved by the owner (Ripple v2 art approved 2026-11-24)
- **Scope:**
  - iPhone app, Apple Watch app and complications, and widgets, in `phuongddx/stress-coach-ios`.
  - The landing page and help site in `phuongddx/stress-coach-ai`.
- **Plan:** [2026-11-24-ripple-v2-rollout.md](../plans/2026-11-24-ripple-v2-rollout.md)
- **Art source:** `/Users/ddphuong/Projects/next-labs/stress-ai/ui-v2-design/ripple-v2/`. Its `NOTES.md` covers construction, contrast and licence notes.

## 1. Goal

Replace the old Ripple otter everywhere it appears with **Ripple v2**:
- A chibi kid in a hooded pastel otter onesie.
- 11 drawn states: `base`, `relaxed`, `mild`, `elevated`, `high`, `severe`, `breathing`, `walking`, `celebrating`, `sleeping` and `thinking`.
- Each state as a full body and a head crop.

Ripple's pose now follows the user's stress level on every surface: phone, watch and widget. The Ripple v2 app icon replaces the current icon on iPhone and Apple Watch.

## 2. Non-goals

- The other four companions (blossom, ember, zephyr and lumi) keep their current art and behaviour. Their style will not match Ripple v2. This is a known gap and the subject of a later spec.
- No change to stress scoring, `StressCategory` bands, copy tone, pricing, IAP, or the character unlock and evolution rules.
- No new dependencies: no Lottie and no snapshot-testing package.
- The legacy `landing/` folder inside the iOS repo is not touched.
- Nothing is submitted to App Review.

## 3. Current state (main @ 9a9ab5f)

- **iPhone:**
  - The mascot is one SVG per companion (`Assets.xcassets/Characters/ripple.svg`, `ripple-hero`). It is drawn through `StressBuddyIllustration` → `CharacterAssetResolver` / `CharacterAssetCatalog`.
  - The image ignores mood. `RippleMood` only drives an ambient animation (`CharacterAnimationModifier`).
- **Mood and level mapping is inconsistent:**
  - `RippleMood.from(stressLevel:)` uses 6 score bands (<10, 10–25, 25–50, 50–75, 75–90, ≥90).
  - The watch uses `StressCategory` directly.
  - The widget uses `WidgetStressTier` with bands at 21, 41, 61 and 81.
- **Watch:** the otter is drawn in SwiftUI shapes (`RippleOtter` in `Watch App/Theme/StressCharacter.swift`). The watch asset catalog has no images.
- **Widget:** the mascot is an emoji (`WidgetCharacterFace`, `Text(tier.emoji)`).
- **App icon:** PNG `AppIcon.appiconset` in each of the three targets, drawn by `scripts/generate_app_icons.py`. There is no Icon Composer `.icon`. PR #86 (icon B) is superseded by this spec.
- **Project:** a plain xcodeproj with file-system synchronized groups (objectVersion 77). Files dropped into a target folder join that target, and each target has its own `.xcassets`.

## 4. Design

### 4.1 One pose model

Add `RipplePose`, a `String`-raw enum with the 11 states. It is the single place that decides which drawing to show.

```swift
enum RipplePose: String, CaseIterable, Sendable {
    case base, relaxed, mild, elevated, high, severe
    case breathing, walking, celebrating, sleeping, thinking

    static func from(category: StressCategory) -> RipplePose   // .relaxed→.relaxed, .mild→.mild,
                                                              // .moderate→.elevated, .high→.high, .severe→.severe
    var assetName: String      { "ripple-v2-\(rawValue)" }
    var headAssetName: String  { "ripple-v2-\(rawValue)-head" }
    var accessibilityLabel: String   // "Ripple, relaxed and floating", "Ripple, a little worried", …
}
```

**Level → pose is a table, not bands.** It goes through `StressCategory`, so the phone hero, the watch and the widget always agree. Score → category stays `StressResult.category(for:)`. No data: `.base`.

**`RippleMood` stays** for animation and the existing call sites. It gains `var pose: RipplePose`:

| RippleMood | pose |
|---|---|
| serene | base |
| relaxed | relaxed |
| focused | mild |
| happy | mild (waving) |
| celebrating | celebrating |
| worried | elevated |
| determined | high |
| tired | sleeping |

`StressBuddyIllustration` changes as follows:
- When the companion is `ripple`, it renders `Image(pose.assetName)` (or the head asset for head-crop sizes; see 4.3). It gets the pose either from an explicit `pose:` argument or from `mood.pose`.
- Other companions keep the current path unchanged.
- The ambient `.characterAnimation(for:)` stays.

`CharacterAssetCatalog` changes:
- `"ripple"` and `"ripple-hero"` resolve to `ripple-v2-base`.
- The character collection, the paywall trio and the detail screen pick up v2 automatically.

### 4.2 Surface → pose

| Surface (file) | Today | Ripple v2 |
|---|---|---|
| Home hero (`StressHeroCard`) | `RippleMood.from(stressLevel:)` | `RipplePose.from(category:)`, full body. No data → `base` |
| Recommendation card (`RippleRecommendationCard`) | mood from level | pose from category, head |
| AI insight card (`AIInsightCard`) | `.happy` | `thinking`, head |
| Mood check-in (`MoodCheckInView`) | local mood map | its `MoodLevel` mapped to the 5 level poses, head |
| Chat avatar (`ChatBottomSheetView:146`) | `StressBuddyIllustration` | `base`, head, on a teal chip in light mode |
| Chat typing indicator (`ChatTypingDots`, sheet and `AgentChatView`) | 3 dots | `thinking` head (small) + the existing dots. Label "Ripple is thinking" |
| Chat empty / unavailable | `.happy` / `.tired` | `mild` / `sleeping` |
| Onboarding welcome / success | `.happy` / `.celebrating` | `mild` (wave) / `celebrating` |
| Permission denied / empty (`PermissionCardView`) | `.tired` | `sleeping` |
| Breathing summary hero + "Ripple note" row | `.happy` / `.serene` | `breathing` / `relaxed` head |
| Mini Walk complete | `.happy` | `walking` |
| Purchase success | `.happy` | `celebrating` |
| Settings `CompanionBanner`, `AboutView`, `WatchFacePreferencesView` | ripple | `base` |
| Character collection / detail / grid / paywall trio | `ripple` SVG | `ripple-v2-base` (via the catalog) |
| `MoodPreviewButton` (character detail) | mood previews | for ripple, shows the pose for each previewed mood |
| Watch home gauge, menu, history empty | `RippleOtter` shapes | `RipplePose.from(category:)` head, PNG/SVG from the watch catalog. Empty → `sleeping` |
| Watch complications (22–26 pt) | `RippleOtter` | level head. Verify it reads at 22 pt and in tinted faces (see 4.4) |
| Widgets small / medium / large (`WidgetCompanionBadge`) | emoji | level head in the existing accent disc. The disc uses teal `#206A5D` in light mode |

Copy changes are limited to accessibility labels and the typing label. "Water Otter" stays, since Ripple still wears an otter suit.

### 4.3 Assets

- **Format:**
  - The designer's SVGs (512 artboard, plain paths plus `clipPath`, 92 KB for all 22) go in as single-scale image sets with `preserves-vector-representation: true`. This is the same pattern as today's `ripple.svg`, and it keeps widget memory low.
  - If any SVG renders wrong in Xcode (check every one in the simulator), use that state's PNGs at @1x 512 downscaled to @1x/@2x/@3x for its largest on-screen size, not 1536 px.
- **Names:** `ripple-v2-<state>` and `ripple-v2-<state>-head`, in a `RippleV2/` folder group in each catalog that needs them.
- **Which target gets what:**
  - iPhone `Assets.xcassets`: all 22.
  - Watch catalog: the 5 level heads plus `base-head` and `sleeping-head`.
  - Widget catalog: the 5 level heads plus `base-head`.
- **Removals (iPhone):**
  - Remove `Characters/ripple.imageset`, `Characters/ripple-hero.imageset` and `ripple_droplet_calm.imageset` once nothing references them (grep shows zero hits).
  - Keep the other companions' sets.
  - Keep the legacy `Character*` fallbacks unless they become unreferenced.
- **Source of truth in the repo:** `design/ripple-v2/` gets `svg/`, `NOTES.md` and `_source/ripple.py`. PNG renders are not committed.
- **Light-mode treatment:** the suit outline is 1.34:1 on `#F1F1E8`. Head crops at ≤ 44 pt in light mode sit on a `#206A5D` circle (the designer's recommendation, shown in `previews/light-dark-check.png`). Dark mode needs no chip (12.3:1).

### 4.4 Watch and widget specifics

- **Watch:**
  - `CharacterFaceView` keeps its signature.
  - For `.ripple` it renders `Image(RipplePose.from(category:).headAssetName)`. Nil category → `sleeping`.
  - `RippleOtter` is deleted once unused.
  - The other creatures are unchanged.
  - `StressCategory` is duplicated per target, so add the watch-side `RipplePose` mapping in the watch target. Keep the table identical; the shared test (§6) guards the phone copy.
- **Complications and widgets in tinted / accented rendering:**
  - Full-colour images go through `.widgetAccentedRenderingMode(.fullColor)` where the API is available.
  - Otherwise use `.accentedDesaturated`, and verify the face is still readable.
  - If a 22 pt head is not legible, fall back to the current gauge-only layout for that family, and record it in the PR.
- **Widget:**
  - `WidgetCharacterFace` draws `Image(headAssetName)` instead of the emoji.
  - The tier → pose mapping is `WidgetStressTier.from(category:)` → category → pose. `resting` (no data) → `base`.

### 4.5 App icon

- **Use the Ripple v2 icon:** `ripple-v2/icon/AppIcon.icon` (2 layers, face and hood; light, dark and tinted variants).
  - iPhone: add it as `StressMonitor/StressMonitor/AppIcon.icon`.
  - Watch: add `ripple-v2/icon/WatchAppIcon.icon` as `StressMonitor/StressMonitorWatch Watch App/AppIcon.icon`. It is renamed so `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` matches.
- **Keep each `AppIcon.appiconset`** as the fallback for iOS 18 / watchOS 11, regenerated from `ripple-light-1024.png`:
  - iPhone and widget sets: every existing size.
  - Watch set: 1024. The watch uses the circular-mask source.
- **Generator:** replace `scripts/generate_app_icons.py`'s drawing code with a resize from `design/ripple-v2/icon/ripple-light-1024.png`, using `sips` or PIL. A rerun then reproduces the fallbacks.
- **PR #86:**
  - Follow its `.icon` integration approach, and reuse its `HIG-CHECK.md` checklist for the new icon.
  - Close #86 with a comment pointing to the new PR. It can be reopened if needed.

### 4.6 Landing page and help site (`phuongddx/stress-coach-ai`)

The real landing pages are the standalone `.vitepress/home/index.html` (en) and `.vitepress/home/vi.html` (vi). `scripts/home.mjs` copies them over the VitePress output. Make every change in both languages.

1. **Brand files:** regenerate from the Ripple v2 light icon:
   - `public/favicon.png` (64)
   - `public/apple-touch-icon.png` (180)
   - `public/assets/icon.png` (256)
   - `public/share.jpg` (1200×630 og image: the new icon and Ripple `base` on `#F1F1E8`, with the app name)
2. **Alt text:** "Ripple the otter on blue" / "rái cá Ripple trên nền xanh" → on green ("trên nền xanh lá").
3. **`#coach` section (Meet Ripple):** add the full-body `base` (or `thinking`) Ripple v2 beside the copy. Use the SVG from `public/img/ripple/`.
4. **`#score` section:** add a **5-level strip**: Relaxed, Mild, Elevated, High, Severe. Each entry is a Ripple head (SVG), the level name, the score range (0–25, 25–50, 50–75, 75–90, 90–100), and the level colour as a small dot:
   - Relaxed `#8CC12A`
   - Mild `#4FA89D`
   - Elevated `#F2BC50`
   - High `#E2683C`
   - Severe `#E46A80`

   The strip:
   - Wraps to 2 rows on mobile.
   - Has `alt` text per image.
   - Honours `prefers-reduced-motion`: no animation, or a subtle one when motion is allowed.
5. **Screenshots:** re-capture `public/img/v2/phone-{home,chat,breatheIntro,trends}-{light,dark}.webp`, `watch-*.webp`, `lockscreen.webp` and `widgets-{light,dark}.webp` from the new app build, at the same pixel sizes as the current files.
6. **Help page:**
   - `principle/stress-levels.md` and `vi/principle/stress-levels.md` describe 4 outdated levels. Rewrite both to the app's 5 levels and score ranges, with the Ripple head per level.
   - Images live under `public/img/ripple/`, which keeps them out of the build output's top level.
7. **Clean-up:**
   - Delete the unreferenced `public/assets/brand/ripple.svg`.
   - Do not touch the CSS `.ripple` ring animation; it is not the mascot.

## 5. Accessibility

- Every Ripple image has a label from `RipplePose.accessibilityLabel`, or is `.accessibilityHidden(true)` where adjacent text already says the level (hero card, widget badge).
- The typing indicator says "Ripple is thinking".
- Large text: the hero still hides the mascot at accessibility sizes, as today.
- Reduce Motion: the ambient animation already respects it. Keep it that way.

## 6. Verification

- **Unit tests (Swift Testing, `StressMonitorTests`):**
  - `RipplePose.from(category:)` covers all 5 categories, including `.moderate → .elevated`.
  - `RippleMood.pose` covers all 8 moods.
  - Every `RipplePose` `assetName` and `headAssetName` loads with `UIImage(named:)` in the app bundle.
  - `CharacterAssetCatalog` resolves `ripple` and `ripple-hero` to `ripple-v2-base`.
  - Update `CharacterAssetResolverTests` for the removed legacy names.
- **CI:** the 4 required checks pass: Lint & Build, Build watchOS, Build Widget and Test.
- **Visual:** simulator screenshots, light and dark, in the PR under `docs/screenshots/ripple-v2/`:
  - Home at 3 levels (relaxed, elevated, severe)
  - Chat (avatar plus thinking)
  - Breathing summary
  - Mini Walk complete
  - Onboarding welcome
  - Watch home
  - One complication
  - Widgets small, medium and large

  Each image is checked by eye for clipping, the light-mode chip and legibility. Local disk is tight (about 4 GB free), so the `screenshots.yml` workflow (manual dispatch on the branch) and CI builds are preferred over local builds.
- **Landing:**
  - `npm ci && npm run build` passes.
  - Every new or changed path exists in `.vitepress/dist`.
  - The en and vi pages are checked at 390 px and 1280 px, in light and dark.

## 7. Delivery

- **One PR in `stress-coach-ios`** for all app work, on branch `feat/ripple-v2`, cut from current main. Once #85 lands, merge main into the branch (no rebase or force-push).
- **One PR in `stress-coach-ai`** for the landing and help site. It must be a separate repo, so one PR there.
- **Neither PR is merged without the owner's approval.**
  - Commits are authored by Phuong Doan, with no AI attribution.
  - No force-push to main, no admin merge, and no tests skipped.
