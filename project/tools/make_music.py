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


def render(stage):
    fn = {"city": city, "town": town}.get(stage)
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
