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
pg = set_key(pg, "application", "config/features", 'PackedStringArray("4.8", "Mobile")')
pg = set_key(pg, "display", "window/handheld/orientation", '"landscape"')
pg = set_key(pg, "rendering", "renderer/rendering_method", '"mobile"')
pg = set_key(pg, "rendering", "renderer/rendering_method.mobile", '"mobile"')
pg = set_key(pg, "rendering", "textures/vram_compression/import_etc2_astc", "true")
open(pg_path, "w", encoding="utf-8").write(pg)
log("project.godot patched")
print("----- project.godot -----")
print(pg)
print("-------------------------")
