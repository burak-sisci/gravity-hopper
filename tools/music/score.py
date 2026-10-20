"""Beste yazımı (M3-21): notalar, ezgi satırları, ritim kalıpları.

Zaman vuruş cinsindendir (4/4; ölçü = 4 vuruş). at(ölçü, vuruş) 1'den sayar: at(1) parçanın
başı. Ezgi satırı: "A4:1.5 G4:.5 r:1 D5:2~ C5:1" (nota:süre; r = sus; ~ sonraki notaya bağlı;
! vurgulu; ? hafif; < alttan kayarak giriş; ^ önce süs notası, ör. ^Bb4|A4:1).
Ritim kalıbı: on altılık başına bir harf ("D-T- k-T- D-k- T-k-"; boşluklar okunmaz, - sus).
İnsan eli: küçük zaman ve güç oynaması, tohumlu (parça her üretimde aynı çıkar).
"""

import random
from collections import defaultdict

from engine import Event, note_number

BEATS_PER_BAR = 4


def at(bar: int, beat: float = 1.0) -> float:
    return (bar - 1) * BEATS_PER_BAR + (beat - 1)


def n(name: str) -> int:
    return note_number(name)


class Score:
    def __init__(self, bpm: float, bars: int, seed: int):
        self.bpm = bpm
        self.bars = bars
        self.events: dict[str, list[Event]] = defaultdict(list)
        self.rng = random.Random(seed)

    @property
    def beats(self) -> int:
        return self.bars * BEATS_PER_BAR

    def _human(self, sd: float) -> float:
        return max(-2.5 * sd, min(2.5 * sd, self.rng.gauss(0.0, sd)))

    def note(self, inst: str, beat: float, dur: float, key: int | str, vel: float = 0.8,
             human: float = 0.006, **kw) -> None:
        vel = max(0.05, min(1.0, vel + self._human(0.03)))
        self.events[inst].append(Event(beat % self.beats, dur, key, vel,
                                       offset=self._human(human), **kw))

    def line(self, inst: str, beat: float, text: str, vel: float = 0.75, transpose: int = 0,
             human: float = 0.008, grace: float = 0.07, slur: bool = False,
             slide_in: tuple[float, float] = (-1.0, 0.09), **kw) -> float:
        """Ezgi satırı; satırın bittiği vuruşu döndürür. slur: susa kadar bütün notalar bağlı."""
        pos = beat
        legato_next = False
        for token in text.split():
            name, dur_text = token.split(":")
            grace_note = None
            if name.startswith("^"):
                grace_note, name = name[1:].split("|")
            flags = ""
            while dur_text and dur_text[-1] in "~!?<":
                flags += dur_text[-1]
                dur_text = dur_text[:-1]
            if "/" in dur_text:
                num, den = dur_text.split("/")
                dur = float(num) / float(den)
            else:
                dur = float(dur_text)
            if name != "r":
                v = vel + (0.15 if "!" in flags else 0.0) - (0.2 if "?" in flags else 0.0)
                extra = dict(kw)
                if "<" in flags:
                    extra["bend"] = slide_in
                if grace_note:
                    gbeat = pos - grace * self.bpm / 60.0
                    self.note(inst, gbeat, grace * self.bpm / 60.0, n(grace_note) + transpose,
                              v * 0.8, human=0.002, legato=legato_next, release=0.04)
                    legato_next = True
                self.note(inst, pos, dur, n(name) + transpose, v, human=human,
                          legato=legato_next, **extra)
            legato_next = "~" in flags or (slur and name != "r")
            pos += dur
        return pos

    def drums(self, inst: str, beat: float, pattern: str, keys: dict[str, tuple[str, float]],
              vel: float = 1.0, step: float = 0.25, human: float = 0.004,
              swing: float = 0.0) -> float:
        pos = beat
        for ch in pattern.replace(" ", ""):
            if ch != "-":
                key, v = keys[ch]
                # Sallantı: ara on altılıklar biraz geç.
                late = swing * step if round((pos - beat) / step) % 2 == 1 else 0.0
                self.note(inst, pos + late, step, key, v * vel, human=human)
            pos += step
        return pos

    def chord(self, inst: str, beat: float, dur: float, names: list[str], vel: float = 0.6,
              strum: float = 0.0, **kw) -> None:
        for i, name in enumerate(names):
            self.note(inst, beat + i * strum, dur - i * strum, n(name), vel, **kw)

    def arp(self, inst: str, beat: float, names: list[str], order: list[int], step: float,
            count: int, vel: float = 0.6, accent: float = 0.12, every: int = 4,
            human: float = 0.006) -> None:
        """Arpej / ostinato: names'ten order sırasıyla, step aralıkla count nota."""
        for i in range(count):
            v = vel + (accent if i % every == 0 else 0.0)
            self.note(inst, beat + i * step, step, n(names[order[i % len(order)]]), v,
                      human=human)


SHARP_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def name_of(key: int) -> str:
    return f"{SHARP_NAMES[key % 12]}{key // 12 - 1}"


def diatonic(text: str, steps: int, scale: list[str]) -> str:
    """Ezgi satırını gamın içinde steps basamak kaydırır (bir üçlü aşağı = -2)."""
    classes = sorted(n(name + "4") % 12 for name in scale)

    def shift(name: str) -> str:
        key = n(name)
        octave, pc = divmod(key, 12)
        degree = max(d for d in range(len(classes)) if classes[d] <= pc) if pc >= classes[0]             else -1
        if degree < 0:
            octave, degree = octave - 1, len(classes) - 1
        chromatic = key - (12 * octave + classes[degree])
        target_octave, target = divmod(degree + steps, len(classes))
        return name_of(12 * (octave + target_octave) + classes[target] + chromatic)

    tokens = []
    for token in text.split():
        name, rest = token.split(":")
        if name == "r":
            tokens.append(token)
            continue
        if name.startswith("^"):
            grace, main = name[1:].split("|")
            name = f"^{shift(grace)}|{shift(main)}"
        else:
            name = shift(name)
        tokens.append(f"{name}:{rest}")
    return " ".join(tokens)


def _dur(token: str) -> float:
    text = token.split(":")[1].rstrip("~!?<")
    if "/" in text:
        num, den = text.split("/")
        return float(num) / float(den)
    return float(text)


def length(text: str) -> float:
    """Ezgi satırının vuruş cinsinden uzunluğu."""
    return sum(_dur(t) for t in text.split())


def phrase(text: str, first: int, last: int) -> str:
    """Ezgi satırının first..last ölçüleri (1'den; başlangıcı bu ölçülere düşen notalar)."""
    out, pos = [], 0.0
    for token in text.split():
        bar = int(pos // BEATS_PER_BAR + 1e-9) + 1
        if first <= bar <= last:
            out.append(token)
        pos += _dur(token)
    return " ".join(out)
