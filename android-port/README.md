# Awake or Not? — Android Port (مستيقظ أم لا؟)

Android version of the Windows game found in `windows.zip` on Google Drive
(Godot 4.8.dev3 export: `Awake or not.exe` + `Awake or not.pck`).

## 📱 Download & install

**APK (49 MB):** https://github.com/salahcloud11-cell/Salah/releases/tag/awake-or-not-android-v1

1. Open the link on your Android phone and download `AwakeOrNot.apk`.
2. Tap the downloaded file → allow "Install unknown apps" if asked → **Install**.
3. Open **مستيقظ أم لا؟** and play in landscape.

Requirements: arm64 Android phone. The APK is debug-signed for direct
(sideload) installation — no Play Store needed. If you later rebuild it
yourself, uninstall this one first (different signature = update refused).

## 🎮 Touch controls

| Control | Action |
| --- | --- |
| Left virtual joystick | Move (WASD) |
| Drag on the right side of the screen | Look around (mouse look) |
| **USE / تفاعل** (glows gold) | Interact — bed: sleep, front door: go to work |
| **JUMP / قفز** | Jump (Space) |
| **RUN / ركض** (toggle) | Sprint (Shift) |
| Tap anywhere / **SKIP ≫** | Advance / skip cutscene dialogue |

Menus, sliders and buttons work with normal taps.

## 🔧 How the conversion was done

The Windows `.exe` cannot run on Android, so the game was rebuilt
from its own data with the matching engine version:

1. **Recovery** (`.github/workflows/android-recover.yml`): GDRE Tools 2.7.4
   extracted `Awake or not.pck` and decompiled all 21 GDScript files,
   500/501 resources (report in `recovered_src/recover.log`, recovered
   text sources in `recovered_src/`).
2. **Android patch** (`patch_project.py` + `overlay/`):
   - new `android/touch_controls.gd` autoload (joystick/buttons/skip),
     original game code untouched;
   - renderer switched Forward+ → **Mobile**, textures re-imported as
     **ETC2/ASTC** (the Windows S3TC textures don't work on phone GPUs);
   - two character models that GDRE could only recover as GLB were
     re-pointed from the lost `.fbx` sources to the recovered `.glb`;
   - landscape orientation.
3. **Build** (`.github/workflows/android-build.yml`): official Godot
   **4.8-dev3** editor + export templates (exact version the game was
   made with), Android SDK signing, published to the GitHub Release.
4. **QA** (`.github/workflows/android-qa.yml`, logs in `android-port/qa-logs/`):
   the patched game is run headless and driven automatically —
   menu → Start → skip intro → look → walk 1.4 m → DreamCorridor load —
   final result: **SMOKE PASS, 0 script errors**.

## Rebuild it yourself

Push a change to `android-port/build.trigger` on this branch and the
build workflow regenerates + republishes the APK (it needs `windows.zip`
temporarily link-shared on Google Drive — remember to set it back to
private afterwards).

Known notes: performance depends on your GPU (Mobile renderer + ETC2
keep it as light as possible); one book-stack model lost its roughness
texture reference during recovery (cosmetic only).
