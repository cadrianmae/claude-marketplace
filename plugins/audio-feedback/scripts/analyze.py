#!/usr/bin/env python3
"""Objective audio measurement + target verification for the audio-feedback
default theme. Dev-time tool only (numpy/scipy); never invoked by hooks."""
import glob
import json
import os
import sys

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


def palette_loudness(directory):
    rms = []
    peak_max = -120.0
    files = sorted(glob.glob(os.path.join(directory, "*.wav")))
    for p in files:
        sr, x = load(p)
        rms.append(20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-9))
        _, raw = wavfile.read(p)
        raw = (raw.mean(1) if raw.ndim > 1 else raw).astype(float)
        raw = raw / 32768.0 if raw.max() > 1.5 else raw
        peak_max = max(peak_max, peak_dbfs(raw))
    spread = (max(rms) - min(rms)) if rms else 0.0
    return {"files": len(files), "rms_spread_db": round(spread, 2),
            "peak_max_dbfs": round(peak_max, 2)}


def main(argv=None):
    argv = argv if argv is not None else sys.argv[1:]
    if argv and argv[0] == "--palette":
        if len(argv) < 2:
            print("usage: analyze.py --palette <dir>", file=sys.stderr)
            return 2
        directory = argv[1]
        r = palette_loudness(directory)
        if r["files"] == 0:
            print(f"[WARN] no .wav files found in palette directory: {directory}")
            return 2
        print(f"palette: {r['files']} files, RMS spread {r['rms_spread_db']} dB, "
              f"peak max {r['peak_max_dbfs']} dBFS")
        return 0 if r["rms_spread_db"] <= 3.0 and r["peak_max_dbfs"] <= -0.7 else 1
    if not argv:
        print("usage: analyze.py <wav> [event] | analyze.py --palette <dir>")
        return 2
    path = argv[0]
    event = argv[1] if len(argv) > 1 else os.path.splitext(os.path.basename(path))[0]
    targets = load_targets()
    if event not in targets:
        sr, x = load(path)
        print(f"{event}: partials {peaks(sr, x)}, envelope {envelope(sr, x)}")
        return 0
    r = verify(path, targets[event])
    for c in r["checks"]:
        tag = "[OK]  " if c["ok"] else "[WARN]"
        print(f"{tag} {c['name']}: measured {c['measured']} expected {c['expected']}")
    print("[OK] PASS" if r["ok"] else "[WARN] FAIL")
    return 0 if r["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
