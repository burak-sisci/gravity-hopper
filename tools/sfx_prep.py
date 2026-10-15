"""Ses efekti hazırlama aracı (M3-15, architecture.md §8.8, ADR-061).

Kenney ses paketlerinden (CC0, ADR-042) seçilen efektleri oyuna hazırlar:
  1. Her olayın sesini bulur ve assets/audio/sfx/<olay>.ogg olarak kopyalar. Dosya yeniden
     kodlanmaz (Kenney OGG'leri olduğu gibi).
  2. Ses düzeyini müzikle dengeler: her efektin en yüksek kısa süreli düzeyi (50 ms RMS), müziğin
     ortanca kısa süreli düzeyine göre katmanının farkına (TIERS) çekilir. Telefon hoparlörü
     alçak sesleri vermez; iki ölçüm de 250 Hz altı atılarak yapılır. Kazanç, tepe -1 dBFS'yi
     geçmeyecek kadarla sınırlanır.
  3. data/audio/sfx_bank.tres (SfxBank) dosyasını yazar. Ses düzeyi dosyaya işlenmez,
     volume_db alanına yazılır.
  4. Gerilim sesini (M3-16) hazırlar: kaynağın son CROSSFADE saniyesi başına eşit güçlü çapraz
     geçişle bindirilir (dikişsiz döngü, assets/audio/sfx/tension.ogg; yeniden kodlanır). Düzeyi
     müziğin ortanca düzeyine göre TENSION_DB'ye çekilir ve data/audio/tension_mix.tres'teki
     volume_db satırına yazılır (dosyanın diğer değerleri elle ayarlanır).

Olay sırası GameTypes.Sfx ile aynıdır (enum değeri = SOUNDS'taki sıra).

Kullanım (proje dışındaki geliştirme ortamı; numpy 2.5.4, soundfile 0.14.0):
  python tools/sfx_prep.py <kaynak klasörü>
Kaynak klasöründe Kenney paketlerinin zip'leri <paket>/ alt klasörlerine açılmış olur
(digital-audio/, impact-sounds/ …); indirme bağlantıları PACKS'te. Kaynaklar depoya girmez.
"""
import math
import re
import shutil
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parent.parent
AUDIO_DIR = ROOT / "assets" / "audio" / "sfx"
MUSIC_DIR = ROOT / "assets" / "audio" / "music"
MUSIC_DATA = ROOT / "data" / "music"
BANK_PATH = ROOT / "data" / "audio" / "sfx_bank.tres"

PACKS = {
    "digital-audio": ("Digital Audio", "https://kenney.nl/assets/digital-audio"),
    "impact-sounds": ("Impact Sounds", "https://kenney.nl/assets/impact-sounds"),
    "interface-sounds": ("Interface Sounds", "https://kenney.nl/assets/interface-sounds"),
    "sci-fi-sounds": ("Sci-fi Sounds", "https://kenney.nl/assets/sci-fi-sounds"),
    "music-jingles": ("Music Jingles", "https://kenney.nl/assets/music-jingles"),
}

# Katman: müziğin ortanca kısa süreli düzeyine göre hedef (dB). Sık çalan sesler (her dokunuş)
# müziğin altında, ödüller biraz üstünde, büyük anlar belirgin biçimde üstünde.
TIERS = {"frequent": -3.0, "reward": 3.0, "moment": 6.0}

# Sıra GameTypes.Sfx ile aynı. pitch_jitter: her çalışta perde ± bu oran (tekrar yorgunluğu).
SOUNDS = [
    {"id": "flip", "pack": "digital-audio", "file": "phaseJump2", "tier": "frequent",
     "jitter": 0.06},
    {"id": "land", "pack": "impact-sounds", "file": "impactGeneric_light_000",
     "tier": "frequent", "jitter": 0.08},
    {"id": "glimmer", "pack": "interface-sounds", "file": "confirmation_003", "tier": "reward",
     "jitter": 0.03},
    {"id": "near_miss", "pack": "digital-audio", "file": "phaserUp4", "tier": "reward",
     "jitter": 0.04},
    {"id": "combo_up", "pack": "digital-audio", "file": "highUp", "tier": "reward",
     "jitter": 0.0},
    {"id": "shield_break", "pack": "interface-sounds", "file": "glass_004", "tier": "moment",
     "jitter": 0.0},
    {"id": "death", "pack": "sci-fi-sounds", "file": "explosionCrunch_000", "tier": "moment",
     "jitter": 0.0},
    {"id": "sector", "pack": "digital-audio", "file": "zapThreeToneUp", "tier": "moment",
     "jitter": 0.0},
    {"id": "record", "pack": "music-jingles", "file": "jingles_PIZZI10", "tier": "moment",
     "jitter": 0.0},
]

# Gerilim sesi: sürekli çalan döngü. Düzeyi (en yakında) müziğin ortanca düzeyinin biraz altı;
# o anda müzik de boğuklaşmıştır.
TENSION = {"id": "tension", "pack": "sci-fi-sounds", "file": "computerNoise_000"}
TENSION_DB = -3.0
TENSION_PATH = ROOT / "data" / "audio" / "tension_mix.tres"
CROSSFADE = 0.5
TENSION_PEAK = 0.95
OGG_COMPRESSION = 0.4
WRITE_BLOCK = 4096

WINDOW = 0.05
PHONE_LOW_HZ = 250.0
PEAK_LIMIT_DB = -1.0
MIN_GAIN_DB = -24.0
MAX_GAIN_DB = 6.0
VOICES = 8


def phone_band(x: np.ndarray, sr: int) -> np.ndarray:
    """Telefon hoparlörünün vermediği alçak sesleri (250 Hz altı) atar."""
    spec = np.fft.rfft(x)
    spec[np.fft.rfftfreq(len(x), 1 / sr) < PHONE_LOW_HZ] = 0.0
    return np.fft.irfft(spec, n=len(x))


def short_term_db(x: np.ndarray, sr: int) -> np.ndarray:
    """50 ms'lik pencerelerde RMS düzeyi (dBFS). Pencereden kısa ses tek pencere sayılır."""
    win = int(WINDOW * sr)
    n = max(1, len(x) // win)
    padded = np.zeros(n * win)
    padded[:min(len(x), n * win)] = x[:n * win]
    rms = np.sqrt(np.mean(padded.reshape(n, win) ** 2, axis=1)) + 1e-12
    return 20 * np.log10(rms)


def load_mono(path: Path) -> tuple[np.ndarray, int]:
    x, sr = sf.read(str(path), dtype="float64", always_2d=True)
    return x.mean(axis=1), sr


def music_reference() -> float:
    """Müziğin oyunda çalan ortanca kısa süreli düzeyi: parçaların volume_db'si uygulanmış,
    beş parçanın ortalaması."""
    levels = []
    for res in sorted(MUSIC_DATA.glob("*.tres")):
        match = re.search(r"^volume_db = (-?[\d.]+)$", res.read_text(encoding="utf-8"), re.M)
        ogg = MUSIC_DIR / (res.stem + ".ogg")
        if match is None or not ogg.exists():
            continue
        x, sr = load_mono(ogg)
        levels.append(float(np.median(short_term_db(phone_band(x, sr), sr))) + float(match[1]))
    return float(np.mean(levels))


def find_source(src_dir: Path, sound: dict) -> Path:
    hits = [p for p in (src_dir / sound["pack"]).rglob(sound["file"] + ".ogg")]
    if len(hits) != 1:
        raise SystemExit(f"{sound['pack']}/{sound['file']}.ogg bulunamadı ya da birden çok: {hits}")
    return hits[0]


def prepare(src_dir: Path, sound: dict, reference: float) -> dict:
    src = find_source(src_dir, sound)
    x, sr = load_mono(src)
    level = float(short_term_db(phone_band(x, sr), sr).max())
    peak = 20 * math.log10(float(np.max(np.abs(x))) + 1e-12)
    wanted = reference + TIERS[sound["tier"]] - level
    gain = min(wanted, PEAK_LIMIT_DB - peak)
    gain = max(MIN_GAIN_DB, min(MAX_GAIN_DB, gain))
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, AUDIO_DIR / (sound["id"] + ".ogg"))
    return dict(sound, length=len(x) / sr, level=level, peak=peak, gain=round(gain, 1),
                limited=gain < wanted - 0.05)


def make_loop(x: np.ndarray, sr: int) -> np.ndarray:
    """Son CROSSFADE saniyeyi başa eşit güçlü çapraz geçişle bindirir. Döngünün sonu kaynağın
    çapraz geçişten hemen önceki örneği, başı ise ondan sonraki örneğidir: dikiş süreklidir."""
    fade = int(CROSSFADE * sr)
    angle = np.linspace(0.0, math.pi / 2, fade)
    loop = x[:len(x) - fade].copy()
    loop[:fade] = x[:fade] * np.sin(angle) + x[len(x) - fade:] * np.cos(angle)
    return loop


def prepare_tension(src_dir: Path, reference: float) -> dict:
    x, sr = load_mono(find_source(src_dir, TENSION))
    loop = make_loop(x, sr)
    peak = float(np.max(np.abs(loop)))
    scale = min(1.0, TENSION_PEAK / peak)
    loop *= scale
    level = float(np.median(short_term_db(phone_band(loop, sr), sr)))
    gain = max(MIN_GAIN_DB, min(MAX_GAIN_DB, reference + TENSION_DB - level))
    # Dikişte düzey sıçraması: döngünün sonu ile başındaki 50 ms'lik pencereler.
    seam = short_term_db(np.concatenate([loop[-int(WINDOW * sr):], loop[:int(WINDOW * sr)]]), sr)
    with sf.SoundFile(str(AUDIO_DIR / (TENSION["id"] + ".ogg")), "w", sr, 1, format="OGG",
                      subtype="VORBIS", compression_level=OGG_COMPRESSION) as f:
        # libsndfile'in Vorbis kodlayıcısı büyük tek yazımda çöküyor (music_prep.py).
        samples = loop.astype(np.float32)
        for start in range(0, len(samples), WRITE_BLOCK):
            f.write(samples[start:start + WRITE_BLOCK])
    text = TENSION_PATH.read_text(encoding="utf-8")
    text, count = re.subn(r"^volume_db = .*$", f"volume_db = {gain:.1f}", text, flags=re.M)
    if count != 1:
        raise SystemExit(f"{TENSION_PATH.name}: volume_db satırı bulunamadı")
    TENSION_PATH.write_text(text, encoding="utf-8", newline="\n")
    return dict(TENSION, length=len(loop) / sr, level=level, gain=round(gain, 1),
                seam=float(seam[1] - seam[0]))


def write_bank(infos: list[dict]) -> None:
    lines = ['[gd_resource type="Resource" script_class="SfxBank" format=3]', "",
             '[ext_resource type="Script" path="res://scripts/data/sfx_bank.gd" id="1_bank"]',
             '[ext_resource type="Script" path="res://scripts/data/sfx_sound.gd" id="2_sound"]']
    for i, info in enumerate(infos):
        lines.append(f'[ext_resource type="AudioStream" path="res://assets/audio/sfx/'
                     f'{info["id"]}.ogg" id="{i + 3}_{info["id"]}"]')
    for i, info in enumerate(infos):
        title, url = PACKS[info["pack"]]
        lines += ["", f'[sub_resource type="Resource" id="Resource_{info["id"]}"]',
                  'script = ExtResource("2_sound")',
                  f"event = {i}",
                  f'stream = ExtResource("{i + 3}_{info["id"]}")',
                  f'volume_db = {info["gain"]:.1f}',
                  f'pitch_jitter = {info["jitter"]:.2f}',
                  f'title = "{info["file"]}.ogg ({title})"',
                  'author = "Kenney (kenney.nl)"',
                  'license = "CC0 1.0"',
                  f'source_url = "{url}"']
    refs = ", ".join(f'SubResource("Resource_{info["id"]}")' for info in infos)
    lines += ["", "[resource]", 'script = ExtResource("1_bank")', f"voices = {VOICES}",
              f'sounds = Array[ExtResource("2_sound")]([{refs}])']
    BANK_PATH.parent.mkdir(parents=True, exist_ok=True)
    BANK_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    src_dir = Path(sys.argv[1])
    reference = music_reference()
    print("müzik (telefon bandı, ortanca kısa süreli düzey): %.1f dBFS" % reference)
    infos = [prepare(src_dir, sound, reference) for sound in SOUNDS]
    for info in infos:
        heard = info["level"] + info["gain"]
        print("%-13s %-24s %4.2f sn | düzey %6.1f tepe %5.1f | kazanç %+5.1f dB → %6.1f "
              "(müzikten %+.1f)%s"
              % (info["id"], info["file"], info["length"], info["level"], info["peak"],
                 info["gain"], heard, heard - reference,
                 " | tepe sınırı" if info["limited"] else ""))
    write_bank(infos)
    tension = prepare_tension(src_dir, reference)
    print("%-13s %-24s %4.2f sn döngü | ortanca düzey %6.1f | kazanç %+5.1f dB → müzikten %+.1f"
          " | dikiş %+.1f dB"
          % (tension["id"], tension["file"], tension["length"], tension["level"],
             tension["gain"], tension["level"] + tension["gain"] - reference, tension["seam"]))


if __name__ == "__main__":
    main()
