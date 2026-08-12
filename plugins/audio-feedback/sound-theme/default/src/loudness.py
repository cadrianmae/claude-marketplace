"""Palette loudness pass.

Evens out loudness across the palette so it survives analyze.py's --palette
gate, WITHOUT crushing the struck-bell character. Only outliers get nudged, and
only their decay tail is shaped (the transient is left exactly as rendered).

Why crest factor, not gain: analyze.py peak-normalizes each file to 0 dBFS
*before* measuring RMS, so a uniform per-file gain has zero effect on the
measured spread. What actually varies between events is crest factor
(peak-to-RMS ratio), driven by accent shape. So we adjust crest, gently, on
outliers only. Knobs live in tuning.py (CREST_TOLERANCE_DB, PEAK_GUARD_S, ...).
"""
import numpy as np

import tuning
from theme import SR

PEAK_CEILING = 10 ** (tuning.PEAK_CEILING_DB / 20)


def _crest_db(sig):
    """peak/RMS ratio in dB. Scale-invariant: a uniform gain doesn't change it."""
    peak = np.max(np.abs(sig)) + 1e-9
    rms = np.sqrt(np.mean(sig.astype(np.float64) ** 2)) + 1e-9
    return 20 * np.log10(peak / rms)


def _shape_tail(sig, p):
    """Sign-preserving power-law shaper on the decay tail only (after the
    transient peak + PEAK_GUARD_S, crossfaded in). p<1 compresses the tail
    (lowers crest), p>1 expands it (raises crest), p=1 is a no-op. The attack
    is left bit-for-bit intact."""
    if abs(p - 1.0) < 1e-6:
        return sig
    peak_i = int(np.argmax(np.abs(sig)))
    guard = min(peak_i + int(SR * tuning.PEAK_GUARD_S), len(sig))
    if guard >= len(sig):
        return sig
    out = sig.copy()
    tail = sig[guard:]
    shaped_tail = np.sign(tail) * (np.abs(tail) ** p)
    xfade = min(int(SR * tuning.CROSSFADE_S), len(tail))
    if xfade > 0:
        ramp = np.linspace(0.0, 1.0, xfade)
        shaped_tail[:xfade] = tail[:xfade] * (1 - ramp) + shaped_tail[:xfade] * ramp
    out[guard:] = shaped_tail
    return out


def normalize_palette(sigs):
    """Nudge crest-factor outliers back inside the tolerance window (tail-only),
    then apply a uniform per-file peak ceiling. In-tolerance files are untouched."""
    crest = {n: _crest_db(s) for n, s in sigs.items()}
    center = float(np.mean(list(crest.values())))
    lo0, hi0 = tuning.CREST_SHAPE_RANGE
    out = {}
    for n, s in sigs.items():
        c0 = crest[n]
        if abs(c0 - center) <= tuning.CREST_TOLERANCE_DB:
            shaped = s
        else:
            target = center + tuning.CREST_TOLERANCE_DB if c0 > center else center - tuning.CREST_TOLERANCE_DB
            lo, hi = lo0, hi0
            for _ in range(tuning.CREST_SHAPE_ITERS):
                mid = (lo + hi) / 2
                if _crest_db(_shape_tail(s, mid)) > target:
                    hi = mid
                else:
                    lo = mid
            shaped = _shape_tail(s, (lo + hi) / 2)
        peak = np.max(np.abs(shaped)) + 1e-9
        out[n] = shaped * (PEAK_CEILING / peak)
    return out
