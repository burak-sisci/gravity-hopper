"""Telefonda performans turu ve cihaz telemetrisi (M6-10, architecture.md §16.1; ADR-110).

Takılma kümesinin (S-09) nedeni bununla bulundu: telefonun 8 çekirdeği başka uygulamaların arka
plan işiyle dolunca oyunun iş parçacığı sıra bekliyor. Kare süresi tek başına bunu söylemez;
aynı anda toplam CPU kullanımı, çekirdek frekansı ve sınırı, GPU doluluğu ve sıcaklık gerekir.

Önce ölçüm yapısı yüklenir (export_presets.cfg'ye geçici `command_line/extra_args`, ör.
`-- --invincible --start-sector=3 --perf=15.1 --auto-tap=0.5`; deploy.ps1; dosya geri alınır).

  python -I tools/phone_perf.py capture --out <klasör> [--seconds 470] [--save <kayıt.json>]
         [--top] [--burn "60:8 150:4"] [--burn-sec 10]
      Uygulamayı durdurur; --save verilirse telefondaki kaydı <klasör>/save_backup'a yedekleyip
      verilen kaydı yazar (debug yapısı, run-as); günlüğü temizler; oyunu
      açar ve süre boyunca <klasör>'e yazar: log.txt (tam `logcat -v epoch`), tel.txt (0,25 sn'de
      bir telemetri), top.txt (--top: ≈ 4 sn'de bir en yoğun iş parçacıkları; kendisi de yük
      bindirir), burn.txt (--burn: "sn:çekirdek" anlarında yapay CPU yükü, nedensellik denemesi).
      Bittiğinde (yarıda kesilse de) uygulamayı durdurur, yedeklenen kaydı geri yükler.
      Telefonun hiçbir ayarına dokunmaz. --out zorunlu (tam günlük başka uygulamaların
      satırlarını da içerir; depoya girmez).
  python -I tools/phone_perf.py analyze <klasör> [<klasör> ...] [--detail]
      Her tur için takılma kümeleri (aralarında ≤ 2 sn, ≥ 5 takılma), kümenin içinde ve 10 sn
      öncesinde telemetri, yoğun iş parçacıkları, yapay yük pencereleri; sonda bütün turların
      saniyeleri toplam CPU kullanımı bantlarına göre (doz-yanıt).
  python -I tools/phone_perf.py --self-test
      Hesapları yapay veriyle dener (CPU yüzdesi, kümeleme, bantlar).
"""
import os
import re
import statistics
import subprocess
import sys
import threading
import time
from collections import Counter, defaultdict
from pathlib import Path

ADB = Path(os.environ.get("LOCALAPPDATA", "")) / "Android" / "Sdk" / "platform-tools" / "adb.exe"
PACKAGE = "com.gravityhopper.dev"
ACTIVITY = PACKAGE + "/com.godot.game.GodotAppLauncher"
SAVE_FILES = ("savegame_debug.json", "savegame_debug.bak")
## Küme: aralarında en çok CLUSTER_GAP_SEC olan, en az CLUSTER_MIN takılmalık dizi.
CLUSTER_GAP_SEC = 2.0
CLUSTER_MIN = 5
## 120 Hz'de bir kare (ms); takılmanın "fazla" süresi bunun üstü.
FRAME_MS = 1000.0 / 120.0
CPU_BANDS = [(0, 60), (60, 70), (70, 80), (80, 90), (90, 101)]
## Telemetri satırı: zaman, GPU dolu/toplam, küçük ve büyük çekirdek frekansı ve sınırı (kHz),
## GPU / CPU / pil sıcaklığı (m°C), /proc/stat toplam satırının ilk yedi alanı.
TEL_FIELDS = 17
## Redmi Note 12 4G (Snapdragon 685): policy0 küçük, policy4 büyük çekirdekler; bölge 16 GPU, 11
## CPU kümesi, 24 pil. Başka telefonda bölge numaraları `thermal_zone*/type`'tan bulunur.
TEL_SCRIPT = """end=$((${EPOCHREALTIME%%.*}+%(sec)d))
k=/sys/class/kgsl/kgsl-3d0/gpubusy; c=/sys/devices/system/cpu/cpufreq; z=/sys/class/thermal
while [ ${EPOCHREALTIME%%.*} -lt $end ]; do
 read gb gt < $k; read f0 < $c/policy0/scaling_cur_freq; read f4 < $c/policy4/scaling_cur_freq
 read m0 < $c/policy0/scaling_max_freq; read m4 < $c/policy4/scaling_max_freq
 read tg < $z/thermal_zone16/temp; read tc < $z/thermal_zone11/temp; read tb < $z/thermal_zone24/temp
 read cpu u n s i w q sq rest < /proc/stat
 echo "$EPOCHREALTIME $gb $gt $f0 $f4 $m0 $m4 $tg $tc $tb $u $n $s $i $w $q $sq"
 sleep 0.25
done"""
TOP_SCRIPT = """end=$((${EPOCHREALTIME%%.*}+%(sec)d))
while [ ${EPOCHREALTIME%%.*} -lt $end ]; do
 echo "T $EPOCHREALTIME"; top -H -b -n 1 -m 12 -s 2 -o TID,%%CPU,CMD,NAME | tail -12; sleep 2
done"""
BURN_SCRIPT = """echo "BURN start n=%(n)d $EPOCHREALTIME"; i=0
while [ $i -lt %(n)d ]; do
 (e=$((${EPOCHREALTIME%%.*}+%(sec)d)); while [ ${EPOCHREALTIME%%.*} -lt $e ]; do :; done) &
 i=$((i+1))
done; wait; echo "BURN end n=%(n)d $EPOCHREALTIME\""""
LOG_LINE = re.compile(r"^\s*(\d+\.\d+)\s+\d+\s+\d+\s+(\w)\s+(.+?)\s*:\s(.*)$")
KV = re.compile(r"(\w+)=([-+\w.]+)")


def _adb(serial: str, *args: str, **kw) -> subprocess.CompletedProcess:
    return subprocess.run([str(ADB), "-s", serial, *args], **kw)


def parse_burns(burn: str) -> list:
    """'60:8 150:4' → [(60, 8), (150, 4)]: tur başından saniye ve çekirdek; bozuk yazım hemen hata."""
    burns = [tuple(int(x) for x in spec.split(":")) for spec in burn.split()]
    if any(len(b) != 2 or b[1] < 1 for b in burns):
        raise ValueError("--burn yazımı 'sn:çekirdek', ör. \"60:8 150:4\"")
    return burns


def capture(out: Path, seconds: int, serial: str, save: str, top: bool, burn: str,
        burn_sec: int) -> None:
    burns = parse_burns(burn)
    out.mkdir(parents=True, exist_ok=True)
    _adb(serial, "shell", "am", "force-stop", PACKAGE, check=True)
    backup = out / "save_backup"
    if save:
        # Telefondaki kayıt önce yedeklenir, tur bitince (yarıda kesilse de) geri yüklenir.
        data = Path(save).read_bytes()
        backup.mkdir(exist_ok=True)
        for name in SAVE_FILES:
            old = _adb(serial, "exec-out", "run-as", PACKAGE, "sh", "-c",
                    "test -f files/%s && cat files/%s" % (name, name), capture_output=True).stdout
            if old:
                (backup / name).write_bytes(old)
        for name in SAVE_FILES:
            _write_save(serial, name, data)
    procs = []
    files = []
    stop = threading.Event()
    burner = None

    def start(name: str, args: list) -> None:
        f = open(out / name, "wb")
        files.append(f)
        procs.append(subprocess.Popen([str(ADB), "-s", serial, *args], stdout=f,
                stderr=subprocess.STDOUT))

    def run_burns() -> None:
        began = time.monotonic()
        with open(out / "burn.txt", "wb") as f:
            for at, cores in burns:
                if stop.wait(max(0.0, at - (time.monotonic() - began))):
                    return
                f.write(_adb(serial, "shell", BURN_SCRIPT % {"n": cores, "sec": burn_sec},
                        capture_output=True).stdout)

    try:
        _adb(serial, "logcat", "-c", check=True)
        start("log.txt", ["logcat", "-v", "epoch"])
        start("tel.txt", ["shell", TEL_SCRIPT % {"sec": seconds}])
        if top:
            start("top.txt", ["shell", TOP_SCRIPT % {"sec": seconds}])
        if burns:
            burner = threading.Thread(target=run_burns, daemon=True)
            burner.start()
        _adb(serial, "shell", "am", "start", "-n", ACTIVITY, capture_output=True, check=True)
        time.sleep(6)
        focus = _adb(serial, "shell", "dumpsys window | grep mCurrentFocus", capture_output=True,
                text=True).stdout.strip()
        print("odak:", focus)
        if PACKAGE not in focus:
            print("UYARI: oyun ön planda değil; tur geçersiz sayılmalı.")
        for p in procs[1:]:
            p.wait()
        if burner:
            burner.join()
        time.sleep(2)
    finally:
        # Yarıda kesilse de (hata, Ctrl+C) arka plan süreçleri kapanır, oyun durur, kayıt geri gelir.
        stop.set()
        for p in procs:
            if p.poll() is None:
                p.terminate()
            p.wait()
        for f in files:
            f.close()
        _adb(serial, "shell", "am", "force-stop", PACKAGE)
        if save:
            for name in SAVE_FILES:
                if (backup / name).exists():
                    _write_save(serial, name, (backup / name).read_bytes())
                    print("kayıt geri yüklendi:", name)
    text = (out / "log.txt").read_text(encoding="utf-8", errors="replace")
    print("bitti: %d evre, %d takılma" % (text.count("PERF phase="), text.count("PERF spike")))


def _write_save(serial: str, name: str, data: bytes) -> None:
    _adb(serial, "exec-in", "run-as", PACKAGE, "sh", "-c", "cat > files/" + name, input=data,
            check=True)


def cpu_percent(prev: list, cur: list) -> float | None:
    """İki /proc/stat örneği arasında toplam CPU kullanımı (%): user nice system idle iowait irq
    softirq alanlarından; boş = idle + iowait. Zaman geçmediyse None."""
    busy = lambda v: v[0] + v[1] + v[2] + v[5] + v[6]
    total = lambda v: busy(v) + v[3] + v[4]
    dt = total(cur) - total(prev)
    return (busy(cur) - busy(prev)) / dt * 100.0 if dt > 0 else None


def clusters(spikes: list) -> list:
    """Zamana göre sıralı takılmaları kümelere ayırır (aralık ≤ CLUSTER_GAP_SEC, ≥ CLUSTER_MIN)."""
    out, cur = [], []
    for s in spikes:
        if cur and s["t"] - cur[-1]["t"] > CLUSTER_GAP_SEC:
            if len(cur) >= CLUSTER_MIN:
                out.append(cur)
            cur = []
        cur.append(s)
    if len(cur) >= CLUSTER_MIN:
        out.append(cur)
    return out


def band_of(cpu: float) -> tuple | None:
    for band in CPU_BANDS:
        if band[0] <= cpu < band[1]:
            return band
    return None


def load(folder: Path) -> dict:
    run = {"start": None, "spikes": [], "phases": 0, "system": [], "tel": [], "top": [], "burn": []}
    for line in open(folder / "log.txt", encoding="utf-8", errors="replace"):
        m = LOG_LINE.match(line)
        if not m:
            continue
        t, level, tag, msg = float(m.group(1)), m.group(2), m.group(3), m.group(4)
        if tag != "godot":
            run["system"].append((t, level, tag, msg))
        elif "EVENT run_started" in msg and run["start"] is None:
            run["start"] = t
        elif msg.startswith("PERF spike"):
            d = {k: float(v) for k, v in KV.findall(msg) if k not in ("phase", "sector", "t")}
            for old in ("process", "physics"):  # M6-10 ilk günlükleri: aynı değer, eski ad
                if old + "_ms" in d:
                    d[old + "_max_1s_ms"] = d.pop(old + "_ms")
            d["t"] = t
            d["sector"] = int(re.search(r"sector=(\d+)", msg).group(1))
            run["spikes"].append(d)
        elif msg.startswith("PERF phase="):
            run["phases"] += 1
    prev = None
    for line in open(folder / "tel.txt", encoding="utf-8", errors="replace"):
        p = line.split()
        if len(p) != TEL_FIELDS:
            continue
        v = [float(x) for x in p]
        run["tel"].append({
            "t": v[0], "gpu": v[1] / v[2] * 100.0 if v[2] else None, "f0": v[3] / 1e3,
            "f4": v[4] / 1e3, "m0": v[5] / 1e3, "m4": v[6] / 1e3, "tg": v[7] / 1e3, "tc": v[8] / 1e3,
            "tb": v[9] / 1e3, "cpu": cpu_percent(prev, v[10:]) if prev else None,
        })
        prev = v[10:]
    if (folder / "top.txt").exists():
        cur = None
        for line in open(folder / "top.txt", encoding="utf-8", errors="replace"):
            if line.startswith("T "):
                cur = {"t": float(line.split()[1]), "rows": []}
                run["top"].append(cur)
            elif cur is not None:
                p = line.split(None, 2)
                if len(p) == 3 and re.fullmatch(r"\d+(\.\d+)?", p[1]):
                    cur["rows"].append((float(p[1]), p[2].strip()))
    if (folder / "burn.txt").exists():
        begin = {}
        for line in open(folder / "burn.txt", encoding="utf-8", errors="replace"):
            p = line.split()
            if len(p) == 4 and p[0] == "BURN":
                if p[1] == "start":
                    begin = {"n": int(p[2][2:]), "a": float(p[3])}
                elif begin:
                    run["burn"].append({**begin, "b": float(p[3])})
    return run


def _median(rows: list, key: str) -> float:
    v = [r[key] for r in rows if r[key] is not None]
    return statistics.median(v) if v else float("nan")


def _tel_text(rows: list) -> str:
    return ("CPU %%%.0f · GPU dolu %%%.0f · büyük çekirdek %.0f MHz (sınır %.0f) · küçük %.0f (%.0f) · "
            "GPU %.1f° CPU %.1f° pil %.1f°") % tuple(_median(rows, k) for k in (
                "cpu", "gpu", "f4", "m4", "f0", "m0", "tg", "tc", "tb"))


def _spike_text(spikes: list) -> str:
    mean = lambda k: statistics.mean(s[k] for s in spikes)
    return ("%d kare %.0f–%.0f ms, fazla %.0f ms; ort. çizim %.1f · sonrası %.1f · son 1 sn'nin en "
            "uzun işlemi %.1f · fizik %.1f ms") % (len(spikes), min(s["ms"] for s in spikes),
                max(s["ms"] for s in spikes), sum(s["ms"] - FRAME_MS for s in spikes),
                mean("draw_ms"), mean("after_draw_ms"), mean("process_max_1s_ms"), mean("physics_max_1s_ms"))


def analyze(folders: list, detail: bool) -> None:
    bands = defaultdict(lambda: [0, 0, 0.0])  # saniye, takılmalı saniye, fazla ms
    for folder in folders:
        run = load(Path(folder))
        start, spikes, tel = run["start"], run["spikes"], run["tel"]
        if start is None or not tel:
            print("\n%s: tur başı ya da telemetri yok" % folder)
            continue
        found = clusters(spikes)
        print("\n=== %s: %.0f sn, %d evre, %d takılma, %d küme" % (
                folder, tel[-1]["t"] - start, run["phases"], len(spikes), len(found)))
        print("  tur: " + _tel_text([r for r in tel if r["t"] >= start]))
        for i, c in enumerate(found, 1):
            a, b = c[0]["t"] - c[0]["ms"] / 1000.0, c[-1]["t"]
            print("  Küme %d: tur başından %.1f–%.1f sn (S%d): %s" % (
                    i, a - start, b - start, c[0]["sector"], _spike_text(c)))
            print("    içinde    : " + _tel_text([r for r in tel if a <= r["t"] <= b]))
            print("    10 sn önce: " + _tel_text([r for r in tel if a - 10 <= r["t"] < a - 1]))
            hot, n = Counter(), 0
            for sample in run["top"]:
                if a - 2 <= sample["t"] <= b + 1:
                    n += 1
                    for pct, name in sample["rows"][:8]:
                        hot[name] += pct
            for name, pct in hot.most_common(6):
                print("      %%%5.1f  %s" % (pct / n, name[:80]))
            if detail:
                for t, level, tag, msg in run["system"]:
                    if a - 3 <= t <= b + 1 and level in "WE":
                        print("      %7.2f %s %s: %s" % (t - start, level, tag, msg[:140]))
        for w in run["burn"]:
            inside = [s for s in spikes if w["a"] <= s["t"] <= w["b"] + 0.5]
            before = [s for s in spikes if w["a"] - 20 <= s["t"] < w["a"] - 5]
            print("  Yapay yük %d çekirdek, %.1f–%.1f sn: %d takılma, fazla %.0f ms (önceki 15 sn: %d) · %s"
                    % (w["n"], w["a"] - start, w["b"] - start, len(inside),
                        sum(s["ms"] - FRAME_MS for s in inside), len(before),
                        _tel_text([r for r in tel if w["a"] <= r["t"] <= w["b"]])))
        per_sec = defaultdict(list)
        for r in tel:
            if r["t"] >= start + 2 and r["cpu"] is not None:
                per_sec[int(r["t"] - start)].append(r["cpu"])
        hits, extra = Counter(), defaultdict(float)
        for s in spikes:
            hits[int(s["t"] - start)] += 1
            extra[int(s["t"] - start)] += s["ms"] - FRAME_MS
        for sec, v in per_sec.items():
            band = band_of(sum(v) / len(v))
            if band is None:
                continue
            b = bands[band]
            b[0] += 1
            b[1] += 1 if hits[sec] else 0
            b[2] += extra[sec]
    print("\nToplam CPU kullanımı → saniye · takılmalı saniye · saniyede fazla süre")
    for band in CPU_BANDS:
        s, w, ms = bands[band]
        if s:
            print("  %%%3d–%3d: %5d sn · %%%5.1f · %6.1f ms" % (band[0], min(band[1], 100), s,
                    w / s * 100.0, ms / s))


def self_test() -> None:
    # 4 çekirdeklik iki örnek: 300 meşgul + 100 boş birim → %75.
    assert abs(cpu_percent([0] * 7, [100, 0, 100, 80, 20, 50, 50]) - 75.0) < 1e-9
    assert cpu_percent([1] * 7, [1] * 7) is None  # zaman geçmedi
    sp = lambda t: {"t": t, "ms": 30.0}
    c = clusters([sp(t) for t in (1.0, 1.5, 2.0, 3.0, 4.9, 10.0, 11.0, 20.0, 20.1, 20.2, 20.3,
            20.4)])
    assert [len(x) for x in c] == [5, 5], c  # 10–11 iki takılma: küme değil
    assert clusters([sp(t) for t in (0, 1, 2, 3)]) == []
    assert band_of(59.9) == (0, 60) and band_of(90.0) == (90, 101) and band_of(100.0) == (90, 101)
    assert band_of(float("nan")) is None and band_of(-1.0) is None
    assert clusters([sp(t) for t in (0, 2, 4, 6, 8)]) != []  # tam 2 sn aralık kümeye girer
    assert parse_burns("60:8 150:4") == [(60, 8), (150, 4)] and parse_burns("") == []
    for bad in ("60", "60:0", "a:4"):
        try:
            parse_burns(bad)
        except ValueError:
            continue
        raise AssertionError(bad)
    print("SELF-TEST TAMAM")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    args = sys.argv[1:]
    if args[:1] == ["--self-test"]:
        self_test()
        return

    def opt(name: str, default: str = "") -> str:
        return args[args.index(name) + 1] if name in args else default

    if args[:1] == ["capture"] and opt("--out"):
        capture(Path(opt("--out")), int(opt("--seconds", "470")), opt("--serial", "ecde8b60"),
                opt("--save"), "--top" in args, opt("--burn"), int(opt("--burn-sec", "10")))
    elif args[:1] == ["analyze"]:
        analyze([a for a in args[1:] if not a.startswith("--")], "--detail" in args)
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == "__main__":
    main()
