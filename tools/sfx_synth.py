"""Özgün ses efektlerini kodla üreten araç (M4-13, architecture.md §8.8, ADR-081).

Kenney paketlerinde karşılığı olmayan büyük anların sesini sıfırdan sentezler; örnek ses ya da
başkasının kaydı kullanılmaz (projenin özgün eseri). Şimdilik tek ses var:
  finale: Büyük Depolama Birimi'ne varış (Events.great_storage_reached). Alçak bir vuruş, açık
     beşlilerle (D–A) hızla yükselen arpej, yavaş açılan bir akor yüzeyi ve seyrelen pırıltılar.
     Üçlü yoktur: majör/minör renk vermez, D Hicaz ve D Dorian parçalarıyla çakışmaz.

Her ses:
  1. assets/audio/sfx/<olay>.ogg olarak yazılır (OGG Vorbis; dosyanın tepesi FILE_PEAK_DB).
  2. Düzeyi sfx_prep'in kuralıyla müziğe göre ayarlanır (telefon bandı, 50 ms RMS, katman farkı,
     tepe -1 dBFS sınırı) ve data/audio/sfx_bank.tres'e eklenir ya da güncellenir. Ölçüm
     kodlanmış dosyadan yeniden okunarak yapılır.

Olay numarası GameTypes.Sfx'teki sırasıdır: önce sfx_prep.SOUNDS (Kenney), sonra SYNTH.
sfx_prep bankayı baştan yazar; ondan sonra bu araç yeniden çalıştırılır.
Rastgelelik sabit tohumludur: araç her çalışmada aynı sesi üretir.

Kullanım (proje dışındaki geliştirme ortamı; numpy 2.5.4, soundfile 0.14.0):
  python tools/sfx_synth.py
"""
import math
import re
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
import sfx_prep  # noqa: E402  (aynı klasördeki araç; -I ile çalışınca yol elle eklenir)

SR = 44100
FILE_PEAK_DB = -3.0
SEED = 4013
CREDIT = {"author": "Claude (Anthropic), Gravity Hopper için", "license": "Özgün (projenin)",
          "source_url": "tools/sfx_synth.py"}

D4, A4, D5, A5, D6, A6, D7, A7, D8 = (293.66, 440.0, 587.33, 880.0, 1174.66, 1760.0, 2349.32,
                                      3520.0, 4698.64)


def tone(freq: float, t: np.ndarray, harmonics: int, rolloff: float, cents: float) -> np.ndarray:
    """İki hafif akort farklı sesin toplamı (koro); üst harmonikler 1/n^rolloff zayıflar."""
    out = np.zeros_like(t)
    for detune in (-cents, cents):
        f = freq * 2 ** (detune / 1200)
        for n in range(1, harmonics + 1):
            if f * n < SR / 2:
                out += np.sin(2 * math.pi * f * n * t) / n ** rolloff
    return out / 2


def envelope(t: np.ndarray, attack: float, decay: float) -> np.ndarray:
    return np.minimum(t / attack, 1.0) * np.exp(-np.maximum(t - attack, 0.0) / decay)


def place(out: np.ndarray, start: float, sound: np.ndarray) -> None:
    i = int(start * SR)
    n = min(len(sound), len(out) - i)
    out[i:i + n] += sound[:n]


def finale() -> np.ndarray:
    length = 3.0
    out = np.zeros(int(length * SR))
    rng = np.random.default_rng(SEED)
    # Alçak vuruş: 110 → 45 Hz inen sinüs ve kısa bir tık.
    t = np.arange(int(0.6 * SR)) / SR
    phase = 2 * math.pi * np.cumsum(45 + 65 * np.exp(-t / 0.08)) / SR
    boom = np.sin(phase) * np.exp(-t / 0.22) * 0.75
    click = rng.standard_normal(int(0.006 * SR)) * np.linspace(1, 0, int(0.006 * SR)) * 0.25
    boom[:len(click)] += click
    place(out, 0.0, boom)
    # Arpej: açık beşlilerle iki oktav yukarı.
    t = np.arange(int(1.4 * SR)) / SR
    for i, freq in enumerate((D5, A5, D6, A6, D7)):
        place(out, 0.02 + i * 0.065, tone(freq, t, 6, 1.6, 5) * envelope(t, 0.004, 0.45) * 0.22)
    # Akor yüzeyi: yavaş açılır, sonra söner.
    t = np.arange(int(length * SR)) / SR
    pad = sum(tone(f, t, 4, 1.2, 8) for f in (D4, A4, D5, A5))
    swell = np.minimum(t / 0.3, 1.0) * np.exp(-np.maximum(t - 0.5, 0.0) / 0.8)
    place(out, 0.0, pad * swell * 0.1)
    # Pırıltılar: yüksek D ve A'lar; zamanla seyrelir.
    t = np.arange(int(0.3 * SR)) / SR
    for _ in range(36):
        start = 0.1 + 1.9 * rng.random() ** 1.8
        freq = rng.choice((D7, A7, D8))
        place(out, start, np.sin(2 * math.pi * freq * t) * np.exp(-t / 0.07)
              * rng.uniform(0.03, 0.08) * (1.2 - start / 2.5))
    # Son 0,4 sn yumuşak kapanış.
    fade = int(0.4 * SR)
    out[-fade:] *= np.cos(np.linspace(0, math.pi / 2, fade))
    return out * 10 ** (FILE_PEAK_DB / 20) / float(np.max(np.abs(out)))


# Sıra GameTypes.Sfx ile aynı: sfx_prep.SOUNDS'tan sonra gelir.
SYNTH = [
    {"id": "finale", "render": finale, "tier": "moment", "jitter": 0.0,
     "title": "Büyük Depolama Birimi finali"},
]


def write(sound: dict) -> Path:
    path = sfx_prep.AUDIO_DIR / (sound["id"] + ".ogg")
    samples = sound["render"]().astype(np.float32)
    with sf.SoundFile(str(path), "w", SR, 1, format="OGG", subtype="VORBIS",
                      compression_level=sfx_prep.OGG_COMPRESSION) as f:
        # libsndfile'in Vorbis kodlayıcısı büyük tek yazımda çöküyor (architecture.md §8.3).
        for start in range(0, len(samples), sfx_prep.WRITE_BLOCK):
            f.write(samples[start:start + sfx_prep.WRITE_BLOCK])
    return path


def measure(sound: dict, path: Path, reference: float) -> dict:
    x, sr = sfx_prep.load_mono(path)
    level = float(sfx_prep.short_term_db(sfx_prep.phone_band(x, sr), sr).max())
    peak = 20 * math.log10(float(np.max(np.abs(x))) + 1e-12)
    wanted = reference + sfx_prep.TIERS[sound["tier"]] - level
    gain = min(wanted, sfx_prep.PEAK_LIMIT_DB - peak)
    gain = max(sfx_prep.MIN_GAIN_DB, min(sfx_prep.MAX_GAIN_DB, gain))
    return dict(sound, length=len(x) / sr, level=level, peak=peak, gain=round(gain, 1),
                limited=gain < wanted - 0.05)


def update_bank(info: dict, event: int) -> None:
    """Bankadaki sesi ekler ya da günceller (sfx_prep'in yazdığı biçimde)."""
    text = sfx_prep.BANK_PATH.read_text(encoding="utf-8")
    sid = info["id"]
    block = "\n".join([
        f'[sub_resource type="Resource" id="Resource_{sid}"]',
        'script = ExtResource("2_sound")',
        f"event = {event}",
        f'stream = ExtResource("{event + 3}_{sid}")',
        f'volume_db = {info["gain"]:.1f}',
        f'pitch_jitter = {info["jitter"]:.2f}',
        f'title = "{info["title"]}"',
        f'author = "{CREDIT["author"]}"',
        f'license = "{CREDIT["license"]}"',
        f'source_url = "{CREDIT["source_url"]}"'])
    existing = re.compile(rf'\[sub_resource type="Resource" id="Resource_{sid}"\]\n(?:.+\n)+?'
                          r'source_url = .*')
    if existing.search(text):
        text = existing.sub(lambda _: block, text)
    else:
        ext = (f'[ext_resource type="AudioStream" path="res://assets/audio/sfx/{sid}.ogg" '
               f'id="{event + 3}_{sid}"]')
        last_ext = list(re.finditer(r"^\[ext_resource .*\]$", text, re.M))[-1]
        text = text[:last_ext.end()] + "\n" + ext + text[last_ext.end():]
        text = text.replace("\n[resource]", f"\n{block}\n\n[resource]", 1)
        text, count = re.subn(r"(sounds = Array\[ExtResource\(\"2_sound\"\)\]\(\[.*)\]\)$",
                              rf'\1, SubResource("Resource_{sid}")])', text, flags=re.M)
        if count != 1:
            raise SystemExit("sfx_bank.tres: sounds satırı bulunamadı")
    sfx_prep.BANK_PATH.write_text(text, encoding="utf-8", newline="\n")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    reference = sfx_prep.music_reference()
    print("müzik (telefon bandı, ortanca kısa süreli düzey): %.1f dBFS" % reference)
    for i, sound in enumerate(SYNTH):
        info = measure(sound, write(sound), reference)
        update_bank(info, len(sfx_prep.SOUNDS) + i)
        heard = info["level"] + info["gain"]
        print("%-13s %4.2f sn | düzey %6.1f tepe %5.1f | kazanç %+5.1f dB → %6.1f "
              "(müzikten %+.1f, hedef %+.1f)%s"
              % (info["id"], info["length"], info["level"], info["peak"], info["gain"], heard,
                 heard - reference, sfx_prep.TIERS[info["tier"]],
                 " | tepe sınırı" if info["limited"] else ""))


if __name__ == "__main__":
    main()
