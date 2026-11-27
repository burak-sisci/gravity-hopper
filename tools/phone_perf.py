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
  python -I tools/phone_perf.py thermal <klasör>
      Uzun ısınma turu (M6-05; ölçüm yapısı `--perf=60 --quality=high`, evre = 1 dk, kalite
      sabit): dakika dakika kare süresi (ham ve takılmasız), GPU / CPU / pil sıcaklığı, büyük
      çekirdeğin frekans sınırı (ısıl kısma), toplam CPU; ilk ve son THERMAL_MIN dakikanın kareye
      göre ağırlıklı ortalaması ve kabul ölçütü (son ≤ ilk × 1,10 ve ≤ 10 ms; kümesiz evrelerin
      takılmasız ortalaması). capture tur boyunca 30 sn'de bir ön plandaki pencereyi ve görünür üst katman
      penceresi sayısını focus.txt'ye yazar. Çıkış: 0 tutuyor, 1 tutmuyor, 2 geçersiz (kısa,
      karışık kalite, evre 1 dk değil, oyun ön planda değil).
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
## Üst katman: görünür durumdaki (isReadyForDisplay()=true) APPLICATION_OVERLAY pencereleri; sistemin
## görünmez katman penceresi sayılmaz (M6-05 yeniden ölçüm). windows= dökümdeki pencere sayısı:
## 0 ise döküm boş ya da biçim değişmiş, üst katman ölçülmemiş sayılır.
FOCUS_SCRIPT = """end=$((${EPOCHREALTIME%%.*}+%(sec)d))
while [ ${EPOCHREALTIME%%.*} -lt $end ]; do
 o=$(dumpsys window windows | awk '/^ *Window #[0-9]/{v=0; w++} /ty=APPLICATION_OVERLAY/{v=1} v && /isReadyForDisplay[(][)]=true/{n++; v=0} END{print n+0 " windows=" w+0}')
 echo "$EPOCHREALTIME overlays=$o $(dumpsys window | grep mCurrentFocus)"; sleep 30
done"""
## Isınma ölçütü (M6-05): ilk ve son bu kadar dakika karşılaştırılır; son en çok THERMAL_WORSE
## kat kötü ve THERMAL_MAX_MS'yi aşmaz.
THERMAL_MIN = 5
THERMAL_WORSE = 1.10
THERMAL_MAX_MS = 10.0
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
        start("focus.txt", ["shell", FOCUS_SCRIPT % {"sec": seconds}])
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
    run = {"start": None, "spikes": [], "phases": 0, "system": [], "tel": [], "top": [], "burn": [],
            "phase_rows": [], "focus": []}
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
            d["phase"] = int(re.search(r"phase=(\d+)", msg).group(1))
            run["spikes"].append(d)
        elif msg.startswith("PERF phase="):
            run["phases"] += 1
            d = dict(KV.findall(msg))
            run["phase_rows"].append({"t": t, "phase": int(d["phase"]), "q": d["q"],
                    "sector": int(d["sector"]), "frames": int(d["frames"]),
                    "avg_ms": float(d["avg_ms"]), "p95_ms": float(d["p95_ms"])})
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
    if (folder / "focus.txt").exists():
        for line in open(folder / "focus.txt", encoding="utf-8", errors="replace"):
            sample = focus_sample(line)
            if sample is not None:
                run["focus"].append(sample)
    return run


def focus_sample(line: str):
    """focus.txt satırı: zaman [overlays=N windows=W] mCurrentFocus=… → (zaman, oyun ön planda mı,
    görünür üst katman sayısı ya da None). Odak satırı boşsa oyun ön planda sayılmaz; windows=0 ise
    döküm boştur, üst katman ölçülmemiş sayılır (None)."""
    p = line.split(None, 1)
    if not p or not re.fullmatch(r"\d+\.\d+", p[0]):
        return None
    rest = p[1] if len(p) == 2 else ""
    m = re.search(r"overlays=(\d+)", rest)
    w = re.search(r"windows=(\d+)", rest)
    measured = m is not None and (w is None or int(w.group(1)) > 0)
    return (float(p[0]), PACKAGE in rest, int(m.group(1)) if measured else None)


def phase_minutes(phase_rows: list, spikes: list) -> list:
    """Evre başına ham ve takılmasız ortalama (ms). Takılmasız: takılma karelerinin (PERF spike,
    aynı evre) süresi ve sayısı çıkarılır; başka uygulamaların CPU kümesi ısınmadan ayrılsın."""
    by_phase = defaultdict(list)
    for s in spikes:
        by_phase[int(s.get("phase", -1))].append(s["ms"])
    clustered = {int(s.get("phase", -1)) for c in clusters(spikes) for s in c}
    out = []
    for r in phase_rows:
        sp = by_phase.get(r["phase"], [])
        total = r["avg_ms"] * r["frames"]
        clean_n = r["frames"] - len(sp)
        clean = (total - sum(sp)) / clean_n if clean_n > 0 else float("nan")
        out.append({**r, "spikes": len(sp), "clean_ms": clean, "cluster": r["phase"] in clustered})
    return out


def weighted(rows: list, key: str) -> float:
    """Kare sayısına göre ağırlıklı ortalama (takılmasızda takılmalar sayılmaz)."""
    if key == "clean_ms":
        n = sum(r["frames"] - r["spikes"] for r in rows)
        return sum(r["clean_ms"] * (r["frames"] - r["spikes"]) for r in rows) / n if n else float("nan")
    n = sum(r["frames"] for r in rows)
    return sum(r[key] * r["frames"] for r in rows) / n if n else float("nan")


def thermal_verdict(first: float, last: float) -> bool:
    return last <= first * THERMAL_WORSE and last <= THERMAL_MAX_MS


def thermal(folder: Path) -> int:
    """0: ölçüt tutuyor, 1: tutmuyor, 2: tur geçersiz (kısa, karışık kalite, evre 1 dk değil, oyun
    ön planda değil)."""
    run = load(folder)
    tel, start = run["tel"], run["start"]
    if start is None:
        print("%s: tur başı yok" % folder)
        return 2
    # Tur başından önceki evre, takılma ve ön plan örneği (menü, açılış) sayılmaz.
    rows = phase_minutes([r for r in run["phase_rows"] if r["t"] >= start],
            [s for s in run["spikes"] if s["t"] >= start])
    focus = [f for f in run["focus"] if f[0] >= start]
    qualities = sorted({r["q"] for r in rows})
    gaps = [b["t"] - a["t"] for a, b in zip(rows, rows[1:])]
    if len(rows) < 2 * THERMAL_MIN or len(qualities) != 1 or abs(statistics.median(gaps) - 60.0) > 2.0:
        print("%s: geçersiz ölçüm: %d evre, kalite %s, evre aralığı %.1f sn (gerekli: ≥ %d evre, tek "
                "kalite, 60 sn; --perf=60 --quality=…)" % (folder, len(rows), "/".join(qualities),
                    statistics.median(gaps) if gaps else 0.0, 2 * THERMAL_MIN))
        return 2
    away = [f for f in focus if not f[1]]
    overlays = [f[2] for f in focus if f[2] is not None]
    print("=== %s: %d dakika, kalite %s, ön plan denetimi %d örnek, %d dışarıda, üst katman %s" % (
            folder, len(rows), qualities[0], len(focus), len(away),
            "%d–%d" % (min(overlays), max(overlays)) if overlays else "ölçülmedi"))
    print(" dk  sektör  kare   ham ms  takılmasız  p95   takılma(K: küme)  GPU°  CPU°  pil°  büyük çekirdek sınırı MHz  CPU%")
    prev_t = start
    for i, r in enumerate(rows, 1):
        w = [x for x in tel if prev_t < x["t"] <= r["t"]]
        prev_t = r["t"]
        mx = lambda k: max((x[k] for x in w if x[k] is not None), default=float("nan"))
        mn = lambda k: min((x[k] for x in w if x[k] is not None), default=float("nan"))
        print("%3d  S%d  %6d  %7.2f  %9.2f  %5.2f  %6d%s  %5.1f %5.1f %5.1f  %5.0f–%5.0f  %4.0f" % (
                i, r["sector"], r["frames"], r["avg_ms"], r["clean_ms"], r["p95_ms"], r["spikes"],
                " K" if r["cluster"] else "  ",
                _median(w, "tg"), _median(w, "tc"), mx("tb"), mn("m4"), mx("m4"), _median(w, "cpu")))
    first, last = rows[:THERMAL_MIN], rows[-THERMAL_MIN:]
    # Resmî ölçüt kümesiz evrelerle (ADR-110: başka uygulamaların CPU kümesi ısınma değildir);
    # ham ve takılmasız ortalama bilgi için.
    calm = lambda rs: [r for r in rs if not r["cluster"]]
    ok = bool(calm(first)) and bool(calm(last))
    for key, name, a_rows, b_rows in (
            ("clean_ms", "kümesiz evreler, takılmasız (ölçüt)", calm(first), calm(last)),
            ("avg_ms", "kümesiz evreler, ham", calm(first), calm(last)),
            ("avg_ms", "ham", first, last), ("clean_ms", "takılmasız", first, last)):
        a, b = weighted(a_rows, key), weighted(b_rows, key)
        good = thermal_verdict(a, b)
        if name.endswith("(ölçüt)"):
            ok = ok and good
            name += " %d+%d dk" % (len(a_rows), len(b_rows))
        print("İlk %d dk %s %.2f ms → son %d dk %.2f ms (%+.1f%%; ölçüt ≤ %%%d kötü ve ≤ %.0f ms): %s" % (
                THERMAL_MIN, name, a, THERMAL_MIN, b, (b / a - 1) * 100, round((THERMAL_WORSE - 1) * 100),
                THERMAL_MAX_MS, "TUTUYOR" if good else "TUTMUYOR"))
    t0 = [x for x in tel if start < x["t"] <= start + 60]
    t1 = [x for x in tel if rows[-1]["t"] - 60 < x["t"] <= rows[-1]["t"]]
    print("Sıcaklık ilk dk → son dk (medyan): GPU %.1f → %.1f°, CPU %.1f → %.1f°, pil %.1f → %.1f°" % (
            _median(t0, "tg"), _median(t1, "tg"), _median(t0, "tc"), _median(t1, "tc"),
            _median(t0, "tb"), _median(t1, "tb")))
    if away:
        print("GEÇERSİZ: oyun %d örnekte ön planda değil" % len(away))
        return 2
    if overlays and max(overlays) > 0:
        print("NOT: oyunun üstünde %d üst katman penceresi vardı (ekran birleştirici yükü, M6-10)."
                % max(overlays))
    print("SONUÇ: " + ("TUTUYOR" if ok else "TUTMUYOR"))
    return 0 if ok else 1


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
    # Isınma: takılmasız ortalama takılmaları çıkarır; ölçüt hem oran hem tavan.
    rows = phase_minutes([{"t": 0, "phase": 1, "q": "high", "sector": 6, "frames": 100,
            "avg_ms": 10.0, "p95_ms": 0}], [{"t": 0, "ms": 100.0, "phase": 1}])
    assert abs(rows[0]["clean_ms"] - 900.0 / 99) < 1e-9 and rows[0]["spikes"] == 1
    assert abs(weighted(rows, "clean_ms") - 900.0 / 99) < 1e-9
    assert not rows[0]["cluster"]  # tek takılma küme değil
    five = [{"t": 0.5 * i, "ms": 30.0, "phase": 2} for i in range(5)]
    two = [{"t": 0, "phase": p, "q": "high", "sector": 6, "frames": 100, "avg_ms": 9.0,
            "p95_ms": 0} for p in (1, 2)]
    assert [r["cluster"] for r in phase_minutes(two, five)] == [False, True]
    # Üç evreye yayılan küme: ortadaki evre de kümeli.
    long = [{"t": 1.5 * i, "ms": 30.0, "phase": 1 + i // 4} for i in range(12)]
    three = [{**two[0], "phase": p} for p in (1, 2, 3)]
    assert [r["cluster"] for r in phase_minutes(three, long)] == [True, True, True]
    assert thermal_verdict(9.0, 9.9) and not thermal_verdict(9.0, 9.95)
    assert thermal_verdict(9.95, 10.0) and not thermal_verdict(9.95, 10.01)
    # Ön plan / üst katman satırı: boş döküm (windows=0) ölçülmemiş, eski biçim (windows yok) geçerli.
    g = "mCurrentFocus=Window{1 u0 %s/x}" % PACKAGE
    assert focus_sample("1.5 overlays=0 windows=0 " + g) == (1.5, True, None)
    assert focus_sample("2.5 overlays=1 windows=40 " + g) == (2.5, True, 1)
    assert focus_sample("3.5 overlays=0   mCurrentFocus=Window{2 u0 home/L}") == (3.5, False, 0)
    assert focus_sample("4.5\n") == (4.5, False, None) and focus_sample("odak yok") is None
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
    elif args[:1] == ["thermal"] and len(args) == 2:
        sys.exit(thermal(Path(args[1])))
    elif args[:1] == ["analyze"]:
        analyze([a for a in args[1:] if not a.startswith("--")], "--detail" in args)
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == "__main__":
    main()
