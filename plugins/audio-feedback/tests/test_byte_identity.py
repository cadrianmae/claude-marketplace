"""Determinism gate: the numpy synth renders byte-identical WAVs across two
runs. The voices seed their RNG (reverb RandomState(0), pink-noise fixed seed),
so a fresh render must reproduce the previous one exactly. (Replaces the old
byte-identity-to-signalflow-baseline test, whose goldens the engine rewrite
made obsolete.)
"""
import hashlib
import os

import generate


def _hash_dir(d):
    return {f: hashlib.md5(open(os.path.join(d, f), "rb").read()).hexdigest()
            for f in sorted(os.listdir(d)) if f.endswith(".wav")}


def test_palette_render_is_deterministic(tmp_path):
    a = str(tmp_path / "a")
    b = str(tmp_path / "b")
    generate.cmd_serve_dir(a)
    generate.cmd_serve_dir(b)
    ha, hb = _hash_dir(a), _hash_dir(b)
    assert set(ha) == set(hb)
    assert len(ha) == 41
    for name in ha:
        assert ha[name] == hb[name], f"{name} not reproducible across renders"
