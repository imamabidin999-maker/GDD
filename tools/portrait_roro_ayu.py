"""Potret dialog Roro Ayu (80x80), dipanggil dari tools/build_assets.py.

Potret dipotong dari desain sprite diam Roro Ayu buatan pemilik proyek
(docs/desain_asli/roro_ayu_standby.png): bagian kepala sampai dada, menghadap
kanan ke arah teks dialog. Latarnya dibuang, dan kebaya hijaunya diganti putih
dengan terang-gelap yang tetap dipertahankan. Lis emas, selendang, kulit,
rambut, dan perhiasan tidak diubah.
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "docs", "desain_asli", "roro_ayu_standby.png")
CROP = (390, 88, 615, 313)  # kepala sampai dada, di koordinat gambar desain
SIZE = 80
BACKGROUND = np.array([33.0, 35.0, 47.0])  # warna latar desain
# Kebaya putih: dari bayangan kebiruan sampai putih gading.
WHITE_SHADOW = np.array([118.0, 116.0, 132.0])
WHITE_LIGHT = np.array([250.0, 248.0, 240.0])


def _hue_sat_val(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    r, g, b = rgb[..., 0] / 255.0, rgb[..., 1] / 255.0, rgb[..., 2] / 255.0
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    d = np.maximum(mx - mn, 1e-6)
    hue = np.where(mx == r, (60 * (g - b) / d + 360) % 360,
                   np.where(mx == g, 60 * (b - r) / d + 120, 60 * (r - g) / d + 240))
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
    return hue, sat, mx


def draw_roro_ayu() -> Image.Image:
    x0, y0, x1, y1 = CROP
    rgb = np.asarray(Image.open(SOURCE).convert("RGB")).astype(np.float64)[y0:y1, x0:x1]
    # latar desain dibuang
    solid = np.sqrt(((rgb - BACKGROUND) ** 2).sum(axis=2)) > 22
    # kebaya: piksel hijau diganti putih menurut terangnya
    hue, sat, val = _hue_sat_val(rgb)
    green = solid & (hue > 70) & (hue < 175) & (sat > 0.22) & (val > 0.12)
    t = np.clip((val - 0.18) / (0.70 - 0.18), 0.0, 1.0) ** 0.85
    white = WHITE_SHADOW + (WHITE_LIGHT - WHITE_SHADOW) * t[..., None]
    rgb = np.where(green[..., None], white, rgb)
    rgba = Image.fromarray(np.dstack([rgb, solid * 255.0]).astype(np.uint8), "RGBA")
    small = np.asarray(rgba.convert("RGBa").resize((SIZE, SIZE), Image.LANCZOS).convert("RGBA")).copy()
    small[..., 3] = np.where(small[..., 3] >= 128, 255, 0)
    return Image.fromarray(small, "RGBA")
