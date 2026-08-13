"""Regression tests for click artifacts (truncated bell decay).

A click is a sample-to-sample discontinuity. Its root cause here was the bell
render buffer being exactly BELL_DUR long while the envelope (attack + release)
runs longer -- so each note's decay was amputated, and in a phrase every note
but the last dropped to a truncated tail at its slot end (one click per note).

These tests assert the synthesis stage produces no such step:
  - a raw bell rings out to ~silence before its buffer ends
  - an assembled phrase has no interior step discontinuity
Run: .venv/bin/python -m pytest tests/test_no_click.py -q  (from the plugin dir)
"""
import os, sys
import numpy as np

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "..", "sound-theme", "default", "src")
sys.path.insert(0, os.path.abspath(SRC))

from synth import render_bell, render_event, midi_hz  # noqa: E402
from variants import SOUNDS             # noqa: E402

RING_OUT = 0.02      # a bell must decay below this before its buffer ends
# A click is an ISOLATED step: a big sample-to-sample jump whose neighbours are
# small. A loud high partial has a steep but *sustained* slope (neighbouring
# jumps are just as big), so raw max-jump can't tell them apart. The isolation
# score below subtracts each jump's largest neighbour, so a smooth slope scores
# ~0 and only a standalone step scores high. Truncation clicks scored ~0.18;
# clean renders score < 0.003. 0.05 is the gap.
ISO_MAX = 0.05
PHRASES = ["session-start", "notification-idle", "stop"]  # multi-note sounds


def _isolation(sig):
    """Largest jump that stands alone (a step), ignoring sustained slopes."""
    d = np.abs(np.diff(sig))
    neighbour = np.zeros_like(d)
    for shift in (-2, -1, 1, 2):
        neighbour = np.maximum(neighbour, np.roll(d, shift))
    return float((d - neighbour).max())


def test_raw_bell_rings_out():
    """A struck bell decays to ~silence within its own buffer (no truncation)."""
    tail = abs(float(render_bell(midi_hz(72))[-1]))
    assert tail < RING_OUT, f"bell truncated at |{tail:.3f}| (envelope amputated)"


def test_phrases_have_no_interior_click():
    """No note in a phrase drops to a truncated tail at its slot boundary."""
    for name in PHRASES:
        iso = _isolation(render_event(SOUNDS[name]))
        assert iso < ISO_MAX, f"{name}: isolated step {iso:.3f} (click)"
