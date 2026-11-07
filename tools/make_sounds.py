#!/usr/bin/env python3
"""Gör spelets 8-bit-ljud: effekter och två musikslingor (meny och spel), som WAV i assets/sfx.

Allt syntetiseras som på en gammal spelkonsol: pulsvågor, triangelbas och brus.
"""
import os
import wave

import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")
SR = 22050
rng = np.random.default_rng(3)


def save(name, s, vol=0.8):
    s = np.clip(s * vol, -1, 1)
    data = (s * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(name, f"{len(s) / SR:.2f}s")


def t(dur):
    return np.arange(int(SR * dur)) / SR


def pulse(freq, dur, duty=0.5):
    """freq: tal eller array (glidande ton)."""
    f = np.broadcast_to(np.asarray(freq, float), t(dur).shape)
    ph = np.cumsum(f) / SR
    return np.where((ph % 1.0) < duty, 1.0, -1.0) * 0.5


def tri(freq, dur):
    f = np.broadcast_to(np.asarray(freq, float), t(dur).shape)
    ph = np.cumsum(f) / SR
    return (np.abs((ph % 1.0) * 4 - 2) - 1) * 0.6


def noise(dur, step=1):
    n = rng.uniform(-1, 1, int(SR * dur) // step + 1)
    return np.repeat(n, step)[: int(SR * dur)] * 0.5


def env(n, a=0.005, d=None, curve=2.0):
    x = np.arange(n) / SR
    dur = n / SR
    d = d or dur
    e = np.minimum(1, x / max(a, 1e-4)) * np.clip(1 - (x - a) / max(d - a, 1e-4), 0, 1) ** curve
    return e


def lowpass(s, k):
    """Enkelt glidande medelvärde: mjukare brus."""
    return np.convolve(s, np.ones(k) / k, mode="same")


os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------- effekter
d = 0.22
f = 180 + 420 * (t(d) / d) ** 0.6 + 40 * np.sin(t(d) * 90)          # trampolinens "boing"
save("studs", pulse(f, d, 0.25) * env(len(f), 0.003, d, 1.2))

d = 0.3
f = 90 + 160 * (t(d) / d) + 25 * np.sin(t(d) * 60)                   # rumpstuds: lägre och bredare
save("rumpa", (pulse(f, d, 0.5) * 0.7 + tri(f * 0.5, d)) * env(len(f), 0.003, d, 1.5))

parts = [pulse(fr, 0.05, 0.125) * env(int(SR * 0.05), 0.002, 0.05, 1) for fr in (660, 880, 1100, 1320)]
save("trick", np.concatenate(parts), 0.6)

d = 0.12
save("land", lowpass(noise(d, 2), 6) * env(int(SR * d), 0.001, d, 3) + tri(70, d) * env(int(SR * d), 0.001, d, 3), 0.9)

d = 0.6
f = 600 * np.exp(-t(d) * 4)
save("krasch", (pulse(f, d, 0.5) * 0.6 + noise(d, 3) * 0.5) * env(int(SR * d), 0.002, d, 1.5), 0.7)

# applåder: många korta klapp
s = np.zeros(int(SR * 1.4))
for k in range(40):
    p = int(rng.uniform(0, 1.2) * SR)
    n = int(SR * 0.03)
    s[p:p + n] += noise(0.03) * env(n, 0.001, 0.03, 3) * rng.uniform(0.4, 1.0)
s *= np.clip(1.4 - t(1.4), 0, 1)
save("applad", lowpass(s, 2), 0.7)

d = 0.5
f = np.concatenate([np.full(int(SR * 0.2), 523.0), np.linspace(523, 784, int(SR * 0.3))])
save("oj", tri(f, d) * env(int(SR * d), 0.01, d, 1), 0.8)

d = 2.4
rumble = lowpass(noise(d, 8), 40) * 3.0
crack = noise(0.15) * env(int(SR * 0.15), 0.001, 0.15, 2)
rumble[: len(crack)] += crack * 0.8
save("aska", rumble * env(int(SR * d), 0.01, d, 1.4), 0.9)

d = 2.0
r = lowpass(noise(d), 3) * 0.5
fade = np.minimum(1, np.minimum(t(d), d - t(d)) * 20)    # mjuka ändar så att slingan inte klickar
save("regn", r * fade, 0.5)

d = 3.0
w = lowpass(noise(d), 60) * 6 * (0.6 + 0.4 * np.sin(t(d) * 2 * np.pi / 3.0))
fade = np.minimum(1, np.minimum(t(d), d - t(d)) * 6)
save("vind", w * fade, 0.6)

parts = [pulse(fr, 0.09, 0.25) * env(int(SR * 0.09), 0.002, 0.09, 0.8) for fr in (523, 659, 784, 1047)]
parts.append(pulse(1047, 0.35, 0.25) * env(int(SR * 0.35), 0.002, 0.35, 1.5))
save("niva", np.concatenate(parts), 0.6)

save("meny", pulse(880, 0.04, 0.25) * env(int(SR * 0.04), 0.001, 0.04, 1), 0.5)
save("valj", np.concatenate([pulse(660, 0.05, 0.25), pulse(990, 0.08, 0.25)]) * env(int(SR * 0.13), 0.001, 0.13, 1), 0.5)
save("lapp", lowpass(noise(0.08, 2), 3) * env(int(SR * 0.08), 0.001, 0.08, 2), 0.5)


# ---------------------------------------------------------------- musik
def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def song(bpm, lead, bass, drums, duty=0.25):
    """lead/bass: listor med (not, längd i sextondelar), not 0 = paus. drums: sträng per sextondel
    (k = trumma, s = virvel, h = hi-hat, . = inget), upprepas."""
    step = 60 / bpm / 4
    total = sum(l for _, l in lead)
    out = np.zeros(int(SR * step * total) + SR // 10)
    def put(notes, fn, vol):
        pos = 0
        for n, l in notes:
            dur = step * l
            if n:
                s = fn(midi(n), dur) * env(int(SR * dur), 0.004, dur, 0.6) * vol
                i = int(pos * SR)
                out[i:i + len(s)] += s[: len(out) - i]
            pos += dur
    put(lead, lambda f, dd: pulse(f, dd, duty), 0.32)
    put(bass, tri, 0.45)
    for k in range(total):
        c = drums[k % len(drums)]
        i = int(k * step * SR)
        if c == "k":
            dd = 0.12
            s = tri(110 * np.exp(-t(dd) * 18) + 45, dd) * env(int(SR * dd), 0.001, dd, 2) * 0.9
        elif c == "s":
            dd = 0.1
            s = noise(dd, 2) * env(int(SR * dd), 0.001, dd, 2) * 0.35
        elif c == "h":
            dd = 0.03
            s = noise(dd) * env(int(SR * dd), 0.001, dd, 2) * 0.15
        else:
            continue
        out[i:i + len(s)] += s[: len(out) - i]
    return out[: int(SR * step * total)]


# menyn: en glad, lugn trudelutt i C-dur
menu_lead = [(72, 2), (76, 2), (79, 2), (76, 2), (77, 2), (81, 2), (79, 4),
             (76, 2), (77, 2), (79, 2), (84, 2), (83, 4), (79, 4),
             (81, 2), (79, 2), (77, 2), (76, 2), (74, 2), (76, 2), (77, 4),
             (79, 2), (76, 2), (74, 2), (71, 2), (72, 8)]
menu_bass = [(48, 4), (55, 4), (53, 4), (55, 4), (48, 4), (52, 4), (55, 4), (55, 4),
             (53, 4), (48, 4), (50, 4), (53, 4), (55, 4), (55, 4), (48, 8)]
save("musik_meny", song(116, menu_lead, menu_bass, "k.h.s.h.k.h.s.hh"), 0.7)

# spelet: en driv i 80-talets new wave-stil, a-moll med pulserande oktavbas och arpeggio.
# Melodin är egen (ingen cover): Am F C G Am F G E.
CHORDS = [(45, (69, 72, 76)), (41, (65, 69, 72)), (48, (67, 72, 76)), (43, (67, 71, 74)),
          (45, (69, 72, 76)), (41, (65, 69, 72)), (43, (67, 71, 74)), (40, (68, 71, 76))]
game_lead = [(76, 4), (74, 2), (72, 2), (74, 6), (0, 2),
             (72, 2), (74, 2), (76, 4), (77, 4), (76, 4),
             (79, 6), (76, 2), (72, 4), (74, 4),
             (74, 8), (71, 4), (0, 4),
             (69, 2), (72, 2), (76, 4), (81, 4), (79, 4),
             (77, 4), (76, 2), (74, 2), (72, 8),
             (74, 4), (76, 4), (79, 4), (74, 4),
             (76, 12), (0, 4)]
game_bass = []
game_arp = []
for root, tones in CHORDS:
    game_bass += [(root, 2), (root, 2), (root + 12, 2), (root, 2)] * 2
    game_arp += [(n + 12, 1) for n in (tones[0], tones[1], tones[2], tones[1])] * 4
song_main = song(132, game_lead, game_bass, "k.h.s.h.k.hks.h.")
arp = song(132, game_arp, [], ".", 0.5)
save("musik_spel", np.tile(song_main + arp * 0.35, 2), 0.7)


# ---------------------------------------------------------------- röst
# Barnets replik vid rumpstuds, talsyntes (espeak-ng) som krossas till 8-bit-ljud.
def voice(name, text, pitch=85):
    import subprocess
    import tempfile
    with tempfile.NamedTemporaryFile(suffix=".wav") as f:
        subprocess.run(["espeak-ng", "-v", "sv+f4", "-p", str(pitch), "-s", "150", "-m", "-w", f.name, text], check=True)
        with wave.open(f.name) as w:
            rate = w.getframerate()
            raw = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16) / 32768.0
    x = np.interp(np.arange(int(len(raw) * SR / rate)) * rate / SR, np.arange(len(raw)), raw)
    x = np.repeat(x[::3], 3)[: len(x)]                      # lägre samplingsfrekvens
    x = x / (np.abs(x).max() + 1e-9)
    x = np.round(x * 15) / 15                               # 4-bitars nivåer
    save(name, x, 0.8)


voice("ett_trick", 'Det är <emphasis level="strong">ETT</emphasis> trick!')
