# Ripple v2 rollout: implementation plan

- **Spec:** [2026-11-24-ripple-v2-rollout-design.md](../specs/2026-11-24-ripple-v2-rollout-design.md)
- **Delivery:**
  - One branch `feat/ripple-v2` gives one PR in `stress-coach-ios`.
  - One branch `feat/ripple-v2` gives one PR in `stress-coach-ai`.
- **Art:** `ART=/Users/ddphuong/Projects/next-labs/stress-ai/ui-v2-design/ripple-v2`. Read it only; never edit it.

Paths: `SM=StressMonitor/StressMonitor`, `WATCH="StressMonitor/StressMonitorWatch Watch App"`, `WIDGET=StressMonitor/StressMonitorWidget`, `TESTS=StressMonitor/StressMonitorTests`.

## Throughput checkpoint

- **Blocking first steps:** Tasks 0–2.
  - Branch, spec and plan commit.
  - Assets in all three catalogs.
  - The `RipplePose` model and its tests.
  - Every later task depends on asset names and the model.
- **Independent workstreams after Task 2** (disjoint files, safe to fan out to parallel workers):
  - **A:** iPhone views (Task 3).
  - **B:** Watch (Task 4).
  - **C:** Widget (Task 5).
  - **D:** App icon (Task 6).
  - **E:** Landing repo (Task 8). This is a different repo; brand files can start right away, and screenshots wait for Task 7.
- **Shared mutable state:**
  - The single git branch: workers edit disjoint folders and the coordinator commits per task, one at a time.
  - `project.pbxproj`: it should need no edit (synchronized groups). If a worker thinks it does, the coordinator makes that edit alone.
  - `CharacterAssetResolverTests.swift`: owned by Task 2 only.
- **Smallest safe decomposition:** 1 coordinator plus up to 4 parallel workers (A–D). E runs alongside. Every task ends with its own commit, verified by a build of the affected scheme. CI does the full run.

## Task 0: Branch and docs

1. In a clean clone or worktree of `stress-coach-ios` (not `/Users/ddphuong/Projects/next-labs/stress-ai/ios-stress-app`), branch `feat/ripple-v2` from `origin/main`.
2. Copy this spec and plan into `docs/superpowers/specs/` and `docs/superpowers/plans/`.
3. Commit: `docs(ripple-v2): spec and implementation plan`.

## Task 1: Assets (blocking)

1. Copy `$ART/svg/*.svg`, `$ART/NOTES.md` and `$ART/_source/ripple.py` into `design/ripple-v2/`. Do not copy the PNGs.
2. iPhone: `$SM/Assets.xcassets/RippleV2/` gets 22 imagesets named `ripple-v2-<state>` and `ripple-v2-<state>-head`.
   - Each set has the SVG and a `Contents.json` with `idiom: universal` and `properties.preserves-vector-representation: true`.
   - Copy the format from `Characters/ripple.imageset/Contents.json`.
   - Add a folder-level `Contents.json` with `"provides-namespace": false`, so names stay flat.
3. Watch: `$WATCH/Assets.xcassets/RippleV2/` gets the heads for relaxed, mild, elevated, high, severe, base and sleeping.
4. Widget: `$WIDGET/Assets.xcassets/RippleV2/` gets the heads for relaxed, mild, elevated, high, severe and base.
5. Run the simulator and check that every SVG renders correctly, especially the `clipPath` hood shapes.
   - Any state that renders wrong switches to PNGs (resized from `$ART/png/<state>@1x.png` to the 1x/2x/3x sizes of its largest use).
   - Record any switch in the PR.
6. Commit: `feat(ripple-v2): add Ripple v2 artwork to iPhone, Watch and widget catalogs`.

## Task 2: Pose model (blocking)

1. Add `$SM/Components/Character/RipplePose.swift` per spec §4.1. It contains:
   - The enum.
   - `from(category:)` as a `switch`, with no score bands.
   - `assetName` and `headAssetName`.
   - `accessibilityLabel`.
2. Add `var pose: RipplePose` to `RippleMood` (`$SM/Components/Character/RippleMood.swift`), using the table in spec §4.1.
3. `CharacterAssetCatalog` (`$SM/Theme/CharacterAssetCatalog.swift`): map `ripple` and `ripple-hero` to `ripple-v2-base`.
4. `StressBuddyIllustration`:
   - Add `pose: RipplePose? = nil` and `crop: .full | .head` (default `.full`).
   - When the character is ripple, render `Image(resolvedPose.assetName or headAssetName).resizable().scaledToFit()`. `resolvedPose` is `pose ?? mood.pose`.
   - Keep `.characterAnimation(for: mood)`.
   - Add a `lightChip: Bool` option that draws a `#206A5D` circle behind the head in light mode only. Use a V2 token if one exists for `#206A5D`; otherwise add `Color.V2.rippleChip` with light and dark values.
5. Tests in `$TESTS/RipplePoseTests.swift`, written test-first:
   - All 5 categories map to the right pose.
   - All 8 moods map to the right pose.
   - Every pose's two asset names load with `UIImage(named:)`.
   - The catalog maps `ripple` to `ripple-v2-base`.
6. Update `CharacterAssetResolverTests.swift` for the removed legacy names.
7. Commit: `feat(ripple-v2): RipplePose model and level-driven drawing`.

## Task 3 (A): iPhone surfaces

Apply the spec §4.2 table. Pass `pose:` explicitly at each call site rather than relying on the mood mapping, wherever the table names a pose.

| File | Change |
|---|---|
| `Views/Dashboard/Components/StressHeroCard.swift` | pose from `StressCategory` of the current result; no data → `.base`. Delete the `RippleMood.from(stressLevel:)` use there |
| `Views/Action/Components/RippleRecommendationCard.swift` | pose from category, head crop |
| `Views/Dashboard/Components/AIInsightCard.swift` | `.thinking`, head |
| `Views/Dashboard/Components/MoodCheckInView.swift` | map `MoodLevel` to the 5 level poses, head |
| `Views/Chat/ChatBottomSheetView.swift` | avatar `.base` head with `lightChip`; empty `.mild`; unavailable `.sleeping` |
| `Views/Chat/ChatComponents.swift` | `ChatTypingDots` gets an optional leading thinking-head (18–20 pt) and label "Ripple is thinking". Use it in the sheet and in `AgentChatView` |
| `Views/Chat/AgentChatView.swift` | empty `.mild` |
| `Views/Onboarding/OnboardingWelcomeView.swift` / `OnboardingSuccessView.swift` | `.mild` / `.celebrating` |
| `Views/Dashboard/Components/PermissionCardView.swift` | `.sleeping` |
| `Views/Breathing/BreathingSummaryView.swift` | hero `.breathing`; "Ripple note" row `.relaxed` head |
| `Views/MiniWalk/MiniWalkCompleteView.swift` | `.walking` |
| `Views/Premium/PurchaseSuccessView.swift` | `.celebrating` |
| `Views/Settings/Components/CompanionBanner.swift`, `AboutView.swift`, `WatchFacePreferencesView.swift` | `.base` |
| `Views/Characters/Components/MoodPreviewButton.swift` | for ripple, preview shows `mood.pose` |

Then:
1. Grep for `ripple_droplet_calm`, `"ripple-hero"` and `"ripple"` image names. Once nothing references them, delete `Characters/ripple.imageset`, `Characters/ripple-hero.imageset` and `ripple_droplet_calm.imageset`.
2. Build the `StressMonitor` scheme for the simulator.
3. Commit: `feat(ripple-v2): show Ripple v2 poses across iPhone screens`.

## Task 4 (B): Watch

1. Add `$WATCH/Theme/RipplePose.swift`, the watch copy of the level table, with heads only.
2. In `$WATCH/Theme/StressCharacter.swift`, `CharacterFaceView` renders `Image(pose.headAssetName)` for `.ripple`. Nil category → `.sleeping`. Keep `showsRing` and `showsHalo`.
3. Delete `RippleOtter` once unused. Keep the other creatures.
4. Complications (`Complications/ComplicationBundle.swift:89`, `Providers/RectangularComplicationProvider.swift:64`): add `.widgetAccentedRenderingMode(.fullColor)` where available.
   - Check the 22 pt and 26 pt renders in a tinted face.
   - If unreadable, use the fallback from spec §4.4 and note it.
5. Build the `StressMonitorWatch Watch App` scheme.
6. Commit: `feat(ripple-v2): Ripple v2 on Apple Watch and complications`.

## Task 5 (C): Widget

1. In `$WIDGET/WidgetStressCharacter.swift`, `WidgetCharacterFace` draws `Image(headAssetName)` for the tier's category pose. `resting` → `base`. Delete the emoji path.
2. In `$WIDGET/Views/WidgetV2Components.swift`, `WidgetCompanionBadge` uses a `#206A5D` disc in light mode. Hide the image from accessibility, since the text already says the level.
3. Small, medium and large widgets pick it up automatically. Check each in the widget gallery, in light and dark.
4. Build the `StressMonitorWidgetExtension` scheme.
5. Commit: `feat(ripple-v2): Ripple v2 heads in widgets`.

## Task 6 (D): App icon

1. Copy the icon bundles:
   - `$ART/icon/AppIcon.icon` → `$SM/AppIcon.icon`.
   - `$ART/icon/WatchAppIcon.icon` → `$WATCH/AppIcon.icon`.
   - Use PR #86 (`feat/app-icon-b-surfacing`) as the reference for how its `.icon` bundles were placed and picked up.
2. Regenerate the PNG fallbacks in all three `AppIcon.appiconset` folders from `$ART/icon/ripple-light-1024.png`, keeping the existing file names and sizes.
3. Rewrite `scripts/generate_app_icons.py` to resize from `design/ripple-v2/icon/ripple-light-1024.png`; copy that PNG there.
4. Fill in `design/ripple-v2/HIG-CHECK.md` using #86's checklist.
5. Build iOS and watch. Confirm the built `.app` contains the new icon by inspecting `Assets.car` with `assetutil --info`, or the Home Screen in the simulator.
6. Commit: `feat(ripple-v2): Ripple v2 app icon for iPhone and Apple Watch`.

## Task 7: Verify and open the app PR

1. **Push the branch and open the PR:**
   - Title: `feat: Ripple v2 mascot states and app icon`.
   - The body links the spec, lists the surface table, and lists the not-verified items.
   - Author Phuong Doan, no AI attribution.
   - No merge.
2. **Screenshots:**
   - Run `.github/workflows/screenshots.yml` by manual dispatch on `feat/ripple-v2`, with `open_pr: false`.
   - Plus manual simulator captures for what it doesn't cover: the spec §6 list, in light and dark.
   - Commit them to `docs/screenshots/ripple-v2/` and embed them in the PR body.
   - Local disk has about 4 GB free. Prefer CI and clean `DerivedData` after local builds.
3. **CI:** all 4 required checks green, with review threads resolved.
4. **Close #86** with the comment "Replaced by #<new PR>: Ripple v2 icon (owner's choice 2026-11-24)."
5. **After #85 merges:** merge `origin/main` into `feat/ripple-v2` (no force-push) and let CI rerun.

## Task 8 (E): Landing and help site, `stress-coach-ai`

Clone `phuongddx/stress-coach-ai` and branch `feat/ripple-v2`. Make every page change in both `.vitepress/home/index.html` and `.vitepress/home/vi.html`.

1. **Brand files:**
   - Generate `public/favicon.png` (64), `public/apple-touch-icon.png` (180) and `public/assets/icon.png` (256) from `ripple-light-1024.png`. Keep them RGB and the same sizes as now.
   - Make `public/share.jpg` at 1200×630 per spec §4.6.
   - Copy the heads and `base` / `thinking` full-body SVGs to `public/img/ripple/`.
2. **Alt text:** change blue → green (en and vi).
3. **`#coach` section:** add a Ripple v2 full body. Use `<img>` with `width` and `height` set and `loading="lazy"`.
4. **`#score` section:** add the 5-level strip per spec §4.6.
   - Use semantic markup (`<ul>`) with alt text in each language.
   - Wrap on mobile.
   - Respect `prefers-reduced-motion`.
5. **Help page:** rewrite `principle/stress-levels.md` and `vi/principle/stress-levels.md` to the 5 levels and ranges.
6. Delete `public/assets/brand/ripple.svg`.
7. **Screenshots, after Task 7's screenshots exist:**
   - Replace `public/img/v2/*.webp`, at the same names and pixel sizes.
   - Convert with `cwebp`, or with `sips` and then `cwebp`.
8. **Verify:**
   - `npm ci && npm run build`.
   - Every referenced path exists in `.vitepress/dist`.
   - Check en and vi at 390 px and 1280 px, in light and dark, with screenshots in the PR.
9. **Open the PR** titled `feat: Ripple v2 on the landing page and stress-level guide`.
   - Link the app PR.
   - Do not merge. A merge to main deploys to Pages.

## Done when

- **App PR:**
  - The app PR is open with green required checks and the screenshots attached.
  - #86 is closed.
- **Landing PR:**
  - The landing PR is open with build output verified and screenshots attached.
- **Both:**
  - Both are reported with links, a list of what was checked by eye, and what was not verified (for example, a real device or the watch on the wrist).
