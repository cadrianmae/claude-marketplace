#!/usr/bin/env python3
"""Objective audio measurement + target verification for the audio-feedback
default theme. Dev-time tool only (numpy/scipy); never invoked by hooks."""
import json
import os

import numpy as np
from scipy.io import wavfile


def load(path):
    sr, x = wavfile.read(path)
    if x.ndim > 1:
        x = x.mean(1)
    x = x.astype(float)
    x = x / (np.abs(x).max() + 1e-9)           # peak-normalize; relative measures
    return sr, x


def peaks(sr, x, n=5):
    seg = x[int(0.06 * sr):]                       # skip attack transient
    if len(seg) < 16:
        seg = x
    w = np.hanning(len(seg))
    X = np.abs(np.fft.rfft(seg * w))
    f = np.fft.rfftfreq(len(seg), 1 / sr)
    X = X / (X.max() + 1e-9)
    idx = []
    for i in np.argsort(X)[::-1]:
        if f[i] < 40:
            continue
        if all(abs(f[i] - f[j]) > 25 for j in idx):
            idx.append(i)
        if len(idx) >= n:
            break
    idx.sort(key=lambda i: f[i])
    return [(round(float(f[i]), 1), round(float(20 * np.log10(X[i] + 1e-9)), 1))
            for i in idx]


def envelope(sr, x):
    hop = max(1, int(0.01 * sr))
    e = np.array([np.sqrt(np.mean(x[i:i + hop] ** 2))
                  for i in range(0, len(x) - hop, hop)])
    e = e / (e.max() + 1e-9)
    t = np.arange(len(e)) * (hop / sr)
    pk = int(np.argmax(e))
    attack = float(t[pk]) if len(t) else 0.0
    below = np.where(e[pk:] < 0.1)[0]
    decay = float(below[0] * hop / sr) if len(below) else float((len(e) - pk) * hop / sr)
    return attack, decay, len(x) / sr


def peak_dbfs(x):
    p = float(np.abs(x).max())
    return 20 * np.log10(p + 1e-9)


def load_targets(path=None):
    if path is None:
        path = os.path.join(os.path.dirname(__file__), "sound_targets.json")
    with open(path) as f:
        return json.load(f)


def _nearest_level(pk, hz):
    """dB level of the partial nearest hz (or -120 if none within 30 Hz)."""
    cand = [(abs(f - hz), lv) for f, lv in pk]
    cand.sort()
    return cand[0][1] if cand and cand[0][0] < 30 else -120.0


def verify(path, target):
    sr, x = load(path)
    pk = peaks(sr, x, n=6)
    atk, dec, dur = envelope(sr, x)
    _, raw = wavfile.read(path)
    raw = (raw.mean(1) if raw.ndim > 1 else raw).astype(float)
    raw = raw / 32768.0 if raw.max() > 1.5 else raw
    raw_peak = peak_dbfs(raw)

    checks = []

    dom = target["dominant_hz"]
    top = max(pk, key=lambda t: t[1]) if pk else (0, -120)
    checks.append({"name": "dominant_note", "ok": abs(top[0] - dom) < 15,
                   "measured": top[0], "expected": dom})

    if len(target["partials_hz"]) > 1:
        others = [h for h in target["partials_hz"] if h != dom]
        sec_lv = max(_nearest_level(pk, h) for h in others)
        checks.append({"name": "second_level_db", "ok": sec_lv <= target["second_max_db"] + 3,
                       "measured": sec_lv, "expected": f"<= {target['second_max_db']}"})

    lo, hi = target["attack_ms"]
    checks.append({"name": "attack_ms", "ok": lo - 40 <= atk * 1000 <= hi + 40,
                   "measured": round(atk * 1000), "expected": f"{lo}-{hi}"})

    lo, hi = target["decay_ms"]
    checks.append({"name": "decay_ms", "ok": lo - 80 <= dec * 1000 <= hi + 80,
                   "measured": round(dec * 1000), "expected": f"{lo}-{hi}"})

    checks.append({"name": "peak_dbfs", "ok": raw_peak <= target["peak_dbfs_max"] + 0.3,
                   "measured": round(raw_peak, 1), "expected": f"<= {target['peak_dbfs_max']}"})

    return {"ok": all(c["ok"] for c in checks), "checks": checks}
