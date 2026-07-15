"""ReaScript: batch-render every project region to sounds/default/<region>.wav
(mono, 44.1 kHz, normalised to -1 dB). Run from REAPER:
  Actions > Show action list > ReaScript: Load > this file > Run
Requires the reapy-free native ReaScript Python API (RPR_* functions).
Invoke headless (optional):
  ~/.local/opt/REAPER/reaper -new -nosplash \\
    -renderproject plugins/audio-feedback/sounds/src/audio-feedback.rpp
(after configuring render settings once in-project).

NOTE (render settings source of truth): mono, 44.1 kHz, normalise -1 dB, and
the per-region render matrix are configured ONCE in REAPER's render dialog
(File > Render...) and saved into the project's .rpp file. This script does
not itself set sample rate/channel-count/normalisation -- it only points the
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
    RPR_GetSetProjectInfo_String = RPR_Main_OnCommand = RPR_ShowConsoleMsg = None

OUT_SUBDIR = os.path.join("sounds", "default")
SR = 44100


def render_all():
    # Configure render: mono, 44.1k, normalise -1 dB, per-region, WAV.
    RPR_GetSetProjectInfo_String(0, "RENDER_FILE", OUT_SUBDIR, True)
    RPR_GetSetProjectInfo_String(0, "RENDER_PATTERN", "$region", True)
    # SRATE / channels / normalise configured in the saved project's render dialog.
    # 41824 = File: Render project, using the most recent render settings (all regions matrix).
    RPR_Main_OnCommand(41824, 0)
    RPR_ShowConsoleMsg("[OK] rendered regions to %s at %d Hz\n" % (OUT_SUBDIR, SR))


if __name__ == "__main__" and RPR_EnumProjectMarkers is not None:
    render_all()
