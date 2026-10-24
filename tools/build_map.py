"""Menggambar peta perjalanan (assets/backgrounds/map_mejayan.png).

Tidak ada desain peta di folder desain asli, jadi peta ini digambar dari kode
memakai palet malam yang sama dengan latar battle: langit biru gelap, rumput
hijau kelam, tanah coklat, bata candi merah tua.

Digambar di kanvas 320x180 lalu diperbesar 2x (nearest) supaya pikselnya
sebesar piksel sprite di layar 640x360.

Posisi titik stage harus sama dengan map_position di tools/generate_data.gd
(dibagi dua karena kanvasnya setengah ukuran layar).

Pemakaian: python3 tools/build_map.py
"""
import math
import os
import random

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "backgrounds", "map_mejayan.png")

W, H = 320, 180
rng = random.Random(11)

SKY_TOP = (6, 8, 20)
SKY_BOT = (20, 28, 50)
MOUNT_FAR = (22, 30, 50)
MOUNT_NEAR = (17, 25, 36)
GRASS = [(18, 32, 31), (22, 37, 35), (26, 43, 38), (31, 49, 41)]
DIRT = (78, 61, 48)
DIRT_D = (52, 40, 35)
DIRT_L = (104, 84, 64)
WATER = (24, 46, 74)
WATER_D = (16, 30, 50)
WATER_L = (92, 130, 158)
BRICK = (82, 50, 42)
BRICK_D = (54, 33, 30)
BRICK_L = (110, 72, 56)
MOSS = (48, 74, 46)
ROOF = (48, 32, 29)
ROOF_L = (78, 54, 44)
WALL = (90, 68, 50)
WALL_D = (64, 48, 38)
WINDOW = (250, 204, 112)
BAMBOO = (36, 68, 48)
BAMBOO_L = (60, 100, 64)
LEAF = (30, 64, 44)
LEAF_L = (52, 96, 58)
TREE = (14, 30, 27)
TREE_M = (20, 40, 34)
TREE_L = (30, 56, 42)
FIREFLY = (255, 226, 130)

# Titik stage di kanvas setengah ukuran (map_position / 2).
STAGES = [(46, 134), (103, 98), (159, 131), (219, 94), (277, 56)]
PATH_START = (2, 178)
# Area panel info di kanan bawah (dalam kanvas ini), dibiarkan polos.
INFO_PANEL = (214, 106, 320, 180)

canvas = np.zeros((H, W, 3), dtype=np.float32)


def put(x, y, color, alpha=1.0):
    x = int(round(x))
    y = int(round(y))
    if 0 <= x < W and 0 <= y < H:
        canvas[y, x] = canvas[y, x] * (1.0 - alpha) + np.array(color) * alpha


def rect(x0, y0, x1, y1, color, alpha=1.0):
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            put(x, y, color, alpha)


def disc(cx, cy, r, color, alpha=1.0):
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                put(x, y, color, alpha)


def glow(cx, cy, r, color, strength):
    for y in range(int(cy - r), int(cy + r + 1)):
        for x in range(int(cx - r), int(cx + r + 1)):
            d = math.hypot(x - cx, y - cy) / r
            if d < 1.0:
                put(x, y, color, strength * (1.0 - d) ** 2)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


# --- Langit, bulan, bintang -------------------------------------------------

def horizon(x):
    """Tinggi kaki gunung/batas rumput di kolom x."""
    return 50 + 3 * math.sin(x * 0.045) + 2 * math.sin(x * 0.13 + 1.0)


def mountain_far(x):
    # Gunung Wilis di tengah, perbukitan di kiri-kanan.
    peak = 24 + abs(x - 168) * 0.32
    hills = 40 + 4 * math.sin(x * 0.06) + 2 * math.sin(x * 0.17)
    return min(peak, hills)


def mountain_near(x):
    return 44 + 4 * math.sin(x * 0.05 + 2.0) + 3 * math.sin(x * 0.11 + 0.5)


for y in range(H):
    t = min(1.0, y / 52.0)
    for x in range(W):
        canvas[y, x] = mix(SKY_TOP, SKY_BOT, t)

for _ in range(70):
    sx, sy = rng.randrange(W), rng.randrange(10, 44)
    put(sx, sy, (200, 210, 235), rng.uniform(0.25, 0.8))

glow(64, 22, 22, (120, 140, 190), 0.35)
disc(64, 22, 7, (226, 228, 210))
disc(66, 21, 6, (206, 210, 196))
put(62, 20, (182, 186, 176)); put(66, 25, (182, 186, 176)); put(63, 24, (190, 194, 182))

for x in range(W):
    for y in range(int(mountain_far(x)), H):
        canvas[y, x] = MOUNT_FAR
    for y in range(int(mountain_near(x)), H):
        canvas[y, x] = MOUNT_NEAR

# Aura pagebluk di sekitar candi (kanan atas).
glow(282, 34, 46, (90, 26, 80), 0.55)
glow(282, 30, 20, (150, 40, 70), 0.35)

# --- Rumput -----------------------------------------------------------------

noise = np.array([[rng.random() for _ in range(W)] for _ in range(H)])
for y in range(H):
    for x in range(W):
        top = horizon(x)
        if y < top:
            continue
        depth = min(1.0, (y - top) / 90.0)
        n = noise[y, x] * 0.5 + noise[y // 3 * 3, x // 4 * 4] * 0.5
        level = n * 0.6 + depth * 0.5
        idx = min(len(GRASS) - 1, int(level * len(GRASS)))
        canvas[y, x] = GRASS[idx]

# Kabut tipis di kaki gunung.
for y in range(44, 62):
    a = 0.16 * (1.0 - abs(y - 52) / 10.0)
    if a <= 0:
        continue
    for x in range(W):
        put(x, y, (70, 90, 120), a * (0.6 + 0.4 * math.sin(x * 0.07 + y)))

# --- Jalan setapak ------------------------------------------------------------

def catmull(points, steps=40):
    pts = [points[0]] + points + [points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            out.append(tuple(
                0.5 * (2 * p1[k] + (-p0[k] + p2[k]) * t
                       + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                       + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3)
                for k in range(2)))
    out.append(points[-1])
    return out


path = catmull([PATH_START] + STAGES)
for (x, y) in path:
    w = 3.4 - 1.2 * (1.0 - y / H)
    disc(x, y + 0.6, w + 0.8, DIRT_D)
for (x, y) in path:
    w = 3.4 - 1.2 * (1.0 - y / H)
    disc(x, y, w, DIRT)
for i, (x, y) in enumerate(path):
    if i % 7 == 0:
        put(x + rng.uniform(-2, 2), y + rng.uniform(-1.5, 1.5), DIRT_L)
    if i % 11 == 0:
        put(x + rng.uniform(-2, 2), y + rng.uniform(-1, 1), DIRT_D)


def near_path(x, y, dist):
    for (px_, py_) in path[::3]:
        if (px_ - x) ** 2 + (py_ - y) ** 2 < dist * dist:
            return True
    return False


# --- Stage 3: sendang (kolam) ---------------------------------------------------

PCX, PCY, PRX, PRY = 186, 150, 22, 8
for y in range(PCY - PRY - 2, PCY + PRY + 3):
    for x in range(PCX - PRX - 2, PCX + PRX + 3):
        d = ((x - PCX) / PRX) ** 2 + ((y - PCY) / PRY) ** 2
        if d <= 1.0:
            put(x, y, WATER if d < 0.75 else WATER_D)
        elif d <= 1.35:
            put(x, y, (40, 46, 40))
for i in range(9):
    lx = PCX - 10 + i * 2.4
    put(lx, PCY - 2 + (i % 3), WATER_L, 0.8)
for x in range(PCX - 6, PCX + 7):
    put(x, PCY + 1, WATER_L, 0.5)
for i in range(16):
    a = rng.uniform(0, math.tau)
    rx = PCX + math.cos(a) * (PRX + 1)
    ry = PCY + math.sin(a) * (PRY + 1)
    h = rng.randint(2, 5)
    for k in range(h):
        put(rx, ry - k, (52, 92, 56) if k < h - 1 else (120, 110, 60))

# --- Bangunan --------------------------------------------------------------------

def house(x, y, w=16):
    """Rumah joglo kecil. (x, y) = pojok kiri bawah."""
    rect(x + 2, y - 7, x + w - 3, y - 1, WALL)
    rect(x + w - 6, y - 7, x + w - 3, y - 1, WALL_D)
    rect(x + 4, y - 5, x + 5, y - 3, WINDOW)
    rect(x + w - 8, y - 4, x + w - 7, y - 1, (40, 30, 26))
    glow(x + 4.5, y - 4, 6, WINDOW, 0.25)
    for i in range(3):  # atap bawah, landai
        rect(x + i, y - 8 - i, x + w - 1 - i, y - 8 - i, ROOF)
    for i in range(5):  # atap atas, curam
        rect(x + 4 + i // 2, y - 11 - i, x + w - 5 - i // 2, y - 11 - i, ROOF)
    rect(x + 4, y - 15, x + w - 5, y - 15, ROOF_L)
    rect(x, y - 8, x + w - 1, y - 8, ROOF_L)
    rect(x + 1, y, x + w - 2, y, (14, 22, 22), 0.6)


def bamboo_clump(cx, base_y, count):
    for i in range(count):
        x = cx + rng.uniform(-6, 6)
        h = rng.randint(18, 30)
        lean = rng.uniform(-0.12, 0.12)
        for k in range(h):
            put(x + lean * k, base_y - k, BAMBOO_L if k % 5 == 0 else BAMBOO)
        top_x, top_y = x + lean * h, base_y - h
        for _ in range(14):
            lx = top_x + rng.uniform(-6, 6)
            ly = top_y + rng.uniform(-2, 10)
            d = rng.choice([-1, 1])
            for s in range(3):
                put(lx + s * d, ly + s * 0.5, LEAF_L if s == 0 else LEAF)


def stepped_tower(x, base_y, widths, row_h, flat_side=None):
    """Bangunan bata bertingkat. widths dari bawah ke atas."""
    y = base_y
    for w in widths:
        for r in range(row_h):
            if flat_side == "right":
                x0, x1 = x + widths[0] - w, x + widths[0] - 1
            elif flat_side == "left":
                x0, x1 = x, x + w - 1
            else:
                x0 = x + (widths[0] - w) // 2
                x1 = x0 + w - 1
            for xx in range(x0, x1 + 1):
                c = BRICK
                if (y - r) % 3 == 0:
                    c = BRICK_D
                elif xx == x0:
                    c = BRICK_L
                elif xx >= x1 - 1:
                    c = BRICK_D
                put(xx, y - r, c)
        y -= row_h
    return y


def gapura(cx, base_y):
    """Candi bentar: dua menara yang seperti dibelah dua."""
    widths = [10, 8, 6, 5, 3, 2]
    stepped_tower(cx - 18, base_y, widths, 6, flat_side="right")
    stepped_tower(cx + 8, base_y, widths, 6, flat_side="left")
    for _ in range(10):
        put(cx - 18 + rng.randint(0, 9), base_y - rng.randint(0, 20), MOSS)
        put(cx + 8 + rng.randint(0, 9), base_y - rng.randint(0, 20), MOSS)


def candi(cx, base_y):
    widths = [46, 40, 36, 36, 30, 26, 22, 18, 14, 10, 6, 3]
    rows = [3, 3, 6, 6, 4, 4, 4, 3, 3, 3, 3, 3]
    y = base_y
    for w, rh in zip(widths, rows):
        x0 = cx - w // 2
        for r in range(rh):
            for xx in range(x0, x0 + w):
                c = BRICK
                if (y - r) % 3 == 0:
                    c = BRICK_D
                elif xx <= x0 + 1:
                    c = BRICK_L
                elif xx >= x0 + w - 3:
                    c = BRICK_D
                put(xx, y - r, c)
        y -= rh
    # pintu gelap & relung
    rect(cx - 3, base_y - 16, cx + 2, base_y - 6, (20, 10, 18))
    glow(cx, base_y - 10, 8, (170, 50, 80), 0.35)
    for nx in (cx - 12, cx + 9):
        rect(nx, base_y - 15, nx + 2, base_y - 10, BRICK_D)
    for _ in range(26):
        put(cx + rng.randint(-20, 20), base_y - rng.randint(0, 30), MOSS)


def tree(x, y, size):
    """Pohon bulat gelap. (x, y) = pangkal batang."""
    rect(x, y - size // 2, x + 1, y, (34, 26, 24))
    cy = y - size // 2 - size * 0.6
    for _ in range(6):
        disc(x + rng.uniform(-size * 0.5, size * 0.5), cy + rng.uniform(-size * 0.3, size * 0.3),
             size * rng.uniform(0.45, 0.6), TREE)
    for _ in range(4):
        disc(x + rng.uniform(-size * 0.4, size * 0.2), cy - size * rng.uniform(0.1, 0.4),
             size * 0.3, TREE_M)
    for _ in range(5):
        put(x + rng.uniform(-size * 0.4, size * 0.1), cy - size * rng.uniform(0.3, 0.6), TREE_L)


# Stage 1: rumah warga Desa Mejayan.
house(10, 126)
house(22, 160, 18)
house(62, 160)
house(72, 124, 14)

# Stage 2: rumpun bambu wingit.
bamboo_clump(86, 100, 7)
bamboo_clump(124, 94, 6)
bamboo_clump(96, 78, 4)

# Stage 4 & 5.
gapura(219, 98)
candi(283, 64)

# Pohon tersebar, menjauhi jalan, landmark, titik stage, dan panel info.
blocked = [(10, 100, 90, 162), (78, 60, 134, 104), (160, 136, 212, 164),
           (196, 64, 242, 100), (254, 10, 312, 68)]
trees = []
tries = 0
while len(trees) < 34 and tries < 4000:
    tries += 1
    x, y = rng.randint(4, W - 4), rng.randint(58, H - 2)
    if near_path(x, y, 10):
        continue
    if any(x0 <= x <= x1 and y0 <= y <= y1 for (x0, y0, x1, y1) in blocked):
        continue
    if INFO_PANEL[0] <= x <= INFO_PANEL[2] and INFO_PANEL[1] <= y <= INFO_PANEL[3]:
        continue
    if any(math.hypot(x - sx, y - sy) < 16 for (sx, sy) in STAGES):
        continue
    if any(math.hypot(x - tx, y - ty) < 9 for (tx, ty, _) in trees):
        continue
    trees.append((x, y, rng.randint(6, 10) if y > 80 else rng.randint(4, 7)))
for (x, y, s) in sorted(trees, key=lambda t: t[1]):
    tree(x, y, s)

# Kunang-kunang.
for _ in range(26):
    fx, fy = rng.randint(4, W - 4), rng.randint(60, H - 6)
    glow(fx, fy, 3, FIREFLY, 0.35)
    put(fx, fy, FIREFLY)

# Vignette: pinggir layar sedikit lebih gelap.
for y in range(H):
    for x in range(W):
        dx = (x - W / 2) / (W / 2)
        dy = (y - H / 2) / (H / 2)
        v = max(0.0, math.hypot(dx * 0.9, dy) - 0.7)
        canvas[y, x] *= 1.0 - min(0.55, v * 0.9)

img = Image.fromarray(np.clip(canvas, 0, 255).astype(np.uint8), "RGB")
img = img.resize((W * 2, H * 2), Image.NEAREST)
img.save(OUT)
print("tulis", OUT)
