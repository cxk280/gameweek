#!/usr/bin/env python3
"""Offline music generator for the stages — original tracks in a 16-bit console style.

Synthesizes at the SNES DSP's native 32 kHz using period-looped waveform "samples", per-note
ADSR, softened treble (approximating the chip's gaussian interpolation), and a feedback echo
(the chip's signature). Each stage gets its own original composition (key/tempo/mood chosen to
suit the stage); melodies are written here, not copied from any reference.

Usage:  python3 make_music.py <stage> <out.wav>
        (a sibling step pipes the WAV through ffmpeg to OGG for the game.)
"""
import sys, math
import numpy as np

SR = 32000  # SNES S-DSP native sample rate


def midi(n):           # MIDI note -> Hz
    return 440.0 * 2.0 ** ((n - 69) / 12.0)


def adsr(n, a, d, s, r):
    a = max(1, int(a * SR)); d = max(1, int(d * SR)); r = max(1, int(r * SR))
    sus = max(0, n - a - d - r)
    env = np.concatenate([
        np.linspace(0, 1, a, endpoint=False),
        np.linspace(1, s, d, endpoint=False),
        np.full(sus, s),
        np.linspace(s, 0, r),
    ])
    if len(env) < n:
        env = np.concatenate([env, np.zeros(n - len(env))])
    return env[:n]


def osc(kind, freq, n, detune=0.0, pw=0.5):
    t = np.arange(n) / SR
    ph = (t * freq * (1.0 + detune)) % 1.0
    if kind == "pulse":
        return np.where(ph < pw, 1.0, -1.0)
    if kind == "saw":
        return 2.0 * ph - 1.0
    if kind == "tri":
        return 2.0 * np.abs(2.0 * ph - 1.0) - 1.0
    if kind == "sine":
        return np.sin(2 * math.pi * ph)
    if kind == "noise":
        return np.random.uniform(-1, 1, n)
    return np.zeros(n)


def lowpass(x, cutoff):
    # one-pole lowpass — softens treble like the chip's interpolation
    a = math.exp(-2.0 * math.pi * cutoff / SR)
    y = np.empty_like(x); acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def note(kind, n_midi, dur, vol, env_p, detune=0.0, pw=0.5, vib=0.0, lp=0.0):
    n = int(dur * SR)
    f = midi(n_midi)
    w = osc(kind, f, n, detune, pw)
    if vib > 0.0:
        t = np.arange(n) / SR
        w = osc(kind, f * (1.0 + vib * 0.006 * np.sin(2 * math.pi * 5.0 * t)), n, detune, pw)
    if kind != "noise" and detune != 0.0:
        w = 0.5 * (w + osc(kind, f, n, -detune, pw))  # two slightly-detuned voices
    w *= adsr(n, *env_p)
    if lp > 0.0:
        w = lowpass(w, lp)
    return w * vol


def drum(kind, dur, vol):
    n = int(dur * SR); t = np.arange(n) / SR
    if kind == "kick":
        f = 120.0 * np.exp(-t * 22.0) + 45.0
        w = np.sin(2 * math.pi * np.cumsum(f) / SR) * np.exp(-t * 9.0)
    elif kind == "snare":
        w = (np.random.uniform(-1, 1, n) * np.exp(-t * 24.0)
             + np.sin(2 * math.pi * 190 * t) * np.exp(-t * 30.0) * 0.5)
    else:  # hat
        w = np.random.uniform(-1, 1, n) * np.exp(-t * 90.0)
        w = w - lowpass(w, 6000)  # highpass-ish
    return w * vol


def echo(x, delay_s, fb, mix):
    d = int(delay_s * SR)
    y = x.copy()
    for i in range(d, len(x)):
        y[i] += y[i - d] * fb
    wet = lowpass(y, 7000)  # the chip's echo is filtered
    return x * (1 - mix) + wet * mix


# --------------------------------------------------------------- stage compositions
def city(bpm=124):
    """Neon-city: upbeat, smooth, lightly jazzy. Key of A major, ii-V-ish changes."""
    beat = 60.0 / bpm
    bar = 4 * beat
    bars = 8
    total = int(bars * bar * SR) + SR  # +tail for echo
    lead = np.zeros(total); pad = np.zeros(total); bass = np.zeros(total); perc = np.zeros(total)

    def place(buf, w, start_beat):
        s = int(start_beat * beat * SR)
        buf[s:s + len(w)] += w[:max(0, len(buf) - s)]

    # 8-bar chord plan (root, third, fifth, seventh) — smooth I-vi-ii-V then a lift
    chords = [
        [57, 61, 64, 68], [54, 57, 61, 64], [59, 62, 66, 69], [52, 56, 59, 62],
        [62, 66, 69, 73], [61, 64, 68, 71], [59, 62, 66, 69], [52, 56, 59, 62],
    ]
    for b in range(bars):
        ch = chords[b]
        for v in ch[1:]:
            place(pad, note("saw", v, bar * 0.96, 0.10, (0.02, 0.1, 0.7, 0.25), 0.01, lp=2600), b * 4)
        # bass: root + fifth walking
        root = ch[0] - 12
        place(bass, note("tri", root, beat * 0.9, 0.34, (0.005, 0.05, 0.8, 0.08), lp=1400), b * 4)
        place(bass, note("tri", root + 7, beat * 0.9, 0.30, (0.005, 0.05, 0.8, 0.08), lp=1400), b * 4 + 1)
        place(bass, note("tri", root + 12, beat * 0.9, 0.30, (0.005, 0.05, 0.8, 0.08), lp=1400), b * 4 + 2)
        place(bass, note("tri", root + 7, beat * 0.9, 0.30, (0.005, 0.05, 0.8, 0.08), lp=1400), b * 4 + 3)

    # original syncopated lead melody (beats are global), chord-tone based
    mel = [
        (0.0, 1.5, 76), (1.5, 0.5, 73), (2.0, 1.0, 69), (3.0, 1.0, 71),
        (4.0, 1.0, 73), (5.0, 0.5, 69), (5.5, 0.5, 66), (6.0, 2.0, 64),
        (8.0, 1.5, 74), (9.5, 0.5, 71), (10.0, 1.0, 69), (11.0, 1.0, 66),
        (12.0, 1.0, 64), (13.0, 1.0, 66), (14.0, 2.0, 69),
        (16.0, 1.0, 78), (17.0, 1.0, 76), (18.0, 1.5, 73), (19.5, 0.5, 74),
        (20.0, 1.0, 73), (21.0, 0.5, 69), (21.5, 0.5, 71), (22.0, 2.0, 73),
        (24.0, 1.5, 71), (25.5, 0.5, 69), (26.0, 1.0, 66), (27.0, 1.0, 64),
        (28.0, 1.0, 62), (29.0, 1.0, 64), (30.0, 2.0, 57),
    ]
    for (sb, du, nt) in mel:
        place(lead, note("pulse", nt, du * beat * 0.95, 0.26, (0.01, 0.08, 0.6, 0.12), 0.006, 0.5, vib=0.4, lp=3800), sb)

    # drums: kick 1&3, snare 2&4, hats on eighths
    for b in range(bars):
        place(perc, drum("kick", 0.18, 0.9), b * 4 + 0)
        place(perc, drum("kick", 0.18, 0.7), b * 4 + 2.5)
        place(perc, drum("snare", 0.18, 0.6), b * 4 + 1)
        place(perc, drum("snare", 0.18, 0.6), b * 4 + 3)
        for e in range(8):
            place(perc, drum("hat", 0.06, 0.18), b * 4 + e * 0.5)

    mix = lead + pad + bass + perc
    mix = echo(mix, beat * 0.75, 0.30, 0.26)   # dotted-eighth echo
    return mix


def town(bpm=110):
    """Dusk old-town / lantern quarter: calm, warm, Eastern pentatonic. D minor pentatonic."""
    beat = 60.0 / bpm
    bar = 4 * beat
    bars = 8
    total = int(bars * bar * SR) + SR
    lead = np.zeros(total); pad = np.zeros(total); bass = np.zeros(total); perc = np.zeros(total)

    def place(buf, w, start_beat):
        s = int(start_beat * beat * SR)
        buf[s:s + len(w)] += w[:max(0, len(buf) - s)]

    # sustained open-fifth drone (D-A) that swells each bar — lanterns at dusk
    for b in range(bars):
        place(pad, note("saw", 50, bar * 0.98, 0.09, (0.4, 0.2, 0.8, 0.4), 0.01, lp=1500), b * 4)
        place(pad, note("saw", 57, bar * 0.98, 0.08, (0.4, 0.2, 0.8, 0.4), 0.01, lp=1500), b * 4)
    # soft bass: root/fifth, gentle
    bassline = [50, 57, 50, 53, 50, 57, 48, 50]
    for b in range(bars):
        place(bass, note("tri", bassline[b], beat * 1.8, 0.30, (0.01, 0.1, 0.8, 0.2), lp=1100), b * 4)
        place(bass, note("tri", bassline[b] + 7, beat * 1.6, 0.24, (0.01, 0.1, 0.8, 0.2), lp=1100), b * 4 + 2)

    # original koto-like pentatonic melody (plucked: short decay)
    pluck = (0.004, 0.14, 0.18, 0.10)
    mel = [
        (0.0, 1.0, 74), (1.0, 1.0, 72), (2.0, 1.5, 69), (3.5, 0.5, 67), (4.0, 2.0, 65), (6.0, 2.0, 69),
        (8.0, 1.0, 72), (9.0, 1.0, 74), (10.0, 1.5, 77), (11.5, 0.5, 74), (12.0, 2.0, 72), (14.0, 2.0, 69),
        (16.0, 1.0, 67), (17.0, 1.0, 69), (18.0, 1.5, 72), (19.5, 0.5, 69), (20.0, 2.0, 67), (22.0, 2.0, 65),
        (24.0, 1.0, 69), (25.0, 1.0, 72), (26.0, 1.5, 74), (27.5, 0.5, 72), (28.0, 1.0, 69), (29.0, 1.0, 67), (30.0, 2.0, 62),
    ]
    for (sb, du, nt) in mel:
        place(lead, note("pulse", nt, du * beat * 0.9, 0.24, pluck, 0.005, 0.35, vib=0.25, lp=3200), sb)
        place(lead, note("tri", nt, du * beat * 0.5, 0.10, pluck, lp=2400), sb)  # soft body under the pluck

    # sparse soft percussion: a low taiko-ish hit on bar 1, woodblock offbeats
    for b in range(bars):
        place(perc, drum("kick", 0.22, 0.7), b * 4)
        place(perc, drum("kick", 0.20, 0.4), b * 4 + 2.5)
        for e in [1.0, 3.0]:
            place(perc, note("tri", 84, 0.05, 0.10, (0.001, 0.03, 0.0, 0.02)), b * 4 + e)  # woodblock click

    mix = lead + pad + bass + perc
    mix = echo(mix, beat * 0.5, 0.34, 0.30)
    return mix


def lake(bpm=116):
    """Bright bouncy tropical: syncopated, major, octave-jumping bass. G major pentatonic."""
    beat = 60.0 / bpm; bar = 4 * beat; bars = 8; total = int(bars * bar * SR) + SR
    lead = np.zeros(total); pad = np.zeros(total); bass = np.zeros(total); perc = np.zeros(total)
    def place(buf, w, sb):
        s = int(sb * beat * SR); buf[s:s + len(w)] += w[:max(0, len(buf) - s)]
    chords = [[59, 62, 67], [60, 64, 67], [62, 66, 69], [59, 62, 67],
              [55, 59, 62], [57, 60, 64], [62, 66, 69], [55, 59, 62]]
    roots = [43, 48, 50, 43, 43, 45, 50, 43]
    for b in range(bars):
        for v in chords[b]:
            place(pad, note("tri", v, bar * 0.9, 0.08, (0.02, 0.2, 0.7, 0.2), lp=2600), b * 4)
        for e in range(4):                      # bouncy boom-octave bass
            place(bass, note("tri", roots[b], beat * 0.45, 0.32, (0.004, 0.05, 0.5, 0.05), lp=1500), b * 4 + e)
            place(bass, note("tri", roots[b] + 12, beat * 0.45, 0.22, (0.004, 0.05, 0.5, 0.05), lp=1800), b * 4 + e + 0.5)
    mel = [(0.0, 0.5, 79), (0.5, 0.5, 76), (1.0, 1.0, 74), (2.0, 0.5, 76), (2.5, 0.5, 79), (3.0, 1.0, 81),
           (4.0, 0.5, 79), (4.5, 0.5, 76), (5.0, 1.0, 72), (6.0, 1.0, 74), (7.0, 1.0, 71),
           (8.0, 0.5, 74), (8.5, 0.5, 76), (9.0, 1.0, 79), (10.0, 0.5, 76), (10.5, 0.5, 74), (11.0, 1.0, 72),
           (12.0, 1.0, 71), (13.0, 0.5, 74), (13.5, 0.5, 76), (14.0, 2.0, 67),
           (16.0, 0.5, 79), (16.5, 0.5, 81), (17.0, 1.0, 83), (18.0, 1.0, 81), (19.0, 1.0, 78),
           (20.0, 0.5, 76), (20.5, 0.5, 79), (21.0, 1.0, 81), (22.0, 2.0, 79),
           (24.0, 0.5, 76), (24.5, 0.5, 74), (25.0, 1.0, 72), (26.0, 1.0, 74), (27.0, 1.0, 71),
           (28.0, 1.0, 74), (29.0, 1.0, 67), (30.0, 2.0, 67)]
    for (sb, du, nt) in mel:
        place(lead, note("tri", nt, du * beat * 0.9, 0.26, (0.004, 0.12, 0.4, 0.1), lp=4200), sb)
    for b in range(bars):
        place(perc, drum("kick", 0.16, 0.8), b * 4); place(perc, drum("kick", 0.16, 0.6), b * 4 + 2.5)
        place(perc, drum("snare", 0.15, 0.5), b * 4 + 1); place(perc, drum("snare", 0.15, 0.5), b * 4 + 3)
        for e in range(8):
            place(perc, drum("hat", 0.05, 0.16), b * 4 + e * 0.5)
    mix = lead + pad + bass + perc
    return echo(mix, beat * 0.75, 0.26, 0.22)


def terracotta(bpm=84):
    """Warm golden-hour Renaissance: bright MAJOR choir + lute + a gentle uplifting lead. G major."""
    beat = 60.0 / bpm; bar = 4 * beat; bars = 8; total = int(bars * bar * SR) + SR
    voice = np.zeros(total); lute = np.zeros(total); low = np.zeros(total); lead = np.zeros(total)
    def place(buf, w, sb):
        s = int(sb * beat * SR); buf[s:s + len(w)] += w[:max(0, len(buf) - s)]
    # warm major progression: G D Em C / G C D G (bright, resolving)
    chords = [[55, 59, 62], [54, 57, 62], [52, 55, 59], [48, 52, 55],
              [55, 59, 62], [48, 52, 55], [54, 57, 62], [55, 59, 62]]
    for b in range(bars):
        for v in chords[b]:
            place(voice, note("sine", v, bar * 1.02, 0.15, (0.3, 0.3, 0.85, 0.45), lp=2700), b * 4)
            place(voice, note("tri", v + 12, bar * 1.02, 0.05, (0.35, 0.3, 0.8, 0.45), lp=2900), b * 4)
        place(low, note("tri", chords[b][0] - 12, bar * 1.0, 0.22, (0.08, 0.3, 0.85, 0.3), lp=1000), b * 4)
        for k in range(4):
            place(lute, note("pulse", chords[b][k % 3] + 12, beat * 0.85, 0.08, (0.004, 0.18, 0.2, 0.1), 0.004, 0.3, lp=3300), b * 4 + k)
    mel = [(0.0, 2.0, 71), (2.0, 1.0, 74), (3.0, 1.0, 76), (4.0, 2.0, 74), (6.0, 2.0, 71),
           (8.0, 2.0, 72), (10.0, 1.0, 71), (11.0, 1.0, 69), (12.0, 2.0, 67), (14.0, 2.0, 74),
           (16.0, 2.0, 76), (18.0, 1.0, 74), (19.0, 1.0, 72), (20.0, 2.0, 71), (22.0, 2.0, 67),
           (24.0, 2.0, 72), (26.0, 1.0, 74), (27.0, 1.0, 71), (28.0, 4.0, 67)]
    for (sb, du, nt) in mel:
        place(lead, note("tri", nt, du * beat * 0.95, 0.16, (0.03, 0.2, 0.6, 0.2), vib=0.3, lp=3500), sb)
    return echo(voice + lute + low + lead, beat * 0.66, 0.28, 0.26)


def brick(bpm=138):
    """Bluegrass: fast banjo forward-rolls + boom-chuck bass, major. G major."""
    beat = 60.0 / bpm; bar = 4 * beat; bars = 8; total = int(bars * bar * SR) + SR
    banjo = np.zeros(total); bass = np.zeros(total); chuck = np.zeros(total); lead = np.zeros(total)
    def place(buf, w, sb):
        s = int(sb * beat * SR); buf[s:s + len(w)] += w[:max(0, len(buf) - s)]
    # I-IV-V flavored: G G C G / G D G G
    chords = [[55, 59, 62], [55, 59, 62], [60, 64, 67], [55, 59, 62],
              [55, 59, 62], [62, 66, 69], [55, 59, 62], [55, 59, 62]]
    for b in range(bars):
        ch = chords[b]; roll = [ch[0], ch[2], ch[1], ch[2]]   # forward roll
        for e in range(8):
            nt = roll[e % 4] + (12 if e % 4 == 1 else 0)
            place(banjo, note("pulse", nt, beat * 0.4, 0.16, (0.003, 0.1, 0.15, 0.06), 0.004, 0.35, lp=4200), b * 4 + e * 0.5)
        for e in range(4):                       # boom (root/fifth) - chuck
            place(bass, note("tri", ch[0] - 12 + (7 if e % 2 else 0), beat * 0.5, 0.34, (0.004, 0.06, 0.5, 0.05), lp=1200), b * 4 + e)
            for v in ch:
                place(chuck, note("pulse", v + 12, beat * 0.18, 0.06, (0.002, 0.05, 0.0, 0.03), 0.004, 0.4, lp=3500), b * 4 + e + 0.5)
    melody = [(2.0, 1.0, 71), (3.0, 1.0, 74), (6.0, 1.0, 67), (7.0, 1.0, 71),
              (10.0, 1.0, 76), (11.0, 1.0, 74), (14.0, 2.0, 67),
              (18.0, 1.0, 71), (19.0, 1.0, 74), (22.0, 1.0, 78), (23.0, 1.0, 74), (26.0, 1.0, 71), (28.0, 2.0, 67)]
    for (sb, du, nt) in melody:
        place(lead, note("saw", nt, du * beat * 0.8, 0.14, (0.01, 0.1, 0.5, 0.12), 0.01, lp=3200, vib=0.6), sb)
    mix = banjo + bass + chuck + lead
    return echo(mix, beat * 0.5, 0.18, 0.16)


def library(bpm=100):
    """Mysterious, ornate, baroque: harpsichord-ish runs over soft strings. D minor."""
    beat = 60.0 / bpm; bar = 4 * beat; bars = 8; total = int(bars * bar * SR) + SR
    harp = np.zeros(total); strings = np.zeros(total); bass = np.zeros(total)
    def place(buf, w, sb):
        s = int(sb * beat * SR); buf[s:s + len(w)] += w[:max(0, len(buf) - s)]
    # Dm A Gm Dm / Bb A Dm A
    chords = [[50, 53, 57], [57, 61, 64], [55, 58, 62], [50, 53, 57],
              [58, 62, 65], [57, 61, 64], [50, 53, 57], [57, 61, 64]]
    for b in range(bars):
        for v in chords[b]:
            place(strings, note("saw", v, bar * 0.98, 0.07, (0.3, 0.25, 0.8, 0.4), 0.01, lp=2000), b * 4)
        place(bass, note("tri", chords[b][0] - 12, bar * 0.95, 0.26, (0.01, 0.1, 0.8, 0.2), lp=900), b * 4)
        # ornate harpsichord arpeggio (up-down) over the chord
        arp = [chords[b][0], chords[b][1], chords[b][2], chords[b][1] + 12, chords[b][2], chords[b][1], chords[b][0], chords[b][2]]
        for e in range(8):
            place(harp, note("pulse", arp[e] + 12, beat * 0.45, 0.12, (0.003, 0.12, 0.1, 0.06), 0.004, 0.25, lp=3600), b * 4 + e * 0.5)
    mix = harp + strings + bass
    return echo(mix, beat * 0.66, 0.32, 0.3)


def lunar(bpm=86):
    """Moody, atmospheric, spacey: slow minor, soft pads + sparse bell. F minor."""
    beat = 60.0 / bpm; bar = 4 * beat; bars = 8; total = int(bars * bar * SR) + SR
    pad = np.zeros(total); bell = np.zeros(total); bass = np.zeros(total)
    def place(buf, w, sb):
        s = int(sb * beat * SR); buf[s:s + len(w)] += w[:max(0, len(buf) - s)]
    chords = [[53, 56, 60], [48, 51, 55], [51, 55, 58], [48, 51, 55],
              [44, 48, 51], [51, 55, 58], [53, 56, 60], [48, 51, 55]]
    for b in range(bars):
        for v in chords[b]:
            place(pad, note("saw", v, bar * 1.02, 0.08, (0.6, 0.3, 0.85, 0.7), 0.012, lp=1700), b * 4)
        place(bass, note("sine", chords[b][0] - 12, bar * 1.0, 0.24, (0.2, 0.3, 0.85, 0.5), lp=700), b * 4)
    mel = [(0.0, 2.0, 72), (2.0, 1.0, 70), (3.0, 1.0, 68), (4.0, 3.0, 65), (7.0, 1.0, 68),
           (8.0, 2.0, 75), (10.0, 2.0, 72), (12.0, 2.0, 68), (14.0, 2.0, 63),
           (16.0, 2.0, 68), (18.0, 1.0, 70), (19.0, 1.0, 72), (20.0, 3.0, 70), (23.0, 1.0, 68),
           (24.0, 2.0, 67), (26.0, 2.0, 63), (28.0, 4.0, 65)]
    for (sb, du, nt) in mel:
        place(bell, note("sine", nt, du * beat * 0.95, 0.20, (0.02, 0.4, 0.5, 0.5), lp=3000), sb)
        place(bell, note("tri", nt + 12, du * beat * 0.5, 0.05, (0.02, 0.3, 0.3, 0.4), lp=3200), sb)
    return echo(pad + bell + bass, beat * 0.75, 0.42, 0.36)


def highland(bpm=104):
    """Pastoral, adventurous, rolling: open major with light hand-percussion. G major."""
    beat = 60.0 / bpm; bar = 4 * beat; bars = 8; total = int(bars * bar * SR) + SR
    lead = np.zeros(total); pad = np.zeros(total); bass = np.zeros(total); perc = np.zeros(total)
    def place(buf, w, sb):
        s = int(sb * beat * SR); buf[s:s + len(w)] += w[:max(0, len(buf) - s)]
    chords = [[55, 59, 62], [60, 64, 67], [62, 66, 69], [59, 62, 67],
              [55, 59, 62], [57, 60, 64], [62, 66, 69], [55, 59, 62]]
    for b in range(bars):
        for v in chords[b]:
            place(pad, note("saw", v, bar * 0.95, 0.07, (0.05, 0.2, 0.7, 0.3), 0.01, lp=2300), b * 4)
        place(bass, note("tri", chords[b][0] - 12, beat * 1.7, 0.30, (0.005, 0.08, 0.7, 0.1), lp=1100), b * 4)
        place(bass, note("tri", chords[b][0] - 5, beat * 1.7, 0.26, (0.005, 0.08, 0.7, 0.1), lp=1100), b * 4 + 2)
    mel = [(0.0, 1.5, 74), (1.5, 0.5, 72), (2.0, 1.0, 71), (3.0, 1.0, 67), (4.0, 2.0, 69), (6.0, 2.0, 74),
           (8.0, 1.0, 76), (9.0, 1.0, 74), (10.0, 1.5, 72), (11.5, 0.5, 71), (12.0, 2.0, 67), (14.0, 2.0, 69),
           (16.0, 1.5, 71), (17.5, 0.5, 69), (18.0, 1.0, 67), (19.0, 1.0, 64), (20.0, 2.0, 62), (22.0, 2.0, 67),
           (24.0, 1.0, 74), (25.0, 1.0, 72), (26.0, 1.5, 71), (27.5, 0.5, 69), (28.0, 4.0, 67)]
    for (sb, du, nt) in mel:
        place(lead, note("tri", nt, du * beat * 0.92, 0.22, (0.02, 0.15, 0.6, 0.15), vib=0.4, lp=3600), sb)
    for b in range(bars):
        place(perc, drum("kick", 0.18, 0.6), b * 4); place(perc, drum("kick", 0.16, 0.45), b * 4 + 1.5)
        place(perc, note("tri", 80, 0.06, 0.10, (0.001, 0.04, 0.0, 0.03)), b * 4 + 2.0)
        for e in range(4):
            place(perc, drum("hat", 0.05, 0.12), b * 4 + e + 0.5)
    return echo(lead + pad + bass + perc, beat * 0.66, 0.24, 0.2)


def bay(bpm=112):
    """Warm Latin bossa: jazzy maj7/ii-V, nylon comp, clave, smooth lead. C major."""
    beat = 60.0 / bpm; bar = 4 * beat; bars = 8; total = int(bars * bar * SR) + SR
    lead = np.zeros(total); gtr = np.zeros(total); bass = np.zeros(total); perc = np.zeros(total)
    def place(buf, w, sb):
        s = int(sb * beat * SR); buf[s:s + len(w)] += w[:max(0, len(buf) - s)]
    chords = [[48, 52, 55, 59], [57, 60, 64, 67], [50, 53, 57, 60], [55, 59, 62, 65],
              [48, 52, 55, 59], [57, 60, 64, 67], [50, 53, 57, 60], [55, 59, 62, 65]]
    for b in range(bars):
        ch = chords[b]
        place(bass, note("tri", ch[0] - 12, beat * 0.9, 0.30, (0.005, 0.08, 0.7, 0.1), lp=1100), b * 4)
        place(bass, note("tri", ch[2] - 12, beat * 0.9, 0.26, (0.005, 0.08, 0.7, 0.1), lp=1100), b * 4 + 2)
        for sb2 in [0.5, 1.5, 2.0, 3.0, 3.5]:    # bossa offbeat comp
            for v in ch[1:]:
                place(gtr, note("pulse", v, beat * 0.4, 0.07, (0.004, 0.1, 0.1, 0.06), 0.005, 0.4, lp=2800), b * 4 + sb2)
    mel = [(0.0, 1.0, 67), (1.0, 0.5, 71), (1.5, 0.5, 72), (2.0, 1.5, 76), (3.5, 0.5, 74), (4.0, 2.0, 72), (6.0, 1.5, 71), (7.5, 0.5, 67),
           (8.0, 1.0, 69), (9.0, 1.0, 72), (10.0, 1.5, 74), (11.5, 0.5, 72), (12.0, 2.0, 71), (14.0, 2.0, 67),
           (16.0, 1.0, 72), (17.0, 0.5, 76), (17.5, 0.5, 77), (18.0, 2.0, 79), (20.0, 2.0, 76), (22.0, 2.0, 72),
           (24.0, 1.0, 74), (25.0, 1.0, 71), (26.0, 1.5, 69), (27.5, 0.5, 67), (28.0, 4.0, 60)]
    for (sb, du, nt) in mel:
        place(lead, note("tri", nt, du * beat * 0.9, 0.22, (0.01, 0.12, 0.6, 0.12), vib=0.5, lp=3800), sb)
    for b in range(bars):
        for cl in [0.0, 0.75, 1.5, 2.5, 3.0]:    # 3-2 clave on a woodblock
            place(perc, note("tri", 82, 0.05, 0.12, (0.001, 0.035, 0.0, 0.03)), b * 4 + cl)
        place(perc, drum("kick", 0.16, 0.5), b * 4); place(perc, drum("kick", 0.14, 0.4), b * 4 + 2)
        for e in range(8):
            place(perc, drum("hat", 0.04, 0.1), b * 4 + e * 0.5)
    return echo(lead + gtr + bass + perc, beat * 0.75, 0.2, 0.18)


def tower(bpm=130):
    """Dark, mechanical, driving finale: pulsing minor bass, marching drums, ominous stabs. D minor."""
    beat = 60.0 / bpm; bar = 4 * beat; bars = 8; total = int(bars * bar * SR) + SR
    lead = np.zeros(total); stab = np.zeros(total); bass = np.zeros(total); perc = np.zeros(total)
    def place(buf, w, sb):
        s = int(sb * beat * SR); buf[s:s + len(w)] += w[:max(0, len(buf) - s)]
    roots = [50, 50, 46, 45, 50, 50, 46, 45]                 # Dm Dm Bb A ...
    chords = [[50, 53, 57], [50, 53, 57], [46, 50, 53], [45, 49, 52],
              [50, 53, 57], [50, 53, 57], [46, 50, 53], [45, 49, 52]]
    for b in range(bars):
        for e in range(8):                                   # driving 8th-note bass pulse
            place(bass, note("pulse", roots[b] - 12, beat * 0.42, 0.30, (0.003, 0.05, 0.6, 0.04), 0.004, 0.5, lp=1300), b * 4 + e * 0.5)
        for v in chords[b]:                                  # ominous brass-ish stab on the downbeat
            place(stab, note("saw", v, beat * 0.8, 0.10, (0.01, 0.15, 0.3, 0.1), 0.012, lp=2400), b * 4)
            place(stab, note("saw", v, beat * 0.8, 0.10, (0.01, 0.15, 0.3, 0.1), 0.012, lp=2400), b * 4 + 2)
    mel = [(0.0, 1.0, 69), (1.0, 1.0, 68), (2.0, 1.0, 65), (3.0, 1.0, 69), (4.0, 2.0, 70), (6.0, 1.0, 69), (7.0, 1.0, 65),
           (8.0, 1.0, 69), (9.0, 1.0, 68), (10.0, 1.0, 65), (11.0, 1.0, 62), (12.0, 4.0, 64),
           (16.0, 1.0, 72), (17.0, 1.0, 70), (18.0, 1.0, 69), (19.0, 1.0, 65), (20.0, 2.0, 67), (22.0, 2.0, 69),
           (24.0, 1.0, 70), (25.0, 1.0, 69), (26.0, 1.0, 65), (27.0, 1.0, 64), (28.0, 4.0, 62)]
    for (sb, du, nt) in mel:
        place(lead, note("pulse", nt, du * beat * 0.9, 0.18, (0.01, 0.1, 0.5, 0.1), 0.006, 0.5, vib=0.4, lp=3200), sb)
    for b in range(bars):
        for e in range(4):
            place(perc, drum("kick", 0.15, 0.85), b * 4 + e)         # four-on-the-floor march
        place(perc, drum("snare", 0.16, 0.6), b * 4 + 1); place(perc, drum("snare", 0.16, 0.6), b * 4 + 3)
        for e in range(8):
            place(perc, drum("hat", 0.04, 0.16), b * 4 + e * 0.5)
    return echo(lead + stab + bass + perc, beat * 0.5, 0.22, 0.2)


def render(stage):
    fn = {"city": city, "town": town, "lake": lake, "terracotta": terracotta, "brick": brick,
          "library": library, "lunar": lunar, "highland": highland, "bay": bay, "tower": tower}.get(stage)
    if fn is None:
        raise SystemExit("unknown stage: " + stage)
    mono = fn()
    mono = lowpass(mono, 9000)                  # master treble softening
    mono = np.tanh(mono * 1.1)                  # gentle saturation/limit
    mono /= max(1e-6, np.max(np.abs(mono)))
    mono *= 0.92
    # light stereo widening via a short echo offset between channels
    left = mono
    right = np.concatenate([np.zeros(int(0.011 * SR)), mono])[:len(mono)]
    stereo = np.stack([left, right * 0.96], axis=1)
    return stereo


def write_wav(path, stereo):
    import wave
    data = (np.clip(stereo, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "w") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data.tobytes())


if __name__ == "__main__":
    stage = sys.argv[1] if len(sys.argv) > 1 else "city"
    out = sys.argv[2] if len(sys.argv) > 2 else "city.wav"
    np.random.seed(1)  # reproducible noise/drums
    s = render(stage)
    write_wav(out, s)
    print("music %s: %.1fs %dHz -> %s" % (stage, len(s) / SR, SR, out))
