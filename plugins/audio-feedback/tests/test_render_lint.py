import os, py_compile

SCRIPT = os.path.join(os.path.dirname(__file__), "..", "scripts", "render-sounds.py")

def test_render_script_compiles():
    py_compile.compile(SCRIPT, doraise=True)

def test_render_targets_default_dir_and_settings():
    src = open(SCRIPT).read()
    assert "sounds/default" in src
    assert "44100" in src
    # renders per-region and normalises
    assert "RegionRenderMatrix" in src or "GetSetProjectInfo_String" in src
