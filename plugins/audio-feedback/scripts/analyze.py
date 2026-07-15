#!/usr/bin/env python3
"""Objective audio measurement + target verification for the audio-feedback
default theme. Dev-time tool only (numpy/scipy); never invoked by hooks."""
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
