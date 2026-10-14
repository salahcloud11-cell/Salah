# "Ramadan" (ramadn.rar) — what it is, and how to play it on Android

## What was inside `ramadn.rar`

```
Rayman Legends/          <- the game folder
  Rayman Legends.exe     (12 MB)
  Bundle_PC.ipk          (5.6 GB - all game data)
  LumaPlay_x86.exe, codex.ini, steam_api.dll ...
_CommonRedist/           (DirectX / Visual C++ installers)
```

So despite the file name, this is **Rayman Legends** (Ubisoft, 2013) — the
**Windows PC version**, a pre-installed cracked Steam release. Extracted size:
**5.9 GB**.

## Why it can't be converted to an APK like "Awake or Not?"

"Awake or Not?" was a **Godot** game: we recovered its project files and
re-exported a true Android build. Rayman Legends runs on Ubisoft's closed,
proprietary **UbiArt Framework**:

- The game is a compiled Windows (DirectX) binary + proprietary `.ipk` data
  bundles. There is **no project/source inside** and no tool that can recover
  or re-export it for Android.
- Ubisoft never released Rayman Legends on Android, so there is no official
  APK to compare with either.

Anyone promising a "Rayman Legends APK" online is offering a fake or malware —
please don't install those.

## How you CAN play it on your phone: Winlator

Winlator runs Windows games inside a container on Android (Wine + Box64
translation). Rayman Legends is a 2D game, which makes it one of the more
realistic candidates. Steps:

1. **Install Winlator** from its official GitHub (search
   "Winlator brunodev85 GitHub" → Releases → install the APK; it's not on the
   Play Store, so allow "Install unknown apps").
2. **Extract `ramadn.rar`** on your phone with ZArchiver (or on a PC) and put
   the `Rayman Legends` folder in your phone's `Download` folder. You need
   roughly **10 GB free** (archive + extracted game) — delete the `.rar`
   afterwards to reclaim 4 GB.
3. In Winlator, create a container. For this game set:
   - Screen size: **960×540** (or 800×600 on a weak phone)
   - Graphics driver: **Turnip** (Adreno/Snapdragon) or **VirGL** (other GPUs)
   - DX Wrapper: **WineD3D** (best for DirectX 9 2D games)
   - Box64 preset: **Performance**
4. Open the container, browse to `D:\Rayman Legends`, run **Rayman Legends.exe**.

**Honest expectations:** on a mid-range phone this runs well. On a
1.5–2 GB RAM phone it will very likely be slow or unstable — Winlator plus a
5.9 GB PC game is much heavier than a native port. Worth a try, but the PC
version on a computer remains the smooth way to play this one.

## Privacy note

The `.rar` was temporarily shared so the inspection tool could download it;
it has been set back to **private**. Nothing from the archive was copied into
this repository (only this report).

Inspection report: `ramadan-port/inspect-report.txt`
