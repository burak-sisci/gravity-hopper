"""Liman (menü müziği, M5-10): D majör, 84 BPM, 32 ölçü (≈ 1:31).

Üç uygarlığa yolculuğun başladığı liman: sakin, umutlu, davetkâr. Tur parçalarından (Kervan,
Pagoda, Kale) daha yavaş ve seyrek; menüde uzun süre dinlenince yormasın diye vurmalı az.
Arp akan arpejlerle; ezgi flütte, ikinci turda kemanlarda (flüt üstte karşı ezgi); B'de korno
ve yaylılar kabarır, timpani; çıkış girişe bağlanır (döngü dikişsiz).
Biçim: giriş 1–4 · A 5–12 · A' 13–20 · B 21–28 · çıkış 29–32.
"""

import engine
import instruments as ins
from score import Score, at, n

ID = "harbor"
TITLE = "Liman"
BPM = 84
BARS = 32
SEED = 2711

INTRO_PROG = ["D", "G", "D", "A"]
A_PROG = ["D", "A", "Bm", "G", "D", "A", "G", "A"]
B_PROG = ["G", "D", "Em", "A", "G", "D", "Bm", "A"]
OUTRO_PROG = ["D", "G", "D", "A"]
ARP = {"D": ["D3", "A3", "D4", "F#4", "A4", "D5"],
       "A": ["A2", "E3", "A3", "C#4", "E4", "A4"],
       "Bm": ["B2", "F#3", "B3", "D4", "F#4", "B4"],
       "G": ["G2", "D3", "G3", "B3", "D4", "G4"],
       "Em": ["E3", "B3", "E4", "G4", "B4", "E5"]}
PAD = {"D": ("D4", "F#4", "A4"), "A": ("C#4", "E4", "A4"), "Bm": ("D4", "F#4", "B4"),
       "G": ("D4", "G4", "B4"), "Em": ("E4", "G4", "B4")}
ROOT = {"D": "D2", "A": "A1", "Bm": "B1", "G": "G1", "Em": "E2"}


def section(bar: int) -> str:
    if bar <= 4:
        return "intro"
    if bar <= 12:
        return "A"
    if bar <= 20:
        return "A2"
    if bar <= 28:
        return "B"
    return "outro"


def chord_of(bar: int) -> str:
    sec = section(bar)
    if sec == "intro":
        return INTRO_PROG[bar - 1]
    if sec in ("A", "A2"):
        return A_PROG[(bar - 5) % 8]
    if sec == "B":
        return B_PROG[bar - 21]
    return OUTRO_PROG[bar - 29]


def mix() -> engine.Mix:
    return engine.Mix({
        "harp": ins.harp(pan=0.25, reverb=0.3, gain_db=-5.0, max_ring=3.0,
                         eq=[("hp", 90, 2)]),
        "bass": ins.contrabass_pizz(pan=0.05, reverb=0.18, gain_db=-4.0, max_ring=1.5,
                                    eq=[("hp", 35, 2)]),
        "cellos": ins.cellos(pan=0.15, reverb=0.28, gain_db=-11.0, release=0.8,
                             eq=[("hp", 40, 2), ("pk", 250, -2.0, 1.0)]),
        "violas": ins.violas(pan=0.3, reverb=0.3, gain_db=-13.0, release=0.8,
                             eq=[("hp", 120, 2)]),
        "violins": ins.violins(pan=-0.25, reverb=0.3, gain_db=-5.0, release=0.4,
                               eq=[("hp", 180, 2), ("hs", 6000, -2.0)]),
        "flute": ins.flute(pan=0.05, reverb=0.3, gain_db=-4.0, release=0.3,
                           eq=[("hp", 250, 2)]),
        "horn": ins.horn(pan=-0.35, reverb=0.35, gain_db=-8.0, release=0.7,
                         eq=[("hp", 70, 2)]),
        "frame": ins.frame_drum(pan=-0.2, reverb=0.22, gain_db=-9.0, eq=[("hp", 40, 2)]),
        "timpani": ins.timpani(pan=0.0, reverb=0.3, gain_db=-5.0, max_ring=4.0,
                               eq=[("hp", 35, 2)]),
        "chimes": ins.mark_tree(pan=-0.3, reverb=0.4, gain_db=-14.0),
    }, engine.make_ir(2.8, 4.0, 0.03, SEED), master_eq=[("hp", 28, 2)])


# --- Eşlik ---

def accompaniment(sc: Score) -> None:
    for bar in range(1, BARS + 1):
        sec = section(bar)
        chord = chord_of(bar)
        tones = ARP[chord]
        b = at(bar)
        # Arp: sekizlik dalga (yukarı-aşağı); B'de ikinci yarı on altılığa açılır.
        order = [0, 1, 2, 3, 4, 3, 2, 1]
        for i in range(8):
            v = (0.62 if i % 4 == 0 else 0.48) * (0.85 if sec in ("intro", "outro") else 1.0)
            sc.note("harp", b + i * 0.5, 0.5, n(tones[order[i]]), v)
        if sec == "B" and bar % 2 == 0:
            for i in range(4):
                sc.note("harp", b + 2 + i * 0.5 + 0.25, 0.25, n(tones[5 - i % 3]), 0.35)
        # Bas: kök, A'dan itibaren.
        if sec in ("A2", "B"):
            root = n(ROOT[chord])
            sc.note("bass", b, 2, root, 0.75)
            sc.note("bass", b + 2.5, 1.5, root + 7, 0.5)
        elif sec == "A":
            sc.note("bass", b, 4, n(ROOT[chord]), 0.6)
        # Çello: girişte ve çıkışta D pedalı; ötekilerde kök.
        if sec in ("intro", "outro"):
            if bar % 2 == 1:
                sc.note("cellos", b, 8, n("D3"), 0.5, legato=True)
                sc.note("cellos", b, 8, n("A3"), 0.4, legato=True)
        else:
            sc.note("cellos", b, 4, n(ROOT[chord]) + 12, 0.55, legato=True)
        # Viyola zemini: A' ve B.
        if sec in ("A2", "B"):
            swell = (0.4, 1.0) if bar in (13, 21) else (1.0, 1.0)
            for key in PAD[chord]:
                sc.note("violas", b, 4, n(key) - 12, 0.5, legato=True, swell=swell)
        # Korno: B'nin akorları.
        if sec == "B":
            lo, mid, _ = PAD[chord]
            sc.note("horn", b, 4, n(lo) - 12, 0.55, legato=True)
            sc.note("horn", b, 4, n(mid) - 12, 0.45, legato=True)


# --- Vurmalı (seyrek) ---

def percussion(sc: Score) -> None:
    kit = {"B": ("B", 0.7), "h": ("h", 0.5)}
    for bar in range(1, BARS + 1):
        sec = section(bar)
        if sec == "A2":
            sc.drums("frame", at(bar), "B-------h-------", kit, vel=0.75)
        elif sec == "B":
            sc.drums("frame", at(bar), "B-----h-B---h-h-", kit, vel=0.85)
    for bar, key in ((4, "A"), (12, "A"), (20, "D"), (28, "A")):
        sc.note("chimes", at(bar, 3), 4, key, 0.6)
    for bar, key, v in ((21, "G2", 0.6), (25, "G2", 0.75), (13, "D3", 0.45)):
        sc.note("timpani", at(bar), 4, n(key), v)
    for i in range(8):
        sc.note("timpani", at(28, 3) + i * 0.25, 0.25, n("A2"), 0.3 + 0.06 * i, human=0.003)


# --- Ezgiler ---

A_LINE = ("F#5:1.5 E5:.5 D5:1 A4:1 "
          "C#5:1.5 D5:.5 E5:2 "
          "F#5:1 G5:.5 F#5:.5 E5:1 D5:1 "
          "B4:3 r:1 "
          "A4:1 D5:1 F#5:1.5 G5:.5 "
          "A5:1.5 G5:.5 F#5:1 E5:1 "
          "D5:1 E5:.5 F#5:.5 G5:1 B4:1 "
          "A4:3 r:1")
# A' karşı ezgisi (flüt, kemanların üstünde, uzun notalar).
A_COUNTER = ("A5:4 A5:2 G#5:2 F#5:4 G5:3 r:1 "
             "F#5:4 E5:2 C#6:2 B5:4 A5:3 r:1")
B_LINE = ("B4:2 D5:1 G5:1 "
          "F#5:2 E5:1 D5:1 "
          "E5:1.5 F#5:.5 G5:1 B5:1 "
          "A5:3 r:1 "
          "G5:1.5 F#5:.5 E5:1 D5:1 "
          "F#5:1.5 E5:.5 D5:1 A4:1 "
          "B4:1 D5:1 F#5:1 E5:1 "
          "E5:2 C#5:1 A4:1")


def melodies(sc: Score) -> None:
    sc.line("flute", at(5), A_LINE, vel=0.68, slur=True)
    sc.line("violins", at(13), A_LINE, vel=0.66, slur=True)
    sc.line("flute", at(13), A_COUNTER, vel=0.42, slur=True)
    sc.line("violins", at(21), B_LINE, vel=0.72, slur=True)
    sc.line("flute", at(21), B_LINE, vel=0.5, transpose=12, slur=True)
    # Çıkış: flüt uzun D, sönerek; girişe bağlanır.
    sc.line("flute", at(29), "D5:6 r:2 A4:4 r:4", vel=0.45, swell=(1.0, 0.4))


def compose() -> Score:
    sc = Score(BPM, BARS, SEED)
    accompaniment(sc)
    percussion(sc)
    melodies(sc)
    return sc
