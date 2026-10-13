"""Müzik hazırlama aracı (M2-20, architecture.md §8.3, ADR-040).

Kaynak parçaları oyuna hazırlar:
  1. Başı ilk vuruşa kadar kırpar: oyunun vuruş ızgarası parçanın 0. saniyesinde başlar.
  2. Döngüyü tam ölçü sınırlarında seçer. Döngü olarak yayımlanan parçalarda döngü bütün
     parçadır, diğerlerinde müziğin kendini en çok tekrar ettiği ölçü çifti aranır.
  3. Döngü dikişini yumuşatır: döngü başı 0 değilse son 30 ms döngü başından önceki sese
     karışır, bütün parça döngüyse sondan taşan yankı başa eklenir.
  4. OGG Vorbis yazar (assets/audio/music/<id>.ogg) ve data/music/<id>.tres (MusicTrack) ile
     data/music/music_catalog.tres dosyalarını üretir. Ses düzeyi dosyaya işlenmez,
     volume_db alanına yazılır.

Tempo kaynağın sayfasındaki ya da kulakla doğrulanan değerdir (TRACKS). Araç yalnızca ilk vuruşun
yerini (faz) ölçer: vuruş başlangıçlarının spektral akısı üzerinde tarak araması. Ölçümün
gecikmesi her çalıştırmada yapay bir tık dizisiyle ayarlanır.

Kullanım (proje dışındaki geliştirme ortamı; numpy 2.5.4, soundfile 0.14.0):
  python tools/music_prep.py <kaynak klasörü>
Kaynak dosyalar depoya girmez; indirme bağlantıları TRACKS'te.
"""

import math
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parent.parent
AUDIO_DIR = ROOT / "assets" / "audio" / "music"
DATA_DIR = ROOT / "data" / "music"

TRACKS = [
    {"id": "epic_journey", "file": "epic_journey_0.mp3", "bpm": 100.0, "loop": "search",
     "title": "Epic Journey", "author": "Thor Arisland (tcarisland)", "license": "CC-BY 4.0",
     "url": "https://opengameart.org/content/epic-journey"},
    {"id": "mountain_peak", "file": "mountain_peak_0.mp3", "bpm": 100.0, "loop": "search",
     "title": "Mountain Peak", "author": "Thor Arisland (tcarisland)", "license": "CC-BY 4.0",
     "url": "https://opengameart.org/content/mountain-peak"},
    {"id": "treasure_hunter", "file": "treasure_hunter_0.mp3", "bpm": 90.0, "loop": "whole",
     "title": "Treasure Hunter", "author": "TAD", "license": "CC0 1.0",
     "url": "https://opengameart.org/content/treasure-hunter"},
    {"id": "epic_departure",
     "file": "Of Far Different Nature - Scene - Epic Departure (CC-BY)_2.mp3",
     "bpm": 120.0, "loop": "search",
     "title": "Epic Departure", "author": "Of Far Different Nature", "license": "CC-BY 4.0",
     "url": "https://opengameart.org/content/epic-departure"},
    {"id": "determined_pursuit", "file": "determined_pursuit_loop.wav", "bpm": 80.0,
     "loop": "whole", "title": "Determined Pursuit", "author": "Emma_MA", "license": "CC0 1.0",
     "url": "https://opengameart.org/content/determined-pursuit-epic-orchestra-loop"},
]

HOP = 512
NFFT = 2048
BEATS_PER_BAR = 4
# Döngü araması: dikişten sonraki 2 ölçü ve önceki 1 ölçü karşılaştırılır.
AFTER_BEATS = 8
BEFORE_BEATS = 4
MIN_LOOP_SHARE = 0.5
MAX_START_SHARE = 0.45
SEAM_SECONDS = 0.03
# İlk vuruş dosyanın bu kadar öncesine düşüyorsa başa sessizlik eklenir (kırpılmaz).
LEAD_IN_SECONDS = 0.05
# Döngü olarak yapılmış parçanın süresi tam ölçüden en çok bu kadar sapabilir (sn).
WHOLE_TOLERANCE = 0.02
# İlk vuruş araması adımı (sn).
COMB_STEP = 0.001
FADE_IN = 88
TAIL_SECONDS = 2.0
# Sessizliğe inen son: kısa süreli ses düzeyi parçanın ortancasından bu kadar düşükse içerik bitti.
END_DROP_DB = 15.0
# Parçalar arasında eşit duyulan ses düzeyi (döngü bölgesinin RMS'i); yükseltme yapılmaz.
TARGET_RMS_DB = -18.0
OGG_COMPRESSION = 0.4
WRITE_BLOCK = 4096
BANDS = 24


def onset_env(x: np.ndarray, sr: int) -> np.ndarray:
    win = np.hanning(NFFT)
    frames = 1 + (len(x) - NFFT) // HOP
    env = np.zeros(frames - 1)
    prev = None
    chunk = 2048
    for start in range(0, frames, chunk):
        idx = np.arange(NFFT)[None, :] + HOP * np.arange(start, min(frames, start + chunk))[:, None]
        logm = np.log1p(100 * np.abs(np.fft.rfft(x[idx] * win, axis=1)))
        if prev is not None:
            logm = np.vstack([prev, logm])
            offset = start - 1
        else:
            offset = 0
        flux = np.maximum(np.diff(logm, axis=0), 0).sum(axis=1)
        env[offset:offset + len(flux)] = flux
        prev = logm[-1:]
    env -= np.convolve(env, np.ones(16) / 16, mode="same")
    return np.maximum(env, 0)


def calibrate(sr: int, bpm: float) -> float:
    """Ölçümün sistematik kayması: bilinen anlarda tıklarla dolu yapay bir kayıtta ölçülür."""
    beat = 60.0 / bpm
    true_first = 0.2 * beat
    x = np.zeros(int(30 * sr))
    click = np.exp(-np.arange(int(0.01 * sr)) / (0.002 * sr))
    rng = np.random.default_rng(1)
    t = true_first
    while t < 29.5:
        i = int(t * sr)
        x[i:i + len(click)] += click * rng.standard_normal(len(click))
        t += beat
    measured = comb_peak(onset_env(x, sr), sr, beat)
    return ((measured - true_first + beat / 2) % beat) - beat / 2


def comb_score(env: np.ndarray, sr: int, first: float, beat: float) -> float:
    """İlk vuruş first iken bütün vuruş anlarındaki vuruş başlangıcı gücü (ara kareler doğrusal)."""
    times = first + np.arange(int(len(env) * HOP / sr / beat) - 1) * beat
    pos = times * sr / HOP
    pos = pos[pos < len(env) - 1]
    return float(np.sum(np.interp(pos, np.arange(len(env)), env)))


def comb_peak(env: np.ndarray, sr: int, beat: float) -> float:
    """Vuruş ızgarasının vuruş başlangıcı tepeleriyle en çok örtüştüğü kayma (sn, [0, vuruş))."""
    smooth = np.convolve(env, np.hanning(3) / 2, mode="same")
    offsets = np.arange(0.0, beat, COMB_STEP)
    scores = [comb_score(smooth, sr, c, beat) for c in offsets]
    return float(offsets[int(np.argmax(scores))])


def measure_first(mono: np.ndarray, sr: int, bpm: float) -> float:
    """İlk vuruşun anı (sn, [0, vuruş)): tarak araması (1 ms adım) eksi ölçüm gecikmesi.
    Ortalamaya dayalı faz, ritim deseni bakışımsızken (vurgulu ara sekizlikler) 50 ms'ye kadar
    yanılıyordu."""
    beat = 60.0 / bpm
    return (comb_peak(onset_env(mono, sr), sr, beat) - calibrate(sr, bpm)) % beat


def is_whole_bars(duration: float, beat: float) -> bool:
    bars = duration / (beat * BEATS_PER_BAR)
    return abs(bars - round(bars)) * beat * BEATS_PER_BAR < WHOLE_TOLERANCE


def content_end(x: np.ndarray, sr: int) -> float:
    win = int(0.5 * sr)
    n = len(x) // win
    rms = np.sqrt(np.mean(x[:n * win].reshape(n, win) ** 2, axis=1)) + 1e-9
    db = 20 * np.log10(rms)
    loud = np.nonzero(db > np.median(db) - END_DROP_DB)[0]
    return (loud[-1] + 1) * win / sr if len(loud) else len(x) / sr


def beat_features(x: np.ndarray, sr: int, first: float, beat: float, count: int) -> np.ndarray:
    edges = np.geomspace(60, 12000, BANDS + 1)
    freqs = np.fft.rfftfreq(NFFT, 1 / sr)
    band_of = np.digitize(freqs, edges) - 1
    win = np.hanning(NFFT)
    feats = np.zeros((count, BANDS))
    for k in range(count):
        a = int((first + k * beat) * sr)
        b = int((first + (k + 1) * beat) * sr)
        starts = np.arange(a, max(a + 1, b - NFFT), HOP)
        mags = np.abs(np.fft.rfft(np.stack([x[s:s + NFFT] * win for s in starts]), axis=1))
        power = (mags ** 2).mean(axis=0)
        for band in range(BANDS):
            sel = band_of == band
            feats[k, band] = math.log10(power[sel].sum() + 1e-12)
    feats -= feats.mean(axis=0)
    feats /= feats.std(axis=0) + 1e-9
    feats /= np.linalg.norm(feats, axis=1, keepdims=True) + 1e-9
    return feats


def find_loop(feats: np.ndarray) -> tuple[int, int, float]:
    count = len(feats)
    best = (0, (count // BEATS_PER_BAR) * BEATS_PER_BAR, -9.0)
    # Döngü başı en az bir ölçü içeride: dikiş, döngü başından önceki sese karıştırılır.
    for ka in range(BEFORE_BEATS, int(count * MAX_START_SHARE) + 1):
        min_len = max(8 * BEATS_PER_BAR, int(count * MIN_LOOP_SHARE))
        for kb in range(ka + min_len, count - AFTER_BEATS + 1):
            if (kb - ka) % BEATS_PER_BAR:
                continue
            after = float(np.mean(np.sum(feats[ka:ka + AFTER_BEATS] * feats[kb:kb + AFTER_BEATS],
                                         axis=1)))
            before = float(np.mean(np.sum(
                feats[ka - BEFORE_BEATS:ka] * feats[kb - BEFORE_BEATS:kb], axis=1)))
            score = (2 * after + before) / 3 + 0.05 * (kb - ka) / count
            if score > best[2]:
                best = (ka, kb, score)
    return best


def prepare(src_dir: Path, track: dict) -> dict:
    data, sr = sf.read(str(src_dir / track["file"]), always_2d=True, dtype="float64")
    if data.shape[1] == 1:
        data = np.repeat(data, 2, axis=1)
    mono = data.mean(axis=1)
    bpm = track["bpm"]
    beat = 60.0 / bpm
    first = measure_first(mono, sr, bpm)
    if track["loop"] == "whole" and is_whole_bars(len(data) / sr, beat):
        # Döngü olarak yapılmış parça tam ölçü uzunluğunda: kırpılmaz, ilk vuruş başa gelecek
        # şekilde döndürülür (döngünün kendi dikişi korunur).
        s0 = int(round(first * sr))
        out = np.vstack([data[s0:], data[:s0]])
        end = len(data) / sr
        count = int(round(end / beat))
        ka, kb, score, sa = 0, count, 1.0, 0
        info_first = first
    else:
        if first > beat - LEAD_IN_SECONDS:
            # İlk vuruş dosyanın hemen başında (kodlayıcı gecikmesi yüzünden biraz öncesinde):
            # kırpılmaz, başa sessizlik eklenir.
            lead = int(round((beat - first) * sr))
            data = np.vstack([np.zeros((lead, 2)), data])
            mono = data.mean(axis=1)
            first = 0.0
        info_first = first
        end = content_end(mono, sr)
        count = int(math.floor((end - first) / beat + 0.05))
        if track["loop"] == "whole":
            ka, kb, score = 0, (count // BEATS_PER_BAR) * BEATS_PER_BAR, 1.0
        else:
            ka, kb, score = find_loop(beat_features(mono, sr, first, beat, count))
        s0 = int(round(first * sr))
        sa = s0 + int(round(ka * beat * sr))
        sb = s0 + int(round(kb * beat * sr))
        out = data[s0:sb].copy()
        seam = int(SEAM_SECONDS * sr)
        if ka > 0:
            w = np.linspace(0, 1, seam)[:, None]
            out[-seam:] = out[-seam:] * (1 - w) + data[sa - seam:sa] * w
        else:
            # Döngünün sonundan taşan yankı başa eklenir; baştaki 2 ms açılış dikişi sürekli yapar.
            out[:FADE_IN] *= np.linspace(0, 1, FADE_IN)[:, None]
            tail = data[sb:min(len(data), sb + int(TAIL_SECONDS * sr))]
            fade = np.linspace(1, 0, len(tail))[:, None]
            out[:len(tail)] += tail * fade
        sa -= s0
    loop = out[sa:]
    rms_db = 20 * math.log10(math.sqrt(np.mean(loop ** 2)) + 1e-12)
    volume_db = min(0.0, TARGET_RMS_DB - rms_db)
    peak = np.max(np.abs(out))
    if peak > 1.0:
        out /= peak
        volume_db += 20 * math.log10(peak)
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    # libsndfile'in Vorbis kodlayıcısı büyük tek yazımda çöküyor; küçük bloklarla yazılır.
    with sf.SoundFile(str(AUDIO_DIR / (track["id"] + ".ogg")), "w", sr, 2, format="OGG",
                      subtype="VORBIS", compression_level=OGG_COMPRESSION) as f:
        samples = out.astype(np.float32)
        for start in range(0, len(samples), WRITE_BLOCK):
            f.write(samples[start:start + WRITE_BLOCK])
    loop_start = ka * beat
    info = dict(track, sr=sr, first=info_first, end=end, beats=count, ka=ka, kb=kb, score=score,
                loop_start=loop_start, length=len(out) / sr, volume_db=round(volume_db, 1))
    write_track_resource(info)
    return info


def write_track_resource(info: dict) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    text = f"""[gd_resource type="Resource" script_class="MusicTrack" format=3]

[ext_resource type="Script" path="res://scripts/data/music_track.gd" id="1_script"]
[ext_resource type="AudioStream" path="res://assets/audio/music/{info["id"]}.ogg" id="2_stream"]

[resource]
script = ExtResource("1_script")
id = &"{info["id"]}"
stream = ExtResource("2_stream")
bpm = {info["bpm"]:.1f}
loop_start = {info["loop_start"]:.6f}
volume_db = {info["volume_db"]:.1f}
title = "{info["title"]}"
author = "{info["author"]}"
license = "{info["license"]}"
source_url = "{info["url"]}"
"""
    (DATA_DIR / (info["id"] + ".tres")).write_text(text, encoding="utf-8", newline="\n")


def write_catalog(ids: list[str]) -> None:
    # Betik sınıfı tipli dizi, Godot'nun yazdığı gibi sınıfın betiğine başvurur.
    lines = ['[gd_resource type="Resource" script_class="MusicCatalog" format=3]', "",
             '[ext_resource type="Script" path="res://scripts/data/music_catalog.gd" id="1_script"]',
             '[ext_resource type="Script" path="res://scripts/data/music_track.gd" id="2_track"]']
    for i, track_id in enumerate(ids):
        lines.append(f'[ext_resource type="Resource" path="res://data/music/{track_id}.tres" '
                     f'id="{i + 3}_{track_id}"]')
    refs = ", ".join(f'ExtResource("{i + 3}_{track_id}")' for i, track_id in enumerate(ids))
    lines += ["", "[resource]", 'script = ExtResource("1_script")',
              f'tracks = Array[ExtResource("2_track")]([{refs}])']
    text = "\n".join(lines) + "\n"
    (DATA_DIR / "music_catalog.tres").write_text(text, encoding="utf-8", newline="\n")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    src_dir = Path(sys.argv[1])
    for track in TRACKS:
        info = prepare(src_dir, track)
        print("%-19s %3.0f BPM | ilk vuruş %.3f sn | içerik %.1f sn = %d vuruş | döngü %d→%d "
              "(%.2f→%.2f sn, %d ölçü, benzerlik %.2f) | dosya %.2f sn | ses %+.1f dB"
              % (info["id"], info["bpm"], info["first"], info["end"], info["beats"], info["ka"],
                 info["kb"], info["loop_start"], info["kb"] * 60 / info["bpm"],
                 (info["kb"] - info["ka"]) // BEATS_PER_BAR, info["score"], info["length"],
                 info["volume_db"]))
    write_catalog([t["id"] for t in TRACKS])


if __name__ == "__main__":
    main()
