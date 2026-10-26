"""Potret dialog Roro Ayu (80x80, setengah badan), dipanggil dari tools/build_assets.py.

Roro Ayu tidak punya sprite, jadi potretnya dilukis di sini. Rujukannya:
- Topeng Roro Ayu dalam kesenian Dongkrek: wajah krem, cantik, tatapan sendu,
  senyum tipis.
- Gambaran perempuan cantik dalam Serat Centhini: rambut hitam berkilau, kulit
  kuning langsat, leher jenjang, sikap halus dan tenang.
- Sanggul ukel konde gaya Solo: lonjong dan rendah di tengkuk, dihias ronce
  melati dan tusuk konde. Kebaya kutubaru dengan bef di dada, berpeniti
  renteng, dan subang di telinga.
- Teknik potret piksel ala GBA: wajah tiga perempat (sisi dekat dan jauh
  dibedakan, tidak dicerminkan), shading menggerombol dengan 4-6 warna per
  bahan, bayangan bergeser ke merah-ungu dan kilau ke kuning.

Caranya: setiap bagian (sanggul, badan, leher, rambut, telinga, wajah) dibentuk
8x lebih besar, diperkecil jadi cakupan per piksel, lalu diwarnai bertingkat
menurut arah cahaya (kiri atas). Piksel tunggal yang menyendiri dibuang supaya
bayangannya rapi. Mata, alis, hidung, bibir, perhiasan, melati, dan sulaman
kebaya kemudian ditempel per piksel.
"""
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

S = 8
W = 80
OUTLINE = (30, 18, 32)

# Ramp warna, gelap -> terang. Bayangan bergeser ke merah-ungu, kilau ke kuning.
SKIN = [(150, 88, 92), (192, 124, 108), (220, 160, 128), (238, 190, 152), (248, 214, 180), (255, 236, 212)]
HAIR = [(14, 10, 22), (26, 20, 38), (42, 36, 62), (66, 62, 98), (104, 104, 146)]
KEBAYA = [(16, 46, 44), (24, 76, 62), (36, 108, 78), (62, 144, 94), (112, 184, 116)]
GOLD = [(112, 66, 28), (178, 120, 44), (230, 178, 74), (255, 226, 140)]
BATIK = [(46, 22, 22), (82, 44, 32), (122, 74, 44), (186, 140, 82)]
MELATI = [(176, 188, 170), (226, 232, 218), (255, 255, 248)]
RUBY = (200, 40, 60)
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

FACE = [(45.5, 15.6), (51.0, 16.6), (54.6, 19.6), (56.0, 24.0), (55.8, 28.4), (55.0, 31.0), (55.6, 33.6),
        (54.6, 37.2), (52.4, 40.8), (49.0, 43.6), (46.4, 45.0), (43.8, 44.8), (40.0, 42.6), (36.2, 39.2),
        (33.6, 35.4), (33.0, 29.6), (34.2, 23.4), (37.4, 18.6), (41.2, 16.2)]
HEAD = [(40, 5.6), (48.5, 6.6), (55.4, 11.0), (58.6, 17.6), (58.2, 24.0), (55.2, 26.0), (34.0, 36.8),
        (28.6, 37.6), (25.6, 30.4), (26.0, 20.4), (29.6, 12.0), (34.0, 7.6)]
# rambut depan: belah di (45.6, 15), disisir ke samping menutupi pelipis dan atas telinga
FRINGE_NEAR = [(45.8, 13.4), (45.6, 16.6), (41.0, 18.0), (37.8, 20.4), (35.8, 24.2), (35.0, 28.4), (34.8, 30.6),
               (31.0, 30.4), (27.6, 27.0), (28.0, 19.0), (32.6, 12.2), (39.0, 9.2)]
FRINGE_FAR = [(45.8, 13.4), (51.0, 11.6), (55.8, 13.8), (58.4, 18.6), (57.8, 23.6), (56.4, 24.4), (55.2, 20.8),
              (52.4, 18.0), (49.0, 16.6), (45.6, 16.6)]
EAR = [(30.4, 29.6), (32.6, 29.0), (34.4, 31.0), (34.4, 35.6), (33.0, 37.0), (31.0, 35.8), (30.0, 32.4)]
NECK = [(39.0, 40.0), (49.4, 42.0), (49.2, 48.0), (50.2, 57.6), (38.6, 57.6), (39.4, 48.0)]
BUN = (22.8, 35.6, 8.4, 7.2)
# Bahu landai selebar kira-kira dua kali kepala; lengan atas terpisah dari badan
# supaya siluetnya ramping.
BODY = [(37.2, 55.2), (51.0, 55.4), (57.6, 57.0), (63.2, 59.6), (66.6, 62.6), (67.8, 67.0), (68.0, 72.0),
        (67.8, 80), (14.2, 80), (14.0, 72.0), (14.4, 66.4), (16.6, 62.6), (20.6, 59.6), (28.0, 57.2)]
ARM_NEAR = [(16.6, 62.6), (14.4, 66.4), (14.0, 72.0), (14.2, 80), (21.0, 80), (20.6, 72.0), (20.4, 66.0)]
ARM_FAR = [(66.6, 62.6), (67.8, 67.0), (68.0, 72.0), (67.8, 80), (62.2, 80), (62.4, 72.0), (62.8, 66.0)]
VNECK = [(38.6, 55.4), (50.2, 55.6), (48.4, 61.0), (45.6, 65.0), (42.8, 61.0)]
BEF = [(41.8, 64.6), (50.2, 64.2), (50.8, 80), (41.2, 80)]


def build_base() -> Canvas:
    c = Canvas()

    # sanggul ukel konde: lonjong, rendah di tengkuk
    bx, by, brx, bry = BUN
    bun = big_mask(lambda d: d.ellipse(E(bx, by, brx, bry), fill=255))
    v = light_field(bx - 1, by - 2, 9.0) * 0.8 + 0.2 * blur(bun, 1.6)
    c.fill(down(bun), v, HAIR, [0.28, 0.5, 0.72, 0.9])

    # badan dan kebaya
    body = big_mask(lambda d: d.polygon(P(smooth_poly(BODY, 4)), fill=255))
    bust = blur(big_mask(lambda d: (d.ellipse(E(32.5, 70.5, 6.5, 4.5), fill=255), d.ellipse(E(56.5, 70.5, 4.5, 4.5), fill=255))), 1.4)
    under_bust = blur(big_mask(lambda d: (d.chord(E(32.5, 74.5, 7.0, 4.0), 0, 180, fill=255), d.chord(E(56.5, 74.5, 5.0, 4.0), 0, 180, fill=255))), 1.0)
    v = light_field(36, 66, 22.0) * 0.72 + 0.28 * blur(body, 1.8) + 0.12 * bust - 0.18 * under_bust
    c.fill(down(body), v, KEBAYA, [0.3, 0.46, 0.64, 0.84])
    for arm, cx in ((ARM_NEAR, 17.0), (ARM_FAR, 65.0)):
        m = big_mask(lambda d, arm=arm: d.polygon(P(smooth_poly(arm, 4)), fill=255))
        v = light_field(cx, 68, 9.0) * 0.6 + 0.4 * blur(m, 1.2) - (0.12 if cx > 40 else 0.0)
        c.fill(down(m), v, KEBAYA, [0.3, 0.46, 0.64, 0.84])

    # leher: bayangan rahang di atasnya, sisi kanan lebih gelap
    neck = big_mask(lambda d: d.polygon(P(smooth_poly(NECK, 4)), fill=255))
    jaw_shadow = big_mask(lambda d: d.polygon(P(smooth_poly(FACE, 6)), fill=255))
    jaw = blur(jaw_shadow.transform(jaw_shadow.size, Image.AFFINE, (1, 0, 0, 0, 1, -2.0 * S)), 1.2)
    v = light_field(41, 52, 10.0) * 0.8 + 0.2 * blur(neck, 1.4) - 0.22 * jaw
    c.fill(down(neck), v, SKIN, [0.12, 0.3, 0.5, 0.78, 0.97])

    # dada di leher kebaya, kemben batik, dan bef kutubaru
    vneck = big_mask(lambda d: d.polygon(P(VNECK), fill=255))
    v = light_field(42, 58, 8.0) * 0.8 + 0.2 * blur(vneck, 1.0)
    c.fill(down(vneck), v, SKIN, [0.1, 0.28, 0.5, 0.8, 0.98])
    kemben = big_mask(lambda d: d.polygon(P([(40.4, 59.6), (49.6, 59.6), (45.6, 65.6)]), fill=255))
    kem = np.minimum(down(kemben), down(vneck))
    c.fill(kem, np.full((W, W), 0.4), BATIK, [0.3, 0.7, 0.95])
    bef = big_mask(lambda d: d.polygon(P(BEF), fill=255))
    v = light_field(44, 72, 14.0) * 0.7 + 0.3 * blur(bef, 1.0)
    c.fill(down(bef), v, KEBAYA, [0.22, 0.42, 0.62, 0.86])

    # rambut belakang (kepala) dan sunggar
    head = big_mask(lambda d: d.polygon(P(smooth_poly(HEAD, 6)), fill=255))
    v = light_field(38, 16, 16.0) * 0.8 + 0.2 * blur(head, 2.0)
    c.fill(down(head), v, HAIR, [0.3, 0.52, 0.74, 0.92])

    # telinga dekat
    ear = big_mask(lambda d: d.polygon(P(smooth_poly(EAR, 4)), fill=255))
    v = light_field(32, 32, 4.0) * 0.6 + 0.4 * blur(ear, 0.8)
    c.fill(down(ear), v, SKIN, [0.15, 0.36, 0.56, 0.84, 0.99])

    # wajah
    face_big = big_mask(lambda d: d.polygon(P(smooth_poly(FACE, 6)), fill=255))
    v = light_field(42, 30, 15.0) * 0.66 + 0.34 * blur(face_big, 1.6)
    # bayangan rambut di dahi, rongga mata, bawah hidung/bibir; kilau tulang pipi & dahi
    fringe_big = big_mask(lambda d: (d.polygon(P(smooth_poly(FRINGE_NEAR, 4)), fill=255),
                                     d.polygon(P(smooth_poly(FRINGE_FAR, 4)), fill=255)))
    under_hair = blur(fringe_big.transform(fringe_big.size, Image.AFFINE, (1, 0, 0, 0, 1, -1.6 * S)), 0.9)
    sockets = blur(big_mask(lambda d: (d.ellipse(E(39.6, 30.4, 4.6, 2.6), fill=255), d.ellipse(E(51.4, 30.4, 3.4, 2.4), fill=255))), 1.0)
    cheek = blur(big_mask(lambda d: d.ellipse(E(38.6, 36.4, 4.4, 3.0), fill=255)), 1.2)
    forehead = blur(big_mask(lambda d: d.ellipse(E(42.6, 21.0, 4.6, 2.6), fill=255)), 1.0)
    far_side = blur(big_mask(lambda d: d.polygon(P([(54.2, 26), (57, 26), (57, 44), (51.6, 47.6), (54.4, 38)]), fill=255)), 0.8)
    v = v - 0.42 * under_hair - 0.12 * sockets + 0.18 * cheek + 0.07 * forehead - 0.22 * far_side
    c.fill(down(face_big), v, SKIN, [0.1, 0.26, 0.44, 0.7, 0.9])

    # rambut depan
    fn = big_mask(lambda d: d.polygon(P(smooth_poly(FRINGE_NEAR, 4)), fill=255))
    v = light_field(34, 16, 9.0) * 0.75 + 0.25 * blur(fn, 1.0)
    c.fill(down(fn), v, HAIR, [0.26, 0.5, 0.74, 0.92])
    ff = big_mask(lambda d: d.polygon(P(smooth_poly(FRINGE_FAR, 4)), fill=255))
    v = light_field(48, 12, 9.0) * 0.6 + 0.4 * blur(ff, 0.8)
    c.fill(down(ff), v, HAIR, [0.3, 0.55, 0.8, 0.95])

    c.clean()
    return c


LASH = (38, 20, 30)
WHITE = (246, 240, 236)
WHITE_D = (214, 200, 200)
IRIS = (58, 30, 26)
IRIS_L = (122, 72, 46)
SHINE = (255, 255, 255)
BROW = (86, 54, 46)
BROW_L = (124, 82, 70)
SHADOW_LID = (222, 162, 140)
LIP_LINE = (138, 42, 60)
LIP_UP = (180, 68, 82)
LIP_LO = (218, 102, 112)
LIP_HI = (244, 156, 152)
BLUSH = (244, 180, 160)


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

    # --- mata: sendu (kelopak atas agak turun), sudut luar sedikit menurun, melirik ke kanan
    eye_cols = {"c": SHADOW_LID, "L": LASH, "w": WHITE, "v": WHITE_D, "H": SHINE, "I": IRIS, "i": IRIS_L,
                "s": SKIN[1], "l": SKIN[2]}
    stamp(px, 35, 28, [
        ".L.ccc...",
        "LLLLLLLL.",
        ".vwIHIIws",
        ".LwiIIiv.",
        "...liil..",
    ], eye_cols)
    stamp(px, 48, 28, [
        "..cccL.",
        ".LLLLLL",
        "swIHIL.",
        ".viIiL.",
        "..lil..",
    ], eye_cols)
    # alis tipis melengkung seperti bulan sabit
    brow_cols = {"d": BROW, "b": BROW_L}
    stamp(px, 35, 24, [
        "...dddd.",
        ".bd....b",
        "b.......",
    ], brow_cols)
    stamp(px, 48, 24, [
        ".dddd.",
        "b....b",
    ], brow_cols)
    # hidung kecil (ngudhup mlathi): punggung terang pendek, bayangan sisi jauh, ujung, cuping
    skin(46, 32, 4)
    for x, y in ((47, 33), (47, 34), (48, 35)):
        skin(x, y, 2)
    skin(46, 35, 4)
    skin(47, 36, 2)
    skin(46, 37, 2)
    skin(45, 37, 1)
    # bibir: senyum tipis, bibir bawah penuh dengan kilau
    lip_cols = {"x": LIP_LINE, "u": LIP_UP, "o": LIP_LO, "h": LIP_HI, "k": SKIN[2]}
    stamp(px, 42, 40, [
        "k......k",
        ".uuxuuu.",
        "..ohooo.",
        "...kkk..",
    ], lip_cols)
    # rona pipi
    for x, y in ((35, 35), (36, 35), (37, 35), (36, 36), (37, 36), (51, 35), (52, 35)):
        if c.region[y, x] >= 0:
            px[x, y] = BLUSH + (255,)

    # --- telinga dan subang
    skin(31, 32, 2)
    skin(32, 33, 2)
    skin(31, 33, 1)
    stamp(px, 31, 36, [
        ".a.",
        "brb",
        ".c.",
    ], {"a": GOLD[3], "b": GOLD[2], "r": RUBY, "c": GOLD[1]})

    # --- kilau rambut mengikuti lengkung kepala, garis belah, dan helai ke arah sanggul
    for x, y in ((30, 15), (31, 14), (32, 13), (33, 12), (34, 11), (35, 11), (36, 10), (37, 10), (38, 10)):
        px[x, y] = HAIR[3] + (255,)
    for x, y in ((33, 13), (34, 12), (35, 12), (36, 11)):
        px[x, y] = HAIR[4] + (255,)
    for x, y in ((29, 18), (29, 19), (30, 17)):
        px[x, y] = HAIR[3] + (255,)
    for x, y in ((45, 14), (45, 13), (44, 12), (44, 11), (43, 10), (43, 9)):
        px[x, y] = HAIR[0] + (255,)
    for x, y in ((50, 10), (51, 10), (52, 11), (53, 12)):
        px[x, y] = HAIR[3] + (255,)
    def on_hair(x, y):
        return c.region[y, x] >= 0 and c.ramps[c.region[y, x]] is HAIR

    for pts in (((40, 13), (36, 16), (33, 20), (31, 25)), ((42, 15), (38, 18), (35, 22))):
        polyline(px, pts, HAIR[2], on_hair)

    # --- sanggul: ronce melati melingkar dan tusuk konde emas
    bx, by, brx, bry = BUN

    def on_bun(x, y):
        return ((x + 0.5 - bx) / (brx - 0.8)) ** 2 + ((y + 0.5 - by) / (bry - 0.8)) ** 2 <= 1.0

    # ronce melati: pita kuntum melati mengikuti tepi luar bawah sanggul
    def in_band(x, y):
        inner = ((x + 0.5 - bx - 2.4) / (brx - 3.2)) ** 2 + ((y + 0.5 - by + 2.0) / (bry - 2.6)) ** 2
        return on_bun(x, y) and inner > 1.0

    for y in range(int(by - bry), int(by + bry) + 1):
        for x in range(int(bx - brx), int(bx + brx) + 1):
            if not in_band(x, y) or (x + 2 * (y // 2)) % 3 != 0 or y % 2 != 0:
                continue
            for dx, dy, col in ((0, 0, MELATI[2]), (1, 0, MELATI[1]), (0, 1, MELATI[1]), (1, 1, MELATI[0])):
                if on_bun(x + dx, y + dy):
                    px[x + dx, y + dy] = col + (255,)
    for x, y in ((25, 32), (24, 31), (23, 30), (22, 29), (21, 28), (20, 27), (19, 26)):
        px[x, y] = GOLD[2] + (255,)
        px[x, y + 1] = GOLD[1] + (255,)
    stamp(px, 16, 23, [
        ".a.",
        "ara",
        ".a.",
    ], {"a": GOLD[2], "r": RUBY})
    px[17, 23] = GOLD[3] + (255,)

    # --- kebaya kutubaru: tepi bersulam emas, bef, peniti renteng, dan kalung
    polyline(px, [(38, 55), (42, 60), (45, 64)], GOLD[2])
    polyline(px, [(39, 55), (43, 60)], GOLD[1])
    polyline(px, [(50, 55), (48, 60), (46, 64)], GOLD[2])
    polyline(px, [(42, 64), (41, 79)], GOLD[2])
    polyline(px, [(50, 64), (51, 79)], GOLD[2])
    polyline(px, [(42, 64), (50, 64)], GOLD[1])
    for x, y in ((39, 56), (42, 60), (44, 63), (49, 57), (47, 62), (41, 69), (41, 75), (51, 70), (51, 76)):
        px[x, y] = GOLD[3] + (255,)
    # peniti renteng: tiga bros emas yang dirangkai rantai di bef
    for i, y in enumerate((66, 71, 76)):
        stamp(px, 45, y, [
            ".a.",
            "ara",
            ".b.",
        ], {"a": GOLD[2], "r": RUBY, "b": GOLD[1]})
        px[45, y] = GOLD[3] + (255,)
        if i < 2:
            for yy in range(y + 3, y + 5):
                px[46, yy] = GOLD[1] + (255,)
    # lipatan antara lengan dan badan
    polyline(px, [(20, 66), (20, 72), (21, 79)], KEBAYA[0])
    polyline(px, [(63, 66), (62, 72), (62, 79)], KEBAYA[0])
    # motif brokat di kain kebaya
    for y in range(60, 80, 5):
        for x in range(2 + (y // 5 % 2) * 3, 80, 6):
            if c.region[y, x] >= 0 and c.ramps[c.region[y, x]] is KEBAYA and not (40 <= x <= 52):
                px[x, y] = KEBAYA[min(c.level[y, x] + 1, 4)] + (255,)
    # kemben batik: titik-titik emas
    for x, y in ((44, 60), (47, 60), (45, 62)):
        if c.region[y, x] >= 0:
            px[x, y] = BATIK[3] + (255,)
    # kalung emas tipis dengan liontin, di atas kerah
    polyline(px, [(41, 50), (43, 52), (45, 53)], GOLD[2])
    polyline(px, [(48, 51), (47, 53), (46, 53)], GOLD[2])
    stamp(px, 45, 54, ["ab", "rb"], {"a": GOLD[3], "b": GOLD[1], "r": RUBY})
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

