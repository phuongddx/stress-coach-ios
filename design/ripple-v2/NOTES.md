# Ripple v2 — handoff notes (2026-11-24)

The reference image (7220008.jpg) was used **only as a style guide**: flat chibi, a hooded onesie, blush and pastel colours. Nothing was traced or copied, and the reference file is not part of this folder. Stock licences usually forbid using a stock image as a logo or mascot, so every shape here is drawn from scratch in SVG (`_source/ripple.py`).

## Choices vs the reference (one line each)
- Ears: small, round, low otter ears instead of long pointed ones, so Ripple stays an otter.
- Hood: an otter nose and eyes on the top of the hood, so you can tell it is an otter suit even from the head alone.
- Hair: a rounded fringe swept to one side with 2 notches. It is softer, fits "calm", and does not look like the reference fringe.
- Body: a cream oval belly (the otter's chest), round paws, and shading on one side only.
- Tail: a thick tapered tail, the clearest otter cue on the full body.
- Colour: the app's green palette made pastel: suit #A8DCCF, shade #82CBBA, accent #5FBFA9, deep #206A5D.
- Kindness: the stressed states use worried brows (inner ends raised), never angry ones. Severe always comes with a comfort heart.

## Files
- `svg/<state>.svg` and `svg/<state>-head.svg`: a 512 artboard with a transparent background. The 11 states are base, relaxed, mild, elevated, high, severe, breathing, walking, celebrating, sleeping and thinking.
- `png/<state>@{1,2,3}x.png` and `png/<state>-head@{1,2,3}x.png`: 512, 1024 and 1536 px, transparent, 66 files.
- `icon/AppIcon.icon` and `icon/WatchAppIcon.icon`: Icon Composer bundles with 2 layers (face, hood) and light, dark and tinted versions. `icon/render/` holds the Default, Dark, Clear light, Clear dark, Tinted light, Tinted dark and Watch renders.
- `previews/construction-sheet.png`, `previews/light-dark-check.png`, `review/index.html`, `review/contact-sheet.png`.

## Contrast (measured)
- Hair and eyes on the face: 12.6:1. The face reads in both modes.
- Suit #A8DCCF on light #F1F1E8: **1.34:1**. The silhouette is soft on light backgrounds, as in the pastel reference. On dark #0B1411 it is 12.3:1.
- For small avatars in light mode, the teal chip (#206A5D) behind the head is the recommended treatment. The check sheet shows it.

## For engineering, after approval
- Use the head-crop PNGs for the chat avatar and widgets. The full-body states go on the status screens.
- Free-floating marks (Zzz, motion lines) use #3FA48E, so they read on both backgrounds.
