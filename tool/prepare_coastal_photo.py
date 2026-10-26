#!/usr/bin/env python3
"""Build the bundled coastal scene from a pinned CC0 photo, entirely offline.

The original is preserved in tool/scene_sources. Pillow 11.3.0 is the only
authoring dependency; neither this script nor its source photo ships in the app.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageEnhance, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tool/scene_sources/Sunrise_Over_the_Ocean.jpg"
OUTPUT = ROOT / "assets/scenes/coastal-sunrise.jpg"
EXPECTED_SHA256 = "c5dffbd473dc4f523dfeeaecc365a43dc0dc4429eb6a4d3feabe2ee7506b7c46"

def main():
    digest = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    if digest != EXPECTED_SHA256:
        raise RuntimeError("Source photograph differs from the reviewed CC0 original.")
    with Image.open(SOURCE) as original:
        # MPO contains multiple frames. Only the reviewed primary frame is used.
        original.seek(0)
        photo = ImageOps.exif_transpose(original).convert("RGB")
    photo.thumbnail((1920, 1440), Image.Resampling.LANCZOS)
    photo = photo.point([round(255 * (value / 255) ** 0.68) for value in range(256)] * 3)
    photo = ImageEnhance.Color(photo).enhance(0.58)
    red, green, blue = photo.split()
    photo = Image.merge("RGB", (
        red.point(lambda v: round(min(255, v * 0.96 + 4))),
        green.point(lambda v: round(min(255, v * 0.99 + 10))),
        blue.point(lambda v: round(min(255, v * 1.06 + 18))),
    ))
    gradient = Image.new("RGB", (1, photo.height))
    stops = [(0.0, (139, 184, 222)), (0.54, (251, 228, 199)), (1.0, (66, 143, 181))]
    for y in range(photo.height):
        t = y / (photo.height - 1)
        left, right = (stops[0], stops[1]) if t < stops[1][0] else (stops[1], stops[2])
        f = (t - left[0]) / (right[0] - left[0])
        gradient.putpixel((0, y), tuple(round(a + (b - a) * f) for a, b in zip(left[1], right[1])))
    photo = Image.blend(photo, gradient.resize(photo.size), 0.24)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    # Conversion strips EXIF/GPS; the shipped file contains environment pixels only.
    photo.save(OUTPUT, "JPEG", quality=91, optimize=True, progressive=True)
    manifest = {
        "asset": "coastal-sunrise.jpg",
        "title": "Sunrise Over the Ocean",
        "author": "Hommie09",
        "source_page": "https://commons.wikimedia.org/wiki/File:Sunrise_Over_the_Ocean.jpg",
        "original_url": "https://upload.wikimedia.org/wikipedia/commons/4/4d/Sunrise_Over_the_Ocean.jpg",
        "license": "CC0-1.0",
        "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
        "original_sha256": digest,
        "processing": "Primary MPO frame; EXIF orientation; 1920px resize; lifted shadows; reduced saturation; cool-white balance; subtle sky/warm-horizon/blue-water tint; metadata stripped.",
        "asset_sha256": hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
        "size": list(photo.size),
        "pillow_version": "11.3.0"
    }
    (OUTPUT.parent / "photo-source.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Prepared {OUTPUT.relative_to(ROOT)}: {photo.width}x{photo.height}, sha256 {manifest['asset_sha256']}")

if __name__ == "__main__":
    main()
