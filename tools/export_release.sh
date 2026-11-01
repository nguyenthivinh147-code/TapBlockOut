#!/usr/bin/env bash
# Dùng: tools/export_release.sh           (chạy khi editor Godot đóng)
# Ra build/TapBlockOut-gradle-debug.apk (APK debug có plugin) và
# build/TapBlockOut-release-<versionName>.aab (AAB bản phát hành, KHÔNG ký: Horus ký).
# Không tạo, không in, không ghi keystore hay mật khẩu. Thiếu android/config/platform_config.json
# vẫn build bình thường (mô-đun thiếu cấu hình tự tắt).
set -euo pipefail
cd "$(dirname "$0")/.."

export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk-amd64}"
PRESETS=export_presets.cfg
APK_PRESET="Android Gradle APK"
AAB_PRESET="Android Release"
BUILD_DIR=android/build
MANIFEST=$BUILD_DIR/src/main/AndroidManifest.xml
CONFIG_SRC=android/config/platform_config.json
GSERVICES_SRC=android/config/google-services.json
CONFIG_TMP=android_config.json
GSERVICES_VERSION=4.4.4

# versionName của preset "Android Release" (section [preset.N] có name đó).
version_name=$(python3 -I - "$PRESETS" "$AAB_PRESET" <<'EOF'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'\[preset\.(\d+)\]\s*\nname="%s"' % re.escape(sys.argv[2]), text)
if not m:
    sys.exit("không thấy preset " + sys.argv[2])
n = m.group(1)
sec = text.split("[preset.%s.options]" % n, 1)[1].split("\n[preset.", 1)[0]
v = re.search(r'^version/name="([^"]+)"', sec, re.M)
if not v:
    sys.exit("preset thiếu version/name")
print(v.group(1))
EOF
)
AAB_OUT="build/TapBlockOut-release-${version_name}.aab"
APK_OUT="build/TapBlockOut-gradle-debug.apk"

for f in addons/tbo_platform/bin/tbo_platform-debug.aar addons/tbo_platform/bin/tbo_platform-release.aar \
		addons/GodotGooglePlayBilling/bin/debug/GodotGooglePlayBilling-debug.aar \
		addons/GodotGooglePlayBilling/bin/release/GodotGooglePlayBilling-release.aar; do
	[ -s "$f" ] || { echo "Thiếu $f (chạy tools/build_plugin.sh hoặc tools/install_billing.sh)" >&2; exit 1; }
done

cleanup() {
	rm -f "$CONFIG_TMP" "$CONFIG_TMP.import"
}
trap cleanup EXIT

mkdir -p build

# 1. Cài android build template nếu thiếu. Godot chỉ nhận --install-android-build-template đi
#    kèm --export-*, nên xuất thử APK Gradle ra file tạm (template cài trước, rồi build; kết quả bỏ).
if [ ! -f "$BUILD_DIR/build.gradle" ] || [ ! -f android/.build_version ]; then
	echo "Cài Android build template (xuất thử, bỏ kết quả) ..."
	tools/godot.sh --headless --path . --install-android-build-template \
		--export-debug "$APK_PRESET" build/.template_probe.apk >/dev/null 2>&1 || true
	rm -f build/.template_probe.apk build/.template_probe.apk.idsig
	[ -f "$BUILD_DIR/build.gradle" ] || { echo "Không cài được android/build (template)" >&2; exit 1; }
fi

# 2. Vá template (idempotent). Các thay đổi này nằm trong android/build/ nên không vào git.
python3 -I - "$MANIFEST" <<'EOF'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
m = re.search(r"<application\b[^>]*>", s)
if not m:
    sys.exit("manifest không có thẻ <application>")
tag = m.group(0)
new = tag
def setattr_(t, name, value):
    pat = r'\s%s="[^"]*"' % re.escape(name)
    if re.search(pat, t):
        return re.sub(pat, ' %s="%s"' % (name, value), t, count=1)
    return t.replace("<application", '<application\n        %s="%s"' % (name, value), 1)
new = setattr_(new, "android:allowBackup", "true")
new = setattr_(new, "android:fullBackupContent", "@xml/tbo_backup_rules")
new = setattr_(new, "android:dataExtractionRules", "@xml/tbo_data_extraction_rules")
if new != tag:
    open(p, "w", encoding="utf-8").write(s.replace(tag, new, 1))
    print("Đã vá manifest (Auto Backup).")
EOF

# 2b. play_games_app_id -> res/values/tbo_platform.xml (export plugin cũng ghi; làm ở đây cho chắc thứ tự).
VALUES_FILE=$BUILD_DIR/res/values/tbo_platform.xml
app_id=""
if [ -f "$CONFIG_SRC" ]; then
	app_id=$(python3 -I - "$CONFIG_SRC" <<'EOF'
import json, sys
try:
    v = str(json.load(open(sys.argv[1], encoding="utf-8")).get("play_games_app_id", "")).strip()
except Exception:
    v = ""
print(v if v.isdigit() else "")
EOF
)
fi
if [ -n "$app_id" ]; then
	mkdir -p "$(dirname "$VALUES_FILE")"
	printf '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n\t<string name="game_services_project_id" translatable="false">%s</string>\n</resources>\n' "$app_id" > "$VALUES_FILE"
else
	rm -f "$VALUES_FILE"
fi

# 2c. google-services.json (tuỳ chọn): chép vào template và áp plugin Gradle. Không có file thì
#     gỡ vết cũ và dùng khoá firebase_* trong platform_config.json.
python3 -I - "$BUILD_DIR" "$GSERVICES_VERSION" "$([ -f "$GSERVICES_SRC" ] && echo 1 || echo 0)" <<'EOF'
import os, re, sys
d, ver, on = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
plugin_id = "com.google.gms.google-services"
def patch(path, anchor_re, line, present):
    s = open(path, encoding="utf-8").read()
    has = plugin_id in s
    if on and not has:
        s = re.sub(anchor_re, lambda m: m.group(0) + line, s, count=1)
    elif not on and has:
        s = "\n".join(l for l in s.split("\n") if plugin_id not in l) + ("" if s.endswith("\n") else "")
    open(path, "w", encoding="utf-8").write(s)
patch(os.path.join(d, "settings.gradle"), r"id 'org\.jetbrains\.kotlin\.android' version [^\n]*\n",
      "        id '%s' version '%s'\n" % (plugin_id, ver), None)
patch(os.path.join(d, "build.gradle"), r"id 'org\.jetbrains\.kotlin\.android'\n",
      "    id '%s'\n" % plugin_id, None)
EOF
if [ -f "$GSERVICES_SRC" ]; then
	cp "$GSERVICES_SRC" "$BUILD_DIR/google-services.json"
else
	rm -f "$BUILD_DIR/google-services.json"
fi

# 3. android_config.json tạm (vào PCK, không chứa bí mật riêng tư). Thiếu nguồn thì không tạo.
#    Kèm .import "keep" để file nằm nguyên văn trong PCK (không bị đổi thành resource JSON).
rm -f "$CONFIG_TMP" "$CONFIG_TMP.import"
if [ -f "$CONFIG_SRC" ]; then
	cp "$CONFIG_SRC" "$CONFIG_TMP"
	printf '[remap]\n\nimporter="keep"\n' > "$CONFIG_TMP.import"
	echo "Có platform_config.json: chép thành $CONFIG_TMP"
else
	echo "Không có $CONFIG_SRC: build không cấu hình (mô-đun thiếu khoá tự tắt)."
fi

# 4. Import (cập nhật .godot), rồi xuất.
tools/godot.sh --headless --path . --import >/dev/null 2>&1 || true

rm -f "$APK_OUT" "$AAB_OUT"
echo "Xuất APK debug (Gradle): $APK_OUT"
tools/godot.sh --headless --path . --export-debug "$APK_PRESET" "$APK_OUT"
test -s "$APK_OUT"
echo "Xuất AAB phát hành (chưa ký): $AAB_OUT"
tools/godot.sh --headless --path . --export-release "$AAB_PRESET" "$AAB_OUT"
test -s "$AAB_OUT"

echo "Xong:"
ls -lh "$APK_OUT" "$AAB_OUT"
