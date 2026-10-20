"""Enstrüman kayıtları (M3-21, architecture.md §8.3, ADR-065).

Kaynak: Versilian Studios'un CC0 kütüphaneleri, sürümü sabit commit'lerden:
  VCSL (Versilian Community Sample Library) ve VSCO 2 CE (Community Edition).
Dosyalar proje dışında önbelleğe iner (%LOCALAPPDATA%/gravity-hopper/music_src); depoya
girmez. Godot proje klasöründeki her dosyayı içe aktardığı için içeri hiç kopyalanmaz.
"""

import json
import os
import re
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

REPOS: dict[str, tuple[str, str]] = {
    "vcsl": ("sgossner/VCSL", "c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e"),
    "vsco": ("sgossner/VSCO-2-CE", "440300901dfe9275fd84e0b7763af1f8443ae62e"),
}
CACHE = Path(os.environ["LOCALAPPDATA"]) / "gravity-hopper" / "music_src"
WORKERS = 8


def tree(repo: str) -> list[str]:
    """Kütüphanedeki bütün dosya yolları (ağaç bir kez indirilir)."""
    name, sha = REPOS[repo]
    path = CACHE / f"{repo}_{sha[:7]}_tree.json"
    if not path.exists():
        url = f"https://api.github.com/repos/{name}/git/trees/{sha}?recursive=1"
        with urllib.request.urlopen(url, timeout=60) as response:
            data = json.loads(response.read())
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps([e["path"] for e in data["tree"] if e["type"] == "blob"]),
                        encoding="utf-8")
    return json.loads(path.read_text(encoding="utf-8"))


def local(repo: str, rel: str) -> Path:
    return CACHE / repo / rel


def _download(repo: str, rel: str) -> Path:
    target = local(repo, rel)
    if target.exists():
        return target
    name, sha = REPOS[repo]
    url = f"https://raw.githubusercontent.com/{name}/{sha}/{urllib.parse.quote(rel)}"
    target.parent.mkdir(parents=True, exist_ok=True)
    part = target.with_suffix(".part")
    with urllib.request.urlopen(url, timeout=120) as response:
        part.write_bytes(response.read())
    if part.read_bytes()[:4] != b"RIFF":
        part.unlink()
        raise SystemExit(f"WAV değil: {repo}/{rel}")
    part.replace(target)
    return target


def fetch(repo: str, folder: str, pattern: str = r".*") -> list[Path]:
    """Klasördeki (alt klasörler dahil), adı desene uyan WAV dosyaları; eksikler indirilir."""
    regex = re.compile(pattern)
    rels = [p for p in tree(repo) if p.startswith(folder + "/") and p.lower().endswith(".wav")
            and regex.search(p.rsplit("/", 1)[-1])]
    if not rels:
        raise SystemExit(f"dosya yok: {repo}/{folder} ({pattern})")
    with ThreadPoolExecutor(WORKERS) as pool:
        return sorted(pool.map(lambda rel: _download(repo, rel), rels))
