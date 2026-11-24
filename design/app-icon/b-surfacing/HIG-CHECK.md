# App icon B · Surfacing: Apple HIG check

Checked against the [Apple HIG app icons page](https://developer.apple.com/design/human-interface-guidelines/app-icons), latest change October 28, 2026. Checked on 2026-11-24.

| # | HIG point | B before | B after | HIG section |
|---|---|---|---|---|
| 1 | Use the layered Icon Composer format (one background, one or more foreground layers) | ❌ A flat PNG/SVG. The system would split it into 2 layers on its own. | ✅ `AppIcon.icon` has 2 groups (Otter, Water). The background is an Icon Composer gradient fill. | [Icon formats](https://developer.apple.com/design/human-interface-guidelines/app-icons#Icon-formats) · [Layer design](https://developer.apple.com/design/human-interface-guidelines/app-icons#Layer-design) |
| 2 | Clear edges on foreground layers, vector art preferred | ✅ | ✅ SVG layers with hard edges | [Layer design](https://developer.apple.com/design/human-interface-guidelines/app-icons#Layer-design) |
| 3 | A background that stands out and puts the foreground first | ❌ 52% of the icon is near-white (L>0.80), so it blends into white neighbors (Calendar, Photos, Notes, Health). | ✅ 1.3% near-white. Sage sky with a deep-green #206A5D water band. | [Layer design](https://developer.apple.com/design/human-interface-guidelines/app-icons#Layer-design) |
| 4 | Default, dark, clear and tinted appearances | ❌ Flat light, dark and gray images only. No clear. | ✅ Light, dark and tinted (mono) art per layer. The system makes clear. All 6 looks were rendered with Apple's `ictool`. | [Appearances](https://developer.apple.com/design/human-interface-guidelines/app-icons#Appearances) |
| 5 | Same core features in every variant, dark built from light | ✅ | ✅ | [Appearances](https://developer.apple.com/design/human-interface-guidelines/app-icons#Appearances) |
| 6 | No text | ✅ | ✅ | [Design](https://developer.apple.com/design/human-interface-guidelines/app-icons#Design) |
| 7 | Illustration, not photo | ✅ | ✅ | [Design](https://developer.apple.com/design/human-interface-guidelines/app-icons#Design) |
| 8 | Square, unmasked layers, no rounded corners in the art | ✅ | ✅ | [Icon shape](https://developer.apple.com/design/human-interface-guidelines/app-icons#Icon-shape) |
| 9 | No baked-in specular highlights, drop shadows, bevels, blurs or glows | ✅ | ✅ The system adds Liquid Glass. | [Visual effects](https://developer.apple.com/design/human-interface-guidelines/app-icons#Visual-effects) |
| 10 | Keep it simple: few shapes, no very thin lines | ❌ Whiskers (8 px) and freckle dots drop below 0.5 px at 40 px. Ripple strokes are 16–20 px. | ✅ Whiskers and freckles removed. Smile is 18 px, ripples 24–30 px, eyes larger. | [Design](https://developer.apple.com/design/human-interface-guidelines/app-icons#Design) |
| 11 | Still reads small: 40 px, 29 pt Settings (58/87 px) | ❌ Detail turns to noise and the ripples disappear. | ✅ Face, eyes, nose and water line still read at 40 px. See `previews/before-after-light.png`. | [Design](https://developer.apple.com/design/human-interface-guidelines/app-icons#Design) · [Specifications](https://developer.apple.com/design/human-interface-guidelines/app-icons#Specifications) |
| 12 | iOS 1024×1024 master | ✅ | ✅ | [Specifications](https://developer.apple.com/design/human-interface-guidelines/app-icons#Specifications) |
| 13 | watchOS: square layers, circular mask, 1088×1088 canvas, content centered | ❌ No Watch art. The Watch still used the old icon. | ✅ Watch `AppIcon.icon` (circles/watchOS) rendered at 1088. Ears and ripples sit inside the circle. | [Icon shape](https://developer.apple.com/design/human-interface-guidelines/app-icons#Icon-shape) · [Specifications](https://developer.apple.com/design/human-interface-guidelines/app-icons#Specifications) |
| 14 | watchOS: no black background | ✅ | ✅ | [watchOS](https://developer.apple.com/design/human-interface-guidelines/app-icons#watchOS) |
| 15 | Same design on every platform | ⚠️ iOS only | ✅ iOS and Watch share the same layers | [Design](https://developer.apple.com/design/human-interface-guidelines/app-icons#Design) |
| 16 | Opaque full-bleed bitmaps (iOS 18 / watchOS 11 fallback) | ✅ | ✅ 1024 PNGs, no alpha channel | [Layer design](https://developer.apple.com/design/human-interface-guidelines/app-icons#Layer-design) |

Notes
- The HIG page lists no point sizes (40 px, 29 pt) and no numeric watchOS safe area. It says the system scales down from the master, and it points to the grids in Apple Design Resources. Small sizes were checked by rendering at 40/58/87 px. Watch centering was checked against the circle mask, not against Apple's template grid.
- The current HIG has no general "no transparency" rule. Icon Composer layers are transparent by design. Only the background and the bitmap fallbacks must be opaque.
