import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))
import analyze

def test_peaks_finds_fundamental(sox_wav):
    # pure 440 Hz sine, 0.5s
    w = sox_wav("a440.wav", "synth", "0.5", "sine", "440", "fade", "h", "0.01", "0.5", "0.1")
    sr, x = analyze.load(w)
    pk = analyze.peaks(sr, x, n=3)
    freqs = [f for f, _ in pk]
    assert any(abs(f - 440) < 5 for f in freqs)

def test_dominant_is_0db(sox_wav):
    w = sox_wav("a440.wav", "synth", "0.5", "sine", "440", "fade", "h", "0.01", "0.5", "0.1")
    sr, x = analyze.load(w)
    pk = analyze.peaks(sr, x, n=3)
    top = max(pk, key=lambda t: t[1])
    assert abs(top[1]) < 0.5  # loudest partial ~0 dB reference

def test_envelope_attack_and_decay(sox_wav):
    # slow 0.2s fade-in, so attack ~200ms
    w = sox_wav("swell.wav", "synth", "1.0", "sine", "440", "fade", "h", "0.2", "1.0", "0.3")
    sr, x = analyze.load(w)
    atk, dec, dur = analyze.envelope(sr, x)
    assert 0.15 < atk < 0.25
    assert dur > 0.9

def test_peak_dbfs_headroom(sox_wav):
    # file peaks at -6 dBFS; peak_dbfs on the raw samples should report ~-6
    w = sox_wav("q.wav", "synth", "0.3", "sine", "440", "gain", "-6")
    import scipy.io.wavfile as wf
    _, raw = wf.read(w)
    assert analyze.peak_dbfs(raw.astype(float) / 32768.0) < -3


def test_load_targets_has_base_events():
    t = analyze.load_targets()
    for ev in ["stop", "notification", "session-start", "subagent-stop",
               "pre-compact", "user-prompt-submit", "pre-tool-use", "post-tool-use"]:
        assert ev in t

def test_verify_passes_matching_sound(sox_wav):
    # build a 262+392 dyad, C4 dominant, slow attack -> matches "stop" target
    c4 = sox_wav("c4.wav", "synth", "0.9", "sine", "262", "fade", "h", "0.18", "0.9", "0.7")
    g4 = sox_wav("g4.wav", "synth", "0.9", "sine", "392", "fade", "h", "0.18", "0.9", "0.7")
    import subprocess
    mix = c4.replace("c4.wav", "stop.wav")
    subprocess.run(["sox", "-m", "-v", "0.6", c4, "-v", "0.33", g4,
                    "-b", "16", "--no-dither", mix,
                    "gain", "-8", "reverb", "40", "60", "90", "100", "10", "0",
                    "lowpass", "2000", "norm", "-1"], check=True, capture_output=True)
    t = analyze.load_targets()["stop"]
    r = analyze.verify(mix, t)
    assert r["ok"], r["checks"]

def test_verify_fails_wrong_note(sox_wav):
    w = sox_wav("wrong.wav", "synth", "0.9", "sine", "880", "fade", "h", "0.18", "0.9", "0.7", "norm", "-1")
    t = analyze.load_targets()["stop"]
    r = analyze.verify(w, t)
    assert not r["ok"]


def test_palette_loudness_reports_spread(sox_wav, tmp_path):
    # NOTE: analyze.load() peak-normalizes every file, so differing sox "gain"
    # values alone are cancelled out and never reach palette_loudness's RMS
    # calc. To get a genuine, deterministic RMS difference post-normalization
    # we vary duty cycle instead: a full-duration tone vs. the same tone
    # padded with trailing silence to a quarter of the duration. That changes
    # the RMS/peak ratio (crest factor) even after peak-normalization.
    import subprocess
    d = tmp_path / "pal"; d.mkdir()
    # a.wav: tone fills the whole 0.4s file -> RMS ~ -3 dB relative to peak.
    subprocess.run(["sox", "-n", "-r", "44100", "-c", "1", "-b", "16", "--no-dither", str(d / "a.wav"),
                    "synth", "0.4", "sine", "440"], check=True, capture_output=True)
    # b.wav: same peak amplitude, but tone only fills a quarter of the 0.4s
    # file (rest is silence) -> RMS ~6 dB lower relative to peak than a.wav.
    subprocess.run(["sox", "-n", "-r", "44100", "-c", "1", "-b", "16", "--no-dither", str(d / "b.wav"),
                    "synth", "0.1", "sine", "440", "pad", "0", "0.3"], check=True, capture_output=True)
    r = analyze.palette_loudness(str(d))
    assert r["files"] == 2
    assert r["rms_spread_db"] > 3  # ~6 dB crest-factor difference should be clearly detected

    d2 = tmp_path / "pal_equal"; d2.mkdir()
    for f in ["c.wav", "d.wav"]:
        subprocess.run(["sox", "-n", "-r", "44100", "-c", "1", "-b", "16", "--no-dither", str(d2 / f),
                        "synth", "0.4", "sine", "440"], check=True, capture_output=True)
    r2 = analyze.palette_loudness(str(d2))
    assert r2["files"] == 2
    assert r2["rms_spread_db"] < 1  # identical-loudness files -> near-zero spread
