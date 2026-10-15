# Fish Me → Android APK

## The APK to install on the phone

**`fish-me-LOWRAM-32bit-Android11-SIGNED.apk`** — 816 KB (835,663 bytes)

- **Google Drive:** https://drive.google.com/file/d/1C6zES_ZsuGQaX9nYDWqiDLATm3VEb-hj/view
- **GitHub backup:** https://github.com/salahcloud11-cell/Salah/releases/tag/fish-me-android-v1
- SHA256: `05b628592097ed2439a36c62216069eb8094451d7828db0167909621e0f983ea` (same file in `dist/`)

Built by CI from the **Fish Me Android project** that was already on Google Drive:
release build (R8-minified), signed with a generated key, verified with `apksigner`
(v1 + v2 + v3 signature schemes) so it installs directly on a normal phone.

### Install
1. Open the Drive (or GitHub) link on the phone.
2. Tap the `.apk` file → if asked, allow **Install unknown apps** for the browser/Files app.
3. Tap **Install**, then open **Fish Me - Low RAM**.
4. If an older "Fish Me" is already installed, uninstall it first (different signing key).

### What the app is
- Package `com.fishme.game`, landscape, label "Fish Me - Low RAM"
- Works from Android 5.0 (min API 21), targets Android 11 (API 30) — made for the low-RAM phone
- No internet permission, only `VIBRATE`; `largeHeap=false`; ~1 MB installed footprint
- Gameplay: tap to cast the line → wait for the bite (2–5 s) → tap quickly when
  "TAP NOW! HOOK IT!" appears → the fish is reeled in; score by fish size.

## What was on Google Drive

| File | What it is |
|------|------------|
| `fich-me.zip` (841 MB) | The original PC game inside: **"How to Fish"** (Dazed Games, Steam, 2026) — Unity engine, first-person, multiplayer. Windows-only, listed minimum 8 GB RAM. |
| `Fish-Me-Android-Project-All-Files.zip` | The lightweight "Fish Me" Android project for phones |
| `fish-me-LOWRAM-32bit-Android11.apk`, `fish-me-3D-POTATO-*.apk` | Earlier APK builds of that Android project |

## Can the PC game ("How to Fish") be turned into an APK? No

- It is a **Unity Windows build** (`How to Fish.exe` + `How to Fish_Data`).
  Re-exporting it for Android needs the original Unity project + the Unity editor with
  an Android licence — a compiled Windows build contains none of that.
- The game's own store/wiki listings show **Windows only**; no official Android or iOS version exists.
- With a listed minimum of 8 GB RAM it would not run on a 1.5 GB phone anyway
  (not even through Winlator-style emulation).

So the playable option for the phone is the signed APK above (the Fish Me Android game
built from the project on the Drive).

## CI verification files
- `dist/` — the signed APK + its SHA256
- `build-report.txt` — aapt/apksigner verification output of this build + the older APKs
- `emulator-test.txt` — Android 11 emulator install/launch test
- `original-report.txt` — what the original `fich-me.zip` contains
- Workflow: `.github/workflows/fishme-build.yml`
