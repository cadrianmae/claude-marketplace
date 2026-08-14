"""Real-time synth: play a MIDI keyboard, hear the voices live, and hot-reload
the DSP code as you edit it. A sounddevice OutputStream callback sums PRE-RENDERED
note buffers (a sample-bank -- Isaac Roberts, 'Drop the DAW'); note-on renders a
note into numpy (~ms) and hands the buffer to the mixer, so the audio thread only
copies and adds. Percussive/decaying voices self-terminate, so note-off is a
no-op. Edit voices.py / dsp.py / tuning.py and the watcher reloads them.

    just live            # play a connected MIDI input (falls back to a demo loop)
"""
import importlib
import os
import sys
import threading
import time

import numpy as np

import dsp
import tuning
import voices
from dsp import midi_hz
from theme import SR

BLOCKSIZE = 256
WATCH = ["dsp.py", "voices.py", "tuning.py"]
DEMO_NOTES = [60, 64, 67, 72]   # a C-major arpeggio for the no-MIDI demo loop


class Mixer:
    """Polyphonic sample-bank mixer. note_on pre-renders a note buffer; each
    render_block sums the active buffers and drops any that have been consumed.
    Thread-safe: the audio callback and the MIDI/reload threads share `active`."""

    def __init__(self, voice_registry: dict) -> None:
        self._voices = dict(voice_registry)
        self._active: list[list] = []               # [buffer, pos] pairs
        self._lock = threading.Lock()

    def swap_voices(self, voice_registry: dict) -> None:
        with self._lock:
            self._voices = dict(voice_registry)

    def note_on(self, midi: int, voice: str = "bell") -> None:
        with self._lock:
            fn = self._voices.get(voice)
        if fn is None:
            return
        buf = np.ascontiguousarray(fn(midi_hz(midi)), dtype=np.float32)
        with self._lock:
            self._active.append([buf, 0])

    def render_block(self, frames: int) -> np.ndarray:
        out = np.zeros((frames, 2), dtype=np.float32)
        with self._lock:
            still = []
            for item in self._active:
                buf, pos = item
                take = min(frames, len(buf) - pos)
                if take > 0:
                    out[:take, 0] += buf[pos:pos + take]
                    out[:take, 1] += buf[pos:pos + take]
                    item[1] = pos + take
                if item[1] < len(buf):
                    still.append(item)
            self._active = still
        return out


def make_callback(mixer: Mixer):
    """PortAudio callback: fill `outdata` (frames x 2) from the mixer, clipped to
    [-1, 1] so a hot buffer can't wrap. Allocation-free copy into the device buffer."""
    def callback(outdata, frames, time_info, status):
        block = mixer.render_block(frames)
        np.clip(block, -1.0, 1.0, out=block)
        outdata[:] = block
    return callback


def _mtimes() -> dict:
    here = os.path.dirname(os.path.abspath(__file__))
    out = {}
    for f in WATCH:
        try:
            out[f] = os.path.getmtime(os.path.join(here, f))
        except OSError:
            out[f] = 0
    return out


def _reload_loop(mixer: Mixer, stop: threading.Event) -> None:
    last = _mtimes()
    while not stop.is_set():
        time.sleep(0.4)
        now = _mtimes()
        if now != last:
            last = now
            try:
                importlib.reload(dsp)
                importlib.reload(tuning)
                importlib.reload(voices)
                mixer.swap_voices(voices.VOICES)
                print("[OK] reloaded voices")
            except Exception as exc:                # a syntax error must not kill audio
                print(f"[WARN] reload failed (keeping current): {exc}")


def _midi_loop(mixer: Mixer, stop: threading.Event) -> bool:
    """Open the first MIDI input and feed note-on to the mixer. Returns True if a
    port was opened, False if none is available (caller starts the demo loop)."""
    try:
        import rtmidi
    except ImportError:
        return False
    midi_in = rtmidi.MidiIn()
    ports = midi_in.get_ports()
    if not ports:
        return False
    midi_in.open_port(0)
    print(f"[OK] MIDI: {ports[0]}")
    while not stop.is_set():
        msg = midi_in.get_message()
        if msg:
            data = msg[0]
            if len(data) >= 3 and (data[0] & 0xF0) == 0x90 and data[2] > 0:
                mixer.note_on(data[1])
        else:
            time.sleep(0.001)
    return True


def _demo_loop(mixer: Mixer, stop: threading.Event) -> None:
    print("[INFO] no MIDI input -- playing a demo arpeggio (edit voices.py to hear reloads)")
    i = 0
    while not stop.is_set():
        mixer.note_on(DEMO_NOTES[i % len(DEMO_NOTES)])
        i += 1
        time.sleep(0.5)


def main(argv: list[str] | None = None) -> int:
    import sounddevice as sd
    mixer = Mixer(voices.VOICES)
    stop = threading.Event()
    threading.Thread(target=_reload_loop, args=(mixer, stop), daemon=True).start()

    def midi_or_demo():
        if not _midi_loop(mixer, stop):
            _demo_loop(mixer, stop)
    threading.Thread(target=midi_or_demo, daemon=True).start()

    with sd.OutputStream(samplerate=SR, channels=2, blocksize=BLOCKSIZE,
                         dtype="float32", callback=make_callback(mixer)):
        print("live: play MIDI (or hear the demo). Ctrl-C to stop.")
        try:
            while True:
                time.sleep(0.1)
        except KeyboardInterrupt:
            stop.set()
            print("\nlive: stopped")
    return 0


if __name__ == "__main__":
    sys.exit(main())
