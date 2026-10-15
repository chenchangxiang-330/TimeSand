"""Original deterministic environment artwork for TimeSand; no UI or user data.
Run in CI: python tool/generate_coastal_scene.py (Pillow 11.3.0).
"""
import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

random.seed(24015)
W, H = 1600, 1200
horizon = 720
image = Image.new("RGB", (W, H))
draw = ImageDraw.Draw(image)
stops = [(0, (110, 158, 203)), (430, (181, 206, 222)),
         (660, (249, 221, 191)), (720, (243, 224, 200)),
         (850, (86, 156, 185)), (1200, (30, 101, 145))]

for y in range(H):
    for (a, c1), (b, c2) in zip(stops, stops[1:]):
        if a <= y <= b:
            t = (y - a) / (b - a)
            color = tuple(round(c1[i] * (1-t) + c2[i] * t) for i in range(3))
            draw.line((0, y, W, y), fill=color)
            break

# Warm light behind the distant coast, with broad blue sky for live widgets.
glow = Image.new("RGBA", (W, H))
g = ImageDraw.Draw(glow)
for radius in range(420, 0, -8):
    alpha = round(1.4 * (1-radius/420))
    g.ellipse((900-radius, 620-radius*.7, 900+radius, 620+radius*.7),
              fill=(255, 249, 224, alpha))
image = Image.alpha_composite(image.convert("RGBA"), glow.filter(ImageFilter.GaussianBlur(28)))

# Layered soft clouds, avoiding hard vector edges.
for cy, density, spread in [(185, 18, 280), (415, 24, 330), (590, 35, 220)]:
    cloud = Image.new("RGBA", (W, H))
    c = ImageDraw.Draw(cloud)
    for _ in range(density):
        x = random.uniform(-120, W+120)
        y = cy + random.gauss(0, spread*.16)
        rx = random.uniform(50, 160)
        ry = rx * random.uniform(.16, .38)
        c.ellipse((x-rx, y-ry, x+rx, y+ry), fill=(255, 242, 224, random.randint(40, 120)))
        c.ellipse((x-rx*.8, y-ry*.9, x+rx*.9, y+ry*.15), fill=(255, 253, 242, random.randint(65, 150)))
    image = Image.alpha_composite(image, cloud.filter(ImageFilter.GaussianBlur(19)))

# Hazy silhouettes leave the center open; the horizon is environmental only.
for side, base, tint in [(0, 705, (117, 151, 166, 105)), (1, 710, (114, 146, 159, 90)),
                         (0, 740, (93, 133, 150, 135)), (1, 750, (85, 128, 145, 120))]:
    mountains = Image.new("RGBA", (W, H))
    m = ImageDraw.Draw(mountains)
    points = [(0, base), (0, base-130), (60, base-180), (120, base-145),
              (190, base-220), (240, base-155), (300, base-125),
              (340, base-158), (395, base-90), (465, base-65), (580, base)]
    if side: points = [(W-x, y+30) for x,y in points]
    m.polygon(points, fill=tint)
    image = Image.alpha_composite(image, mountains.filter(ImageFilter.GaussianBlur(4)))

water = Image.new("RGBA", (W, H))
w = ImageDraw.Draw(water)
# Perspective wavelets and scattered light, never containing baked-in text.
for _ in range(3000):
    depth = random.random() ** .62
    y = horizon + 5 + depth * (H-horizon)
    x = random.uniform(-40, W+40)
    length = 4 + depth * random.uniform(15, 100)
    amplitude = .5 + depth * 6
    light = abs(x-900) < 90 + depth*300 and random.random() < .55
    color = (255, 245, 217, random.randint(60, 155)) if light else (
        (171, 219, 234, random.randint(25, 100)) if random.random() < .65
        else (22, 82, 120, random.randint(20, 70)))
    points = [(x + j * length/9, y + math.sin(j*.55)*amplitude) for j in range(10)]
    w.line(points, fill=color, width=max(1, round(depth*2)))
water = water.filter(ImageFilter.GaussianBlur(.6))
image = Image.alpha_composite(image, water)

# Subtle foreground coast to anchor the scene without obscuring controls.
rocks = Image.new("RGBA", (W, H))
r = ImageDraw.Draw(rocks)
r.polygon([(0, 1200), (0, 1070), (70, 1005), (135, 1028), (193, 1132), (310, 1200)],
          fill=(47, 83, 108, 160))
r.polygon([(1600,1200),(1600,1095),(1525,1050),(1450,1117),(1390,1200)],
          fill=(50, 87, 112, 150))
image = Image.alpha_composite(image, rocks.filter(ImageFilter.GaussianBlur(3)))
target = Path("assets/scenes/coastal-light.png")
target.parent.mkdir(parents=True, exist_ok=True)
image.convert("RGB").save(target, optimize=True)
print("Generated original environment asset:", target)
