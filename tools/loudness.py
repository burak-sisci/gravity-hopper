"""Ses yüksekliği ölçümü (M5-10, ITU-R BS.1770-4 / EBU R128; architecture.md §8.8).

  integrated_lufs(x, sr): K ağırlıklı, kapılı tümleşik ses yüksekliği (LUFS). K süzgeci frekans
      alanında uygulanır (sayısal biquad'ların tam yanıtı FFT kutularında); parça döngü olduğu
      için dairesel süzme doğrudur. 400 ms bloklar, %75 örtüşme, mutlak kapı -70 LUFS, göreli
      kapı -10 LU.
  true_peak_db(x, sr): 4 kat aşırı örneklemeyle gerçek tepe (dBTP); FFT ile parça parça.

Kendi kendini sınar: python -I tools/loudness.py --selftest (997 Hz, 0 dBFS tepe, iki kanal
≈ 0,0 LUFS; tek kanal ≈ -3,0 LUFS; örnekler arasına düşen tepe dBTP'de görünür).
Bağımlılık: numpy, soundfile (geliştirme ortamı).
"""
import math
import sys

import numpy as np

BLOCK_SEC = 0.4
OVERLAP = 0.75
ABS_GATE = -70.0
REL_GATE = -10.0
OVERSAMPLE = 4
TP_CHUNK = 1 << 16
TP_PAD = 1 << 10


# Katsayılar her örnekleme hızı için analog ön örnekten (B. De Man'ın türetmesi); 48 kHz'te
# ITU-R BS.1770-4 tablosunu verir.
def _shelf(sr: float) -> tuple[np.ndarray, np.ndarray]:
    gain_db, q, fc = 3.999843853973347, 0.7071752369554196, 1681.974450955533
    k = math.tan(math.pi * fc / sr)
    vh = 10 ** (gain_db / 20)
    vb = vh ** 0.4996667741545416
    a0 = 1 + k / q + k * k
    return (np.array([(vh + vb * k / q + k * k) / a0, 2 * (k * k - vh) / a0,
                      (vh - vb * k / q + k * k) / a0]),
            np.array([1.0, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0]))


def _highpass(sr: float) -> tuple[np.ndarray, np.ndarray]:
    q, fc = 0.5003270373238773, 38.13547087602444
    k = math.tan(math.pi * fc / sr)
    a0 = 1 + k / q + k * k
    return (np.array([1.0, -2.0, 1.0]),
            np.array([1.0, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0]))


def _response(b: np.ndarray, a: np.ndarray, w: np.ndarray) -> np.ndarray:
    z = np.exp(-1j * w)
    return (b[0] + b[1] * z + b[2] * z * z) / (a[0] + a[1] * z + a[2] * z * z)


def k_weight(x: np.ndarray, sr: int) -> np.ndarray:
    """x: (örnek, kanal)."""
    w = 2 * math.pi * np.fft.rfftfreq(len(x), 1 / sr) / sr
    h = _response(*_shelf(sr), w) * _response(*_highpass(sr), w)
    return np.fft.irfft(np.fft.rfft(x, axis=0) * h[:, None], n=len(x), axis=0)


def integrated_lufs(x: np.ndarray, sr: int) -> float:
    x = np.atleast_2d(x.T).T if x.ndim == 1 else x
    y = k_weight(x, sr)
    block = int(BLOCK_SEC * sr)
    step = int(block * (1 - OVERLAP))
    count = max(1, 1 + (len(y) - block) // step)
    power = np.cumsum(np.concatenate([np.zeros((1, y.shape[1])), y ** 2]), axis=0)
    starts = np.arange(count) * step
    z = (power[starts + block] - power[starts]) / block
    loud = -0.691 + 10 * np.log10(z.sum(axis=1) + 1e-20)
    kept = loud > ABS_GATE
    if not kept.any():
        return -math.inf
    relative = -0.691 + 10 * math.log10(z[kept].sum(axis=1).mean()) + REL_GATE
    kept &= loud > relative
    return -0.691 + 10 * math.log10(z[kept].sum(axis=1).mean())


def true_peak_db(x: np.ndarray) -> float:
    x = np.atleast_2d(x.T).T if x.ndim == 1 else x
    peak = float(np.abs(x).max())
    for start in range(0, len(x), TP_CHUNK):
        a = max(0, start - TP_PAD)
        b = min(len(x), start + TP_CHUNK + TP_PAD)
        seg = x[a:b]
        n = len(seg)
        spec = np.fft.rfft(seg, axis=0)
        up = np.fft.irfft(spec, n=n * OVERSAMPLE, axis=0) * OVERSAMPLE
        lo = (start - a) * OVERSAMPLE
        hi = lo + min(TP_CHUNK, len(x) - start) * OVERSAMPLE
        peak = max(peak, float(np.abs(up[lo:hi]).max()))
    return 20 * math.log10(peak + 1e-20)


def _selftest() -> None:
    sr = 48000
    t = np.arange(sr * 10) / sr
    sine = np.sin(2 * math.pi * 997 * t)
    both = integrated_lufs(np.stack([sine, sine], axis=1), sr)
    left = integrated_lufs(np.stack([sine, np.zeros_like(sine)], axis=1), sr)
    # sr/4'te 45° kaymış sinüs: örnekler ±0,707'de, gerçek tepe 1,0 (0 dBTP; örnek tepe -3 dB).
    quarter = np.sin(2 * math.pi * (sr / 4) * np.arange(4096) / sr + math.pi / 4) * 0.999
    tp = true_peak_db(np.stack([quarter, quarter], axis=1))
    sample = 20 * math.log10(float(np.abs(quarter).max()))
    print(f"iki kanal {both:+.2f} LUFS (beklenen 0,00) | tek kanal {left:+.2f} (-3,01) | "
          f"gerçek tepe {tp:+.2f} dBTP, örnek tepe {sample:+.2f}")
    ok = abs(both) < 0.05 and abs(left + 3.01) < 0.05 and tp > -0.2 and sample < -2.9
    print("SELFTEST", "TAMAM" if ok else "BOZUK")
    if not ok:
        raise SystemExit(1)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    if "--selftest" in sys.argv:
        _selftest()
