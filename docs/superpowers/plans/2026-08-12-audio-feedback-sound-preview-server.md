# Sound Preview Webserver Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A `just serve` Flask dashboard showing all 28 default-theme sounds (waveform + params + play), live-reloading via SSE when the generator source changes, styled in lumae Dusk.

**Architecture:** `generate.py` gains `--serve-dir DIR` (render all 28 WAVs + dump `palette.json`). `serve.py` (Flask) serves an `index.html` dashboard, the preview WAVs, `/api/palette`, and an SSE `/events` stream; a watcher thread re-runs the generator subprocess on source changes and pushes `reload`. The browser draws waveforms (Web Audio + canvas) and re-fetches on SSE. Never touches committed `sounds/`.

**Tech Stack:** Flask (dev dep), the existing generator (`synth`/`theme`/`loudness`/`variants`), vanilla browser JS (Web Audio, canvas, EventSource), lumae Dusk CSS tokens.

## Global Constraints

- The generator is a uv project at `plugins/audio-feedback/sound-theme/default/`; run python via its synced venv `sound-theme/default/.venv/bin/python`, or `just` recipes. `signalflow==0.5.3` (x86_64 wheel).
- All new `.py` fully type-annotated to pass the project's basedpyright (`[tool.basedpyright]`, standard mode, in `sound-theme/default/pyproject.toml`).
- The preview render writes to a preview dir (git-ignored `src/.preview/`), NEVER the committed `sounds/`.
- Dashboard is self-contained: inline CSS + JS, no CDN/external requests. lumae tokens bundled from `~/git/github.com/cadrianmae/lumae/dist/css/{primitives.css,tokens.css,dusk.css}`.
- Flask is a dev dependency only (`[dependency-groups] dev`), never a plugin runtime dep.
- Paths in this plan are relative to `plugins/audio-feedback/` unless absolute.

## File Structure

- `sound-theme/default/src/generate.py` — add `--serve-dir DIR` mode + `palette.json` dump + midi→name/param helpers.
- `sound-theme/default/src/serve.py` — Flask app: routes, watcher thread, SSE, subprocess render.
- `sound-theme/default/src/index.html` — dashboard template (lumae Dusk, inline CSS/JS).
- `sound-theme/default/pyproject.toml` — `flask` in `[dependency-groups] dev`.
- `justfile` — `serve` recipe.
- `tests/test_serve.py` — `--serve-dir` output + Flask test-client route checks.
- `README.md` — document `just serve`.

---

## Task 1: `generate.py --serve-dir` + palette.json

**Files:**
- Modify: `sound-theme/default/src/generate.py`
- Test: `tests/test_serve.py` (created here)

**Interfaces:**
- Produces (CLI): `generate.py --serve-dir DIR` → renders all 28 WAVs into DIR and writes `DIR/palette.json`.
- Produces (python): `midi_to_name(m: int) -> str`; `sound_params(name: str, sound: type[variants.Sound]) -> dict[str, object]`; `cmd_serve_dir(out: str) -> None`.
- `palette.json` = a JSON list; each entry `{"name": str, "voice": "bell"|"swoosh", "level_db": float}` plus, for bell: `"notes": list[str]`, `"accents": dict[str, object]` (only non-default knobs); for swoosh: `"swoosh_dir": "up"|"down"`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_serve.py`:
```python
import json, os, subprocess, sys, wave
import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
PLUGIN = os.path.dirname(HERE)
GEN = os.path.join(PLUGIN, "sound-theme", "default", "src", "generate.py")
PY = os.path.join(PLUGIN, "sound-theme", "default", ".venv", "bin", "python")

BASE = ["session-start", "user-prompt-submit", "pre-tool-use", "notification",
        "pre-compact", "post-tool-use", "subagent-stop", "stop"]


def _py() -> str:
    return PY if os.path.exists(PY) else sys.executable


def test_serve_dir_emits_wavs_and_palette(tmp_path):
    out = str(tmp_path / "preview")
    r = subprocess.run([_py(), GEN, "--serve-dir", out], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    # 28 sounds (8 base + 19 variants + subagent-accent) all present, mono 44100
    names = [f[:-4] for f in os.listdir(out) if f.endswith(".wav")]
    assert len(names) == 28
    for b in BASE:
        assert b in names
        with wave.open(os.path.join(out, b + ".wav")) as w:
            assert w.getnchannels() == 1 and w.getframerate() == 44100
    palette = json.load(open(os.path.join(out, "palette.json")))
    assert len([p for p in palette]) == 27  # 8 base + 19 variants (accent not a card)
    by = {p["name"]: p for p in palette}
    assert by["stop"]["voice"] == "bell" and by["stop"]["notes"][0] == "C5"
    assert by["pre-tool-use-network"]["voice"] == "swoosh"
    assert by["pre-tool-use-network"]["swoosh_dir"] == "up"
    assert "level_db" in by["stop"]
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd plugins/audio-feedback && sound-theme/default/.venv/bin/python -m pytest tests/test_serve.py -q`
Expected: FAIL (unrecognized `--serve-dir` / no palette.json).

- [ ] **Step 3: Add the helpers + mode to `generate.py`**

Add imports at the top of `generate.py` (it already imports `theme`, `synth`, `loudness`; add `json` and the base class):
```python
import json
from variants import Sound
```
Add helpers (near `_render_events`):
```python
_NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
_ACCENT_KEYS = ("transpose", "brightness", "decay_scale", "detune_cents", "punch", "layer", "air_db")


def midi_to_name(m: int) -> str:
    return f"{_NOTE_NAMES[m % 12]}{m // 12 - 1}"


def sound_params(name: str, sound: type[Sound]) -> dict[str, object]:
    p: dict[str, object] = {"name": name, "voice": sound.voice, "level_db": sound.level_db}
    if sound.voice == "swoosh":
        p["swoosh_dir"] = sound.swoosh_dir
    else:
        p["notes"] = [midi_to_name(midi + sound.transpose) for midi, _ in sound.notes]
        p["accents"] = {k: getattr(sound, k) for k in _ACCENT_KEYS
                        if getattr(sound, k) != getattr(Sound, k)}
    return p


def cmd_serve_dir(out: str) -> None:
    os.makedirs(out, exist_ok=True)
    targets = theme.all_targets()
    for name, sig in _render_events().items():
        theme.write_wav(os.path.join(out, name + ".wav"), sig)
    theme.write_wav(os.path.join(out, "subagent-accent.wav"), synth.render_subagent_accent())
    palette = [sound_params(name, targets[name]) for name in targets]
    with open(os.path.join(out, "palette.json"), "w") as f:
        json.dump(palette, f, indent=2)
    print(f"serve-dir: 28 wavs + palette.json -> {out}")
```
In `main()`, dispatch the flag before the subcommand check:
```python
    if "--serve-dir" in argv:
        i = argv.index("--serve-dir")
        cmd_serve_dir(argv[i + 1])
        return 0
```
(Place this at the very top of `main()` after `argv` is normalized.)

- [ ] **Step 4: Run the test — expect PASS**

Run: `cd plugins/audio-feedback && sound-theme/default/.venv/bin/python -m pytest tests/test_serve.py -q`
Expected: 1 passed.

- [ ] **Step 5: basedpyright + commit**

Run: `cd plugins/audio-feedback/sound-theme/default && UV_PYTHON_PREFERENCE=only-managed uvx basedpyright src/generate.py 2>&1 | tail -1` → `0 errors`.
```bash
cd /home/cadrianmae/git/github.com/cadrianmae/claude-marketplace
git add plugins/audio-feedback/sound-theme/default/src/generate.py plugins/audio-feedback/tests/test_serve.py
git commit -m "feat(audio-feedback): generate.py --serve-dir (render all + palette.json)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: `serve.py` Flask app — routes + initial render

**Files:**
- Create: `sound-theme/default/src/serve.py`
- Modify: `sound-theme/default/pyproject.toml` (flask dev dep)
- Test: `tests/test_serve.py` (extend)

**Interfaces:**
- Consumes: `generate.py --serve-dir` (Task 1).
- Produces (python): `create_app(preview_dir: str) -> flask.Flask` with routes `/` (HTML), `/api/palette` (JSON, reads `preview_dir/palette.json`), `/sounds/<name>.wav` (from `preview_dir`), `/events` (SSE, `text/event-stream`). `render(preview_dir: str) -> str | None` runs the generator subprocess, returns an error string or None. Module-level `main()` runs the dev server.

- [ ] **Step 1: Add flask to the dev deps + sync**

In `sound-theme/default/pyproject.toml`, extend the dev group:
```toml
[dependency-groups]
dev = ["pytest", "flask"]
```
Run: `cd plugins/audio-feedback/sound-theme/default && UV_PYTHON_PREFERENCE=only-managed uv sync` → installs flask.

- [ ] **Step 2: Write the failing route test**

Append to `tests/test_serve.py`:
```python
flask = pytest.importorskip("flask")


def _app(tmp_path):
    src = os.path.join(PLUGIN, "sound-theme", "default", "src")
    sys.path.insert(0, src)
    import serve
    out = str(tmp_path / "preview")
    subprocess.run([_py(), GEN, "--serve-dir", out], capture_output=True, text=True, check=True)
    return serve.create_app(out)


def test_routes(tmp_path):
    app = _app(tmp_path)
    c = app.test_client()
    assert c.get("/").status_code == 200
    assert b"sound" in c.get("/").data.lower()
    pal = c.get("/api/palette")
    assert pal.status_code == 200 and len(pal.get_json()) == 27
    wav = c.get("/sounds/stop.wav")
    assert wav.status_code == 200 and wav.data[:4] == b"RIFF"
    ev = c.get("/events")
    assert "text/event-stream" in ev.headers["Content-Type"]
```

- [ ] **Step 3: Run it to verify it fails**

Run: `cd plugins/audio-feedback && sound-theme/default/.venv/bin/python -m pytest tests/test_serve.py::test_routes -q`
Expected: FAIL (`serve` module missing).

- [ ] **Step 4: Write `serve.py`**

Create `sound-theme/default/src/serve.py`:
```python
"""Flask dev dashboard for auditioning the default-theme sounds.

Run: just serve   (or: python serve.py)
Serves index.html, the preview WAVs, /api/palette, and an SSE /events stream;
watches the generator source and re-renders on change. Dev-time only.
"""
import json
import os
import queue
import subprocess
import sys
import threading
import time

import flask

HERE = os.path.dirname(os.path.abspath(__file__))
GEN = os.path.join(HERE, "generate.py")
INDEX = os.path.join(HERE, "index.html")
WATCH = ["tuning.py", "synth.py", "loudness.py", "theme.py", "variants.py"]

# render state, shared with the watcher + SSE
_state = {"version": 0, "error": ""}
_subscribers: list[queue.Queue[str]] = []
_lock = threading.Lock()


def render(preview_dir: str) -> str | None:
    """Run the generator subprocess -> preview_dir. Return an error string or None."""
    env = dict(os.environ, UV_PYTHON_PREFERENCE="only-managed")
    r = subprocess.run([sys.executable, GEN, "--serve-dir", preview_dir],
                       capture_output=True, text=True, env=env)
    return None if r.returncode == 0 else (r.stderr or "render failed")


def _publish(event: str, data: str = "") -> None:
    with _lock:
        for q in list(_subscribers):
            q.put(f"event: {event}\ndata: {data}\n\n")


def _rerender(preview_dir: str) -> None:
    err = render(preview_dir)
    with _lock:
        _state["error"] = err or ""
        if not err:
            _state["version"] += 1
    _publish("error", err) if err else _publish("reload", str(_state["version"]))


def _watch(preview_dir: str) -> None:
    last = {f: _mtime(f) for f in WATCH}
    while True:
        time.sleep(0.3)
        now = {f: _mtime(f) for f in WATCH}
        if now != last:
            last = now
            _rerender(preview_dir)


def _mtime(f: str) -> float:
    try:
        return os.path.getmtime(os.path.join(HERE, f))
    except OSError:
        return 0.0


def create_app(preview_dir: str) -> flask.Flask:
    app = flask.Flask(__name__)

    @app.route("/")
    def index() -> str:
        with open(INDEX) as f:
            return f.read()

    @app.route("/api/palette")
    def palette() -> flask.Response:
        with open(os.path.join(preview_dir, "palette.json")) as f:
            data = json.load(f)
        return flask.jsonify(data)

    @app.route("/sounds/<name>.wav")
    def sound(name: str) -> flask.Response:
        return flask.send_from_directory(preview_dir, name + ".wav", mimetype="audio/wav")

    @app.route("/api/version")
    def version() -> flask.Response:
        with _lock:
            return flask.jsonify({"version": _state["version"], "error": _state["error"]})

    @app.route("/events")
    def events() -> flask.Response:
        def stream():
            q: queue.Queue[str] = queue.Queue()
            with _lock:
                _subscribers.append(q)
            try:
                yield f"event: reload\ndata: {_state['version']}\n\n"
                while True:
                    yield q.get()
            finally:
                with _lock:
                    _subscribers.remove(q)
        return flask.Response(stream(), mimetype="text/event-stream")

    return app


def main() -> None:
    preview_dir = os.path.join(HERE, ".preview")
    os.makedirs(preview_dir, exist_ok=True)
    err = render(preview_dir)          # initial render
    if err:
        print(err, file=sys.stderr)
    _state["version"] = 1
    threading.Thread(target=_watch, args=(preview_dir,), daemon=True).start()
    print("audio-feedback preview: http://127.0.0.1:8765")
    create_app(preview_dir).run(host="127.0.0.1", port=8765, threaded=True)


if __name__ == "__main__":
    main()
```

- [ ] **Step 5: Run the route test — expect PASS**

Run: `cd plugins/audio-feedback && sound-theme/default/.venv/bin/python -m pytest tests/test_serve.py -q`
Expected: all pass. (The `/` route needs `index.html` to exist — create a minimal placeholder now so the test passes; Task 4 writes the real one.)

Create a minimal `sound-theme/default/src/index.html` placeholder:
```html
<!doctype html><html><head><title>audio-feedback sounds</title></head>
<body><h1>sound preview</h1></body></html>
```

- [ ] **Step 6: basedpyright + commit**

Run: `cd plugins/audio-feedback/sound-theme/default && UV_PYTHON_PREFERENCE=only-managed uvx basedpyright src/serve.py 2>&1 | tail -1` → `0 errors`.
```bash
git add plugins/audio-feedback/sound-theme/default/src/serve.py \
        plugins/audio-feedback/sound-theme/default/src/index.html \
        plugins/audio-feedback/sound-theme/default/pyproject.toml \
        plugins/audio-feedback/sound-theme/default/uv.lock \
        plugins/audio-feedback/tests/test_serve.py
git commit -m "feat(audio-feedback): Flask preview server routes + subprocess render

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: The dashboard UI (`index.html`, lumae Dusk)

Replace the placeholder with the real dashboard: lumae-Dusk tokens, card grid, waveforms, playback, SSE live-reload.

**Files:**
- Modify: `sound-theme/default/src/index.html`

**Interfaces:**
- Consumes: `/api/palette`, `/sounds/<name>.wav?v=`, `/events` (Task 2).

- [ ] **Step 1: Bundle the lumae Dusk tokens**

Concatenate the three lumae token files into the page's first `<style>` block (inline, self-contained):
```bash
cat ~/git/github.com/cadrianmae/lumae/dist/css/primitives.css \
    ~/git/github.com/cadrianmae/lumae/dist/css/tokens.css \
    ~/git/github.com/cadrianmae/lumae/dist/css/dusk.css
```
Paste that output verbatim into `<style id="lumae">…</style>` in `index.html`. Set `<html data-theme="dusk">` so the `[data-theme="dusk"]` semantic layer applies.

- [ ] **Step 2: Write `index.html`**

Create `sound-theme/default/src/index.html` (paste the lumae tokens into the `#lumae` style block as Step 1 says; the rest is verbatim):
```html
<!doctype html>
<html lang="en" data-theme="dusk">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>audio-feedback sound preview</title>
<style id="lumae">/* PASTE lumae primitives.css + tokens.css + dusk.css HERE (Step 1) */</style>
<style>
  * { box-sizing: border-box; }
  body { margin: 0; background: var(--color-bg); color: var(--color-text);
         font-family: var(--font-body); padding: var(--space-3); }
  header { display: flex; align-items: center; gap: var(--space-2); margin-bottom: var(--space-3); }
  h1 { font-family: var(--font-heading); font-size: var(--size-h2); margin: 0; }
  .status { display: flex; align-items: center; gap: var(--space-0-5); color: var(--color-subtext);
            font-size: var(--size-caption); }
  .dot { width: 10px; height: 10px; border-radius: var(--radius-pill); background: var(--color-success); }
  .dot.off { background: var(--color-danger); }
  button { font-family: var(--font-body); cursor: pointer; border: 1px solid var(--color-border);
           background: var(--color-surface); color: var(--color-text); border-radius: var(--radius-input);
           padding: var(--space-0-5) var(--space-1); }
  #banner { display: none; background: var(--color-danger); color: var(--color-grey-800);
            padding: var(--space-1); border-radius: var(--radius-input); white-space: pre-wrap;
            font-family: monospace; font-size: var(--size-caption); margin-bottom: var(--space-2); }
  .group-title { font-family: var(--font-heading); font-size: var(--size-lead);
                 color: var(--color-subtext); margin: var(--space-3) 0 var(--space-1); }
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: var(--space-2); }
  .card { background: var(--color-surface); border: 1px solid var(--color-border);
          border-radius: var(--radius-card); padding: var(--space-2); cursor: pointer; transition: border-color .1s; }
  .card:hover { border-color: var(--color-overlay); }
  .card.playing { border-color: var(--color-primary-emphasis); }
  .card .name { font-weight: 600; }
  .badge { font-size: var(--size-caption); padding: 0 var(--space-0-5); border-radius: var(--radius-pill);
           border: 1px solid currentColor; }
  .badge.bell { color: var(--color-success); }
  .badge.swoosh { color: var(--color-primary); }
  canvas { width: 100%; height: 48px; display: block; margin: var(--space-1) 0; }
  .params { color: var(--color-subtext); font-size: var(--size-caption); font-family: monospace; }
</style>
</head>
<body>
<header>
  <h1>audio-feedback sounds</h1>
  <button id="playall">play all</button>
  <span class="status"><span class="dot" id="dot"></span><span id="stat">connecting…</span></span>
</header>
<div id="banner"></div>
<div id="root"></div>
<script>
const ctx = new (window.AudioContext || window.webkitAudioContext)();
let version = 0;
const buffers = {};   // name -> AudioBuffer

const GROUPS = [
  ["base", n => !n.includes("-") || ["user-prompt-submit","pre-tool-use","post-tool-use","pre-compact","subagent-stop","session-start"].includes(n)],
  ["pre-tool-use", n => n.startsWith("pre-tool-use-")],
  ["post-tool-use", n => n.startsWith("post-tool-use-")],
  ["notification", n => n.startsWith("notification-")],
  ["session-start", n => n.startsWith("session-start-")],
];
const BASE = ["session-start","user-prompt-submit","pre-tool-use","notification","pre-compact","post-tool-use","subagent-stop","stop"];

async function loadBuffer(name) {
  const res = await fetch(`/sounds/${name}.wav?v=${version}`);
  const buf = await res.arrayBuffer();
  buffers[name] = await ctx.decodeAudioData(buf);
  return buffers[name];
}

function drawWave(canvas, audiobuf) {
  const w = canvas.width = canvas.clientWidth * devicePixelRatio;
  const h = canvas.height = canvas.clientHeight * devicePixelRatio;
  const g = canvas.getContext("2d");
  const data = audiobuf.getChannelData(0);
  const step = Math.max(1, Math.floor(data.length / w));
  g.clearRect(0, 0, w, h);
  g.strokeStyle = getComputedStyle(document.body).getPropertyValue("--color-info");
  g.beginPath();
  for (let x = 0; x < w; x++) {
    let min = 1, max = -1;
    for (let i = 0; i < step; i++) { const v = data[x*step+i] || 0; if (v<min) min=v; if (v>max) max=v; }
    g.moveTo(x, (1-min)*h/2); g.lineTo(x, (1-max)*h/2);
  }
  g.stroke();
}

function play(name, card) {
  const src = ctx.createBufferSource();
  src.buffer = buffers[name];
  src.connect(ctx.destination);
  src.start();
  if (card) { card.classList.add("playing"); src.onended = () => card.classList.remove("playing"); }
  return src;
}

function paramText(p) {
  if (p.voice === "swoosh") return `swoosh ${p.swoosh_dir === "up" ? "↑ send" : "↓ receive"}`;
  const acc = Object.entries(p.accents || {}).map(([k,v]) => `${k}=${v}`).join(" ");
  const lvl = p.level_db ? ` ${p.level_db}dB` : "";
  return `${p.notes.join(" ")}${acc ? " · "+acc : ""}${lvl}`;
}

async function build(palette) {
  const root = document.getElementById("root");
  root.innerHTML = "";
  const order = {}; BASE.forEach((n,i) => order[n] = i);
  for (const [title, test] of GROUPS) {
    const items = palette.filter(p => test(p.name));
    if (!items.length) continue;
    if (title === "base") items.sort((a,b)=> (order[a.name]??99)-(order[b.name]??99));
    const h = document.createElement("div"); h.className = "group-title"; h.textContent = title;
    const grid = document.createElement("div"); grid.className = "grid";
    root.append(h, grid);
    for (const p of items) {
      const card = document.createElement("div"); card.className = "card";
      card.innerHTML = `<div class="name">${p.name} <span class="badge ${p.voice}">${p.voice}</span></div>
        <canvas></canvas><div class="params">${paramText(p)}</div>`;
      grid.append(card);
      const canvas = card.querySelector("canvas");
      await loadBuffer(p.name).then(b => drawWave(canvas, b));
      card.onclick = () => play(p.name, card);
    }
  }
}

async function refresh() {
  const palette = await (await fetch("/api/palette")).json();
  await build(palette);
}

document.getElementById("playall").onclick = async () => {
  for (const name of Object.keys(buffers)) {
    const src = play(name); await new Promise(r => src.onended = r);
  }
};

const es = new EventSource("/events");
es.onopen = () => { document.getElementById("dot").classList.remove("off"); document.getElementById("stat").textContent = "live"; };
es.onerror = () => { document.getElementById("dot").classList.add("off"); document.getElementById("stat").textContent = "disconnected"; };
es.addEventListener("reload", async e => {
  version = e.data; document.getElementById("banner").style.display = "none";
  await refresh();
});
es.addEventListener("error", e => {
  const b = document.getElementById("banner"); b.style.display = "block"; b.textContent = e.data;
});
</script>
</body>
</html>
```

- [ ] **Step 3: Manual smoke (note: browser test is by-eye)**

Run the server and open it:
```bash
cd plugins/audio-feedback && sound-theme/default/.venv/bin/python sound-theme/default/src/serve.py
```
Open `http://127.0.0.1:8765`. Expected: lumae-Dusk dashboard, cards grouped by family, waveforms drawn, click plays, "live" status dot. Edit `tuning.py` (e.g. `BELL_DUR = 0.8`), save → the grid re-renders within ~1s and re-fetched sounds reflect it. Ctrl-C to stop; revert the tuning edit.

- [ ] **Step 4: Route test still green + commit**

Run: `cd plugins/audio-feedback && sound-theme/default/.venv/bin/python -m pytest tests/test_serve.py -q` → pass (the `/` route now returns the real HTML; the test only checks it contains "sound").
```bash
git add plugins/audio-feedback/sound-theme/default/src/index.html
git commit -m "feat(audio-feedback): lumae-Dusk sound dashboard (waveforms, play, SSE reload)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: `just serve` recipe + docs

**Files:**
- Modify: `justfile`, `README.md`, `.gitignore` (ensure `.preview/` ignored — already is)

**Interfaces:** none.

- [ ] **Step 1: Add the `serve` recipe**

In `plugins/audio-feedback/justfile`, add:
```make
# live sound-preview dashboard (lumae Dusk) at http://127.0.0.1:8765
serve:
    {{py}} {{src}}/serve.py
```

- [ ] **Step 2: Document in README**

In `README.md`'s "Regenerating sounds" section, add after the iterate block:
```markdown
Or preview the whole palette in the browser (lumae Dusk), with live-reload on save:

    just serve        # http://127.0.0.1:8765 — all sounds, waveforms, click to play
```

- [ ] **Step 3: Verify + commit**

Run: `cd plugins/audio-feedback && just --list | grep serve` → shows the recipe.
```bash
git add plugins/audio-feedback/justfile plugins/audio-feedback/README.md
git commit -m "docs(audio-feedback): just serve recipe + README for the preview dashboard

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:**
- Flask server + routes (/,/api/palette,/sounds,/events) → Task 2. `--serve-dir` + palette.json → Task 1. Watcher + SSE reload/error → Task 2 (`_watch`/`_rerender`/`_publish`). Dashboard UI (cards, waveform, params, play, grouping, lumae Dusk) → Task 3. flask dev dep → Task 2. `just serve` + docs → Task 4. Preview dir never touches `sounds/` → Task 1/2 (`--serve-dir` + `.preview`). Testing (`--serve-dir` output + Flask test-client) → Tasks 1-2; browser/SSE manual → Task 3 Step 3. basedpyright typed → Tasks 1-2 steps. All spec sections covered.

**Placeholder scan:** No TBD/TODO. The one intentional paste-point (lumae tokens in `#lumae`) has an exact `cat` command producing the content (Task 3 Step 1) — not a vague placeholder. All code blocks are literal.

**Type/name consistency:** `midi_to_name`/`sound_params`/`cmd_serve_dir` defined + tested in Task 1. `create_app(preview_dir)`/`render`/`_rerender`/`_publish`/`_watch`/`_mtime`/`main` consistent within `serve.py` (Task 2), consumed by the test (Task 2). Routes `/api/palette`,`/sounds/<name>.wav`,`/events`,`/api/version` match the JS `fetch`/`EventSource` calls in Task 3. `palette.json` entry shape (name/voice/level_db/notes/accents/swoosh_dir) consistent between Task 1 producer, Task 1 test, and Task 3 `paramText`. `--serve-dir` flag consistent across Task 1 (main dispatch), the test, and `serve.render` (Task 2). 28 WAVs vs 27 palette cards (accent excluded) consistent between Task 1 test and Task 2 test.
