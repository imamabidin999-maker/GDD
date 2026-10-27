"""Potret dialog Roro Ayu (80x80, setengah badan), dipanggil dari tools/build_assets.py.

Rujukannya desain sprite diam Roro Ayu dari pemilik proyek: kulit sawo matang,
rambut hitam disisir ke belakang dengan sanggul di tengkuk dan cunduk bunga
emas, subang emas, kebaya hijau terang berlis emas dengan panel dada hijau tua
bermotif belah ketupat emas, dan selendang jingga-merah bertepi kuning di bahu.
Di potret ini wajahnya menghadap ke depan supaya kepala dan badan searah;
sanggulnya mengintip di belakang leher kiri dan cunduk mentulnya di atas kepala.

Digambar seperti pixel art buatan tangan, dalam tiga lapis:
1. Siluet: tiap bagian (sanggul, leher, badan, lengan, panel, selendang,
   rambut, telinga, wajah) diisi satu warna dasar dari bentuk poligon.
2. Cel shading: bidang terang dan bayangan digambar sebagai bentuk tersendiri
   yang dipotong ke bagiannya, dengan cahaya dari kiri atas, bukan gradasi
   otomatis.
3. Detail per piksel: mata, alis, hidung, bibir, rona pipi, subang, cunduk,
   kalung, lis emas, motif panel, dan tepi selendang.
"""

import numpy as np
from PIL import Image, ImageDraw

S = 8
W = 80

# Palet dari desain sprite diam: h = kilau, l = terang, b = dasar, s = bayangan, d = gelap.
OUT = (22, 14, 22)
SK = {"h": (246, 206, 166), "l": (232, 180, 138), "b": (214, 152, 112), "s": (182, 116, 88), "d": (140, 80, 68)}
HR = {"h": (110, 112, 140), "l": (66, 66, 92), "b": (36, 34, 52), "s": (22, 20, 34), "d": (12, 10, 20)}
GR = {"h": (150, 210, 104), "l": (98, 176, 78), "b": (60, 142, 62), "s": (38, 102, 52), "d": (22, 62, 36)}
GI = {"b": (30, 84, 44)}  # panel dalam hijau tua
OR = {"l": (212, 100, 52), "b": (184, 72, 40), "s": (138, 48, 30), "d": (96, 30, 24)}
GD = {"h": (255, 232, 160), "l": (236, 186, 96), "b": (204, 144, 64), "s": (150, 96, 40)}
RUBY = (196, 40, 52)
LIP = {"u": (168, 52, 58), "x": (116, 30, 38), "o": (206, 86, 82), "h": (234, 140, 120)}
BLUSH = (226, 140, 112)
EYE = {"L": (30, 16, 22), "w": (246, 240, 232), "v": (204, 186, 176), "I": (46, 26, 22), "i": (104, 62, 40),
       "H": (255, 255, 255), "c": (190, 128, 98)}
BROW = (52, 32, 30)


def P(pts):
    return [(x * S, y * S) for x, y in pts]


def mirror(half, axis=40.0):
    """Separuh kanan (dari atas ke bawah) -> bentuk utuh simetris."""
    left = [(2 * axis - x, y) for x, y in reversed(half)]
    return half + left


def cover(draw_fn):
    m = Image.new("L", (W * S, W * S), 0)
    draw_fn(ImageDraw.Draw(m))
    return np.asarray(m.resize((W, W), Image.BOX)) >= 128


def poly(pts):
    return cover(lambda d: d.polygon(P(pts), fill=255))


def ellipse(cx, cy, rx, ry):
    return cover(lambda d: d.ellipse([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], fill=255))


class Pic:
    def __init__(self):
        self.rgb = np.zeros((W, W, 3), dtype=np.uint8)
        self.a = np.zeros((W, W), dtype=bool)
        self.regions = {}

    def fill(self, name, mask, color):
        self.rgb[mask] = color
        self.a |= mask
        for k in self.regions:
            self.regions[k] &= ~mask
        self.regions[name] = mask.copy()

    def shade(self, name, mask, color):
        m = mask & self.regions[name]
        self.rgb[m] = color

    def px(self, x, y, color):
        self.rgb[y, x] = color
        self.a[y, x] = True

    def image(self):
        out = np.dstack([self.rgb, self.a.astype(np.uint8) * 255])
        return Image.fromarray(out, "RGBA").copy()


# ---------------------------------------------------------------------------
# Siluet
# ---------------------------------------------------------------------------
HAIR_R = [(40, 4.4), (45.6, 5.0), (50.2, 7.6), (53.2, 11.6), (54.4, 16.6), (54.2, 22.0), (53.0, 26.6),
          (51.2, 29.2), (48.0, 30.0), (40, 30.0)]
FACE_R = [(40, 16.2), (43.8, 16.6), (47.2, 18.0), (49.8, 20.8), (51.0, 24.6), (51.2, 28.6), (50.8, 32.2),
          (49.4, 36.0), (47.2, 39.6), (44.4, 42.4), (42.0, 43.8), (40, 44.2)]
NECK_R = [(40, 38.0), (44.8, 38.0), (45.2, 44.0), (45.8, 50.6), (40, 50.6)]
BODY_R = [(40, 49.0), (46.0, 49.0), (50.6, 50.6), (55.4, 52.8), (59.6, 55.4), (62.8, 58.6), (64.6, 62.4),
          (65.4, 67.0), (65.8, 73.0), (66.0, 80), (40, 80)]
ARM_R = [(62.8, 58.6), (64.6, 62.4), (65.4, 67.0), (65.8, 73.0), (66.0, 80), (59.0, 80), (59.2, 72.0), (59.4, 65.0)]
VNECK_R = [(40, 49.2), (45.4, 49.4), (43.2, 53.6), (40, 57.0)]
PANEL_R = [(40, 55.0), (42.6, 55.0), (43.2, 62.0), (43.4, 80), (40, 80)]
SAMPUR = [(34.4, 49.4), (31.0, 50.2), (25.0, 52.6), (19.6, 55.6), (16.8, 59.6), (16.2, 66.0), (16.2, 80),
          (27.6, 80), (28.2, 68.0), (29.8, 60.0), (32.8, 53.6)]


def build() -> Pic:
    p = Pic()
    # sanggul lebar di tengkuk, tampak di kedua sisi leher
    p.fill("bun", ellipse(28.4, 39.8, 6.4, 5.0), HR["s"])
    p.fill("neck", poly(mirror(NECK_R)), SK["s"])
    p.fill("body", poly(mirror(BODY_R)), GR["b"])
    p.fill("arm_r", poly(ARM_R), GR["s"])
    p.fill("arm_l", poly([(80 - x, y) for x, y in ARM_R]), GR["l"])
    p.fill("vneck", poly(mirror(VNECK_R)), SK["b"])
    p.fill("panel", poly(mirror(PANEL_R)), GI["b"])
    p.fill("sampur", poly(SAMPUR), OR["b"])
    p.fill("hair", poly(mirror(HAIR_R)), HR["b"])
    p.fill("ear_l", ellipse(28.4, 30.6, 1.5, 3.0), SK["s"])
    p.fill("ear_r", ellipse(51.6, 30.6, 1.5, 3.0), SK["s"])
    p.fill("face", poly(mirror(FACE_R)), SK["l"])
    return p


def line(p, pts, color, region=None):
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for k in range(n + 1):
            x = round(x0 + (x1 - x0) * k / n)
            y = round(y0 + (y1 - y0) * k / n)
            if 0 <= x < W and 0 <= y < W and (region is None or p.regions[region][y, x]):
                p.px(x, y, color)


def stamp(p, x0, y0, rows, cols):
    for dy, row in enumerate(rows):
        for dx, ch in enumerate(row):
            if ch != ".":
                p.px(x0 + dx, y0 + dy, cols[ch])


def shade(p: Pic) -> None:
    # --- wajah: dasar terang; pita warna tengah mengikuti lengkung pipi kanan, bayangan tipis di tepi
    p.shade("face", poly([(45.4, 17.4), (49.8, 20.8), (51.0, 24.6), (51.2, 28.6), (50.8, 32.2), (49.4, 36.0),
                          (47.2, 39.6), (44.4, 42.4), (42.0, 43.8), (39.0, 44.4), (36.8, 43.4), (40.6, 42.6),
                          (43.6, 40.0), (45.4, 36.8), (46.2, 33.6), (45.6, 31.8), (46.4, 28.6), (46.4, 24.6),
                          (45.2, 21.0), (43.6, 18.6)]), SK["b"])
    p.shade("face", poly([(48.4, 19.4), (50.4, 21.6), (51.4, 25.0), (51.6, 28.6), (51.2, 32.4), (49.8, 36.2),
                          (47.6, 39.8), (44.8, 42.6), (42.2, 44.0), (40.4, 44.6), (42.6, 42.4), (45.4, 39.6),
                          (47.4, 36.4), (48.6, 32.6), (49.2, 28.6), (48.8, 24.4), (47.6, 21.0)]), SK["s"])
    p.shade("face", poly([(30, 15), (50, 15), (50, 18.0), (46, 18.4), (40, 17.4), (34, 18.4), (30, 19.0)]), SK["b"])
    p.shade("face", poly([(30.6, 26.0), (31.6, 22.0), (31.0, 30.0), (31.6, 35.6), (34.0, 39.6), (33.4, 40.0), (30.6, 35.0), (29.8, 30.0)]), SK["b"])
    for x, y in ((34, 20), (35, 20), (36, 20), (35, 21), (33, 31), (34, 31)):
        p.shade("face", dot(x, y), SK["h"])
    # leher: bayangan rahang, sisi kiri lebih terang
    p.shade("neck", poly([(30, 43), (50, 43), (50, 46.4), (40, 47.4), (30, 46.4)]), SK["d"])
    p.shade("neck", poly([(34, 46), (37.6, 47), (37.2, 52), (33.6, 52)]), SK["b"])
    p.shade("vneck", poly([(43, 49), (47, 49), (42, 57), (40, 57)]), SK["s"])

    # --- rambut: kilau melengkung di kiri atas, bayangan di kanan
    p.shade("hair", poly([(46.0, 5.0), (50.6, 7.8), (53.6, 11.8), (54.6, 17.0), (54.4, 22.4), (53.4, 26.8),
                          (51.6, 29.6), (50.6, 28.0), (51.6, 23.0), (51.8, 18.6), (50.4, 13.4), (47.6, 9.2), (43.6, 6.6)]), HR["s"])
    p.shade("hair", poly([(29.0, 15.6), (30.4, 11.2), (33.6, 7.6), (38.0, 5.6), (41.0, 5.4), (40.0, 7.0),
                          (36.0, 8.4), (33.0, 11.0), (31.4, 14.4), (30.6, 18.0)]), HR["l"])
    for x, y in ((34, 8), (35, 7), (36, 7), (37, 6), (31, 12), (32, 11)):
        p.shade("hair", dot(x, y), HR["h"])
    # helai rambut disisir ke belakang
    for pts in (((36, 17), (34, 12), (35, 8)), ((33, 19), (31, 14), (32, 10))):
        line(p, pts, HR["l"], "hair")
    for pts in (((44, 17), (46, 12), (45, 8)), ((47, 19), (49, 14), (48, 10))):
        line(p, pts, HR["s"], "hair")
    # sanggul: kilau tipis di lengkung kiri
    p.shade("bun", poly([(22.6, 40.4), (24.0, 37.0), (27.0, 35.4), (29.0, 35.8), (26.0, 37.8), (24.4, 41.0)]), HR["l"])
    p.shade("bun", poly([(22, 42.6), (36, 42.6), (36, 46), (22, 46)]), HR["d"])

    # --- kebaya
    p.shade("arm_l", poly([(14, 60), (17.4, 59), (16.6, 66), (16.2, 80), (14, 80)]), GR["h"])
    p.shade("body", poly([(52, 56), (62, 58), (64, 80), (55, 80), (56, 66)]), GR["s"])
    p.shade("body", poly([(30, 60), (36, 56), (37, 60), (33, 63)]), GR["l"])
    line(p, [(59, 64), (59, 71), (59, 79)], GR["d"])
    line(p, [(21, 64), (21, 71), (21, 79)], GR["d"])
    # sampur: kilau di sisi luar, bayangan di sisi dalam, dua lipatan
    p.shade("sampur", poly([(17, 58), (21, 55), (23, 56), (20, 62), (19.4, 80), (16, 80)]), OR["l"])
    p.shade("sampur", poly([(29, 58), (33, 53), (33, 56), (29.6, 66), (28.6, 80), (26.4, 80), (27, 68)]), OR["s"])
    line(p, [(25, 55), (23, 62), (22, 72), (22, 79)], OR["s"])
    line(p, [(28, 54), (26, 60), (25, 70), (25, 79)], OR["d"])


def dot(x, y):
    m = np.zeros((W, W), bool)
    m[y, x] = True
    return m


def details(p: Pic) -> None:
    # --- alis tipis melengkung
    stamp(p, 31, 24, [
        "..dddd.",
        ".d....b",
        "b......",
    ], {"d": BROW, "b": SK["d"]})
    stamp(p, 43, 24, [
        ".dddd..",
        "b....d.",
        "......b",
    ], {"d": BROW, "b": SK["d"]})
    # --- mata menatap ke depan
    ec = dict(EYE)
    ec["s"] = SK["s"]
    ec["l"] = SK["s"]
    stamp(p, 31, 26, [
        "..ccc..",
        ".LLLLLL",
        "LvIHIws",
        ".viIiv.",
        "..lll..",
    ], ec)
    stamp(p, 43, 26, [
        "..ccc..",
        "LLLLLL.",
        "swIHIvL",
        ".viIiv.",
        "..lll..",
    ], ec)
    # --- hidung kecil
    for x, y, c in ((40, 31, SK["h"]), (40, 32, SK["h"]), (41, 33, SK["s"]), (41, 34, SK["s"]), (40, 34, SK["h"]),
                    (39, 35, SK["d"]), (40, 35, SK["s"]), (41, 35, SK["d"])):
        p.px(x, y, c)
    # --- bibir, senyum tipis
    stamp(p, 37, 38, [
        "j.....j",
        ".xuuux.",
        "..oho..",
        "...s...",
    ], {"j": SK["s"], "x": LIP["x"], "u": LIP["u"], "o": LIP["o"], "h": LIP["h"], "s": SK["s"]})
    # --- rona pipi
    for x, y in ((32, 34), (33, 34), (34, 34), (33, 35)):
        p.px(x, y, BLUSH)
    for x, y in ((46, 34), (47, 34), (48, 34), (47, 35)):
        p.px(x, y, (214, 132, 104))
    # --- subang
    for x in (27, 51):
        stamp(p, x, 33, [".a.", "brb", ".c."], {"a": GD["h"], "b": GD["l"], "r": RUBY, "c": GD["s"]})
    # --- cunduk mentul: tiga kuntum emas di atas kepala
    flower = [".aa.", "ahha", "ahha", ".ab."]
    fc = {"a": GD["l"], "h": GD["h"], "b": GD["s"]}
    for (sx0, sy0, sx1, sy1), (fx, fy) in (((40, 7, 40, 5), (39, 1)), ((35, 8, 34, 6), (32, 3)), ((45, 8, 46, 6), (46, 3))):
        line(p, [(sx0, sy0), (sx1, sy1)], GD["s"])
        stamp(p, fx, fy, flower, fc)
    # --- kalung tipis
    line(p, [(36, 46), (38, 48), (40, 49)], GD["l"])
    line(p, [(44, 46), (42, 48), (41, 49)], GD["l"])
    p.px(40, 50, RUBY)
    # --- kerah dan lis emas kebaya, panel belah ketupat
    line(p, [(35, 49), (37, 53), (37, 55)], GD["l"])
    line(p, [(45, 49), (43, 53), (43, 55)], GD["l"])
    line(p, [(37, 55), (37, 79)], GD["l"])
    line(p, [(43, 55), (43, 79)], GD["l"])
    line(p, [(36, 55), (36, 79)], GD["s"], "body")
    line(p, [(44, 55), (44, 79)], GD["s"], "body")
    for y in range(57, 80):
        for x in range(38, 43):
            if (x + y) % 4 == 0 and p.regions["panel"][y, x]:
                p.px(x, y, GD["b"])
            elif (x + y) % 4 == 2 and (x - y) % 4 == 0 and p.regions["panel"][y, x]:
                p.px(x, y, GD["s"])
    # --- tepi kuning selendang
    line(p, [(20, 55), (17, 59), (16, 66), (16, 79)], GD["l"])
    line(p, [(33, 53), (30, 60), (28, 68), (28, 79)], GD["l"])
    line(p, [(34, 49), (25, 52), (20, 55)], GD["b"])
    # motif kecil di kain kebaya
    for y in range(58, 80, 5):
        for x in range(2 + (y // 5 % 2) * 3, 78, 6):
            if p.regions["body"][y, x] and not (34 <= x <= 46):
                p.px(x, y, GR["l"] if x < 52 else GR["b"])


def outline(img):
    a = np.asarray(img).copy()
    al = a[..., 3] > 0
    g = np.zeros_like(al)
    g[1:, :] |= al[:-1, :]
    g[:-1, :] |= al[1:, :]
    g[:, 1:] |= al[:, :-1]
    g[:, :-1] |= al[:, 1:]
    ring = g & ~al
    a[ring] = OUT + (255,)
    return Image.fromarray(a, "RGBA")


def draw_roro_ayu() -> Image.Image:
    p = build()
    shade(p)
    details(p)
    return outline(p.image())
