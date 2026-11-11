#!/usr/bin/env bash
# Dùng: tools/export_apk.sh <preset> <đường_dẫn_apk>   (xuất debug; chạy khi editor đóng)
# Preset Gradle (Android Demo, Android Gradle APK) cần android/build: thiếu thì cài template trước.
set -euo pipefail
if [ $# -ne 2 ]; then echo "Dùng: $0 <preset> <đường_dẫn_apk>" >&2; exit 2; fi
cd "$(dirname "$0")/.."
mkdir -p "$(dirname "$2")"
# Godot chỉ nhận --install-android-build-template đi kèm --export-*, nên xuất thử một lần (template cài trước, rồi
# build; kết quả bỏ). Preset không Gradle thì Godot bỏ qua template.
if [ ! -f android/build/build.gradle ] || [ ! -f android/.build_version ]; then
	echo "Cài Android build template (xuất thử, bỏ kết quả) ..."
	tools/godot.sh --headless --path . --install-android-build-template \
		--export-debug "$1" build/.template_probe.apk >/dev/null 2>&1 || true
	rm -f build/.template_probe.apk build/.template_probe.apk.idsig
fi
# SDF thân khối bake sẵn: chỉ bake lại khi level hoặc cách dựng SDF đổi.
tools/godot.sh --headless --path . -s res://tools/bake_sdf.gd
tools/godot.sh --headless --path . --export-debug "$1" "$2"
test -s "$2"
