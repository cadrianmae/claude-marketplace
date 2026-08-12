"""Theme paths + WAV I/O for the audio-feedback generator.

Plumbing only: paths, sample rate, the sound registry, and writing WAVs. The
palette (note-map + accents) lives in variants.py as a class hierarchy; the
synthesis lives in synth.py.
"""
import os

import numpy as np

from variants import SOUNDS as _SOUNDS

SR = 44100  # output sample rate (fixed by the plugin's WAV format, not a tuning knob)

HERE = os.path.dirname(os.path.abspath(__file__))
SOUNDS = os.path.normpath(os.path.join(HERE, "..", "sounds"))  # output WAV dir


def all_targets():
    """name -> Sound class, for the 8 base + 19 variants."""
    return dict(_SOUNDS)


def write_wav(path, sig):
    """Write a mono float signal as 16-bit PCM at SR."""
    import scipy.io.wavfile as wav
    wav.write(path, SR, (np.clip(sig, -1, 1) * 32767).astype(np.int16))
