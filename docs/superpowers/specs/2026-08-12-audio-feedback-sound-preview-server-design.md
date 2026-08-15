# audio-feedback — Sound Preview Webserver

Date: 2026-08-12
Branch: `feat/audio-feedback-sound-redesign`
Status: Approved design, pre-implementation
Depends on: the sound generator (`sound-theme/default/src/`, a uv project) — `synth`/`theme`/`loudness`/`variants` + `generate.py`.

## Context

The default-theme sounds are generated programmatically (28 sounds: bells +
swoosh voices) and tuned by ear via `just live <name>` (CLI file-watch →
re-render → `paplay`). This adds a **browser dashboard** that shows the whole
palette at once — each sound with a waveform, its params, and a play button —
and live-reloads when the generator source changes. Styled with **lumae Dusk**
(Mae's own design system).

## Goals

- See all 28 sounds at a glance; click any to play.
- Waveform + params per sound (voice, note-map / swoosh direction, accents,
  `level_db`).
- Live-reload: editing `tuning.py` / `variants.py` / `synth.py` / `loudness.py`
  re-renders and refreshes the dashboard automatically.
- Authentic lumae Dusk styling via the project's real semantic tokens.
- Dev-time only: never touches the committed `sounds/`; flask is a dev dep.

## Non-goals

- Editing params in the browser (read-only preview; tuning stays in the code).
- Multiple lumae variants / a theme switcher (Dusk only).
- Spectrograms, multi-user, auth, remote hosting (local single-user).

---

## Section 1 — Architecture

A small **Flask** dev-server, `sound-theme/default/src/serve.py`, run via
`just serve`. Routes:

- `GET /` → the dashboard HTML (`index.html`, lumae-Dusk, inline CSS/JS).
- `GET /api/palette` → JSON: every sound's `name`, `voice`, params, and the
  current render `version`.
- `GET /sounds/<name>.wav?v=<version>` → the rendered WAV from the **preview
  dir** (never the committed `sounds/`). The `v` query-param cache-busts.
- `GET /events` → SSE stream; emits `reload` after each re-render, `error`
  with a traceback if a render fails.

`serve.py` owns HTTP + file-watching + SSE + subprocess orchestration. It does
NOT reimplement synthesis — audio + params come from the generator. Flask goes
in the uv project's `[dependency-groups] dev`; a `just serve` recipe launches it
on the synced venv.

## Section 2 — Data flow

**Render on change (server):**
```
watcher thread (debounced ~300ms) sees tuning/synth/loudness/variants.py change
  -> subprocess: python generate.py --serve-dir <preview>
       (renders all 28 WAVs AND writes palette.json into <preview>)
  -> version += 1
  -> SSE: emit "reload"   (or "error" + traceback if the subprocess failed)
```
Subprocess (not in-process `importlib.reload`) so every edit is picked up
cleanly, matching `just live`'s robustness. A `tuning.py` change affects every
bell, so "render all" is the safe default; the few-second cost is acceptable
for a preview. `generate.py` gains one mode: `--serve-dir DIR` → render the
palette to `DIR` + dump `palette.json` (each sound's `voice` and params). The
server stays thin: serve the preview dir + watch + SSE.

**Browser:**
```
on load / on SSE "reload":
  fetch /api/palette -> rebuild the card grid + params
  per card: fetch /sounds/<name>.wav?v=<version>
            -> Web Audio decodeAudioData -> draw waveform on <canvas>
  click card / play button -> play the decoded buffer
```
SSE auto-reconnects if the server restarts. On `error`, a banner shows the
traceback without blanking the grid; the last good preview stays playable.

## Section 3 — UI & lumae styling

**Layout:** header (title · SSE status dot · last-render time · "play all") + a
responsive card grid grouped by family: base events, then `pre-tool-use-*`,
`post-tool-use-*`, `notification-*`, `session-start-*`.

**Card:** name; a **voice badge** (`bell` / `swoosh`); a **waveform** `<canvas>`
(Web Audio `decodeAudioData` → peak draw); **params** (bell → note names +
non-default accents + `level_db`; swoosh → ↑ send / ↓ receive); click / ▶ to
play; playing pulses the card border.

**lumae Dusk styling:** bundle the project's real tokens inline (self-contained,
no external fetch) — copy `lumae/dist/css/tokens.css` (primitives, spacing,
radii, type scale, fonts) + `lumae/dist/css/dusk.css` (the `[data-theme="dusk"]`
semantic layer) into the page's `<style>`, and set `data-theme="dusk"` on
`<html>`. Map UI to semantic roles:

| UI element | lumae token |
|---|---|
| page background | `--color-bg` |
| card surface | `--color-surface` |
| card border | `--color-border` |
| primary text | `--color-text` |
| params / labels | `--color-subtext` |
| waveform | `--color-info` |
| bell badge | `--color-success` |
| swoosh badge | `--color-primary` |
| playing pulse | `--color-primary-emphasis` |
| error banner | `--color-danger` |

Spacing/radii/fonts use the token scale (`--space-*`, `--radius-card`,
`--font-heading` Zilla Slab, `--font-body` DM Sans). Fonts fall back to the
token stacks' system fonts (no CDN); if the lumae webfonts aren't installed the
fallbacks apply.

## Section 4 — Structure, deps, testing

**Files (`sound-theme/default/src/`):**
- `serve.py` — Flask app (routes, watcher thread, SSE, subprocess render).
- `index.html` — dashboard template (lumae-Dusk, inline CSS/JS), served by `/`.
- `generate.py` — gains `--serve-dir DIR` (render all 28 + write `palette.json`).
- `pyproject.toml` — `flask` in `[dependency-groups] dev`.
- `justfile` — `just serve` recipe.
- Preview dir: `src/.preview/` (already git-ignored) or a fresh temp dir.

**palette.json shape** (per sound): `{ "name", "voice": "bell"|"swoosh",
"level_db", ... }` — bell adds `{"notes": ["C3","E3",...], "accents": {...
non-default ...}}`; swoosh adds `{"swoosh_dir": "up"|"down"}`. Note names are
rendered from MIDI for display.

**Testing** (`test_serve.py`, pytest, skips without flask):
- `generate.py --serve-dir <tmp>` emits 28 WAVs + a `palette.json` whose entries
  have the right shape (name, voice, params, `level_db`).
- Flask **test client**: `GET /` → 200 HTML; `GET /api/palette` → 28 JSON
  entries; `GET /sounds/stop.wav` → audio bytes; `GET /events` →
  `text/event-stream`.
- NOT unit-tested (manual/by-eye): browser JS (Web Audio/canvas), live SSE
  reload, watcher debounce — inherently integration.

**basedpyright:** `serve.py` typed to the same bar as the rest (the project's
`[tool.basedpyright]` config already covers `src/`).

## Open items (resolved during implementation)

- Exact preview-dir choice (`src/.preview/` vs a `tempfile` dir) and how the
  server locates the generator subprocess (`sys.executable` + module path).
- Whether `palette.json` is written by `generate.py --serve-dir` or a small
  separate `--dump-params` step (leaning: same `--serve-dir` pass).
- Port (default e.g. 8765) and whether `just serve` opens the browser.
- Precisely which lumae token files/values to inline (grab from
  `~/git/github.com/cadrianmae/lumae/dist/css/`).
