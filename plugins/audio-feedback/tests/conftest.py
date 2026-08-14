import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "sound-theme", "default", "src"))

import subprocess, os, pytest

@pytest.fixture
def sox_wav(tmp_path):
    """Synthesize a known WAV with sox for measurement tests."""
    def _make(name, *sox_args):
        out = str(tmp_path / name)
        subprocess.run(["sox", "-n", "-r", "44100", "-c", "1", "-b", "16", "--no-dither", out, *sox_args],
                       check=True, capture_output=True)
        return out
    return _make
