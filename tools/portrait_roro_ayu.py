"""Potret dialog Roro Ayu (80x80, setengah badan), dipanggil dari tools/build_assets.py.

Rujukan utamanya adalah desain sprite diam Roro Ayu dari pemilik proyek: wajah
menyamping menghadap kanan, kulit sawo matang, rambut hitam disisir ke belakang
dengan sanggul bulat di tengkuk dan hiasan cunduk emas, subang emas, kebaya
hijau terang berlis emas dengan motif belah ketupat emas di dada, dan selendang
(sampur) jingga-merah bertepi kuning di bahu. Warnanya diambil dari desain itu.

Sebelumnya juga dipakai rujukan topeng Roro Ayu di Dongkrek (cantik, tatapan
sendu, senyum tipis) dan teknik potret piksel ala GBA (shading menggerombol
dengan 4-6 warna per bahan, bayangan bergeser warna).

Caranya: setiap bagian (sanggul, badan, selendang, leher, rambut, wajah,
telinga) dibentuk 8x lebih besar, diperkecil jadi cakupan per piksel, lalu
diwarnai bertingkat menurut arah cahaya (kiri atas). Piksel tunggal yang
menyendiri dibuang supaya bayangannya rapi. Mata, alis, bibir, cunduk, subang,
dan lis kebaya kemudian ditempel per piksel.
"""
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

S = 8
W = 80
OUTLINE = (30, 18, 32)

# Ramp warna, gelap -> terang, diambil dari desain sprite diam Roro Ayu.
SKIN = [(140, 82, 66), (176, 114, 86), (202, 142, 104), (218, 160, 122), (232, 180, 140), (246, 206, 168)]
HAIR = [(8, 8, 16), (20, 20, 32), (34, 34, 48), (54, 54, 70), (86, 86, 106)]
KEBAYA = [(22, 62, 34), (38, 104, 52), (58, 142, 62), (90, 172, 76), (136, 202, 98)]
KEBAYA_IN = [(14, 44, 26), (26, 76, 40), (40, 104, 52)]
SAMPUR = [(96, 32, 24), (136, 48, 30), (176, 66, 38), (200, 86, 46), (224, 120, 64)]
GOLD = [(136, 84, 38), (194, 136, 64), (226, 174, 96), (252, 222, 152)]
RUBY = (190, 40, 46)
LIGHT = (-0.72, -0.62)  # cahaya dari kiri atas


def P(pts):
    return [(x * S, y * S) for x, y in pts]


def E(cx, cy, rx, ry):
    return [(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S]


def big_mask(fn):
    m = Image.new("L", (W * S, W * S), 0)
    fn(ImageDraw.Draw(m))
    return m


def smooth_poly(pts, steps=6):
    """Kurva Catmull-Rom tertutup lewat titik-titik kendali."""
    out = []
    n = len(pts)
    for i in range(n):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        for k in range(steps):
            t = k / steps
            t2, t3 = t * t, t * t * t
            x = 0.5 * (2 * p1[0] + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * (2 * p1[1] + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((x, y))
    return out


def down(mask_big):
    """Mask besar -> cakupan 0..1 per piksel akhir."""
    return np.asarray(mask_big.resize((W, W), Image.BOX)).astype(np.float64) / 255.0


def blur(mask_big, r):
    return down(mask_big.filter(ImageFilter.GaussianBlur(r * S)))


YY, XX = np.mgrid[0:W, 0:W].astype(np.float64) + 0.5


def light_field(cx, cy, spread):
    """1 di sisi yang menghadap cahaya, 0 di sisi seberang."""
    lx, ly = LIGHT
    d = -((XX - cx) * lx + (YY - cy) * ly) / spread
    return np.clip(0.5 - 0.5 * d, 0.0, 1.0)


class Canvas:
    def __init__(self):
        self.rgb = np.zeros((W, W, 3), dtype=np.float64)
        self.alpha = np.zeros((W, W), dtype=bool)
        self.region = np.full((W, W), -1, dtype=np.int32)
        self.level = np.zeros((W, W), dtype=np.int32)
        self.ramps = []

    def fill(self, cover, value, ramp, thresholds=None):
        """Mengisi piksel yang tertutup >= 50% dengan warna ramp sesuai nilai terang (0..1)."""
        rid = len(self.ramps)
        self.ramps.append(ramp)
        m = cover >= 0.5
        n = len(ramp)
        if thresholds is None:
            thresholds = [(i + 1) / n for i in range(n - 1)]
        lvl = np.zeros((W, W), dtype=np.int32)
        for t in thresholds:
            lvl += (value >= t).astype(np.int32)
        self.region[m] = rid
        self.level[m] = lvl[m]
        self.alpha |= m
        return m

    def clean(self):
        """Buang piksel tunggal yang berbeda dari keempat tetangganya (agar shading menggerombol)."""
        lv = self.level.copy()
        for y in range(1, W - 1):
            for x in range(1, W - 1):
                r = self.region[y, x]
                if r < 0:
                    continue
                nb = [(y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)]
                if any(self.region[a, b] != r for a, b in nb):
                    continue
                vals = [self.level[a, b] for a, b in nb]
                if all(v != self.level[y, x] for v in vals) and len(set(vals)) == 1:
                    lv[y, x] = vals[0]
        self.level = lv

    def image(self):
        out = np.zeros((W, W, 4), dtype=np.uint8)
        for y in range(W):
            for x in range(W):
                r = self.region[y, x]
                if r >= 0:
                    out[y, x, :3] = self.ramps[r][self.level[y, x]]
                    out[y, x, 3] = 255
        return Image.fromarray(out, "RGBA").copy()


# ---------------------------------------------------------------------------
# Bentuk (koordinat piksel akhir 80x80)
# ---------------------------------------------------------------------------

# Wajah menyamping ke kanan: dahi, hidung, bibir, dan dagu membentuk garis tepi kanan.
FACE = [(52.4, 13.8), (54.8, 17.2), (56.0, 22.4), (55.8, 25.4), (57.2, 28.2), (58.8, 30.8), (60.2, 32.8),
        (59.0, 34.0), (57.2, 34.8), (56.8, 35.6), (57.6, 37.0), (56.4, 38.2), (57.2, 39.6), (55.6, 41.2), (56.0, 43.2), (54.4, 45.2),
        (50.6, 46.0), (46.6, 43.6), (43.4, 39.6), (41.6, 33.0), (43.6, 22.6), (47.0, 16.2)]
# rambut disisir ke belakang, menutupi kepala sampai tengkuk
HEAD = [(52.4, 13.8), (50.2, 10.0), (45.0, 7.0), (38.0, 6.6), (31.0, 9.4), (26.4, 15.0), (25.0, 22.0),
        (26.0, 30.0), (30.0, 36.4), (36.0, 40.6), (41.6, 40.2), (41.4, 31.0), (43.6, 22.6), (47.0, 16.2)]
EAR = [(42.4, 28.6), (44.6, 28.2), (45.8, 30.8), (45.6, 34.4), (44.2, 36.4), (42.6, 35.6), (41.8, 31.8)]
NECK = [(39.4, 38.0), (50.0, 44.0), (49.4, 50.0), (50.2, 58.0), (37.4, 58.0), (38.6, 48.0)]
BUN = (26.8, 29.2, 9.4, 8.8)
# Bahu landai, badan sedikit menghadap penonton; selendang di bahu dekat.
BODY = [(34.6, 55.6), (52.6, 55.8), (59.6, 58.2), (64.0, 62.0), (65.4, 68.0), (65.6, 80),
        (13.2, 80), (13.6, 70.0), (15.6, 64.6), (21.0, 60.0), (28.0, 57.2)]
SAMPUR_SHAPE = [(26.0, 57.6), (34.8, 55.6), (35.4, 59.0), (31.6, 70.0), (30.0, 80), (17.6, 80), (18.6, 70.0),
                (20.4, 61.0)]
VNECK = [(37.6, 56.0), (51.2, 56.2), (49.4, 61.6), (46.8, 65.6), (44.2, 61.6)]
BEF = [(43.0, 64.6), (51.0, 64.2), (51.8, 80), (42.2, 80)]


def build_base() -> Canvas:
    c = Canvas()

    # sanggul bulat di tengkuk
    bx, by, brx, bry = BUN
    bun = big_mask(lambda d: d.ellipse(E(bx, by, brx, bry), fill=255))
    v = light_field(bx - 2, by - 3, 9.0) * 0.8 + 0.2 * blur(bun, 1.6)
    c.fill(down(bun), v, HAIR, [0.3, 0.52, 0.74, 0.92])

    # leher jenjang, bayangan di bawah rahang
    neck = big_mask(lambda d: d.polygon(P(smooth_poly(NECK, 4)), fill=255))
    jaw_big = big_mask(lambda d: d.polygon(P(smooth_poly(FACE, 6)), fill=255))
    jaw = blur(jaw_big.transform(jaw_big.size, Image.AFFINE, (1, 0, 0, 0, 1, -2.0 * S)), 1.2)
    v = light_field(42, 50, 10.0) * 0.8 + 0.2 * blur(neck, 1.4) - 0.3 * jaw
    c.fill(down(neck), v, SKIN, [0.12, 0.3, 0.5, 0.78, 0.97])

    # badan berkebaya hijau, sedikit bentuk dada
    body = big_mask(lambda d: d.polygon(P(smooth_poly(BODY, 4)), fill=255))
    bust = blur(big_mask(lambda d: d.ellipse(E(39.0, 70.5, 7.0, 4.6), fill=255)), 1.4)
    under = blur(big_mask(lambda d: d.chord(E(39.0, 74.5, 7.5, 4.0), 0, 180, fill=255)), 1.0)
    v = light_field(34, 66, 22.0) * 0.72 + 0.28 * blur(body, 1.8) + 0.1 * bust - 0.16 * under
    c.fill(down(body), v, KEBAYA, [0.3, 0.46, 0.64, 0.84])

    # dada di leher kebaya dan panel dalam berwarna hijau tua
    vneck = big_mask(lambda d: d.polygon(P(VNECK), fill=255))
    v = light_field(44, 58, 8.0) * 0.8 + 0.2 * blur(vneck, 1.0)
    c.fill(down(vneck), v, SKIN, [0.1, 0.28, 0.5, 0.8, 0.98])
    bef = big_mask(lambda d: d.polygon(P(BEF), fill=255))
    v = light_field(46, 72, 12.0) * 0.7 + 0.3 * blur(bef, 1.0)
    c.fill(down(bef), v, KEBAYA_IN, [0.4, 0.75])

    # selendang (sampur) di bahu dekat
    sampur = big_mask(lambda d: d.polygon(P(smooth_poly(SAMPUR_SHAPE, 4)), fill=255))
    v = light_field(24, 64, 10.0) * 0.7 + 0.3 * blur(sampur, 1.2)
    c.fill(down(sampur), v, SAMPUR, [0.26, 0.44, 0.64, 0.86])

    # rambut
    head = big_mask(lambda d: d.polygon(P(smooth_poly(HEAD, 6)), fill=255))
    v = light_field(36, 14, 15.0) * 0.8 + 0.2 * blur(head, 2.0)
    c.fill(down(head), v, HAIR, [0.3, 0.52, 0.74, 0.92])

    # wajah menyamping: pipi disinari, bagian belakang rahang lebih gelap
    face_big = big_mask(lambda d: d.polygon(P(smooth_poly(FACE, 6)), fill=255))
    v = light_field(48, 30, 13.0) * 0.6 + 0.4 * blur(face_big, 1.6)
    hairline = blur(big_mask(lambda d: d.polygon(P(smooth_poly(HEAD, 6)), fill=255)).transform(
        face_big.size, Image.AFFINE, (1, 0, -1.2 * S, 0, 1, -1.2 * S)), 0.9)
    cheek = blur(big_mask(lambda d: d.ellipse(E(51.0, 33.0, 3.6, 3.0), fill=255)), 1.0)
    jaw_back = blur(big_mask(lambda d: d.polygon(P([(41, 33), (45, 39), (49, 46), (41, 46)]), fill=255)), 1.0)
    v = v - 0.35 * hairline + 0.16 * cheek - 0.28 * jaw_back
    c.fill(down(face_big), v, SKIN, [0.12, 0.28, 0.46, 0.7, 0.9])

    # telinga
    ear = big_mask(lambda d: d.polygon(P(smooth_poly(EAR, 4)), fill=255))
    v = light_field(43, 31, 4.0) * 0.6 + 0.4 * blur(ear, 0.8)
    c.fill(down(ear), v, SKIN, [0.15, 0.36, 0.56, 0.84, 0.99])

    c.clean()
    return c


LASH = (30, 16, 22)
WHITE = (244, 238, 230)
IRIS = (52, 28, 22)
IRIS_L = (112, 66, 40)
SHINE = (255, 255, 255)
BROW = (40, 26, 26)
BROW_L = (96, 62, 50)
SHADOW_LID = (196, 136, 104)
LIP_LINE = (110, 30, 34)
LIP_UP = (160, 46, 48)
LIP_LO = (196, 74, 70)
LIP_HI = (226, 128, 110)
BLUSH = (226, 146, 116)


def polyline(px, points, color, where=None):
    """Garis piksel lewat titik-titik; `where(x, y)` bisa membatasi piksel mana yang boleh diwarnai."""
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for k in range(n + 1):
            x = round(x0 + (x1 - x0) * k / n)
            y = round(y0 + (y1 - y0) * k / n)
            if 0 <= x < W and 0 <= y < W and (where is None or where(x, y)):
                px[x, y] = color + (255,)


def stamp(px, x0, y0, rows, colors):
    """Menempel pola huruf: tiap huruf = satu warna, '.' = biarkan."""
    for dy, row in enumerate(rows):
        for dx, ch in enumerate(row):
            if ch != ".":
                px[x0 + dx, y0 + dy] = colors[ch] + (255,)


def details(img: Image.Image, c: Canvas) -> Image.Image:
    px = img.load()

    def skin(x, y, level):
        px[x, y] = SKIN[level] + (255,)

    # --- alis tegas yang sedikit melengkung, mata menyamping dengan bulu mata lentik
    stamp(px, 49, 23, [
        "..dddd.",
        ".d....b",
        "b......",
    ], {"d": BROW, "b": BROW_L})
    stamp(px, 48, 26, [
        "L.cccc..",
        ".LLLLLL.",
        "..LwHIw.",
        "...lii..",
    ], {"c": SHADOW_LID, "L": LASH, "w": WHITE, "H": SHINE, "I": IRIS, "i": IRIS_L, "l": SKIN[2]})
    # cuping hidung dan bayangan di bawahnya
    skin(57, 32, 2)
    skin(57, 33, 1)
    skin(56, 34, 2)

    # bibir merah mengikuti garis tepi wajah di tiap baris, senyum tipis di sudut
    def edge(y):
        xs = [x for x in range(40, W) if c.region[y, x] >= 0]
        return max(xs)

    for y, cols in ((36, (None, LIP_UP, LIP_UP)), (37, (LIP_LINE, LIP_UP, LIP_UP)),
                    (38, (LIP_LINE, LIP_LINE, LIP_LO)), (39, (None, LIP_LO, LIP_HI))):
        xr = edge(y)
        for i, col in enumerate(cols):
            if col is not None:
                px[xr - 2 + i, y] = col + (255,)
    skin(edge(37) - 3, 37, 2)
    # rona pipi
    for x, y in ((51, 33), (52, 33), (51, 34)):
        px[x, y] = BLUSH + (255,)
    # lekuk telinga dan subang emas
    skin(43, 30, 2)
    skin(43, 31, 1)
    skin(44, 32, 2)
    stamp(px, 42, 36, [
        ".a.",
        "brb",
        ".c.",
    ], {"a": GOLD[3], "b": GOLD[2], "r": RUBY, "c": GOLD[1]})

    # --- helai rambut disisir ke belakang, menuju sanggul
    def on_hair(x, y):
        return c.region[y, x] >= 0 and c.ramps[c.region[y, x]] is HAIR

    for pts in (((50, 11), (44, 9), (37, 10), (31, 14)),
                ((49, 14), (43, 13), (36, 15), (30, 20)),
                ((46, 19), (40, 19), (34, 22), (31, 27)),
                ((43, 25), (38, 26), (34, 29))):
        polyline(px, pts, HAIR[3], on_hair)
    for x, y in ((40, 9), (41, 9), (42, 9), (36, 10), (37, 10), (33, 12)):
        if on_hair(x, y):
            px[x, y] = HAIR[4] + (255,)
    # alur sanggul
    bx, by, brx, bry = BUN
    for r in (3.0, 6.0):
        for ang in range(110, 260, 12):
            t = math.radians(ang)
            x, y = round(bx + (r + 1.0) * math.cos(t)), round(by + r * math.sin(t))
            if on_hair(x, y):
                px[x, y] = HAIR[3] + (255,)

    # --- cunduk emas: rumpun kuntum bunga di atas sanggul, bertangkai pendek
    flower = [
        ".aa.",
        "ahha",
        "ahha",
        ".ab.",
    ]
    fcols = {"a": GOLD[2], "h": GOLD[3], "b": GOLD[0]}
    for stem, (fx, fy) in ((((27, 21), (24, 17)), (21, 13)),
                           (((29, 21), (28, 16)), (26, 10)),
                           (((25, 23), (21, 21)), (16, 18))):
        polyline(px, list(stem), GOLD[1])
        stamp(px, fx, fy, flower, fcols)
    for x, y in ((14, 23), (19, 11), (25, 15), (31, 12)):
        px[x, y] = GOLD[2] + (255,)

    # --- selendang: tepi kuning di kedua sisi dan lipatan
    polyline(px, [(21, 61), (19, 70), (18, 79)], GOLD[2])
    polyline(px, [(34, 57), (32, 66), (30, 79)], GOLD[2])
    polyline(px, [(26, 60), (25, 70), (24, 79)], SAMPUR[1])

    # --- kebaya: lis emas di kerah dan tepi depan, motif belah ketupat emas di panel dalam
    polyline(px, [(38, 56), (44, 61), (46, 65)], GOLD[2])
    polyline(px, [(51, 56), (49, 61), (47, 65)], GOLD[2])
    polyline(px, [(43, 64), (42, 79)], GOLD[2])
    polyline(px, [(51, 64), (52, 79)], GOLD[2])
    for x, y in ((40, 57), (43, 60), (50, 58), (48, 62), (42, 70), (42, 75), (52, 70), (52, 76)):
        px[x, y] = GOLD[3] + (255,)
    for y in range(66, 80, 3):
        for x in range(44 + (y // 3 % 2), 51, 3):
            if c.region[y, x] >= 0 and c.ramps[c.region[y, x]] is KEBAYA_IN:
                px[x, y] = GOLD[1] + (255,)
    # lipatan lengan jauh
    polyline(px, [(60, 64), (59, 72), (59, 79)], KEBAYA[1])
    # motif kecil di kain kebaya
    for y in range(61, 80, 5):
        for x in range(36 + (y // 5 % 2) * 3, 66, 6):
            if c.region[y, x] >= 0 and c.ramps[c.region[y, x]] is KEBAYA and not (41 <= x <= 53):
                px[x, y] = KEBAYA[min(c.level[y, x] + 1, 4)] + (255,)
    # kalung emas tipis
    polyline(px, [(40, 51), (43, 53), (46, 54)], GOLD[2])
    polyline(px, [(49, 52), (47, 54)], GOLD[2])
    stamp(px, 46, 55, ["ab", "rb"], {"a": GOLD[3], "b": GOLD[1], "r": RUBY})
    return img


def outline(img: Image.Image) -> Image.Image:
    a = np.asarray(img).copy()
    alpha = a[..., 3] > 0
    grow = np.zeros_like(alpha)
    grow[1:, :] |= alpha[:-1, :]
    grow[:-1, :] |= alpha[1:, :]
    grow[:, 1:] |= alpha[:, :-1]
    grow[:, :-1] |= alpha[:, 1:]
    ring = grow & ~alpha
    a[ring] = OUTLINE + (255,)
    return Image.fromarray(a, "RGBA")


def draw_roro_ayu() -> Image.Image:
    c = build_base()
    return outline(details(c.image(), c))

