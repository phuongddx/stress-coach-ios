#!/usr/bin/env python3
"""Regenerate the StressMonitor app icon PNG fallbacks from the Ripple v2 master.

iOS 26 / watchOS 26 use the Icon Composer bundles (`AppIcon.icon`) next to each
target's asset catalog. The `AppIcon.appiconset` PNGs are the fallback for
iOS 18 / watchOS 11. This script resizes the single Ripple v2 light master
(`design/ripple-v2/icon/ripple-light-1024.png`) into every PNG listed in the
three appiconsets' Contents.json:

- iPhone app:  StressMonitor/StressMonitor/Assets.xcassets/AppIcon.appiconset
- Watch app:   StressMonitor/StressMonitorWatch Watch App/Assets.xcassets/AppIcon.appiconset
- Widget:      StressMonitor/StressMonitorWidget/Assets.xcassets/AppIcon.appiconset

File names and sizes come from each Contents.json, which is not modified.
The output is opaque RGB (no alpha), as the App Store requires. The watch uses
the same square full-bleed master; watchOS applies the circular mask.
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "design/ripple-v2/icon/ripple-light-1024.png"
ICONSETS = [
    ROOT / "StressMonitor/StressMonitor/Assets.xcassets/AppIcon.appiconset",
    ROOT / "StressMonitor/StressMonitorWatch Watch App/Assets.xcassets/AppIcon.appiconset",
    ROOT / "StressMonitor/StressMonitorWidget/Assets.xcassets/AppIcon.appiconset",
]


def pixel_size(entry: dict) -> int:
    """Pixel edge for a Contents.json image entry ("60x60" @ "3x" -> 180)."""
    points = float(entry["size"].split("x")[0])
    scale = int(entry.get("scale", "1x").rstrip("x"))
    return round(points * scale)


def load_master() -> tuple[Image.Image, bytes | None]:
    with Image.open(MASTER) as img:
        icc = img.info.get("icc_profile")
        rgb = img.convert("RGB")  # drop any alpha: App Store icons must be opaque
    if rgb.size != (1024, 1024):
        raise SystemExit(f"{MASTER} must be 1024x1024, got {rgb.size}")
    return rgb, icc


def generate_iconset(iconset: Path, master: Image.Image, icc: bytes | None) -> list[tuple[str, int]]:
    contents = json.loads((iconset / "Contents.json").read_text())
    written: list[tuple[str, int]] = []
    for entry in contents["images"]:
        filename = entry.get("filename")
        if not filename:
            continue
        px = pixel_size(entry)
        out = master if px == master.width else master.resize((px, px), Image.Resampling.LANCZOS)
        save_kwargs = {"optimize": True}
        if icc:
            save_kwargs["icc_profile"] = icc
        out.save(iconset / filename, "PNG", **save_kwargs)
        written.append((filename, px))
    return written


def main() -> None:
    master, icc = load_master()
    print(f"Master: {MASTER.relative_to(ROOT)}")
    for iconset in ICONSETS:
        written = generate_iconset(iconset, master, icc)
        sizes = ", ".join(str(px) for px in sorted({px for _, px in written}))
        print(f"- {iconset.relative_to(ROOT)}: {len(written)} PNG files ({sizes})")


if __name__ == "__main__":
    main()
