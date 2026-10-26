"""Menggambar latar battle tiap babak dan latar layar lain (assets/backgrounds/).

Latar lama hanya desain 160x160 yang diperbesar dan diburamkan, jadi terlihat
pecah di layar 1280x720. Latar di sini digambar piksel demi piksel di ukuran
asli layar (640x360) dengan palet malam yang terbatas, gradasi berpola
(dithering Bayer), dan cahaya bulan dari kiri atas, supaya tetap tajam saat
diperbesar dan senada dengan sprite karakter.

Setiap gambar 656x376: ada tepi 8 piksel di semua sisi untuk guncangan layar.
Semua koordinat di kode ini koordinat layar battle (0..640, 0..360):
- kaki Eyang Palang dan Buto di y=228, Eyang di x=150, Buto di x=320..580,
- bar atas menutup y<18, panel kartu menutup y>=252,
- jadi pemandangan utama ada di y 40..210 dan tanah tempat berdiri di y 200..252,
- bulan tidak ditaruh di x 290..600, y 30..110: di situ ikon niat Buto muncul.

Pemakaian: python3 tools/build_backgrounds.py [nama ...]
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "backgrounds")

W, H = 640, 360
M = 8  # tepi untuk guncangan layar
GROUND_Y = 228

BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 + 1 / 32.0


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def pick(rng, seq):
    """Satu anggota acak dari daftar (rng.choice mengubah tuple jadi larik)."""
    return seq[int(rng.integers(len(seq)))]


def shade(c, k):
    """k < 1 menggelapkan, k > 1 menerangkan (menuju putih)."""
    if k <= 1:
        return tuple(int(v * k) for v in c)
    return mix(c, (255, 255, 255), min(1.0, k - 1))


class Art:
    """Kanvas piksel dengan koordinat layar battle (tepi M ikut digambar)."""

    def __init__(self, seed):
        self.img = Image.new("RGB", (W + 2 * M, H + 2 * M))
        self.d = ImageDraw.Draw(self.img)
        self.rng = np.random.default_rng(seed)

    # --- bentuk dasar (tanpa anti-alias) ---
    def _p(self, pts):
        return [(int(round(x)) + M, int(round(y)) + M) for x, y in pts]

    def rect(self, x0, y0, x1, y1, c):
        if x1 < x0 or y1 < y0:
            return
        self.d.rectangle([x0 + M, y0 + M, x1 + M, y1 + M], fill=c)

    def poly(self, pts, c):
        self.d.polygon(self._p(pts), fill=c)

    def line(self, pts, c, w=1):
        self.d.line(self._p(pts), fill=c, width=w)

    def ellipse(self, x0, y0, x1, y1, c):
        self.d.ellipse([x0 + M, y0 + M, x1 + M, y1 + M], fill=c)

    def circle(self, x, y, r, c):
        self.ellipse(x - r, y - r, x + r, y + r, c)

    def px(self, x, y, c):
        x, y = int(x) + M, int(y) + M
        if 0 <= x < self.img.width and 0 <= y < self.img.height:
            self.img.putpixel((x, y), c)

    # --- operasi larik ---
    def arr(self):
        return np.asarray(self.img).astype(np.float32)

    def put(self, a):
        self.img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")
        self.d = ImageDraw.Draw(self.img)

    def grid(self):
        h, w = self.img.height, self.img.width
        ys, xs = np.mgrid[0:h, 0:w]
        return xs - M, ys - M

    def bayer(self):
        h, w = self.img.height, self.img.width
        return np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w]

    def blend(self, alpha, color, levels=4):
        """Mencampur warna dengan alpha (larik 0..1) yang dipatah jadi beberapa
        tingkat berpola Bayer, supaya cahaya dan kabut tetap terlihat piksel."""
        a = self.arr()
        q = np.clip(alpha, 0, 1) * levels
        lo = np.floor(q)
        step = (lo + ((q - lo) > self.bayer())) / levels
        c = np.array(color, dtype=np.float32)
        a = a * (1 - step[..., None]) + c * step[..., None]
        self.put(a)

    def save(self, name):
        path = os.path.join(OUT, name + ".png")
        self.img.save(path)
        print("tulis", os.path.relpath(path, ROOT))


# ---------------------------------------------------------------------------
# Langit
# ---------------------------------------------------------------------------

def sky(art, stops, bands=10):
    """Gradasi langit dari daftar (y, warna), dipatah jadi pita berpola."""
    xs, ys = art.grid()
    ys_f = ys.astype(np.float32)
    ys_s = np.array([s[0] for s in stops], dtype=np.float32)
    t = np.interp(ys_f, ys_s, np.linspace(0, 1, len(stops)))
    q = t * bands
    lo = np.floor(q)
    idx = (lo + ((q - lo) > art.bayer())) / bands
    cols = np.array([s[1] for s in stops], dtype=np.float32)
    pos = np.linspace(0, 1, len(stops))
    out = np.zeros(idx.shape + (3,), dtype=np.float32)
    for ch in range(3):
        out[..., ch] = np.interp(idx, pos, cols[:, ch])
    art.put(out)


def stars(art, count, y_max, color=(210, 214, 240)):
    rng = art.rng
    for _ in range(count):
        x = rng.uniform(-M, W + M)
        y = rng.uniform(-M, y_max) ** 1.0
        if rng.random() < y / max(1.0, y_max) * 0.7:
            continue  # lebih jarang di dekat cakrawala
        b = rng.uniform(0.35, 1.0)
        c = mix((60, 64, 100), color, b)
        art.px(x, y, c)
        if b > 0.93:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                art.px(x + dx, y + dy, mix((40, 44, 80), color, 0.45))


def moon(art, x, y, r, color=(236, 230, 198), halo=(70, 78, 120), halo_r=3.2, halo_a=0.4):
    xs, ys = art.grid()
    dist = np.sqrt((xs - x) ** 2 + (ys - y) ** 2)
    glow = np.clip(1 - (dist - r) / (r * halo_r), 0, 1) ** 2 * halo_a
    art.blend(glow, halo, levels=5)
    art.circle(x, y, r, color)
    # sisi gelap dan kawah
    dark = shade(color, 0.86)
    for (cx, cy, cr) in ((0.3, -0.2, 0.28), (-0.35, 0.3, 0.2), (0.15, 0.45, 0.14), (-0.1, -0.45, 0.12)):
        art.circle(x + cx * r, y + cy * r, max(1, cr * r), dark)
    art.d.arc([x - r + M, y - r + M, x + r + M, y + r + M], 20, 200, fill=shade(color, 0.93))


def clouds(art, specs, color, light, shadow=None):
    """Awan berlapis: specs = [(x, y, panjang, tebal), ...]. Gumpalan lonjong
    yang tumpang tindih, tepi atas-kiri terkena bulan, dasar lebih rata."""
    shadow = shadow or shade(color, 0.82)
    rng = art.rng
    for x, y, length, thick in specs:
        blobs = []
        n = max(4, int(length / 10))
        for i in range(n):
            t = i / (n - 1)
            bx = x + (t - 0.5) * length + rng.uniform(-4, 4)
            hump = math.sin(math.pi * t) ** 0.7
            rx = rng.uniform(0.6, 1.1) * length / n * 1.6
            ry = thick * (0.45 + 0.75 * hump) * rng.uniform(0.8, 1.15)
            by = y - ry * 0.35 + rng.uniform(-1, 1)
            blobs.append((bx, by, rx, ry))
        for bx, by, rx, ry in blobs:
            art.ellipse(bx - rx + 1, by - ry + 2, bx + rx + 1, min(by + ry + 2, y + thick * 0.5 + 2), shadow)
        for bx, by, rx, ry in blobs:
            art.ellipse(bx - rx - 1, by - ry - 1, bx + rx - 1, min(by + ry - 1, y + thick * 0.5), light)
        for bx, by, rx, ry in blobs:
            art.ellipse(bx - rx, by - ry + 1, bx + rx, min(by + ry, y + thick * 0.5 + 1), color)


def tint_poly(art, pts, color, alpha):
    """Mewarnai bidang poligon secara tembus pandang rata (tanpa pola)."""
    mask = Image.new("L", art.img.size, 0)
    ImageDraw.Draw(mask).polygon(art._p(pts), fill=255)
    m = np.asarray(mask).astype(np.float32)[..., None] / 255.0 * alpha
    a = art.arr()
    art.put(a * (1 - m) + np.array(color, dtype=np.float32) * m)


# ---------------------------------------------------------------------------
# Bentang alam
# ---------------------------------------------------------------------------

def ridge(art, base, amp, freqs, seed_shift=0.0):
    """Garis punggung bukit: tinggi tiap kolom x."""
    xs = np.arange(-M, W + M)
    h = np.zeros(len(xs), dtype=np.float32)
    rng = art.rng
    for f, a in freqs:
        ph = rng.uniform(0, 2 * math.pi) + seed_shift
        h += a * np.sin(xs / W * 2 * math.pi * f + ph)
    h = base - amp * (h / max(1e-6, sum(a for _, a in freqs)))
    return xs, h


def mountain(art, xs, top, color, light=None, bottom=H):
    """Mengisi dari garis `top` ke bawah. Sisi yang menghadap bulan (kiri)
    diberi garis terang tipis."""
    for x, t in zip(xs, top):
        art.rect(x, int(t), x, bottom, color)
    if light is not None:
        for i in range(1, len(xs)):
            if top[i] < top[i - 1] - 0.15:  # lereng naik ke kanan menghadap kiri
                art.px(xs[i], int(top[i]), light)
                art.px(xs[i], int(top[i]) + 1, mix(color, light, 0.5))


def gunung(art, peak_x, peak_y, base_y, width, color, light, snow=None):
    """Gunung tunggal (Wilis) berbentuk kerucut landai dengan alur lereng."""
    xs = np.arange(-M, W + M)
    d = np.abs(xs - peak_x) / (width / 2)
    top = peak_y + (base_y - peak_y) * np.clip(d, 0, 1) ** 0.75
    top += np.sin(xs * 0.13) * 1.2 + np.sin(xs * 0.041 + 1.3) * 2.0
    mountain(art, xs, top, color, light, base_y + 20)
    # alur lereng
    rng = art.rng
    for _ in range(9):
        sx = peak_x + rng.uniform(-width * 0.08, width * 0.08)
        ang = rng.uniform(0.35, 1.2) * (1 if rng.random() < 0.5 else -1)
        length = rng.uniform(10, 30)
        sy = peak_y + abs(sx - peak_x) * 0.4 + 4
        art.line([(sx, sy), (sx + math.sin(ang) * length * 1.6, sy + length)], shade(color, 0.85))


def tree_line(art, base_y, height, color, light, dark, density=0.9, bumps=7):
    """Barisan pohon jauh: tepi atas bergelombang bulat-bulat."""
    rng = art.rng
    x = -M
    while x < W + M:
        r = rng.uniform(height * 0.35, height * 0.6)
        top = base_y - height * rng.uniform(0.6, 1.0)
        art.circle(x, top + r, r, color)
        art.rect(x - r, top + r, x + r, base_y + 30, color)
        art.circle(x - r * 0.25, top + r * 0.75, r * 0.45, light)
        art.circle(x - r * 0.05, top + r * 0.95, r * 0.5, color)
        x += r * rng.uniform(1.0, 1.6) / density
    # bayangan bawah
    for x in range(-M, W + M):
        if rng.random() < 0.6:
            art.px(x, base_y + rng.integers(-2, 3), dark)


def foliage(art, cx, cy, rx, ry, pal, seed_count=26):
    """Rimbun daun bulat: lapisan gelap, sedang, terang (bulan dari kiri atas),
    lalu bintik daun di tepi."""
    dark, mid, light, high = pal
    rng = art.rng
    blobs = []
    for _ in range(seed_count):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0, 1) ** 0.6
        bx = cx + math.cos(a) * rx * d * 0.8
        by = cy + math.sin(a) * ry * d * 0.8
        br = rng.uniform(0.25, 0.42) * (rx + ry) / 2
        blobs.append((bx, by, br))
    for bx, by, br in blobs:
        art.circle(bx, by, br, dark)
    for bx, by, br in blobs:
        art.circle(bx - br * 0.2, by - br * 0.22, br * 0.78, mid)
    for bx, by, br in blobs:
        if (bx - cx) / rx + (by - cy) / ry < 0.4:
            art.circle(bx - br * 0.38, by - br * 0.4, br * 0.42, light)
    for bx, by, br in blobs:
        if (bx - cx) / rx + (by - cy) / ry < -0.4:
            art.circle(bx - br * 0.5, by - br * 0.5, max(1, br * 0.16), high)
    # daun-daun kecil di tepi
    for _ in range(int((rx + ry) * 1.2)):
        a = rng.uniform(0, 2 * math.pi)
        ex = cx + math.cos(a) * rx * rng.uniform(0.85, 1.05)
        ey = cy + math.sin(a) * ry * rng.uniform(0.85, 1.05)
        c = light if (math.cos(a) + math.sin(a)) < -0.3 else (mid if rng.random() < 0.5 else dark)
        art.rect(ex, ey, ex + 1, ey + rng.integers(0, 2), c)


def trunk(art, x, y0, y1, w, color, light, lean=0.0):
    pts = [(x - w / 2, y1), (x + w / 2, y1), (x + w * 0.35 + lean, y0), (x - w * 0.35 + lean, y0)]
    art.poly(pts, color)
    art.line([(x - w / 2 + 1, y1), (x - w * 0.35 + lean + 1, y0)], light)


def tree(art, x, base_y, height, pal, trunk_c, trunk_l, width=None):
    width = width or height * 0.55
    trunk(art, x, base_y - height * 0.55, base_y, max(3, height * 0.08), trunk_c, trunk_l)
    foliage(art, x, base_y - height * 0.68, width / 2, height * 0.34, pal)


def coconut(art, x, base_y, height, lean, trunk_c, trunk_l, leaf, leaf_l):
    """Pohon kelapa: batang melengkung bercincin, pelepah melengkung."""
    pts = []
    for i in range(21):
        t = i / 20
        pts.append((x + lean * t * t * height * 0.3, base_y - t * height))
    for i in range(len(pts) - 1):
        (xa, ya), (xb, yb) = pts[i], pts[i + 1]
        w = 3 - i * 0.06
        art.poly([(xa - w, ya), (xa + w, ya), (xb + w, yb), (xb - w, yb)], trunk_c)
        if i % 2 == 0:
            art.line([(xa - w, ya), (xa + w, ya)], shade(trunk_c, 0.8))
        art.px(xa - w + 1, ya, trunk_l)
    tx, ty = pts[-1]
    for k, ang in enumerate((-165, -140, -112, -84, -58, -32, -8, 18, 195)):
        a = math.radians(ang)
        length = height * (0.34 + 0.05 * math.sin(k * 1.7))
        prev = (tx, ty)
        for s_ in range(1, 15):
            t = s_ / 14
            px_ = tx + math.cos(a) * length * t
            py_ = ty + math.sin(a) * length * t + (t * t) * length * 0.6
            art.line([prev, (px_, py_)], leaf, 2)
            # anak daun menjuntai di kedua sisi pelepah
            lf = 7 * (1 - t * 0.5)
            art.line([(px_, py_), (px_ - 3, py_ + lf)], leaf)
            art.line([(px_, py_), (px_ + 3, py_ + lf)], leaf)
            if math.cos(a) < 0.3 and s_ % 3 == 0:
                art.line([(px_, py_), (px_ - 3, py_ + lf)], leaf_l)
            prev = (px_, py_)
        art.line([(tx, ty), (tx + math.cos(a) * length * 0.45, ty + math.sin(a) * length * 0.45 + length * 0.05)], leaf_l)
    art.circle(tx, ty + 2, 4, shade(trunk_c, 0.7))
    art.circle(tx - 2, ty + 4, 2, (70, 60, 40))
    art.circle(tx + 2, ty + 5, 2, (60, 52, 36))


def banana(art, x, base_y, height, leaf, leaf_l, stem):
    art.rect(x - 1, base_y - height * 0.55, x + 1, base_y, stem)
    for k, ang in enumerate((-150, -115, -70, -35, -95)):
        a = math.radians(ang)
        length = height * 0.55
        sx, sy = x, base_y - height * 0.5
        ex, ey = sx + math.cos(a) * length, sy + math.sin(a) * length * 0.8
        art.line([(sx, sy), (ex, ey)], stem)
        nx, ny = -math.sin(a), math.cos(a)
        w = height * 0.11
        art.poly([(sx, sy), (ex, ey), (ex + nx * 2, ey + ny * 2 + 3),
                  ((sx + ex) / 2 + nx * w, (sy + ey) / 2 + ny * w + 3)], leaf)
        art.line([((sx + ex) / 2, (sy + ey) / 2), (ex, ey)], leaf_l)


def bamboo_clump(art, x, base_y, height, count, pal, spread=26, lean=1.0):
    """Rumpun bambu: batang beruas yang condong keluar dan melengkung di
    pucuk, dengan daun runcing lebat yang menjuntai di sepertiga atas."""
    dark, mid, light, leaf_d, leaf_m, leaf_l = pal
    rng = art.rng
    culms = []
    for i in range(count):
        u = (i + 0.5) / count - 0.5
        off = u * spread
        h = height * rng.uniform(0.7, 1.05)
        bend = (u * 1.8 + rng.uniform(-0.25, 0.25)) * h * 0.45 * lean
        w = pick(rng, [3, 4, 4, 5])
        culms.append((off, h, bend, w, (dark, mid)[i % 2]))
    culms.sort(key=lambda c: -abs(c[0]))  # yang di tengah digambar terakhir (paling depan)
    leaf_spots = []
    for off, h, bend, w, col in culms:
        prev = None
        steps = 36
        for s_ in range(steps + 1):
            t = s_ / steps
            px_ = x + off * 0.25 + bend * t ** 2.2
            py_ = base_y - h * t + abs(bend) * 0.25 * t ** 3
            ww = max(2, w * (1 - 0.5 * t))
            if prev is not None:
                art.poly([(prev[0], prev[1]), (prev[0] + ww, prev[1]), (px_ + ww, py_), (px_, py_)], col)
                art.line([prev, (px_, py_)], light)
            if s_ % 4 == 0 and 0 < s_ < steps:
                art.line([(px_ - 1, py_), (px_ + ww, py_)], shade(col, 0.6))
                art.px(px_ - 1, py_ - 1, light)
            if t > 0.55:
                leaf_spots.append((px_, py_, t))
            prev = (px_, py_)
    for lx, ly, t in leaf_spots:
        if rng.random() > 0.55:
            continue
        for _ in range(3):
            side = pick(rng, [-1, 1])
            ln = rng.uniform(5, 11)
            droop = rng.uniform(2, 6)
            ex, ey = lx + side * ln, ly + droop
            c = pick(rng, [leaf_d, leaf_m, leaf_m, leaf_l if side < 0 else leaf_m])
            art.line([(lx, ly), (lx + side * ln * 0.5, ly + droop * 0.2), (ex, ey)], c)
            art.px(ex, ey + 1, c)


# ---------------------------------------------------------------------------
# Bangunan
# ---------------------------------------------------------------------------

def house(art, x, base_y, w, h, pal, lit=True, door=True):
    """Rumah limasan: atap genteng tinggi, dinding gedhek (anyaman bambu),
    jendela berpendar lampu senthir."""
    roof, roof_l, roof_d, wall, wall_d, post, glow = pal
    wall_top = base_y - h * 0.45
    art.rect(x - w / 2, wall_top, x + w / 2, base_y, wall)
    # anyaman gedhek
    for yy in range(int(wall_top) + 2, int(base_y), 3):
        for xx in range(int(x - w / 2), int(x + w / 2), 4):
            off = 2 if (yy // 3) % 2 else 0
            art.px(xx + off, yy, wall_d)
            art.px(xx + off + 1, yy, wall_d)
    # tiang
    for px_ in (x - w / 2, x + w / 2 - 2, x - w * 0.18, x + w * 0.18):
        art.rect(px_, wall_top, px_ + 1, base_y, post)
    # pintu & jendela
    if door:
        art.rect(x - 5, base_y - h * 0.32, x + 5, base_y, shade(post, 0.7))
        if lit:
            art.rect(x - 4, base_y - h * 0.3, x + 4, base_y, shade(glow, 0.55))
            art.rect(x - 1, base_y - h * 0.3, x + 1, base_y, shade(glow, 0.8))
    for wx in (x - w * 0.34, x + w * 0.27):
        art.rect(wx - 4, wall_top + 5, wx + 4, wall_top + 11, shade(post, 0.6))
        if lit:
            art.rect(wx - 3, wall_top + 6, wx + 3, wall_top + 10, glow)
            for k in range(-3, 4, 2):
                art.px(wx + k, wall_top + 8, shade(glow, 0.7))
    # atap limasan dua tingkat: brunjung yang curam di atas, penanggap yang
    # landai di bawah, dengan bubungan (wuwungan) di puncak.
    eave = w * 0.1
    mid_y = wall_top - h * 0.22
    top_y = base_y - h
    upper_half = w * 0.36
    ridge_half = w * 0.16
    art.poly([(x - w / 2 - eave, wall_top + 2), (x + w / 2 + eave, wall_top + 2),
              (x + upper_half, mid_y), (x - upper_half, mid_y)], roof)
    art.poly([(x - upper_half - 1, mid_y + 1), (x + upper_half + 1, mid_y + 1),
              (x + ridge_half, top_y), (x - ridge_half, top_y)], roof)
    for yy in range(int(top_y) + 3, int(wall_top) + 2, 3):
        if yy <= mid_y:
            t = (yy - top_y) / max(1.0, mid_y - top_y)
            half = ridge_half + (upper_half - ridge_half) * t
        else:
            t = (yy - mid_y) / max(1.0, wall_top + 2 - mid_y)
            half = upper_half + (w / 2 + eave - upper_half) * t
        art.line([(x - half, yy), (x + half, yy)], roof_d)
    # sisi kiri terkena cahaya bulan
    art.poly([(x - upper_half, mid_y), (x - ridge_half, top_y), (x - ridge_half + 4, top_y), (x - upper_half + 5, mid_y)], roof_l)
    art.poly([(x - w / 2 - eave, wall_top + 2), (x - upper_half - 1, mid_y + 1), (x - upper_half + 4, mid_y + 1), (x - w / 2 - eave + 6, wall_top + 2)], roof_l)
    art.line([(x - upper_half, mid_y), (x + upper_half, mid_y)], roof_d)
    art.line([(x - w / 2 - eave, wall_top + 2), (x + w / 2 + eave, wall_top + 2)], roof_d)
    art.rect(x - ridge_half, top_y - 2, x + ridge_half, top_y, roof_d)
    art.line([(x - ridge_half, top_y - 2), (x + ridge_half, top_y - 2)], roof_l)
    for side in (-1, 1):
        ex = x + side * ridge_half
        art.line([(ex, top_y - 2), (ex + side * 3, top_y - 6)], roof_d)
        art.px(ex + side * 3, top_y - 7, roof_l)


def lamp_glow(art, x, y, r, color, strength=0.5):
    xs, ys = art.grid()
    d = np.sqrt((xs - x) ** 2 + ((ys - y) * 1.15) ** 2)
    art.blend(np.clip(1 - d / r, 0, 1) ** 1.6 * strength, color, levels=4)


def torch(art, x, base_y, h, pole, flame, glow):
    art.rect(x - 1, base_y - h, x + 1, base_y, pole)
    art.line([(x - 1, base_y - h), (x + 1, base_y - h)], shade(pole, 1.3))
    art.poly([(x - 3, base_y - h), (x + 3, base_y - h), (x, base_y - h - 9)], flame)
    art.poly([(x - 1, base_y - h), (x + 1, base_y - h), (x, base_y - h - 5)], (255, 244, 200))


def fence(art, x0, x1, base_y, h, color, light, dark):
    """Pagar bambu: tiang tegak dan dua bilah melintang."""
    for xx in range(int(x0), int(x1), 7):
        art.rect(xx, base_y - h, xx + 1, base_y, color)
        art.px(xx, base_y - h, light)
    for yy in (base_y - h * 0.75, base_y - h * 0.35):
        art.line([(x0, yy), (x1, yy)], light)
        art.line([(x0, yy + 1), (x1, yy + 1)], dark)


def gardu(art, x, base_y, pal):
    """Gardu ronda: gubuk kecil berpanggung dengan kentongan tergantung."""
    roof, roof_l, wood, wood_d, glow = pal
    w, h = 44, 46
    art.rect(x - w / 2, base_y - 16, x + w / 2, base_y - 13, wood)  # lantai
    for px_ in (x - w / 2, x + w / 2 - 2):
        art.rect(px_, base_y - h + 10, px_ + 2, base_y, wood_d)
    art.rect(x - w / 2 + 2, base_y - 13, x + w / 2 - 2, base_y - 11, wood_d)
    art.poly([(x - w / 2 - 7, base_y - h + 12), (x + w / 2 + 7, base_y - h + 12), (x, base_y - h - 6)], roof)
    art.poly([(x - w / 2 - 7, base_y - h + 12), (x, base_y - h - 6), (x + 2, base_y - h - 3), (x - w / 2 - 2, base_y - h + 12)], roof_l)
    for yy in range(int(base_y - h - 2), int(base_y - h + 12), 3):
        t = (yy - (base_y - h - 6)) / 18
        art.line([(x - (w / 2 + 7) * t, yy), (x + (w / 2 + 7) * t, yy)], shade(roof, 0.8))
    # kentongan
    kx = x + w / 2 - 8
    art.line([(kx, base_y - h + 12), (kx, base_y - h + 18)], wood_d)
    art.rect(kx - 2, base_y - h + 18, kx + 2, base_y - h + 32, (120, 86, 52))
    art.rect(kx - 1, base_y - h + 22, kx, base_y - h + 28, (60, 40, 26))
    # pelita kecil
    art.rect(x - 9, base_y - 20, x - 7, base_y - 17, glow)


def bricks(art, x0, y0, x1, y1, base, mortar, light=None, row=3, brick=7):
    """Tekstur bata: garis nat mendatar dan sambungan berselang-seling."""
    art.rect(x0, y0, x1, y1, base)
    for r, yy in enumerate(range(int(y0) + row, int(y1) + 1, row)):
        art.line([(x0, yy), (x1, yy)], mortar)
        off = (brick // 2) if r % 2 else 0
        for xx in range(int(x0) + off, int(x1), brick):
            art.line([(xx, yy - row + 1), (xx, yy - 1)], mortar)
    if light is not None:
        art.line([(x0, y0), (x0, y1)], light)


def candi_bentar(art, cx, base_y, height, half_w, gap, pal):
    """Gapura candi bentar: dua menara bata kembar yang seperti dibelah dua.
    Sisi dalam menara kanan menghadap bulan (terang), sisi dalam menara kiri
    dalam bayangan."""
    brick_c, mortar, light, dark, moss = pal
    tiers = [(0.0, 1.0), (0.14, 0.92), (0.30, 0.84), (0.44, 0.74), (0.56, 0.64),
             (0.68, 0.52), (0.78, 0.40), (0.87, 0.28), (0.94, 0.16)]
    for side in (-1, 1):
        inner = cx + side * gap / 2
        for i, (start, width) in enumerate(tiers):
            end = tiers[i + 1][0] if i + 1 < len(tiers) else 1.0
            y_bot = base_y - height * start
            y_top = base_y - height * end
            outer = inner + side * half_w * width
            xa, xb = (outer, inner) if side < 0 else (inner, outer)
            bricks(art, xa, y_top, xb, y_bot, brick_c, mortar)
            # pinggir tingkat dan hiasan sudut (antefiks)
            art.line([(xa, y_top), (xb, y_top)], light)
            art.line([(xa, y_top + 1), (xb, y_top + 1)], dark)
            art.poly([(outer - 2, y_top), (outer + 2, y_top), (outer, y_top - 4)], light if side < 0 else brick_c)
            if art.rng.random() < 0.6:
                mx = art.rng.uniform(min(xa, xb), max(xa, xb))
                art.rect(mx, y_top - 1, mx + art.rng.integers(2, 6), y_top, moss)
        # sisi dalam yang terbelah
        face = light if side > 0 else dark
        art.rect(inner - (2 if side > 0 else 0), base_y - height * 0.94, inner + (0 if side > 0 else 2), base_y, face)
        # sisi luar terkena bulan (kiri)
        if side < 0:
            for i, (start, width) in enumerate(tiers):
                end = tiers[i + 1][0] if i + 1 < len(tiers) else 1.0
                ox = inner - half_w * width
                art.line([(ox, base_y - height * end), (ox, base_y - height * start)], light)
    # anak tangga di celah gapura
    for k in range(5):
        yy = base_y - k * 3
        art.rect(cx - gap / 2 + 1, yy - 2, cx + gap / 2 - 1, yy, shade(brick_c, 0.8 + 0.05 * k))
        art.line([(cx - gap / 2 + 1, yy - 2), (cx + gap / 2 - 1, yy - 2)], light)


def candi(art, cx, base_y, w, h, pal, door=None, tiers=6):
    """Candi bata gaya Jawa Timur: kaki berundak, tubuh berpintu dengan
    kepala kala di atasnya, atap bertingkat yang meruncing."""
    brick_c, mortar, light, dark, moss = pal
    foot_h = h * 0.18
    body_h = h * 0.34
    roof_h = h - foot_h - body_h
    # kaki berundak
    for k in range(3):
        fw = w * (1.0 - 0.08 * k)
        y0 = base_y - foot_h * (k + 1) / 3
        y1 = base_y - foot_h * k / 3
        bricks(art, cx - fw / 2, y0, cx + fw / 2, y1, brick_c, mortar)
        art.line([(cx - fw / 2, y0), (cx + fw / 2, y0)], light)
        art.line([(cx - fw / 2, y0), (cx - fw / 2, y1)], light)
    # tangga depan
    sw = w * 0.16
    for k in range(6):
        yy = base_y - k * foot_h / 6
        art.rect(cx - sw / 2, yy - foot_h / 6, cx + sw / 2, yy, shade(brick_c, 0.75 + 0.04 * k))
        art.line([(cx - sw / 2, yy - foot_h / 6), (cx + sw / 2, yy - foot_h / 6)], light)
    # tubuh
    bw = w * 0.72
    by1 = base_y - foot_h
    by0 = by1 - body_h
    bricks(art, cx - bw / 2, by0, cx + bw / 2, by1, brick_c, mortar)
    art.line([(cx - bw / 2, by0), (cx - bw / 2, by1)], light)
    art.rect(cx + bw / 2 - 3, by0, cx + bw / 2, by1, dark)
    # pintu dan kala
    dw = bw * 0.24
    dh = body_h * 0.62
    art.rect(cx - dw / 2 - 2, by1 - dh - 2, cx + dw / 2 + 2, by1, light)
    art.rect(cx - dw / 2, by1 - dh, cx + dw / 2, by1, door or (12, 8, 10))
    if door is not None:
        art.rect(cx - dw / 2 + 2, by1 - dh + 3, cx + dw / 2 - 2, by1, shade(door, 1.25))
    ky = by1 - dh - 3
    art.ellipse(cx - dw * 0.55, ky - dw * 0.55, cx + dw * 0.55, ky + 1, dark)
    art.px(cx - dw * 0.2, ky - dw * 0.25, light)
    art.px(cx + dw * 0.2, ky - dw * 0.25, light)
    art.line([(cx - dw * 0.3, ky - 2), (cx + dw * 0.3, ky - 2)], shade(dark, 1.3))
    # relung kiri-kanan
    for side in (-1, 1):
        nx = cx + side * bw * 0.32
        art.rect(nx - 4, by0 + body_h * 0.25, nx + 4, by0 + body_h * 0.7, dark)
        art.line([(nx - 4, by0 + body_h * 0.25), (nx + 4, by0 + body_h * 0.25)], light)
    # atap bertingkat
    y = by0
    tw = bw * 1.06
    for k in range(tiers):
        th = roof_h * (0.2 if k == 0 else 0.8 / tiers)
        y_top = y - th
        bricks(art, cx - tw / 2, y_top, cx + tw / 2, y, brick_c, mortar)
        art.line([(cx - tw / 2, y_top), (cx + tw / 2, y_top)], light)
        art.line([(cx - tw / 2, y_top), (cx - tw / 2, y)], light)
        art.rect(cx + tw / 2 - 2, y_top, cx + tw / 2, y, dark)
        for side in (-1, 1):
            ex = cx + side * tw / 2
            art.poly([(ex - 2, y_top), (ex + 2, y_top), (ex, y_top - 5)], light if side < 0 else brick_c)
        if art.rng.random() < 0.7:
            mx = art.rng.uniform(cx - tw / 2, cx + tw / 2)
            art.rect(mx, y_top - 1, mx + art.rng.integers(2, 7), y_top, moss)
        y = y_top
        tw *= 0.8 if k == 0 else 0.84
    # puncak
    art.rect(cx - tw * 0.3, y - 6, cx + tw * 0.3, y, brick_c)
    art.poly([(cx - 3, y - 6), (cx + 3, y - 6), (cx, y - 16)], light)
    art.line([(cx, y - 16), (cx, y - 6)], brick_c)


def beringin(art, cx, base_y, height, pal, trunk_pal):
    """Beringin tua: tajuk sangat lebar, akar gantung, batang berbanir."""
    dark, mid, light, high = pal
    tc, tl, td = trunk_pal
    rng = art.rng
    # batang dan banir: lebar di bawah, menyempit, lalu bercabang ke tajuk
    tw = height * 0.1
    pts_l, pts_r = [], []
    for i in range(13):
        t = i / 12
        half = tw * (2.6 - 1.7 * t ** 0.6) + math.sin(t * 9) * 1.5
        y = base_y - height * 0.6 * t
        pts_l.append((cx - half + math.sin(t * 5) * 3, y))
        pts_r.append((cx + half + math.sin(t * 5 + 1) * 3, y))
    art.poly(pts_l + pts_r[::-1], tc)
    for k in range(-3, 4):
        art.line([(cx + k * tw * 0.4, base_y - height * 0.55), (cx + k * tw * 0.8, base_y)], td)
    art.line(pts_l, tl)
    for ang, ln in ((-130, 0.36), (-100, 0.3), (-70, 0.3), (-45, 0.36), (-150, 0.3)):
        a = math.radians(ang)
        sx, sy = cx, base_y - height * 0.56
        art.line([(sx, sy), (sx + math.cos(a) * height * ln, sy + math.sin(a) * height * ln * 0.6)], tc, 4)
    # akar gantung
    for _ in range(int(height * 0.5)):
        x = cx + rng.uniform(-height * 0.75, height * 0.75)
        y0 = base_y - height * rng.uniform(0.55, 0.7)
        y1 = y0 + rng.uniform(height * 0.15, height * 0.55)
        art.line([(x, y0), (x + rng.uniform(-1, 1), y1)], pick(rng, [td, tc, tc]))
    foliage(art, cx - height * 0.35, base_y - height * 0.78, height * 0.42, height * 0.24, pal, 30)
    foliage(art, cx + height * 0.35, base_y - height * 0.74, height * 0.42, height * 0.24, pal, 30)
    foliage(art, cx, base_y - height * 0.9, height * 0.5, height * 0.26, pal, 36)


def teak(art, x, base_y, height, bark, bark_l, bark_d, leaf_pal):
    """Pohon jati: batang lurus tinggi bergaris, daun lebar besar di atas."""
    w = max(6, height * 0.05)
    art.poly([(x - w / 2 - 2, base_y), (x + w / 2 + 2, base_y), (x + w / 2, base_y - height), (x - w / 2, base_y - height)], bark)
    for k in range(int(w)):
        if k % 3 == 0:
            art.line([(x - w / 2 + k, base_y), (x - w / 2 + k, base_y - height)], bark_d)
    art.line([(x - w / 2 - 1, base_y), (x - w / 2, base_y - height)], bark_l)
    rng = art.rng
    dark, mid, light, high = leaf_pal
    for _ in range(int(height / 18)):
        by = base_y - height * rng.uniform(0.55, 1.0)
        side = pick(rng, [-1, 1])
        bx = x + side * rng.uniform(10, 30)
        art.line([(x, by + 8), (bx, by)], bark)
        # daun jati: lonjong besar
        for _ in range(3):
            lx = bx + rng.uniform(-10, 10)
            ly = by + rng.uniform(-8, 6)
            lw, lh = rng.uniform(5, 9), rng.uniform(3, 6)
            art.ellipse(lx - lw, ly - lh, lx + lw, ly + lh, pick(rng, [dark, mid, mid]))
            art.line([(lx - lw + 1, ly), (lx + lw - 1, ly)], shade(mid, 0.8))
            if lx < x:
                art.ellipse(lx - lw, ly - lh, lx, ly - 1, light)


def boulder(art, x, y, rx, ry, pal, crack=False):
    """Batu besar tidak beraturan: atas-kiri terang, bawah-kanan gelap."""
    dark, mid, light, high = pal
    rng = art.rng
    pts = []
    n = 14
    for i in range(n):
        a = math.pi + 2 * math.pi * i / n
        r = rng.uniform(0.82, 1.08)
        py_ = y + math.sin(a) * ry * r
        pts.append((x + math.cos(a) * rx * r, min(py_, y + ry * 0.35)))
    art.poly(pts, dark)
    inner = [(x + (px_ - x) * 0.86 - rx * 0.06, y + (py_ - y) * 0.86 - ry * 0.08) for px_, py_ in pts]
    art.poly(inner, mid)
    lit = [(x + (px_ - x) * 0.55 - rx * 0.25, y + (py_ - y) * 0.5 - ry * 0.32) for px_, py_ in pts]
    art.poly(lit, light)
    for i in range(n // 2 - 1, n - 2):
        art.line([pts[i], pts[i + 1]], high) if pts[i][1] < y else None
    if crack:
        cx_, cy_ = x + rng.uniform(-rx * 0.3, rx * 0.1), y - ry * 0.6
        for _ in range(4):
            nx, ny = cx_ + rng.uniform(-4, 6), cy_ + rng.uniform(3, 7)
            art.line([(cx_, cy_), (nx, ny)], shade(dark, 0.7))
            cx_, cy_ = nx, ny


def water(art, y0, y1, pal, moon_x=None, ripple=0.06):
    """Air mendatar: makin gelap ke depan, garis kilau, pantulan bulan."""
    deep, mid, light, high = pal
    for yy in range(int(y0), int(y1) + 1):
        t = (yy - y0) / max(1.0, y1 - y0)
        art.line([(-M, yy), (W + M, yy)], mix(mid, deep, t))
    rng = art.rng
    for _ in range(int((y1 - y0) * W * ripple / 20)):
        yy = rng.uniform(y0 + 1, y1)
        xx = rng.uniform(-M, W + M)
        ln = rng.uniform(3, 14)
        art.line([(xx, yy), (xx + ln, yy)], light if rng.random() < 0.7 else high)
    if moon_x is not None:
        for yy in range(int(y0) + 1, int(y1), 2):
            spread = 3 + (yy - y0) * 0.25
            for _ in range(2):
                xx = moon_x + rng.uniform(-spread, spread)
                art.line([(xx, yy), (xx + rng.uniform(2, 6), yy)], high)


def bamboo_bridge(art, x0, x1, deck_y, sag, pal):
    """Jembatan bambu gantung: lantai bilah, dua tali sandaran, tiang ujung."""
    dark, mid, light, rope = pal
    n = 60
    deck = []
    for i in range(n + 1):
        t = i / n
        deck.append((x0 + (x1 - x0) * t, deck_y + sag * 4 * t * (1 - t)))
    for i in range(n):
        (xa, ya), (xb, yb) = deck[i], deck[i + 1]
        art.poly([(xa, ya), (xb, yb), (xb, yb + 3), (xa, ya + 3)], mid)
        art.line([(xa, ya + 3), (xb, yb + 3)], dark)
        if i % 2 == 0:
            art.line([(xa, ya), (xa, ya + 3)], dark)
        art.line([(xa, ya), (xb, yb)], light)
    for rail_h in (18, 10):
        prev = None
        for i in range(n + 1):
            xa, ya = deck[i]
            pt = (xa, ya - rail_h + sag * 0.15 * 4 * (i / n) * (1 - i / n))
            if prev is not None:
                art.line([prev, pt], rope)
            if i % 5 == 0:
                art.line([pt, (xa, ya)], dark)
            prev = pt
    for px_ in (x0, x1):
        art.rect(px_ - 2, deck_y - 30, px_ + 2, deck_y + 14, mid)
        art.line([(px_ - 2, deck_y - 30), (px_ - 2, deck_y + 14)], light)
        art.rect(px_ - 3, deck_y - 31, px_ + 3, deck_y - 29, dark)


def ilalang(art, y_base, y_top_min, y_top_max, density, pal, wind=6.0, x0=-M, x1=W + M):
    """Padang ilalang: batang tipis melengkung tertiup angin, ujung keperakan."""
    dark, mid, light, tip = pal
    rng = art.rng
    for _ in range(int((x1 - x0) * density)):
        x = rng.uniform(x0, x1)
        top = rng.uniform(y_top_min, y_top_max)
        bend = wind * rng.uniform(0.6, 1.3)
        c = pick(rng, [dark, mid, mid, light])
        prev = (x, y_base)
        for s_ in range(1, 7):
            t = s_ / 6
            pt = (x + bend * t * t, y_base + (top - y_base) * t)
            art.line([prev, pt], c)
            prev = pt
        if rng.random() < 0.45:
            art.line([prev, (prev[0] + 2, prev[1] - 3)], tip)
            art.px(prev[0] + 1, prev[1] - 1, tip)


def dead_tree(art, x, base_y, height, color, light, depth=5, angle=-90.0, width=5.0):
    rng = art.rng

    def branch(x0, y0, length, ang, w, d):
        a = math.radians(ang)
        x1 = x0 + math.cos(a) * length
        y1 = y0 + math.sin(a) * length
        art.line([(x0, y0), (x1, y1)], color, max(1, int(w)))
        if math.cos(a) < 0:
            art.line([(x0 - 1, y0), (x1 - 1, y1)], light)
        if d > 0:
            for da in (rng.uniform(-38, -18), rng.uniform(16, 36)):
                branch(x1, y1, length * rng.uniform(0.6, 0.78), ang + da, w * 0.62, d - 1)

    branch(x, base_y, height * 0.38, angle, width, depth)


def light_shafts(art, specs, color, strength=0.18):
    """Berkas cahaya bulan miring: specs = [(x atas, lebar), ...]."""
    for x_top, width in specs:
        for k, a in ((1.0, strength * 0.5), (0.55, strength * 0.5)):
            w2 = width * k / 2
            art_y = 210
            art_dx = art_y * 0.45
            tint_poly(art, [(x_top - w2, -M), (x_top + w2, -M), (x_top + w2 + art_dx, art_y), (x_top - w2 + art_dx, art_y)], color, a)


def flagstones(art, top_y, pal):
    """Lantai batu pelataran dalam perspektif: baris makin lebar ke depan."""
    base, line_c, light, moss = pal
    art.rect(-M, top_y, W + M, H + M, base)
    y = top_y
    row = 0
    rng = art.rng
    while y < H + M:
        hgt = 4 + row * 2.2
        art.line([(-M, y), (W + M, y)], line_c)
        art.line([(-M, y + 1), (W + M, y + 1)], light)
        step = 26 + row * 9
        off = (step / 2) * (row % 2)
        xx = -M - off
        while xx < W + M:
            # sambungan miring mengikuti titik hilang di tengah
            slope = (xx - W / 2) / 260.0
            art.line([(xx, y), (xx + slope * hgt, y + hgt)], line_c)
            if rng.random() < 0.18:
                art.rect(xx + 2, y + hgt - 2, xx + 2 + rng.integers(3, 8), y + hgt - 1, moss)
            xx += step
        y += hgt
        row += 1


def sesajen(art, x, y, pal):
    """Sesajen: tampah daun pisang berisi bunga, dupa yang berasap."""
    leaf, flower_a, flower_b, smoke = pal
    art.ellipse(x - 9, y - 3, x + 9, y + 2, leaf)
    for k, c in enumerate([flower_a, flower_b, flower_a, flower_b, flower_a]):
        art.px(x - 6 + k * 3, y - 2, c)
        art.px(x - 5 + k * 3, y - 1, c)
    art.line([(x + 6, y - 1), (x + 6, y - 8)], (110, 80, 50))
    art.px(x + 6, y - 9, (255, 150, 80))
    prev = (x + 6, y - 10)
    for k in range(1, 9):
        pt = (x + 6 + math.sin(k * 0.9) * 2, y - 10 - k * 3)
        art.line([prev, pt], smoke)
        prev = pt


# ---------------------------------------------------------------------------
# Tanah
# ---------------------------------------------------------------------------

def ground(art, top_y, pal, path=None, grass=None, stones=True):
    """Tanah tempat berdiri: pita mendatar makin gelap ke depan, tekstur
    tanah berpola, rumput di tepi belakang."""
    far, mid, near, speck_l, speck_d = pal
    xs, ys = art.grid()
    t = np.clip((ys - top_y) / (H - top_y), 0, 1)
    base = np.zeros(xs.shape + (3,), dtype=np.float32)
    stops = [far, mid, near]
    q = t * 6
    lo = np.floor(q)
    idx = (lo + ((q - lo) > art.bayer())) / 6
    for ch in range(3):
        base[..., ch] = np.interp(idx, [0, 0.5, 1], [s[ch] for s in stops])
    a = art.arr()
    mask = ys >= top_y
    a[mask] = base[mask]
    art.put(a)
    rng = art.rng
    for _ in range(900):
        x = rng.uniform(-M, W + M)
        y = rng.uniform(top_y + 2, H + M)
        art.px(x, y, speck_l if rng.random() < 0.45 else speck_d)
        if rng.random() < 0.3:
            art.px(x + 1, y, speck_d)
    if path is not None:
        p_far, p_near, p_light = path
        # jalan tanah yang melebar ke depan
        art.poly([(240, top_y), (420, top_y), (W + 60, H), (-80, H)], p_far)
        art.poly([(270, top_y + 18), (390, top_y + 18), (W, H), (-40, H)], p_near)
        for _ in range(400):
            y = rng.uniform(top_y + 2, H)
            t2 = (y - top_y) / (H - top_y)
            x = rng.uniform(250 - 290 * t2, 410 + 230 * t2)
            art.px(x, y, p_light if rng.random() < 0.5 else shade(p_near, 0.8))
    if stones:
        for _ in range(26):
            x = rng.uniform(-M, W + M)
            y = rng.uniform(top_y + 8, H)
            r = rng.uniform(1.5, 3.5)
            art.ellipse(x - r, y - r * 0.6, x + r, y + r * 0.6, speck_d)
            art.px(x - r * 0.4, y - r * 0.3, speck_l)
    if grass is not None:
        g_d, g_m, g_l = grass
        for x in range(-M, W + M, 2):
            h = rng.integers(2, 8)
            c = pick(rng, [g_d, g_m, g_m, g_l])
            art.line([(x, top_y + 2), (x + rng.integers(-1, 2), top_y + 2 - h)], c)
        art.rect(-M, top_y + 1, W + M, top_y + 3, g_d)


def grass_tufts(art, y_min, y_max, count, pal, tall=(3, 9)):
    g_d, g_m, g_l = pal
    rng = art.rng
    for _ in range(count):
        x = rng.uniform(-M, W + M)
        y = rng.uniform(y_min, y_max)
        for k in range(rng.integers(3, 7)):
            h = rng.uniform(*tall)
            dx = rng.uniform(-3, 3)
            c = g_l if k == 0 else pick(rng, [g_d, g_m])
            art.line([(x + k - 2, y), (x + k - 2 + dx, y - h)], c)


def fog(art, y, height, color, strength=0.35, wave=6.0):
    xs, ys = art.grid()
    centre = y + np.sin(xs / 37.0) * wave + np.sin(xs / 13.0 + 1.2) * wave * 0.3
    d = np.abs(ys - centre) / (height / 2)
    art.blend(np.clip(1 - d, 0, 1) ** 1.3 * strength, color, levels=4)


def vignette(art, strength=0.35, color=(4, 4, 10)):
    xs, ys = art.grid()
    dx = (xs - W / 2) / (W / 2)
    dy = (ys - H * 0.42) / (H * 0.62)
    d = np.sqrt(dx * dx * 0.85 + dy * dy)
    art.blend(np.clip(d - 0.55, 0, 1) ** 1.5 * strength * 2.2, color, levels=4)


# ---------------------------------------------------------------------------
# Babak
# ---------------------------------------------------------------------------

NIGHT_SKY = [(-8, (7, 9, 22)), (60, (14, 18, 42)), (130, (28, 32, 64)), (190, (46, 50, 84))]
TREE_PAL = ((14, 28, 30), (22, 42, 40), (36, 62, 52), (64, 92, 72))
TRUNK = ((44, 34, 30), (70, 56, 46))
HOUSE_PAL = ((50, 34, 32), (88, 62, 50), (36, 24, 24), (82, 64, 48), (60, 46, 36), (46, 34, 28), (255, 196, 112))
DIRT = ((52, 44, 40), (44, 36, 34), (28, 24, 26), (74, 62, 52), (34, 28, 28))
GRASS = ((20, 36, 32), (30, 52, 42), (52, 78, 58))


def stage_1():
    """Pinggir Desa Mejayan: rumah limasan berlampu, gardu ronda dengan
    kentongan, pohon kelapa, pagar bambu, dan Gunung Wilis di kejauhan."""
    art = Art(101)
    sky(art, NIGHT_SKY)
    stars(art, 240, 140)
    moon(art, 86, 52, 14)
    clouds(art, [(205, 74, 110, 4), (450, 40, 90, 3), (585, 84, 120, 4)], (36, 42, 78), (66, 74, 112))
    gunung(art, 420, 84, 190, 560, (24, 28, 54), (46, 54, 92))
    xs, top = ridge(art, 182, 8, [(2, 1.0), (5, 0.5), (11, 0.25)])
    mountain(art, xs, top, (19, 24, 44), (36, 44, 74))
    tree_line(art, 198, 30, (15, 28, 32), (24, 42, 44), (11, 21, 25))
    # kiri: rumah besar dan kelapa
    house(art, 34, 212, 104, 100, HOUSE_PAL)
    lamp_glow(art, 0, 176, 30, (255, 170, 80), 0.34)
    lamp_glow(art, 61, 176, 30, (255, 170, 80), 0.34)
    lamp_glow(art, 34, 196, 26, (255, 170, 80), 0.3)
    coconut(art, 112, 214, 168, 1.1, TRUNK[0], TRUNK[1], (22, 44, 40), (48, 78, 60))
    banana(art, 196, 214, 52, (28, 56, 44), (56, 88, 64), (38, 60, 44))
    # tengah: gardu ronda di ujung jalan
    tree(art, 360, 206, 96, TREE_PAL, *TRUNK, width=104)
    gardu(art, 290, 214, ((54, 38, 32), (92, 66, 50), (96, 72, 50), (60, 44, 32), (255, 200, 120)))
    lamp_glow(art, 281, 196, 30, (255, 170, 80), 0.32)
    # kanan: pohon rindang, rumah, kelapa
    tree(art, 520, 210, 150, TREE_PAL, *TRUNK, width=150)
    house(art, 628, 214, 112, 104, HOUSE_PAL)
    lamp_glow(art, 590, 178, 30, (255, 170, 80), 0.34)
    lamp_glow(art, 628, 198, 26, (255, 170, 80), 0.3)
    coconut(art, 572, 216, 150, -0.9, TRUNK[0], TRUNK[1], (22, 44, 40), (48, 78, 60))
    fence(art, 130, 252, 216, 18, (88, 76, 52), (122, 108, 74), (56, 48, 36))
    fence(art, 322, 470, 216, 16, (88, 76, 52), (122, 108, 74), (56, 48, 36))
    fog(art, 200, 22, (58, 64, 100), 0.2)
    ground(art, 214, DIRT, path=((70, 58, 48), (82, 68, 54), (104, 88, 68)), grass=GRASS)
    grass_tufts(art, 218, 250, 60, GRASS)
    vignette(art, 0.4)
    art.save("stage_1")


BAMBOO_PAL = ((30, 52, 40), (40, 68, 48), (70, 104, 68), (22, 44, 34), (34, 64, 44), (62, 96, 60))
BRICK_PAL = ((92, 52, 44), (60, 34, 32), (130, 82, 62), (46, 26, 26), (52, 78, 48))
ROCK_PAL = ((34, 38, 46), (56, 60, 70), (84, 90, 100), (124, 130, 138))


def stage_2():
    """Rumpun Bambu Wingit: lorong rumpun bambu yang rapat dan melengkung,
    berkas cahaya bulan, dan kabut penyakit kehijauan dari Buto Hijau."""
    art = Art(202)
    sky(art, [(-8, (5, 9, 16)), (70, (10, 22, 28)), (150, (20, 38, 42)), (200, (34, 52, 50))])
    stars(art, 120, 100)
    moon(art, 236, 40, 12, color=(222, 228, 196), halo=(50, 74, 70))
    far = ((16, 30, 26), (20, 36, 30), (30, 48, 38), (14, 28, 24), (18, 34, 28), (28, 46, 36))
    for x in (40, 150, 250, 350, 450, 560, 640):
        bamboo_clump(art, x, 200, art.rng.uniform(110, 150), 9, far, spread=60, lean=0.8)
    tree_line(art, 204, 30, (12, 26, 22), (18, 36, 30), (10, 22, 20))
    light_shafts(art, [(250, 30), (330, 18), (180, 14)], (170, 210, 160), 0.2)
    bamboo_clump(art, 300, 212, 120, 10, BAMBOO_PAL, spread=40, lean=0.7)
    bamboo_clump(art, 20, 216, 250, 16, BAMBOO_PAL, spread=70, lean=1.2)
    bamboo_clump(art, 110, 216, 200, 10, BAMBOO_PAL, spread=40, lean=1.4)
    bamboo_clump(art, 530, 214, 210, 12, BAMBOO_PAL, spread=50, lean=-1.3)
    bamboo_clump(art, 630, 218, 260, 16, BAMBOO_PAL, spread=70, lean=-1.1)
    fog(art, 198, 34, (96, 120, 70), 0.32)
    ground(art, 214, ((40, 40, 30), (32, 32, 26), (22, 22, 20), (92, 84, 52), (26, 26, 22)),
           grass=((22, 40, 30), (32, 56, 40), (66, 92, 56)))
    rng = art.rng
    for _ in range(140):  # daun bambu kering berserakan
        x = rng.uniform(-M, W + M)
        y = rng.uniform(216, 252)
        art.line([(x, y), (x + rng.integers(2, 5), y + rng.integers(-1, 2))], pick(rng, [(110, 96, 58), (86, 76, 46)]))
    for x in (210, 420, 470):  # rebung
        art.poly([(x - 3, 222), (x + 3, 222), (x, 208)], (70, 82, 46))
        art.line([(x - 2, 216), (x + 2, 216)], (46, 58, 34))
    vignette(art, 0.5)
    art.save("stage_2")


def stage_3():
    """Sendang Larangan: kolam mata air yang airnya memerah, pancuran batu,
    beringin tua dengan akar gantung, batu berlumut, dan sesajen."""
    art = Art(303)
    sky(art, NIGHT_SKY)
    stars(art, 200, 120)
    moon(art, 612, 40, 13)
    clouds(art, [(330, 56, 120, 4), (470, 90, 100, 3)], (36, 42, 78), (66, 74, 112))
    xs, top = ridge(art, 150, 10, [(1.5, 1.0), (4, 0.6), (9, 0.3)])
    mountain(art, xs, top, (20, 26, 46), (38, 46, 76))
    tree_line(art, 166, 36, (14, 28, 30), (22, 40, 40), (10, 20, 22))
    tree(art, 540, 168, 110, TREE_PAL, *TRUNK, width=130)
    beringin(art, 86, 216, 200, TREE_PAL, ((52, 42, 36), (84, 70, 56), (34, 28, 26)))
    # tepi seberang kolam
    art.rect(130, 160, W + M, 168, (34, 40, 40))
    x = 140
    while x < W + M:
        r = art.rng.uniform(6, 11)
        boulder(art, x, 166, r, r * 0.55, ((36, 42, 42), (56, 64, 60), (80, 90, 80), (110, 122, 106)))
        x += r * 1.6
    # air sendang: gelap kemerahan, ada pantulan bulan
    water(art, 168, 212, ((40, 12, 20), (70, 24, 34), (130, 66, 70), (220, 186, 170)), moon_x=612, ripple=0.08)
    tint_poly(art, [(130, 168), (W + M, 168), (W + M, 212), (130, 212)], (120, 20, 30), 0.12)
    # pancuran bambu: pipa bambu di atas tiang, airnya jatuh ke kolam
    px_ = 330
    art.rect(px_ + 26, 128, px_ + 30, 168, (78, 62, 46))
    art.line([(px_ + 26, 128), (px_ + 26, 168)], (110, 92, 70))
    art.poly([(px_ - 4, 132), (px_ + 46, 128), (px_ + 46, 132), (px_ - 4, 136)], (96, 112, 70))
    art.line([(px_ - 4, 132), (px_ + 46, 128)], (140, 160, 100))
    for k in range(0, 50, 8):
        art.line([(px_ + k, 132 - k * 0.08), (px_ + k, 135 - k * 0.08)], (66, 80, 50))
    for k in range(36):
        art.px(px_ - 5 + art.rng.uniform(-1, 1), 136 + k * 0.9, (176, 196, 206))
    art.line([(px_ - 5, 136), (px_ - 5, 168)], (140, 160, 176))
    for k in range(6):
        art.line([(px_ - 11 - k * 2, 169 + k % 2), (px_ + 1 + k * 2, 169 + k % 2)], (180, 196, 204))
    boulder(art, px_ + 30, 166, 14, 8, ((36, 42, 42), (56, 64, 60), (80, 90, 80), (110, 122, 106)))
    sesajen(art, px_ + 58, 160, ((50, 84, 46), (240, 220, 120), (230, 90, 90), (150, 150, 170)))
    # bibir kolam di depan
    x = 120
    while x < W + M:
        r = art.rng.uniform(8, 14)
        boulder(art, x, 214, r, r * 0.6, ((40, 46, 44), (62, 70, 64), (88, 98, 86), (120, 132, 114)))
        x += r * 1.5
    boulder(art, 610, 196, 24, 16, ROCK_PAL)
    for x in (200, 470, 620):  # pakis
        for k in range(7):
            a = math.radians(-160 + k * 23)
            art.line([(x, 216), (x + math.cos(a) * 14, 216 + math.sin(a) * 10)], (40, 74, 50))
    fog(art, 196, 24, (90, 70, 90), 0.2)
    ground(art, 216, ((36, 42, 40), (30, 34, 34), (20, 22, 24), (70, 84, 70), (24, 28, 28)),
           grass=((22, 40, 32), (32, 56, 42), (60, 88, 60)))
    vignette(art, 0.45)
    art.save("stage_3")


def stage_4():
    """Gapura Candi Tua: candi bentar dari bata merah di tengah, tembok
    pagar, pohon kamboja berbunga putih, dan jalan batu."""
    art = Art(404)
    sky(art, [(-8, (8, 8, 24)), (70, (20, 18, 48)), (150, (40, 34, 72)), (200, (62, 52, 90))])
    stars(art, 230, 130)
    moon(art, 300, 66, 18, color=(240, 232, 206), halo=(86, 80, 130), halo_a=0.5)
    clouds(art, [(120, 90, 130, 4), (520, 60, 110, 3)], (44, 38, 76), (78, 70, 112))
    tree_line(art, 196, 46, (16, 22, 34), (26, 32, 48), (12, 16, 24))
    # tembok pagar bata
    for side in (-1, 1):
        x0, x1 = (-M, 248) if side < 0 else (352, W + M)
        bricks(art, x0, 176, x1, 214, BRICK_PAL[0], BRICK_PAL[1])
        art.rect(x0, 172, x1, 176, BRICK_PAL[2])
        art.line([(x0, 177), (x1, 177)], BRICK_PAL[3])
        for k in range(int(x0), int(x1), 40):
            art.rect(k, 164, k + 8, 176, BRICK_PAL[0])
            art.rect(k, 162, k + 8, 164, BRICK_PAL[2])
    candi_bentar(art, 300, 216, 170, 74, 40, BRICK_PAL)
    # kamboja
    for (x, h) in ((60, 110), (560, 120)):
        trunk(art, x, 214 - h * 0.5, 214, 7, (66, 56, 50), (96, 84, 72), lean=4)
        for k in range(3):
            art.line([(x + 2, 214 - h * 0.5), (x - 26 + k * 26, 214 - h * 0.75)], (66, 56, 50), 3)
        foliage(art, x, 214 - h * 0.82, 46, 26, ((18, 34, 30), (28, 52, 40), (44, 74, 52), (70, 100, 70)))
        for _ in range(40):
            fx = x + art.rng.uniform(-44, 44)
            fy = 214 - h * 0.82 + art.rng.uniform(-24, 18)
            art.px(fx, fy, (236, 232, 214))
            art.px(fx + 1, fy, (240, 214, 120))
    fog(art, 204, 18, (70, 60, 100), 0.18)
    flagstones(art, 216, ((54, 50, 56), (36, 32, 40), (74, 70, 76), (48, 66, 44)))
    vignette(art, 0.45)
    art.save("stage_4")


def stage_5():
    """Tegal Ilalang: padang ilalang luas di bawah langit yang memerah oleh
    murka Buto, pohon randu menyendiri, dan Gunung Wilis."""
    art = Art(505)
    sky(art, [(-8, (10, 8, 22)), (60, (24, 16, 40)), (130, (60, 30, 52)), (190, (112, 50, 56))])
    stars(art, 150, 90)
    moon(art, 120, 46, 12, color=(236, 214, 190), halo=(110, 60, 70))
    clouds(art, [(300, 60, 160, 4), (520, 96, 140, 5), (80, 110, 120, 4)], (70, 32, 50), (120, 60, 70))
    gunung(art, 360, 104, 192, 600, (38, 22, 40), (80, 44, 60))
    xs, top = ridge(art, 186, 6, [(3, 1.0), (7, 0.4)])
    mountain(art, xs, top, (28, 18, 32), (60, 36, 50))
    # pohon randu menyendiri
    for (x, h) in ((230, 70), (470, 54)):
        art.rect(x - 2, 186 - h, x + 1, 188, (24, 16, 24))
        for k, (dx, dy) in enumerate(((-20, -0.8), (18, -0.7), (-12, -1.0), (14, -0.95))):
            art.line([(x, 188 - h * 0.6 - k * 4), (x + dx, 188 - h * abs(dy))], (24, 16, 24), 2)
            art.ellipse(x + dx - 9, 188 - h * abs(dy) - 4, x + dx + 9, 188 - h * abs(dy) + 2, (26, 18, 26))
    ilalang(art, 200, 168, 186, 3.0, ((50, 34, 40), (70, 48, 50), (110, 80, 72), (190, 160, 140)), wind=7)
    ilalang(art, 214, 160, 188, 2.6, ((40, 30, 34), (62, 44, 44), (104, 76, 66), (210, 180, 150)), wind=9)
    ground(art, 214, ((56, 42, 40), (44, 34, 34), (28, 22, 26), (90, 70, 60), (34, 26, 28)),
           grass=((50, 38, 38), (72, 54, 48), (124, 96, 80)))
    ilalang(art, 222, 176, 206, 1.4, ((36, 26, 30), (56, 40, 40), (96, 72, 62), (200, 170, 140)), wind=10, x0=-M, x1=110)
    ilalang(art, 222, 176, 206, 1.4, ((36, 26, 30), (56, 40, 40), (96, 72, 62), (200, 170, 140)), wind=10, x0=560, x1=W + M)
    fog(art, 190, 26, (140, 70, 70), 0.16)
    vignette(art, 0.45)
    art.save("stage_5")


def stage_6():
    """Alas Jati Peteng: hutan jati gelap dan lembap, batang-batang lurus
    tinggi, daun lebar menutup langit, kabut racun hijau."""
    art = Art(606)
    sky(art, [(-8, (4, 8, 10)), (100, (10, 20, 20)), (200, (20, 34, 30))])
    stars(art, 40, 60)
    leaf_far = ((12, 24, 20), (18, 32, 26), (26, 44, 32), (40, 60, 42))
    for k in range(16):  # batang jauh
        x = -M + k * 44 + art.rng.uniform(-12, 12)
        art.rect(x, 20, x + 4, 210, (18, 26, 24))
        art.line([(x, 20), (x, 210)], (24, 34, 30))
    foliage(art, 160, 30, 200, 50, leaf_far, 60)
    foliage(art, 520, 26, 220, 50, leaf_far, 60)
    light_shafts(art, [(250, 24), (330, 14)], (140, 190, 140), 0.18)
    leaf = ((14, 30, 22), (22, 44, 30), (36, 66, 42), (62, 94, 60))
    for (x, h) in ((24, 260), (96, 240), (250, 220), (376, 230), (530, 250), (616, 260)):
        teak(art, x, 216, h, (58, 50, 42), (90, 80, 66), (40, 34, 30), leaf)
    foliage(art, 60, 10, 140, 40, leaf, 40)
    foliage(art, 580, 6, 150, 42, leaf, 40)
    fog(art, 200, 36, (70, 130, 70), 0.3, wave=4)
    ground(art, 214, ((36, 34, 26), (28, 26, 22), (18, 18, 16), (96, 74, 44), (24, 22, 18)),
           grass=((18, 34, 24), (28, 50, 32), (52, 80, 48)))
    rng = art.rng
    for _ in range(70):  # daun jati kering
        x = rng.uniform(-M, W + M)
        y = rng.uniform(218, 252)
        c = pick(rng, [(70, 52, 32), (58, 44, 30), (84, 62, 38)])
        art.ellipse(x - 3, y - 1, x + 3, y + 1, c)
        art.line([(x - 2, y), (x + 2, y)], shade(c, 0.75))
    for x in (180, 330, 450):  # pakis
        for k in range(9):
            a = math.radians(-170 + k * 20)
            art.line([(x, 220), (x + math.cos(a) * 16, 220 + math.sin(a) * 12)], (30, 62, 40))
    vignette(art, 0.6)
    art.save("stage_6")


def stage_7():
    """Kali Watu: sungai lebar yang deras di antara tebing berbatu, batu-batu
    besar yang retak dihantam Buto Merah."""
    art = Art(707)
    sky(art, NIGHT_SKY)
    stars(art, 180, 100)
    moon(art, 150, 46, 13)
    clouds(art, [(380, 58, 140, 4), (560, 34, 90, 3)], (36, 42, 78), (66, 74, 112))
    xs, top = ridge(art, 110, 18, [(1.5, 1.0), (3.5, 0.5), (9, 0.25)])
    mountain(art, xs, top, (24, 28, 44), (46, 52, 74))
    # tebing seberang
    xs, top = ridge(art, 140, 10, [(3, 1.0), (8, 0.6), (17, 0.3)])
    mountain(art, xs, top, (40, 42, 52), (78, 82, 96), bottom=160)
    for _ in range(40):
        x = art.rng.uniform(-M, W + M)
        y = art.rng.uniform(140, 158)
        art.line([(x, y), (x + art.rng.uniform(3, 9), y + art.rng.uniform(1, 4))], (30, 32, 40))
    tree_line(art, 136, 26, (16, 28, 30), (24, 40, 40), (12, 22, 24))
    # sungai
    water(art, 158, 210, ((20, 32, 54), (44, 66, 98), (110, 140, 170), (210, 226, 236)), moon_x=150, ripple=0.14)
    rng = art.rng
    for _ in range(140):  # buih arus deras
        x = rng.uniform(-M, W + M)
        y = rng.uniform(160, 208)
        ln = rng.uniform(4, 16)
        art.line([(x, y), (x + ln, y + rng.uniform(-1, 1))], pick(rng, [(170, 196, 214), (210, 226, 236)]))
    for (x, y, rx, ry, cr) in ((180, 174, 18, 11, True), (330, 170, 24, 14, True), (450, 180, 14, 9, False),
                               (250, 196, 20, 12, False), (520, 200, 22, 13, True)):
        boulder(art, x, y, rx, ry, ROCK_PAL, crack=cr)
        for k in range(-int(rx), int(rx), 3):
            art.px(x + k, y + ry * 0.35 + 1, (200, 218, 230))
    # batu besar di tepi kiri dan kanan
    boulder(art, 30, 196, 58, 40, ROCK_PAL, crack=True)
    boulder(art, 610, 194, 64, 44, ROCK_PAL, crack=True)
    boulder(art, 90, 210, 26, 16, ROCK_PAL)
    boulder(art, 560, 212, 30, 18, ROCK_PAL)
    ground(art, 212, ((50, 52, 58), (40, 42, 48), (26, 28, 32), (96, 100, 108), (30, 32, 36)),
           grass=((26, 40, 36), (36, 54, 46), (64, 86, 70)))
    for _ in range(40):  # kerikil dan pecahan batu
        x = rng.uniform(-M, W + M)
        y = rng.uniform(216, 252)
        r = rng.uniform(2, 5)
        boulder(art, x, y, r * 1.4, r, ROCK_PAL)
    fog(art, 166, 16, (90, 110, 140), 0.16)
    vignette(art, 0.45)
    art.save("stage_7")


def stage_8():
    """Jembatan Pring: jembatan bambu gantung di atas jurang sungai, cahaya
    bulan pucat yang dingin, rumpun bambu di kedua tebing."""
    art = Art(808)
    sky(art, [(-8, (12, 14, 26)), (70, (28, 32, 52)), (150, (58, 64, 88)), (200, (86, 92, 112))])
    stars(art, 160, 100)
    moon(art, 250, 50, 22, color=(242, 244, 236), halo=(120, 130, 160), halo_a=0.55)
    clouds(art, [(170, 46, 140, 4), (520, 84, 130, 4)], (70, 76, 102), (120, 126, 150))
    xs, top = ridge(art, 140, 16, [(1.2, 1.0), (3, 0.6), (7, 0.3)])
    mountain(art, xs, top, (44, 50, 72), (80, 88, 110))
    xs, top = ridge(art, 162, 8, [(2, 1.0), (6, 0.5)])
    mountain(art, xs, top, (34, 38, 58), (62, 68, 92))
    # jurang: tebing dalam, sungai jauh di bawah
    art.rect(-M, 168, W + M, 214, (22, 24, 38))
    water(art, 200, 212, ((18, 22, 36), (30, 38, 58), (84, 98, 124), (196, 206, 222)), moon_x=250)
    for side in (-1, 1):
        edge = 130 if side < 0 else 510
        outer = -M if side < 0 else W + M
        art.poly([(outer, 150), (edge, 156), (edge + side * 30, 214), (outer, 214)], (46, 48, 60))
        art.poly([(outer, 150), (edge, 156), (edge + side * 8, 166), (outer, 162)], (64, 68, 80))
        art.line([(outer, 150), (edge, 156)], (110, 116, 130))
        for k in range(10):
            yy = 170 + k * 4
            art.line([(edge + side * (6 + k * 2.5), yy), (edge + side * (14 + k * 2.5), yy + 3)], (34, 36, 48))
    fog(art, 188, 30, (150, 160, 190), 0.32)
    bamboo_bridge(art, 132, 508, 152, 24, ((70, 74, 60), (118, 124, 94), (168, 172, 134), (140, 128, 96)))
    pale_bamboo = ((50, 64, 58), (64, 82, 70), (110, 130, 110), (40, 56, 50), (56, 76, 62), (100, 122, 98))
    bamboo_clump(art, 40, 214, 230, 14, pale_bamboo, spread=70, lean=1.2)
    bamboo_clump(art, 108, 214, 170, 8, pale_bamboo, spread=34, lean=1.4)
    bamboo_clump(art, 540, 214, 180, 9, pale_bamboo, spread=36, lean=-1.4)
    bamboo_clump(art, 610, 214, 240, 14, pale_bamboo, spread=70, lean=-1.2)
    ground(art, 214, ((52, 54, 60), (40, 42, 50), (26, 28, 34), (100, 104, 112), (32, 34, 40)),
           grass=((32, 46, 44), (46, 62, 56), (90, 110, 98)))
    grass_tufts(art, 218, 250, 50, ((32, 46, 44), (46, 62, 56), (90, 110, 98)))
    vignette(art, 0.4)
    art.save("stage_8")


def stage_9():
    """Pelataran Candi: lantai batu luas, empat candi perwara di belakang,
    candi induk di kejauhan, obor-obor menyala di bawah langit merah."""
    art = Art(909)
    sky(art, [(-8, (10, 6, 16)), (60, (30, 12, 28)), (130, (70, 22, 40)), (200, (120, 40, 48))])
    stars(art, 90, 80, color=(230, 200, 210))
    moon(art, 240, 40, 14, color=(240, 196, 180), halo=(130, 50, 60))
    clouds(art, [(120, 50, 160, 5), (360, 84, 150, 4), (560, 110, 110, 4)], (60, 22, 36), (110, 46, 56))
    tree_line(art, 184, 34, (24, 12, 20), (38, 18, 28), (16, 8, 14))
    dark_brick = ((76, 40, 40), (46, 24, 28), (116, 66, 56), (34, 18, 22), (50, 60, 40))
    candi(art, 320, 190, 120, 150, dark_brick, door=(150, 40, 30))
    for (x, sc) in ((60, 0.72), (200, 0.62), (440, 0.62), (580, 0.72)):
        candi(art, x, 214, 90 * sc, 130 * sc, BRICK_PAL, tiers=4)
    for x in (130, 260, 380, 510):
        torch(art, x, 214, 40, (70, 50, 36), (255, 150, 60), (255, 200, 120))
        lamp_glow(art, x, 170, 34, (255, 120, 50), 0.36)
    fog(art, 200, 20, (130, 50, 50), 0.2)
    flagstones(art, 216, ((70, 54, 54), (44, 32, 36), (92, 74, 70), (60, 64, 44)))
    vignette(art, 0.45)
    art.save("stage_9")


def stage_10():
    """Candi Pagebluk: candi induk menjulang dengan pintu menyala merah,
    langit ungu-merah berawan pekat, pohon mati, dan kabut pagebluk."""
    art = Art(1010)
    sky(art, [(-8, (8, 4, 14)), (60, (30, 8, 34)), (130, (70, 16, 50)), (200, (110, 28, 54))])
    stars(art, 50, 60, color=(220, 180, 210))
    moon(art, 116, 48, 20, color=(210, 80, 80), halo=(120, 20, 50), halo_a=0.6)
    clouds(art, [(80, 40, 200, 6), (300, 70, 220, 6), (560, 30, 160, 5), (480, 110, 180, 5), (150, 120, 140, 4)],
           (40, 12, 34), (90, 30, 60), shadow=(26, 6, 22))
    xs, top = ridge(art, 180, 14, [(2, 1.0), (5, 0.5)])
    mountain(art, xs, top, (26, 8, 24), (60, 20, 44))
    hitam_brick = ((60, 30, 38), (36, 16, 24), (98, 50, 58), (24, 10, 18), (58, 40, 70))
    candi(art, 320, 214, 200, 176, hitam_brick, door=(200, 40, 50), tiers=6)
    lamp_glow(art, 320, 186, 56, (230, 40, 60), 0.4)
    for (x, h) in ((40, 170), (130, 120), (520, 130), (610, 180)):
        dead_tree(art, x, 216, h, (30, 16, 26), (70, 40, 60), depth=5, width=6)
    for x in (200, 440):
        torch(art, x, 214, 36, (50, 30, 34), (220, 70, 200), (255, 200, 240))
        lamp_glow(art, x, 174, 30, (180, 60, 200), 0.34)
    fog(art, 204, 40, (120, 40, 130), 0.36, wave=8)
    fog(art, 150, 30, (90, 30, 90), 0.16, wave=12)
    ground(art, 216, ((46, 26, 40), (36, 20, 32), (22, 12, 20), (90, 50, 80), (28, 14, 24)),
           grass=((30, 18, 30), (44, 26, 40), (80, 50, 70)))
    rng = art.rng
    for _ in range(14):  # retakan tanah
        x = rng.uniform(-M, W + M)
        y = rng.uniform(222, 252)
        for _ in range(4):
            nx, ny = x + rng.uniform(-8, 8), y + rng.uniform(-1, 4)
            art.line([(x, y), (nx, ny)], (16, 6, 14))
            x, y = nx, ny
    vignette(art, 0.5)
    art.save("stage_10")


def menu():
    """Menu utama: candi di bawah bulan purnama. Kaki Eyang Palang dan Buto
    Hitam di y=330, dan sisi kiri digelapkan oleh menu sendiri."""
    art = Art(1111)
    sky(art, [(-8, (6, 6, 18)), (90, (18, 16, 44)), (200, (40, 32, 70)), (300, (70, 46, 80))], bands=12)
    stars(art, 300, 200)
    moon(art, 470, 90, 26, halo=(90, 84, 140), halo_a=0.5)
    clouds(art, [(250, 120, 200, 5), (560, 160, 150, 4), (380, 60, 120, 3)], (40, 34, 74), (80, 72, 116))
    gunung(art, 300, 150, 290, 700, (24, 22, 50), (50, 48, 86))
    tree_line(art, 300, 50, (14, 18, 30), (24, 28, 44), (10, 12, 22))
    candi(art, 560, 316, 210, 250, BRICK_PAL, door=(120, 40, 30), tiers=7)
    lamp_glow(art, 560, 280, 50, (220, 90, 60), 0.3)
    for (x, h) in ((380, 120), (640, 140)):
        tree(art, x, 318, h, TREE_PAL, *TRUNK, width=h * 0.9)
    fog(art, 300, 36, (70, 60, 110), 0.26)
    flagstones(art, 318, ((50, 46, 56), (32, 28, 38), (70, 66, 76), (44, 60, 42)))
    vignette(art, 0.4)
    art.save("menu")


def ending():
    """Ending: Desa Mejayan saat fajar. Pagebluk sudah sirna, langit
    menghangat, lampu rumah padam satu per satu."""
    art = Art(1212)
    sky(art, [(-8, (40, 46, 90)), (60, (90, 90, 140)), (120, (200, 140, 150)), (170, (250, 186, 140)), (200, (255, 214, 160))])
    stars(art, 30, 50, color=(220, 220, 240))
    art.circle(330, 196, 26, (255, 236, 190))
    lamp_glow(art, 330, 196, 120, (255, 200, 140), 0.45)
    clouds(art, [(120, 80, 160, 5), (440, 110, 180, 5), (560, 60, 120, 4)], (210, 150, 160), (255, 214, 190), shadow=(170, 116, 140))
    gunung(art, 420, 92, 192, 560, (96, 80, 120), (150, 120, 150))
    xs, top = ridge(art, 184, 8, [(2, 1.0), (5, 0.5), (11, 0.25)])
    mountain(art, xs, top, (70, 64, 96), (110, 96, 126))
    tree_line(art, 200, 30, (40, 52, 60), (60, 76, 74), (30, 40, 48))
    dawn_tree = ((30, 44, 46), (44, 64, 58), (70, 94, 74), (120, 140, 100))
    dawn_house = ((80, 54, 48), (130, 92, 72), (56, 38, 36), (124, 98, 74), (94, 72, 56), (70, 52, 42), (255, 214, 150))
    house(art, 34, 212, 104, 100, dawn_house, lit=False)
    coconut(art, 112, 214, 168, 1.1, (70, 54, 46), (110, 90, 70), (40, 66, 54), (90, 120, 90))
    tree(art, 520, 210, 150, dawn_tree, (70, 54, 46), (110, 90, 70), width=150)
    house(art, 628, 214, 112, 104, dawn_house, lit=False)
    coconut(art, 572, 216, 150, -0.9, (70, 54, 46), (110, 90, 70), (40, 66, 54), (90, 120, 90))
    fence(art, 130, 252, 216, 18, (130, 110, 80), (180, 160, 120), (90, 76, 56))
    fence(art, 380, 470, 216, 16, (130, 110, 80), (180, 160, 120), (90, 76, 56))
    fog(art, 200, 26, (255, 220, 190), 0.22)
    ground(art, 214, ((100, 82, 66), (84, 68, 56), (60, 48, 42), (140, 118, 92), (70, 56, 48)),
           path=((122, 100, 80), (136, 112, 88), (170, 144, 112)), grass=((50, 76, 56), (70, 100, 70), (120, 150, 100)))
    grass_tufts(art, 218, 250, 60, ((50, 76, 56), (70, 100, 70), (120, 150, 100)))
    vignette(art, 0.25, color=(40, 20, 30))
    art.save("ending")


SCENES = {
    "stage_1": stage_1,
    "stage_2": stage_2,
    "stage_3": stage_3,
    "stage_4": stage_4,
    "stage_5": stage_5,
    "stage_6": stage_6,
    "stage_7": stage_7,
    "stage_8": stage_8,
    "stage_9": stage_9,
    "stage_10": stage_10,
    "menu": menu,
    "ending": ending,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    names = sys.argv[1:] or list(SCENES)
    for name in names:
        SCENES[name]()


if __name__ == "__main__":
    main()
