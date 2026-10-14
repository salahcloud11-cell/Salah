#!/usr/bin/env python3
"""Patch a GDRE-recovered Godot project for Android export.

Usage: python3 patch_project.py <recovered_project_dir> <overlay_dir>

- Restores GDRE '.assets' conversions to their real paths (FBX->GLB chars).
- Redirects character scenes from the lost .fbx sources to the recovered .glb.
- Drops recovery leftovers (.assets/.autoconverted/.godot caches).
- Edits project.godot: TouchControls autoload, Mobile renderer,
  ETC2/ASTC texture imports, landscape orientation.
- Copies overlay files (touch_controls.gd, export_presets.cfg) into place.
"""
import os
import re
import shutil
import sys

proj = os.path.abspath(sys.argv[1])
overlay = os.path.abspath(sys.argv[2])


def log(*a):
    print("[patch]", *a, flush=True)


# 1) restore .assets conversions (only where the real file is missing)
assets_root = os.path.join(proj, ".assets")
if os.path.isdir(assets_root):
    for root, _dirs, files in os.walk(assets_root):
        for fn in files:
            src = os.path.join(root, fn)
            rel = os.path.relpath(src, assets_root)
            dest = os.path.join(proj, rel)
            if not os.path.exists(dest):
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                shutil.copy2(src, dest)
                log("restored from .assets:", rel)

# 2) character scenes: .fbx -> recovered .glb
for tscn_name, old, new in [
    ("character_male.tscn", "Character_01.fbx", "Character_01.glb"),
    ("character_female.tscn", "Character_Female_02.fbx", "Character_Female_02.glb"),
]:
    tscn = os.path.join(proj, "apartment/assets/characters", tscn_name)
    if os.path.exists(tscn):
        txt = open(tscn, encoding="utf-8").read()
        lines = txt.splitlines()
        for i, line in enumerate(lines):
            if old in line and "ext_resource" in line:
                line = line.replace(old, new)
                line = re.sub(r'\s*uid="[^"]*"', "", line, count=1)
                lines[i] = line
                log("patched", tscn_name, "->", new)
        open(tscn, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    # stale .import for the missing .fbx source would make the editor fail
    stale = os.path.join(proj, "apartment/assets/characters", old + ".import")
    fbx = os.path.join(proj, "apartment/assets/characters", old)
    if os.path.exists(stale) and not os.path.exists(fbx):
        os.remove(stale)
        log("removed stale import:", stale)

# 3) recovery leftovers / stale caches
for d in [".assets", ".autoconverted", ".godot"]:
    p = os.path.join(proj, d)
    if os.path.isdir(p):
        shutil.rmtree(p)
        log("removed", d)

# 3b) disable shadow casting on all lights (big GPU saver on low-end;
# shadow maps re-render the scene per light)
shadow_off = 0
for root, _dirs, files in os.walk(proj):
    for fn in files:
        if not fn.endswith(".tscn"):
            continue
        p = os.path.join(root, fn)
        try:
            txt = open(p, encoding="utf-8").read()
        except Exception:
            continue
        n = txt.count("shadow_enabled = true")
        if n:
            open(p, "w", encoding="utf-8").write(
                txt.replace("shadow_enabled = true", "shadow_enabled = false"))
            shadow_off += n
log("shadows disabled on", shadow_off, "lights")

# 3c) cap texture size on import (RAM saver for 1.5 GB devices):
# world/model/furniture textures at 256px (they dominate texture memory);
# the shared room-surface set under assets/Textures (incl. the main-menu
# wallpaper) stays at 512px so menus and main walls don't turn blurry.
KEEP_512_DIR = "apartment/assets/Textures"  # direct files only, not subfolders
capped = 0
capped_big = 0
for root, _dirs, files in os.walk(proj):
    if ".godot" in root.split(os.sep):
        continue
    for fn in files:
        if not fn.endswith(".import"):
            continue
        p = os.path.join(root, fn)
        try:
            txt = open(p, encoding="utf-8").read()
        except Exception:
            continue
        if 'importer="texture"' in txt and "process/size_limit=" in txt:
            rel = os.path.relpath(p, proj).replace(os.sep, "/")
            limit = 512 if os.path.dirname(rel) == KEEP_512_DIR else 256
            txt2 = re.sub(r"process/size_limit=\d+",
                          "process/size_limit=%d" % limit, txt)
            if txt2 != txt:
                open(p, "w", encoding="utf-8").write(txt2)
                capped += 1
                if limit == 512:
                    capped_big += 1
log("texture size_limit applied (256 world / 512 kept on %d) to %d imports"
    % (capped_big, capped))

# 4) overlay files
for root, _dirs, files in os.walk(overlay):
    for fn in files:
        src = os.path.join(root, fn)
        rel = os.path.relpath(src, overlay)
        dest = os.path.join(proj, rel)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copy2(src, dest)
        log("overlay:", rel)

# 5) project.godot edits
pg_path = os.path.join(proj, "project.godot")
pg = open(pg_path, encoding="utf-8").read()


def set_key(text, section, key, value):
    """Set key=value inside [section]; append to section if absent."""
    sec_re = re.compile(r"^\[" + re.escape(section) + r"\]\s*$", re.M)
    m = sec_re.search(text)
    if not m:
        return text.rstrip() + f"\n\n[{section}]\n\n{key}={value}\n"
    start = m.end()
    nxt = re.compile(r"^\[", re.M).search(text, start)
    end = nxt.start() if nxt else len(text)
    body = text[start:end]
    key_re = re.compile(r"^" + re.escape(key) + r"=.*$", re.M)
    if key_re.search(body):
        body = key_re.sub(lambda _: f"{key}={value}", body, count=1)
    else:
        body = body.rstrip() + f"\n{key}={value}\n"
    return text[:start] + body + text[end:]


pg = set_key(pg, "autoload", "TouchControls", '"*res://android/touch_controls.gd"')
pg = set_key(pg, "application", "config/features", 'PackedStringArray("4.8", "GL Compatibility")')
pg = set_key(pg, "application", "run/max_fps", "30")
pg = set_key(pg, "display", "window/handheld/orientation", '"landscape"')
pg = set_key(pg, "rendering", "renderer/rendering_method", '"glcompatibility"')
pg = set_key(pg, "rendering", "renderer/rendering_method.mobile", '"glcompatibility"')
pg = set_key(pg, "rendering", "textures/vram_compression/import_etc2_astc", "true")
# --- low-end device support ---
pg = set_key(pg, "display", "window/size/viewport_width", "1152")
pg = set_key(pg, "display", "window/size/viewport_height", "648")
pg = set_key(pg, "display", "window/stretch/aspect", '"expand"')
pg = set_key(pg, "rendering", "scaling_3d/scale", "0.4")
pg = set_key(pg, "rendering", "textures/default_filters/anisotropic_filtering_level", "1")
pg = set_key(pg, "rendering", "lights_and_shadows/positional_shadow/atlas_size", "512")
pg = set_key(pg, "rendering", "mesh_lod/lod_change/threshold_pixels", "8.0")
# --- lowest-end devices (1.5 GB RAM class) ---
# per-vertex lighting: far cheaper than per-pixel on weak mobile GPUs
pg = set_key(pg, "rendering", "shading/overrides/force_vertex_shading", "true")
# physics at the same rate as the 30 FPS render cap (half the CPU work)
pg = set_key(pg, "physics", "common/physics_ticks_per_second", "30")

# --- PS3 / generic gamepad bindings -------------------------------------
# Godot joypad indices: A/Cross=0, B/Circle=1, X/Square=2, Y/Triangle=3,
# Back=4, Start=6, L3=7, R3=8, L1=9, R1=10, DPad U/D/L/R=11/12/13/14.
# Axes: LeftX=0, LeftY=1, RightX=2, RightY=3.


def _joy_button(idx: int) -> str:
    return (
        'Object(InputEventJoypadButton,"resource_local_to_scene":false,'
        '"resource_name":"","device":-1,"button_index":%d,'
        '"pressure":0.0,"pressed":false,"script":null)' % idx
    )


def _joy_motion(axis: int, value: float) -> str:
    return (
        'Object(InputEventJoypadMotion,"resource_local_to_scene":false,'
        '"resource_name":"","device":-1,"axis":%d,'
        '"axis_value":%s,"script":null)' % (axis, ("%.1f" % value))
    )


JOY_BINDINGS = {
    "up": [_joy_motion(1, -1.0), _joy_button(11)],
    "down": [_joy_motion(1, 1.0), _joy_button(12)],
    "left": [_joy_motion(0, -1.0), _joy_button(13)],
    "right": [_joy_motion(0, 1.0), _joy_button(14)],
    "jump": [_joy_button(0)],            # Cross
    "sprint": [_joy_button(7), _joy_button(9)],  # L3 or L1
    "interact": [_joy_button(2), _joy_button(3)],  # Square or Triangle
}
MOVE_ACTIONS = {"up", "down", "left", "right"}

for action, extra in JOY_BINDINGS.items():
    pat = re.compile(
        r"(^" + action + r"=\{\n\"deadzone\": )([0-9.]+)(,\n\"events\": \[)(.*?)(\n\]\n\})",
        re.M | re.S,
    )
    m = pat.search(pg)
    if not m:
        log("WARNING: input action not found:", action)
        continue
    deadzone = "0.2" if action in MOVE_ACTIONS else m.group(2)
    events = m.group(4)
    if "InputEventJoypad" not in events:
        events = events + ",\n" + ",\n".join(extra)
    pg = pg[: m.start()] + m.group(1) + deadzone + m.group(3) + events + m.group(5) + pg[m.end():]
    log("gamepad bindings added:", action)
open(pg_path, "w", encoding="utf-8").write(pg)
log("project.godot patched")
print("----- project.godot -----")
print(pg)
print("-------------------------")
