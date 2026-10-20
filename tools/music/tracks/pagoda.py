"""Pagoda: G# minör pentatonik (G# B C# D# F#), 90 BPM, 56 ölçü (≈ 2:29).

Uzak Doğu havası: kanuna benzeyen zither (dan tranh, kendi pentatonik akordunda) akan
arpejlerle; ezgi flütte (bambu flüt gibi kayarak girişler, süs notaları) ve kemanlarda
(erhu gibi kaymalı); büyük davul ve deflerle taiko benzeri ritim; doruğa doğru korno ve timpani.
Biçim: giriş 1–4 · A 5–20 · B 21–32 · ara 33–40 · doruk 41–52 · çıkış 53–56 (girişe bağlanır).
"""

import engine
import instruments as ins
from score import Score, at, n, phrase

ID = "pagoda"
TITLE = "Pagoda"
BPM = 90
BARS = 56
SEED = 1603

A_PROG = ["G#m", "E", "F#", "G#m", "G#m", "E", "F#", "G#m"]
B_PROG = ["C#m", "G#m", "E", "F#", "C#m", "G#m", "E", "F#"]
BREAK_PROG = ["G#m", "G#m", "E", "E", "F#", "F#", "G#m", "G#m"]
# Zither arpej tonları (pentatonik; akorun rengini veren notalar).
ARP = {"G#m": ["G#3", "D#4", "G#4", "B4", "C#5", "D#5"],
       "E": ["G#3", "B3", "D#4", "G#4", "B4", "D#5"],
       "F#": ["F#3", "C#4", "F#4", "G#4", "C#5", "D#5"],
       "C#m": ["C#4", "G#4", "B4", "C#5", "D#5", "G#5"]}
PAD = {"G#m": ("G#3", "B3", "D#4"), "E": ("G#3", "B3", "E4"), "F#": ("F#3", "A#3", "C#4"),
       "C#m": ("G#3", "C#4", "E4")}
ROOT = {"G#m": "G#1", "E": "E1", "F#": "F#1", "C#m": "C#2"}


def section(bar: int) -> str:
    if bar <= 4 or bar >= 53:
        return "edge"
    if bar <= 20:
        return "A"
    if bar <= 32:
        return "B"
    if bar <= 40:
        return "break"
    return "climax"


def chord_of(bar: int) -> str:
    sec = section(bar)
    if sec == "edge":
        return "G#m"
    if sec in ("A", "climax"):
        return A_PROG[(bar - 5) % 8]
    if sec == "B":
        return B_PROG[(bar - 21) % 8]
    return BREAK_PROG[bar - 33]


def mix() -> engine.Mix:
    return engine.Mix({
        "zither": ins.dan_tranh(pan=0.3, reverb=0.22, gain_db=-4.0, max_ring=2.5,
                                eq=[("hp", 120, 2), ("pk", 2500, 1.5, 1.5)]),
        "harp": ins.harp(pan=-0.35, reverb=0.25, gain_db=-9.5, max_ring=2.5,
                         eq=[("hp", 90, 2)]),
        "taiko": ins.bass_drum(pan=0.0, reverb=0.22, gain_db=-3.0, max_ring=2.0,
                               eq=[("hp", 30, 2), ("lp", 5000, 1)]),
        "frame": ins.frame_drum(pan=-0.2, reverb=0.18, gain_db=-4.0,
                                eq=[("hp", 40, 2)]),
        "shime": ins.rope_snare(pan=0.25, reverb=0.15, gain_db=-10.0,
                                eq=[("hp", 150, 2), ("lp", 7000, 1)]),
        "zills": ins.finger_cymbals(pan=0.5, reverb=0.3, gain_db=-13.0, max_ring=2.5),
        "chimes": ins.mark_tree(pan=-0.3, reverb=0.35, gain_db=-12.0),
        "timpani": ins.timpani(pan=0.0, reverb=0.25, gain_db=-2.0, max_ring=4.0,
                               eq=[("hp", 35, 2)]),
        "bass": ins.cellos_pizz(pan=0.1, reverb=0.12, gain_db=-3.0, max_ring=1.2,
                                eq=[("hp", 40, 2)]),
        "cellos": ins.cellos(pan=0.15, reverb=0.22, gain_db=-10.0, release=0.6,
                             eq=[("hp", 40, 2), ("pk", 250, -2.0, 1.0)]),
        "violas": ins.violas(pan=0.28, reverb=0.26, gain_db=-12.0, release=0.6,
                             eq=[("hp", 120, 2)]),
        "violins": ins.violins(pan=-0.22, reverb=0.26, gain_db=-4.0, release=0.35,
                               eq=[("hp", 180, 2), ("hs", 6000, -2.0)]),
        "flute": ins.flute(pan=0.05, reverb=0.26, gain_db=-3.0, release=0.25,
                           eq=[("hp", 250, 2)]),
        "horn": ins.horn(pan=-0.38, reverb=0.32, gain_db=-8.0, release=0.6,
                         eq=[("hp", 70, 2)]),
    }, engine.make_ir(2.6, 4.0, 0.03, SEED), master_eq=[("hp", 28, 2)])


# --- Ritim (taiko benzeri) ---

TAIKO_A = "B-------B--b----"
TAIKO_B = "B-----B-B---b-b-"
FRAME_A = "----h-------h-hh"
SHIME = "s-s-s-s-s-s-s-s-"
SHIME_DRIVE = "s-ss-ss-s-ss-sss"


def percussion(sc: Score) -> None:
    taiko = {"B": ("B", 0.9), "b": ("B", 0.6)}
    frame = {"B": ("B", 0.8), "b": ("b", 0.6), "h": ("h", 0.55), "H": ("H", 0.7)}
    shime = {"s": ("N", 0.5)}
    for bar in range(1, BARS + 1):
        b = at(bar)
        sec = section(bar)
        pos = (bar - 1) % 4
        if sec == "edge":
            if bar % 2 == 1:
                sc.note("taiko", b, 4, "B", 0.6)
            sc.drums("frame", b, "--------h-------", frame, vel=0.7)
        elif sec == "break":
            if bar <= 38:
                sc.drums("frame", b, "B-------h---h---", frame, vel=0.7)
            else:
                # Taiko yağmuru: on altılıklar kabararak.
                for i in range(16):
                    frac = ((bar - 39) * 16 + i) / 32
                    sc.note("frame", b + i * 0.25, 0.25, "H" if i % 2 == 0 else "h",
                            0.35 + 0.6 * frac)
                    if i % 4 == 0:
                        sc.note("taiko", b + i * 0.25, 1, "B", 0.4 + 0.5 * frac)
        else:
            sc.drums("taiko", b, TAIKO_A if pos < 3 else TAIKO_B, taiko,
                     vel=1.0 if sec == "climax" else 0.85)
            sc.drums("frame", b, FRAME_A, frame, vel=0.9)
            sc.drums("shime", b, SHIME if pos < 3 and sec != "climax" else SHIME_DRIVE, shime,
                     vel=1.0 if sec != "A" else 0.85)
        if sec in ("A", "B", "climax") and pos == 3:
            sc.note("zills", at(bar, 4.5), 2, "Z", 0.5)
    for bar, key in ((4, "A"), (20, "A"), (32, "D"), (40, "A"), (52, "D")):
        sc.note("chimes", at(bar, 2), 4, key, 0.7)
    for bar, key, v in ((5, "G#2", 0.7), (21, "C#3", 0.75), (33, "G#2", 0.5),
                        (41, "G#2", 1.0), (49, "G#2", 0.85), (53, "G#2", 0.55)):
        sc.note("timpani", at(bar), 4, n(key), v)
    for i in range(8):
        sc.note("timpani", at(40, 3) + i * 0.25, 0.25, n("D#3"), 0.35 + 0.08 * i,
                human=0.003)


# --- Zither, arp, bas, yaylılar ---

def accompaniment(sc: Score) -> None:
    for bar in range(1, BARS + 1):
        sec = section(bar)
        chord = chord_of(bar)
        tones = ARP[chord]
        b = at(bar)
        # Zither: sekizlik dalga (aşağı-yukarı); doruğun ikinci yarısında on altılık.
        if sec != "break" or bar >= 39:
            fast = sec == "climax" and bar >= 45
            order = [0, 2, 1, 3, 2, 4, 3, 5] if not fast else \
                [0, 2, 3, 4, 3, 2, 1, 2, 0, 2, 3, 5, 4, 3, 2, 1]
            step = 0.25 if fast else 0.5
            for i in range(int(4 / step)):
                v = (0.6 if i % 4 == 0 else 0.48) * (0.8 if sec == "edge" else 1.0)
                sc.note("zither", b + i * step, step, n(tones[order[i % len(order)]]), v)
        # Arp: arada ve B'de geniş akorlar (her yarım ölçü).
        if sec in ("B", "break", "climax"):
            for half in (0, 2):
                sc.chord("harp", b + half, 2, [tones[0], tones[2], tones[4]], 0.45,
                         strum=0.05)
        # Bas: pizzicato kök, A/B/doruk.
        if sec in ("A", "B", "climax"):
            root = n(ROOT[chord]) + 12
            sc.note("bass", b, 1.5, root, 0.85)
            sc.note("bass", b + 1.5, 0.5, root + 7, 0.55)
            sc.note("bass", b + 2.5, 1.5, root, 0.7)
        # Çello pedalı: G# + D# (girişte, A'da ve arada); B ve dorukta kök.
        if sec in ("edge", "A", "break"):
            if (bar - 1) % 2 == 0:
                sc.note("cellos", b, 8, n("G#2"), 0.55, legato=True)
                sc.note("cellos", b, 8, n("D#3"), 0.45, legato=True)
        else:
            sc.note("cellos", b, 4, n(ROOT[chord]) + 12, 0.62, legato=True)
        # Viyola zemini: B, ara sonu, doruk.
        if sec in ("B", "climax") or (sec == "break" and bar >= 37):
            lo, mid, hi = PAD[chord]
            swell = (0.35, 1.0) if bar in (21, 37) else (1.0, 1.0)
            for key in (lo, mid, hi):
                sc.note("violas", b, 4, n(key), 0.5, legato=True, swell=swell)
        # Korno: doruk akorları.
        if sec == "climax":
            lo, mid, _ = PAD[chord]
            sc.note("horn", b, 4, n(mid), 0.6, legato=True)
            sc.note("horn", b, 4, n(lo), 0.5, legato=True)


# --- Ezgiler ---

A1 = ("^F#5|D#5:1.5 C#5:.5 B4:1 C#5:1 "
      "D#5:.5 F#5:.5 D#5:1 C#5:.5 B4:.5 G#4:1 "
      "C#5:1.5 D#5:.5 F#5:1 D#5:.5 C#5:.5 "
      "D#5:3< r:1 "
      "G#5:1.5 F#5:.5 D#5:1 F#5:.5 G#5:.5 "
      "B5:1 G#5:.5 F#5:.5 D#5:1 C#5:1 "
      "C#5:.5 D#5:.5 F#5:.5 D#5:.5 C#5:1 B4:.5 C#5:.5 "
      "G#4:3< r:1")
A2_END = ("C#5:.5 D#5:.5 F#5:.5 G#5:.5 B5:1 G#5:.5 F#5:.5 "
          "G#5:3< r:1")
B1 = ("G#4:2< B4:1 C#5:1 "
      "D#5:2< C#5:.5 B4:.5 G#4:1 "
      "B4:1.5 C#5:.5 D#5:1 F#5:1 "
      "C#5:3< r:1 "
      "G#5:2< F#5:1 D#5:1 "
      "D#5:1 F#5:.5 D#5:.5 C#5:1 B4:1 "
      "B4:1 G#4:.5 B4:.5 C#5:1 D#5:1 "
      "C#5:2 D#5:2")
BREAK_LINE = ("D#5:1.5 C#5:.5 B4:1 C#5:1 D#5:.5 F#5:.5 D#5:1 C#5:.5 B4:.5 G#4:1 "
              "r:8 "
              "G#5:1.5 F#5:.5 D#5:1 F#5:.5 G#5:.5 B5:1 G#5:.5 F#5:.5 D#5:1 C#5:1")


def melodies(sc: Score) -> None:
    a_head = phrase(A1, 1, 6)
    sc.line("flute", at(5), A1, vel=0.7, slur=True)
    sc.line("flute", at(13), a_head + " " + A2_END, vel=0.74, slur=True)
    # B: kemanlar (kaymalı), ikinci turda flüt bir oktav üstte eşlik eder.
    erhu = dict(slur=True, slide_in=(-2.0, 0.16))
    sc.line("violins", at(21), B1, vel=0.68, **erhu)
    sc.line("violins", at(29), phrase(B1, 1, 4), vel=0.72, **erhu)
    sc.line("flute", at(29), phrase(B1, 1, 4), vel=0.45, transpose=12, slur=True)
    sc.line("zither", at(33), BREAK_LINE, vel=0.75)
    # Doruk: flüt + kemanlar oktav.
    sc.line("flute", at(41), A1, vel=0.8, transpose=0, slur=True)
    sc.line("violins", at(41), A1, vel=0.66, transpose=-12, slur=True)
    sc.line("flute", at(49), a_head + " " + A2_END, vel=0.82, slur=True)
    sc.line("violins", at(49), a_head + " " + A2_END, vel=0.68, transpose=-12, slur=True)
    # Çıkış: flüt uzun G#, sönerek.
    sc.line("flute", at(53), "G#5:6< r:2", vel=0.5, swell=(1.0, 0.35))


def compose() -> Score:
    sc = Score(BPM, BARS, SEED)
    percussion(sc)
    accompaniment(sc)
    melodies(sc)
    return sc
