# Father of Olampya — what it actually is, and how to play it on Android

## What was inside `father of olampya.7z`

The archive contains exactly one file:

```
God of War - Chains of Olympus (USA).iso   (1.6 GB)
```

So this is **not a PC game** — it's a **PSP game disc image** (Sony PSP,
"God of War: Chains of Olympus"). The name is a phonetic spelling of
"Olympus": *God of War — Chains of Olympus*.

## Why it can't be converted to an APK like "Awake or Not?"

The previous game was made with the **Godot engine**, so we could recover
its project and re-export a real Android build. A PSP `.iso` is completely
different: it's compiled machine code for the PSP's MIPS processor. There is
no project/source inside to rebuild — no tool can turn it into a native APK.

The good news: you don't need one. PSP games run on Android with the free
**PPSSPP** emulator, which is how everyone plays PSP ISOs on phones.

## How to play it (5 minutes)

1. **Install PPSSPP** (free):
   - Play Store: search **"PPSSPP - PSP emulator"** (by Henrik Rydgård), or
   - Official site: https://www.ppsspp.org → Downloads → Android APK.
2. **Extract the ISO from the .7z**:
   - On your phone: install **ZArchiver** (free, Play Store), open
     `father of olampya.7z` and extract `God of War - Chains of Olympus (USA).iso`
     into a folder, e.g. `PSP/GAME` on your storage.
     ⚠️ You need ~2.7 GB free space (1 GB archive + 1.6 GB ISO). Extracting on
     a PC with 7-Zip and copying the ISO over USB also works.
3. **Open PPSSPP → Games → browse to the folder** → tap the game icon. Play!

## Settings for a weak phone (1.5–2 GB RAM)

God of War is one of the heavier PSP games. In PPSSPP → Settings:

**Graphics**
- Backend: **Vulkan** (if your phone offers it, else OpenGL)
- Rendering resolution: **1×PSP** (raise to 2× only if it stays smooth)
- Frame skipping: **1** (try 2 if still slow), **Auto frameskip: ON**
- **Disable slower effects: ON** (biggest single speedup for this game)
- Texture scaling: **Off**
- Spline/Bezier curves quality: **Low**
- Lazy texture caching: **ON** · Retain changed textures: **OFF**
- Hardware transform + Vertex cache: **ON**

**System**
- Fast memory: **ON**
- Multithreaded: **ON** (helps on quad-core phones)
- Change emulated PSP CPU clock: try **111** or **166 MHz** if it's still slow
  (the game runs much lighter; set back to Auto if anything misbehaves)

With these, Chains of Olympus is playable on low-end phones — not perfect,
but smooth enough to enjoy. Save with the in-game save points **and**
PPSSPP savestates (pause menu) so you never lose progress.

## Privacy note

The `.7z` was temporarily shared so the inspection tool could download it;
it has been set back to **private**. Nothing from the archive was copied
into this repository (only this report).

Inspection report: `olympia-port/inspect-report.txt`
