"""Make readable JPEG previews from actual Flutter-rendered PNG frames.

No drawing, mockups, interpolated frames, or sample data are added here.
Keep the original lossless PNGs alongside these size-limited previews.
"""
from pathlib import Path

from PIL import Image

for source in sorted(Path("build/ui-screenshots").glob("sand-flow-desktop-*.png")):
    with Image.open(source) as frame:
        assert frame.size == (1440, 960), source
        frame.convert("RGB").save(
            source.with_name(source.stem + "-preview.jpg"),
            quality=88,
            optimize=True,
        )
