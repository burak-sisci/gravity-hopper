"""Kervan: D hicaz (D Eb F# G A Bb C), 100 BPM, 64 ölçü (≈ 2:34).

Çöl yolculuğu havası: darbuka maksum ve saidi ritimleri, def, tef, zil; durmadan akan saz
ostinatosu; ezgi obua (A) ve flütte (B); doruğa doğru yaylılar, korno ve timpani.
Biçim: giriş 1–4 · A 5–20 · B 21–36 · ara 37–44 · doruk 45–60 · çıkış 61–64 (girişe bağlanır).
"""

import engine
import instruments as ins
from score import Score, at, n, phrase

ID = "caravan"
TITLE = "Kervan"
BPM = 100
BARS = 64
SEED = 2110

# Akorlar (ölçü başına; ikiye bölünen ölçü (ilk yarı, ikinci yarı)).
CHORDS = {
    "D": ["D", "F#", "A"], "Eb": ["Eb", "G", "Bb"], "Cm": ["C", "Eb", "G"],
    "Gm": ["G", "Bb", "D"],
}
A_PROG = ["D", "Eb", "D", "D", "Cm", "Gm", ("D", "Eb"), "D"]
B_PROG = ["Gm", "Cm", "Eb", "D", "Gm", "Cm", ("Eb", "D"), "D"]
BREAK_PROG = ["D", "D", "Eb", "D", "Gm", "Cm", "Eb", "D"]


def chord_of(bar: int) -> list[tuple[float, float, str]]:
    """(başlangıç vuruşu, süre, akor) dilimleri."""
    if bar <= 4 or bar >= 61:
        prog, idx = ["D"] * 4, 0
    elif bar <= 20:
        prog, idx = A_PROG, (bar - 5) % 8
    elif bar <= 36:
        prog, idx = B_PROG, (bar - 21) % 8
    elif bar <= 44:
        prog, idx = BREAK_PROG, bar - 37
    else:
        prog, idx = A_PROG, (bar - 45) % 8
    c = prog[idx]
    if isinstance(c, tuple):
        return [(at(bar), 2.0, c[0]), (at(bar, 3), 2.0, c[1])]
    return [(at(bar), 4.0, c)]


def mix() -> engine.Mix:
    return engine.Mix({
        "darbuka": ins.darbuka(pan=0.12, reverb=0.10, gain_db=-1.0,
                               eq=[("hp", 60, 2), ("pk", 3500, 1.5, 1.5)]),
        "frame": ins.frame_drum(pan=-0.18, reverb=0.16, gain_db=-3.0,
                                eq=[("hp", 40, 2), ("pk", 300, -2.0, 1.0)]),
        "tamb": ins.tambourine(pan=0.42, reverb=0.10, gain_db=-11.0, eq=[("hp", 2500, 2)]),
        "zills": ins.finger_cymbals(pan=-0.5, reverb=0.25, gain_db=-12.0, max_ring=2.5),
        "chimes": ins.mark_tree(pan=0.3, reverb=0.3, gain_db=-12.0, width=1.0),
        "timpani": ins.timpani(pan=0.0, reverb=0.25, gain_db=-2.0, max_ring=4.0,
                               eq=[("hp", 35, 2)]),
        "bassdrum": ins.bass_drum(pan=0.0, reverb=0.2, gain_db=-5.0, max_ring=3.0,
                                  eq=[("hp", 30, 2), ("lp", 4000, 1)]),
        "saz": ins.strumstick(pan=-0.3, reverb=0.14, gain_db=-6.5, max_ring=0.45,
                              eq=[("hp", 120, 2), ("pk", 2800, 2.0, 1.2)]),
        "kanun": ins.dan_tranh(pan=0.45, reverb=0.2, gain_db=-1.0, max_ring=2.5,
                               eq=[("hp", 150, 2)]),
        "harp": ins.harp(pan=0.32, reverb=0.25, gain_db=-6.0, max_ring=2.5,
                         eq=[("hp", 90, 2)]),
        "bass": ins.contrabass_pizz(pan=0.05, reverb=0.08, gain_db=-3.5, max_ring=1.2,
                                    eq=[("hp", 35, 2), ("pk", 120, 2.0, 1.0)]),
        "cellos": ins.cellos(pan=0.15, reverb=0.2, gain_db=-8.0, release=0.5,
                             eq=[("hp", 40, 2), ("pk", 250, -2.0, 1.0)]),
        "violas": ins.violas(pan=0.28, reverb=0.25, gain_db=-9.0, release=0.5,
                             eq=[("hp", 120, 2)]),
        "violins": ins.violins(pan=-0.25, reverb=0.25, gain_db=-8.0, release=0.4,
                               eq=[("hp", 180, 2), ("hs", 6000, -2.0)]),
        "oboe": ins.oboe(pan=0.08, reverb=0.2, gain_db=-2.0, release=0.18,
                         eq=[("hp", 200, 2)]),
        "flute": ins.flute(pan=-0.1, reverb=0.24, gain_db=-3.0, release=0.2,
                           eq=[("hp", 250, 2)]),
        "horn": ins.horn(pan=-0.35, reverb=0.3, gain_db=-8.0, release=0.6,
                         eq=[("hp", 70, 2)]),
    }, engine.make_ir(2.3, 3.5, 0.025, SEED), master_eq=[("hp", 28, 2)])


# --- Ritim ---

DARBUKA = {"D": ("D", 0.95), "T": ("T", 0.78), "k": ("K", 0.5), "s": ("S", 0.6),
           "p": ("P", 0.45)}
MAQSUM = "D-T---T-D---T---"
MAQSUM_KA = "D-Tk--T-D-k-T-k-"
MAQSUM_RUN = "D-TkTkT-D-kkT-kk"
MAQSUM_FILL = "D-TkT-TkD-TkTsTs"
SAIDI = "D-T---D-D---T---"
SAIDI_KA = "D-Tk-kD-D-k-T-kk"


def percussion(sc: Score) -> None:
    for bar in range(1, BARS + 1):
        b = at(bar)
        # Darbuka.
        if bar <= 2 or bar >= 63:
            sc.drums("darbuka", b, "D-------p-----k-", DARBUKA, vel=0.7)
        elif bar <= 4 or bar >= 61:
            sc.drums("darbuka", b, MAQSUM if bar % 2 else MAQSUM_KA, DARBUKA, vel=0.75)
        elif bar <= 20 or 45 <= bar <= 60:
            pos = (bar - 5) % 4
            pattern = [MAQSUM_KA, MAQSUM_RUN, MAQSUM_KA, MAQSUM_FILL][pos]
            sc.drums("darbuka", b, pattern, DARBUKA, vel=1.0 if bar >= 45 else 0.9)
        elif bar <= 36:
            pos = (bar - 21) % 4
            pattern = [SAIDI, SAIDI_KA, SAIDI, MAQSUM_FILL][pos]
            sc.drums("darbuka", b, pattern, DARBUKA, vel=0.9)
        elif bar >= 43:
            # Ara sonunda kabaran tek-ka yağmuru.
            for i in range(16):
                key = "T" if i % 2 == 0 else "K"
                frac = ((bar - 43) * 16 + i) / 32
                sc.note("darbuka", b + i * 0.25, 0.25, key, 0.25 + 0.7 * frac)
        # Def.
        if 5 <= bar <= 36 or 45 <= bar <= 60:
            sc.drums("frame", b, "B-------b-b-----" if bar % 4 == 0 else "B-------b-------",
                     {"B": ("B", 0.9), "b": ("b", 0.7)})
        elif 37 <= bar <= 42:
            sc.drums("frame", b, "B-----h-b---h---", {"B": ("B", 0.65), "b": ("b", 0.5),
                                                      "h": ("h", 0.45)})
        elif bar <= 4 or bar >= 61:
            sc.drums("frame", b, "B---------------", {"B": ("B", 0.55)})
        # Tef.
        if 5 <= bar <= 20:
            sc.drums("tamb", b, "--S---S---S---SH", {"S": ("S", 0.5), "H": ("H", 0.65)})
        elif 21 <= bar <= 36:
            sc.drums("tamb", b, "-SS--SS--SS--SS-", {"S": ("S", 0.45)})
        elif 45 <= bar <= 60:
            sc.drums("tamb", b, "--S-H-S---S-H-S-", {"S": ("S", 0.55), "H": ("H", 0.8)})
        # Zil.
        if bar <= 4 and bar % 2 == 1:
            sc.note("zills", b, 4, "Z", 0.6)
        elif 5 <= bar <= 36 and bar % 2 == 0:
            sc.note("zills", at(bar, 4.5), 1, "Z", 0.55)
        elif 37 <= bar <= 44 and bar % 2 == 1:
            sc.note("zills", b, 2, "Z", 0.5)
        elif 45 <= bar <= 60:
            sc.note("zills", at(bar, 2), 1, "Z", 0.45)
            sc.note("zills", at(bar, 4), 1, "Z", 0.5)
    # Geçiş çanları.
    for bar, key in ((4, "A"), (20, "A"), (36, "D"), (44, "A"), (60, "D")):
        sc.note("chimes", at(bar), 4, key, 0.7)
    # Timpani ve büyük davul: bölüm girişleri.
    for bar, key, v in ((5, "D3", 0.75), (21, "G2", 0.8), (37, "D3", 0.5), (45, "D3", 1.0),
                        (53, "D3", 0.9), (61, "D3", 0.6)):
        sc.note("timpani", at(bar), 4, n(key), v)
    for bar in range(45, 61, 2):
        sc.note("timpani", at(bar, 3), 2, n("A2"), 0.6)
    for i in range(8):  # ara sonu timpani tremolosu
        sc.note("timpani", at(44, 3) + i * 0.25, 0.25, n("A2"), 0.35 + 0.08 * i, human=0.003)
    for bar in (21, 45, 53):
        sc.note("bassdrum", at(bar), 4, "B", 0.9)


# --- Saz ostinatosu ve bas ---

# Üst pedal + alttan dolaşan çizgi (on altılık çiftler).
OSTINATO = {
    "D": ("D4", ["A3", "Bb3", "A3", "G3", "F#3", "G3", "A3", "Bb3"]),
    "Eb": ("Eb4", ["Bb3", "C4", "Bb3", "G3", "F#3", "G3", "Bb3", "C4"]),
    "Cm": ("C4", ["G3", "A3", "G3", "F#3", "Eb3", "F#3", "G3", "A3"]),
    "Gm": ("D4", ["Bb3", "A3", "G3", "A3", "Bb3", "C4", "Bb3", "A3"]),
}
BASS_ROOT = {"D": "D2", "Eb": "Eb2", "Cm": "C2", "Gm": "G1"}
BASS_FIFTH = {"D": "A1", "Eb": "Bb1", "Cm": "G1", "Gm": "D2"}


def saz_and_bass(sc: Score) -> None:
    for bar in range(1, BARS + 1):
        quiet = bar <= 4 or bar >= 61
        in_break = 37 <= bar <= 44
        for start, length, chord in chord_of(bar):
            pedal, walk = OSTINATO[chord]
            steps = int(length * 4)
            first = 0 if start == at(bar) else 8
            if not in_break or bar >= 43:
                for i in range(steps):
                    k = first + i
                    key = pedal if k % 2 == 0 else walk[k // 2]
                    v = (0.42 if k % 2 == 0 else 0.55) + (0.15 if k % 4 == 0 else 0.0)
                    v *= 0.75 if quiet else (0.85 if bar >= 43 and in_break else 1.0)
                    sc.note("saz", start + i * 0.25, 0.25, n(key), v, human=0.004)
            if 5 <= bar <= 36 or 45 <= bar <= 60:
                root, fifth = BASS_ROOT[chord], BASS_FIFTH[chord]
                sc.note("bass", start, 1.0, n(root), 0.85)
                if length == 4.0:
                    sc.note("bass", start + 1.5, 0.5, n(fifth), 0.6)
                    sc.note("bass", start + 2.0, 1.0, n(root), 0.75)
                    sc.note("bass", start + 3.5, 0.5, n(root) + 12, 0.5)
                else:
                    sc.note("bass", start + 1.5, 0.5, n(fifth), 0.6)


# --- Yaylı zemin ---

def strings(sc: Score) -> None:
    # Çello: giriş / çıkış / ara pedalı; A'da kök, B ve dorukta akor kökü.
    for bar in range(1, BARS + 1):
        for start, length, chord in chord_of(bar):
            root = BASS_ROOT[chord]
            if bar <= 4 or bar >= 61 or 37 <= bar <= 42:
                if start == at(bar) and (bar - 1) % 2 == 0:
                    v = 0.42 if 37 <= bar <= 42 else 0.55
                    sc.note("cellos", start, 8, n("D3"), v, legato=bar not in (1, 37, 61))
                    sc.note("cellos", start, 8, n("A2"), v * 0.8)
            else:
                sc.note("cellos", start, length, n(root) + 12, 0.6 if bar < 45 else 0.75,
                        legato=True)
    # Viyola ve keman akorları: B, ara sonu, doruk.
    voicing = {"D": ("A3", "D4", "F#4"), "Eb": ("G3", "Bb3", "Eb4"),
               "Cm": ("G3", "C4", "Eb4"), "Gm": ("G3", "Bb3", "D4")}
    for bar in list(range(21, 37)) + list(range(41, 61)):
        for start, length, chord in chord_of(bar):
            lo, mid, hi = voicing[chord]
            v = 0.5 if bar < 45 else 0.62
            swell = (0.4, 1.0) if bar in (21, 41) else (1.0, 1.0)
            sc.note("violas", start, length, n(lo), v, legato=True, swell=swell)
            sc.note("violas", start, length, n(mid), v * 0.9, legato=True, swell=swell)
            if bar >= 45 or bar <= 36:
                sc.note("violins", start, length, n(hi), v * 0.8, legato=True, swell=swell)
    # Korno: doruk akorları ve B girişinde kabarma.
    sc.note("horn", at(20, 3), 2, n("D4"), 0.55, swell=(0.2, 1.0))
    for bar in range(45, 61):
        for start, length, chord in chord_of(bar):
            lo, mid, _ = voicing[chord]
            sc.note("horn", start, length, n(mid), 0.62, legato=True)
            sc.note("horn", start, length, n(lo), 0.5, legato=True)


# --- Ezgiler ---

A1 = ("^Bb4|A4:1.5 G4:.5 F#4:.5 G4:.5 A4:1 "
      "Bb4:.5 A4:.5 G4:.5 F#4:.5 Eb4:1 D4:1 "
      "D4:.5 F#4:.5 A4:.5 D5:.5 C5:1 Bb4:.5 A4:.5 "
      "A4:3 r:1 "
      "A4:.5 Bb4:.5 C5:1 Bb4:.5 A4:.5 G4:1 "
      "G4:.5 A4:.5 Bb4:1 A4:.5 G4:.5 F#4:1 "
      "F#4:.5 G4:.5 A4:.5 G4:.5 F#4:.5 Eb4:.5 D4:.5 Eb4:.5 "
      "D4:3< r:1")
A2 = ("^Bb4|A4:1.5 G4:.5 F#4:.5 G4:.5 A4:.5 Bb4:.5 "
      "C5:.5 Bb4:.5 A4:.5 G4:.5 F#4:.5 G4:.5 Eb4:1 "
      "D4:.5 F#4:.5 A4:.5 D5:.5 Eb5:1 D5:.5 C5:.5 "
      "D5:3 r:1 "
      "D5:.5 C5:.5 Eb5:1 D5:.5 C5:.5 Bb4:1 "
      "Bb4:.5 C5:.5 D5:1 C5:.5 Bb4:.5 A4:1 "
      "A4:.5 Bb4:.5 C5:.5 Bb4:.5 A4:.5 G4:.5 F#4:.5 Eb4:.5 "
      "D4:3< r:1")
B1 = ("D5:1 Bb4:.5 C5:.5 D5:1.5 G5:.5 "
      "G5:.5 F#5:.5 Eb5:.5 D5:.5 C5:1 Eb5:1 "
      "Bb4:1 Eb5:.5 D5:.5 Eb5:1 G5:1 "
      "F#5:1.5 Eb5:.5 D5:2 "
      "D5:.5 G5:.5 A5:.5 Bb5:.5 A5:1 G5:1 "
      "G5:.5 A5:.5 G5:.5 F#5:.5 Eb5:1 C5:1 "
      "Eb5:.5 D5:.5 C5:.5 Bb4:.5 A4:1 F#4:.5 G4:.5 "
      "A4:3 r:1")
B2_END = ("Eb5:.5 D5:.5 C5:.5 Bb4:.5 C5:.5 Bb4:.5 A4:.5 G4:.5 "
          "F#4:.5 Eb4:.5 D4:3")
B_COUNTER = ("G4:2 Bb4:2 C5:2 G4:2 G4:2 Bb4:2 A4:4 "
             "Bb4:2 D5:2 Eb5:2 C5:2 Bb4:2 A4:2 F#4:4")
# Kanun cevapları (A'daki susların içine) ve ara ezgisi.
ANSWER_1 = "D5:.25 C5:.25 Bb4:.25 A4:.25"
ANSWER_2 = "G4:.25 A4:.25 Bb4:.25 C5:.25"
BREAK_MELODY = ("A4:1.5 G4:.5 F#4:.5 G4:.5 A4:1 Bb4:.5 A4:.5 G4:.5 F#4:.5 Eb4:1 D4:1 "
                "r:8 "
                "A4:.5 Bb4:.5 C5:1 Bb4:.5 A4:.5 G4:1 G4:.5 A4:.5 Bb4:1 A4:.5 G4:.5 F#4:1")


def melodies(sc: Score) -> None:
    # A: obua; ikinci yarıda flüt uzun notalarla eşlik eder.
    sc.line("oboe", at(5), A1, vel=0.7, slur=True)
    sc.line("oboe", at(13), A2, vel=0.75, slur=True)
    sc.line("flute", at(13), "D5:4 Eb5:4 F#5:4 F#5:4 G5:4 D5:4 A4:2 G4:2 F#4:4",
            vel=0.45, slur=True)
    for bar in (8, 16):
        sc.line("kanun", at(bar, 4), ANSWER_1, vel=0.5)
    for bar in (12,):
        sc.line("kanun", at(bar, 4), ANSWER_2, vel=0.5)
    # B: flüt; ikinci turda obua karşı ezgi.
    sc.line("flute", at(21), B1, vel=0.72, slur=True)
    sc.line("flute", at(29), phrase(B1, 1, 6) + " " + B2_END, vel=0.76, slur=True)
    sc.line("oboe", at(29), B_COUNTER, vel=0.5, slur=True)
    # B'de arp: akor tonları sekizliklerle iner çıkar.
    arp_tones = {"D": ["D4", "F#4", "A4", "D5"], "Eb": ["Eb4", "G4", "Bb4", "Eb5"],
                 "Cm": ["C4", "Eb4", "G4", "C5"], "Gm": ["G3", "Bb3", "D4", "G4"]}
    for bar in list(range(21, 37)) + list(range(37, 45)):
        for start, length, chord in chord_of(bar):
            tones = arp_tones[chord]
            order = [0, 1, 2, 3, 2, 1, 2, 3]
            for i in range(int(length * 2)):
                sc.note("harp", start + i * 0.5, 0.5, n(tones[order[i % 8]]),
                        0.5 if bar < 37 else 0.42)
    # Ara: kanun ezgisi.
    sc.line("kanun", at(37), BREAK_MELODY, vel=0.7)
    # Doruk: A ezgisi obua + flüt (oktav) + kemanlar.
    for lead, transpose, v in (("oboe", 0, 0.82), ("flute", 12, 0.7)):
        sc.line(lead, at(45), A1, vel=v, transpose=transpose, slur=True)
        sc.line(lead, at(53), A2, vel=v + 0.04, transpose=transpose, slur=True)
    # Çıkış: flüt uzun D, sönerek.
    sc.line("flute", at(61), "D5:6", vel=0.5, swell=(1.0, 0.3))


def compose() -> Score:
    sc = Score(BPM, BARS, SEED)
    percussion(sc)
    saz_and_bass(sc)
    strings(sc)
    melodies(sc)
    return sc
