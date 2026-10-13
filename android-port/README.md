# Awake or Not? — Android Port (مستيقظ أم لا؟)

Android version of the Windows game found in `windows.zip` on Google Drive
(Godot 4.8.dev3 export: `Awake or not.exe` + `Awake or not.pck`).

## 📱 Download & install

- **Google Drive:** https://drive.google.com/file/d/12qZgfc8WYruOMCOiuNP0zvbFp_jSdp7a/view
  (file: `AwakeOrNot.apk`, **v3 Lite**, 74 MB universal 32-bit+64-bit, in the same Drive as `windows.zip`)
- **GitHub Release (mirror):** https://github.com/salahcloud11-cell/Salah/releases/tag/awake-or-not-android-v3

1. Open a link on your Android phone and download `AwakeOrNot.apk`.
2. Tap the downloaded file → allow "Install unknown apps" if asked → **Install**.
3. Open **مستيقظ أم لا؟** and play in landscape.
   (If v1 is installed, v2 installs over it; if Android refuses, uninstall first.)

Requirements: arm64 Android phone, landscape. The APK is debug-signed for
direct (sideload) installation — no Play Store needed.

## 🎮 Controls

**Touch**
| Control | Action |
| --- | --- |
| Left virtual joystick | Move |
| Drag on the right side of the screen | Look around |
| **USE / تفاعل** (glows gold) | Interact — bed: sleep, front door: go to work |
| **JUMP / قفز** | Jump |
| **RUN / ركض** (toggle) | Sprint |
| Tap anywhere / **SKIP ≫** | Advance / skip cutscene dialogue |

**PS3 controller (DualShock 3, USB-OTG or Bluetooth) — v2**
| PS3 button | Action |
| --- | --- |
| Left stick / D-pad | Move |
| Right stick | Look around |
| ✕ Cross | Jump (in cutscenes: next line) |
| ▢ Square / △ Triangle | Interact |
| L3 or L1 (hold) | Sprint |
| Start / Select | Skip cutscene / back in menus (Escape) |
| D-pad + ✕ | Menu navigation / confirm |

Pair the controller in Android Bluetooth settings (or plug it in with an
OTG cable) before or during the game. When the pad is used, the touch
buttons hide automatically; touch the screen to bring them back.

## ⚡ Low-end support — v3 Lite (Android 11 · 2 GB RAM · 32-bit)

- **32-bit + 64-bit universal APK** (armeabi-v7a + arm64-v8a): installs
  on old 32-bit phones and modern ones with the same file.
- **Compatibility (OpenGL ES) renderer** instead of Vulkan: runs on
  weak/old GPUs that struggle with or lack Vulkan, and uses much less
  RAM. (Trade-off: some glow effects are simplified.)
- **540p base render resolution** (960×540, expand to screen aspect)
  with adaptive resolution on top: render scale steps
  0.85 → 0.7 → 0.6 → 0.5 → 0.4 automatically to hold playable FPS.
- **Textures capped at 1024 px** on import + ETC2 compression
  (big RAM saving), shadow atlas 1024, earlier mesh LOD, 60 FPS cap.
- Target: Android 11 (works on Android 7+), 2 GB RAM devices.

## 🔧 How the conversion was done

The Windows `.exe` cannot run on Android, so the game was rebuilt
from its own data with the matching engine version:

1. **Recovery** (`.github/workflows/android-recover.yml`): GDRE Tools 2.7.4
   extracted `Awake or not.pck` and decompiled all 21 GDScript files,
   500/501 resources (report in `recovered_src/recover.log`, recovered
   text sources in `recovered_src/`).
2. **Android patch** (`patch_project.py` + `overlay/`):
   - `android/touch_controls.gd` autoload (touch UI, gamepad look,
     adaptive resolution); original game code untouched;
   - gamepad (PS3) bindings injected into the input map
     (sticks/D-pad/buttons for every gameplay action);
   - renderer Forward+ → **Mobile**, textures re-imported as **ETC2**;
   - two character models that GDRE could only recover as GLB were
     re-pointed from the lost `.fbx` sources to the recovered `.glb`;
   - low-end settings (render scale, shadow atlas, LOD, FPS cap),
     landscape orientation.
3. **Build** (`.github/workflows/android-build.yml`): official Godot
   **4.8-dev3** editor + export templates (the exact version the game
   was made with), signed, published to the GitHub Release and
   committed to `android-port/dist/` for the Drive upload.
4. **QA** (`.github/workflows/android-qa.yml`, logs in `android-port/qa-logs/`):
   the patched game runs headless and is driven automatically —
   menu → Start → skip intro → look → walk → **gamepad bindings,
   right-stick camera, left-stick movement** → DreamCorridor load —
   v2 result: **SMOKE PASS, 0 script errors**.

## Rebuild it yourself

Push a change to `android-port/build.trigger` on this branch and the
build workflow regenerates + republishes the APK (it needs `windows.zip`
temporarily link-shared on Google Drive — set it back to private
afterwards). Then upload `android-port/dist/AwakeOrNot.apk` to Drive.

SHA-256 (v3): see `android-port/dist/sha256.txt`.

Known notes: performance still depends on your GPU (the adaptive
scaler is the main defense on weak phones); one book-stack model lost
its roughness texture reference during recovery (cosmetic only).
