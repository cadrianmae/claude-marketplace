# /// script
# requires-python = ">=3.12,<3.13"
# dependencies = ["signalflow", "numpy", "scipy"]
# ///
"""Generate / preview the audio-feedback default theme (additive bell synthesis).

  generate [--only NAME ...]   render the palette to ../sounds/ (the real output)
  preview  NAME [NAME ...]     render + play NAME(s) to a temp dir (no ../sounds/ write)
  live     NAME [NAME ...]     watch the src files; re-render + play NAME(s) on save

With no subcommand it behaves as `generate` (so `generate.py --only stop` works).
Run via `uv run --script generate.py ...` or the activated dev venv. Prefer the
justfile: `just generate`, `just preview stop`, `just live stop notification`.

Tuning knobs live in tuning.py. Synthesis in synth.py. Loudness in loudness.py.
"""
import os
import subprocess
import sys
import time

import theme
import synth
import loudness

PREVIEW_DIR = os.path.join(theme.HERE, ".preview")
WATCH_FILES = ["tuning.py", "synth.py", "loudness.py", "theme.py", "variants.py"]


def _render_events(names=None):
    """Render selected (or all) events -> {name: signal}, palette-normalized."""
    sigs = {}
    for name, sound in theme.all_targets().items():
        if names and name not in names:
            continue
        sigs[name] = synth.render_event(sound)
    return loudness.normalize_palette(sigs)


def cmd_generate(argv):
    only = [argv[i + 1] for i, a in enumerate(argv) if a == "--only"]
    os.makedirs(theme.SOUNDS, exist_ok=True)
    for name, sig in _render_events(only or None).items():
        theme.write_wav(os.path.join(theme.SOUNDS, name + ".wav"), sig)
        print("wrote", name + ".wav")
    if not only or "subagent-accent" in only:
        theme.write_wav(os.path.join(theme.SOUNDS, "subagent-accent.wav"),
                        synth.render_subagent_accent())
        print("wrote subagent-accent.wav")


def _play(path):
    subprocess.run(["paplay", path], check=False)


def cmd_preview(names):
    if not names:
        print("usage: preview NAME [NAME ...]", file=sys.stderr)
        return 2
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    for name in names:
        if name == "subagent-accent":
            sig = synth.render_subagent_accent()
        else:
            sound = theme.all_targets()[name]
            sig = next(iter(loudness.normalize_palette({name: synth.render_event(sound)}).values()))
        path = os.path.join(PREVIEW_DIR, name + ".wav")
        theme.write_wav(path, sig)
        print("preview", name)
        _play(path)
    return 0


def _mtimes():
    out = {}
    for f in WATCH_FILES:
        p = os.path.join(theme.HERE, f)
        try:
            out[f] = os.path.getmtime(p)
        except OSError:
            out[f] = 0
    return out


def cmd_live(names):
    if not names:
        print("usage: live NAME [NAME ...]", file=sys.stderr)
        return 2
    print(f"live: watching {', '.join(WATCH_FILES)} -> re-render {', '.join(names)} on save (Ctrl-C to stop)")
    # render once up front (fresh subprocess so edits are always picked up)
    subprocess.run([sys.executable, __file__, "preview", *names], check=False)
    last = _mtimes()
    try:
        while True:
            time.sleep(0.4)
            now = _mtimes()
            if now != last:
                last = now
                print("--- change detected, re-rendering ---")
                subprocess.run([sys.executable, __file__, "preview", *names], check=False)
    except KeyboardInterrupt:
        print("\nlive: stopped")
    return 0


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    if argv and argv[0] in ("generate", "preview", "live"):
        cmd, rest = argv[0], argv[1:]
    else:
        cmd, rest = "generate", argv
    if cmd == "preview":
        return cmd_preview(rest)
    if cmd == "live":
        return cmd_live(rest)
    return cmd_generate(rest)


if __name__ == "__main__":
    sys.exit(main() or 0)
