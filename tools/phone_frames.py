"""Telefondan hareketli kare dizisi (M4-04): oyunun hareketini Redmi'de görmek için.

`adb screenrecord --output-format=frames` ham RGB kareleri borudan okunur (kurulum gerekmez,
ffmpeg yok). Her kayıt: uint32 uzunluk (16 + piksel) · uint32 genişlik, yükseklik, satır baytı,
piksel baytı (3) · RGB pikseller. Her `--step`'inci kare PNG olarak yazılır; `--sheet` ile
küçültülmüş kareler tek bir tablo resminde (6 sütun) toplanır. Boru yavaş okundukça
screenrecord bekler: kayıt `--seconds`'tan uzun sürebilir ve kare aralıkları düzensizdir.
Yalnızca görsel kanıt içindir (bir şeyin hareket ettiği görülür); süre ölçümü için değildir.
Yalnızca kayıt yapar, telefona dokunmaz. Oyun ön planda değilse kaydetmez (kullanıcının
ekranı kaydedilmesin). Yalnızca standart kütüphane kullanır.

Kullanım: python tools/phone_frames.py <çıktı klasörü> [--seconds 10] [--step 4] [--sheet]
"""

import argparse
import os
import struct
import subprocess
import sys
import time
import zlib

SERIAL = "ecde8b60"
PACKAGE = "com.gravityhopper.dev"
SIZE = (270, 600)
HEADER = struct.Struct("<IIII")
SHEET_COLS = 6
SHEET_SHRINK = 2
# Kayıt süresinin üstüne tanınan pay (sn); aşılırsa kayıt kesilir.
TIMEOUT_MARGIN = 20


def adb_path() -> str:
    return os.path.join(os.environ.get("LOCALAPPDATA", ""), "Android", "Sdk", "platform-tools",
                        "adb.exe")


def write_png(path: str, width: int, height: int, rows: list) -> None:
    raw = b"".join(b"\x00" + row for row in rows)

    def chunk(tag: bytes, data: bytes) -> bytes:
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 6)))
        f.write(chunk(b"IEND", b""))


def game_in_front(adb: str) -> bool:
    windows = subprocess.run([adb, "-s", SERIAL, "shell", "dumpsys", "window"],
                             capture_output=True, text=True, encoding="utf-8", errors="replace",
                             stdin=subprocess.DEVNULL).stdout
    focus = [line for line in windows.splitlines() if "mCurrentFocus" in line]
    return bool(focus) and PACKAGE in focus[0] and "isKeyguardShowing=true" not in windows


def frame_rows(record: bytes) -> tuple:
    width, height, stride, _bpp = HEADER.unpack_from(record)
    pixels = record[HEADER.size:]
    rows = [pixels[y * stride:y * stride + width * 3] for y in range(height)]
    return width, height, rows


def shrink(width: int, rows: list) -> list:
    # En yakın komşu: her SHEET_SHRINK satırdan ve pikselden biri.
    out = []
    for row in rows[::SHEET_SHRINK]:
        out.append(b"".join(row[x * 3:x * 3 + 3] for x in range(0, width, SHEET_SHRINK)))
    return out


def write_sheet(path: str, thumbs: list) -> None:
    cell_w = len(thumbs[0][0]) // 3
    cell_h = len(thumbs[0])
    cols = min(SHEET_COLS, len(thumbs))
    blank = b"\x00" * (cell_w * 3)
    rows = []
    for start in range(0, len(thumbs), cols):
        group = thumbs[start:start + cols]
        group += [[blank] * cell_h] * (cols - len(group))
        for y in range(cell_h):
            rows.append(b"".join(thumb[y] for thumb in group))
    write_png(path, cell_w * cols, len(rows), rows)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("out")
    parser.add_argument("--seconds", type=int, default=10)
    parser.add_argument("--step", type=int, default=4)
    parser.add_argument("--sheet", action="store_true")
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)
    adb = adb_path()
    # Sunucu borudan bağımsız başlasın; yoksa boruyu açık tutar, okuma hiç bitmez (deploy.ps1).
    subprocess.run([adb, "start-server"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if not game_in_front(adb):
        print("OYUN ÖN PLANDA DEĞİL: kayıt yapılmadı")
        return 2
    command = [adb, "-s", SERIAL, "exec-out", "screenrecord", "--output-format=frames",
               "--size", "%dx%d" % SIZE, "--time-limit", str(args.seconds), "-"]
    proc = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    deadline = time.time() + args.seconds + TIMEOUT_MARGIN
    index = 0
    thumbs = []
    while time.time() < deadline:
        head = proc.stdout.read(4)
        if len(head) < 4:
            break
        (length,) = struct.unpack("<I", head)
        record = proc.stdout.read(length)
        if len(record) < length:
            break
        if index % args.step == 0:
            width, height, rows = frame_rows(record)
            write_png(os.path.join(args.out, "f%04d.png" % index), width, height, rows)
            if args.sheet:
                thumbs.append(shrink(width, rows))
        index += 1
    proc.kill()
    if args.sheet and thumbs:
        write_sheet(os.path.join(args.out, "sheet.png"), thumbs)
    print("kare %d, yazılan %d" % (index, (index + args.step - 1) // args.step))
    return 0 if index > 0 else 1


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
