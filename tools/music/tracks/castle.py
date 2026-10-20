"""Kale: D dorian (D E F G A B C), 120 BPM, 12/8 oyun havası (vuruş başına üç sekizlik), 72 ölçü (2:24).

Ortaçağ panayırı havası: tabor (telsiz trampet), def ve tef; üç telli sazın akorları, arp
arpejleri; ezgi blok flütlerde (A) ve obuada (B, eski zurna sesine en yakın); doruğa doğru
kemanlar, korno ve timpani.
Biçim: giriş 1–4 · A 5–20 · B 21–36 · ara 37–44 · doruk 45–68 (A ve B) · çıkış 69–72.
"""

import engine
import instruments as ins
from score import Score, at, diatonic, n, phrase

ID = "castle"
TITLE = "Kale"
BPM = 120
BARS = 72
SEED = 1471

E, Q, D3, H = 1 / 3, 2 / 3, 1.0, 2.0
DORIAN = ["D", "E", "F", "G", "A", "B", "C"]
CHORDS = {"Dm": ["D", "F", "A"], "C": ["C", "E", "G"], "Am": ["A", "C", "E"],
          "G": ["G", "B", "D"], "F": ["F", "A", "C"], "A": ["A", "C#", "E"]}
A_PROG = ["Dm", "C", "Dm", "Am", "Dm", "C", ("G", "Am"), "Dm"]
B_PROG = ["F", "C", "G", "Dm", "F", "C", "G", "A"]
BREAK_PROG = ["Dm", "C", "Dm", "Am", "F", "C", "G", "A"]


def jig(text: str) -> str:
    """Süre kısaltmaları: e sekizlik, q dörtlük (iki sekizlik), d noktalı dörtlük (vuruş),
    h iki vuruş."""
    codes = {"e": "1/3", "q": "2/3", "d": "1", "h": "2"}
    out = []
    for token in text.split():
        name, dur = token.split(":")
        flags = "".join(c for c in dur if c in "~!?<")
        core = dur.rstrip("~!?<")
        out.append(f"{name}:{codes.get(core, core)}{flags}")
    return " ".join(out)


def section(bar: int) -> str:
    if bar <= 4 or bar >= 69:
        return "edge"
    if bar <= 20:
        return "A"
    if bar <= 36:
        return "B"
    if bar <= 44:
        return "break"
    return "climaxA" if bar <= 60 else "climaxB"


def chord_of(bar: int) -> list[tuple[float, float, str]]:
    sec = section(bar)
    if sec == "edge":
        c = "Dm"
    elif sec in ("A", "climaxA"):
        c = A_PROG[(bar - 5) % 8]
    elif sec in ("B", "climaxB"):
        c = B_PROG[(bar - 21) % 8]
    else:
        c = BREAK_PROG[bar - 37]
    if isinstance(c, tuple):
        return [(at(bar), 2.0, c[0]), (at(bar, 3), 2.0, c[1])]
    return [(at(bar), 4.0, c)]


def mix() -> engine.Mix:
    return engine.Mix({
        "tabor": ins.rope_snare(pan=0.12, reverb=0.14, gain_db=-6.0,
                                eq=[("hp", 80, 2), ("pk", 5000, -2.0, 1.5)]),
        "frame": ins.frame_drum(pan=-0.15, reverb=0.16, gain_db=-4.0,
                                eq=[("hp", 40, 2), ("pk", 300, -2.0, 1.0)]),
        "tamb": ins.tambourine(pan=0.4, reverb=0.12, gain_db=-12.0, eq=[("hp", 2500, 2)]),
        "timpani": ins.timpani(pan=0.0, reverb=0.25, gain_db=-2.0, max_ring=3.5,
                               eq=[("hp", 35, 2)]),
        "bassdrum": ins.bass_drum(pan=0.0, reverb=0.2, gain_db=-6.0, max_ring=2.5,
                                  eq=[("hp", 30, 2), ("lp", 4000, 1)]),
        "chimes": ins.mark_tree(pan=-0.3, reverb=0.3, gain_db=-13.0),
        "saz": ins.strumstick(pan=-0.32, reverb=0.16, gain_db=-10.5, max_ring=1.0,
                              eq=[("hp", 110, 2), ("pk", 2600, 1.5, 1.2)]),
        "harp": ins.folk_harp(pan=0.3, reverb=0.22, gain_db=-10.0, max_ring=2.0,
                              eq=[("hp", 90, 2)]),
        "bass": ins.contrabass_pizz(pan=0.05, reverb=0.1, gain_db=-5.0, max_ring=1.0,
                                    eq=[("hp", 35, 2), ("pk", 120, 2.0, 1.0)]),
        "cellos": ins.cellos(pan=0.18, reverb=0.2, gain_db=-8.0, release=0.4,
                             eq=[("hp", 40, 2), ("pk", 250, -2.0, 1.0)]),
        "spic": ins.violins_spiccato(pan=-0.22, reverb=0.18, gain_db=-10.0,
                                     eq=[("hp", 200, 2)]),
        "violins": ins.violins(pan=-0.25, reverb=0.24, gain_db=-7.0, release=0.3,
                               eq=[("hp", 180, 2), ("hs", 6000, -2.0)]),
        "recorder": ins.alto_recorder(pan=0.06, reverb=0.2, gain_db=-3.0, release=0.12,
                                      eq=[("hp", 250, 2)]),
        "tenor": ins.tenor_recorder(pan=-0.12, reverb=0.2, gain_db=-5.0, release=0.12,
                                    eq=[("hp", 180, 2)]),
        "oboe": ins.oboe(pan=0.1, reverb=0.2, gain_db=-3.0, release=0.15,
                         eq=[("hp", 200, 2)]),
        "horn": ins.horn(pan=-0.38, reverb=0.3, gain_db=-7.0, release=0.4,
                         eq=[("hp", 70, 2)]),
    }, engine.make_ir(2.0, 3.0, 0.02, SEED), master_eq=[("hp", 28, 2)])


# --- Ritim (12 sekizlik ölçü) ---

TABOR = {"N": ("N", 0.85), "n": ("N", 0.5), "S": ("S", 0.8), "s": ("S", 0.45),
         "x": ("X", 0.6)}
TABOR_BASIC = "N-nN-nN-nN-n"
TABOR_DRIVE = "N-nNnnN-nNsn"
TABOR_FILL = "N-nN-nSsnSSS"


def percussion(sc: Score) -> None:
    for bar in range(1, BARS + 1):
        b = at(bar)
        sec = section(bar)
        pos = (bar - 1) % 4
        if sec == "edge":
            sc.drums("tabor", b, TABOR_BASIC, TABOR, vel=0.7, step=E)
            sc.drums("frame", b, "B-----------", {"B": ("B", 0.5)}, step=E)
        elif sec == "break":
            if bar <= 42:
                sc.drums("tabor", b, "x-----x-----", TABOR, vel=0.6, step=E)
                sc.drums("frame", b, "B-----b-----", {"B": ("B", 0.55), "b": ("b", 0.45)},
                         step=E)
            else:
                for i in range(12):
                    frac = ((bar - 43) * 12 + i) / 24
                    sc.note("tabor", b + i * E, E, "S", 0.3 + 0.65 * frac)
        else:
            pattern = [TABOR_BASIC, TABOR_DRIVE, TABOR_BASIC, TABOR_FILL][pos]
            loud = 1.0 if sec.startswith("climax") else 0.85
            sc.drums("tabor", b, pattern, TABOR, vel=loud, step=E)
            sc.drums("frame", b, "B-----b-----" if pos < 3 else "B-----b--b--",
                     {"B": ("B", 0.85), "b": ("b", 0.65)}, step=E)
            sc.drums("tamb", b, "--S--H--S--H" if sec != "B" else "--S--S--S--S",
                     {"S": ("S", 0.5), "H": ("H", 0.7)}, step=E)
    for bar, key in ((4, "A"), (20, "D"), (36, "D"), (44, "A"), (68, "D")):
        sc.note("chimes", at(bar, 3), 4, key, 0.6)
    for bar, key, v in ((5, "D3", 0.7), (37, "D3", 0.5), (45, "D3", 1.0), (61, "D3", 0.9),
                        (69, "D3", 0.55)):
        sc.note("timpani", at(bar), 4, n(key), v)
    for bar in range(45, 69):
        root = {"Dm": "D3", "C": "G2", "Am": "A2", "G": "G2", "F": "A2", "A": "A2"}
        for start, length, chord in chord_of(bar):
            if bar % 2 == 1 or length < 4:
                sc.note("timpani", start, 1, n(root[chord]), 0.55)
    for i in range(6):
        sc.note("timpani", at(44, 3) + i * E, E, n("A2"), 0.4 + 0.1 * i, human=0.003)
    for bar in (45, 53, 61):
        sc.note("bassdrum", at(bar), 4, "B", 0.85)


# --- Saz, arp, bas ---

def accompaniment(sc: Score) -> None:
    saz_voicing = {"Dm": ["D3", "A3", "D4"], "C": ["C3", "G3", "E4"], "Am": ["A3", "E4", "A4"],
                   "G": ["G3", "D4", "G4"], "F": ["F3", "C4", "F4"], "A": ["A3", "E4", "C#5"]}
    harp_tones = {"Dm": ["D3", "A3", "D4", "F4"], "C": ["C3", "G3", "C4", "E4"],
                  "Am": ["A2", "E3", "A3", "C4"], "G": ["G2", "D3", "G3", "B3"],
                  "F": ["F2", "C3", "F3", "A3"], "A": ["A2", "E3", "A3", "C#4"]}
    roots = {"Dm": "D2", "C": "C2", "Am": "A1", "G": "G1", "F": "F1", "A": "A1"}
    for bar in range(1, BARS + 1):
        sec = section(bar)
        for start, length, chord in chord_of(bar):
            beats = int(length)
            # Saz: vuruş başında akor (hızlı tarama), üçüncü sekizlikte hafif tekrar.
            if sec != "break" or bar >= 43:
                for k in range(beats):
                    strong = (k % 2 == 0)
                    v = (0.75 if strong else 0.6) * (0.8 if sec == "edge" else 1.0)
                    sc.chord("saz", start + k, D3, saz_voicing[chord], v, strum=0.012)
                    sc.chord("saz", start + k + 2 * E, E, saz_voicing[chord][1:], v * 0.6,
                             strum=0.01)
            # Arp: vuruş başına üç notalık arpej (B'de ve arada).
            if sec in ("A", "B", "break", "climaxA", "climaxB"):
                tones = harp_tones[chord]
                order = [0, 1, 2, 3, 2, 1] if sec != "break" else [0, 2, 3, 1, 3, 2]
                for i in range(beats * 3):
                    sc.note("harp", start + i * E, E, n(tones[order[i % 6]]),
                            0.5 if i % 3 == 0 else 0.4)
            # Bas: 1. ve 3. vuruş kök, doruklarda araya beşli.
            if sec in ("A", "B", "climaxA", "climaxB"):
                root = n(roots[chord])
                for k in range(0, beats, 2):
                    sc.note("bass", start + k, 1, root, 0.85)
                    sc.note("bass", start + k + 1 + 2 * E, E, root + 7, 0.55)
            # Çello: B'de ve dorukta kök (bağlı).
            if sec in ("B", "climaxA", "climaxB") or (sec == "break" and bar >= 41):
                sc.note("cellos", start, length, n(roots[chord]) + 12, 0.6, legato=True)
            # Spiccato kemanlar: B'de sekizlik itici ostinato.
            if sec in ("B", "climaxB"):
                top = harp_tones[chord][3]
                for i in range(beats * 3):
                    key = n(top) + (12 if i % 3 == 0 else 0)
                    sc.note("spic", start + i * E, E, key, 0.62 if i % 3 == 0 else 0.48)


# --- Ezgiler ---

A1 = jig("A4:q D5:e D5:q E5:e F5:q E5:e D5:q C5:e "
         "E5:q C5:e G4:q C5:e E5:q F5:e G5:q E5:e "
         "F5:q D5:e A4:q D5:e F5:q A5:e G5:q F5:e "
         "E5:q D5:e C5:q B4:e A4:d r:d "
         "A4:q D5:e D5:q E5:e F5:q G5:e A5:q F5:e "
         "G5:q E5:e C5:q E5:e G5:q A5:e G5:q E5:e "
         "D5:q B4:e G4:q B4:e C5:q B4:e A4:q G4:e "
         "F5:q E5:e D5:q C5:e D5:h")
A2_END = jig("D5:q B4:e G4:q B4:e C5:q D5:e E5:q C5:e "
             "D5:q C5:e A4:q C5:e D5:h")
B_HEAD = jig("C5:d A4:q F4:e A4:q C5:e F5:d "
             "E5:q D5:e C5:q D5:e E5:d G4:d "
             "D5:q B4:e G4:q B4:e D5:q E5:e D5:q B4:e "
             "A4:h r:d A4:q C5:e "
             "F5:d E5:q D5:e C5:q A4:e F4:d "
             "G4:q C5:e E5:q G5:e E5:q C5:e G4:q C5:e "
             "B4:q D5:e G5:q F5:e E5:q D5:e C5:q B4:e")
B1 = B_HEAD + " " + jig("C#5:d B4:q A4:e A4:h")
# Üçlü üst / alt eşlik; son ölçü (A majör) elle: dorian kaydırması C#'yi bozar.
B_UPPER = diatonic(B_HEAD, 2, DORIAN) + " " + jig("E5:d D5:q C#5:e E5:h")
B_LOWER = diatonic(B_HEAD, -2, DORIAN) + " " + jig("A4:d G4:q E4:e E4:h")
BREAK_LINE = jig("A4:h D5:h C5:h G4:h F4:h A4:h E5:h r:h "
                 "C5:h A4:h G4:h E4:h D5:h B4:h C#5:h E5:h")
FANFARE = jig("D4:q D4:e A4:d D4:q D4:e F4:q A4:e D5:d")


def melodies(sc: Score) -> None:
    a_first = phrase(A1, 1, 6)
    sc.line("recorder", at(5), A1, vel=0.72, slur=True)
    sc.line("recorder", at(13), a_first + " " + A2_END, vel=0.76, slur=True)
    sc.line("tenor", at(13), diatonic(a_first + " " + A2_END, -2, DORIAN), vel=0.6,
            slur=True)
    sc.line("oboe", at(21), B1, vel=0.72, slur=True)
    sc.line("oboe", at(29), B1, vel=0.76, slur=True)
    sc.line("recorder", at(29), B_UPPER, vel=0.5, slur=True)
    sc.line("recorder", at(37), BREAK_LINE, vel=0.55, slur=True)
    # Doruk A: blok flüt + kemanlar ezgide, obua üçlü altta; korno borusu girişte.
    sc.line("horn", at(44), FANFARE, vel=0.75)
    for start in (45, 53):
        body = A1 if start == 45 else a_first + " " + A2_END
        sc.line("recorder", at(start), body, vel=0.8, slur=True)
        sc.line("violins", at(start), body, vel=0.66, slur=True)
        sc.line("oboe", at(start), diatonic(body, -2, DORIAN), vel=0.62, slur=True)
    # Doruk B: obua + kemanlar ezgide, korno üçlü altta.
    sc.line("oboe", at(61), B1, vel=0.8, slur=True)
    sc.line("violins", at(61), B1, vel=0.66, transpose=12, slur=True)
    sc.line("horn", at(61), B_LOWER, vel=0.6, transpose=-12, slur=True)
    # Çıkış: blok flüt uzun D.
    sc.line("recorder", at(69), "D5:6 r:2", vel=0.55, swell=(1.0, 0.4))


def compose() -> Score:
    sc = Score(BPM, BARS, SEED)
    percussion(sc)
    accompaniment(sc)
    melodies(sc)
    return sc
