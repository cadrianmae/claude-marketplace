"""Build design.ipynb -- the by-ear Jupyter audition notebook. Regenerable:
edit the cell sources here and re-run `python build_notebook.py`."""
import os

import nbformat as nbf

CELLS = [
    ("markdown", "# audio-feedback: design by ear\n\n"
                 "Render voices, listen (`Audio` autoplays), and inspect waveform + FFT.\n"
                 "Edit `voices.py` / `tuning.py`, then re-run the imports cell to reload."),
    ("code", "import matplotlib\n"
             "matplotlib.use('Agg')\n"
             "import importlib\n"
             "import numpy as np\n"
             "import matplotlib.pyplot as plt\n"
             "import dsp, voices, tuning\n"
             "importlib.reload(dsp); importlib.reload(tuning); importlib.reload(voices)\n"
             "from theme import SR\n"
             "from variants import SOUNDS\n"
             "from IPython.display import Audio\n"
             "print('sounds:', ', '.join(SOUNDS))"),
    ("markdown", "## Audition one sound"),
    ("code", "sig = voices.render_event(SOUNDS['session-start'])\n"
             "Audio(sig, rate=SR, autoplay=True)"),
    ("markdown", "## Waveform + spectrum"),
    ("code", "def show(name):\n"
             "    sig = voices.render_event(SOUNDS[name]).astype(np.float64)\n"
             "    fig, ax = plt.subplots(1, 2, figsize=(11, 3))\n"
             "    ax[0].plot(np.arange(len(sig)) / SR, sig); ax[0].set_title(name + ' waveform')\n"
             "    mag = np.abs(np.fft.rfft(sig)); freqs = np.fft.rfftfreq(len(sig), 1 / SR)\n"
             "    ax[1].semilogx(freqs[1:], 20 * np.log10(mag[1:] + 1e-9)); ax[1].set_title('spectrum (dB)')\n"
             "    ax[1].set_xlim(20, SR / 2)\n"
             "    plt.tight_layout(); plt.show()\n"
             "show('stop')"),
    ("markdown", "## Render the whole palette (validates every voice)"),
    ("code", "for name in SOUNDS:\n"
             "    s = voices.render_event(SOUNDS[name])\n"
             "    assert s.size and np.all(np.isfinite(s)), name\n"
             "print('[OK]', len(SOUNDS), 'sounds render finite')"),
]


def build() -> str:
    nb = nbf.v4.new_notebook()
    nb.cells = [nbf.v4.new_markdown_cell(src) if kind == "markdown"
                else nbf.v4.new_code_cell(src) for kind, src in CELLS]
    here = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(here, "design.ipynb")
    with open(path, "w") as f:
        nbf.write(nb, f)
    return path


if __name__ == "__main__":
    print("wrote", build())
