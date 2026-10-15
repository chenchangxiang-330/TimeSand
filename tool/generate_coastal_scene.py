"""Generate TimeSand's original, deterministic coastal environment artwork.

Run in CI with Pillow 11.3.0. No downloaded imagery, UI, text, paths, or user data
are incorporated into the artwork. The application only bundles the final PNG.
"""

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

WIDTH, HEIGHT = 1600, 1200
HORIZON = 730
SUN_X, SUN_Y = 1065, 565
RNG = random.Random(24015)


def noise_field(columns, rows, seed):
    """Bicubic value noise: broad natural detail without a repeated wave motif."""
    rng = random.Random(seed)
    grid = Image.new("L", (columns, rows))
    grid.putdata([rng.randrange(256) for _ in range(columns * rows)])
    return grid.resize((WIDTH, HEIGHT), Image.Resampling.BICUBIC)


def mix(a, b, amount):
    return tuple(a[i] + (b[i] - a[i]) * amount for i in range(3))


def smoothstep(low, high, value):
    t = max(0.0, min(1.0, (value - low) / (high - low)))
    return t * t * (3.0 - 2.0 * t)


def gradient(y, stops):
    for (start, first), (end, second) in zip(stops, stops[1:]):
        if y <= end:
            return mix(first, second, (y - start) / (end - start))
    return stops[-1][1]


# Broad, irregular cloud banks rather than rows of translucent ellipses.
cloud_large = noise_field(8, 8, 41).load()
cloud_medium = noise_field(22, 18, 85).load()
cloud_small = noise_field(66, 50, 144).load()
cloud_detail = noise_field(150, 110, 233).load()
water_broad = noise_field(13, 63, 610).load()
water_fine = noise_field(63, 265, 987).load()

sky_stops = [
    (0, (128, 174, 211)),
    (270, (158, 193, 219)),
    (530, (205, 218, 224)),
    (665, (241, 224, 202)),
    (HORIZON, (238, 230, 216)),
]
sea_stops = [
    (HORIZON, (148, 184, 198)),
    (815, (121, 170, 192)),
    (1000, (88, 150, 179)),
    (HEIGHT, (62, 127, 158)),
]

image = Image.new("RGB", (WIDTH, HEIGHT))
pixels = []
for y in range(HEIGHT):
    if y < HORIZON:
        base = gradient(y, sky_stops)
        # The upper and lower cloud systems overlap softly at different slopes.
        for x in range(WIDTH):
            large = cloud_large[x, y] / 255.0
            medium = cloud_medium[x, y] / 255.0
            small = cloud_small[x, y] / 255.0
            detail = cloud_detail[x, y] / 255.0
            field = large * 0.42 + medium * 0.34 + small * 0.18 + detail * 0.06
            upper_bank = math.exp(-((y - (210 + x * 0.11)) / 160) ** 2)
            lower_bank = math.exp(-((y - (565 - x * 0.045)) / 90) ** 2)
            envelope = max(upper_bank * 0.94, lower_bank * 0.82)
            cloud = smoothstep(0.42, 0.69, field + envelope * 0.13)
            cloud *= envelope * (1.0 - smoothstep(665, HORIZON, y))

            # Sunlight is a diffuse warm opening in the atmosphere, not a disc.
            sun = math.exp(
                -((x - SUN_X) / 420) ** 2 - ((y - SUN_Y) / 290) ** 2
            )
            color = mix(base, (255, 241, 214), sun * 0.46)

            # Compare nearby cloud density to light the upper, sunward edges.
            above = cloud_medium[x, max(0, y - 24)] / 255.0
            upward_edge = max(0.0, medium - above)
            silver = min(1.0, 0.30 + small * 0.34 + upward_edge * 1.6)
            shade = mix((151, 176, 196), (253, 250, 239), silver)
            shade = mix(shade, (255, 241, 217), sun * 0.32)
            color = mix(color, shade, cloud * 0.83)
            haze = smoothstep(620, HORIZON, y) * 0.20
            color = mix(color, (249, 232, 208), haze)
            grain = (detail - 0.5) * 0.6
            pixels.append(tuple(round(max(0, min(255, c + grain))) for c in color))
    else:
        base = gradient(y, sea_stops)
        depth = (y - HORIZON) / (HEIGHT - HORIZON)
        for x in range(WIDTH):
            broad = water_broad[x, y] / 255.0
            fine = water_fine[x, y] / 255.0
            texture = (broad - 0.5) * 11 + (fine - 0.5) * 4 * depth
            color = tuple(c + texture for c in base)
            # An irregular, broad reflection follows perspective into the bay.
            axis = SUN_X + (broad - 0.5) * (28 + depth * 90)
            reflection = math.exp(-((x - axis) / (75 + depth * 285)) ** 2)
            broken_light = 0.24 + broad * 0.34 + fine * 0.10
            reflection *= broken_light * (0.76 - depth * 0.24)
            color = mix(color, (246, 228, 194), reflection)
            atmospheric = math.exp(-depth * 19) * 0.23
            color = mix(color, (226, 226, 211), atmospheric)
            pixels.append(tuple(round(max(0, min(255, c))) for c in color))
image.putdata(pixels)
image = image.convert("RGBA")


def smooth_profile(points):
    """Sample a Catmull-Rom coastline to avoid straight triangular mountain edges."""
    extended = [points[0], *points, points[-1]]
    sampled = []
    for i in range(1, len(extended) - 2):
        p0, p1, p2, p3 = extended[i - 1 : i + 3]
        count = max(12, round((p2[0] - p1[0]) / 3))
        for step in range(count):
            t = step / count
            t2, t3 = t * t, t * t * t
            value = []
            for coordinate in (0, 1):
                a, b, c, d = p0[coordinate], p1[coordinate], p2[coordinate], p3[coordinate]
                value.append(
                    0.5
                    * (
                        2 * b
                        + (-a + c) * t
                        + (2 * a - 5 * b + 4 * c - d) * t2
                        + (-a + 3 * b - 3 * c + d) * t3
                    )
                )
            sampled.append(tuple(value))
    return [*sampled, points[-1]]


def coast(points, tint, softness):
    layer = Image.new("RGBA", (WIDTH, HEIGHT))
    shape = smooth_profile(points)
    base = max(point[1] for point in points) + 10
    shape.extend([(points[-1][0], base), (points[0][0], base)])
    ImageDraw.Draw(layer).polygon(shape, fill=tint)
    return layer.filter(ImageFilter.GaussianBlur(softness))


# Asymmetric, low coastal headlands: the open center stays quiet behind live UI.
image = Image.alpha_composite(
    image,
    coast(
        [(-30, 662), (55, 651), (145, 665), (215, 688), (315, 697),
         (410, 710), (530, 720), (680, 728)],
        (137, 166, 177, 120),
        3.5,
    ),
)
image = Image.alpha_composite(
    image,
    coast(
        [(1110, 731), (1220, 727), (1305, 715), (1390, 706),
         (1470, 677), (1540, 667), (1630, 679)],
        (143, 168, 176, 98),
        4.5,
    ),
)
image = Image.alpha_composite(
    image,
    coast(
        [(-30, 710), (55, 695), (130, 707), (190, 716), (260, 718),
         (355, 732), (465, 741)],
        (103, 143, 163, 135),
        2.4,
    ),
)

# Long, gentle light ribbons. Sparse and softly blurred, never a regular grid.
light = Image.new("RGBA", (WIDTH, HEIGHT))
light_draw = ImageDraw.Draw(light)
for _ in range(95):
    depth = RNG.random() ** 0.72
    y = HORIZON + 9 + depth * (HEIGHT - HORIZON - 14)
    x = RNG.gauss(SUN_X, 30 + depth * 135)
    width = RNG.uniform(8, 34) * (0.35 + depth)
    height = RNG.uniform(0.5, 1.1) * (0.6 + depth)
    light_draw.ellipse(
        (x - width, y - height, x + width, y + height),
        fill=(255, 244, 222, RNG.randint(13, 34)),
    )
image = Image.alpha_composite(image, light.filter(ImageFilter.GaussianBlur(1.2)))

target = Path("assets/scenes/coastal-light.png")
target.parent.mkdir(parents=True, exist_ok=True)
image.convert("RGB").save(target, optimize=True)
print("Generated original environment asset:", target)
