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
