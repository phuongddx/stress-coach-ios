# App preview — 1.1.0, iPhone 6.9" (IPHONE_67), en-US

The video itself is **not in git** (9.1 MB binary). It lives in App Store Connect and
can be rebuilt from a new take with the scripts in `scripts/previews/`.

| | |
|---|---|
| ASC preview set | `5d61abda-cc2f-4b90-aa7f-19e17ff0e751` (IPHONE_67, version 1.1.0, en-US localization `7802a3a7-756b-4176-a2e4-eed8e0ad2736`) |
| ASC preview | `87800019-4075-8eba-811b-8f64c99b6f7f`, `appstore-preview-886x1920.mp4`, 9,115,830 B, state `COMPLETE` |
| Poster frame | `00:00:02:00` |
| Uploaded | 2026-11-24 |

## Storyboard (22 s, real app footage, no device frame, no captions)

| Time | Beat |
|---|---|
| 0–3 s | Home: today's stress score ring (demo data shows 27 · Mild) |
| 3–7 s | Action tab: Ripple's suggestion card (zoom 1.25×) |
| 7–9 s | "Start box breathing" → breathing intro |
| 9–16 s | Breathing session running (zoom 1.25×) |
| 16–18 s | "End early" → back to intro |
| 18–22 s | Home tab |

## Recording setup

- Xcode 27.1, Device Hub, simulator "ASC Preview 17PM" (iPhone 17 Pro Max, iOS 26.4).
- App launched in demo mode:
  `-demo-mode -hasCompletedOnboarding YES -didShowOnboardingPaywall YES -preview-recording`
- `-preview-recording` comes from a **local-only patch that is never committed**: it hides
  the "Demo" badge and the server status card so the footage shows the product only.
- Taps were scripted with AXe (`scripts/previews/drive-take.sh`). AXe 2.1 taps only reach
  SwiftUI controls with `--input-mode selected`; each tap takes about 3 s.
- OpenScreen recorded the Device Hub window (1528×2160, variable frame rate). The phone
  screen sits at `846x1840+341+167` inside that take.

## Export

```sh
scripts/previews/build-appstore-preview.sh <take.mp4> 8.4 22 appstore-preview-886x1920.mp4
```

1. Trim `-ss 8.4 -t 22` (drops launch and the end of the take).
2. Crop to the phone screen: `crop=846:1840:341:167`.
3. Square the rounded screen corners: a mask from one frame, filled with the app's own
   background (`#EEEFE5` top half, `#E7E8DE` bottom half). A very faint arc can remain at
   the corners.
4. `scale=886:1928:flags=lanczos,crop=886:1920:0:4`, `fps=30`, `yuv420p`.
5. libx264 High, level 4.0, 8 Mb/s (max 10), plus a silent stereo AAC track (128 kb/s,
   `anullsrc`), `+faststart`.

The two zooms in the storyboard were added in OpenScreen's editor (project
`proj_f7c6ddab-f61a-49ae-b75d-d5d1dc9b0e64`) and are not reproduced by the script; the
uploaded file was cut from the raw take with the same ffmpeg chain. Re-running the script
on the same take gives 9,110,951 B, PSNR 31.5 dB against the uploaded file (mask details differ).

### ffprobe of the uploaded file

```
codec_name=h264 profile=High width=886 height=1920 pix_fmt=yuv420p
r_frame_rate=30/1 avg_frame_rate=30/1
codec_name=aac profile=LC sample_rate=44100 channels=2
duration=22.000000 size=9115830 bit_rate=3314847
```

### Upload

```sh
L=7802a3a7-756b-4176-a2e4-eed8e0ad2736
asc video-previews upload --version-localization $L \
  --path appstore-preview-886x1920.mp4 --device-type IPHONE_67 --time-code 00:00:02:00
asc video-previews list --version-localization $L --output table
```

Read back with `list` until the preview state is `COMPLETE`.

## Landing page cut

The same take, screen-only, feeds the landing hero (phuongddx/stress-coach-ai PR #2):
720×1566, MP4 (H.264, CRF 22, 1.1 MB) and WebM (VP9, CRF 33, 0.8 MB), WebP poster (39 KB).
The page draws the bezel in CSS; under `prefers-reduced-motion` it shows the poster only.
