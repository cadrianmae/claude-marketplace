"""Theme data + I/O for the audio-feedback generator.

Plumbing: paths, sample rate, loading note_map.json / variants.json, resolving
the render list, and writing WAVs. No synthesis or tuning lives here.
"""
import json
import os

import numpy as np

SR = 44100  # output sample rate (fixed by the plugin's WAV format, not a tuning knob)

HERE = os.path.dirname(os.path.abspath(__file__))
SOUNDS = os.path.normpath(os.path.join(HERE, "..", "sounds"))

with open(os.path.join(HERE, "note_map.json")) as _f:
    NOTE_MAP = json.load(_f)
with open(os.path.join(HERE, "variants.json")) as _f:
    VARIANTS = json.load(_f)


def all_targets():
    """name -> (note_map_spec, accent_or_None) for the 8 base + 19 variants."""
    items = {n: (NOTE_MAP[n], None) for n in NOTE_MAP}
    for vname, spec in VARIANTS.items():
        items[vname] = (NOTE_MAP[spec["base"]], spec)
    return items


def write_wav(path, sig):
    """Write a mono float signal as 16-bit PCM at SR."""
    import scipy.io.wavfile as wav
    wav.write(path, SR, (np.clip(sig, -1, 1) * 32767).astype(np.int16))
