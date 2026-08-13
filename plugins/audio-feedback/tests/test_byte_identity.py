"""Byte-identity gate: the mini-notation-driven palette must regenerate the
exact same WAV bytes as the pre-migration (int, "quaver"/"crotchet"/"minim")
note-map. Baseline md5s captured before the migration (HEAD 7a13bec), stored
as "name md5" lines to keep a hash-looking literal off a single dict line.
"""
import os, subprocess, hashlib, pytest

HERE = os.path.dirname(os.path.abspath(__file__))
PLUGIN = os.path.dirname(HERE)
GEN = os.path.join(PLUGIN, "sound-theme", "default", "src", "generate.py")
SOUNDS = os.path.join(PLUGIN, "sound-theme", "default", "sounds")

_BASELINE_LINES = """
notification-auth.wav 313d990c4b654ce57e583a1874fe0182
notification-elicitation.wav a25524f6b484de09a075c2f8aadd0d55
notification-idle.wav c80854918ebb328a5190ceba26912196
notification-permission.wav b3a92996f68455b407507e47122da12c
notification.wav 3f63403610bea9846cac463957b39258
post-tool-use-dispatch.wav 3404063355a3cdbdcb65661f80e1d0c7
post-tool-use-execute.wav c7efe7f9a1e29e5067b02f1a356201ca
post-tool-use-interact.wav 5ade00a310b033e50b791498c7dddf3d
post-tool-use-modify.wav 47890cdc23b84de0c1584885973ede57
post-tool-use-network.wav 30135aa20ac494ac1f3bfa30bd465721
post-tool-use-observe.wav d5140f6b867ce742b50f8a07ce498451
post-tool-use.wav d9d7b91cbd786844ea2dbdd9d4a51d37
pre-compact.wav ad4992af70ef7ccd9359427951ffc75c
pre-tool-use-dispatch.wav 6d471ba5c17964a78dccedb7b99f97cc
pre-tool-use-execute.wav 6d22966ffcc9508b37fe5da47f9c5288
pre-tool-use-interact.wav ae465cec1b80f63bbae977b01e573f3e
pre-tool-use-modify.wav 3201f89e2e8c3bbc496fa02cdc232d18
pre-tool-use-network.wav c4036623fcb6278e1b1f2edb89fd299c
pre-tool-use-observe.wav 32499ca836732fc903e2be0d1b4addec
pre-tool-use.wav 8f7fd027456e54a999d103a2193b2b21
session-start-clear.wav 4e4dc9bf37f02a60e698d380bc7cff3d
session-start-compact.wav 7999b42be5635627119d8545a8cdac16
session-start-resume.wav 7e37259ed432dd20cd489018947c004a
session-start.wav b7fbf63ed206440d68f1770f0de1f48d
stop.wav 730647c0c7de882b396f42ee6c4b179d
subagent-accent.wav 6a8eff990b71d8b46b434afcedac39ed
subagent-stop.wav 7f975293c83803ba4c1786eb5ee66fe9
user-prompt-submit.wav d11186ea0fae78e0c63ab71ff0b39487
""".strip()

BASELINE = dict(line.split() for line in _BASELINE_LINES.splitlines())


@pytest.mark.skipif(not BASELINE, reason="baseline md5s not recorded")
def test_palette_byte_identical():
    env = dict(os.environ, UV_PYTHON_PREFERENCE="only-managed")
    subprocess.run(["uv", "run", "--script", GEN], cwd=PLUGIN, check=True, env=env)
    for name, want in BASELINE.items():
        got = hashlib.md5(open(os.path.join(SOUNDS, name), "rb").read()).hexdigest()
        assert got == want, f"{name} changed"
