"""Örnekleyici (sampler) ve miks motoru (M3-21, architecture.md §8.3, ADR-065).

Bir besteyi (score.py) gerçek enstrüman kayıtlarıyla (samples.py) seslendirir:
  - Nota, en yakın perdedeki kaydın hızı değiştirilerek çalınır (kübik ara değer). Kayıtlar
    çoğunlukla tam ton aralıkla alınmış; perde en çok bir iki yarım ses kayar.
  - Vuruş gücü (velocity) katmanı ve ses düzeyini, sıradaki kayıt (round robin) tekrarı seçer.
  - Uzun notalar kaydın sabit bölümünde çapraz geçişle uzatılır.
  - Kanal başına eşitleme (FFT'de, fazı bozmadan), panorama, genişlik ve yankı gönderimi.
  - Ana çıkışta yapıştırıcı sıkıştırıcı ve tepe sınırlayıcı.
Döngü: parça tam ölçü uzunluğundadır. Sondan taşan sesler (çınlama, yankı) başa eklenir ve
bütün FFT işlemleri döngüsel yapılır; dikiş kendiliğinden süreklidir.
"""

import math
import re
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
import soundfile as sf

SR = 44100
# Döngünün sonundan taşan sesin (çınlama, yankı) başa eklenen bölümü (sn).
TAIL_SEC = 8.0
# Döngünün başından önce başlayan sesler (öne alınmış girişler) için pay (sn); sona eklenir.
LEAD_SEC = 0.5
NOTE_RE = re.compile(r"(?<![A-Za-z])([A-Ga-g])([#b]?)(-?\d)(?![\d])")
PITCH_CLASSES = {"c": 0, "d": 2, "e": 4, "f": 5, "g": 7, "a": 9, "b": 11}
# Kayıt düzeyi: kısa süreli (50 ms) RMS'in tepesi bu değere çekilir.
NORMAL_DB = -18.0
FADE_SEC = 0.004
# Bağlı notada önceki notanın sönüşü (sn): iki perde üst üste uzun süre çalmaz.
LEGATO_RELEASE = 0.07


def note_number(name: str) -> int:
    """'C4' → 60 (bilimsel gösterim; A4 = 69)."""
    m = NOTE_RE.fullmatch(name.strip())
    if m is None:
        raise ValueError(name)
    letter, accidental, octave = m.groups()
    pc = PITCH_CLASSES[letter.lower()] + {"#": 1, "b": -1, "": 0}[accidental]
    return 12 * (int(octave) + 1) + pc


def find_note(text: str) -> int | None:
    m = NOTE_RE.search(text)
    return note_number("".join(m.groups())) if m else None


def resample(x: np.ndarray, sr_in: int) -> np.ndarray:
    """FFT ile bant sınırlı örnek hızı dönüşümü (kayıtlar 48 kHz olabilir)."""
    if sr_in == SR:
        return x
    n_out = int(round(len(x) * SR / sr_in))
    pad = 2048
    padded = np.vstack([np.zeros((pad, x.shape[1])), x, np.zeros((pad, x.shape[1]))])
    spec = np.fft.rfft(padded, axis=0)
    n_pad_out = int(round(len(padded) * SR / sr_in))
    keep = min(spec.shape[0], n_pad_out // 2 + 1)
    out_spec = np.zeros((n_pad_out // 2 + 1, x.shape[1]), dtype=complex)
    out_spec[:keep] = spec[:keep]
    y = np.fft.irfft(out_spec, n=n_pad_out, axis=0) * (n_pad_out / len(padded))
    start = int(round(pad * SR / sr_in))
    return y[start:start + n_out]


def short_rms_db(x: np.ndarray, window: float = 0.05) -> np.ndarray:
    mono = x.mean(axis=1) if x.ndim == 2 else x
    win = max(1, int(window * SR))
    n = max(1, len(mono) // win)
    blocks = mono[:n * win].reshape(n, win) if len(mono) >= win else mono[None, :]
    return 20 * np.log10(np.sqrt(np.mean(blocks ** 2, axis=1)) + 1e-12)


@dataclass
class Sample:
    data: np.ndarray            # (n, 2) float64, SR; başı vuruşun başlangıcına kırpılmış
    root: float                 # MIDI perdesi (vurmalılarda 60)
    layer: int = 0              # vuruş gücü katmanı (0 en yumuşak)
    name: str = ""
    sustain: tuple[int, int] = (0, 0)  # uzatma için sabit bölüm (örnek)


def load_sample(path: Path, root: float = 60.0, layer: int = 0,
                onset_db: float = -40.0) -> Sample:
    x, sr = sf.read(str(path), dtype="float64", always_2d=True)
    if x.shape[1] == 1:
        x = np.repeat(x, 2, axis=1)
    x = resample(x[:, :2], sr)
    # Başlangıç: tepeye göre onset_db'yi ilk aşan örnekten 2 ms önce.
    env = np.abs(x).max(axis=1)
    peak = float(env.max()) + 1e-12
    above = np.nonzero(env > peak * 10 ** (onset_db / 20))[0]
    start = max(0, int(above[0]) - int(0.002 * SR)) if len(above) else 0
    x = x[start:]
    # Sondaki sessizlik atılır.
    above = np.nonzero(np.abs(x).max(axis=1) > peak * 1e-4)[0]
    x = x[:int(above[-1]) + 1] if len(above) else x
    levels = short_rms_db(x[:int(1.5 * SR)])
    x = x * 10 ** ((NORMAL_DB - float(levels.max())) / 20)
    x[:int(0.001 * SR)] *= np.linspace(0, 1, int(0.001 * SR))[:, None]
    # Sabit bölüm: düzeyin tepeden 6 dB içinde kaldığı en uzun kesit.
    lv = short_rms_db(x)
    ok = lv > lv.max() - 6
    best, run_start, best_span = (0, 0), None, 0
    for i, flag in enumerate(np.append(ok, False)):
        if flag and run_start is None:
            run_start = i
        elif not flag and run_start is not None:
            if i - run_start > best_span:
                best_span, best = i - run_start, (run_start, i)
            run_start = None
    win = int(0.05 * SR)
    return Sample(x, root, layer, path.stem, (best[0] * win, best[1] * win))


def detect_pitch(x: np.ndarray, fmin: float = 40.0, fmax: float = 2000.0,
                 at: float = 0.15) -> float | None:
    """Sabit bölümün temel perdesi (MIDI, kesirli); YIN fark fonksiyonu. at: ölçüm başı (sn)."""
    mono = x.mean(axis=1)
    a = min(len(mono) - 1, int(at * SR))
    seg = mono[a:a + int(0.25 * SR)]
    if len(seg) < int(0.1 * SR):
        return None
    tau_max = int(SR / fmin)
    n = len(seg) - tau_max
    if n <= 0:
        return None
    base = seg[:n]
    diff = np.array([np.sum((base - seg[t:t + n]) ** 2) for t in range(1, tau_max)])
    cum = np.cumsum(diff) / np.arange(1, len(diff) + 1)
    d = diff / (cum + 1e-12)
    lo = int(SR / fmax)
    cand = np.nonzero(d[lo:] < 0.15)[0]
    if len(cand) == 0:
        return None
    i = lo + int(cand[0])
    while i + 1 < len(d) and d[i + 1] < d[i]:
        i += 1
    if 0 < i < len(d) - 1:
        den = d[i - 1] - 2 * d[i] + d[i + 1]
        i = i + 0.5 * (d[i - 1] - d[i + 1]) / den if den != 0 else i
    freq = SR / (i + 1)
    return 69 + 12 * math.log2(freq / 440.0)


def cubic_read(x: np.ndarray, pos: np.ndarray) -> np.ndarray:
    """Kübik Hermite ara değeriyle kesirli konumlardan okuma (stereo)."""
    i = np.floor(pos).astype(np.int64)
    t = (pos - i)[:, None]
    n = len(x)
    xp = np.vstack([x[:1], x, x[-1:], x[-1:]])
    i = np.clip(i, 0, n - 1) + 1
    y0, y1, y2, y3 = xp[i - 1], xp[i], xp[i + 1], xp[i + 2]
    c1 = 0.5 * (y2 - y0)
    c2 = y0 - 2.5 * y1 + 2 * y2 - 0.5 * y3
    c3 = 0.5 * (y3 - y0) + 1.5 * (y1 - y2)
    return ((c3 * t + c2) * t + c1) * t + y1


def extend(sample: Sample, length: int) -> np.ndarray:
    """Kaydı en az length örneğe uzatır: sabit bölüm eşit güçlü çapraz geçişlerle tekrarlanır."""
    x = sample.data
    if len(x) >= length:
        return x
    a, b = sample.sustain
    if b - a < int(0.4 * SR):
        a, b = int(len(x) * 0.3), int(len(x) * 0.8)
    xf = min(int(0.12 * SR), (b - a) // 3)
    out = [x[:b]]
    total = b
    angle = np.linspace(0, math.pi / 2, xf)[:, None]
    while total < length + xf:
        seg = x[a:b].copy()
        prev = out[-1]
        mixed = prev[-xf:] * np.cos(angle) + seg[:xf] * np.sin(angle)
        out[-1] = prev[:-xf]
        out.append(mixed)
        out.append(seg[xf:])
        total += (b - a) - xf
    return np.vstack(out)


@dataclass
class Event:
    beat: float
    dur: float
    key: int | str
    vel: float = 0.8
    legato: bool = False
    bend: tuple[float, float] = (0.0, 0.0)     # (yarım ses, sn): perdeye kayarak giriş
    slide: tuple[float, float] = (0.0, 0.0)    # (yarım ses, sn): sonda kayış
    vib: tuple[float, float] = (0.0, 0.0)      # (yarım ses, Hz): eklenen titreşim
    release: float | None = None
    offset: float = 0.0                        # insan eli: zaman kayması (sn)
    swell: tuple[float, float] = (1.0, 1.0)    # nota boyunca güç: baş → son (kabarma / sönme)


@dataclass
class Instrument:
    name: str
    zones: dict[str, list[Sample]] = field(default_factory=dict)   # vurmalı: vuruş adı → kayıtlar
    samples: list[Sample] = field(default_factory=list)            # perdeli: bütün kayıtlar
    sustain: bool = False          # nefesli / yaylı: nota süresince çalar
    release: float = 0.25          # bırakma (sn)
    max_ring: float = 0.0          # telli / vurmalı: en uzun çınlama (0 = kayıt kadar)
    choke: bool = False            # yeni nota öncekini susturur (tek ses)
    gain_db: float = 0.0
    pan: float = 0.0               # −1 sol … +1 sağ
    width: float = 1.0
    eq: list[tuple] = field(default_factory=list)
    reverb: float = 0.15           # yankı gönderimi (doğrusal)
    attack: float = 0.0            # yavaş girişli kayıtlar için öne alma (sn)
    legato_skip: float = 0.07      # bağlı notada kaydın başından atlanan süre (sn)
    vel_curve: float = 1.6
    layers: int = 1
    _rr: dict = field(default_factory=dict)

    def choose(self, key: int | str, vel: float) -> tuple[Sample, float]:
        """Kayıt ve okuma hızı (perde oranı)."""
        layer = min(self.layers - 1, int(vel * self.layers * 0.999))
        if isinstance(key, str):
            pool = self.zones[key]
            pool_l = [s for s in pool if s.layer == layer] or pool
            idx = self._rr.get(key, 0)
            self._rr[key] = idx + 1
            return pool_l[idx % len(pool_l)], 1.0
        cands = [s for s in self.samples if s.layer == layer] or self.samples
        best = min(abs(s.root - key) for s in cands)
        near = [s for s in cands if abs(s.root - key) <= best + 0.3]
        # Eşitlikte aşağı kaydırma (üstteki kayıt) seçilir.
        near.sort(key=lambda s: (abs(s.root - key) - (0.01 if s.root > key else 0)))
        near = [s for s in near if abs(s.root - near[0].root) < 0.3]
        idx = self._rr.get(key, 0)
        self._rr[key] = idx + 1
        s = near[idx % len(near)]
        return s, 2 ** ((key - s.root) / 12)

    def render(self, events: list[Event], beat_sec: float, length: int,
               lead: int = 0) -> np.ndarray:
        out = np.zeros((length, 2))
        events = sorted(events, key=lambda e: e.beat)
        legato_starts = {round(e.beat, 3) for e in events if e.legato}
        for n, ev in enumerate(events):
            sample, ratio = self.choose(ev.key, ev.vel)
            start = lead + int(round((ev.beat * beat_sec + ev.offset - self.attack) * SR))
            dur = int(ev.dur * beat_sec * SR)
            release = self.release if ev.release is None else ev.release
            if self.sustain and round(ev.beat + ev.dur, 3) in legato_starts:
                release = min(release, LEGATO_RELEASE)
            if self.sustain:
                need = dur + int(release * SR)
            else:
                ring = len(sample.data) / ratio
                need = int(min(ring, self.max_ring * SR) if self.max_ring > 0 else ring)
            if self.choke and n + 1 < len(events):
                nxt = lead + int(round((events[n + 1].beat * beat_sec + events[n + 1].offset
                                        - self.attack) * SR))
                need = max(1, min(need, nxt - start + int(0.03 * SR)))
            skip = int(self.legato_skip * SR) if ev.legato else 0
            src = extend(sample, int((need + 4) * ratio) + skip + 8)
            # Perde eğrisi: giriş kayışı, sonda kayış, eklenen titreşim.
            t = np.arange(need) / SR
            semis = np.zeros(need)
            if ev.bend[0]:
                semis += ev.bend[0] * np.clip(1 - t / max(ev.bend[1], 1e-3), 0, 1) ** 2
            if ev.slide[0]:
                t0 = dur / SR - ev.slide[1]
                semis += ev.slide[0] * np.clip((t - t0) / max(ev.slide[1], 1e-3), 0, 1) ** 2
            if ev.vib[0]:
                semis += ev.vib[0] * np.sin(2 * math.pi * ev.vib[1] * t) * np.clip(t / 0.3, 0, 1)
            rate = ratio * 2 ** (semis / 12)
            pos = skip + np.concatenate([[0.0], np.cumsum(rate[:-1])])
            y = cubic_read(src, pos)
            env = np.ones(need)
            fade_in = int((0.02 if ev.legato else FADE_SEC) * SR)
            env[:fade_in] = np.linspace(0, 1, fade_in)[:need] if fade_in <= need else 1
            if self.sustain:
                r = int(release * SR)
                if 0 < dur < need:
                    tail = np.arange(need - dur)
                    env[dur:] *= 0.5 * (1 + np.cos(math.pi * np.clip(tail / max(r, 1), 0, 1)))
            else:
                fade = min(need, int((0.25 if self.max_ring > 0 else 0.03) * SR))
                if need < ring - 1 or self.choke:
                    env[need - fade:] *= np.linspace(1, 0, fade)
            if ev.swell != (1.0, 1.0):
                ramp = np.clip(np.arange(need) / max(dur, 1), 0, 1)
                env *= ev.swell[0] + (ev.swell[1] - ev.swell[0]) * ramp ** 1.5
            gain = 10 ** (self.gain_db / 20) * max(ev.vel, 0.01) ** self.vel_curve
            y *= (env * gain)[:, None]
            a, b = max(0, start), min(length, start + need)
            if b > a:
                out[a:b] += y[a - start:b - start]
        return out


# --- Eşitleme (FFT, sıfır fazlı) ---

def eq_curve(freqs: np.ndarray, bands: list[tuple]) -> np.ndarray:
    """Bantlar: ('hp', f, derece) ('lp', f, derece) ('ls'|'hs', f, dB) ('pk', f, dB, oktav)."""
    f = np.maximum(freqs, 1.0)
    h = np.ones_like(f)
    for band in bands:
        kind = band[0]
        if kind == "hp":
            h /= np.sqrt(1 + (band[1] / f) ** (2 * band[2]))
        elif kind == "lp":
            h /= np.sqrt(1 + (f / band[1]) ** (2 * band[2]))
        elif kind in ("ls", "hs"):
            x = np.log2(f / band[1])
            s = 0.5 * (1 + np.tanh(2.5 * x))
            g = band[2] * (1 - s if kind == "ls" else s)
            h *= 10 ** (g / 20)
        elif kind == "pk":
            x = np.log2(f / band[1]) / (band[3] / 2)
            h *= 10 ** (band[2] * np.exp(-0.5 * (2 * x) ** 2) / 20)
    return h


def apply_eq(x: np.ndarray, bands: list[tuple]) -> np.ndarray:
    """Döngüsel (dikişsiz) FFT eşitlemesi."""
    if not bands:
        return x
    spec = np.fft.rfft(x, axis=0)
    spec *= eq_curve(np.fft.rfftfreq(len(x), 1 / SR), bands)[:, None]
    return np.fft.irfft(spec, n=len(x), axis=0)


def place(x: np.ndarray, pan: float, width: float) -> np.ndarray:
    mid = (x[:, 0] + x[:, 1]) * 0.5
    side = (x[:, 0] - x[:, 1]) * 0.5 * width
    left, right = mid + side, mid - side
    angle = (pan + 1) * math.pi / 4
    return np.stack([left * math.cos(angle), right * math.sin(angle)], axis=1) * math.sqrt(2)


# --- Yankı ---

def make_ir(rt60: float, length: float, predelay: float, seed: int,
            damp_hz: float = 4500.0, low_cut: float = 180.0) -> np.ndarray:
    """Yapay salon yankısı: oktav bantlarında farklı sönen gürültü + erken yansımalar."""
    rng = np.random.default_rng(seed)
    n = int(length * SR)
    noise = rng.standard_normal((n, 2))
    spec = np.fft.rfft(noise, axis=0)
    freqs = np.fft.rfftfreq(n, 1 / SR)
    t = np.arange(n) / SR
    out = np.zeros((n, 2))
    edges = [0, 250, 500, 1000, 2000, 4000, 8000, SR / 2]
    for lo, hi in zip(edges[:-1], edges[1:]):
        band = spec * ((freqs >= lo) & (freqs < hi))[:, None]
        mid = math.sqrt(max(lo, 60) * hi)
        rt = rt60 / (1 + (mid / damp_hz) ** 1.3)
        out += np.fft.irfft(band, n=n, axis=0) * np.exp(-6.91 * t / rt)[:, None]
    fade = np.clip(t / 0.03, 0, 1) ** 2
    out *= fade[:, None]
    for k in range(8):
        tap = int((0.008 + 0.006 * k + rng.uniform(0, 0.004)) * SR)
        out[tap, k % 2] += 0.5 * 0.82 ** k
    pre = int(predelay * SR)
    out = np.vstack([np.zeros((pre, 2)), out])[:n]
    out = apply_eq(out, [("hp", low_cut, 2)])
    return out / np.sqrt(np.sum(out ** 2) / 2)


def circular_convolve(x: np.ndarray, ir: np.ndarray) -> np.ndarray:
    n = len(x)
    if len(ir) > n:
        ir = ir[:n]
    xs = np.fft.rfft(x, axis=0)
    hs = np.fft.rfft(np.vstack([ir, np.zeros((n - len(ir), 2))]), axis=0)
    return np.fft.irfft(xs * hs, n=n, axis=0)


# --- Dinamik ---

def _block_env(x: np.ndarray, block: int) -> np.ndarray:
    n = len(x) // block
    return x[:n * block].reshape(n, block, 2)


def compress(x: np.ndarray, threshold_db: float, ratio: float, attack: float,
             release: float, block: int = 64) -> np.ndarray:
    """RMS sıkıştırıcı (stereo bağlı). Döngü için zarf sondan ısınarak başlar."""
    blocks = _block_env(np.vstack([x[-int(2 * SR):], x]), block)
    level = 10 * np.log10(np.mean(blocks ** 2, axis=(1, 2)) + 1e-12)
    over = np.maximum(0.0, level - threshold_db)
    target = -over * (1 - 1 / ratio)
    a = math.exp(-block / (attack * SR))
    r = math.exp(-block / (release * SR))
    gain = np.empty_like(target)
    g = 0.0
    for i, tgt in enumerate(target):
        coef = a if tgt < g else r
        g = coef * g + (1 - coef) * tgt
        gain[i] = g
    lin = np.repeat(10 ** (gain / 20), block)
    lin = np.concatenate([lin, np.full(len(x) + int(2 * SR) - len(lin), lin[-1])])
    return x * lin[int(2 * SR):][:, None]


def limit(x: np.ndarray, ceiling_db: float, release: float = 0.08,
          block: int = 32) -> np.ndarray:
    """Önden bakan tepe sınırlayıcı: kazanç tepeden önce iner, yavaşça açılır."""
    ceiling = 10 ** (ceiling_db / 20)
    n = int(math.ceil(len(x) / block))
    padded = np.vstack([x, np.zeros((n * block - len(x), 2))])
    peaks = np.abs(padded).reshape(n, block, 2).max(axis=(1, 2))
    need = np.minimum(1.0, ceiling / np.maximum(peaks, 1e-9))
    look = np.minimum.reduce([need, np.roll(need, -1), np.roll(need, -2), np.roll(need, 1)])
    r = math.exp(-block / (release * SR))
    gain = np.empty_like(look)
    g = 1.0
    for _ in range(2):  # döngüsel: ikinci geçiş başı sonun durumuyla başlatır
        for i, v in enumerate(look):
            g = v if v < g else r * g + (1 - r) * v
            gain[i] = g
    lin = np.interp(np.arange(n * block), np.arange(n) * block + block / 2, gain)
    return np.clip(padded * lin[:, None], -ceiling, ceiling)[:len(x)]


# --- Parça ---

@dataclass
class Mix:
    instruments: dict[str, Instrument]
    reverb_ir: np.ndarray
    master_eq: list[tuple] = field(default_factory=list)


def render(mix: Mix, events: dict[str, list[Event]], bpm: float, beats: int) -> np.ndarray:
    """Döngüsel stereo parça (tam beats vuruş)."""
    beat_sec = 60.0 / bpm
    loop = int(round(beats * beat_sec * SR))
    lead = int(LEAD_SEC * SR)
    length = lead + loop + int(TAIL_SEC * SR)
    dry = np.zeros((loop, 2))
    send = np.zeros((loop, 2))
    for name, evs in events.items():
        inst = mix.instruments[name]
        stem = inst.render(evs, beat_sec, length, lead)
        # Döngüsel katlama: sondan taşan ses başa, baştan önce başlayan ses sona.
        wrapped = stem[lead:lead + loop].copy()
        tail = stem[lead + loop:]
        wrapped[:len(tail)] += tail
        wrapped[loop - lead:] += stem[:lead]
        wrapped = apply_eq(wrapped, inst.eq)
        wrapped = place(wrapped, inst.pan, inst.width)
        dry += wrapped
        send += wrapped * inst.reverb
    wet = circular_convolve(send, mix.reverb_ir)
    return apply_eq(dry + wet, mix.master_eq)


# Ana çıkış: dosyanın ortalama düzeyi (dBFS) ve tepe tavanı. Oyundaki düzey volume_db ile
# ayarlandığı için dosya, vurmalı tepeleri sınırlayıcıya az iş bırakacak kadar alçak tutulur.
MASTER_RMS_DB = -18.0
CEILING_DB = -1.5


def master(x: np.ndarray, ceiling_db: float = CEILING_DB) -> np.ndarray:
    y = compress(x, threshold_db=-22.0, ratio=1.8, attack=0.03, release=0.25)
    rms = 20 * math.log10(math.sqrt(np.mean(y ** 2)) + 1e-12)
    y *= 10 ** ((MASTER_RMS_DB - rms) / 20)
    return limit(y, ceiling_db)
