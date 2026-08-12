# /// script
# requires-python = ">=3.12,<3.13"
# dependencies = ["signalflow", "numpy", "scipy"]
# ///
"""Generate the audio-feedback default theme by additive bell synthesis.

Run: UV_PYTHON_PREFERENCE=only-managed uv run --script generate.py [--only NAME ...]
Renders mono 44.1k WAVs to ../sounds/. See DESIGN-NOTES.md for the sound system.
"""
import json
import os
import sys

import numpy as np
from scipy.signal import fftconvolve
import signalflow as sf

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
SOUNDS = os.path.normpath(os.path.join(HERE, "..", "sounds"))
NOTE_MAP = json.load(open(os.path.join(HERE, "note_map.json")))
VARIANTS = json.load(open(os.path.join(HERE, "variants.json")))

# onset spacing per note value (seconds); tunable. Bells ring past their slot.
VALUE_SEC = {"quaver": 0.12, "crotchet": 0.24, "minim": 0.48}
BELL_DUR = 0.6                      # per-bell ring-out length
PARTIALS = [(1.0, 1.0), (2.01, 0.5), (2.99, 0.28), (4.07, 0.15)]  # inharmonic

_graph = None
def _graph_get():
    global _graph
    if _graph is None:
        cfg = sf.AudioGraphConfig(); cfg.sample_rate = SR
        _graph = sf.AudioGraph(config=cfg, output_device="dummy")
    return _graph

def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)

def render_bell(freq, dur=BELL_DUR, brightness=1.0, decay_scale=1.0,
                detune_cents=0.0, punch=1.0, layer=None, air_db=None):
    """One struck inharmonic bell -> mono float32."""
    g = _graph_get()
    patch = None
    for i, (ratio, amp) in enumerate(PARTIALS):
        a = amp * (brightness ** i) * (punch if i == 0 else 1.0)
        det = 2 ** ((detune_cents * i) / 1200)
        env = sf.ASREnvelope(0.003, 0.0, dur * decay_scale)
        v = sf.SineOscillator(freq * ratio * det) * env * a
        patch = v if patch is None else patch + v
    if layer == "shimmer":
        patch = patch + sf.SineOscillator(freq * 6.01) * sf.ASREnvelope(0.003, 0.0, dur * 0.5) * 0.06
    elif layer == "sub":
        patch = patch + sf.SineOscillator(freq * 0.5) * sf.ASREnvelope(0.003, 0.0, dur) * 0.2
    if air_db is not None:
        # subtle high "air" partial, gentle and short so it stays under the palette gate
        air_amp = 10 ** (air_db / 20)
        patch = patch + sf.SineOscillator(freq * 8.0) * sf.ASREnvelope(0.003, 0.0, dur * 0.35) * air_amp
    patch.play()
    buf = g.render_to_new_buffer(int(SR * dur))
    mono = np.asarray(buf.data).mean(axis=0).astype("float32")
    g.clear()
    return mono

def render_event(name, spec, accent=None):
    accent = accent or {}
    transpose = accent.get("transpose", 0)
    kw = {k: accent[k] for k in ("brightness","decay_scale","detune_cents","punch","layer","air_db")
          if k in accent}
    notes = spec["notes"]
    onsets = []
    t = 0.0
    for _, value in notes:
        onsets.append(t)
        t += 0.0 if spec["mode"] == "chord" else VALUE_SEC[value]
    total = int(SR * (max(onsets) + BELL_DUR))
    out = np.zeros(total, dtype="float32")
    for (midi, _), onset in zip(notes, onsets):
        bell = render_bell(midi_hz(midi + transpose), **kw)
        i = int(SR * onset)
        out[i:i + len(bell)] += bell[:total - i]
    return postprocess(out, accent)

def postprocess(sig, accent):
    # air layer as broadband high-shelf-ish noise-free partial already handled; here: reverb + EQ.
    # Loudness normalization happens once across the whole palette (see normalize_palette) so
    # per-file RMS stays consistent for the analyze.py --palette gate.
    ir = np.random.RandomState(0).randn(int(SR * 0.35)) * np.exp(-np.linspace(0, 6, int(SR * 0.35)))
    ir = np.concatenate([np.zeros(int(SR * 0.008)), ir])
    wet = fftconvolve(sig, ir)[:len(sig)]
    sig = sig * 0.85 + wet / (np.max(np.abs(wet)) + 1e-9) * 0.15
    f = int(SR * 0.1)                        # 100ms tail fade
    if len(sig) > f:
        sig[-f:] *= np.linspace(1, 0, f)
    return sig


PEAK_CEILING = 10 ** (-1 / 20)   # -1 dBFS, comfortably under the -0.7 dBFS gate


def _crest_db(sig):
    """peak/RMS ratio in dB. Scale-invariant: a uniform gain does not change it."""
    peak = np.max(np.abs(sig)) + 1e-9
    rms = np.sqrt(np.mean(sig.astype(np.float64) ** 2)) + 1e-9
    return 20 * np.log10(peak / rms)


def _shape(sig, p):
    """Sign-preserving power-law dynamics shaper. p<1 gently compresses (boosts
    quiet portions relative to the peak, lowering crest factor); p>1 gently
    expands (raises crest factor). p=1 is a no-op."""
    return np.sign(sig) * (np.abs(sig) ** p)


def normalize_palette(sigs):
    """Even out loudness across the palette so it survives analyze.py's
    --palette gate.

    analyze.py peak-normalizes each file to 0 dBFS *before* measuring RMS, so
    a uniform per-file gain (simple RMS matching) has zero effect on the
    measured spread -- it's cancelled out by that per-file peak-normalize.
    What actually varies between events is crest factor (peak-to-RMS ratio),
    driven by accent shape (e.g. `punch` extends a partial's full-envelope
    amplitude and lowers crest; the `air_db` accent adds a short bright burst
    that raises peak without adding sustain, raising crest). So instead we
    match crest factor: shape each signal's dynamics toward the palette's
    median crest factor via a light power-law compressor/expander, then apply
    a final per-file peak ceiling (a uniform gain, which does not perturb the
    crest factor we just set)."""
    crest = {n: _crest_db(s) for n, s in sigs.items()}
    target = float(np.median(list(crest.values())))
    out = {}
    for n, s in sigs.items():
        if abs(crest[n] - target) < 0.05:
            shaped = s
        else:
            lo, hi = 0.4, 2.5
            for _ in range(30):
                mid = (lo + hi) / 2
                if _crest_db(_shape(s, mid)) > target:
                    hi = mid
                else:
                    lo = mid
            shaped = _shape(s, (lo + hi) / 2)
        peak = np.max(np.abs(shaped)) + 1e-9
        out[n] = shaped * (PEAK_CEILING / peak)
    return out

def write_wav(path, sig):
    import scipy.io.wavfile as wav
    wav.write(path, SR, (np.clip(sig, -1, 1) * 32767).astype(np.int16))

def all_targets():
    items = {n: (NOTE_MAP[n], None) for n in NOTE_MAP}
    for vname, spec in VARIANTS.items():
        items[vname] = (NOTE_MAP[spec["base"]], spec)
    return items

def main(argv=None):
    argv = argv if argv is not None else sys.argv[1:]
    only = [argv[i + 1] for i, a in enumerate(argv) if a == "--only"]
    os.makedirs(SOUNDS, exist_ok=True)
    sigs = {}
    for name, (spec, accent) in all_targets().items():
        if only and name not in only:
            continue
        sigs[name] = render_event(name, spec, accent)
    sigs = normalize_palette(sigs)
    for name, sig in sigs.items():
        write_wav(os.path.join(SOUNDS, name + ".wav"), sig)
        print("wrote", name + ".wav")

if __name__ == "__main__":
    main()
