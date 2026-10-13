"""Gravity Hopper ana tema denemesi (D-02, docs/music_research.md §9). Aynı melodi üç sektör
düzenlemesinde: S1 100, S2 110, S3 120 BPM; geçişler ölçü sınırında. Yalnızca kodla üretilir
(örnek ses ya da dış kayıt yok); numpy gerekir (pip install numpy). 16 bit stereo WAV yazar.
Kullanım: python tools/theme_demo.py <çıktı.wav> [<spektrogram.png>]"""
import math
import struct
import sys
import wave
import zlib

import numpy as np

SR = 44100
rng = np.random.default_rng(7)


def mtof(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12)


# ---------------------------------------------------------------- ses üreteçleri

def tone(f, dur, rel=0.08, wave_kind="saw", bright=1.0, decay=0.0, attack=0.005, fc=None,
         vib=0.0, vib_delay=0.15, kmax=48, phase=0.0):
    """Toplamsal (additive) osilatör: harmonikler Nyquist altında, tizler 'bright' hızıyla söner."""
    n = int((dur + rel) * SR)
    t = np.arange(n) / SR
    finst = np.full(n, f)
    if vib > 0.0:
        ramp = np.clip((t - vib_delay) / 0.2, 0.0, 1.0)
        finst = f * 2 ** (vib * ramp * np.sin(2 * math.pi * 5.5 * t) / 12)
    base = 2 * math.pi * np.cumsum(finst) / SR + phase
    out = np.zeros(n)
    k_top = min(kmax, int(0.45 * SR / f))
    for k in range(1, k_top + 1):
        if wave_kind == "saw":
            w = 1.0 / k
        elif wave_kind == "square":
            w = 1.0 / k if k % 2 == 1 else 0.0
        else:  # üçgen
            w = 1.0 / (k * k) if k % 2 == 1 else 0.0
        if w == 0.0:
            continue
        if fc is not None:
            w /= math.sqrt(1.0 + (k * f / fc) ** 4)
        if w < 1e-4:
            continue
        env = np.exp(-t * bright * (k - 1)) if bright > 0.0 else 1.0
        out += w * env * np.sin(k * base)
    amp = np.minimum(t / attack, 1.0) * np.exp(-t * decay)
    amp *= np.clip(1.0 - (t - dur) / rel, 0.0, 1.0)
    return out * amp


def noise(seconds):
    return rng.standard_normal(int(seconds * SR))


def lowpass(x, n):
    return np.convolve(x, np.ones(n) / n, mode="same")


def highpass(x, n):
    return x - lowpass(x, n)


def kick():
    t = np.arange(int(0.5 * SR)) / SR
    f = 46 + 120 * np.exp(-t * 32)
    body = np.sin(2 * math.pi * np.cumsum(f) / SR) * np.exp(-t * 7.0)
    click = highpass(noise(0.5), 8) * np.exp(-t * 500) * 0.25
    x = body + click
    return np.tanh(1.6 * x) / math.tanh(1.6)


def clap():
    t = np.arange(int(0.4 * SR)) / SR
    band = lowpass(highpass(noise(0.4), 28), 5)
    env = np.zeros_like(t)
    for off in (0.0, 0.011, 0.022):
        env += np.where(t >= off, np.exp(-(t - off) * 260), 0.0)
    env += np.where(t >= 0.022, np.exp(-(t - 0.022) * 20) * 0.6, 0.0)
    return band * env / 3.0


def snare():
    t = np.arange(int(0.3 * SR)) / SR
    body = lowpass(highpass(noise(0.3), 16), 3) * np.exp(-t * 20) * 0.5
    ring = np.sin(2 * math.pi * 188 * t) * np.exp(-t * 28) * 0.5
    return body + ring


def hat(open_hat=False):
    length = 0.4 if open_hat else 0.09
    t = np.arange(int(length * SR)) / SR
    x = lowpass(highpass(noise(length), 4), 2)
    return x * np.exp(-t * (9.0 if open_hat else 55.0)) * 0.95


def crash():
    t = np.arange(int(2.6 * SR)) / SR
    return lowpass(highpass(noise(2.6), 3), 2) * np.exp(-t * 1.7) * 0.5


def riser(seconds):
    t = np.arange(int(seconds * SR)) / SR
    # Filtre süpürmesi gibi: koyu gürültüden parlak gürültüye geçer.
    r = t / seconds
    x = (1 - r) * lowpass(noise(seconds), 24) * 2.5 + r * highpass(noise(seconds), 6)
    return x * r ** 2.2 * 0.6


# ---------------------------------------------------------------- miks

class Mix:
    def __init__(self, seconds):
        self.n = int(seconds * SR)
        self.buses = {}
        self.kicks = []

    def add(self, bus, start, mono, gain=1.0, pan=0.0):
        if bus not in self.buses:
            self.buses[bus] = np.zeros((2, self.n))
        i = int(round(start * SR))
        if i >= self.n:
            return
        seg = mono[: self.n - i]
        a = (pan + 1.0) * math.pi / 4
        self.buses[bus][0, i:i + len(seg)] += seg * gain * math.cos(a) * math.sqrt(2)
        self.buses[bus][1, i:i + len(seg)] += seg * gain * math.sin(a) * math.sqrt(2)

    def duck(self, depth, tau=0.11):
        """Davul vuruşunda diğer katmanları kısar (sidechain)."""
        d = np.zeros(self.n)
        for tk in self.kicks:
            i = int(tk * SR)
            m = min(self.n - i, int(0.6 * SR))
            if m <= 0:
                continue
            d[i:i + m] = np.maximum(d[i:i + m], np.exp(-np.arange(m) / SR / tau))
        return 1.0 - depth * d


def reverb(x, seconds=1.8, decay=4.5):
    n_ir = int(seconds * SR)
    t = np.arange(n_ir) / SR
    out = np.zeros_like(x)
    nfft = 1 << int(math.ceil(math.log2(x.shape[1] + n_ir)))
    for ch in range(2):
        ir = lowpass(rng.standard_normal(n_ir), 6) * np.exp(-t * decay)
        ir[: int(0.02 * SR)] = 0.0
        ir /= np.sqrt(np.sum(ir ** 2))
        y = np.fft.irfft(np.fft.rfft(x[ch], nfft) * np.fft.rfft(ir, nfft), nfft)
        out[ch] = y[: x.shape[1]]
    return out


# ---------------------------------------------------------------- beste

# Am – F – C – G (i–VI–III–VII); her ölçüye bir akor.
ROOTS = [33, 29, 36, 31]
PAD = [(57, 60, 64), (57, 60, 65), (55, 60, 64), (55, 59, 62)]
ARP = [(69, 72, 76, 81), (65, 69, 72, 77), (67, 72, 76, 79), (67, 71, 74, 79)]
# Ana tema (16'lık adım, MIDI nota, uzunluk). İmza motifi: 3+3+2 ritimde oktav sıçraması
# (A4 A4 E5 → A5): duvardan duvara geçişin müzikteki karşılığı.
HOOK = [
    [(0, 69, 2), (3, 69, 2), (6, 76, 2), (8, 81, 4), (12, 79, 2), (14, 76, 2)],
    [(0, 77, 3), (3, 76, 3), (6, 72, 2), (8, 69, 6)],
    [(0, 67, 2), (3, 67, 2), (6, 72, 2), (8, 79, 4), (12, 76, 2), (14, 74, 2)],
    [(0, 74, 3), (3, 71, 3), (6, 67, 2), (8, 71, 2), (10, 74, 2), (12, 76, 4)],
    [(0, 69, 2), (3, 69, 2), (6, 76, 2), (8, 81, 4), (12, 79, 2), (14, 76, 2)],
    [(0, 77, 3), (3, 79, 3), (6, 81, 2), (8, 84, 4), (12, 81, 4)],
    [(0, 79, 3), (3, 76, 3), (6, 72, 2), (8, 76, 2), (10, 79, 2), (12, 76, 2), (14, 74, 2)],
    [(0, 74, 3), (3, 76, 3), (6, 79, 2), (8, 81, 8)],
]

SECTIONS = [(1, 100.0, 8), (2, 110.0, 8), (3, 120.0, 8)]
TAIL = 3.5


def build(out_wav, out_png=None):
    starts = []
    t0 = 0.0
    for _, bpm, bars in SECTIONS:
        starts.append(t0)
        t0 += bars * 4 * 60.0 / bpm
    end_t = t0
    mix = Mix(end_t + TAIL)
    k_smp, c_smp, s_smp = kick(), clap(), snare()
    hc_smp, ho_smp, cr_smp = hat(), hat(True), crash()

    for (sector, bpm, bars), st in zip(SECTIONS, starts):
        step = 60.0 / bpm / 4

        def at(bar, s, _st=st, _step=step):
            return _st + (bar * 16 + s) * _step

        if sector > 1:
            mix.add("fx", at(0, 0), crash(), 0.22, -0.5)
            mix.add("fx", at(0, 0), cr_smp, 0.22, 0.5)
        for bar in range(bars):
            c = bar % 4
            last = bar == bars - 1
            # Pad
            for m in PAD[c]:
                for cents, pan in ((-9, -0.6), (0, 0.0), (9, 0.6)):
                    x = tone(mtof(m + cents / 100), 16 * step, rel=0.5, wave_kind="saw", bright=0.0,
                             attack=0.25, fc=1100 if sector < 3 else 1800, phase=rng.uniform(0, 6.28))
                    mix.add("pad", at(bar, 0), x, 0.035, pan)
            # Bas
            root = ROOTS[c]
            if sector == 1:
                pattern = [(0, 0, 6), (6, 0, 2), (8, 0, 8)]
            elif sector == 2:
                pattern = [(s, 12 if (s // 2) % 2 else 0, 1.6) for s in range(0, 16, 2)]
            else:
                pattern = [(s, 12 if s % 4 == 2 else 0, 0.85) for s in range(16)]
            for s, octv, ln in pattern:
                f = mtof(root + octv)
                x = tone(f, ln * step, rel=0.03, wave_kind="saw", bright=2.5 if sector > 1 else 0.0,
                         fc=600 + 500 * sector, kmax=24)
                x += np.sin(2 * math.pi * f * np.arange(len(x)) / SR) * np.clip(
                    1 - np.arange(len(x)) / len(x), 0, 1) * 0.35
                mix.add("bass", at(bar, s), x, 0.26)
            # Arpej (S2+)
            if sector > 1:
                for s in range(16):
                    m = ARP[c][s % 4] + (12 if sector == 3 and bar >= 4 else 0)
                    x = tone(mtof(m), 0.8 * step, rel=0.04, wave_kind="square", bright=3.5, kmax=20)
                    pan = -0.45 if s % 2 == 0 else 0.45
                    mix.add("arp", at(bar, s), x, 0.07 + 0.012 * (sector - 2), pan)
            # Ana tema
            for s, m, ln in HOOK[bar]:
                if sector == 1:
                    x = tone(mtof(m), ln * step, rel=0.12, wave_kind="saw", bright=1.4, decay=2.2,
                             fc=3500)
                    layers = [(x, 0.34, 0.0)]
                elif sector == 2:
                    x = tone(mtof(m), ln * step, rel=0.08, wave_kind="square", bright=0.35, decay=0.5,
                             attack=0.008, fc=6000, vib=0.12)
                    layers = [(x, 0.27, 0.0)]
                else:
                    layers = []
                    for cents, pan in ((-11, -0.35), (0, 0.0), (11, 0.35)):
                        x = tone(mtof(m + cents / 100), ln * step, rel=0.08, wave_kind="saw",
                                 bright=0.25, decay=0.4, attack=0.006, fc=6500, vib=0.1,
                                 phase=rng.uniform(0, 6.28))
                        layers.append((x, 0.12, pan))
                    low = tone(mtof(m - 12), ln * step, rel=0.08, wave_kind="square", bright=0.5,
                               decay=0.6, fc=2500)
                    layers.append((low, 0.13, 0.0))
                for x, g, pan in layers:
                    mix.add("lead", at(bar, s), x, g, pan)
                    # Noktalı sekizlik yankı (tempoya göre)
                    mix.add("lead", at(bar, s + 3), x, g * 0.32, -0.5)
                    mix.add("lead", at(bar, s + 6), x, g * 0.14, 0.5)
            # Davul
            if sector == 1:
                for s in (2, 6, 10, 14):
                    mix.add("drums", at(bar, s), hc_smp, 0.18, 0.25)
                if bar >= 4:
                    for s in (0, 8):
                        mix.add("drums", at(bar, s), k_smp, 0.7)
                        mix.kicks.append(at(bar, s))
                    for s in (4, 12):
                        mix.add("drums", at(bar, s), c_smp, 0.55)
            else:
                for s in (0, 4, 8, 12):
                    mix.add("drums", at(bar, s), k_smp, 0.72)
                    mix.kicks.append(at(bar, s))
                for s in (4, 12):
                    mix.add("drums", at(bar, s), c_smp, 0.6)
                for s in range(16):
                    if s % 4 == 2:
                        smp, g = (ho_smp, 0.16) if sector == 3 else (hc_smp, 0.22)
                    else:
                        smp, g = hc_smp, 0.07 if sector == 2 else 0.1
                    mix.add("drums", at(bar, s), smp, g, 0.25)
                if sector == 3 and bar == 4:
                    mix.add("fx", at(bar, 0), cr_smp, 0.2, 0.0)
            if last:
                mix.add("fx", at(bar, 0), riser(16 * step), 0.16, 0.0)
                roll = range(8, 16) if sector == 3 else range(12, 16)
                for s in roll:
                    mix.add("drums", at(bar, s), s_smp, 0.25 + 0.03 * (s - 8))

    # Final vuruşu: Am akoru + davul + zil
    for m, pan in ((45, 0.0), (57, -0.4), (60, 0.4), (64, -0.2), (69, 0.2)):
        for cents in (-10, 10):
            x = tone(mtof(m + cents / 100), 1.4, rel=1.2, wave_kind="saw", bright=0.6, decay=0.8,
                     fc=3000, phase=rng.uniform(0, 6.28))
            mix.add("lead", end_t, x, 0.07, pan)
    mix.add("bass", end_t, tone(mtof(33), 1.6, rel=1.0, wave_kind="saw", bright=0.8, fc=600), 0.35)
    mix.add("drums", end_t, k_smp, 1.0)
    mix.add("fx", end_t, crash(), 0.18, -0.5)
    mix.add("fx", end_t, cr_smp, 0.18, 0.5)
    mix.kicks.append(end_t)

    b = mix.buses
    b["pad"] *= mix.duck(0.65)
    b["bass"] *= mix.duck(0.4, 0.09)
    b["arp"] *= mix.duck(0.35)
    send = 0.35 * b["pad"] + 0.3 * b["lead"] + 0.3 * b["arp"] + 0.12 * b["drums"] + 0.2 * b["fx"]
    master = sum(b.values()) + 0.45 * reverb(send)
    master /= np.max(np.abs(master))
    master = np.tanh(1.5 * master) / math.tanh(1.5)
    fade = np.clip((mix.n - np.arange(mix.n)) / (0.3 * SR), 0, 1)
    master *= fade
    master *= 0.89 / np.max(np.abs(master))

    pcm = (master.T * 32767).astype("<i2")
    with wave.open(out_wav, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    mono = master.mean(axis=0)
    print("süre %.1f sn, tepe %.2f" % (mix.n / SR, np.max(np.abs(master))))
    bounds = starts + [end_t]
    for k in range(len(SECTIONS)):
        i, j = int(bounds[k] * SR), int(bounds[k + 1] * SR)
        print("S%d %.1f–%.1f sn, RMS %.3f" % (k + 1, bounds[k], bounds[k + 1],
                                              np.sqrt(np.mean(mono[i:j] ** 2))))
    if out_png:
        spectrogram(mono, out_png, [s for s in starts[1:]] + [end_t])


def spectrogram(x, path, marks):
    hop, nwin = 1024, 2048
    frames = (len(x) - nwin) // hop
    win = np.hanning(nwin)
    spec = np.array([np.abs(np.fft.rfft(x[i * hop:i * hop + nwin] * win))[:480] for i in range(frames)])
    db = 20 * np.log10(spec + 1e-6)
    img = np.clip((db - db.max() + 80) / 80, 0, 1)
    img = (img.T[::-1] * 255).astype(np.uint8)
    for m in marks:
        img[:, min(frames - 1, int(m * SR / hop))] = 255
    h, w = img.shape
    raw = b"".join(b"\x00" + img[r].tobytes() for r in range(h))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 0, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)


if __name__ == "__main__":
    build(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
