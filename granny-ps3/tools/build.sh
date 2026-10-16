#!/usr/bin/env bash
# Build the Granny PS3-controller-modded APK.
#
# Usage:
#   build.sh <original.apk> <output.apk> [workdir]
#
# Required env (or default guesses):
#   APKTOOL_JAR   path to apktool.jar
#   BAKSMALI_JAR  path to baksmali.jar
#   ANDROID_HOME  Android SDK root (platforms/android-34 + build-tools/34.0.0)
#
# Optional env:
#   JAVA_HOME     JDK 17+ (uses `java`/`javac`/`keytool` from PATH otherwise)
#   KEYSTORE_PASS password for the throwaway signing key (default: ps3modps3mod)
#
# Pipeline:
#   1. apktool decode
#   2. javac com.ps3mod -> d8 -> baksmali -> mapper smali
#   3. patch_apk.py injects smali + activity hooks + manifest tweaks
#   4. apktool build -> zipalign -> apksigner sign -> verify
set -euo pipefail

ORIG_APK="${1:?usage: build.sh <original.apk> <output.apk> [workdir]}"
OUTPUT_APK="${2:?usage: build.sh <original.apk> <output.apk> [workdir]}"
WORK="${3:-$(pwd)/granny-ps3-work}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_JAVA="$SCRIPT_DIR/../java"

APKTOOL_JAR="${APKTOOL_JAR:-$WORK/tools/apktool.jar}"
BAKSMALI_JAR="${BAKSMALI_JAR:-$WORK/tools/baksmali.jar}"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
BT="$ANDROID_HOME/build-tools/34.0.0"
ANDROID_JAR="$ANDROID_HOME/platforms/android-34/android.jar"
KEYSTORE_PASS="${KEYSTORE_PASS:-ps3modps3mod}"

echo "=== Granny PS3-mod build ==="
echo "orig:    $ORIG_APK"
echo "output:  $OUTPUT_APK"
echo "work:    $WORK"
echo "apktool: $APKTOOL_JAR"
echo "sdk:     $ANDROID_HOME"

command -v java >/dev/null || { echo "ERROR: java not found"; exit 1; }
command -v javac >/dev/null || { echo "ERROR: javac not found"; exit 1; }
[ -f "$APKTOOL_JAR" ] || { echo "ERROR: apktool jar missing: $APKTOOL_JAR"; exit 1; }
[ -f "$BAKSMALI_JAR" ] || { echo "ERROR: baksmali jar missing: $BAKSMALI_JAR"; exit 1; }
[ -f "$ANDROID_JAR" ] || { echo "ERROR: android.jar missing: $ANDROID_JAR"; exit 1; }
[ -x "$BT/d8" ] || { echo "ERROR: d8 missing: $BT/d8"; exit 1; }
[ -f "$ORIG_APK" ] || { echo "ERROR: input APK missing: $ORIG_APK"; exit 1; }

mkdir -p "$WORK"
DECODED="$WORK/decoded"
CLASSES="$WORK/mapper-classes"
MAPPER_DEX="$WORK/mapper-dex"
MAPPER_SMALI="$WORK/mapper-smali"

echo "--- [1/6] apktool decode ---"
rm -rf "$DECODED"
java -jar "$APKTOOL_JAR" d -f -o "$DECODED" "$ORIG_APK" 2>&1 | tail -n 5
echo "decoded OK"

echo "--- [2/6] compile com.ps3mod (javac) ---"
rm -rf "$CLASSES"
mkdir -p "$CLASSES"
find "$REPO_JAVA" -name '*.java' | sort
javac -source 8 -target 8 -nowarn -cp "$ANDROID_JAR" -d "$CLASSES" \
  $(find "$REPO_JAVA" -name '*.java' | sort) 2>&1 | grep -v "bootstrap\|deprecat" || true
echo "javac OK"

echo "--- [3/6] d8 -> baksmali (mapper smali) ---"
rm -rf "$MAPPER_DEX" "$MAPPER_SMALI"
mkdir -p "$MAPPER_DEX"
"$BT/d8" --min-api 21 --lib "$ANDROID_JAR" --output "$MAPPER_DEX" \
  $(find "$CLASSES" -name '*.class' | sort)
ls -la "$MAPPER_DEX"
java -jar "$BAKSMALI_JAR" d "$MAPPER_DEX/classes.dex" -o "$MAPPER_SMALI"
find "$MAPPER_SMALI" -name '*.smali'
echo "mapper smali OK"

echo "--- [4/6] patch_apk.py inject ---"
python3 "$SCRIPT_DIR/patch_apk.py" "$DECODED" "$MAPPER_SMALI"
cp "$DECODED/analysis.txt" "$WORK/analysis.txt"
cat "$WORK/analysis.txt"

echo "--- [5/6] apktool build ---"
UNSIGNED="$WORK/unsigned.apk"
rm -f "$UNSIGNED"
java -jar "$APKTOOL_JAR" b -o "$UNSIGNED" "$DECODED" 2>&1 | tail -n 5
ls -la "$UNSIGNED"

echo "--- [6/6] zipalign + sign + verify ---"
ALIGNED="$WORK/aligned.apk"
rm -f "$ALIGNED"
"$BT/zipalign" -f -p 4 "$UNSIGNED" "$ALIGNED"
KEYSTORE="$WORK/ps3mod.keystore"
if [ ! -f "$KEYSTORE" ]; then
  keytool -genkeypair -keystore "$KEYSTORE" -alias ps3mod -keyalg RSA \
    -keysize 2048 -validity 10950 -storepass "$KEYSTORE_PASS" \
    -keypass "$KEYSTORE_PASS" -dname "CN=PS3Mod, OU=Personal, O=Personal, C=MA" >/dev/null
fi
rm -f "$OUTPUT_APK"
"$BT/apksigner" sign --ks "$KEYSTORE" --ks-pass:"$KEYSTORE_PASS" \
  --key-pass:"$KEYSTORE_PASS" --ks-key-alias ps3mod \
  --v1-signing-enabled true --v2-signing-enabled true \
  --out "$OUTPUT_APK" "$ALIGNED"
"$BT/apksigner" verify --print-certs "$OUTPUT_APK" 2>&1 | head -n 8
ls -la "$OUTPUT_APK"

echo "=== BUILD OK: $OUTPUT_APK ==="
md5sum "$OUTPUT_APK" || md5 -r "$OUTPUT_APK"
sha256sum "$OUTPUT_APK" || shasum -a 256 "$OUTPUT_APK"
