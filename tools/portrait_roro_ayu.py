"""Potret dialog Roro Ayu (80x80, setengah badan), dipanggil dari tools/build_assets.py.

Berbeda dengan potret Eyang Palang dan Buto yang dipotong dari sprite, Roro Ayu
tidak punya sprite, jadi potretnya dilukis di sini. Bentuk dan bayangan dilukis
8x lebih besar lalu diperkecil (hasilnya halus seperti sprite lain), kemudian
mata, alis, hidung, dan bibir digambar piksel demi piksel supaya tetap tajam.

Penampilannya: wanita Jawa dengan sanggul berhias melati dan tusuk konde emas,
subang bermata merah, kebaya hijau berkerah sulaman emas, kemben batik, dan
selendang batik merah di bahu. Wajahnya sedikit menoleh, matanya melirik ke
kanan, ke arah teks dialog.
"""
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

S = 8
W = 80
OUTLINE = (16, 12, 24, 255)


def P(pts):
    return [(x * S, y * S) for x, y in pts]


def E(cx, cy, rx, ry):
    return [(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S]


def mirror(pts, axis):
    return [(2 * axis - x, y) for x, y in reversed(pts)]


def new_layer():
    return Image.new("RGBA", (W * S, W * S), (0, 0, 0, 0))


def mask_of(draw_fn):
    m = Image.new("L", (W * S, W * S), 0)
    draw_fn(ImageDraw.Draw(m))
    return m


def shaded(mask, base, light, dark, light_dir=(-0.6, -0.8), edge=3.0, center=None, spread=14.0, edge_dark=0.55):
    """Mengisi mask dengan warna bergradasi: terang ke arah cahaya, gelap di tepi dan sisi seberang."""
    m = np.asarray(mask).astype(np.float64) / 255.0
    ys, xs = np.nonzero(m > 0.5)
    if center is None:
        center = (xs.mean() / S, ys.mean() / S)
    yy, xx = np.mgrid[0:W * S, 0:W * S].astype(np.float64) / S
    lx, ly = light_dir
    dirv = ((xx - center[0]) * lx + (yy - center[1]) * ly) / spread
    blur = np.asarray(mask.filter(ImageFilter.GaussianBlur(edge * S))).astype(np.float64) / 255.0
    inner = np.clip((blur - 0.5) * 2.0, 0.0, 1.0)
    t = np.clip(0.5 + 0.5 * dirv, 0.0, 1.0) * (1 - edge_dark) + inner * edge_dark
    base = np.array(base[:3], dtype=np.float64)
    light = np.array(light[:3], dtype=np.float64)
    dark = np.array(dark[:3], dtype=np.float64)
    t3 = t[..., None]
    col = np.where(t3 > 0.5, base + (light - base) * (t3 - 0.5) * 2.0, dark + (base - dark) * t3 * 2.0)
    out = np.dstack([col, m * 255.0]).clip(0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def paste(dst, layer):
    dst.alpha_composite(layer)


SKIN = (238, 194, 156)
SKIN_L = (252, 222, 192)
SKIN_D = (196, 134, 106)
HAIR = (30, 24, 36)
HAIR_L = (92, 86, 128)
HAIR_D = (12, 9, 16)
KEBAYA = (36, 118, 74)
KEBAYA_L = (86, 172, 110)
KEBAYA_D = (16, 62, 40)
GOLD = (236, 184, 76)
GOLD_L = (255, 230, 150)
GOLD_D = (156, 104, 34)
BATIK = (126, 36, 44)
BATIK_L = (176, 70, 70)
BATIK_D = (70, 18, 28)
MELATI = (250, 250, 240)
MELATI_D = (200, 210, 192)
RUBY = (214, 52, 64)

FACE_R = [(43, 16), (48, 16.8), (51.6, 19.5), (53.4, 24), (53.7, 29), (52.7, 34), (50.6, 38.5), (47.6, 42.5), (45, 45.2), (43, 46.2)]
FACE = FACE_R[:-1] + mirror(FACE_R, 43)[1:]
# Kepala diturunkan sedikit supaya leher tidak terlalu panjang.
HEAD_DY = 2


def clip(a, b):
    return Image.fromarray(np.minimum(np.asarray(a), np.asarray(b)))


def tint(img, mask, color, strength):
    m = (np.asarray(mask).astype(np.float64) * strength).clip(0, 255).astype(np.uint8)
    img.paste(Image.new("RGBA", img.size, tuple(color) + (255,)), (0, 0), Image.fromarray(m))


def melati(d, x, y, r=1.5):
    d.ellipse(E(x, y, r, r * 0.92), fill=MELATI_D + (255,))
    d.ellipse(E(x - 0.3, y - 0.3, r * 0.62, r * 0.56), fill=MELATI + (255,))


def paint() -> Image.Image:
    img = new_layer()

    # --- leher
    neck = mask_of(lambda m: m.polygon(P([(38, 40), (48, 40), (49.5, 57.5), (36.5, 57.5)]), fill=255))
    paste(img, shaded(neck, SKIN, SKIN_L, SKIN_D, light_dir=(-0.9, 0.1), center=(43, 50), spread=7, edge_dark=0.3))
    chin_shadow = mask_of(lambda m: m.chord(E(43, 43.5 + HEAD_DY, 8, 6), 0, 180, fill=255)).filter(ImageFilter.GaussianBlur(0.6 * S))
    tint(img, clip(chin_shadow, neck), SKIN_D, 0.9)

    # --- bahu dan kebaya
    body_pts = [(0, 80), (0.5, 71), (5, 65.5), (15, 61.5), (27, 58.5), (36, 56.5), (50, 56.5), (59, 58.5), (71, 61.5), (79, 66), (80, 71), (80, 80)]
    body = mask_of(lambda m: m.polygon(P(body_pts), fill=255))
    paste(img, shaded(body, KEBAYA, KEBAYA_L, KEBAYA_D, center=(42, 70), spread=24, edge=2.5, edge_dark=0.35))
    d = ImageDraw.Draw(img)
    # dada di leher kebaya (bentuk V), lalu kemben batik
    vneck = [(36, 56.5), (50, 56.5), (47.5, 63), (43, 71), (38.5, 63)]
    vmask = mask_of(lambda m: m.polygon(P(vneck), fill=255))
    paste(img, shaded(vmask, SKIN, SKIN_L, SKIN_D, light_dir=(-0.9, 0.0), center=(43, 60), spread=7, edge_dark=0.25))
    kemben = clip(mask_of(lambda m: m.polygon(P([(36, 64), (50, 64), (43, 73)]), fill=255)), vmask)
    img.paste(Image.new("RGBA", img.size, BATIK_D + (255,)), (0, 0), kemben)
    d = ImageDraw.Draw(img)
    for x, y in ((40.5, 66), (43, 66), (45.5, 66), (42, 68.3), (44, 68.3)):
        d.ellipse(E(x, y, 0.55, 0.55), fill=GOLD + (255,))
    # motif brokat kecil di kain kebaya
    for x, y in ((24, 66), (30, 71), (21, 75), (58, 66), (64, 72), (56, 77), (70, 76), (34, 77)):
        d.ellipse(E(x, y, 0.9, 0.9), fill=KEBAYA_L + (255,))
        d.ellipse(E(x, y, 0.4, 0.4), fill=KEBAYA_D + (255,))
    # kerah kebaya bersulam emas
    for side in (-1, 1):
        edge = [(43 + side * 7.5, 56.5), (43 + side * 4.6, 63), (43, 71.5)]
        d.line(P(edge), fill=GOLD_D + (255,), width=int(2.6 * S))
        d.line(P(edge), fill=GOLD + (255,), width=int(1.5 * S))
        for k in range(6):
            t = (k + 0.5) / 6
            if t < 0.5:
                x = edge[0][0] + (edge[1][0] - edge[0][0]) * t * 2
                y = edge[0][1] + (edge[1][1] - edge[0][1]) * t * 2
            else:
                x = edge[1][0] + (edge[2][0] - edge[1][0]) * (t - 0.5) * 2
                y = edge[1][1] + (edge[2][1] - edge[1][1]) * (t - 0.5) * 2
            d.ellipse(E(x, y, 0.45, 0.45), fill=GOLD_L + (255,))
    # selendang batik merah di bahu kiri
    shawl = [(1, 68), (7, 63.5), (14, 61.5), (22, 72), (26, 80), (8, 80), (3, 74)]
    smask = mask_of(lambda m: m.polygon(P(shawl), fill=255))
    paste(img, shaded(clip(smask, body), BATIK, BATIK_L, BATIK_D, center=(12, 70), spread=10, edge_dark=0.3))
    d = ImageDraw.Draw(img)
    d.line(P([(14, 61.5), (22, 72), (26, 80)]), fill=GOLD + (255,), width=int(1.1 * S))
    for x, y in ((7, 69), (11, 66.5), (12, 73), (16, 70), (17, 77), (8, 76), (21, 79)):
        d.ellipse(E(x, y, 0.9, 0.9), fill=GOLD + (255,))
        d.ellipse(E(x, y, 0.35, 0.35), fill=BATIK_D + (255,))
    # kalung emas tipis
    d.arc(E(43, 52.5, 6.4, 4.2), 20, 160, fill=GOLD + (255,), width=int(0.8 * S))
    d.ellipse(E(43, 57.0, 1.1, 1.3), fill=GOLD + (255,))
    d.ellipse(E(43, 57.1, 0.5, 0.6), fill=RUBY + (255,))

    # --- kepala digambar di lapisan sendiri lalu diturunkan HEAD_DY piksel
    body_img = img
    img = new_layer()
    # --- sanggul (konde) di belakang kepala, tampak dari samping kiri karena wajah sedikit menoleh
    bun = mask_of(lambda m: m.ellipse(E(28, 21, 9.5, 8.5), fill=255))
    paste(img, shaded(bun, HAIR, HAIR_L, HAIR_D, center=(25, 18), spread=9))
    d = ImageDraw.Draw(img)
    for r in (3.0, 6.0):
        d.arc(E(27, 21, r + 1.2, r), 190, 320, fill=HAIR_L + (255,), width=S)
    # tusuk konde emas berhias bunga kecil
    d.line(P([(17, 10.5), (31, 23)]), fill=GOLD_D + (255,), width=int(1.6 * S))
    d.line(P([(17, 10.0), (30, 21.6)]), fill=GOLD + (255,), width=int(0.9 * S))
    for dx, dy in ((0, -1.6), (1.6, 0), (0, 1.6), (-1.6, 0)):
        d.ellipse(E(16.5 + dx, 10 + dy, 1.4, 1.4), fill=GOLD + (255,))
    d.ellipse(E(16.5, 10, 1.1, 1.1), fill=RUBY + (255,))
    d.ellipse(E(16.1, 9.6, 0.4, 0.4), fill=(255, 170, 170, 255))
    # melati melingkari sanggul
    for i in range(8):
        a = math.radians(105 + i * 19)
        melati(d, 28 + 9.4 * math.cos(a), 21 + 8.4 * math.sin(a), 1.4)

    # --- rambut: disisir rapi ke belakang
    back = mask_of(lambda m: m.ellipse(E(42.6, 23.5, 13.6, 14.2), fill=255))
    paste(img, shaded(back, HAIR, HAIR_L, HAIR_D, center=(39, 17), spread=13))

    # --- telinga
    d = ImageDraw.Draw(img)
    for x, flip in ((32.6, -1), (53.4, 1)):
        ear = mask_of(lambda m, x=x: m.ellipse(E(x, 33.2, 1.5, 2.7), fill=255))
        paste(img, shaded(ear, SKIN, SKIN_L, SKIN_D, center=(x, 33), spread=3, edge_dark=0.5))

    # --- wajah
    face = mask_of(lambda m: m.polygon(P(FACE), fill=255))
    paste(img, shaded(face, SKIN, SKIN_L, SKIN_D, light_dir=(-0.8, -0.4), center=(42, 30), spread=15, edge=2.0, edge_dark=0.45))
    # bayangan rambut di dahi
    hair_shadow = mask_of(lambda m: m.ellipse(E(43, 15.5, 11, 5.5), fill=255)).filter(ImageFilter.GaussianBlur(1.0 * S))
    tint(img, clip(hair_shadow, face), SKIN_D, 0.45)
    # rona pipi dan kilau tulang pipi
    for cx in (36.3, 49.7):
        blush = mask_of(lambda m, cx=cx: m.ellipse(E(cx, 36.2, 3.0, 1.7), fill=255)).filter(ImageFilter.GaussianBlur(0.9 * S))
        tint(img, clip(blush, face), (236, 146, 138), 0.55)
    shine = mask_of(lambda m: m.ellipse(E(36.5, 33.5, 2.2, 1.2), fill=255)).filter(ImageFilter.GaussianBlur(0.6 * S))
    tint(img, clip(shine, face), SKIN_L, 0.5)

    # --- rambut depan: belah tengah, menutupi pelipis sampai atas telinga
    left = [(43, 13.2), (38.6, 14.0), (34.6, 16.4), (31.6, 20.4), (30.4, 25.4), (30.8, 30.6), (32.6, 31.6),
            (33.2, 27.0), (34.5, 22.6), (37.2, 19.6), (40.5, 18.1), (43, 17.8)]
    right = mirror(left, 43)
    front = mask_of(lambda m: (m.polygon(P(left), fill=255), m.polygon(P(right), fill=255),
                               m.ellipse(E(43, 14.6, 11.2, 4.6), fill=255)))
    paste(img, shaded(front, HAIR, HAIR_L, HAIR_D, center=(37, 14), spread=10, edge_dark=0.2))
    d = ImageDraw.Draw(img)
    d.arc(E(39.5, 23, 9.5, 12.5), 205, 250, fill=HAIR_L + (255,), width=S)
    d.arc(E(46.5, 23, 9.5, 12.5), 292, 318, fill=(66, 62, 96, 255), width=S)
    d.line(P([(43, 11.0), (43, 16.0)]), fill=HAIR_D + (255,), width=S)

    # --- subang emas di cuping telinga
    for x in (32.4, 53.6):
        d.ellipse(E(x, 37.2, 1.6, 1.6), fill=GOLD_D + (255,))
        d.ellipse(E(x, 37.2, 1.1, 1.1), fill=GOLD + (255,))
        d.ellipse(E(x, 37.2, 0.55, 0.55), fill=RUBY + (255,))

    shifted = new_layer()
    shifted.paste(img, (0, HEAD_DY * S))
    body_img.alpha_composite(shifted)
    return body_img


def downscale(img: Image.Image) -> Image.Image:
    small = img.convert("RGBa").resize((W, W), Image.BOX).convert("RGBA")
    a = np.asarray(small).copy()
    a[..., 3] = np.where(a[..., 3] >= 110, 255, 0)
    return Image.fromarray(a, "RGBA").copy()


def features(img: Image.Image) -> Image.Image:
    """Mata, alis, hidung, dan bibir digambar piksel demi piksel supaya tajam."""
    px = img.load()

    def put(x, y, c):
        px[x, y + HEAD_DY] = tuple(c[:3]) + (255,)

    brow = (84, 54, 44)
    brow_l = (150, 104, 84)
    lash = (36, 20, 26)
    white = (242, 238, 234)
    white_d = (214, 200, 196)
    iris = (66, 38, 30)
    iris_l = (128, 82, 56)
    lid = (220, 164, 134)
    under = (224, 172, 146)
    for cx, side in ((38, -1), (48, 1)):
        # cx = tengah mata, side = arah sudut luarnya (-1 kiri, 1 kanan)
        def X(dx, cx=cx, side=side):
            return cx + side * dx
        # alis: tipis, melengkung, ujung luar sedikit turun
        for dx, y, c in ((-2, 27, brow_l), (-1, 27, brow), (0, 26, brow), (1, 26, brow), (2, 26, brow), (3, 27, brow), (4, 28, brow_l)):
            put(X(dx), y, c)
        # lipatan kelopak tipis
        for dx in (-1, 0, 1, 2):
            put(X(dx), 29, lid)
        # bulu mata atas tebal, bersayap di sudut luar
        for dx in (-2, -1, 0, 1, 2, 3):
            put(X(dx), 30, lash)
        put(X(4), 29, lash)
        # bola mata dua baris; iris besar di kedua mata melirik ke kanan (ke arah teks)
        x0 = cx - 1 if side < 0 else cx
        for x, c in ((x0 - 2, white_d), (x0 - 1, white), (x0, iris), (x0 + 1, (250, 250, 255)), (x0 + 2, iris), (x0 + 3, white_d)):
            put(x, 31, c)
        for x, c in ((x0 - 1, white_d), (x0, iris_l), (x0 + 1, iris), (x0 + 2, iris_l), (x0 + 3, white_d)):
            put(x, 32, c)
        # garis bawah mata lembut
        for dx in (-1, 0, 1, 2):
            put(X(dx), 33, under)
    # hidung: bayangan halus di sisi kanan, ujung terang, cuping
    for y, c in ((33, (222, 168, 136)), (34, (218, 162, 130)), (35, (212, 154, 124))):
        put(44, y, c)
    put(43, 36, (250, 224, 198))
    put(42, 37, (198, 132, 108))
    put(44, 37, (190, 124, 102))
    put(43, 37, (226, 168, 140))
    # bibir: merah merona, bawah lebih terang dengan kilau
    upper = (172, 56, 72)
    lower = (212, 88, 100)
    put(40, 40, (200, 120, 110))
    put(41, 40, upper)
    put(42, 40, upper)
    put(43, 40, (192, 76, 88))
    put(44, 40, upper)
    put(45, 40, upper)
    put(46, 40, (200, 120, 110))
    for x in (41, 42, 43, 44, 45):
        put(x, 41, lower)
    put(42, 41, (240, 146, 146))
    for x in (42, 43, 44):
        put(x, 42, (208, 140, 120))
    return img


def add_outline(img, color=OUTLINE):
    a = np.asarray(img).copy()
    alpha = a[..., 3] > 0
    grow = np.zeros_like(alpha)
    grow[1:, :] |= alpha[:-1, :]
    grow[:-1, :] |= alpha[1:, :]
    grow[:, 1:] |= alpha[:, :-1]
    grow[:, :-1] |= alpha[:, 1:]
    ring = grow & ~alpha
    a[ring] = color
    return Image.fromarray(a, "RGBA")


def draw_roro_ayu() -> Image.Image:
    return add_outline(features(downscale(paint())))
