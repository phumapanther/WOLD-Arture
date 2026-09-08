# Synthesises the combat sound effects as 44.1kHz mono WAVs, ready to upload to Roblox.
#
# Everything is built from noise and simple oscillators shaped by envelopes -- no samples, no libraries
# beyond numpy. Each weapon gets a matched PAIR: the cast (what the attacker hears) and the impact (what
# the victim hears), sharing a timbre so the two obviously belong to the same weapon.
import numpy as np, wave
from pathlib import Path

SR = 44100

def env(n, attack, decay, curve=2.0):
    """Attack-decay envelope over n samples; `curve` above 1 makes the tail fall away faster."""
    a = max(1, int(n * attack))
    d = max(1, n - a)
    return np.concatenate([np.linspace(0, 1, a), (np.linspace(1, 0, d) ** curve)])[:n]

def noise(n):
    return np.random.uniform(-1, 1, n)

def tone(n, f0, f1=None, kind="sine"):
    """A sweep from f0 to f1 (or a steady tone). Phase is integrated so the sweep is continuous."""
    f1 = f0 if f1 is None else f1
    f = np.linspace(f0, f1, n)
    phase = np.cumsum(2 * np.pi * f / SR)
    if kind == "saw":
        return 2 * ((phase / (2 * np.pi)) % 1) - 1
    if kind == "square":
        return np.sign(np.sin(phase))
    return np.sin(phase)

def lowpass(x, cutoff):
    """One-pole lowpass -- enough to take the fizz off white noise."""
    a = np.exp(-2 * np.pi * cutoff / SR)
    out = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = a * acc + (1 - a) * v
        out[i] = acc
    return out

def highpass(x, cutoff):
    return x - lowpass(x, cutoff)

def reverb(x, taps, decay=0.5):
    """Cheap tail: a few delayed copies. Gives spells a sense of space without a real convolver."""
    out = x.copy()
    for i, d in enumerate(taps):
        k = int(SR * d)
        if k < len(x):
            out[k:] += x[:-k] * (decay ** (i + 1))
    return out

def norm(x, peak=0.89):
    x = np.nan_to_num(x)
    m = np.abs(x).max()
    return x * (peak / m) if m > 0 else x

def save(name, x):
    x = norm(x)
    # Short fades stop the click a hard start or stop makes.
    f = min(220, len(x) // 8)
    if f > 0:
        x[:f] *= np.linspace(0, 1, f)
        x[-f:] *= np.linspace(1, 0, f)
    data = (x * 32767).astype("<i2")
    out = Path("assets/sounds") / f"{name}.wav"
    out.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(out), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"  {out.name:28s} {len(x)/SR:.2f}s")

def n(seconds):
    return int(SR * seconds)

# ---------------------------------------------------------------- BOW
def bow_shoot():
    """Creak of the draw, then the string's snap and the arrow tearing away."""
    total = n(0.55)
    out = np.zeros(total)
    # String snap: a sharp band of noise plus a fast pitch drop.
    s = n(0.16)
    snap = highpass(noise(s), 1200) * env(s, 0.002, 0.998, 3.5)
    snap += tone(s, 900, 180) * env(s, 0.001, 0.999, 4.0) * 0.5
    out[:s] += snap * 0.9
    # Arrow flying off: filtered noise sweeping away from the listener.
    w = n(0.42)
    whoosh = lowpass(noise(w), 3000) * env(w, 0.18, 0.82, 2.2)
    whoosh *= np.linspace(1.0, 0.25, w)
    out[n(0.06):n(0.06) + w] += whoosh * 0.5
    return out

def bow_hit():
    """A solid thud into the body, with the shaft still ringing."""
    total = n(0.45)
    out = np.zeros(total)
    t = n(0.18)
    thud = tone(t, 180, 60) * env(t, 0.004, 0.996, 2.6)
    thud += lowpass(noise(t), 700) * env(t, 0.002, 0.998, 3.0) * 0.7
    out[:t] += thud
    # Shaft vibration after the hit.
    v = n(0.3)
    out[n(0.03):n(0.03) + v] += tone(v, 420, 300) * env(v, 0.02, 0.98, 3.2) * 0.22
    return out

# ---------------------------------------------------------------- STAFF (laser beam)
def laser_shoot():
    """A charged whine that snaps into a descending beam -- clean and electric."""
    total = n(0.5)
    out = np.zeros(total)
    c = n(0.12)
    out[:c] += tone(c, 400, 1800) * env(c, 0.5, 0.5, 1.2) * 0.35
    b = n(0.38)
    beam = tone(b, 2200, 500, "saw") * 0.5 + tone(b, 1100, 250) * 0.5
    beam *= env(b, 0.01, 0.99, 2.0)
    beam += highpass(noise(b), 4000) * env(b, 0.005, 0.995, 3.0) * 0.25
    out[c:c + b] += beam
    return reverb(out, [0.035, 0.07], 0.3)

def laser_hit():
    """The beam landing: a bright zap and a scorch that fades."""
    total = n(0.42)
    out = np.zeros(total)
    z = n(0.1)
    out[:z] += (tone(z, 3000, 700, "square") * 0.4 + noise(z) * 0.6) * env(z, 0.002, 0.998, 3.0)
    s = n(0.34)
    sizzle = highpass(noise(s), 2500) * env(s, 0.03, 0.97, 2.4) * 0.45
    out[n(0.04):n(0.04) + s] += sizzle
    out[:n(0.16)] += tone(n(0.16), 260, 90) * env(n(0.16), 0.005, 0.995, 2.5) * 0.4
    return reverb(out, [0.03], 0.25)

# ---------------------------------------------------------------- SPELLBOOK (dark magic)
def spell_shoot():
    """Low, breathy and unpleasant: dark magic leaving the book."""
    total = n(0.6)
    out = np.zeros(total)
    # Whoosh of gathering air.
    w = n(0.28)
    out[:w] += lowpass(noise(w), 1400) * env(w, 0.35, 0.65, 1.6) * 0.5
    # The cast itself: detuned low tones for a sour, wavering colour.
    c = n(0.45)
    body = tone(c, 220, 130) + tone(c, 227, 134)   # slight detune = beating
    body += tone(c, 110, 65) * 0.7
    body *= env(c, 0.06, 0.94, 1.8) * 0.45
    out[n(0.12):n(0.12) + c] += body
    return reverb(out, [0.06, 0.13, 0.21], 0.45)

def spell_hit():
    """The curse landing and clinging -- a dull impact under a shivering tail."""
    total = n(0.65)
    out = np.zeros(total)
    i = n(0.14)
    out[:i] += (tone(i, 150, 55) * 0.7 + lowpass(noise(i), 500) * 0.5) * env(i, 0.004, 0.996, 2.4)
    # Wavering tail: amplitude modulation is what makes it sound like a lingering hex.
    t = n(0.5)
    tail = (tone(t, 320, 180) + tone(t, 326, 184)) * 0.5
    tail *= (1 + 0.5 * np.sin(2 * np.pi * 11 * np.arange(t) / SR))  # shiver
    tail *= env(t, 0.05, 0.95, 2.2) * 0.3
    out[n(0.05):n(0.05) + t] += tail
    return reverb(out, [0.05, 0.11], 0.4)

# ---------------------------------------------------------------- SWORD
def sword_swing():
    """Blade cutting air: a band of noise sweeping past, no impact."""
    total = n(0.4)
    out = np.zeros(total)
    w = n(0.34)
    sw = noise(w)
    sw = lowpass(highpass(sw, 700), 5000)
    # Loudest in the middle of the arc, like the blade passing the listener.
    shape = np.sin(np.linspace(0, np.pi, w)) ** 2.0
    out[n(0.02):n(0.02) + w] += sw * shape * 0.8
    out[n(0.02):n(0.02) + w] += tone(w, 1400, 500) * shape * 0.12
    return out

def sword_hit():
    """Steel landing on a body: a hard cut with a short metallic ring."""
    total = n(0.5)
    out = np.zeros(total)
    c = n(0.12)
    cut = highpass(noise(c), 1800) * env(c, 0.002, 0.998, 3.2)
    out[:c] += cut * 0.75
    b = n(0.16)
    out[:b] += (tone(b, 260, 90) * 0.8 + lowpass(noise(b), 600) * 0.6) * env(b, 0.003, 0.997, 2.6)
    # Ring of the blade afterwards, a few inharmonic partials so it reads as metal.
    r = n(0.36)
    ring = sum(tone(r, f) * a for f, a in [(2100, 1.0), (3170, 0.6), (4550, 0.35)])
    ring *= env(r, 0.006, 0.994, 3.4) * 0.16
    out[n(0.02):n(0.02) + r] += ring
    return out

print("writing sounds:")
for name, fn in [
    ("bow_shoot", bow_shoot), ("bow_hit", bow_hit),
    ("laser_shoot", laser_shoot), ("laser_hit", laser_hit),
    ("spell_shoot", spell_shoot), ("spell_hit", spell_hit),
    ("sword_swing", sword_swing), ("sword_hit", sword_hit),
]:
    np.random.seed(abs(hash(name)) % (2**31))   # reproducible renders
    save(name, fn())
