import os

import generate
import theme


def test_serve_dir_writes_full_palette(tmp_path):
    out = str(tmp_path / "snd")
    generate.cmd_serve_dir(out)
    wavs = [f for f in os.listdir(out) if f.endswith(".wav")]
    assert len(wavs) == 28                          # 27 palette + subagent-accent
    assert "subagent-accent.wav" in wavs
    assert os.path.exists(os.path.join(out, "palette.json"))
    for name in theme.all_targets():
        assert os.path.exists(os.path.join(out, name + ".wav"))


def test_generate_module_has_no_signalflow():
    import importlib.util
    src = importlib.util.find_spec("generate").origin
    with open(src) as f:
        assert "signalflow" not in f.read().lower()
    with open(importlib.util.find_spec("voices").origin) as f:
        assert "signalflow" not in f.read().lower()
