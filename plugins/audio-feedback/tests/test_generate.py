import os, shutil, subprocess, wave, sys
import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
PLUGIN = os.path.dirname(HERE)
GEN = os.path.join(PLUGIN, "sound-theme", "default", "src", "generate.py")
SOUNDS = os.path.join(PLUGIN, "sound-theme", "default", "sounds")
ANALYZE = os.path.join(PLUGIN, "scripts", "analyze.py")
BASE = ["session-start","user-prompt-submit","pre-tool-use","notification",
        "pre-compact","post-tool-use","subagent-stop","stop"]

pytestmark = pytest.mark.skipif(shutil.which("uv") is None, reason="uv required")

def _run_gen(*args):
    env = dict(os.environ, UV_PYTHON_PREFERENCE="only-managed")
    r = subprocess.run(["uv","run","--script",GEN,*args],
                       capture_output=True, text=True, env=env)
    assert r.returncode == 0, r.stderr
    return r

def test_base_sounds_emitted_mono_44100():
    _run_gen(*sum([["--only",b] for b in BASE], []))
    for b in BASE:
        p = os.path.join(SOUNDS, b + ".wav")
        assert os.path.exists(p), f"missing {b}.wav"
        with wave.open(p) as w:
            assert w.getnchannels() == 1 and w.getframerate() == 44100 and w.getsampwidth() == 2
