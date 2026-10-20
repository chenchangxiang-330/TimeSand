#!/usr/bin/env python3
"""Download the two approved scene candidates and make a review-only preview.

Run on a cloud runner with Pillow 11.3.0. Original files are preserved byte for
byte; only the separate side-by-side preview is resized to fit its panels.
Nothing is copied into Flutter's assets directory.
"""

from __future__ import annotations

import hashlib
import io
import json
from pathlib import Path
import time
import urllib.error
import urllib.parse
import urllib.request

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIRECTORY = ROOT / "tool" / "scene_sources"
PREVIEW_PATH = ROOT / "docs" / "ui" / "scene-candidates.jpg"
MAX_DOWNLOAD_BYTES = 25 * 1024 * 1024
Image.MAX_IMAGE_PIXELS = 50_000_000

CANDIDATES = (
    {
        "filename": "Sunrise_Over_the_Ocean.jpg",
        "download_url": "https://upload.wikimedia.org/wikipedia/commons/4/4d/Sunrise_Over_the_Ocean.jpg",
        "source_page": "https://commons.wikimedia.org/wiki/File:Sunrise_Over_the_Ocean.jpg",
        "author": "Hommie09",
        "license": "CC0-1.0",
        "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
    },
    {
        "filename": "Sunrise_over_ocean_seen_from_coast.jpg",
        "download_url": "https://upload.wikimedia.org/wikipedia/commons/d/d9/Sunrise_over_ocean_seen_from_coast.jpg",
        "source_page": "https://commons.wikimedia.org/wiki/File:Sunrise_over_ocean_seen_from_coast.jpg",
        "author": "Steve Hillebrand / USFWS",
        "license": "Public domain (US federal government work)",
        "license_url": "https://commons.wikimedia.org/wiki/Template:PD-USGov-FWS",
    },
)


def download_image(url: str) -> bytes:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "TimeSand-scene-review/1.0 (https://github.com/chenchangxiang-330/TimeSand)",
            "Accept": "image/jpeg",
        },
    )
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                location = urllib.parse.urlparse(response.geturl())
                if location.scheme != "https" or location.hostname != "upload.wikimedia.org":
                    raise RuntimeError("Image download redirected outside the approved HTTPS host.")
                data = response.read(MAX_DOWNLOAD_BYTES + 1)
                if not data or len(data) > MAX_DOWNLOAD_BYTES:
                    raise RuntimeError("Image is empty or exceeds the 25 MiB download limit.")
                return data
        except (urllib.error.URLError, TimeoutError) as error:
            if attempt == 2:
                raise RuntimeError(f"Approved image download failed: {url}: {error}") from error
            print(f"Download attempt {attempt + 1} failed; retrying the same approved URL.", flush=True)
            time.sleep(2 * (attempt + 1))
    raise AssertionError("Download retry loop did not complete.")


def review_font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", size)


def main() -> None:
    loaded = []
    for candidate in CANDIDATES:
        data = download_image(candidate["download_url"])
        with Image.open(io.BytesIO(data)) as source:
            image_format = source.format
            if image_format not in {"JPEG", "PNG", "WEBP", "MPO"}:
                raise RuntimeError(f"{candidate['filename']} has unsupported image format {image_format}.")
            source.verify()
        with Image.open(io.BytesIO(data)) as source:
            original_size = source.size
            displayed = ImageOps.exif_transpose(source).convert("RGB")
            displayed.load()
        if min(original_size) < 200:
            raise RuntimeError(f"{candidate['filename']} is unexpectedly small.")
        record = {
            **candidate,
            "image_format": image_format,
            "sha256": hashlib.sha256(data).hexdigest(),
            "byte_length": len(data),
            "width": original_size[0],
            "height": original_size[1],
        }
        loaded.append((record, data, displayed))
        print(
            f"Validated {record['filename']}: {record['image_format']}, {record['width']}x{record['height']}, "
            f"{record['byte_length']} bytes, sha256 {record['sha256']}",
            flush=True,
        )

    # Both downloads must validate before any repository output is written.
    SOURCE_DIRECTORY.mkdir(parents=True, exist_ok=True)
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    margin, panel_width, image_height, footer_height = 24, 900, 620, 108
    canvas = Image.new("RGB", (margin * 3 + panel_width * 2, margin * 2 + image_height + footer_height), "#edf1f3")
    draw = ImageDraw.Draw(canvas)
    title_font, label_font = review_font(23), review_font(18)
    for index, (record, data, displayed) in enumerate(loaded):
        (SOURCE_DIRECTORY / record["filename"]).write_bytes(data)
        left = margin + index * (panel_width + margin)
        draw.rectangle((left, margin, left + panel_width, margin + image_height), fill="#dce3e8")
        fitted = ImageOps.contain(displayed, (panel_width, image_height), Image.Resampling.LANCZOS)
        canvas.paste(
            fitted,
            (left + (panel_width - fitted.width) // 2, margin + (image_height - fitted.height) // 2),
        )
        text_top = margin + image_height + 12
        draw.text((left, text_top), record["filename"], fill="#1c2c36", font=title_font)
        draw.text((left, text_top + 35), record["author"], fill="#344c5a", font=label_font)
        draw.text((left, text_top + 64), record["license"], fill="#344c5a", font=label_font)
    canvas.save(PREVIEW_PATH, format="JPEG", quality=92, subsampling=0)
    manifest = {
        "manifest_version": 1,
        "purpose": "Review-only environmental photo candidates; not included in Flutter assets.",
        "preview": "docs/ui/scene-candidates.jpg",
        "preview_processing": "EXIF orientation applied; proportional contain resize; labels added; no crop or retouch.",
        "original_files": "Original download bytes preserved without image processing.",
        "candidates": [record for record, _, _ in loaded],
    }
    (SOURCE_DIRECTORY / "manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print("Wrote docs/ui/scene-candidates.jpg and tool/scene_sources/manifest.json.", flush=True)


if __name__ == "__main__":
    main()
