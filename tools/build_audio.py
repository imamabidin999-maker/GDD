"""Membuat semua musik dan efek suara game (assets/audio/**.ogg).

Semua bunyi disintesis dari nol supaya bebas lisensi, dengan warna kesenian
Dongkrek: bedug ("dung"), korek ("krek"), kentongan, kendang, kenong, kempul,
gong, saron, slompret (terompet reed), dan suling. Nada memakai tangga nada
slendro (lagu biasa) dan pelog (lagu bos).

Butuh: numpy, scipy, ffmpeg (encoder libvorbis).
Pemakaian: python3 tools/build_audio.py
"""
import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy.signal import butter, fftconvolve, sosfilt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_BGM = os.path.join(ROOT, "assets", "audio", "bgm")
OUT_SFX = os.path.join(ROOT, "assets", "audio", "sfx")

SR = 44100
rng = np.random.default_rng(7)

# Tangga nada dalam cent. Slendro: 1 2 3 5 6, pelog: 1..7.
SLENDRO = {"1": 0, "2": 231, "3": 474, "5": 717, "6": 955}
PELOG = {"1": 0, "2": 120, "3": 270, "4": 540, "5": 670, "6": 785, "7": 950}


# --- Alat bantu sinyal ---------------------------------------------------------

def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def noise(n):
    return rng.standard_normal(n)


def _sos(kind, freq, order):
    return butter(order, freq, btype=kind, fs=SR, output="sos")


def lp(x, f, order=2):
    return sosfilt(_sos("lowpass", f, order), x)


def hp(x, f, order=2):
    return sosfilt(_sos("highpass", f, order), x)


def bp(x, lo, hi, order=2):
    return sosfilt(_sos("bandpass", [lo, hi], order), x)


def fade_in(x, ms=2.0):
    n = min(len(x), int(SR * ms / 1000))
    x[:n] *= np.linspace(0, 1, n)
    return x


def modes(freq, dur, spec, beat=0.0):
    """Jumlah sinus meluruh. spec = [(rasio, peluruhan_detik, amplitudo), ...]."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    for ratio, decay, amp in spec:
        f = freq * ratio
        if f >= SR / 2:
            continue
        out += amp * np.sin(2 * np.pi * f * t) * np.exp(-t / decay)
    if beat:
        out *= 0.7 + 0.3 * np.cos(2 * np.pi * beat * t)
    return fade_in(out)


def pitch(note, scale, base):
    """'5' = nada 5, "5'" = satu oktaf di atas, '5,' = satu oktaf di bawah."""
    deg = note.rstrip("',")
    octave = note.count("'") - note.count(",")
    return base * 2 ** (scale[deg] / 1200.0 + octave)


# --- Instrumen ---------------------------------------------------------------

def bedug(f0=58.0, vel=1.0, dur=1.0):
    t = t_axis(dur)
    f = f0 * (1 + 0.8 * np.exp(-t / 0.022))
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-t / 0.34)
    over = 0.35 * np.sin(ph * 1.59) * np.exp(-t / 0.11)
    thump = lp(noise(len(t)), 240) * np.exp(-t / 0.03) * 2.2
    skin = bp(noise(len(t)), 700, 2600) * np.exp(-t / 0.012) * 0.25
    x = body + over + thump + skin
    return np.tanh(1.8 * x * vel) / np.tanh(1.8)


def kendang(kind, vel=1.0):
    if kind == "dang":
        t = t_axis(0.5)
        f = 92 * (1 + 0.35 * np.exp(-t / 0.03))
        x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.2)
        x += lp(noise(len(t)), 400) * np.exp(-t / 0.02)
    elif kind == "tung":
        t = t_axis(0.3)
        f = 205 * (1 + 0.25 * np.exp(-t / 0.02))
        x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.1)
        x += 0.3 * bp(noise(len(t)), 600, 2000) * np.exp(-t / 0.01)
    elif kind == "tak":
        t = t_axis(0.15)
        x = 0.6 * np.sin(2 * np.pi * 430 * t) * np.exp(-t / 0.03)
        x += bp(noise(len(t)), 1400, 5200) * np.exp(-t / 0.018) * 1.2
    else:  # "ket": pukulan teredam
        t = t_axis(0.12)
        x = np.sin(2 * np.pi * 270 * t) * np.exp(-t / 0.035)
        x += 0.4 * bp(noise(len(t)), 900, 3000) * np.exp(-t / 0.008)
    return fade_in(x * vel)


def _wood_kernel():
    t = t_axis(0.04)
    k = (np.sin(2 * np.pi * 980 * t) * np.exp(-t / 0.011)
         + 0.7 * np.sin(2 * np.pi * 2350 * t) * np.exp(-t / 0.007)
         + 0.35 * np.sin(2 * np.pi * 3900 * t) * np.exp(-t / 0.004))
    return k


WOOD = _wood_kernel()


def korek(vel=1.0, clicks=9, dur=0.3):
    """Korek: gerigi kayu yang diputar, bunyinya 'krrrek'."""
    n = int((dur + 0.06) * SR)
    imp = np.zeros(n)
    times = dur * np.linspace(0, 1, clicks) ** 0.8
    for i, tm in enumerate(times):
        idx = int(tm * SR + rng.uniform(-0.002, 0.002) * SR)
        if 0 <= idx < n:
            imp[idx] += (1.0 - 0.45 * i / clicks) * rng.uniform(0.7, 1.0)
    x = fftconvolve(imp, WOOD)[:n]
    x += 0.08 * bp(noise(n), 1500, 6000) * np.exp(-np.arange(n) / SR / (dur * 0.6))
    return fade_in(x * vel)


def kentongan(f=640.0, vel=1.0):
    t = t_axis(0.35)
    x = (np.sin(2 * np.pi * f * t) * np.exp(-t / 0.075)
         + 0.45 * np.sin(2 * np.pi * 2.3 * f * t) * np.exp(-t / 0.03)
         + 0.18 * np.sin(2 * np.pi * 3.9 * f * t) * np.exp(-t / 0.012))
    x += 0.35 * bp(noise(len(t)), 2000, 7000) * np.exp(-t / 0.003)
    return fade_in(x * vel)


def gong(f=62.0, vel=1.0, dur=5.5):
    t = t_axis(dur)
    swell = 1 - np.exp(-t / 0.06)
    x = (np.sin(2 * np.pi * f * t) + 0.85 * np.sin(2 * np.pi * (f + 1.4) * t)) * np.exp(-t / 2.3)
    x += 0.5 * np.sin(2 * np.pi * 2.01 * f * t) * np.exp(-t / 1.5)
    x += 0.22 * np.sin(2 * np.pi * 2.83 * f * t) * np.exp(-t / 0.9)
    x += 0.1 * np.sin(2 * np.pi * 4.17 * f * t) * np.exp(-t / 0.5)
    x += 0.05 * np.sin(2 * np.pi * 5.43 * f * t) * np.exp(-t / 0.3)
    x = x * swell + 0.6 * lp(noise(len(t)), 160) * np.exp(-t / 0.04)
    return fade_in(x * vel, 4)


def kempul(f, vel=1.0):
    return modes(f, 2.2, [(1.0, 0.9, 1.0), (1.007, 0.9, 0.6), (2.02, 0.5, 0.35), (3.01, 0.25, 0.12)]) * vel


def kenong(f, vel=1.0):
    return modes(f, 1.6, [(1.0, 0.7, 1.0), (3.0, 0.25, 0.25), (4.2, 0.12, 0.1), (1.004, 0.7, 0.5)]) * vel


def saron(f, vel=1.0):
    x = modes(f, 1.4, [(1.0, 0.55, 1.0), (2.76, 0.18, 0.28), (5.4, 0.05, 0.1)])
    t = t_axis(1.4)
    x += 0.25 * bp(noise(len(t)), 2500, 8000) * np.exp(-t / 0.004)
    return x * vel


def bonang(f, vel=1.0):
    return modes(f, 0.9, [(1.0, 0.35, 1.0), (2.4, 0.12, 0.3), (3.9, 0.05, 0.12), (1.006, 0.35, 0.4)]) * vel


def cricket(dur=0.42):
    t = t_axis(dur)
    am = (np.sin(2 * np.pi * 38 * t) > 0.2).astype(float)
    gate = ((t % 0.14) < 0.09).astype(float)
    x = np.sin(2 * np.pi * 4700 * t) * am * gate * np.exp(-t / 0.5)
    return lp(x, 7000)


def melody_line(notes, bpm, scale, base, voice, octave=0, glide=0.03):
    """Melodi sustain (slompret/suling). notes = [(nada atau None, ketukan), ...]."""
    beat = 60.0 / bpm
    total = sum(b for _, b in notes) * beat
    n = int(total * SR) + 1
    freq = np.zeros(n)
    amp = np.zeros(n)
    since = np.zeros(n)
    pos = 0.0
    last_f = None
    for note, beats in notes:
        s, e = int(pos * SR), int((pos + beats * beat) * SR)
        if note is not None:
            f = pitch(note, scale, base) * 2 ** octave
            freq[s:e] = f
            last_f = f
            length = e - s
            env = np.ones(length) * 0.9
            a = min(length, int(0.035 * SR))
            r = min(length - a, int(0.07 * SR))
            env[:a] = np.linspace(0, 1, a)
            env[length - r:] *= np.linspace(1, 0, r)
            amp[s:e] = env
            since[s:e] = np.arange(length) / SR
        elif last_f is not None:
            freq[s:e] = last_f
        pos += beats * beat
    if (freq == 0).any():
        first = freq[np.nonzero(freq)[0][0]]
        freq[freq == 0] = first
    # glide: haluskan perpindahan nada
    k = int(glide * SR)
    if k > 1:
        freq = np.convolve(np.pad(freq, (k, k), mode="edge"), np.ones(k) / k, mode="same")[k:-k]
    vib_depth = np.clip(since / 0.25, 0, 1)
    t = np.arange(n) / SR
    if voice == "slompret":
        vib = 2 ** (18 / 1200 * vib_depth * np.sin(2 * np.pi * 5.6 * t))
    else:
        vib = 2 ** (9 / 1200 * vib_depth * np.sin(2 * np.pi * 4.8 * t))
    phase = 2 * np.pi * np.cumsum(freq * vib) / SR
    out = np.zeros(n)
    if voice == "slompret":
        for h in range(1, 14):
            weight = (1.0 / h) * (1.6 if 3 <= h <= 6 else 1.0)
            mask = freq * h < SR / 2 - 500
            out += weight * np.sin(h * phase) * mask
        out = 0.55 * bp(out, 900, 1700) + 0.35 * bp(out, 2300, 3200) + 0.4 * lp(out, 3800)
        out += 0.04 * bp(noise(n), 1500, 4500)
    else:  # suling
        out = np.sin(phase) + 0.12 * np.sin(2 * phase) + 0.04 * np.sin(3 * phase)
        out += 0.07 * bp(noise(n), 1800, 6000)
    return out * amp


# --- Mixer -------------------------------------------------------------------

class Mix:
    def __init__(self, seconds):
        self.buf = np.zeros((2, int(seconds * SR) + 1))

    def add(self, sound, at, gain=1.0, pan=0.0):
        s = int(at * SR)
        if s >= self.buf.shape[1]:
            return
        e = min(self.buf.shape[1], s + len(sound))
        theta = (pan + 1) * np.pi / 4
        self.buf[0, s:e] += sound[:e - s] * gain * np.cos(theta)
        self.buf[1, s:e] += sound[:e - s] * gain * np.sin(theta)


def reverb(buf, wet=0.18, length=1.8, decay=0.45):
    t = t_axis(length)
    out = buf.copy()
    for ch in range(2):
        ir = lp(noise(len(t)), 5000) * np.exp(-t / decay)
        ir[: int(0.012 * SR)] = 0
        ir /= np.sqrt(np.sum(ir ** 2))
        out[ch] += wet * fftconvolve(buf[ch], ir)[: buf.shape[1]]
    return out


def finish_loop(mix, loop_seconds):
    """Ekor bunyi yang lewat ujung loop dilipat ke awal supaya loop mulus."""
    buf = reverb(mix.buf)
    n = int(loop_seconds * SR)
    out = buf[:, :n].copy()
    tail = buf[:, n:]
    while tail.shape[1] > 0:
        m = min(n, tail.shape[1])
        out[:, :m] += tail[:, :m]
        tail = tail[:, m:]
    return out


def normalize(x, rms_target, peak=0.95):
    rms = np.sqrt(np.mean(x ** 2)) + 1e-9
    x = x * (rms_target / rms)
    # limiter lembut supaya puncak tidak pecah
    over = np.max(np.abs(x))
    if over > peak:
        x = np.tanh(x / peak * 1.2) / np.tanh(1.2) * peak
    return x


def write_ogg(path, data, quality=4):
    data = np.atleast_2d(data)
    channels = data.shape[0]
    pcm = (np.clip(data, -1, 1) * 32767).astype(np.int16).T.copy()
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav_path = tmp.name
    with wave.open(wav_path, "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path,
                    "-c:a", "libvorbis", "-q:a", str(quality), path], check=True)
    os.remove(wav_path)
    print("tulis", os.path.relpath(path, ROOT), "%.1f dtk" % (data.shape[1] / SR))


# --- Lagu ----------------------------------------------------------------------

def beats_of(text):
    """'2 1 2 6 | 3 5 . 2' -> ['2','1','2','6','3','5',None,'2']"""
    out = []
    for tok in text.replace("|", " ").split():
        out.append(None if tok == "." else tok)
    return out


def colotomic(mix, balungan, beat, scale, base, gong_every=16, kenong_at=(3, 7, 11, 15),
              kempul_at=(5, 9, 13), vel=1.0, gong_f=62.0):
    """Struktur gamelan: kenong, kempul, dan gong menandai siklus lagu."""
    for i, note in enumerate(balungan):
        pos = i % gong_every
        current = note
        j = i
        while current is None and j > 0:
            j -= 1
            current = balungan[j]
        if current is None:
            continue
        if pos in kenong_at:
            mix.add(kenong(pitch(current, scale, base)), i * beat, 0.22 * vel, 0.25)
        if pos in kempul_at:
            mix.add(kempul(pitch(current + ",", scale, base)), i * beat, 0.3 * vel, -0.25)
        if pos == gong_every - 1:
            mix.add(gong(gong_f), i * beat, 0.75 * vel, 0.0)


def song_battle():
    bpm, scale, base = 132, SLENDRO, 290.0
    beat = 60 / bpm
    bal = beats_of("2 1 2 6 | 2 1 2 6 | 3 5 3 2 | 5 3 2 1 |"
                   "3 2 1 6 | 3 5 6 1 | 6 5 3 2 | 5 3 2 1") * 2
    loop = len(bal) * beat
    mix = Mix(loop + 6)
    for i, note in enumerate(bal):
        if note:
            mix.add(saron(pitch(note, scale, base)), i * beat, 0.3, -0.35)
            for half in (0, 0.5):
                mix.add(saron(pitch(note + "'", scale, base)), (i + half) * beat, 0.11, 0.4)
    colotomic(mix, bal, beat, scale, base)
    for i in range(len(bal)):
        pos = i % 4
        t = i * beat
        if pos in (0, 2):
            mix.add(bedug(58, 1.0), t, 0.55)
        if pos in (1, 3):
            mix.add(korek(0.9), t, 0.26, 0.15)
        mix.add(kendang("tak", 0.7 if pos % 2 else 0.5), t + beat * 0.5, 0.22, -0.1)
        mix.add(kentongan(620 if i % 2 else 820, 0.5), t + beat * 0.75, 0.13, 0.5)
        if pos == 3 and (i // 4) % 2 == 1:
            mix.add(bedug(66, 0.7), t + beat * 0.5, 0.4)
        if i % 16 >= 14:  # isian kendang menjelang gong
            for q in (0.25, 0.5, 0.75):
                mix.add(kendang("tung", 0.8), t + beat * q, 0.25, -0.1)
        elif pos == 1:
            mix.add(kendang("dang", 0.8), t + beat * 0.5, 0.3, -0.1)
    lead = [("6", 1), ("1'", 1), ("2'", 2), ("1'", 0.5), ("6", 0.5), ("5", 1), ("6", 2),
            ("3'", 1), ("2'", 1), ("1'", 1), ("2'", 1), ("6", 0.5), ("1'", 0.5), ("2'", 1), ("1'", 2),
            ("5'", 1), ("3'", 1), ("2'", 1), ("3'", 1), ("2'", 0.5), ("1'", 0.5), ("6", 1), ("5", 2),
            ("6", 1), ("1'", 1), ("2'", 1), ("3'", 1), ("5'", 0.5), ("3'", 0.5), ("2'", 1), ("1'", 2)]
    half = loop / 2
    mix.add(melody_line(lead, bpm, scale, base, "slompret"), 0, 0.2, 0.05)
    mix.add(melody_line(lead, bpm, scale, base, "suling", octave=1), half, 0.12, -0.05)
    return normalize(finish_loop(mix, loop), 0.13)


def song_boss():
    bpm, scale, base = 140, PELOG, 220.0
    beat = 60 / bpm
    bal = beats_of("3 2 1 2 | 3 2 1 6, | 1 2 3 5 | 3 2 1 6, |"
                   "6, 5, 6, 1 | 3 2 1 6, | 5 6 7 6 | 5 3 2 1") * 2
    loop = len(bal) * beat
    mix = Mix(loop + 6)
    for i, note in enumerate(bal):
        if note:
            mix.add(saron(pitch(note, scale, base)), i * beat, 0.32, -0.35)
            mix.add(bonang(pitch(note + "'", scale, base)), (i + 0.5) * beat, 0.12, 0.45)
    colotomic(mix, bal, beat, scale, base, gong_every=8, kenong_at=(1, 3, 5, 7), kempul_at=(2, 6),
              vel=1.1, gong_f=55.0)
    for i in range(len(bal)):
        pos = i % 4
        t = i * beat
        mix.add(bedug(50, 1.0), t, 0.55)
        if pos in (1, 3):
            mix.add(bedug(50, 0.8), t + beat * 0.5, 0.42)
        mix.add(korek(1.0, clicks=7, dur=0.2), t + beat * 0.5, 0.24, 0.2)
        mix.add(kendang("tak", 0.7), t + beat * 0.25, 0.18, -0.15)
        mix.add(kendang("tak", 0.6), t + beat * 0.75, 0.16, -0.15)
        if pos == 2:
            mix.add(kentongan(520, 0.7), t, 0.16, 0.5)
    # dengung rendah yang mengancam
    t = t_axis(loop + 2)
    drone_f = pitch("1,", scale, base) / 2
    drone = (np.sin(2 * np.pi * drone_f * t) + 0.5 * np.sin(2 * np.pi * drone_f * 1.5 * t + 1.0)) * (
        0.7 + 0.3 * np.sin(2 * np.pi * t / (loop / 4)))
    mix.add(lp(drone, 300), 0, 0.12)
    lead = [("1'", 1), ("2'", 0.5), ("1'", 0.5), ("7", 1), ("6", 1), ("5", 2), ("6", 1), ("7", 1),
            ("1'", 0.5), ("2'", 0.5), ("3'", 1), ("2'", 1), ("1'", 1), ("7", 2), ("6", 2),
            ("3'", 1.5), ("2'", 0.5), ("1'", 1), ("2'", 1), ("3'", 0.5), ("5'", 0.5), ("4'", 1), ("3'", 2),
            ("2'", 1), ("1'", 1), ("7", 1), ("6", 1), ("5", 0.5), ("6", 0.5), ("7", 1), ("1'", 2)]
    mix.add(melody_line(lead, bpm, scale, base, "slompret"), 0, 0.21, 0.05)
    # putaran kedua: slompret naik satu oktaf, lebih tegang
    mix.add(melody_line(lead, bpm, scale, base, "slompret", octave=1), loop / 2, 0.15, 0.05)
    return normalize(finish_loop(mix, loop), 0.14)


def song_map():
    bpm, scale, base = 96, SLENDRO, 290.0
    beat = 60 / bpm
    bal = beats_of("3 5 6 5 | 3 2 1 2 | 3 5 3 2 | 1 6, 5, 6, |"
                   "1 2 3 2 | 1 6, 5, 6, | 2 1 6, 5, | 3 5 6 1")
    loop = len(bal) * beat
    mix = Mix(loop + 6)
    for i, note in enumerate(bal):
        if note:
            mix.add(saron(pitch(note, scale, base)), i * beat, 0.3, -0.3)
    # bonang mipil: nada sekarang dan berikutnya bergantian
    for i in range(0, len(bal), 2):
        a, b = bal[i], bal[(i + 1) % len(bal)]
        for k, note in enumerate((a, b, a, b)):
            mix.add(bonang(pitch(note + "'", scale, base)), (i + k * 0.5) * beat, 0.1, 0.4)
    colotomic(mix, bal, beat, scale, base)
    for i in range(len(bal)):
        pos = i % 4
        t = i * beat
        if pos == 0:
            mix.add(kendang("dang", 0.8), t, 0.3, -0.1)
        if pos == 1:
            mix.add(kendang("tak", 0.6), t + beat * 0.5, 0.2, -0.1)
        if pos == 2:
            mix.add(kendang("tung", 0.7), t + beat * 0.5, 0.2, -0.1)
        if pos == 3:
            mix.add(kendang("dang", 0.6), t, 0.22, -0.1)
        mix.add(kentongan(700, 0.4), t + beat * 0.5, 0.08, 0.5)
        if i % 16 == 15:
            mix.add(korek(0.8), t, 0.2, 0.2)
    flute = [("5'", 2), ("6'", 1), ("5'", 1), ("3'", 2), ("2'", 1), ("3'", 1), ("5'", 3), ("3'", 0.5),
             ("2'", 0.5), ("1'", 4),
             ("2'", 1), ("3'", 1), ("5'", 2), ("6'", 1.5), ("5'", 0.5), ("3'", 2), ("2'", 1), ("1'", 1),
             ("2'", 1), ("3'", 1), ("2'", 4)]
    mix.add(melody_line(flute, bpm, scale, base, "suling", octave=1), 0, 0.13, -0.1)
    for _ in range(14):
        mix.add(cricket(), rng.uniform(0, loop), 0.02, rng.uniform(-0.8, 0.8))
    return normalize(finish_loop(mix, loop), 0.11)


def song_menu():
    bpm, scale, base = 66, SLENDRO, 290.0
    beat = 60 / bpm
    bal = beats_of("2 . 1 . 2 . 6, . 3 . 5 . 3 . 2 . |"
                   "5 . 3 . 2 . 1 . 2 . 6, . 5, . 6, .")
    loop = len(bal) * beat
    mix = Mix(loop + 7)
    for i, note in enumerate(bal):
        if note:
            mix.add(saron(pitch(note, scale, base)), i * beat, 0.26, -0.3)
    colotomic(mix, bal, beat, scale, base, kenong_at=(3, 11), kempul_at=(7,), vel=0.9)
    for i in range(0, len(bal), 8):
        mix.add(bedug(52, 0.7), i * beat, 0.4)
        mix.add(bedug(52, 0.5), (i + 0.6) * beat, 0.25)
    for i in range(len(bal)):
        if i % 4 == 2:
            mix.add(kentongan(560, 0.35), i * beat, 0.07, 0.5)
    flute = [("3'", 3), ("2'", 1), ("1'", 2), ("6", 2), ("1'", 3), ("2'", 0.5), ("3'", 0.5), ("2'", 4),
             ("5'", 3), ("6'", 1), ("5'", 2), ("3'", 2), ("2'", 3), ("3'", 0.5), ("2'", 0.5), ("1'", 2), ("6", 2)]
    mix.add(melody_line(flute, bpm, scale, base, "suling", octave=1, glide=0.05), 0, 0.14, -0.1)
    # angin malam
    t = t_axis(loop + 2)
    wind = lp(noise(len(t)), 600) * (0.6 + 0.4 * np.sin(2 * np.pi * t / (loop / 2)))
    mix.add(wind, 0, 0.05)
    for _ in range(22):
        mix.add(cricket(), rng.uniform(0, loop), 0.025, rng.uniform(-0.9, 0.9))
    return normalize(finish_loop(mix, loop), 0.1)


def song_victory():
    bpm, scale, base = 120, SLENDRO, 290.0
    mix = Mix(7.5)
    roll = [0.0, 0.18, 0.32, 0.43, 0.52, 0.59, 0.65, 0.7]
    for k, tm in enumerate(roll):
        mix.add(bedug(60, 0.5 + 0.5 * k / len(roll)), tm, 0.5)
    mix.add(korek(1.0), 0.76, 0.32, 0.2)
    for k, note in enumerate(["1", "2", "3", "5", "6", "1'"]):
        mix.add(saron(pitch(note, scale, base)), 0.95 + k * 0.2, 0.36, -0.3)
        mix.add(saron(pitch(note + "'", scale, base)), 0.95 + k * 0.2 + 0.1, 0.14, 0.4)
    mix.add(gong(62), 2.2, 0.8)
    mix.add(kempul(pitch("1", scale, base)), 2.2, 0.3, -0.3)
    mix.add(bedug(56, 1.0), 2.2, 0.6)
    fanfare = [("5", 0.5), ("6", 0.5), ("1'", 1), ("2'", 0.5), ("1'", 3)]
    mix.add(melody_line(fanfare, bpm, scale, base, "slompret"), 2.2, 0.26, 0.05)
    buf = reverb(mix.buf)
    n = buf.shape[1]
    buf *= np.minimum(1.0, (n - np.arange(n)) / (0.8 * SR))  # ujung memudar
    return normalize(buf, 0.13)


# --- Efek suara ------------------------------------------------------------------

def place(dst, src, start, gain=1.0):
    """Tambahkan src ke dst mulai sampel `start`, dipotong kalau kepanjangan."""
    if start >= len(dst):
        return
    m = min(len(src), len(dst) - start)
    dst[start:start + m] += src[:m] * gain


def sfx_all():
    s = {}
    s["bedug"] = bedug(60)
    s["korek"] = korek()
    s["kentongan"] = kentongan(660)
    s["gong"] = gong(64, dur=3.5) * np.minimum(1, (3.5 * SR - np.arange(int(3.5 * SR))) / (0.6 * SR))
    d = np.zeros(int(0.75 * SR))
    place(d, bedug(62), 0)
    place(d, korek(1.0), int(0.16 * SR), 0.8)
    s["dongkrek"] = d

    t = t_axis(0.3)
    hit = lp(noise(len(t)), 1800) * np.exp(-t / 0.03) * 1.3
    hit += np.sin(2 * np.pi * 110 * (1 + np.exp(-t / 0.02)) * t) * np.exp(-t / 0.08)
    s["hit"] = fade_in(hit)
    t = t_axis(0.55)
    heavy = lp(noise(len(t)), 1200) * np.exp(-t / 0.05) * 1.4
    place(heavy, bedug(48), 0, 0.9)
    s["hit_heavy"] = fade_in(heavy)

    t = t_axis(0.35)
    block = 0.7 * kentongan(420)[: len(t)]
    block += 0.35 * np.sin(2 * np.pi * 1650 * t) * np.exp(-t / 0.18) + 0.2 * np.sin(2 * np.pi * 2480 * t) * np.exp(-t / 0.12)
    s["block"] = fade_in(block)

    def swish(dur=0.13, lo=1500, hi=6000):
        tt = t_axis(dur)
        env = np.sin(np.pi * np.clip(tt / dur, 0, 1)) ** 2
        return bp(noise(len(tt)), lo, hi) * env

    s["card"] = swish()
    s["click"] = kentongan(1250, 0.8)[: int(0.07 * SR)] * np.linspace(1, 0, int(0.07 * SR))
    t = t_axis(0.35)
    lock = 0.8 * np.sin(2 * np.pi * 2200 * t) * np.exp(-t / 0.02) + 0.5 * bp(noise(len(t)), 3000, 8000) * np.exp(-t / 0.01)
    for k2 in range(5):
        st = int((0.06 + k2 * 0.045) * SR)
        ln = int(0.03 * SR)
        lock[st:st + ln] += 0.25 * bp(noise(ln), 3500, 9000) * np.linspace(1, 0, ln)
    s["lock"] = fade_in(lock)
    sh = np.zeros(int(0.45 * SR))
    for k2 in range(4):
        place(sh, swish(0.1, 1200 + 300 * k2, 5000), int(k2 * 0.08 * SR), 1 - 0.15 * k2)
    s["shuffle"] = sh

    mox = np.zeros(int(0.9 * SR))
    for k2, note in enumerate(["1", "3", "5", "1'", "3'"]):
        place(mox, saron(pitch(note + "'", SLENDRO, 290.0), 0.8), int(k2 * 0.06 * SR), 0.7 + 0.1 * k2)
    s["moxie"] = mox

    t = t_axis(0.5)
    blob = np.zeros(len(t))
    for k2 in range(5):
        st = int(k2 * 0.08 * SR)
        tt = t[: len(t) - st]
        f = 520 * (1 - 0.1 * k2) * (1 + 0.6 * np.exp(-tt / 0.03))
        blob[st:] += np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / 0.05) * 0.5
    s["poison"] = fade_in(lp(blob, 2500))

    t = t_axis(2.4)
    defeat = gong(55, dur=2.4) * 0.8
    for k2, note in enumerate(["6", "5", "3", "2"]):
        st = int(k2 * 0.3 * SR)
        place(defeat, kempul(pitch(note + ",", SLENDRO, 290.0)), st, 0.5)
    defeat *= np.minimum(1, (len(t) - np.arange(len(t))) / (0.5 * SR))
    s["defeat"] = defeat

    t = t_axis(0.22)
    err = np.zeros(len(t))
    for st_s in (0.0, 0.09):
        st = int(st_s * SR)
        tt = t[: len(t) - st]
        err[st:] += np.sign(np.sin(2 * np.pi * 150 * tt)) * np.exp(-tt / 0.03) * 0.4
    s["error"] = lp(err, 1500)
    return s


def main():
    os.makedirs(OUT_BGM, exist_ok=True)
    os.makedirs(OUT_SFX, exist_ok=True)
    songs = {
        "menu": song_menu, "map": song_map, "battle": song_battle,
        "boss": song_boss, "victory": song_victory,
    }
    for name, fn in songs.items():
        write_ogg(os.path.join(OUT_BGM, name + ".ogg"), fn(), quality=4)
    # Efek suara dinormalkan per puncak lalu diberi bobot supaya seimbang.
    gains = {"click": 0.5, "card": 0.55, "shuffle": 0.55, "error": 0.6, "moxie": 0.75,
             "poison": 0.8, "lock": 0.8, "kentongan": 0.8}
    for name, data in sfx_all().items():
        data = np.asarray(data, dtype=np.float64)
        data = data / (np.max(np.abs(data)) + 1e-9) * 0.85 * gains.get(name, 1.0)
        tail = min(len(data), int(0.015 * SR))
        data[len(data) - tail:] *= np.linspace(1, 0, tail)  # cegah bunyi "klik" di ujung
        write_ogg(os.path.join(OUT_SFX, name + ".ogg"), data, quality=5)


if __name__ == "__main__":
    main()
