# Awake or Not? (مستيقظ أم لا؟) — Android Port

An Android port of the Windows Godot game **"Awake or Not?"**, rebuilt from the
shipped Windows export. The original source project was recovered from the
game's PCK with GDRE Tools and re-exported for Android.

**v4 Lite** fixes the v3 zoomed picture / huge text and pushes the graphics
requirements even lower for weak phones (Android 11+, 2 GB RAM, 32-bit).

## 📱 Download the APK (v4 Lite)

**Google Drive:** https://drive.google.com/file/d/1pcDYp0wvcdl2PfQs9uM56XVerR6C3MVX/view

| | |
|---|---|
| File | `AwakeOrNot.apk` |
| Size | 74,579,756 bytes (≈ 71 MB) |
| SHA-256 | `4c9ffe16277d6560fdce8177c8383acfc70491b4fc2401945bb6dde1f36ac12a` |
| Version | 4.0.0 (code 4), package `com.awakeornot.game` |

Also on GitHub Releases: `awake-or-not-android-v4`, `awake-or-not-android-v3`
(`awake-or-not-android-v2`, `-v1` are the older heavier builds).

## What changed in v4 (zoom/text fix + more low-end)

- **Zoom / huge text FIXED** — the interface now renders at the game's design
  resolution (1152×648), so menus and text are their normal size. Only the 3D
  world renders at lower internal resolution (55% by default, auto-drops to
  33% on slow devices) — slightly softer 3D, never zoomed.
- **All light shadows disabled** (biggest single GPU cost in the apartment
  scene).
- **Textures capped at 512 px** (was 1024) — less memory on 2 GB RAM phones.
- **30 FPS cap**, anisotropy 2, mesh LOD threshold 4.0.

QA-verified headlessly before building: UI base resolution 1152×648, zero
shadow-casting lights, `glcompatibility` renderer, 0 script errors.

## What changed in v3 (Lite)

- **Compatibility renderer (OpenGL ES 3)** instead of Vulkan/Mobile.
- **Universal APK**: 32-bit `armeabi-v7a` + 64-bit `arm64-v8a`.

## Requirements

- Android 11 or newer (minSdk 30), ~2 GB RAM is fine
- OpenGL ES 3.0 capable device (virtually all phones)
- ~150 MB free space. Sideload: allow "Install unknown apps" for your browser.

## 🎮 Controls

### PS3 controller (Bluetooth/USB) — recommended
Left stick move · right stick camera · Cross jump · Square/Triangle interact
· L3/L1 sprint · D-pad menu · Start pause/skip · sticks click = on-screen
buttons hide automatically when a pad is connected.

### Touch
Virtual joystick (left) · drag right side = camera · **JUMP / USE / RUN**
(toggle) buttons · tap = confirm · pause button (top-right) · **Q−/Q+**
buttons manually lower/raise the 3D quality if it's still slow (or already
smooth).

## Performance features

- Adaptive quality: 3D scale 0.55 → 0.33 automatically if FPS drops.
- ETC2 texture compression, 512 px texture cap, shadows off, 30 FPS cap.
- If it still lags: tap **Q−** a few times. For best results use the PS3 pad.

## Known limitations

- Debug-signed APK (sideload only, not Play Store).
- One roughness texture from `bookStack2.glb` wasn't recoverable (cosmetic).
- On very weak GPUs the 3D view is softer (that's the trade for smoothness);
  the UI/text always stays sharp at full size.

## How it was built

```
Google Drive windows.zip ──► GitHub Actions
  GDRE Tools recovery ──► patch_project.py (glcompatibility, 1152x648,
  3D-scale 0.55, shadows off, 512px textures, ETC2 reimport, joypad
  bindings, TouchControls overlay) ──► Godot 4.8-dev3 Android export
  ──► QA smoke test (headless, incl. resolution + shadow checks)
  ──► universal APK ──► GitHub Release + Google Drive
```

Workflows: `.github/workflows/android-{recover,qa,build}.yml` ·
QA logs: `android-port/qa-logs/` · Overlay: `android-port/overlay/`
