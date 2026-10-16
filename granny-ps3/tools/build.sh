#!/usr/bin/env bash
# Build the Granny PS3-controller-modded APK.
#
# Usage:
#   build.sh <original.apk> <output.apk> [workdir]
#
# Required env (or default guesses):
#   APKTOOL_JAR   path to apktool.jar
#   ANDROID_HOME  Android SDK root (platforms/android-NN + build-tools/NN)
#
# Optional env:
#   BT            build-tools dir (default: 34.0.0 or newest with d8)
#   PLATFORM      android platform (default: android-34 or newest)
#   KEYSTORE_PASS password for the throwaway signing key (default: ps3modps3mod)
#   SPLITS_DIR    dir with config split APKs (native libs merged into one APK)
#
# Pipeline:
#   1. apktool decode (+ optional native-lib merge from SPLITS_DIR)
#   2. javac com.ps3mod -> classes dir
#   3. patch_apk.py: activity hooks + manifest tweaks (+ analysis.txt)
#   4. apktool build -> unsigned.apk
#   5. d8: merge built classes.dex + mapper classes -> merged classes.dex,
#      replace it inside the APK, verify PS3Mapper is present
#   6. zipalign -> apksigner sign -> verify
set -euo pipefail

ORIG_APK="${1:?usage: build.sh <original.apk> <output.apk> [workdir]}"
OUTPUT_APK="${2:?usage: build.sh <original.apk> <output.apk> [workdir]}"
WORK="${3:-$(pwd)/granny-ps3-work}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_JAVA="$SCRIPT_DIR/../java"

APKTOOL_JAR="${APKTOOL_JAR:-$WORK/tools/apktool.jar}"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
BT="${BT:-$ANDROID_HOME/build-tools/34.0.0}"
if [ ! -x "$BT/d8" ]; then
  # Fall back to the newest build-tools that ships d8.
  for cand in $(ls -d "$ANDROID_HOME"/build-tools/* 2>/dev/null | sort -Vr); do
    if [ -x "$cand/d8" ]; then BT="$cand"; break; fi
  done
fi
PLATFORM="${PLATFORM:-android-34}"
ANDROID_JAR="$ANDROID_HOME/platforms/$PLATFORM/android.jar"
if [ ! -f "$ANDROID_JAR" ]; then
  for cand in $(ls -d "$ANDROID_HOME"/platforms/android-* 2>/dev/null | sort -Vr); do
    if [ -f "$cand/android.jar" ]; then ANDROID_JAR="$cand/android.jar"; break; fi
  done
fi
KEYSTORE_PASS="${KEYSTORE_PASS:-ps3modps3mod}"

echo "=== Granny PS3-mod build ==="
echo "orig:        $ORIG_APK"
echo "output:      $OUTPUT_APK"
echo "work:        $WORK"
echo "apktool:     $APKTOOL_JAR"
echo "build-tools: $BT"
echo "android.jar: $ANDROID_JAR"

command -v java >/dev/null || { echo "ERROR: java not found"; exit 1; }
command -v javac >/dev/null || { echo "ERROR: javac not found"; exit 1; }
[ -f "$APKTOOL_JAR" ] || { echo "ERROR: apktool jar missing: $APKTOOL_JAR"; exit 1; }
[ -f "$ANDROID_JAR" ] || { echo "ERROR: android.jar missing: $ANDROID_JAR"; exit 1; }
[ -x "$BT/d8" ] || { echo "ERROR: d8 missing: $BT/d8"; exit 1; }
[ -f "$ORIG_APK" ] || { echo "ERROR: input APK missing: $ORIG_APK"; exit 1; }

mkdir -p "$WORK"
DECODED="$WORK/decoded"
CLASSES="$WORK/mapper-classes"
MERGED="$WORK/merged"

echo "--- [1/7] apktool decode ---"
rm -rf "$DECODED"
java -jar "$APKTOOL_JAR" d -f -o "$DECODED" "$ORIG_APK" 2>&1 | tail -n 5
echo "decoded OK"
echo "--- manifest head ---"
head -c 1500 "$DECODED/AndroidManifest.xml"; echo
echo "--- orig apk layout ---"
python3 - "$ORIG_APK" <<'EOF'
import sys, zipfile, collections
z = zipfile.ZipFile(sys.argv[1])
tops = collections.Counter()
lib = []
big = []
for i in z.infolist():
    tops[i.filename.split("/")[0] if "/" in i.filename else "(root)"] += 1
    if i.filename.startswith("lib/") and i.filename.endswith(".so"):
        lib.append((i.filename, i.file_size))
    big.append((i.file_size, i.filename))
print("top-level:", dict(tops))
print("lib/*.so:", lib if lib else "(none)")
so_any = [n for n in z.namelist() if n.endswith(".so")]
print(".so anywhere:", so_any if so_any else "(none)")
for probe in ("assets/bin/Data/app.info", "assets/bin/Data/boot.config"):
    if probe in z.namelist():
        print(probe, "->", z.read(probe)[:300])
big.sort(reverse=True)
print("largest files:")
for s, n in big[:12]:
    print("  %10d %s" % (s, n))
EOF

if [ -n "${SPLITS_DIR:-}" ] && ls "${SPLITS_DIR}"/*.apk >/dev/null 2>&1; then
  echo "--- [1b/7] merge native libs from config splits ---"
  python3 - "$DECODED" "${SPLITS_DIR}" <<'EOF'
import sys, os, glob, zipfile
decoded, splits = sys.argv[1], sys.argv[2]
total = 0
for apk in sorted(glob.glob(os.path.join(splits, "*.apk"))):
    z = zipfile.ZipFile(apk)
    libs = [n for n in z.namelist() if n.startswith("lib/") and n.endswith(".so")]
    other = sorted({n.split("/")[0] for n in z.namelist() if "/" in n} - {"lib"})
    print("%s: lib/*.so=%d (other top-level dirs skipped: %s)"
          % (os.path.basename(apk), len(libs), other))
    for name in libs:
        dest = os.path.join(decoded, name)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "wb") as fh:
            fh.write(z.read(name))
        total += 1
        print("  + %s" % name)
print("merged %d native libs" % total)
if total == 0:
    print("WARNING: splits provided but no lib/*.so found inside")
EOF
else
  echo "--- [1b/7] no config splits (base APK only) ---"
fi

echo "--- [2/7] compile com.ps3mod (javac) ---"
rm -rf "$CLASSES"
mkdir -p "$CLASSES"
find "$REPO_JAVA" -name '*.java' | sort
# shellcheck disable=SC2046
javac -source 8 -target 8 -nowarn -cp "$ANDROID_JAR" -d "$CLASSES" \
  $(find "$REPO_JAVA" -name '*.java' | sort) 2>&1 | grep -v "bootstrap\|deprecat" || true
find "$CLASSES" -name '*.class'
echo "javac OK"

echo "--- [3/7] patch_apk.py inject (hooks + manifest) ---"
python3 "$SCRIPT_DIR/patch_apk.py" "$DECODED"
cp "$DECODED/analysis.txt" "$WORK/analysis.txt"
cat "$WORK/analysis.txt"
MINSDK="$(grep -E '^minSdk=' "$WORK/analysis.txt" | cut -d= -f2 | tr -cd '0-9' || true)"
[ -z "$MINSDK" ] && MINSDK=21
# apktool/smali rebuilds dex as v037 (needs API 24+); keep d8 consistent.
if [ "$MINSDK" -lt 24 ]; then
  echo "note: raising d8 min-api $MINSDK -> 24 (dex v037 requirement)"
  MINSDK=24
fi
echo "d8 min-api: $MINSDK"

echo "--- [4/7] apktool build ---"
UNSIGNED="$WORK/unsigned.apk"
rm -f "$UNSIGNED"
java -jar "$APKTOOL_JAR" b -o "$UNSIGNED" "$DECODED" 2>&1 | tail -n 5
ls -la "$UNSIGNED"

echo "--- [5/7] d8 merge (classes.dex + mapper) ---"
rm -rf "$MERGED"
mkdir -p "$MERGED/out"
python3 - "$UNSIGNED" "$MERGED/classes.dex" <<'EOF'
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
data = z.read("classes.dex")
open(sys.argv[2], "wb").write(data)
print("built classes.dex bytes:", len(data))
print("dex entries:", [n for n in z.namelist() if n.endswith(".dex")])
EOF
# NOTE: pass .class files explicitly (newer d8 rejects directory inputs).
# shellcheck disable=SC2046
"$BT/d8" --min-api "$MINSDK" --lib "$ANDROID_JAR" \
  --output "$MERGED/out" "$MERGED/classes.dex" \
  $(find "$CLASSES" -name '*.class' | sort)
ls -la "$MERGED/out"
if ! strings "$MERGED/out/classes.dex" | grep -q "Lcom/ps3mod/PS3Mapper;"; then
  echo "ERROR: PS3Mapper missing from merged classes.dex"
  exit 1
fi
echo "merged dex contains PS3Mapper OK"

echo "--- [6/7] replace classes.dex inside APK ---"
MERGED_APK="$WORK/merged.apk"
rm -f "$MERGED_APK"
python3 - "$UNSIGNED" "$MERGED/out/classes.dex" "$MERGED_APK" <<'EOF'
import sys, zipfile
src, newdex, dst = sys.argv[1], sys.argv[2], sys.argv[3]
zin = zipfile.ZipFile(src, "r")
dex = open(newdex, "rb").read()
with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zout:
    for item in zin.infolist():
        data = dex if item.filename == "classes.dex" else zin.read(item.filename)
        zout.writestr(item, data)
print("replaced classes.dex (%d bytes)" % len(dex))
EOF
ls -la "$MERGED_APK"

echo "--- [7/7] zipalign + sign + verify ---"
ALIGNED="$WORK/aligned.apk"
rm -f "$ALIGNED"
"$BT/zipalign" -f -p 4 "$MERGED_APK" "$ALIGNED"
KEYSTORE="$WORK/ps3mod.keystore"
if [ ! -f "$KEYSTORE" ]; then
  keytool -genkeypair -keystore "$KEYSTORE" -alias ps3mod -keyalg RSA \
    -keysize 2048 -validity 10950 -storepass "$KEYSTORE_PASS" \
    -keypass "$KEYSTORE_PASS" -dname "CN=PS3Mod, OU=Personal, O=Personal, C=MA" >/dev/null
fi
rm -f "$OUTPUT_APK"
"$BT/apksigner" sign --ks "$KEYSTORE" --ks-pass "pass:$KEYSTORE_PASS" \
  --key-pass "pass:$KEYSTORE_PASS" --ks-key-alias ps3mod \
  --v1-signing-enabled true --v2-signing-enabled true \
  --out "$OUTPUT_APK" "$ALIGNED"
"$BT/apksigner" verify --print-certs "$OUTPUT_APK" 2>&1 | head -n 8
ls -la "$OUTPUT_APK"

echo "=== BUILD OK: $OUTPUT_APK ==="
md5sum "$OUTPUT_APK" || md5 -r "$OUTPUT_APK"
sha256sum "$OUTPUT_APK" || shasum -a 256 "$OUTPUT_APK"
