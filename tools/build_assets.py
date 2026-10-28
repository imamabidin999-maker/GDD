"""Membangun semua aset grafis game dari desain asli di docs/desain_asli/.

Jalankan dari root repo:
    python3 tools/build_assets.py

Butuh Python 3 + Pillow + numpy. Hasilnya ditulis ke assets/ dan langsung
dipakai Godot. Desain asli tidak diubah.

Isinya:
1. Karakter (Eyang Palang + 5 Buto): latar navy dihapus jadi transparan.
2. (Latar battle sekarang digambar oleh tools/build_backgrounds.py.)
3. Bingkai kartu: kartu FOCUS di desain dijadikan template, judul & gambarnya
   dikosongkan, lalu diwarnai ulang untuk tiap tipe kartu.
4. Ikon yang belum ada di desain (keris, padupan, tameng kawung, tombak,
   pusaran, alat musik Tabuh, ikon niat musuh, gembok, dll.) digambar dengan
   gaya yang sama.
5. Ikon topeng Buto dan potret dialog dipotong dari sprite; potret Roro Ayu
   dipotong dari desain sprite diamnya oleh tools/portrait_roro_ayu.py.
"""
from __future__ import annotations

import math
import os
from collections import deque

import numpy as np
from PIL import Image, ImageDraw

from portrait_roro_ayu import draw_roro_ayu
from roro_sprites import draw_ayu_sprite, draw_perot_portrait, draw_perot_sprite

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "docs", "desain_asli")
OUT = os.path.join(ROOT, "assets")


def src(name_id: str) -> str:
    return os.path.join(SRC, f"watermarked_img_{name_id}.jpg")


def save(img: Image.Image, rel: str) -> None:
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("  ", rel, img.size)


# ---------------------------------------------------------------------------
# 1. Karakter
# ---------------------------------------------------------------------------

CHARACTERS = {
    "11953446248845365992": "sprites/hero/eyang_palang_idle.png",
    "16789709125057819876": "sprites/hero/eyang_palang_attack_1.png",
    "17293160605318372196": "sprites/hero/eyang_palang_attack_2.png",
    "2990990066715652855": "sprites/buto/buto_kuning_idle.png",
    "2975913325495764369": "sprites/buto/buto_kuning_attack.png",
    "13928662692508856276": "sprites/buto/buto_hijau_idle.png",
    "10940979905639764417": "sprites/buto/buto_hijau_attack.png",
    "8392346602828052825": "sprites/buto/buto_merah_idle.png",
    "8125092819475861454": "sprites/buto/buto_merah_attack.png",
    "17302615723016600350": "sprites/buto/buto_putih_idle.png",
    "13081834223095883243": "sprites/buto/buto_putih_attack.png",
    "14563013163635915985": "sprites/buto/buto_hitam_idle.png",
    "8928511970749154579": "sprites/buto/buto_hitam_attack.png",
}

T_HARD = 13.0
T_SOFT = 34.0


def _flood(mask_ok: np.ndarray, seeds: list[tuple[int, int]]) -> np.ndarray:
    h, w = mask_ok.shape
    out = np.zeros((h, w), dtype=bool)
    q = deque()
    for y, x in seeds:
        if mask_ok[y, x] and not out[y, x]:
            out[y, x] = True
            q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and mask_ok[ny, nx] and not out[ny, nx]:
                out[ny, nx] = True
                q.append((ny, nx))
    return out


def cut_character(path: str, remove_pockets: bool) -> Image.Image:
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    h, w, _ = rgb.shape
    border = np.concatenate([rgb[0:3].reshape(-1, 3), rgb[-3:].reshape(-1, 3),
                             rgb[:, 0:3].reshape(-1, 3), rgb[:, -3:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    dist = np.sqrt(((rgb - bg) ** 2).sum(axis=2))

    seeds = [(y, x) for x in range(w) for y in (0, h - 1)] + [(y, x) for y in range(h) for x in (0, w - 1)]
    is_bg = _flood(dist <= T_HARD, seeds)

    if remove_pockets:
        # Kantong latar yang tertutup (misalnya di antara lengan dan badan Buto).
        pocket = (dist <= T_HARD * 0.8) & ~is_bg
        seen = np.zeros((h, w), dtype=bool)
        for sy in range(h):
            for sx in range(w):
                if pocket[sy, sx] and not seen[sy, sx]:
                    comp = _flood(pocket & ~seen, [(sy, sx)])
                    seen |= comp
                    if comp.sum() >= 25:
                        is_bg |= comp

    alpha = np.ones((h, w), dtype=np.float32)
    alpha[is_bg] = 0.0
    near = np.zeros((h, w), dtype=bool)
    near[1:, :] |= is_bg[:-1, :]
    near[:-1, :] |= is_bg[1:, :]
    near[:, 1:] |= is_bg[:, :-1]
    near[:, :-1] |= is_bg[:, 1:]
    edge = near & ~is_bg
    a_edge = np.clip((dist - T_HARD) / (T_SOFT - T_HARD), 0.0, 1.0)
    alpha[edge] = a_edge[edge]

    out = rgb.copy()
    m = edge & (alpha > 0.05)
    a3 = alpha[m][:, None]
    out[m] = np.clip((rgb[m] - (1.0 - a3) * bg) / a3, 0, 255)
    alpha = np.where(alpha < 0.35, 0.0, np.where(alpha < 0.75, 0.6, 1.0))
    return Image.fromarray(np.dstack([out, alpha * 255.0]).astype(np.uint8), "RGBA")


def build_characters() -> dict[str, Image.Image]:
    print("Karakter:")
    result = {}
    for key, rel in CHARACTERS.items():
        img = cut_character(src(key), remove_pockets=not rel.startswith("sprites/hero"))
        if rel.startswith("sprites/buto") and rel.endswith("_idle.png"):
            # Di desain asli pose diam Buto menghadap kanan, sedangkan pose
            # serangnya sudah menghadap kiri. Di game Buto berdiri di kanan dan
            # harus menghadap Eyang Palang, jadi hanya pose diam yang dibalik.
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
        save(img, rel)
        result[os.path.basename(rel)[:-4]] = img
    return result


# ---------------------------------------------------------------------------
# 2. Latar
# ---------------------------------------------------------------------------

# Latar battle dan layar lain digambar terpisah oleh tools/build_backgrounds.py.


# ---------------------------------------------------------------------------
# 3. Warna (HSV) dan bingkai kartu
# ---------------------------------------------------------------------------

def rgb_to_hsv(a: np.ndarray) -> np.ndarray:
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx = a.max(axis=-1)
    mn = a.min(axis=-1)
    d = mx - mn
    h = np.zeros_like(mx)
    nz = d > 1e-6
    rm = nz & (mx == r)
    gm = nz & (mx == g) & ~rm
    bm = nz & ~rm & ~gm
    h[rm] = ((g[rm] - b[rm]) / d[rm]) % 6
    h[gm] = (b[gm] - r[gm]) / d[gm] + 2
    h[bm] = (r[bm] - g[bm]) / d[bm] + 4
    h = h / 6.0
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0)
    return np.stack([h, s, mx], axis=-1)


def hsv_to_rgb(a: np.ndarray) -> np.ndarray:
    h, s, v = a[..., 0], a[..., 1], a[..., 2]
    i = np.floor(h * 6).astype(int) % 6
    f = h * 6 - np.floor(h * 6)
    p = v * (1 - s)
    q = v * (1 - f * s)
    t = v * (1 - (1 - f) * s)
    out = np.zeros(a.shape)
    for k, (rr, gg, bb) in enumerate([(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)]):
        m = i == k
        out[..., 0][m] = rr[m]
        out[..., 1][m] = gg[m]
        out[..., 2][m] = bb[m]
    return out


def recolor(img: Image.Image, hue: float, sat_mul: float = 1.0, val_mul: float = 1.0) -> Image.Image:
    rgba = np.asarray(img.convert("RGBA")).astype(np.float64)
    hsv = rgb_to_hsv(rgba[..., :3] / 255.0)
    hsv[..., 0] = hue % 1.0
    hsv[..., 1] = np.clip(hsv[..., 1] * sat_mul, 0, 1)
    hsv[..., 2] = np.clip(hsv[..., 2] * val_mul, 0, 1)
    rgb = hsv_to_rgb(hsv) * 255.0
    return Image.fromarray(np.dstack([rgb, rgba[..., 3]]).clip(0, 255).astype(np.uint8), "RGBA")


CARD_BOX = (42, 27, 118, 133)  # posisi kartu FOCUS di desain
CARD_HUES = {
    "fokus": None,            # biru asli
    "serang": 0.995,          # merah
    "taktik": 0.36,           # hijau
    "crimson": 0.88,          # magenta (Serang + Fokus)
    "piercing": 0.085,        # jingga (Serang + Taktik)
    "flow": 0.48,             # toska (Fokus + Taktik)
}
# Kartu Tabuh: perunggu (lebih gelap dan kurang jenuh dari jingga Piercing).
TABUH_FRAME = (0.13, 1.0, 1.08)


def blank_card_template() -> tuple[Image.Image, Image.Image]:
    """Mengembalikan (template kosong, ikon mata asli)."""
    full = Image.open(src("6155704963498552534")).convert("RGB")
    card = full.crop(CARD_BOX)
    a = np.asarray(card).astype(np.float64)

    eye = card.crop((17, 35, 62, 71))

    # Kosongkan tulisan judul: isi tiap baris dengan warna latar bar di kiri-kanan teks.
    for y in range(10, 20):
        left = a[y, 13]
        right = a[y, 61]
        a[y, 14:61] = (left + right) / 2.0
    # Kosongkan gambar mata: isi tiap baris dengan warna jendela gambar.
    for y in range(34, 72):
        left = a[y, 14]
        right = a[y, 63]
        a[y, 15:63] = (left + right) / 2.0
    blank = Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGB").convert("RGBA")
    return blank, eye


def eye_icon(eye_rgb: Image.Image) -> Image.Image:
    a = np.asarray(eye_rgb.convert("RGB")).astype(np.float64)
    # latar jendela kartu gelap kebiruan; buang piksel yang mirip latar
    bg = np.median(np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]]), axis=0)
    dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
    alpha = np.where(dist > 22, 255, 0)
    return Image.fromarray(np.dstack([a, alpha]).astype(np.uint8), "RGBA")


def build_card_frames() -> Image.Image:
    print("Bingkai kartu:")
    blank, eye = blank_card_template()
    for name, hue in CARD_HUES.items():
        frame = blank if hue is None else recolor(blank, hue, sat_mul=1.05)
        save(frame, f"cards/frame_{name}.png")
    hue, sat, val = TABUH_FRAME
    save(recolor(blank, hue, sat_mul=sat, val_mul=val), "cards/frame_tabuh.png")
    # Mata dari desain asli sekarang hanya dipakai kartu Tenaga Dalam (mata merah).
    return eye_icon(eye)


# ---------------------------------------------------------------------------
# 4. Ikon tambahan (digambar dengan gaya piksel yang sama)
# ---------------------------------------------------------------------------

OUTLINE = (12, 13, 24, 255)


def add_outline(img: Image.Image, color=OUTLINE) -> Image.Image:
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


def canvas(w: int, h: int) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def draw_swirl(size: int = 40) -> Image.Image:
    img, d = canvas(size, size)
    cx, cy = 20, 20
    prev = None
    for i in range(0, 260):
        t = i / 260.0 * 4.2 * math.pi
        r = 2 + t * 1.25
        x, y = cx + r * math.cos(t), cy + r * math.sin(t)
        if prev is not None:
            col = (90, 200, 230, 255) if i % 40 < 26 else (110, 220, 150, 255)
            d.line([prev, (x, y)], fill=col, width=2)
        prev = (x, y)
    d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=(240, 250, 255, 255))
    return add_outline(img)


def draw_gong(size: int = 40) -> Image.Image:
    img, d = canvas(size, size)
    d.ellipse([4, 4, 36, 36], fill=(196, 140, 52, 255))
    d.ellipse([7, 7, 33, 33], fill=(232, 182, 72, 255))
    d.arc([7, 7, 33, 33], 200, 300, fill=(255, 230, 150, 255), width=2)
    d.ellipse([14, 14, 26, 26], fill=(196, 140, 52, 255))
    d.ellipse([16, 15, 24, 23], fill=(250, 214, 120, 255))
    return add_outline(img)


WOOD = (150, 92, 52, 255)
WOOD_D = (98, 58, 34, 255)
WOOD_L = (190, 130, 76, 255)
SKIN = (232, 214, 168, 255)
BRONZE = (196, 140, 52, 255)
BRONZE_L = (250, 214, 120, 255)
BRONZE_D = (140, 96, 36, 255)


def draw_bedug(size: int = 40) -> Image.Image:
    """Bedug: gendang besar berbaring di atas penyangga, dengan pemukulnya."""
    img, d = canvas(size, size)
    d.line([(8, 34), (14, 26)], fill=WOOD_D, width=2)
    d.line([(32, 34), (26, 26)], fill=WOOD_D, width=2)
    d.polygon([(8, 10), (30, 10), (34, 18), (30, 27), (8, 27), (11, 18)], fill=WOOD)
    d.line([(9, 12), (29, 12)], fill=WOOD_L)
    for x in (14, 19, 24):
        d.line([(x, 10), (x, 27)], fill=WOOD_D)
    d.ellipse([3, 9, 13, 28], fill=WOOD_D)
    d.ellipse([4, 10, 12, 27], fill=SKIN)
    d.ellipse([6, 14, 9, 21], fill=(250, 238, 200, 255))
    d.line([(26, 4), (36, 0)], fill=WOOD_L, width=2)
    d.ellipse([22, 3, 27, 8], fill=SKIN)
    return add_outline(img)


def draw_kentongan(size: int = 40) -> Image.Image:
    """Kentongan: batang bambu berlubang memanjang yang digantung, dan pemukulnya."""
    img, d = canvas(size, size)
    d.arc([15, 0, 23, 8], 180, 360, fill=(200, 170, 120, 255))
    d.line([(15, 4), (15, 6)], fill=(200, 170, 120, 255))
    d.line([(23, 4), (23, 6)], fill=(200, 170, 120, 255))
    d.rounded_rectangle([12, 5, 26, 37], radius=5, fill=(176, 150, 82, 255))
    d.line([(14, 8), (14, 34)], fill=(214, 190, 116, 255))
    d.line([(24, 8), (24, 34)], fill=(130, 108, 56, 255))
    d.line([(12, 16), (26, 16)], fill=(130, 108, 56, 255))
    d.rectangle([18, 19, 20, 33], fill=(60, 40, 24, 255))
    d.line([(30, 22), (38, 30)], fill=WOOD, width=2)
    d.ellipse([27, 19, 32, 24], fill=WOOD_D)
    return add_outline(img)


def draw_korek(size: int = 40) -> Image.Image:
    """Korek: alat kayu bergerigi yang diputar sehingga berbunyi "krek"."""
    img, d = canvas(size, size)
    d.rectangle([6, 14, 30, 30], fill=WOOD)
    d.rectangle([8, 16, 28, 28], fill=WOOD_D)
    d.line([(6, 14), (30, 14)], fill=WOOD_L)
    cx, cy = 18, 22
    for i in range(10):
        ang = i * math.pi / 5
        x = cx + math.cos(ang) * 8
        y = cy + math.sin(ang) * 8
        d.rectangle([x - 1, y - 1, x + 1, y + 1], fill=(214, 190, 140, 255))
    d.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=(214, 190, 140, 255))
    d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=WOOD_D)
    d.line([(cx, cy), (34, 6)], fill=WOOD_L, width=2)
    d.rectangle([32, 3, 36, 8], fill=WOOD_D)
    d.line([(3, 8), (6, 11)], fill=(255, 230, 150, 255))
    d.line([(2, 13), (5, 13)], fill=(255, 230, 150, 255))
    return add_outline(img)


def draw_gong_card(size: int = 40) -> Image.Image:
    """Gong besar yang tergantung di rangka kayu."""
    img, d = canvas(size, size)
    d.rectangle([3, 2, 36, 5], fill=WOOD)
    d.line([(3, 2), (36, 2)], fill=WOOD_L)
    d.rectangle([3, 5, 6, 37], fill=WOOD)
    d.rectangle([33, 5, 36, 37], fill=WOOD)
    d.line([(16, 5), (17, 9)], fill=(200, 170, 120, 255))
    d.line([(23, 5), (22, 9)], fill=(200, 170, 120, 255))
    d.ellipse([8, 8, 31, 31], fill=BRONZE_D)
    d.ellipse([9, 9, 30, 30], fill=BRONZE)
    d.arc([9, 9, 30, 30], 200, 300, fill=BRONZE_L, width=2)
    d.ellipse([15, 15, 24, 24], fill=BRONZE_D)
    d.ellipse([16, 15, 23, 22], fill=BRONZE_L)
    return add_outline(img)


def draw_kenong(size: int = 40) -> Image.Image:
    """Kenong: gong pencon besar yang duduk di atas tali dalam kotak kayu."""
    img, d = canvas(size, size)
    d.polygon([(4, 26), (36, 26), (32, 36), (8, 36)], fill=WOOD)
    d.line([(4, 26), (36, 26)], fill=WOOD_L)
    d.line([(9, 28), (31, 34)], fill=(200, 170, 120, 255))
    d.line([(9, 34), (31, 28)], fill=(200, 170, 120, 255))
    d.ellipse([7, 12, 33, 30], fill=BRONZE_D)
    d.ellipse([8, 12, 32, 28], fill=BRONZE)
    d.arc([8, 12, 32, 28], 190, 280, fill=BRONZE_L, width=2)
    d.ellipse([15, 6, 25, 16], fill=BRONZE_D)
    d.ellipse([16, 6, 24, 14], fill=BRONZE_L)
    d.point((18, 8), fill=(255, 245, 200, 255))
    return add_outline(img)


def draw_gong_beri(size: int = 40) -> Image.Image:
    """Gong beri: gong datar tanpa pencu dan bersisi tipis, digantung pada tali,
    dengan pemukul berlapis kain dan garis desing di tepinya."""
    img, d = canvas(size, size)
    # tali gantungan
    d.line([(13, 1), (19, 6)], fill=(200, 170, 120, 255))
    d.line([(25, 1), (19, 6)], fill=(200, 170, 120, 255))
    d.rectangle([11, 0, 27, 1], fill=WOOD)
    # garis desing di kanan atas
    for a, b in (((31, 6), (35, 2)), ((34, 11), (38, 9)), ((35, 16), (39, 16))):
        d.line([a, b], fill=GOLD_L)
    # piringan datar: tepi tipis, permukaan berpalu, tanpa tonjolan di tengah
    cx, cy, r = 19, 21, 15
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=BRONZE_D)
    d.ellipse([cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1], fill=BRONZE)
    for rr, col in ((11, BRONZE_L), (7, BRONZE_D), (4, BRONZE_L)):
        d.arc([cx - rr, cy - rr, cx + rr, cy + rr], 200, 320, fill=col)
        d.arc([cx - rr, cy - rr, cx + rr, cy + rr], 20, 140, fill=BRONZE_D if col == BRONZE_L else BRONZE_L)
    d.arc([cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2], 195, 285, fill=GOLD_L, width=2)
    # ukiran naga kecil yang melingkar
    d.arc([cx - 3, cy - 3, cx + 3, cy + 3], 0, 270, fill=BRONZE_D)
    d.line([(cx + 3, cy), (cx + 6, cy + 3)], fill=BRONZE_D)
    d.point((cx - 1, cy - 1), fill=GOLD_L)
    # pemukul: tangkai kayu dan kepala berlapis kain merah
    d.line([(37, 38), (30, 31)], fill=WOOD, width=2)
    d.line([(38, 37), (31, 30)], fill=WOOD_L)
    d.ellipse([24, 25, 31, 32], fill=(150, 44, 40, 255))
    d.ellipse([25, 26, 29, 30], fill=(196, 72, 60, 255))
    return add_outline(img)


# Kartu dasar bernuansa Jawa: keris (Sabet), padupan (Semedi), tameng (Tangkis),
# dan tombak (Tangkis Balik), dengan palet kayu-perunggu yang sama dengan Tabuh.
GOLD = (232, 182, 72, 255)
GOLD_L = (255, 226, 140, 255)
GOLD_D = (168, 118, 40, 255)

# Sumbu diagonal: dari kiri bawah ke kanan atas.
U = (1 / math.sqrt(2), -1 / math.sqrt(2))
N = (1 / math.sqrt(2), 1 / math.sqrt(2))


def at(base, s, t):
    """Titik sejauh s di sepanjang sumbu diagonal dan t tegak lurus darinya."""
    return (base[0] + U[0] * s + N[0] * t, base[1] + U[1] * s + N[1] * t)


def band(d, base, s0, s1, t0, t1, fill):
    """Pita tegak lurus sumbu, misalnya cincin emas di gagang."""
    d.polygon([at(base, s0, t0), at(base, s1, t0), at(base, s1, t1), at(base, s0, t1)], fill=fill)


def draw_keris(size: int = 40) -> Image.Image:
    """Keris luk lima: bilah berkelok dengan pamor, ganja, mendak emas, dan deder kayu."""
    img, d = canvas(size, size)
    base = (15.0, 25.0)
    length = 26.0
    steel = (140, 146, 164, 255)
    steel_d = (96, 102, 120, 255)
    pamor = (224, 230, 242, 255)

    def wave(s):
        ramp = min(1.0, max(0.0, (s - 5.0) / 3.0), max(0.0, (length - 1.0 - s) / 4.0))
        return 1.2 * ramp * math.sin(2 * math.pi * 2.5 * (s - 5.0) / (length - 5.0))

    def half(s):
        if s < 5.0:
            return 3.4 - 0.1 * s
        return 2.9 - 2.4 * ((s - 5.0) / (length - 5.0)) ** 1.3

    steps = [i * 0.5 for i in range(int(length * 2) + 1)]
    left = [at(base, s, wave(s) - half(s)) for s in steps]
    right = [at(base, s, wave(s) + half(s)) for s in reversed(steps)]
    d.polygon(left + right, fill=steel)
    shade = [at(base, s, wave(s) + 0.3) for s in steps]
    d.polygon(shade + right, fill=steel_d)
    d.line([at(base, s, wave(s) * 0.7 - 1.0) for s in steps[3:-8]], fill=pamor, width=1)
    # ganja: tumpul di sisi gandik, meruncing di sisi lain
    d.polygon([at(base, -2.0, -4.4), at(base, 0.6, -4.0), at(base, 0.6, 3.6), at(base, -0.6, 5.6), at(base, -2.0, 4.2)], fill=(70, 74, 90, 255))
    d.line([at(base, -0.7, -3.9), at(base, -0.7, 4.0)], fill=steel, width=1)
    # mendak emas
    band(d, base, -4.0, -2.0, -2.6, 2.6, GOLD)
    d.line([at(base, -2.6, -2.2), at(base, -2.6, 2.2)], fill=GOLD_L, width=1)
    # deder kayu yang kepalanya menunduk
    d.line([at(base, -4.0, 0), at(base, -9.0, 0.6), at(base, -12.0, -1.6), at(base, -12.6, -4.2)], fill=WOOD, width=5)
    d.line([at(base, -4.4, -1.6), at(base, -9.0, -1.2), at(base, -10.8, -2.8)], fill=WOOD_L, width=1)
    d.line([at(base, -4.6, 2.0), at(base, -9.6, 2.4)], fill=WOOD_D, width=1)
    return add_outline(img)


def draw_padupan(size: int = 40) -> Image.Image:
    """Padupan (anglo dupa) perunggu dengan asap kemenyan yang naik berkelok."""
    img, d = canvas(size, size)
    # tiga alur asap sejajar, dulu, supaya padupan menutupi pangkalnya
    smoke = (164, 198, 238, 255)
    smoke_l = (236, 244, 255, 255)
    for x0, top in ((14.5, 9.0), (20.0, 2.0), (25.5, 9.0)):
        pts = []
        y = 21.0
        while y >= top:
            pts.append((x0 + 1.7 * math.sin((21.0 - y) * 0.5), y))
            y -= 0.5
        d.line(pts, fill=smoke, width=2)
        d.line(pts[3:-3], fill=smoke_l, width=1)
    # kaki dan batang
    d.polygon([(12, 37), (28, 37), (25, 33), (15, 33)], fill=BRONZE_D)
    d.line([(14, 34), (26, 34)], fill=BRONZE, width=1)
    d.rectangle([17, 29, 23, 33], fill=BRONZE)
    d.line([(18, 29), (18, 33)], fill=BRONZE_L)
    # mangkuk
    d.chord([7, 15, 33, 33], 0, 180, fill=BRONZE)
    d.arc([8, 16, 32, 31], 110, 170, fill=BRONZE_L, width=2)
    d.arc([7, 15, 33, 33], 20, 70, fill=BRONZE_D, width=2)
    for x in range(11, 30, 3):
        d.point((x, 27), fill=BRONZE_L)
    # telinga mangkuk
    d.rectangle([4, 22, 7, 24], fill=BRONZE_D)
    d.rectangle([33, 22, 36, 24], fill=BRONZE_D)
    # bibir mangkuk dan bara kemenyan
    d.ellipse([7, 21, 33, 26], fill=BRONZE_L)
    d.ellipse([9, 22, 31, 25], fill=(58, 34, 22, 255))
    for x, col in ((13, (236, 96, 48)), (16, (255, 190, 80)), (19, (236, 96, 48)), (22, (255, 220, 120)), (25, (236, 96, 48)), (27, (255, 190, 80))):
        d.point((x, 23), fill=col + (255,))
    return add_outline(img)


def draw_tameng(size: int = 40) -> Image.Image:
    """Tameng prajurit Jawa: lonjong runcing, berbingkai emas, motif tumpal dan kawung."""
    img, d = canvas(size, size)
    body = (64, 168, 92, 255)
    dark = (36, 108, 60, 255)
    light = (120, 206, 128, 255)
    petal = (238, 214, 140, 255)

    def outline_pts(top, bottom, width):
        pts_l, pts_r = [], []
        steps = 40
        for i in range(steps + 1):
            k = i / steps
            y = top + (bottom - top) * k
            w = width * math.sin(math.pi * k) ** 0.7
            pts_l.append((20 - w, y))
            pts_r.append((20 + w, y))
        return pts_l + list(reversed(pts_r))

    d.polygon(outline_pts(1, 39, 12.5), fill=GOLD)
    d.polygon(outline_pts(3, 37, 10.6), fill=body)
    # sisi kanan lebih gelap, kiri disinari
    right = [p for p in outline_pts(3, 37, 10.6) if p[0] >= 20]
    d.polygon([(20, 3)] + right + [(20, 37)], fill=dark)
    d.line([(12, 12), (11, 20), (12, 28)], fill=light, width=1)
    # tumpal (deret segitiga) di ujung atas dan bawah
    d.polygon([(16, 10), (20, 4), (24, 10)], fill=petal)
    d.polygon([(16, 30), (20, 36), (24, 30)], fill=petal)
    d.polygon([(18, 9), (20, 6), (22, 9)], fill=GOLD_D)
    d.polygon([(18, 31), (20, 34), (22, 31)], fill=GOLD_D)
    # kawung di tengah: empat kelopak mengelilingi bulatan emas
    cx, cy = 20, 20
    for dx, dy in ((0, -5), (0, 5), (-5, 0), (5, 0)):
        d.ellipse([cx + dx - 3, cy + dy - 3, cx + dx + 3, cy + dy + 3], fill=petal)
        d.point((cx + dx, cy + dy), fill=GOLD_D)
    d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=GOLD)
    d.point((cx - 1, cy - 1), fill=GOLD_L)
    # bingkai: garis emas terang di sisi kiri
    d.line([(9, 14), (8, 20), (9, 26)], fill=GOLD_L, width=1)
    return add_outline(img)


def draw_tombak(size: int = 40) -> Image.Image:
    """Tombak: mata tombak lurus segaris dengan tangkainya, methuk emas, dan garis angin."""
    img, d = canvas(size, size)
    butt = (5.5, 35.5)
    length = 43.0
    blade = 12.0
    sb = length - blade
    # garis angin (hijau taktik + merah serang), di sisi atas tangkai supaya tidak menimpanya
    for i, col in enumerate([(120, 220, 120, 255), (230, 90, 70, 255), (120, 220, 120, 255)]):
        t = -5.0 - i * 3.6
        s0 = 9.0 + i * 2.0
        d.line([at(butt, s0, t), at(butt, s0 + 10.0, t)], fill=col, width=1)
    # tangkai kayu
    d.line([at(butt, 0, 0), at(butt, sb - 1.5, 0)], fill=WOOD, width=3)
    d.line([at(butt, 2, -0.9), at(butt, sb - 2, -0.9)], fill=WOOD_L, width=1)
    d.line([at(butt, 0.5, 0), at(butt, 2.5, 0)], fill=GOLD, width=3)
    # mata tombak berbentuk daun
    pts_l, pts_r = [], []
    for i in range(25):
        k = i / 24
        s = sb + blade * k
        w = 2.9 * math.sin(math.pi * min(1.0, k * 1.35 + 0.08)) ** 0.8 if k < 0.74 else 2.9 * (1 - k) / 0.26 * 0.95
        pts_l.append(at(butt, s, -w))
        pts_r.append(at(butt, s, w))
    d.polygon(pts_l + list(reversed(pts_r)), fill=(220, 226, 238, 255))
    d.polygon([at(butt, sb, 0)] + pts_r[1:] + [at(butt, length, 0)], fill=(176, 184, 200, 255))
    d.line([at(butt, sb + 1, 0), at(butt, length - 1.5, 0)], fill=(140, 150, 170, 255), width=1)
    # methuk emas di pangkal mata tombak
    band(d, butt, sb - 2.2, sb + 0.2, -2.2, 2.2, GOLD)
    d.line([at(butt, sb - 1.0, -1.8), at(butt, sb - 1.0, 1.8)], fill=GOLD_L, width=1)
    return add_outline(img)


def crimson_eye(eye: Image.Image) -> Image.Image:
    a = np.asarray(eye).astype(np.float64)
    hsv = rgb_to_hsv(a[..., :3] / 255.0)
    blue = (hsv[..., 1] > 0.35) & (hsv[..., 0] > 0.45) & (hsv[..., 0] < 0.75)
    hsv[..., 0] = np.where(blue, 0.99, hsv[..., 0])
    rgb = hsv_to_rgb(hsv) * 255.0
    out = Image.fromarray(np.dstack([rgb, a[..., 3]]).clip(0, 255).astype(np.uint8), "RGBA")
    # keris kecil di belakang mata
    keris = draw_keris(40)
    base = Image.new("RGBA", (max(out.width, 44), 40), (0, 0, 0, 0))
    base.alpha_composite(keris, (2, 0))
    base.alpha_composite(out, ((base.width - out.width) // 2, (40 - out.height) // 2))
    return base


def mini_icon(kind: str) -> Image.Image:
    """Ikon kecil 12x12 untuk niat musuh dan angka di kartu."""
    img, d = canvas(12, 12)
    if kind == "attack":
        d.line([(2, 9), (9, 2)], fill=(220, 226, 238, 255), width=2)
        d.line([(1, 7), (4, 10)], fill=(232, 182, 72, 255), width=1)
    elif kind == "heavy":
        d.line([(1, 10), (10, 1)], fill=(255, 120, 90, 255), width=3)
        d.line([(0, 7), (4, 11)], fill=(232, 182, 72, 255), width=2)
    elif kind == "block":
        d.polygon([(2, 1), (9, 1), (9, 6), (5, 10), (2, 6)], fill=(92, 190, 110, 255))
        d.line([(5, 2), (5, 8)], fill=(200, 240, 180, 255))
    elif kind == "moxie":
        d.polygon([(5, 0), (9, 6), (6, 11), (3, 11), (1, 6)], fill=(90, 170, 240, 255))
        d.polygon([(5, 4), (7, 7), (5, 10), (3, 7)], fill=(200, 235, 255, 255))
    elif kind == "drain":
        d.polygon([(5, 0), (9, 6), (6, 11), (3, 11), (1, 6)], fill=(196, 96, 230, 255))
        d.line([(3, 7), (7, 7)], fill=(255, 255, 255, 255))
    elif kind == "lock":
        d.arc([3, 0, 8, 7], 180, 360, fill=(220, 220, 228, 255), width=2)
        d.rectangle([2, 5, 9, 11], fill=(232, 182, 72, 255))
        d.rectangle([5, 7, 6, 9], fill=(60, 40, 20, 255))
    elif kind == "charge":
        for x in (2, 6):
            d.polygon([(x, 5), (x + 2, 1), (x + 4, 5)], fill=(255, 150, 70, 255))
            d.line([(x + 2, 5), (x + 2, 10)], fill=(255, 150, 70, 255), width=1)
    elif kind == "poison":
        d.polygon([(5, 0), (9, 6), (6, 11), (3, 11), (1, 6)], fill=(110, 200, 80, 255))
        d.rectangle([4, 6, 6, 8], fill=(30, 70, 20, 255))
    elif kind == "ap":
        d.polygon([(5, 0), (10, 5), (5, 10), (0, 5)], fill=(250, 210, 90, 255))
        d.polygon([(5, 2), (8, 5), (5, 8), (2, 5)], fill=(255, 240, 170, 255))
    elif kind == "ap_empty":
        d.polygon([(5, 0), (10, 5), (5, 10), (0, 5)], fill=(60, 60, 80, 255))
        d.polygon([(5, 2), (8, 5), (5, 8), (2, 5)], fill=(34, 34, 50, 255))
    elif kind == "heart":
        d.polygon([(5, 10), (0, 5), (0, 2), (2, 0), (5, 2), (8, 0), (10, 2), (10, 5)], fill=(226, 70, 70, 255))
    elif kind == "deck":
        d.rectangle([3, 1, 10, 10], fill=(80, 110, 170, 255))
        d.rectangle([1, 2, 8, 11], fill=(120, 150, 210, 255))
    elif kind == "discard":
        d.rectangle([1, 2, 8, 11], fill=(110, 90, 90, 255))
        d.line([(2, 4), (7, 9)], fill=(220, 120, 120, 255))
        d.line([(2, 9), (7, 4)], fill=(220, 120, 120, 255))
    elif kind == "amuk":
        # api kecil: titik Amuk yang sudah terisi
        d.polygon([(5, 0), (9, 5), (9, 8), (6, 11), (3, 11), (1, 8), (1, 5), (3, 3), (4, 5)], fill=(236, 84, 52, 255))
        d.polygon([(5, 5), (7, 8), (6, 10), (4, 10), (3, 8)], fill=(255, 200, 90, 255))
    elif kind == "amuk_empty":
        d.polygon([(5, 0), (9, 5), (9, 8), (6, 11), (3, 11), (1, 8), (1, 5), (3, 3), (4, 5)], fill=(70, 50, 60, 255))
        d.polygon([(5, 5), (7, 8), (6, 10), (4, 10), (3, 8)], fill=(42, 32, 44, 255))
    elif kind == "prayitna":
        # mata waspada dengan sinar: buff Prayitna
        d.line([(5, 0), (5, 1)], fill=(255, 220, 120, 255))
        d.line([(1, 1), (2, 2)], fill=(255, 220, 120, 255))
        d.line([(9, 1), (8, 2)], fill=(255, 220, 120, 255))
        d.polygon([(0, 7), (3, 4), (8, 4), (11, 7), (8, 10), (3, 10)], fill=(232, 240, 226, 255))
        d.ellipse([3, 4, 8, 10], fill=(92, 190, 110, 255))
        d.rectangle([5, 6, 6, 8], fill=(20, 40, 24, 255))
    elif kind == "chain":
        d.ellipse([0, 3, 6, 9], outline=(232, 182, 72, 255), width=2)
        d.ellipse([5, 2, 11, 8], outline=(255, 220, 120, 255), width=2)
    elif kind in ("star", "star_empty"):
        pts = []
        for i in range(10):
            ang = -math.pi / 2 + i * math.pi / 5
            r = 5.6 if i % 2 == 0 else 2.4
            pts.append((5.5 + r * math.cos(ang), 6.0 + r * math.sin(ang)))
        if kind == "star":
            d.polygon(pts, fill=(255, 210, 90, 255))
            d.point((5, 4), fill=(255, 245, 200, 255))
        else:
            d.polygon(pts, fill=(58, 56, 76, 255))
    elif kind == "all":
        # semua sasaran: tiga titik bidik
        for (x, y) in ((1, 6), (5, 1), (9, 6)):
            d.ellipse([x - 1, y, x + 2, y + 3], outline=(255, 120, 90, 255))
        d.line([(1, 11), (10, 11)], fill=(255, 120, 90, 255))
    elif kind == "calm":
        # Amuk dibuyarkan: api dicoret
        d.polygon([(5, 0), (9, 5), (9, 8), (6, 11), (3, 11), (1, 8), (1, 5), (3, 3), (4, 5)], fill=(150, 90, 70, 255))
        d.line([(0, 11), (11, 0)], fill=(230, 236, 250, 255), width=2)
    elif kind == "giris":
        # Giris: serangan Buto melemah (bilah dengan panah ungu ke bawah)
        d.line([(1, 10), (6, 5)], fill=(220, 226, 238, 255), width=2)
        d.line([(0, 8), (3, 11)], fill=(232, 182, 72, 255), width=1)
        d.rectangle([8, 0, 9, 5], fill=(200, 140, 255, 255))
        d.polygon([(6, 5), (11, 5), (8, 9)], fill=(200, 140, 255, 255))
    elif kind == "boost":
        # kartu berikutnya lebih kuat: panah naik emas
        d.polygon([(5, 0), (10, 5), (7, 5), (7, 11), (3, 11), (3, 5), (0, 5)], fill=(250, 210, 90, 255))
        d.line([(5, 2), (5, 9)], fill=(255, 240, 170, 255))
    elif kind == "plague":
        # Gebug Pagebluk: hantaman + tetes Lara
        d.line([(1, 8), (7, 2)], fill=(220, 226, 238, 255), width=2)
        d.line([(0, 6), (3, 9)], fill=(232, 182, 72, 255), width=1)
        d.polygon([(9, 4), (11, 8), (10, 11), (8, 11), (7, 8)], fill=(150, 90, 200, 255))
        d.point((9, 8), fill=(220, 190, 255, 255))
    elif kind == "ajian":
        # Ajian Lebur Saketi: ledakan merah keunguan berinti kuning
        pts = []
        for i in range(16):
            ang = -math.pi / 2 + i * math.pi / 8
            r = 5.8 if i % 2 == 0 else 2.6
            pts.append((5.5 + r * math.cos(ang), 5.5 + r * math.sin(ang)))
        d.polygon(pts, fill=(214, 48, 96, 255))
        d.ellipse([3, 3, 8, 8], fill=(255, 150, 90, 255))
        d.ellipse([4, 4, 7, 7], fill=(255, 236, 150, 255))
    elif kind == "summon":
        # Memanggil Bala: dua bayangan berkerudung
        for x, col in ((0, (96, 70, 130, 255)), (5, (130, 96, 170, 255))):
            d.polygon([(x + 3, 1), (x + 6, 4), (x + 6, 11), (x + 4, 9), (x + 3, 11), (x + 1, 9), (x, 11), (x, 4)], fill=col)
            d.point((x + 2, 5), fill=(255, 210, 120, 255))
            d.point((x + 4, 5), fill=(255, 210, 120, 255))
    elif kind == "stagger":
        # Terhuyung: bintang-bintang pusing berputar
        d.arc([1, 3, 10, 10], 200, 520, fill=(200, 200, 220, 255), width=1)
        for (x, y) in ((2, 2), (8, 4), (4, 8)):
            d.polygon([(x, y - 2), (x + 1, y - 1), (x + 2, y), (x + 1, y + 1), (x, y + 2), (x - 1, y + 1), (x - 2, y), (x - 1, y - 1)],
                      fill=(255, 220, 110, 255))
            d.point((x, y), fill=(255, 250, 210, 255))
    elif kind == "bala_shield":
        # Perisai Bala: Buto Hitam hanya menerima separuh damage
        d.polygon([(1, 1), (10, 1), (10, 6), (5, 11), (1, 6)], fill=(118, 80, 168, 255))
        d.polygon([(5, 1), (10, 1), (10, 6), (5, 11)], fill=(82, 54, 124, 255))
        d.polygon([(5, 2), (8, 5), (5, 8), (2, 5)], fill=(214, 190, 255, 255))
        d.point((5, 5), fill=(82, 54, 124, 255))
    return add_outline(img)


def blessing_icon(kind: str) -> Image.Image:
    """Ikon berkah 15x15 (ditampilkan 2x di panel berkah)."""
    img, d = canvas(15, 15)
    if kind == "kendang":
        # kendang: badan kayu, kulit di kedua ujung, tali
        d.polygon([(2, 4), (12, 4), (13, 7), (12, 10), (2, 10), (1, 7)], fill=(150, 92, 52, 255))
        d.line([(3, 5), (11, 5)], fill=(190, 130, 76, 255))
        d.ellipse([0, 3, 3, 11], fill=(232, 214, 168, 255))
        d.ellipse([11, 3, 14, 11], fill=(214, 194, 150, 255))
        for x in (4, 7, 10):
            d.line([(x, 4), (x + 1, 10)], fill=(92, 56, 34, 255))
    elif kind == "leluhur":
        # Greget Leluhur: api biru berlingkar emas
        d.ellipse([0, 1, 14, 14], outline=(232, 182, 72, 255))
        d.polygon([(7, 2), (11, 8), (10, 12), (7, 13), (4, 12), (3, 8), (5, 6), (6, 8)], fill=(90, 170, 240, 255))
        d.polygon([(7, 7), (9, 10), (7, 12), (5, 10)], fill=(200, 235, 255, 255))
    elif kind == "pusaka":
        # Tameng Pusaka: tameng emas bermata merah
        d.polygon([(1, 1), (13, 1), (13, 7), (7, 14), (1, 7)], fill=(232, 182, 72, 255))
        d.polygon([(7, 1), (13, 1), (13, 7), (7, 14)], fill=(196, 140, 52, 255))
        d.line([(2, 2), (12, 2)], fill=(255, 230, 150, 255))
        d.ellipse([4, 3, 10, 9], fill=(150, 30, 44, 255))
        d.ellipse([5, 4, 9, 8], fill=(214, 48, 64, 255))
        d.point((6, 5), fill=(255, 170, 170, 255))
    elif kind == "jimat":
        # Jimat Penolak Sirep: liontin bertali dengan batu ungu
        d.arc([3, 0, 11, 8], 180, 360, fill=(200, 170, 120, 255))
        d.line([(3, 4), (5, 7)], fill=(200, 170, 120, 255))
        d.line([(11, 4), (9, 7)], fill=(200, 170, 120, 255))
        d.polygon([(7, 6), (11, 10), (7, 14), (3, 10)], fill=(232, 182, 72, 255))
        d.polygon([(7, 8), (9, 10), (7, 12), (5, 10)], fill=(150, 90, 200, 255))
        d.point((6, 9), fill=(220, 190, 255, 255))
    elif kind == "kencur":
        # Jamu Beras Kencur: gelas jamu krem dengan daun
        d.polygon([(3, 5), (11, 5), (10, 14), (4, 14)], fill=(220, 226, 236, 160))
        d.polygon([(4, 7), (10, 7), (9, 13), (5, 13)], fill=(238, 214, 150, 255))
        d.line([(4, 7), (10, 7)], fill=(255, 240, 200, 255))
        d.polygon([(8, 1), (13, 0), (12, 4), (9, 5)], fill=(92, 170, 80, 255))
        d.line([(9, 5), (12, 1)], fill=(52, 110, 50, 255))
    return add_outline(img)


def build_icons(eye: Image.Image) -> None:
    print("Ikon kartu:")
    save(draw_keris(), "cards/icon_serang.png")
    save(draw_padupan(), "cards/icon_fokus.png")
    save(draw_tameng(), "cards/icon_taktik.png")
    save(crimson_eye(eye), "cards/icon_crimson.png")
    save(draw_tombak(), "cards/icon_piercing.png")
    save(draw_swirl(), "cards/icon_flow.png")
    save(draw_gong(), "ui/icon_ultimate.png")
    save(draw_bedug(), "cards/icon_bedug.png")
    save(draw_kentongan(), "cards/icon_kentongan.png")
    save(draw_korek(), "cards/icon_korek.png")
    save(draw_gong_card(), "cards/icon_gong.png")
    save(draw_kenong(), "cards/icon_kenong.png")
    save(draw_gong_beri(), "cards/icon_beri.png")
    print("Ikon kecil:")
    for kind in ("attack", "heavy", "block", "moxie", "drain", "lock", "charge",
                 "poison", "ap", "ap_empty", "heart", "deck", "discard", "chain",
                 "amuk", "amuk_empty", "prayitna", "plague", "ajian", "summon", "stagger",
                 "bala_shield", "all", "calm", "boost", "star", "star_empty", "giris"):
        save(mini_icon(kind), f"ui/mini_{kind}.png")
    for kind in ("kendang", "leluhur", "pusaka", "jimat", "kencur"):
        save(blessing_icon(kind), f"ui/bless_{kind}.png")
    # gembok besar untuk kartu terkunci
    img, d = canvas(20, 24)
    d.arc([4, 0, 15, 14], 180, 360, fill=(226, 226, 236, 255), width=3)
    d.line([(4, 7), (4, 11)], fill=(226, 226, 236, 255), width=3)
    d.line([(15, 7), (15, 11)], fill=(226, 226, 236, 255), width=3)
    d.rectangle([1, 10, 18, 23], fill=(232, 182, 72, 255))
    d.rectangle([1, 10, 18, 12], fill=(255, 220, 130, 255))
    d.rectangle([8, 14, 11, 20], fill=(70, 46, 20, 255))
    save(add_outline(img), "ui/padlock.png")
    # titik Amuk kecil (api 7x8) di atas kepala Buto
    for filled in (True, False):
        img, d = canvas(7, 8)
        body = (236, 84, 52, 255) if filled else (70, 50, 60, 255)
        core = (255, 200, 90, 255) if filled else (42, 32, 44, 255)
        d.polygon([(3, 0), (6, 4), (6, 6), (4, 7), (2, 7), (0, 6), (0, 4), (2, 2)], fill=body)
        d.polygon([(3, 4), (4, 6), (2, 6)], fill=core)
        save(img, "ui/amuk_dot.png" if filled else "ui/amuk_dot_empty.png")


# ---------------------------------------------------------------------------
# 5. Topeng & potret
# ---------------------------------------------------------------------------

MASK_HUES = {"kuning": (0.10, 0.20), "hijau": (0.22, 0.45), "merah": (0.96, 1.02), "putih": None, "hitam": None}


def mask_box(img: Image.Image, color: str) -> tuple[int, int, int, int]:
    a = np.asarray(img).astype(np.float64)
    rgb = a[..., :3] / 255.0
    hsv = rgb_to_hsv(rgb)
    head = np.zeros(a.shape[:2], dtype=bool)
    head[20:110, 60:140] = True
    if color == "putih":
        m = (rgb.min(axis=-1) > 0.62) & head
    elif color == "hitam":
        return (0, 0, 0, 0)
    else:
        lo, hi = MASK_HUES[color]
        hue = hsv[..., 0]
        if hi > 1.0:
            hue_ok = (hue >= lo) | (hue <= hi - 1.0)
        else:
            hue_ok = (hue >= lo) & (hue <= hi)
        # Bulu Buto coklat kemerahan, jadi topeng merah butuh saturasi lebih tinggi.
        min_sat = 0.62 if color == "merah" else 0.45
        m = hue_ok & (hsv[..., 1] > min_sat) & (hsv[..., 2] > 0.35) & head
    ys, xs = np.nonzero(m)
    return (int(np.percentile(xs, 2)), int(np.percentile(ys, 2)), int(np.percentile(xs, 98)), int(np.percentile(ys, 98)))


def build_masks(chars: dict[str, Image.Image]) -> None:
    print("Topeng & potret:")
    boxes = {}
    for color in ("kuning", "hijau", "merah", "putih"):
        boxes[color] = mask_box(chars[f"buto_{color}_idle"], color)
    # Topeng hitam memakai posisi rata-rata topeng lain (pose idle sama).
    avg = tuple(int(sum(b[i] for b in boxes.values()) / len(boxes)) for i in range(4))
    boxes["hitam"] = avg
    for color, (x0, y0, x1, y1) in boxes.items():
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
        icon = chars[f"buto_{color}_idle"].crop((cx - 16, cy - 16, cx + 16, cy + 16))
        save(icon, f"ui/mask_{color}.png")
        portrait = chars[f"buto_{color}_idle"].crop((cx - 40, cy - 30, cx + 40, cy + 50))
        save(portrait, f"ui/portrait_buto_{color}.png")
    hero = chars["eyang_palang_idle"]
    a = np.asarray(hero)
    ys, xs = np.nonzero(a[..., 3] > 0)
    top = int(ys.min())
    # kepala Eyang Palang ada di bagian atas siluet
    head_x = int(np.median(xs[ys < top + 18]))
    save(hero.crop((head_x - 40, top - 6, head_x + 40, top + 74)), "ui/portrait_eyang_palang.png")
    # Potret Roro Ayu dipotong dari desain sprite diamnya, kebayanya diputihkan
    # (tools/portrait_roro_ayu.py).
    save(draw_roro_ayu(), "ui/portrait_roro_ayu.png")
    # Sprite badan penuh Roro Ayu dan Roro Perot, dibaca dari kisi asli desain
    # yang sama. Roro Perot rancangan sementara turunan Roro Ayu
    # (tools/roro_sprites.py).
    save(draw_ayu_sprite(), "sprites/roro/roro_ayu_idle.png")
    save(draw_perot_sprite(), "sprites/roro/roro_perot_idle.png")
    save(draw_perot_portrait(), "ui/portrait_roro_perot.png")


def build_app_icon() -> None:
    print("Ikon aplikasi:")
    mask = Image.open(os.path.join(OUT, "ui", "mask_hitam.png")).convert("RGBA")
    icon = Image.new("RGBA", (64, 64), (24, 22, 36, 255))
    d = ImageDraw.Draw(icon)
    d.rectangle([0, 0, 63, 63], outline=(232, 182, 72, 255), width=2)
    big = mask.resize((56, 56), Image.NEAREST)
    icon.alpha_composite(big, (4, 4))
    save(icon, "ui/app_icon.png")


def main() -> None:
    chars = build_characters()
    eye = build_card_frames()
    build_icons(eye)
    build_masks(chars)
    build_app_icon()
    print("Selesai.")


if __name__ == "__main__":
    main()
