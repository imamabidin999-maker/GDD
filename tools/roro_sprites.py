"""Sprite Roro Ayu dan Roro Perot, dipanggil dari tools/build_assets.py.

Keduanya dibuat dari desain sprite diam Roro Ayu buatan pemilik proyek
(docs/desain_asli/roro_ayu_standby.png). Desain itu pixel art yang diperbesar
sekitar 5,125 kali, jadi kisi aslinya dibaca ulang dulu (satu warna per sel)
sehingga satu piksel desain menjadi satu piksel game. Tingginya kira-kira sama
dengan Eyang Palang.

- Roro Ayu: kebaya hijau diganti putih, sama seperti potret dialognya.
- Roro Perot: rancangan sementara (belum ada desain dari pemilik proyek),
  diturunkan dari Roro Ayu. Wajahnya berlapis bedak dingin putih, mulutnya
  miring (perot), ada tahi lalat dan pipi merah, alisnya terangkat, kebayanya
  lurik nila, dan hiasan sanggulnya bunga merah.
"""
import os
from collections import deque

import numpy as np
from PIL import Image

from portrait_roro_ayu import BACKGROUND, CROP, SIZE, SOURCE, WHITE_LIGHT, WHITE_SHADOW, _hue_sat_val

# Kisi pixel art di gambar desain: lebar sel dan letak sel pertama.
PITCH = 5.125
OFFSET = (4.05, 2.65)
# Kanvas sprite sama dengan sprite Eyang Palang: 160x160, kaki di baris ~150.
CANVAS = 160
FEET_Y = 149

# Kebaya lurik Roro Perot: nila gelap sampai nila terang.
INDIGO_SHADOW = np.array([30.0, 36.0, 82.0])
INDIGO_LIGHT = np.array([112.0, 134.0, 210.0])
# Bedak dingin: krem kebiruan di bagian gelap sampai putih beras.
POWDER_SHADOW = np.array([186.0, 176.0, 178.0])
POWDER_LIGHT = np.array([252.0, 248.0, 238.0])
# Bunga merah pengganti cunduk mentul emas.
FLOWER_SHADOW = np.array([120.0, 26.0, 38.0])
FLOWER_LIGHT = np.array([255.0, 120.0, 120.0])

# Wajah Roro Ayu di kisi asli (menghadap kanan): kulit wajah di atas garis
# rahang, lalu titik-titik yang diubah untuk Roro Perot.
FACE_BOX = (99, 26, 108, 40)  # x0, y0, x1, y1 (inklusif)
LIPS = [(105, 37), (106, 37)]
PEROT_LIPS = [(104, 37), (105, 37), (106, 36)]
PEROT_MOLE = (102, 34)
PEROT_BLUSH = [(101, 36), (102, 36)]
PEROT_BROW = [(104, 29)]
HAIR_ORNAMENT_BOX = (80, 15, 96, 30)


def native_grid() -> np.ndarray:
    """Gambar desain dibaca ulang menjadi kisi aslinya (satu warna per sel)."""
    rgb = np.asarray(Image.open(SOURCE).convert("RGB")).astype(np.float64)
    h, w = rgb.shape[:2]
    nx = int((w - OFFSET[0]) / PITCH)
    ny = int((h - OFFSET[1]) / PITCH)
    out = np.zeros((ny, nx, 3))
    for j in range(ny):
        cy = int(round(OFFSET[1] + (j + 0.5) * PITCH))
        for i in range(nx):
            cx = int(round(OFFSET[0] + (i + 0.5) * PITCH))
            win = rgb[cy - 1:cy + 2, cx - 1:cx + 2].reshape(-1, 3)
            out[j, i] = np.median(win, axis=0)
    return out


def _background_mask(grid: np.ndarray) -> np.ndarray:
    """Latar dan bayangan di kaki, diisi dari tepi gambar sampai garis luar
    tokoh. Rambut yang warnanya mirip latar tidak ikut terhapus."""
    h, w = grid.shape[:2]
    dist = np.sqrt(((grid - BACKGROUND) ** 2).sum(axis=2))
    blue = grid[..., 2] - grid[..., 0]
    rows = np.arange(h)[:, None]
    shadow = (rows >= 120) & (blue >= 8) & (grid.max(axis=2) < 60)
    passable = (dist <= 10) | shadow
    mask = np.zeros((h, w), dtype=bool)
    queue = deque()
    for x in range(w):
        for y in (0, h - 1):
            if passable[y, x] and not mask[y, x]:
                mask[y, x] = True
                queue.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if passable[y, x] and not mask[y, x]:
                mask[y, x] = True
                queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and passable[ny, nx] and not mask[ny, nx]:
                mask[ny, nx] = True
                queue.append((ny, nx))
    return mask


def _ramp(rgb: np.ndarray, where: np.ndarray, shadow: np.ndarray, light: np.ndarray,
          lo: float = 0.18, hi: float = 0.70) -> np.ndarray:
    """Mewarnai ulang `where` menurut terangnya: gelap -> shadow, terang -> light."""
    _hue, _sat, val = _hue_sat_val(rgb)
    t = np.clip((val - lo) / (hi - lo), 0.0, 1.0) ** 0.85
    color = shadow + (light - shadow) * t[..., None]
    return np.where(where[..., None], color, rgb)


def _kebaya_mask(rgb: np.ndarray) -> np.ndarray:
    hue, sat, val = _hue_sat_val(rgb)
    return (hue > 70) & (hue < 175) & (sat > 0.22) & (val > 0.12)


def ayu_grid() -> np.ndarray:
    grid = native_grid()
    return _ramp(grid, _kebaya_mask(grid), WHITE_SHADOW, WHITE_LIGHT)


def perot_grid() -> np.ndarray:
    grid = native_grid()
    kebaya = _kebaya_mask(grid)
    grid = _ramp(grid, kebaya, INDIGO_SHADOW, INDIGO_LIGHT, 0.12, 0.62)
    # lurik: garis tegak tipis yang sedikit lebih terang setiap tiga kolom
    cols = np.arange(grid.shape[1])[None, :]
    stripe = kebaya & (cols % 3 == 0)
    grid = np.where(stripe[..., None], np.minimum(grid * 1.18 + 10, 255), grid)
    # bunga merah di sanggul, menggantikan cunduk mentul emas
    hue, sat, val = _hue_sat_val(grid)
    x0, y0, x1, y1 = HAIR_ORNAMENT_BOX
    box = np.zeros(grid.shape[:2], dtype=bool)
    box[y0:y1 + 1, x0:x1 + 1] = True
    gold = box & (hue > 25) & (hue < 60) & (sat > 0.3) & (val > 0.35)
    grid = _ramp(grid, gold, FLOWER_SHADOW, FLOWER_LIGHT, 0.3, 0.95)
    # bedak dingin di wajah (kulit di atas garis rahang)
    hue, sat, val = _hue_sat_val(grid)
    x0, y0, x1, y1 = FACE_BOX
    face = np.zeros(grid.shape[:2], dtype=bool)
    face[y0:y1 + 1, x0:x1 + 1] = True
    skin = face & (hue > 8) & (hue < 40) & (sat > 0.15) & (val > 0.45)
    grid = _ramp(grid, skin, POWDER_SHADOW, POWDER_LIGHT, 0.45, 0.88)
    # mulut perot, tahi lalat, pipi merah, dan alis yang terangkat
    for x, y in LIPS:
        grid[y, x] = POWDER_LIGHT
    for x, y in PEROT_LIPS:
        grid[y, x] = (196, 40, 52)
    grid[PEROT_MOLE[1], PEROT_MOLE[0]] = (48, 28, 26)
    for x, y in PEROT_BLUSH:
        grid[y, x] = (246, 158, 160)
    for x, y in PEROT_BROW:
        grid[y, x] = (26, 18, 22)
    return grid


def to_sprite(grid: np.ndarray, flip: bool = False) -> Image.Image:
    """Kisi tokoh -> sprite 160x160 dengan kaki di baris FEET_Y."""
    clear = _background_mask(grid)
    ys, xs = np.nonzero(~clear)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    rgba = np.dstack([grid, np.where(clear, 0, 255)]).astype(np.uint8)[y0:y1 + 1, x0:x1 + 1]
    figure = Image.fromarray(rgba, "RGBA")
    if flip:
        figure = figure.transpose(Image.FLIP_LEFT_RIGHT)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(figure, ((CANVAS - figure.width) // 2, FEET_Y - figure.height + 1))
    return canvas


def to_portrait(grid: np.ndarray) -> Image.Image:
    """Potret 80x80 dengan cara yang sama persis seperti potret Roro Ayu:
    kisi diperbesar lagi ke ukuran desain, dipotong, lalu dikecilkan."""
    h, w = np.asarray(Image.open(SOURCE)).shape[:2]
    clear = _background_mask(grid)
    cols = np.clip(((np.arange(w) - OFFSET[0]) / PITCH).astype(int), 0, grid.shape[1] - 1)
    rows = np.clip(((np.arange(h) - OFFSET[1]) / PITCH).astype(int), 0, grid.shape[0] - 1)
    big = grid[rows][:, cols]
    solid = ~clear[rows][:, cols]
    x0, y0, x1, y1 = CROP
    rgba = np.dstack([big, solid * 255.0])[y0:y1, x0:x1].astype(np.uint8)
    small = np.asarray(Image.fromarray(rgba, "RGBA").convert("RGBa").resize((SIZE, SIZE), Image.LANCZOS)
                       .convert("RGBA")).copy()
    small[..., 3] = np.where(small[..., 3] >= 128, 255, 0)
    return Image.fromarray(small, "RGBA")


def draw_ayu_sprite() -> Image.Image:
    return to_sprite(ayu_grid())


def draw_perot_sprite() -> Image.Image:
    return to_sprite(perot_grid())


def draw_perot_portrait() -> Image.Image:
    return to_portrait(perot_grid())
