"""Potret dialog Roro Ayu (80x80, setengah badan), dipanggil dari tools/build_assets.py.

Rujukan utamanya adalah desain sprite diam Roro Ayu dari pemilik proyek: kulit
sawo matang, rambut hitam disisir ke belakang
dengan sanggul bulat di tengkuk dan hiasan cunduk emas, subang emas, kebaya
hijau terang berlis emas dengan motif belah ketupat emas di dada, dan selendang
(sampur) jingga-merah bertepi kuning di bahu. Warnanya diambil dari desain itu.
Di potret ini wajahnya menghadap ke depan supaya kepala dan badan searah.

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

# Wajah menghadap ke depan, oval dengan dagu mungil. Separuh kanan; kiri dicerminkan.
FACE_R = [(40.0, 16.4), (45.2, 17.0), (48.8, 19.6), (50.6, 23.6), (51.0, 27.6), (50.4, 32.2), (48.6, 36.6),
          (46.2, 40.4), (43.4, 43.2), (40.0, 44.6)]
FACE = FACE_R[:-1] + [(80 - x, y) for x, y in reversed(FACE_R)][:-1]
# rambut disisir ke belakang, membingkai wajah
HEAD = [(40.0, 6.4), (47.6, 7.6), (53.0, 12.0), (55.0, 19.0), (54.6, 27.0), (52.4, 34.0), (49.0, 36.0),
        (31.0, 36.0), (27.6, 34.0), (25.4, 27.0), (25.0, 19.0), (27.0, 12.0), (32.4, 7.6)]
EARS = [(28.0, 31.6, 1.6, 3.4), (52.0, 31.6, 1.6, 3.4)]
NECK = [(35.2, 38.0), (44.8, 38.0), (45.0, 46.0), (45.6, 53.0), (34.4, 53.0), (35.0, 46.0)]
# sanggul di belakang kepala, mengintip di sisi kiri
BUN = (25.0, 32.6, 6.6, 6.2)
# Bahu landai selebar kira-kira dua kali kepala; lengan atas terpisah dari badan.
BODY = [(34.0, 51.6), (46.0, 51.6), (53.6, 53.6), (60.6, 56.6), (64.8, 60.6), (66.4, 66.0), (66.8, 72.0),
        (66.6, 80), (13.4, 80), (13.2, 72.0), (13.6, 66.0), (15.2, 60.6), (19.4, 56.6), (26.4, 53.6)]
ARMS = [[(15.2, 60.6), (13.6, 66.0), (13.2, 72.0), (13.4, 80), (20.4, 80), (20.0, 72.0), (19.8, 65.6)],
        [(64.8, 60.6), (66.4, 66.0), (66.8, 72.0), (66.6, 80), (59.6, 80), (60.0, 72.0), (60.2, 65.6)]]
VNECK = [(34.6, 51.8), (45.4, 51.8), (43.2, 57.6), (40.0, 62.0), (36.8, 57.6)]
BEF = [(35.6, 60.8), (44.4, 60.8), (45.4, 80), (34.6, 80)]
SAMPUR_SHAPE = [(19.4, 56.6), (26.4, 53.6), (33.2, 52.2), (32.6, 56.4), (28.8, 66.0), (27.4, 80), (16.6, 80),
                (17.2, 68.0), (17.6, 61.0)]


def build_base() -> Canvas:
    c = Canvas()

    # sanggul di belakang kepala
    bx, by, brx, bry = BUN
    bun = big_mask(lambda d: d.ellipse(E(bx, by, brx, bry), fill=255))
    v = light_field(bx - 2, by - 3, 7.0) * 0.8 + 0.2 * blur(bun, 1.4)
    c.fill(down(bun), v, HAIR, [0.3, 0.52, 0.74, 0.92])

    # leher, bayangan di bawah dagu
    neck = big_mask(lambda d: d.polygon(P(smooth_poly(NECK, 4)), fill=255))
    face_big = big_mask(lambda d: d.polygon(P(smooth_poly(FACE, 6)), fill=255))
    jaw = blur(face_big.transform(face_big.size, Image.AFFINE, (1, 0, 0, 0, 1, -2.2 * S)), 1.0)
    v = light_field(38, 46, 8.0) * 0.8 + 0.2 * blur(neck, 1.2) - 0.32 * jaw
    c.fill(down(neck), v, SKIN, [0.12, 0.3, 0.5, 0.78, 0.97])

    # badan berkebaya hijau, sedikit bentuk dada
    body = big_mask(lambda d: d.polygon(P(smooth_poly(BODY, 4)), fill=255))
    bust = blur(big_mask(lambda d: (d.ellipse(E(31.0, 68.0, 6.0, 4.4), fill=255), d.ellipse(E(49.0, 68.0, 6.0, 4.4), fill=255))), 1.4)
    under = blur(big_mask(lambda d: (d.chord(E(31.0, 72.0, 6.5, 3.8), 0, 180, fill=255), d.chord(E(49.0, 72.0, 6.5, 3.8), 0, 180, fill=255))), 1.0)
    v = light_field(34, 64, 22.0) * 0.72 + 0.28 * blur(body, 1.8) + 0.1 * bust - 0.16 * under
    c.fill(down(body), v, KEBAYA, [0.3, 0.46, 0.64, 0.84])
    for arm, cx in zip(ARMS, (16.6, 63.4)):
        m = big_mask(lambda d, arm=arm: d.polygon(P(smooth_poly(arm, 4)), fill=255))
        v = light_field(cx, 66, 9.0) * 0.6 + 0.4 * blur(m, 1.2) - (0.12 if cx > 40 else 0.0)
        c.fill(down(m), v, KEBAYA, [0.3, 0.46, 0.64, 0.84])

    # dada di leher kebaya dan panel dalam hijau tua
    vneck = big_mask(lambda d: d.polygon(P(VNECK), fill=255))
    v = light_field(38, 55, 7.0) * 0.8 + 0.2 * blur(vneck, 1.0)
    c.fill(down(vneck), v, SKIN, [0.1, 0.28, 0.5, 0.8, 0.98])
    bef = big_mask(lambda d: d.polygon(P(BEF), fill=255))
    v = light_field(39, 70, 12.0) * 0.7 + 0.3 * blur(bef, 1.0)
    c.fill(down(bef), v, KEBAYA_IN, [0.4, 0.75])

    # selendang (sampur) di bahu kiri
    sampur = big_mask(lambda d: d.polygon(P(smooth_poly(SAMPUR_SHAPE, 4)), fill=255))
    v = light_field(22, 62, 10.0) * 0.7 + 0.3 * blur(sampur, 1.2)
    c.fill(down(sampur), v, SAMPUR, [0.26, 0.44, 0.64, 0.86])

    # rambut
    head = big_mask(lambda d: d.polygon(P(smooth_poly(HEAD, 6)), fill=255))
    v = light_field(34, 12, 15.0) * 0.8 + 0.2 * blur(head, 2.0)
    c.fill(down(head), v, HAIR, [0.3, 0.52, 0.74, 0.92])

    # telinga
    for ex, ey, erx, ery in EARS:
        ear = big_mask(lambda d, ex=ex, ey=ey, erx=erx, ery=ery: d.ellipse(E(ex, ey, erx, ery), fill=255))
        v = light_field(ex, ey, 3.0) * 0.6 + 0.4 * blur(ear, 0.8) - (0.15 if ex > 40 else 0.0)
        c.fill(down(ear), v, SKIN, [0.15, 0.36, 0.56, 0.84, 0.99])

    # wajah: disinari dari kiri atas, bayangan rambut di dahi, kilau tulang pipi
    v = light_field(40, 30, 14.0) * 0.68 + 0.32 * blur(face_big, 1.6)
    hairline = blur(face_big.transform(face_big.size, Image.AFFINE, (1, 0, 0, 0, 1, 2.4 * S)), 1.0)
    sockets = blur(big_mask(lambda d: (d.ellipse(E(35.5, 29.0, 3.6, 2.2), fill=255), d.ellipse(E(44.5, 29.0, 3.6, 2.2), fill=255))), 0.9)
    cheek = blur(big_mask(lambda d: d.ellipse(E(34.0, 34.0, 3.4, 2.6), fill=255)), 1.0)
    v = v - 0.4 * (1.0 - hairline) * blur(face_big, 0.6) - 0.1 * sockets + 0.16 * cheek
    c.fill(down(face_big), v, SKIN, [0.12, 0.28, 0.46, 0.7, 0.9])

    c.clean()
    return c


LASH = (30, 16, 22)
WHITE = (244, 238, 230)
WHITE_D = (206, 190, 180)
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

    # --- alis tegas yang melengkung lembut
    brow_cols = {"d": BROW, "b": BROW_L}
    stamp(px, 32, 24, [
        "..dddd.",
        ".d....b",
        "b......",
    ], brow_cols)
    stamp(px, 42, 24, [
        ".dddd..",
        "b....d.",
        "......b",
    ], brow_cols)
    # --- mata besar menatap ke depan, bulu mata lentik di sudut luar
    eye_cols = {"c": SHADOW_LID, "L": LASH, "w": WHITE, "v": WHITE_D, "H": SHINE, "I": IRIS, "i": IRIS_L,
                "s": SKIN[1], "l": SKIN[2]}
    stamp(px, 32, 27, [
        ".L.ccc..",
        "LLLLLLL.",
        ".vIHIIws",
        ".LiIIiv.",
        "..liil..",
    ], eye_cols)
    stamp(px, 41, 27, [
        "..ccc.L.",
        ".LLLLLLL",
        "swIHIIv.",
        ".viIIiL.",
        "..liil..",
    ], eye_cols)
    # --- hidung kecil
    skin(40, 30, 4)
    skin(40, 31, 4)
    skin(41, 32, 2)
    skin(41, 33, 2)
    skin(40, 34, 4)
    skin(40, 35, 2)
    skin(39, 35, 1)
    skin(41, 35, 1)
    # --- bibir merah dengan senyum tipis
    stamp(px, 37, 38, [
        "j.....j",
        ".xuuux.",
        "..oho..",
        "...k...",
    ], {"j": SKIN[1], "k": SKIN[2], "u": LIP_UP, "x": LIP_LINE, "o": LIP_LO, "h": LIP_HI})
    # --- rona pipi
    for x, y in ((33, 34), (34, 34), (35, 34), (34, 35), (45, 34), (46, 34), (47, 34), (46, 35)):
        px[x, y] = BLUSH + (255,)
    # --- subang emas di kedua telinga
    for x in (27, 51):
        stamp(px, x, 35, [
            ".a.",
            "brb",
            ".c.",
        ], {"a": GOLD[3], "b": GOLD[2], "r": RUBY, "c": GOLD[1]})

    # --- helai rambut disisir ke belakang dan kilau di ubun-ubun
    def on_hair(x, y):
        return c.region[y, x] >= 0 and c.ramps[c.region[y, x]] is HAIR

    for pts in (((36, 15), (34, 11), (34, 8)), ((32, 18), (29, 13), (30, 9)), ((29, 24), (27, 18), (27, 13)),
                ((44, 15), (46, 11), (46, 8)), ((48, 18), (51, 13), (50, 9)), ((51, 24), (53, 18), (53, 13))):
        polyline(px, pts, HAIR[3], on_hair)
    for x, y in ((32, 10), (33, 9), (34, 9), (35, 8), (36, 8), (37, 8), (31, 11)):
        if on_hair(x, y):
            px[x, y] = HAIR[4] + (255,)

    # --- cunduk emas: rumpun kuntum bunga yang mencuat dari sanggul di belakang kepala
    flower = [
        ".aa.",
        "ahha",
        "ahha",
        ".ab.",
    ]
    fcols = {"a": GOLD[2], "h": GOLD[3], "b": GOLD[0]}
    for stem, (fx, fy) in ((((24, 27), (22, 20)), (20, 16)),
                           (((26, 26), (25, 15)), (23, 11)),
                           (((23, 29), (19, 26)), (15, 22))):
        polyline(px, list(stem), GOLD[1])
        stamp(px, fx, fy, flower, fcols)
    for x, y in ((14, 27), (18, 14), (27, 12)):
        px[x, y] = GOLD[2] + (255,)

    # --- selendang: tepi kuning dan lipatan
    polyline(px, [(19, 57), (18, 68), (17, 79)], GOLD[2])
    polyline(px, [(32, 53), (29, 65), (28, 79)], GOLD[2])
    polyline(px, [(25, 56), (23, 68), (22, 79)], SAMPUR[1])

    # --- kebaya: lis emas di kerah dan tepi panel, motif belah ketupat emas di panel dalam
    polyline(px, [(35, 52), (38, 57), (39, 61)], GOLD[2])
    polyline(px, [(45, 52), (42, 57), (41, 61)], GOLD[2])
    polyline(px, [(36, 61), (35, 79)], GOLD[2])
    polyline(px, [(44, 61), (45, 79)], GOLD[2])
    for x, y in ((36, 54), (44, 54), (35, 67), (35, 74), (45, 67), (45, 74)):
        px[x, y] = GOLD[3] + (255,)
    for y in range(63, 80, 3):
        for x in range(37 + (y // 3 % 2), 44, 3):
            if c.region[y, x] >= 0 and c.ramps[c.region[y, x]] is KEBAYA_IN:
                px[x, y] = GOLD[1] + (255,)
    # lipatan antara lengan dan badan
    polyline(px, [(20, 64), (20, 71), (20, 79)], KEBAYA[0])
    polyline(px, [(60, 64), (60, 71), (60, 79)], KEBAYA[0])
    # motif kecil di kain kebaya
    for y in range(58, 80, 5):
        for x in range(2 + (y // 5 % 2) * 3, 78, 6):
            if c.region[y, x] >= 0 and c.ramps[c.region[y, x]] is KEBAYA and not (33 <= x <= 47):
                px[x, y] = KEBAYA[min(c.level[y, x] + 1, 4)] + (255,)
    # kalung emas tipis dengan liontin
    polyline(px, [(36, 48), (38, 50), (40, 51)], GOLD[2])
    polyline(px, [(44, 48), (42, 50), (41, 51)], GOLD[2])
    stamp(px, 40, 52, ["a", "r"], {"a": GOLD[3], "r": RUBY})
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

