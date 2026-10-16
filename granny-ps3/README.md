# Granny — PS3 Controller (Full Support) 🎮

لعبة **Granny** (DVloper) بدعم كامل ليد **PlayStation 3 (DualShock 3)**:
العصاوت الاتنين (analog sticks) + كامل الأزرار خدامين داخل اللعبة عبر
**touch-mapper مدمج** (`com.ps3mod`): اليد كتحوّل للمسات فالبلايص الصحيحة.

> **الملف الأصلي**: `Granny.apk` من Google Drive (183,565,031 bytes).
> **النسخة المعدّلة** ما محطوطاش فالـ git (كبيرة بزاف: ~183MB > حد 100MB ديال GitHub) —
> حمّلها من صفحة **Releases** (تاغ `granny-ps3-latest`).

## 📦 الملفات

| الملف | الوصف |
|---|---|
| `java/com/ps3mod/PS3Mapper.java` | سورس الـ mapper (Java — يتكومپايلا فالـ CI) |
| `tools/patch_apk.py` | سكريبت الحقن (smali + manifest) |
| `tools/build.sh` | pipeline كامل: decode → inject → build → sign |
| `PS3-CONTROLLER-GUIDE.md` | الدليل الكامل (الفرملة + الأزرار + المشاكل) |

## ⚠️ التثبيت (خطوة ضرورية)

1. **احذف (uninstall) لعبة Granny الأصلية أولاً** — التوقيع مختلف.
2. حمّل الـ APK من **Releases** وثبّته (سمح بمصادر مجهولة).
3. **فرمّل اليد قبل ما تفتح اللعبة.**

## 🎮 مختصر التحكم

- **العصا اليسرى / D-Pad** — الحركة (joystick البيضاء)
- **العصا اليمنى** — التدوير/التخمام (look) المستمر
- **✕ / R1** — اليد: هز / استعمل / حل 🤚
- **○ / R2** — Drop / Use / Place / Shoot / Spray
- **□ / L2** — التخبية والخروج + أزرار الوسط
- **△ / L1 / SELECT** — القرفصاء / الوقوف
- **START** — القائمة (pause)
- **L3+R3** — طفيان/تشغيل الـ mapping

الدليل الكامل: [`PS3-CONTROLLER-GUIDE.md`](./PS3-CONTROLLER-GUIDE.md)

## 🔨 البناء (build)

تلقائي عبر GitHub Actions (workflow `granny-ps3.yml`):
كيحمّل الأصلي من Drive، كيحقن `com.ps3mod`، كيعاود البناء والتوقيع، وكينشر release.

```sh
gh workflow run granny-ps3.yml --ref arena/f166472e-salah
```

## ✅ معلومات النسخة المبنية

- **versionName/versionCode:** unknown / 0 (الـ manifest الأصلي ما فيهش version —
  طبيعي، ماشي مشكل)
- **الملف:** `Granny-unknown-PS3-FULL-CONTROLLER.apk`
- **الحجم:** 186,407,467 bytes
- **md5:** `f0b3baefe52813be4b755eadd0a30522`
- **sha256:** `6d9118f144c7d13990d1404481511c28329d44c65569506dffcb162025193d66`
- **التوقيع:** `CN=PS3Mod` (RSA 2048, v1+v2) — `apksigner verify` ✅
- **التحقق:** `PS3Mapper` موجودة فـ classes.dex ✅ + الـ hooks محقونة فـ
  `UnityPlayerActivity` (dispatchKeyEvent/dispatchGenericMotionEvent) ✅

## ⚠️ Native libraries (مهم!)

الـ `Granny.apk` اللي فـ Drive هو **base APK بلا native libraries** (الـ `.so`
كاينين فـ **config split** بوحدو: `config.arm64_v8a.apk` أو similar).
النسخة الحالية فـ Releases خدامة من ناحية الـ mod، ولكن **ما غاديش تفتح اللعبة**
بلا الـ native libs (Unity/IL2CPP).

**باش نكمّل نسخة واحدة جاهزة للتثبيت (single APK):**

1. من التيليفون اللي فيه Granny منصّبة (Play Store version)، ثبّت تطبيق
   **SAI (Split APKs Installer)**.
2. SAI > Apps > Granny > **Backup** (غادي يساڤي base + splits).
3. صيفط ملفات الـ split اللي سميتها فيها `arm64` (مثال:
   `config.arm64_v8a.apk` — شي ~20-60MB) لـ **Google Drive** (نفس المجلد).
4. علمني — غادي نحوّلهم public، الـ CI غادي يدمج الـ `.so` فالنسخة المعدّلة،
   وغادي تولّي APK وحدة جاهزة: ثبّت ولعب 🎮.

> ⚠️ الـ split **خاصو يكون من نفس version ديال Granny** اللي فالـ base
> (الأحسن: من اللعبة المنصّبة عندك دابا). version مختلفة = crash.

---

> نسخة معدّلة (mod) — اللعبة ملك لـ DVloper؛ هاد المجلد مخصص للاستعمال الشخصي ديال صاحب الحساب.
