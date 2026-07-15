#!/usr/bin/env python3
"""Generate a starter REAPER project: one named track + region marker per
audio-feedback sound filename. Mae opens it and adds synths per track.
Dev-time tool. Run: python scaffold_rpp.py > ../sounds/src/audio-feedback.rpp"""

BASE = ["stop", "notification", "session-start", "subagent-stop",
        "pre-compact", "user-prompt-submit", "pre-tool-use", "post-tool-use"]
GROUPS = ["execute", "modify", "network", "observe", "dispatch", "interact"]
NOTIF = ["auth", "elicitation", "idle", "permission"]
SESSION = ["clear", "compact", "resume"]


def sound_names():
    names = list(BASE)
    names += [f"pre-tool-use-{g}" for g in GROUPS]
    names += [f"post-tool-use-{g}" for g in GROUPS]
    names += [f"notification-{s}" for s in NOTIF]
    names += [f"session-start-{s}" for s in SESSION]
    return names


def build_rpp(names):
    lines = ['<REAPER_PROJECT 0.1 "7.0" 0', "  SAMPLERATE 44100 0 0"]
    for i, n in enumerate(names):
        # region marker pair around a 2s slot per sound (MARKER start / end).
        # Both lines of a region MUST share the same integer ID -- that is
        # what makes REAPER read them as one named region rather than two
        # independent point markers.
        region_id = i + 1
        start = i * 2.0
        end = start + 1.5
        guid = "{{00000000-0000-0000-0000-{:012d}}}".format(i)
        lines.append(f'  MARKER {region_id} {start} "{n}" 1 0 1 R {guid}')
        lines.append(f'  MARKER {region_id} {end} "" 1')
    for n in names:
        lines.append("  <TRACK")
        lines.append(f'    NAME "{n}"')
        lines.append("  >")
    lines.append(">")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    import sys
    sys.stdout.write(build_rpp(sound_names()))
