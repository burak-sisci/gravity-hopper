"""Ses düzeyi denetimi (M5-10, architecture.md §8.8): check.ps1'in 6. adımı.

Oyuna giren her sesi, oyunda çalındığı düzeyde (dosya + kaynaktaki volume_db) ölçer:
  1) Ölçerin kendisi: tools/loudness.py --selftest (bilinen sinüslerde LUFS ve dBTP).
  2) Müzik (data/music/*.tres; tur parçaları ve menü parçası): tümleşik ses yüksekliği tur
     parçalarının ortalamasından en çok ±1 LU uzakta; gerçek tepe ≤ -1 dBTP.
  3) Efektler (data/audio/sfx_bank.tres): M3-15 düzey kuralı. Her efektin telefon bandındaki en
     yüksek kısa süreli düzeyi, tur müziğinin ortanca düzeyinin katman farkı kadar üstünde
     (sık -3, ödül +3, an +6 dB; ±0,2 dB yuvarlama payı). Daha sessiz kalabilmesinin tek yolu
     tepe sınırıdır: o zaman tepesi -1 dBFS'e dayanmıştır. Hiçbir efektin tepesi -1 dBFS'i aşmaz.
Çıktı: her satır ölçü; sonda "SES TAMAM" ya da "SES SORUNLU" (çıkış kodu 1).
Kullanım: python -I tools/audio_check.py
"""
import math
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import numpy as np  # noqa: E402
import soundfile as sf  # noqa: E402

import loudness  # noqa: E402
import sfx_prep  # noqa: E402
import sfx_synth  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
MUSIC_DATA = ROOT / "data" / "music"
CATALOG = MUSIC_DATA / "music_catalog.tres"
BANK = ROOT / "data" / "audio" / "sfx_bank.tres"

## Parçalar arası en büyük fark (LU) ve en yüksek gerçek tepe (dBTP): M5-10 kabulü.
MAX_LU_FROM_MEAN = 1.0
MAX_TRUE_PEAK_DB = -1.0
## Efekt düzeyinde yuvarlama payı (volume_db 0,1 dB'e yuvarlanır; OGG kodlaması).
LEVEL_TOLERANCE_DB = 0.2


def res_path(text: str) -> Path:
    return ROOT / text.replace("res://", "")


def music_tracks() -> list[tuple[str, Path, float, bool]]:
    catalog = CATALOG.read_text(encoding="utf-8")
    tracks = []
    for res in sorted(MUSIC_DATA.glob("*.tres")):
        text = res.read_text(encoding="utf-8")
        if 'script_class="MusicTrack"' not in text:
            continue
        stream = re.search(r'type="AudioStream" path="([^"]+)"', text)[1]
        volume = float(re.search(r"^volume_db = (-?[\d.]+)$", text, re.M)[1])
        in_run = f'path="res://data/music/{res.name}"' in catalog
        tracks.append((res.stem, res_path(stream), volume, in_run))
    return tracks


def check_music() -> list[str]:
    problems = []
    rows = []
    for name, path, volume, in_run in music_tracks():
        x, sr = sf.read(str(path), always_2d=True)
        lufs = loudness.integrated_lufs(x, sr) + volume
        peak = loudness.true_peak_db(x) + volume
        rows.append((name, lufs, peak, in_run))
    run = [r[1] for r in rows if r[3]]
    if not run:
        return ["müzik: tur kataloğunda parça yok"]
    mean = float(np.mean(run))
    for name, lufs, peak, in_run in rows:
        role = "tur" if in_run else "menü"
        print(f"müzik {name:9} ({role}) {lufs:6.2f} LUFS ({lufs - mean:+.2f} LU) | "
              f"gerçek tepe {peak:6.2f} dBTP")
        if abs(lufs - mean) > MAX_LU_FROM_MEAN:
            problems.append(f"müzik {name}: ortalamadan {lufs - mean:+.2f} LU (sınır ±1)")
        if peak > MAX_TRUE_PEAK_DB:
            problems.append(f"müzik {name}: gerçek tepe {peak:.2f} dBTP (sınır -1)")
    return problems


def bank_sounds() -> list[tuple[str, float]]:
    text = BANK.read_text(encoding="utf-8")
    streams = dict(re.findall(r'path="res://assets/audio/sfx/([a-z_]+)\.ogg" id="([^"]+)"', text))
    by_id = {v: k for k, v in streams.items()}
    sounds = []
    for block in text.split("[sub_resource")[1:]:
        stream = re.search(r'stream = ExtResource\("([^"]+)"\)', block)
        volume = re.search(r"^volume_db = (-?[\d.]+)$", block, re.M)
        if stream and volume:
            sounds.append((by_id[stream[1]], float(volume[1])))
    return sounds


def check_sfx() -> list[str]:
    problems = []
    tiers = {s["id"]: s["tier"] for s in sfx_prep.SOUNDS + sfx_synth.SYNTH}
    reference = sfx_prep.music_reference()
    print(f"efekt başvurusu (tur müziği, telefon bandı ortancası): {reference:.2f} dBFS")
    for sound_id, volume in bank_sounds():
        if sound_id not in tiers:
            problems.append(f"efekt {sound_id}: katmanı yok (sfx_prep.SOUNDS / sfx_synth.SYNTH)")
            continue
        x, sr = sfx_prep.load_mono(sfx_prep.AUDIO_DIR / f"{sound_id}.ogg")
        level = float(sfx_prep.short_term_db(sfx_prep.phone_band(x, sr), sr).max()) + volume
        peak = 20 * math.log10(float(np.max(np.abs(x))) + 1e-12) + volume
        target = reference + sfx_prep.TIERS[tiers[sound_id]]
        limited = peak >= sfx_prep.PEAK_LIMIT_DB - LEVEL_TOLERANCE_DB
        print(f"efekt {sound_id:12} {tiers[sound_id]:8} {level - reference:+6.2f} dB "
              f"(hedef {target - reference:+.1f}) | tepe {peak:6.2f} dBFS"
              + (" | tepe sınırında" if limited else ""))
        if peak > sfx_prep.PEAK_LIMIT_DB + 0.05:
            problems.append(f"efekt {sound_id}: tepe {peak:.2f} dBFS (sınır -1)")
        if level > target + LEVEL_TOLERANCE_DB:
            problems.append(f"efekt {sound_id}: hedefin {level - target:+.2f} dB üstünde")
        elif level < target - LEVEL_TOLERANCE_DB and not limited:
            problems.append(f"efekt {sound_id}: hedefin {level - target:+.2f} dB altında "
                            "(tepe sınırında değil)")
    return problems


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    loudness._selftest()
    problems = check_music() + check_sfx()
    for problem in problems:
        print("SORUN", problem)
    print("SES TAMAM" if not problems else "SES SORUNLU")
    if problems:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
