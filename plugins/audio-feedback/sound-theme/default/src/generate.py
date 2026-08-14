# /// script
# dependencies = ["numpy", "scipy", "parsimonious", "numba"]
# ///
"""Generate / preview the audio-feedback default theme (additive bell synthesis).

  generate [--only NAME ...]   render the palette to ../sounds/ (the real output)
  preview  NAME [NAME ...]     render + play NAME(s) to a temp dir (no ../sounds/ write)
  live     NAME [NAME ...]     watch the src files; re-render + play NAME(s) on save

With no subcommand it behaves as `generate` (so `generate.py --only stop` works).
Run via `uv run --script generate.py ...` or the activated dev venv. Prefer the
justfile: `just generate`, `just preview stop`, `just live stop notification`.

Tuning knobs live in tuning.py. Synthesis in voices.py/dsp.py. Loudness in loudness.py.
"""
import json
import os
import subprocess
import sys
import time

import theme
import voices
import dsp
import loudness
from variants import Sound

PREVIEW_DIR = os.path.join(theme.HERE, ".preview")
WATCH_FILES = ["tuning.py", "voices.py", "dsp.py", "loudness.py", "theme.py", "variants.py"]


def _render_events(names: list[str] | None = None) -> dict[str, dsp.Signal]:
    """Render selected (or all) events -> {name: signal}, palette-normalized,
    then per-sound level trims applied (real output loudness, by ear)."""
    targets = theme.all_targets()
    sigs: dict[str, dsp.Signal] = {}
    for name, sound in targets.items():
        if names and name not in names:
            continue
        sigs[name] = voices.render_event(sound)
    sigs = loudness.normalize_palette(sigs)
    for name, sig in sigs.items():
        db = targets[name].level_db
        if db:
            sigs[name] = sig * (10 ** (db / 20))
    return sigs


_NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
_ACCENT_KEYS = ("transpose", "brightness", "decay_scale", "detune_cents", "punch", "layer", "air_db")


def midi_to_name(m: int) -> str:
    return f"{_NOTE_NAMES[m % 12]}{m // 12 - 1}"


def sound_params(name: str, sound: type[Sound]) -> dict[str, object]:
    p: dict[str, object] = {"name": name, "voice": sound.voice, "level_db": sound.level_db}
    if sound.voice == "swoosh":
        p["swoosh_dir"] = sound.swoosh_dir
    else:
        p["notes"] = [midi_to_name(midi + sound.transpose) for _, midi, _ in sound.notes]
        p["accents"] = {k: getattr(sound, k) for k in _ACCENT_KEYS
                        if getattr(sound, k) != getattr(Sound, k)}
    return p


def cmd_serve_dir(out: str) -> None:
    os.makedirs(out, exist_ok=True)
    targets = theme.all_targets()
    for name, sig in _render_events().items():
        theme.write_wav(os.path.join(out, name + ".wav"), sig)
    theme.write_wav(os.path.join(out, "subagent-accent.wav"), voices.render_subagent_accent())
    palette = [sound_params(name, targets[name]) for name in targets]
    with open(os.path.join(out, "palette.json"), "w") as f:
        json.dump(palette, f, indent=2)
    print(f"serve-dir: 28 wavs + palette.json -> {out}")


def cmd_generate(argv: list[str]) -> None:
    only = [argv[i + 1] for i, a in enumerate(argv) if a == "--only"]
    os.makedirs(theme.SOUNDS, exist_ok=True)
    for name, sig in _render_events(only or None).items():
        theme.write_wav(os.path.join(theme.SOUNDS, name + ".wav"), sig)
        print("wrote", name + ".wav")
    if not only or "subagent-accent" in only:
        theme.write_wav(os.path.join(theme.SOUNDS, "subagent-accent.wav"),
                        voices.render_subagent_accent())
        print("wrote subagent-accent.wav")


def _play(path: str) -> None:
    subprocess.run(["paplay", path], check=False)


def cmd_preview(names: list[str]) -> int:
    if not names:
        print("usage: preview NAME [NAME ...]", file=sys.stderr)
        return 2
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    for name in names:
        if name == "subagent-accent":
            sig = voices.render_subagent_accent()
        else:
            sound = theme.all_targets()[name]
            sig = next(iter(loudness.normalize_palette({name: voices.render_event(sound)}).values()))
        path = os.path.join(PREVIEW_DIR, name + ".wav")
        theme.write_wav(path, sig)
        print("preview", name)
        _play(path)
    return 0


def _mtimes() -> dict[str, float]:
    out: dict[str, float] = {}
    for f in WATCH_FILES:
        p = os.path.join(theme.HERE, f)
        try:
            out[f] = os.path.getmtime(p)
        except OSError:
            out[f] = 0
    return out


def cmd_live(names: list[str]) -> int:
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


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if "--serve-dir" in argv:
        i = argv.index("--serve-dir")
        cmd_serve_dir(argv[i + 1])
        return 0
    if argv and argv[0] in ("generate", "preview", "live"):
        cmd, rest = argv[0], argv[1:]
    else:
        cmd, rest = "generate", argv
    if cmd == "preview":
        return cmd_preview(rest)
    if cmd == "live":
        return cmd_live(rest)
    cmd_generate(rest)
    return 0


if __name__ == "__main__":
    sys.exit(main())
