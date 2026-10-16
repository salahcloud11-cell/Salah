#!/usr/bin/env python3
"""Inject the PS3Mapper (com.ps3mod) hooks into a decoded APK directory.

Usage:
    patch_apk.py <decoded_dir> [ps3mod_smali_dir]

Steps:
  1. Parse AndroidManifest.xml -> package, version, launcher activity.
  2. If a ps3mod smali dir is given, copy com/ps3mod/*.smali into the best
     smali_classes* dir (64K heuristic). Otherwise the mapper classes are
     merged at dex level later (see build.sh d8 step) and this is skipped.
  3. Inject dispatchKeyEvent / dispatchGenericMotionEvent overrides into the
     launcher activity smali (hooks the originals if they already exist).
  4. Add gamepad/usb-host <uses-feature> entries + "-ps3" versionName suffix.
  5. Write analysis.txt with everything the build needs.

Only stdlib is used.
"""

import glob
import os
import re
import shutil
import sys
import xml.etree.ElementTree as ET

ANDROID_NS = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID_NS)


def register_manifest_namespaces(manifest_path):
    """Preserve every xmlns prefix (tools, dist, ...) so ET won't emit ns0:."""
    try:
        with open(manifest_path, "r", encoding="utf-8") as fh:
            raw = fh.read(65536)
    except OSError:
        return
    for prefix, uri in re.findall(r'xmlns:([A-Za-z0-9_.-]+)="([^"]+)"', raw):
        if prefix == "android":
            continue
        try:
            ET.register_namespace(prefix, uri)
        except ValueError:
            pass


def android_attr(name):
    return "{%s}%s" % (ANDROID_NS, name)


KEY_METHOD = """\
.method public dispatchKeyEvent(Landroid/view/KeyEvent;)Z
    .locals 2
    invoke-static {{p0, p1}}, Lcom/ps3mod/PS3Mapper;->onKey(Landroid/app/Activity;Landroid/view/KeyEvent;)Z
    move-result v0
    if-eqz v0, :ps3mod_pass_key
    const/4 v0, 0x1
    return v0
    :ps3mod_pass_key
    {passthrough} {{p0, p1}}, {target}->dispatchKeyEvent(Landroid/view/KeyEvent;)Z
    move-result v0
    return v0
.end method
"""

MOTION_METHOD = """\
.method public dispatchGenericMotionEvent(Landroid/view/MotionEvent;)Z
    .locals 2
    invoke-static {{p0, p1}}, Lcom/ps3mod/PS3Mapper;->onMotion(Landroid/app/Activity;Landroid/view/MotionEvent;)Z
    move-result v0
    if-eqz v0, :ps3mod_pass_motion
    const/4 v0, 0x1
    return v0
    :ps3mod_pass_motion
    {passthrough} {{p0, p1}}, {target}->dispatchGenericMotionEvent(Landroid/view/MotionEvent;)Z
    move-result v0
    return v0
.end method
"""


def find_launcher_activity(manifest_root, package):
    for tag in ("activity", "activity-alias"):
        for act in manifest_root.iter(tag):
            for intent in act.iter("intent-filter"):
                has_main = False
                has_launcher = False
                for action in intent.iter("action"):
                    if action.get(android_attr("name")) == "android.intent.action.MAIN":
                        has_main = True
                for cat in intent.iter("category"):
                    if cat.get(android_attr("name")) == "android.intent.category.LAUNCHER":
                        has_launcher = True
                if has_main and has_launcher:
                    name = act.get(android_attr("name")) or ""
                    target = act.get(android_attr("targetActivity")) or ""
                    if tag == "activity-alias" and target:
                        name = target
                    if name.startswith("."):
                        return package + name
                    if "." not in name:
                        return package + "." + name
                    return name
    return None


def count_methods(smali_dir):
    total = 0
    for root, _dirs, files in os.walk(smali_dir):
        for f in files:
            if not f.endswith(".smali"):
                continue
            try:
                with open(os.path.join(root, f), "r", encoding="utf-8",
                          errors="ignore") as fh:
                    for line in fh:
                        if line.startswith(".method "):
                            total += 1
            except OSError:
                pass
    return total


def pick_smali_dir(decoded_dir):
    """Pick the smali dir with the fewest methods (64K-ref safety)."""
    candidates = sorted(glob.glob(os.path.join(decoded_dir, "smali*")))
    candidates = [d for d in candidates if os.path.isdir(d)]
    if not candidates:
        raise SystemExit("No smali* directories found in %s" % decoded_dir)
    scored = []
    for d in candidates:
        n = count_methods(d)
        scored.append((n, d))
        print("  %s: ~%d methods" % (os.path.basename(d), n))
    scored.sort()
    print("  -> injecting into %s" % os.path.basename(scored[0][1]))
    return scored[0][1]


def inject_activity(smali_path):
    with open(smali_path, "r", encoding="utf-8") as fh:
        text = fh.read()

    m_super = re.search(r"^\.super\s+(L[^;]+;)", text, re.M)
    m_class = re.search(r"^\.class[^\n]*\s+(L[^;]+;)", text, re.M)
    if not m_super or not m_class:
        raise SystemExit("Cannot parse .super/.class in %s" % smali_path)
    super_type = m_super.group(1)
    own_type = m_class.group(1)
    print("  activity smali: super=%s self=%s" % (super_type, own_type))

    additions = []
    for kind, template, short in (
            ("dispatchKeyEvent", KEY_METHOD, "Key"),
            ("dispatchGenericMotionEvent", MOTION_METHOD, "Motion")):
        pattern = re.compile(
            r"(^\.method[^\n]*?)\b%s\((Landroid/view/(?:KeyEvent|MotionEvent);)\)Z" % kind,
            re.M)
        m = pattern.search(text)
        if m:
            # Hook: rename original, override calls helper then original.
            orig_name = "ps3modOrigDispatch" + short
            text = pattern.sub(
                r"\1%s(\2)Z" % orig_name, text, count=1)
            # Build the override manually so the call target is the renamed original.
            if kind == "dispatchKeyEvent":
                additions.append(KEY_METHOD.format(
                    passthrough="invoke-virtual",
                    target=own_type).replace(
                        "->dispatchKeyEvent(", "->" + orig_name + "(", 1))
            else:
                additions.append(MOTION_METHOD.format(
                    passthrough="invoke-virtual",
                    target=own_type).replace(
                        "->dispatchGenericMotionEvent(",
                        "->" + orig_name + "(", 1))
            print("  hooked existing %s -> %s" % (kind, orig_name))
        else:
            additions.append(template.format(
                passthrough="invoke-super", target=super_type))
            print("  added new override %s" % kind)

    if not text.endswith("\n"):
        text += "\n"
    text += "\n# PS3 controller mapper (com.ps3mod) injected overrides\n"
    text += "\n".join(additions)
    with open(smali_path, "w", encoding="utf-8") as fh:
        fh.write(text)


def guess_unity_version(decoded_dir):
    # Best effort: scan libunity.so for a 20xx.y.z version string.
    for lib in glob.glob(os.path.join(decoded_dir, "lib", "*", "libunity.so")):
        try:
            with open(lib, "rb") as fh:
                blob = fh.read(2 * 1024 * 1024)
            m = re.search(rb"20\d{2}\.\d+\.[0-9a-zA-Z]+", blob)
            if m:
                return m.group(0).decode("ascii", "ignore")
        except OSError:
            pass
    return "unknown"


def find_ps3mapper_smali(ps3mod_smali):
    """Return dir containing PS3Mapper.smali, or None."""
    if not ps3mod_smali or not os.path.isdir(ps3mod_smali):
        return None
    direct = os.path.join(ps3mod_smali, "com", "ps3mod", "PS3Mapper.smali")
    if os.path.isfile(direct):
        return os.path.join(ps3mod_smali, "com", "ps3mod")
    hits = glob.glob(os.path.join(ps3mod_smali, "**", "PS3Mapper.smali"),
                     recursive=True)
    if hits:
        return os.path.dirname(hits[0])
    return None


def main():
    if len(sys.argv) not in (2, 3):
        print("Usage: patch_apk.py <decoded_dir> [ps3mod_smali_dir]")
        return 2
    decoded_dir = sys.argv[1]
    ps3mod_smali = sys.argv[2] if len(sys.argv) == 3 else None

    manifest_path = os.path.join(decoded_dir, "AndroidManifest.xml")
    register_manifest_namespaces(manifest_path)
    tree = ET.parse(manifest_path)
    root = tree.getroot()
    package = root.get("package", "")
    version_name = root.get(android_attr("versionName"), "unknown")
    version_code = root.get(android_attr("versionCode"), "0")
    print("package=%s versionName=%s versionCode=%s"
          % (package, version_name, version_code))

    activity = find_launcher_activity(root, package)
    if not activity:
        raise SystemExit("Launcher activity not found in manifest")
    print("launcher activity: %s" % activity)

    # 1. Copy mapper smali files (optional: dex-merge path skips this).
    src = find_ps3mapper_smali(ps3mod_smali)
    if src:
        print("Picking smali dir for injection:")
        smali_dir = pick_smali_dir(decoded_dir)
        dst = os.path.join(smali_dir, "com", "ps3mod")
        os.makedirs(dst, exist_ok=True)
        for f in os.listdir(src):
            if f.endswith(".smali"):
                shutil.copy2(os.path.join(src, f), os.path.join(dst, f))
                print("  copied com/ps3mod/%s" % f)
    else:
        print("No PS3Mapper smali provided: mapper will be merged at dex level (d8).")

    # 2. Inject activity overrides.
    rel = activity.replace(".", "/") + ".smali"
    smali_path = None
    for cand in sorted(glob.glob(os.path.join(decoded_dir, "smali*", rel))):
        smali_path = cand
        break
    if not smali_path:
        raise SystemExit("Activity smali not found for %s" % activity)
    print("Injecting overrides into %s"
          % os.path.relpath(smali_path, decoded_dir))
    inject_activity(smali_path)

    # 3. Manifest: uses-feature + versionName suffix.
    app_elem = root.find("application")
    features = [
        ("android.hardware.gamepad", "false"),
        ("android.hardware.usb.host", "false"),
    ]
    have = set()
    for f in root.iter("uses-feature"):
        have.add(f.get(android_attr("name")))
    for name, required in features:
        if name in have:
            continue
        elem = ET.Element("uses-feature")
        elem.set(android_attr("name"), name)
        elem.set(android_attr("required"), required)
        if app_elem is not None:
            idx = list(root).index(app_elem)
            root.insert(idx, elem)
        else:
            root.append(elem)
        print("  added uses-feature %s" % name)
    if not version_name.endswith("-ps3"):
        root.set(android_attr("versionName"), version_name + "-ps3")
    # Rebuilt dex is v037 (API 24+); keep minSdk honest so old devices get a
    # clean "not compatible" instead of a runtime crash.
    uses_sdk = root.find("uses-sdk")
    if uses_sdk is not None:
        try:
            cur_min = int(uses_sdk.get(android_attr("minSdkVersion"), "24"))
        except ValueError:
            cur_min = 24
        if cur_min < 24:
            uses_sdk.set(android_attr("minSdkVersion"), "24")
            print("  minSdkVersion %d -> 24" % cur_min)
    tree.write(manifest_path, encoding="utf-8", xml_declaration=True)
    print("  versionName -> %s" % root.get(android_attr("versionName")))

    # 4. Analysis file.
    dexes = sorted(glob.glob(os.path.join(decoded_dir, "smali*")))
    abis = sorted(d for d in os.listdir(os.path.join(decoded_dir, "lib"))
                  if os.path.isdir(os.path.join(decoded_dir, "lib", d))) \
        if os.path.isdir(os.path.join(decoded_dir, "lib")) else []
    unity = guess_unity_version(decoded_dir)
    uses_sdk = root.find("uses-sdk")
    min_sdk = uses_sdk.get(android_attr("minSdkVersion"), "21") \
        if uses_sdk is not None else "21"
    target_sdk = uses_sdk.get(android_attr("targetSdkVersion"), "?") \
        if uses_sdk is not None else "?"
    with open(os.path.join(decoded_dir, "analysis.txt"), "w",
              encoding="utf-8") as fh:
        fh.write("package=%s\n" % package)
        fh.write("versionName=%s\n" % version_name)
        fh.write("versionCode=%s\n" % version_code)
        fh.write("launcherActivity=%s\n" % activity)
        fh.write("dexCount=%d\n" % len(
            [d for d in dexes if os.path.isdir(d)]))
        fh.write("abis=%s\n" % ",".join(abis))
        fh.write("unity=%s\n" % unity)
        fh.write("minSdk=%s\n" % min_sdk)
        fh.write("targetSdk=%s\n" % target_sdk)
    print("wrote analysis.txt (abis=%s unity=%s minSdk=%s targetSdk=%s)"
          % (abis, unity, min_sdk, target_sdk))
    return 0


if __name__ == "__main__":
    sys.exit(main())
