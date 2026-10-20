"""Enstrümanlar (M3-21): kayıt eşlemesi, perde düzeltmesi, ön ayarlar.

Dosya adlarındaki nota adları kütüphaneye göre bir oktav kayık olabilir (VCSL telliler "C3"
der, ses C4'tür); her enstrümanın kayması ölçülerek bulundu ve shift olarak yazıldı. Perde,
adın gösterdiği notanın en çok ±0,6 yarım ses yakınındaysa ölçülen değere ince ayarlanır.
Her işlev yeni bir Instrument döndürür (sıradaki kayıt sayacı parçaya özgü kalır); yüklenen
kayıtlar önbellekte paylaşılır.
"""

import re
from functools import lru_cache

import numpy as np

import engine
from engine import SR, Instrument, Sample, detect_pitch, load_sample, note_number
from samples import fetch

NOTE_IN_NAME = r"(?<![A-Za-z])([A-Ga-g][#b]?-?\d)(?![\d])"
# Telli ve vurmalı perdeli kayıtlarda saldırı perdesi tiz olur; ölçüm sonradan yapılır.
PITCH_AT = 0.4
TUNE_LIMIT = 0.6


def _layers(tokens: list[str], order: list[str] | None) -> dict[str, int]:
    found = sorted(set(tokens), key=lambda t: order.index(t) if order else (len(t), t))
    return {t: i for i, t in enumerate(found)}


def _tuned(sample: Sample, nominal: float, at: float, report: list[str]) -> float:
    measured = detect_pitch(sample.data, at=at)
    if measured is None:
        return nominal
    diff = (measured - nominal + 6) % 12 - 6
    if abs(diff) < TUNE_LIMIT:
        return nominal + diff
    report.append(f"{sample.name}: ölçülen {measured:.2f}, ad {nominal:.0f} (ad kullanıldı)")
    return nominal


@lru_cache(maxsize=None)
def pitched_samples(repo: str, folder: str, pattern: str, layer_re: str,
                    order: tuple[str, ...] | None, shift: int, at: float = PITCH_AT,
                    tune: bool = True) -> tuple[Sample, ...]:
    paths = fetch(repo, folder, pattern)
    tokens = [m.group(1) if (m := re.search(layer_re, p.stem)) else "" for p in paths]
    layer_of = _layers(tokens, list(order) if order else None)
    out = []
    report: list[str] = []
    for path, token in zip(paths, tokens):
        m = re.search(NOTE_IN_NAME, path.stem)
        if m is None:
            continue
        nominal = note_number(m.group(1)) + shift
        s = load_sample(path, nominal, layer_of[token])
        s.root = _tuned(s, nominal, at, report) if tune else nominal
        out.append(s)
    for line in report:
        print("  perde:", line)
    return tuple(out)


@lru_cache(maxsize=None)
def zone_samples(repo: str, folder: str, pattern: str, layer_re: str = "",
                 order: tuple[str, ...] | None = None) -> tuple[Sample, ...]:
    paths = fetch(repo, folder, pattern)
    tokens = [m.group(1) if layer_re and (m := re.search(layer_re, p.stem)) else ""
              for p in paths]
    layer_of = _layers(tokens, list(order) if order else None)
    return tuple(load_sample(p, 60.0, layer_of[t]) for p, t in zip(paths, tokens))


@lru_cache(maxsize=None)
def sliced(repo: str, folder: str, pattern: str, gap: float = 0.25,
           threshold_db: float = -30.0) -> tuple[Sample, ...]:
    """Tek dosyada art arda çalınmış vuruşları ayrı kayıtlara böler."""
    path = fetch(repo, folder, pattern)[0]
    whole = load_sample(path)
    lv = engine.short_rms_db(whole.data, 0.01)
    rising = np.nonzero((lv[1:] > threshold_db + float(lv.max()) + 18)
                        & (lv[1:] - lv[:-1] > 6))[0] + 1
    starts: list[int] = []
    for i in rising:
        if not starts or (i - starts[-1]) * 0.01 > gap:
            starts.append(int(i))
    bounds = [s * int(0.01 * SR) for s in starts] + [len(whole.data)]
    out = []
    for k, (a, b) in enumerate(zip(bounds[:-1], bounds[1:])):
        seg = whole.data[max(0, a - int(0.005 * SR)):b]
        peak_db = engine.short_rms_db(seg).max()
        seg = seg * 10 ** ((engine.NORMAL_DB - peak_db) / 20)
        out.append(Sample(seg, 60.0, 0, f"{whole.name}_{k}"))
    return tuple(out)


def kit(name: str, zones: dict[str, tuple[Sample, ...]], layers: int = 1,
        **kw) -> Instrument:
    return Instrument(name, zones={k: list(v) for k, v in zones.items()}, layers=layers, **kw)


def tonal(name: str, samples: tuple[Sample, ...], **kw) -> Instrument:
    layers = 1 + max(s.layer for s in samples)
    return Instrument(name, samples=list(samples), layers=layers, **kw)


VCSL_MEM = "Membranophones/Struck Membranophones"
VCSL_IDIO = "Idiophones/Struck Idiophones"
VCSL_CHORD = "Chordophones/Composite Chordophones"
VCSL_AERO = "Aerophones/Edge-blown Aerophones"


# --- Vurmalılar ---

def darbuka(**kw) -> Instrument:
    """D: düm (derin), T: tek (keskin kenar), K: ka (yumuşak kenar), S: ikinci tek, P: çıt."""
    folder = f"{VCSL_MEM}/Darbuka"
    zones = {key: zone_samples("vcsl", folder, rf"Darbuka_{num}_", r"_vl(\d)_")
             for key, num in {"D": 1, "T": 4, "K": 3, "S": 5, "P": 2}.items()}
    return kit("darbuka", zones, layers=2, **kw)


def frame_drum(**kw) -> Instrument:
    """B: büyük def (açık), b: büyük boğuk, H: küçük def, h: küçük boğuk, S: el şaplağı."""
    folder = f"{VCSL_MEM}/Frame Drum"
    zones = {
        "B": zone_samples("vcsl", folder, r"HDrumL_Hit_v", r"_v(\d)_"),
        "b": zone_samples("vcsl", folder, r"HDrumL_HitMuted", r"_v(\d)_"),
        "H": zone_samples("vcsl", folder, r"HDrumS_Hit_v", r"_v(\d)_"),
        "h": zone_samples("vcsl", folder, r"HDrumS_HitMuted", r"_v(\d)_"),
        "S": zone_samples("vcsl", folder, r"_Hand"),
    }
    return kit("frame_drum", zones, layers=2, **kw)


def tambourine(**kw) -> Instrument:
    """H: vuruş, S: sallama."""
    folder = f"{VCSL_IDIO}/Tambourine 1"
    zones = {"H": zone_samples("vcsl", folder, r"_Hit_", r"_v(\d)_"),
             "S": zone_samples("vcsl", folder, r"_Shake_")}
    return kit("tambourine", zones, layers=2, **kw)


def shaker(**kw) -> Instrument:
    """D / U: aşağı / yukarı sallama, L: hızlı alçak, R: uzun titretme."""
    folder = f"{VCSL_IDIO}/Shaker, Small"
    zones = {"D": zone_samples("vcsl", folder, r"ShakerDouble_Down"),
             "U": zone_samples("vcsl", folder, r"ShakerDouble_Up"),
             "L": zone_samples("vcsl", folder, r"ShakerLowFaster"),
             "R": zone_samples("vcsl", folder, r"Shaker_Roll")}
    return kit("shaker", zones, **kw)


def finger_cymbals(**kw) -> Instrument:
    return kit("finger_cymbals", {"Z": sliced("vcsl", f"{VCSL_IDIO}/Finger Cymbals", r".")},
               **kw)


def mark_tree(**kw) -> Instrument:
    """A: yukarı süpürme, D: aşağı süpürme."""
    folder = f"{VCSL_IDIO}/Mark Trees"
    zones = {"A": zone_samples("vcsl", folder, r"windchimes_asc1"),
             "D": zone_samples("vcsl", folder, r"windchimes_desc1")}
    return kit("mark_tree", zones, **kw)


def bass_drum(**kw) -> Instrument:
    zones = {"B": zone_samples("vcsl", f"{VCSL_MEM}/Bass Drum 2", r"hit",
                               r"_hit_([a-z]+)", ("pp", "mp", "mf", "f", "ff"))}
    return kit("bass_drum", zones, layers=5, **kw)


def rope_snare(**kw) -> Instrument:
    """S: teller açık, N: teller kapalı (tabor sesi), X: kenar vuruşu."""
    folder = f"{VCSL_MEM}/Snare Drum, Rope Tension"
    zones = {"S": zone_samples("vcsl", folder, r"_low_sn_", r"_vl(\d)_"),
             "N": zone_samples("vcsl", folder, r"_low_ns_", r"_vl(\d)_"),
             "X": zone_samples("vcsl", folder, r"_sidestick_")}
    return kit("rope_snare", zones, layers=3, **kw)


# Timpani kayıtları perde adı taşımıyor; tepe (1,1) kipinden ölçüldü (F#2, B2, C#3, E3, F#3).
TIMPANI_ROOTS = {1: 41.92, 2: 46.65, 3: 49.11, 4: 51.91, 5: 54.19}


@lru_cache(maxsize=None)
def _timpani_samples() -> tuple[Sample, ...]:
    paths = fetch("vcsl", f"{VCSL_MEM}/Timpani 1", r"Hit")
    out = []
    for p in paths:
        drum = int(re.search(r"Timpani(\d)", p.stem).group(1))
        layer = int(re.search(r"_v(\d)_", p.stem).group(1)) - 2
        out.append(load_sample(p, TIMPANI_ROOTS[drum], layer))
    return tuple(out)


def timpani(**kw) -> Instrument:
    return tonal("timpani", _timpani_samples(), **kw)


# --- Telliler ve tınılı vurmalılar ---

def strumstick(**kw) -> Instrument:
    """Üç telli halk sazı (saz / ud yerine; parmakla)."""
    return tonal("strumstick", pitched_samples(
        "vcsl", f"{VCSL_CHORD}/Strumstick", r"_Main_", r"_vl(\d)_", None, 12), **kw)


def dan_tranh(**kw) -> Instrument:
    """Kanun benzeri zither (pentatonik B C# D# F# G#; öteki perdeler kaydırılarak)."""
    return tonal("dan_tranh", pitched_samples(
        "vcsl", "Chordophones/Zithers/Dan Tranh", r"^[A-Ga-g]#?\d_(mf|f|ff)_", r"_(mf|f|ff)_",
        ("mf", "f", "ff"), 12), **kw)


def folk_harp(**kw) -> Instrument:
    return tonal("folk_harp", pitched_samples(
        "vcsl", f"{VCSL_CHORD}/Folk Harp", r"Normal", r"_(v\d)_", None, 12), **kw)


# --- Orkestra (VSCO 2 CE; adlar bir oktav aşağı yazılmış: "C3" = orta do) ---

def _vsco(name: str, folder: str, pattern: str, layer_re: str = r"_v(\d)",
          shift: int = 12, at: float = 0.3, **kw) -> Instrument:
    return tonal(name, pitched_samples("vsco", folder, pattern, layer_re, None, shift, at), **kw)


def flute(**kw) -> Instrument:
    return _vsco("flute", "Woodwinds/Flute", r"_susvib_", sustain=True, **kw)


def flute_expressive(**kw) -> Instrument:
    """Kabarıp sönen titreşimli flüt (uzun notalar için)."""
    return _vsco("flute_exp", "Woodwinds/Flute", r"_expvib_", sustain=True, **kw)


def flute_staccato(**kw) -> Instrument:
    return _vsco("flute_stac", "Woodwinds/Flute", r"_stac_", **kw)


def oboe(**kw) -> Instrument:
    return _vsco("oboe", "Woodwinds/Oboe", r"_Vib_", sustain=True, **kw)


def oboe_staccato(**kw) -> Instrument:
    return _vsco("oboe_stac", "Woodwinds/Oboe", r"_Stacc_", **kw)


def violins(**kw) -> Instrument:
    return _vsco("violins", "Strings/Violin Section", r"_susVib_", sustain=True, **kw)


def violins_spiccato(**kw) -> Instrument:
    return _vsco("violins_spic", "Strings/Violin Section", r"_Spic_", **kw)


def violins_pizz(**kw) -> Instrument:
    return _vsco("violins_pizz", "Strings/Violin Section", r"_Pizz_", **kw)


def violas(**kw) -> Instrument:
    return _vsco("violas", "Strings/Viola Section", r"_susvib_", sustain=True, **kw)


def violas_pizz(**kw) -> Instrument:
    return _vsco("violas_pizz", "Strings/Viola Section", r"_pizz_", **kw)


def cellos(**kw) -> Instrument:
    return _vsco("cellos", "Strings/Cello Section", r"^susvib_", sustain=True, **kw)


def cellos_pizz(**kw) -> Instrument:
    return _vsco("cellos_pizz", "Strings/Cello Section", r"^pizzT_", **kw)


def cellos_spiccato(**kw) -> Instrument:
    return _vsco("cellos_spic", "Strings/Cello Section", r"^spic_", **kw)


def contrabass(**kw) -> Instrument:
    return _vsco("contrabass", "Strings/Solo Contrabass", r"_SusVib_", sustain=True, **kw)


def contrabass_pizz(**kw) -> Instrument:
    return _vsco("contrabass_pizz", "Strings/Solo Contrabass", r"_Pizz_", **kw)


def horn(**kw) -> Instrument:
    return _vsco("horn", "Brass/F Horn", r"_sus_", sustain=True, **kw)


def harp(**kw) -> Instrument:
    return _vsco("harp", "Strings/Harp", r"KSHarp", r"()", 0, **kw)


# --- Blok flütler (VCSL; adlar bir oktav aşağı) ---

def alto_recorder(**kw) -> Instrument:
    return tonal("alto_recorder", pitched_samples(
        "vcsl", f"{VCSL_AERO}/Baroque Alto Recorder", r"_SusVib_", r"()", None, 12, 0.3),
        sustain=True, **kw)


def alto_recorder_staccato(**kw) -> Instrument:
    return tonal("alto_recorder_stac", pitched_samples(
        "vcsl", f"{VCSL_AERO}/Baroque Alto Recorder", r"_Stac_", r"()", None, 12, 0.05),
        **kw)


def tenor_recorder(**kw) -> Instrument:
    return tonal("tenor_recorder", pitched_samples(
        "vcsl", f"{VCSL_AERO}/Baroque Tenor Recorder", r"_SusVib_", r"()", None, 12, 0.3),
        sustain=True, **kw)
