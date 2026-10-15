# Rayman Mini APK — can it run on a 32-bit Android phone?

**Short answer: No. ❌ This APK cannot be installed on your phone.**

Your phone is 32-bit; this APK is a **64-bit (arm64-v8a) only** build. Android will
refuse it with "App not installed / not compatible with this phone"
(`INSTALL_FAILED_NO_MATCHING_ABIS`).

---

## What the file actually is

`Rayman-Mini-v1.4-full-apkvision.apk` — 443 MB (464,535,736 bytes)

- **Not a Ubisoft release.** Package `io.github.raymanminiport`, main activity
  `com.mod.MainActivity` — a fan-made Android port of the Apple Arcade **iOS** game.
  You can see the iOS data straight inside it: `assets/bundle/bundle_ios.ipk` (291 MB),
  `assets/bundle/Sound/WwisePackage/iOS/…`, `assets/bundle/ios_UA_Engine_retail`.
- Signed (v2+v3 signature ✓), so on a **64-bit** phone it would install.
- Minimum Android 8.0 — your Android 11 is fine. The CPU type is the wall, not the OS version.
- Asks for INTERNET + network-state permissions (so it is not really "offline").
- Needs about **2.2 GB free space** on the phone per the download page.

## The proof (from the APK itself, CI report `report.txt`)

```
native-code: 'arm64-v8a'          <- declared in the manifest

lib/arm64-v8a/*  : 6 libraries, 16.4 MB
lib/armeabi-v7a/*: (none)         <- nothing 32-bit inside
lib/x86/*        : (none)
```

A 32-bit Android system only executes 32-bit (armeabi-v7a) code, and this APK ships
**zero** 32-bit libraries. There is no tweak that makes it installable — the code inside
is 64-bit ARM.

## What you CAN play on a 32-bit Android 11 phone

| Game | Size | 32-bit? | Notes |
|------|------|---------|-------|
| ✅ **Rayman Classic** (the original 1995 Rayman) | ~34 MB | **armeabi-v7a ✓** | Fully offline, Android 4.0+, very light on RAM — the best fit for your phone |
| ✅ **Rayman Fiesta Run** | ~7 MB APK + ~200 MB data | **armeabi-v7a ✓** (pick that variant) | Offline runner, ~$0.99 on Google Play; newest v1.4.2 builds are mostly arm64 — choose the armeabi-v7a version |
| ✅ **Rayman Jungle Run** | ~10 MB | **armeabi-v7a ✓** | Offline runner (2012), light, 32-bit era build |
| ⚠️ **Rayman Adventures** | ~40 MB + data | armeabi-v7a ✓ | BUT Ubisoft shut its servers down on 26 June 2023 — only the first 2–3 levels are playable. Not worth it for a full game |
| ❌ Rayman Mini (this file) | 443 MB | **arm64 only** | Cannot install on 32-bit |
| ❌ Rayman Legends (the 5.9 GB `ramadn.rar`) | 5.9 GB | PC only | Windows game — see `ramadan-port/README.md` |

Tip: when a download page shows architectures, take **armeabi-v7a** rather than
arm64-v8a. If there's no armeabi-v7a version, it will not work on this phone.

---

Full machine report: `rayman-port/report.txt`
