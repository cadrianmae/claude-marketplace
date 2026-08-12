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
    r = subprocess.run([sys.executable, GEN, "--serve-dir", preview_dir],
                       capture_output=True, text=True)
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
        path = os.path.join(preview_dir, "palette.json")
        if not os.path.exists(path):
            return flask.make_response(flask.jsonify([]), 503)
        with open(path) as f:
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
    if not err:
        _state["version"] = 1
    threading.Thread(target=_watch, args=(preview_dir,), daemon=True).start()
    print("audio-feedback preview: http://127.0.0.1:8765")
    create_app(preview_dir).run(host="127.0.0.1", port=8765, threaded=True)


if __name__ == "__main__":
    main()
