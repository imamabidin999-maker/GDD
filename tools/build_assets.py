"""Membangun semua aset grafis game dari desain asli di docs/desain_asli/.

Jalankan dari root repo:
    python3 tools/build_assets.py

Butuh Python 3 + Pillow + numpy. Hasilnya ditulis ke assets/ dan langsung
dipakai Godot. Desain asli tidak diubah.

Isinya:
1. Karakter (Eyang Palang + 5 Buto): latar navy dihapus jadi transparan.
2. Latar battle: diperbesar 4x (nearest) supaya tetap tajam.
3. Bingkai kartu: kartu FOCUS di desain dijadikan template, judul & gambarnya
   dikosongkan, lalu diwarnai ulang untuk tiap tipe kartu.
4. Ikon yang belum ada di desain (pedang, perisai kawung, tombak, pusaran,
   gong, ikon niat musuh, gembok, dll.) digambar dengan gaya yang sama.
5. Ikon topeng Buto dan potret dialog dipotong dari sprite.
"""
from __future__ import annotations

import math
import os
from collections import deque

import numpy as np
from PIL import Image, ImageDraw

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
        save(img, rel)
        result[os.path.basename(rel)[:-4]] = img
    return result


# ---------------------------------------------------------------------------
# 2. Latar
# ---------------------------------------------------------------------------

def build_backgrounds() -> None:
    print("Latar:")
    im = Image.open(src("8413950758356832246")).convert("RGB")
    save(im.resize((640, 640), Image.NEAREST), "backgrounds/battle_candi.png")


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
    icon = eye_icon(eye)
    save(icon, "cards/icon_fokus.png")
    return icon


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


def draw_sword(size: int = 40, blade=(214, 220, 232, 255), edge=(140, 150, 170, 255)) -> Image.Image:
    img, d = canvas(size, size)
    s = size / 40.0
    # bilah diagonal dari kiri bawah ke kanan atas
    d.polygon([(30 * s, 6 * s), (34 * s, 6 * s), (34 * s, 10 * s), (15 * s, 29 * s), (11 * s, 25 * s)], fill=blade)
    d.line([(32 * s, 8 * s), (14 * s, 26 * s)], fill=edge, width=1)
    # pelindung tangan (emas)
    d.line([(9 * s, 23 * s), (17 * s, 31 * s)], fill=(232, 182, 72, 255), width=max(2, int(3 * s)))
    # gagang (kayu)
    d.line([(12 * s, 28 * s), (6 * s, 34 * s)], fill=(120, 76, 44, 255), width=max(2, int(3 * s)))
    d.rectangle([4 * s, 33 * s, 7 * s, 36 * s], fill=(232, 182, 72, 255))
    return add_outline(img)


def draw_kawung_shield(size: int = 40) -> Image.Image:
    img, d = canvas(size, size)
    body = (64, 168, 92, 255)
    dark = (34, 104, 58, 255)
    rim = (156, 222, 120, 255)
    pts = [(8, 6), (32, 6), (32, 20), (20, 35), (8, 20)]
    d.polygon(pts, fill=body)
    d.line(pts + [pts[0]], fill=rim, width=1)
    d.polygon([(20, 6), (32, 6), (32, 20), (20, 35)], fill=dark)
    # motif kawung: empat kelopak mengelilingi titik tengah
    cx, cy = 20, 18
    petal = (238, 214, 140, 255)
    for dx, dy in ((0, -5), (0, 5), (-5, 0), (5, 0)):
        d.ellipse([cx + dx - 3, cy + dy - 3, cx + dx + 3, cy + dy + 3], fill=petal)
    d.rectangle([cx - 1, cy - 1, cx + 1, cy + 1], fill=dark)
    return add_outline(img)


def draw_spear(size: int = 40) -> Image.Image:
    img, d = canvas(size, size)
    d.line([(5, 35), (27, 13)], fill=(122, 78, 46, 255), width=2)
    d.polygon([(26, 10), (36, 4), (30, 14)], fill=(220, 226, 238, 255))
    d.line([(27, 12), (34, 6)], fill=(150, 160, 178, 255), width=1)
    d.line([(24, 15), (28, 11)], fill=(232, 182, 72, 255), width=3)
    # garis angin (hijau taktik + merah serang)
    for i, col in enumerate([(120, 220, 120, 255), (230, 90, 70, 255), (120, 220, 120, 255)]):
        y = 24 + i * 4
        d.line([(4 + i * 3, y), (14 + i * 3, y - 10)], fill=col, width=1)
    return add_outline(img)


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


def crimson_eye(eye: Image.Image) -> Image.Image:
    a = np.asarray(eye).astype(np.float64)
    hsv = rgb_to_hsv(a[..., :3] / 255.0)
    blue = (hsv[..., 1] > 0.35) & (hsv[..., 0] > 0.45) & (hsv[..., 0] < 0.75)
    hsv[..., 0] = np.where(blue, 0.99, hsv[..., 0])
    rgb = hsv_to_rgb(hsv) * 255.0
    out = Image.fromarray(np.dstack([rgb, a[..., 3]]).clip(0, 255).astype(np.uint8), "RGBA")
    # pedang kecil di belakang mata
    sword = draw_sword(40)
    base = Image.new("RGBA", (max(out.width, 44), 40), (0, 0, 0, 0))
    base.alpha_composite(sword, (2, 0))
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
    elif kind == "shuffle":
        d.line([(1, 3), (8, 9)], fill=(240, 240, 240, 255), width=1)
        d.line([(1, 9), (8, 3)], fill=(240, 240, 240, 255), width=1)
        d.polygon([(8, 1), (11, 3), (8, 5)], fill=(240, 240, 240, 255))
        d.polygon([(8, 7), (11, 9), (8, 11)], fill=(240, 240, 240, 255))
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
    elif kind == "chain":
        d.ellipse([0, 3, 6, 9], outline=(232, 182, 72, 255), width=2)
        d.ellipse([5, 2, 11, 8], outline=(255, 220, 120, 255), width=2)
    return add_outline(img)


def build_icons(eye: Image.Image) -> None:
    print("Ikon kartu:")
    save(draw_sword(), "cards/icon_serang.png")
    save(draw_kawung_shield(), "cards/icon_taktik.png")
    save(crimson_eye(eye), "cards/icon_crimson.png")
    save(draw_spear(), "cards/icon_piercing.png")
    save(draw_swirl(), "cards/icon_flow.png")
    save(draw_gong(), "ui/icon_ultimate.png")
    print("Ikon kecil:")
    for kind in ("attack", "heavy", "block", "moxie", "drain", "lock", "shuffle", "charge",
                 "poison", "ap", "ap_empty", "heart", "deck", "discard", "chain"):
        save(mini_icon(kind), f"ui/mini_{kind}.png")
    # gembok besar untuk kartu terkunci
    img, d = canvas(20, 24)
    d.arc([4, 0, 15, 14], 180, 360, fill=(226, 226, 236, 255), width=3)
    d.line([(4, 7), (4, 11)], fill=(226, 226, 236, 255), width=3)
    d.line([(15, 7), (15, 11)], fill=(226, 226, 236, 255), width=3)
    d.rectangle([1, 10, 18, 23], fill=(232, 182, 72, 255))
    d.rectangle([1, 10, 18, 12], fill=(255, 220, 130, 255))
    d.rectangle([8, 14, 11, 20], fill=(70, 46, 20, 255))
    save(add_outline(img), "ui/padlock.png")


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
    build_backgrounds()
    eye = build_card_frames()
    build_icons(eye)
    build_masks(chars)
    build_app_icon()
    print("Selesai.")


if __name__ == "__main__":
    main()
