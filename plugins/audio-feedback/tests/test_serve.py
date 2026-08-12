import json, os, subprocess, sys, wave
import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
PLUGIN = os.path.dirname(HERE)
GEN = os.path.join(PLUGIN, "sound-theme", "default", "src", "generate.py")
PY = os.path.join(PLUGIN, "sound-theme", "default", ".venv", "bin", "python")

BASE = ["session-start", "user-prompt-submit", "pre-tool-use", "notification",
        "pre-compact", "post-tool-use", "subagent-stop", "stop"]


def _py() -> str:
    return PY if os.path.exists(PY) else sys.executable


def test_serve_dir_emits_wavs_and_palette(tmp_path):
    out = str(tmp_path / "preview")
    r = subprocess.run([_py(), GEN, "--serve-dir", out], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    # 28 sounds (8 base + 19 variants + subagent-accent) all present, mono 44100
    names = [f[:-4] for f in os.listdir(out) if f.endswith(".wav")]
    assert len(names) == 28
    for b in BASE:
        assert b in names
        with wave.open(os.path.join(out, b + ".wav")) as w:
            assert w.getnchannels() == 1 and w.getframerate() == 44100
    palette = json.load(open(os.path.join(out, "palette.json")))
    assert len([p for p in palette]) == 27  # 8 base + 19 variants (accent not a card)
    by = {p["name"]: p for p in palette}
    assert by["stop"]["voice"] == "bell" and by["stop"]["notes"][0] == "C5"
    assert by["pre-tool-use-network"]["voice"] == "swoosh"
    assert by["pre-tool-use-network"]["swoosh_dir"] == "up"
    assert "level_db" in by["stop"]
