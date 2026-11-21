"""İndirme boyutu (M6-03, architecture.md §16): hedef < 40 MB; check.ps1'in 7. adımı.

Play, AAB'den her cihaza yalnızca kendi işlemci mimarisinin kitaplıklarını gönderir. Cihazın
indirdiği boyut ≈ APK'nın sıkıştırılmış toplamı − öbür mimarilerin kitaplıkları.

İki kullanım:
  python -I tools/size_report.py
      Tahmin (dışa aktarmadan, her denetimde), en büyük mimari için (armeabi-v7a: 32 bit,
      zayıf telefonlar): ölçülmüş motor payı (ENGINE_MB: Godot kitaplığı, Java kodu, Android
      kaynakları; yayın şablonu) + oyunun verisi (assets/ altındaki dosyalar; müzik zaten
      sıkıştırılmış) + kod, sahne ve veri dosyaları (DATA_OVERHEAD_MB). Sınır TARGET_MB.
  python -I tools/size_report.py --apk <yayın.apk>
      Gerçek APK'yı ölçer: mimari başına cihaz boyutu, en büyük kalemler ve tahminle farkı
      (ENGINE_MB yeniden ölçüldüğünde buradan alınır).
Çıktı: sonda "BOYUT TAMAM" ya da "BOYUT SORUNLU" (çıkış kodu 1).
"""
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TARGET_MB = 40.0
## Yayın yapısında oyunun verisi dışındaki her şey, armeabi-v7a cihaz (2026-11-21, Godot 4.7.2
## yayın şablonu, M6-03 ölçümü; sıkıştırılmış): libgodot_android.so 25,51 + libc++_shared.so
## 0,40 + Java kodu, kaynaklar ve imza 2,10 MB. arm64 cihazda 26,58 MB.
ENGINE_MB = 28.01
## Kod, sahne, çeviri ve veri dosyalarının dışa aktarılmış payı (MB; ölçüldü: APK'daki assets/
## 11,34, assets/ klasörü 11,03).
DATA_OVERHEAD_MB = 0.35
DATA_DIRS = ["assets"]
SKIP_SUFFIXES = {".import", ".gitkeep", ".uid"}
MB = 1_000_000


def data_mb() -> float:
    total = 0
    for folder in DATA_DIRS:
        for path in (ROOT / folder).rglob("*"):
            if path.is_file() and path.suffix not in SKIP_SUFFIXES:
                total += path.stat().st_size
    return total / MB


def estimate() -> float:
    return ENGINE_MB + data_mb() + DATA_OVERHEAD_MB


def apk_report(apk: Path) -> int:
    archive = zipfile.ZipFile(apk)
    per_arch: dict[str, int] = {}
    total = 0
    groups: dict[str, int] = {}
    for info in archive.infolist():
        total += info.compress_size
        parts = info.filename.split("/")
        key = parts[0]
        if info.filename.startswith("lib/"):
            per_arch[parts[1]] = per_arch.get(parts[1], 0) + info.compress_size
            key = parts[1] + "/" + parts[-1]
        elif info.filename.startswith("assets/"):
            key = "assets/" + parts[1]
        groups[key] = groups.get(key, 0) + info.compress_size
    for key, size in sorted(groups.items(), key=lambda item: -item[1])[:8]:
        print(f"  {size / MB:6.2f} MB  {key}")
    worst = 0.0
    for arch in per_arch:
        device = (total - sum(s for a, s in per_arch.items() if a != arch)) / MB
        worst = max(worst, device)
        print(f"CİHAZ {arch}: {device:.2f} MB")
    print(f"TAHMİN {estimate():.2f} MB (en büyük mimari için; fark {estimate() - worst:+.2f})")
    return verdict(worst)


def verdict(size: float) -> int:
    if size >= TARGET_MB:
        print(f"SORUN: {size:.2f} MB ≥ {TARGET_MB:.0f} MB")
        print("BOYUT SORUNLU")
        return 1
    print(f"BOYUT TAMAM ({size:.2f} / {TARGET_MB:.0f} MB; kalan {TARGET_MB - size:.2f} MB)")
    return 0


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    if len(sys.argv) == 3 and sys.argv[1] == "--apk":
        return apk_report(Path(sys.argv[2]))
    size = estimate()
    print(f"veri {data_mb():.2f} MB + motor {ENGINE_MB:.2f} + kod/sahne {DATA_OVERHEAD_MB:.2f}")
    return verdict(size)


if __name__ == "__main__":
    sys.exit(main())
