# Awake or Not? (مستيقظ أم لا؟) — Android Port

An Android port of the Windows Godot game **"Awake or Not?"**, rebuilt from the
shipped Windows export. The original source project was recovered from the
game's PCK with GDRE Tools and re-exported for Android.

**v5 Lite** targets the weakest phones: **Android 11+ with just 1.5 GB RAM**
(32-bit included), while keeping the interface at normal size.

## 📱 Download the APK (v5 Lite)

**Google Drive:** https://drive.google.com/file/d/1JexUgGVE_3HxK18BohjJ1wvCBRGzIolZ/view

| | |
|---|---|
| File | `AwakeOrNot.apk` |
| Size | 73,346,860 bytes (≈ 70 MB) |
| SHA-256 | `7c963fbaec33246fcdc4b2af14ee19ad9e131367bc852469ba0944f5c8d8e526` |
| Version | 5.0.0 (code 5), package `com.awakeornot.game` |

Older builds on GitHub Releases: `awake-or-not-android-v5` (this one),
`-v4`, `-v3`, `-v2`, `-v1`.

## What changed in v5 (1.5 GB RAM class)

- **Textures:** world/model/furniture textures capped at **256 px** (the big
  RAM saver). Menu wallpaper and main room surfaces stay at 512 px so menus
  don't blur.
- **Per-vertex lighting** (much cheaper than per-pixel on weak GPUs),
  anisotropic filtering off, mesh LOD switches earlier (8 px threshold).
- **3D render scale 0.40** by default; auto-drops to **0.25** if the frame
  rate dips. Physics runs at 30 ticks/s, matched to the 30 FPS cap (half the
  CPU work).
- **New Q- / Q+ buttons** (top-right, with a `3D xx%` indicator): lower the
  quality by hand if your phone still struggles, or raise it for a sharper
  picture.
- Text/UI still render at the game's design resolution (1152×648) — normal
  size, never zoomed (the v3 bug, fixed in v4, kept fixed).

QA-verified headlessly before building: vertex shading on, 3D scale 0.40,
anisotropy 1, physics 30/s, zero shadow-casting lights, renderer
`glcompatibility`, full gameplay walk-through, **0 script errors**.

## What changed in v4 (kept in v5)

- Zoom / huge text fixed (design-resolution UI, only 3D buffer scales).
- All light shadows disabled; adaptive quality steps.

## What changed in v3 (kept in v5)

- Compatibility renderer (OpenGL ES 3) instead of Vulkan/Mobile.
- Universal APK: 32-bit `armeabi-v7a` + 64-bit `arm64-v8a`.

## Requirements

- Android 11 or newer (minSdk 30), **1.5 GB RAM is enough**
- OpenGL ES 3.0 capable device (virtually all phones)
- ~150 MB free space. Sideload: allow "Install unknown apps" for your browser.

## 🎮 Controls

### PS3 controller (Bluetooth/USB) — recommended
Left stick move · right stick camera · Cross jump · Square/Triangle interact
· L3/L1 sprint · D-pad menu · Start pause/skip · touch buttons hide
automatically when a pad is connected.

### Touch
Virtual joystick (left) · drag right side = camera · **JUMP / USE / RUN**
(toggle) buttons · tap = confirm · **Q- / Q+** (top-right) adjust 3D quality.

## Performance features

- Adaptive quality: 3D scale 0.40 → 0.25 automatically if FPS drops.
- ETC2 texture compression, 256 px texture cap, shadows off, vertex
  lighting, 30 FPS + 30 physics ticks, no anisotropic filtering.
- Still slow? Tap **Q-** a few times (down to 25%). Smooth? **Q+** sharpens.

## Known limitations

- Debug-signed APK (sideload only, not Play Store).
- At these settings the 3D world looks soft/retro on purpose — that's the
  trade for running on 1.5 GB RAM. The UI/text always stays sharp.
- One roughness texture from `bookStack2.glb` wasn't recoverable (cosmetic).

## How it was built

```
Google Drive windows.zip ──► GitHub Actions
  GDRE Tools recovery ──► patch_project.py (glcompatibility, 1152x648 UI,
  3D-scale 0.40, shadows off, 256px textures, vertex shading, 30Hz
  physics, ETC2 reimport, joypad bindings, TouchControls overlay)
  ──► Godot 4.8-dev3 Android export ──► QA smoke test (headless)
  ──► universal APK ──► GitHub Release + Google Drive
```

Workflows: `.github/workflows/android-{recover,qa,build}.yml` ·
QA logs: `android-port/qa-logs/` · Overlay: `android-port/overlay/`
