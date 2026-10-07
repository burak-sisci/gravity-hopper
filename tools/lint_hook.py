"""Claude Code kancası (PostToolUse, Edit|Write): düzenlenen .gd dosyasını gdlint ile denetler.

Yalnızca sorun varsa konuşur: gdlint hata bulursa çıktısını stderr'e yazar ve 2 ile çıkar
(Claude Code bunu Claude'a gösterir). Dosya .gd değilse, proje dışındaysa, addons/ ya da
.godot/ altındaysa veya temizse sessizce 0 ile çıkar. Yalnızca standart kütüphane kullanır.
gdlint, proje dışındaki sanal ortamdan çalışır (architecture.md §13.1, M0-12).
"""

import json
import os
import subprocess
import sys
from pathlib import Path

SKIP_PARTS = {"addons", ".godot"}
BLOCKING_EXIT = 2


def gdlint_path() -> Path:
    local = os.environ.get("LOCALAPPDATA", "")
    return Path(local) / "gravity-hopper" / "venv" / "Scripts" / "gdlint.exe"


def main() -> int:
    # utf-8-sig: girdinin başında BOM varsa atılır (PowerShell boru hattı ekliyor).
    raw = sys.stdin.buffer.read().decode("utf-8-sig", errors="replace")
    try:
        data = json.loads(raw)
    except ValueError:
        return 0
    file_path = (data.get("tool_input") or {}).get("file_path") or ""
    if not file_path.endswith(".gd"):
        return 0

    project = Path(os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or ".").resolve()
    try:
        relative = Path(file_path).resolve().relative_to(project)
    except ValueError:
        return 0  # Proje dışındaki dosya
    if SKIP_PARTS & set(relative.parts):
        return 0

    linter = gdlint_path()
    if not linter.exists():
        print(f"gdlint bulunamadı: {linter} (kurulum: architecture.md §13.1)", file=sys.stderr)
        return BLOCKING_EXIT

    result = subprocess.run(
        [str(linter), str(relative)],
        cwd=project,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if result.returncode == 0:
        return 0
    print(f"gdlint {relative}:", file=sys.stderr)
    print((result.stdout + result.stderr).strip(), file=sys.stderr)
    return BLOCKING_EXIT


if __name__ == "__main__":
    sys.exit(main())
