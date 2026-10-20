"""Özgün müzik üreteci (M3-21, architecture.md §8.3, ADR-065).

Claude'un bestelediği parçaları (tracks/) CC0 enstrüman kayıtlarıyla seslendirir, mikse eder
ve oyuna yazar: assets/audio/music/<id>.ogg, data/music/<id>.tres (MusicTrack) ve
data/music/music_catalog.tres.
  - Parça tam ölçü uzunluğundadır ve 0. saniyesi ilk vuruştur; döngü bütün parçadır
    (loop_start = 0). Sondan taşan sesler başa katlanır, bütün süzgeçler döngüseldir: dikiş
    kendiliğinden süreklidir (engine.py).
  - Ses düzeyi dosyaya işlenmez, volume_db alanına yazılır: parçanın telefon bandındaki
    (250 Hz üstü) ortanca kısa süreli düzeyi, efektlerin dengelendiği müzik düzeyine
    (MUSIC_REFERENCE_DB, M3-15) çekilir. Böylece efekt dengesi değişmez.

Kullanım (proje dışındaki geliştirme ortamı; numpy 2.5.4, soundfile 0.14.0):
  python -I tools/music/build.py                      bütün parçalar
  python -I tools/music/build.py caravan              tek parça
  python -I tools/music/build.py caravan --preview x.wav [--from 30 --to 60]
                                                      yalnızca dinleme dosyası (oyuna yazmaz)
Kayıtlar ilk çalıştırmada indirilir (~1 GB, %LOCALAPPDATA%/gravity-hopper/music_src).
"""

import argparse
import importlib
import math
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
# Önce tools/ (sfx_prep düzey ölçümü), en önde bu klasör.
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE))

import numpy as np  # noqa: E402
import soundfile as sf  # noqa: E402

import engine  # noqa: E402
import sfx_prep  # noqa: E402
from engine import Event  # noqa: E402

TRACKS = ["caravan", "pagoda", "castle"]
AUDIO_DIR = ROOT / "assets" / "audio" / "music"
DATA_DIR = ROOT / "data" / "music"
AUTHOR = "Claude (Anthropic), Gravity Hopper için"
LICENSE = "Original"
# M3-15'te efektlerin göre dengelendiği müzik düzeyi (telefon bandı, ortanca 50 ms, dBFS).
MUSIC_REFERENCE_DB = -23.4
MIN_VOLUME_DB = -12.0
MAX_VOLUME_DB = 0.0
OGG_COMPRESSION = 0.4
# libsndfile'in Vorbis kodlayıcısı büyük tek yazımda çöküyor; küçük bloklarla yazılır.
WRITE_BLOCK = 4096
# Dikiş denetimi: sondan başa geçişteki örnek sıçraması, dikişin iki yanındaki 10 ms'de görülen
# en büyük örnekten örneğe değişimi geçmez (tık, çevresinden büyük bir basamaktır; dikişte o an
# çalan tiz bir ses ise kendi doğal değişimini taşır).
SEAM_LIMIT = 1.0
SEAM_WINDOW_SEC = 0.01


def merge_ties(events: list[Event]) -> list[Event]:
    """Uzun sesli çalgılarda art arda gelen aynı notayı tek notada birleştirir (yeniden
    tetiklenen kayıtların üst üste binip düzeyi kabartmaması için)."""
    plain = ((0.0, 0.0), (1.0, 1.0))
    out: list[Event] = []
    for ev in sorted(events, key=lambda e: (str(e.key), e.beat)):
        prev = out[-1] if out else None
        if (prev is not None and prev.key == ev.key and ev.legato
                and abs(prev.beat + prev.dur - ev.beat) < 1e-6 and prev.swell == plain[1]
                and ev.swell == plain[1] and ev.bend == plain[0] and prev.slide == plain[0]):
            prev.dur += ev.dur
            continue
        out.append(Event(**vars(ev)))
    return out


def render(track) -> np.ndarray:
    sc = track.compose()
    mix = track.mix()
    events = {}
    for name, evs in sc.events.items():
        inst = mix.instruments[name]
        events[name] = merge_ties(evs) if inst.sustain else evs
    return engine.master(engine.render(mix, events, track.BPM, track.BARS * 4))


def music_level(x: np.ndarray) -> float:
    mono = x.mean(axis=1)
    return float(np.median(sfx_prep.short_term_db(sfx_prep.phone_band(mono, engine.SR),
                                                  engine.SR)))


def seam_ratio(x: np.ndarray) -> float:
    jump = float(np.abs(x[0] - x[-1]).max())
    w = int(SEAM_WINDOW_SEC * engine.SR)
    around = np.concatenate([np.diff(x[-w:], axis=0), np.diff(x[:w], axis=0)])
    return jump / float(np.abs(around).max())


def write_ogg(path: Path, x: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with sf.SoundFile(str(path), "w", engine.SR, 2, format="OGG", subtype="VORBIS",
                      compression_level=OGG_COMPRESSION) as f:
        samples = x.astype(np.float32)
        for start in range(0, len(samples), WRITE_BLOCK):
            f.write(samples[start:start + WRITE_BLOCK])


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
loop_start = 0.0
volume_db = {info["volume_db"]:.1f}
title = "{info["title"]}"
author = "{AUTHOR}"
license = "{LICENSE}"
source_url = "tools/music/tracks/{info["id"]}.py"
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
    (DATA_DIR / "music_catalog.tres").write_text("\n".join(lines) + "\n", encoding="utf-8",
                                                 newline="\n")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser()
    parser.add_argument("ids", nargs="*", default=TRACKS)
    parser.add_argument("--preview")
    parser.add_argument("--from", dest="start", type=float, default=0.0)
    parser.add_argument("--to", dest="end", type=float, default=0.0)
    args = parser.parse_args()
    for track_id in args.ids:
        t0 = time.time()
        track = importlib.import_module(f"tracks.{track_id}")
        x = render(track)
        seconds = len(x) / engine.SR
        bars = seconds * track.BPM / 60 / 4
        level = music_level(x)
        volume_db = round(max(MIN_VOLUME_DB, min(MAX_VOLUME_DB, MUSIC_REFERENCE_DB - level)), 1)
        seam = seam_ratio(x)
        peak = 20 * math.log10(float(np.abs(x).max()))
        print(f"{track_id:8s} {track.BPM} BPM | {seconds:.3f} sn = {bars:.4f} ölçü | tepe "
              f"{peak:.1f} dBFS | telefon bandı ortanca {level:.1f} dB → volume_db "
              f"{volume_db:+.1f} | dikiş sıçraması {seam:.2f} | {time.time() - t0:.0f} sn")
        if abs(bars - track.BARS) > 1e-6 or seam > SEAM_LIMIT:
            raise SystemExit("ölçü sayısı ya da dikiş tutmuyor")
        if args.preview:
            a = int(args.start * engine.SR)
            b = int(args.end * engine.SR) if args.end else len(x)
            sf.write(args.preview, (x[a:b] * 10 ** (volume_db / 20)).astype(np.float32),
                     engine.SR)
            continue
        write_ogg(AUDIO_DIR / f"{track_id}.ogg", x)
        write_track_resource(dict(id=track_id, bpm=track.BPM, volume_db=volume_db,
                                  title=track.TITLE))
    if not args.preview:
        write_catalog([t for t in TRACKS if (DATA_DIR / f"{t}.tres").exists()])


if __name__ == "__main__":
    main()
