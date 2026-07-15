"""ReaScript: batch-render every project region to sounds/default/<region>.wav
(mono, 44.1 kHz, normalized to -1 dB). Run from REAPER:
  Actions > Show action list > ReaScript: Load > this file > Run
Requires the reapy-free native ReaScript Python API (RPR_* functions).
Invoke headless (optional):
  ~/.local/opt/REAPER/reaper -new -nosplash \\
    -renderproject plugins/audio-feedback/sounds/src/audio-feedback.rpp
(after configuring render settings once in-project).

NOTE (render settings source of truth): mono, 44.1 kHz, normalize -1 dB, and
the per-region render matrix are configured ONCE in REAPER's render dialog
(File > Render...) and saved into the project's .rpp file. This script does
not itself set sample rate/channel-count/normalization -- it only points the
render output at sounds/default and triggers a render using whatever render
settings are currently saved in the project. See Task 8 for the exact dialog
settings to configure.
"""
import os
try:
    from reaper_python import (RPR_GetProjectPath, RPR_EnumProjectMarkers,
                               RPR_GetSetProjectInfo_String, RPR_Main_OnCommand,
                               RPR_ShowConsoleMsg)
except ImportError:  # allows py_compile lint outside REAPER
    RPR_GetProjectPath = RPR_EnumProjectMarkers = None

OUT_SUBDIR = os.path.join("sounds", "default")
SR = 44100


def _regions():
    names, i = [], 0
    while True:
        ok, _, _, isrgn, pos, rgnend, name, idx = RPR_EnumProjectMarkers(i, 0, 0, 0, "", 0)
        if ok == 0:
            break
        if isrgn:
            names.append((name, pos, rgnend))
        i += 1
    return names


def render_all():
    # Configure render: mono, 44.1k, normalize -1 dB, per-region, WAV.
    RPR_GetSetProjectInfo_String(0, "RENDER_FILE", OUT_SUBDIR, True)
    RPR_GetSetProjectInfo_String(0, "RENDER_PATTERN", "$region", True)
    # SRATE / channels / normalize configured in the saved project's render dialog.
    # 42230 = File: Render project, using the most recent render settings.
    RPR_Main_OnCommand(41824, 0)  # render using last settings (all regions matrix)
    RPR_ShowConsoleMsg("[OK] rendered regions to %s\n" % OUT_SUBDIR)


if __name__ == "__main__" and RPR_EnumProjectMarkers is not None:
    render_all()
