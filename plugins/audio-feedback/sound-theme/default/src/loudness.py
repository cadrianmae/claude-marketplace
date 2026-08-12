"""Palette loudness pass.

Currently: peak-normalize each sound to the ceiling (-1 dBFS). An earlier
crest-factor matching step was removed -- it produced audible distortion on
high-crest phrases (session-start-*), and loudness is now judged by ear.
`crest_db` is kept as a diagnostic for that tuning.
"""
import numpy as np
from numpy.typing import NDArray

import tuning

Signal = NDArray[np.float32]

PEAK_CEILING = 10 ** (tuning.PEAK_CEILING_DB / 20)


def crest_db(sig: Signal) -> float:
    """peak/RMS ratio in dB. Scale-invariant. Kept as a diagnostic helper for
    tuning loudness by ear (not used by the current peak-only normalize)."""
    peak = float(np.max(np.abs(sig))) + 1e-9
    rms = float(np.sqrt(np.mean(sig.astype(np.float64) ** 2))) + 1e-9
    return 20 * np.log10(peak / rms)


def normalize_palette(sigs: dict[str, Signal]) -> dict[str, Signal]:
    """Peak-normalize each sound to the ceiling. No crest-matching / dynamics
    processing -- that produced audible distortion on high-crest phrases
    (session-start-*). Loudness consistency is now judged by ear; per-sound
    level trims can be added to tuning.py if a sound sits too hot/quiet."""
    out = {}
    for n, s in sigs.items():
        peak = np.max(np.abs(s)) + 1e-9
        out[n] = s * (PEAK_CEILING / peak)
    return out
