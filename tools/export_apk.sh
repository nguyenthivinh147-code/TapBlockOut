#!/usr/bin/env bash
# Dùng: tools/export_apk.sh <preset> <đường_dẫn_apk>   (xuất debug; chạy khi editor đóng)
set -euo pipefail
if [ $# -ne 2 ]; then echo "Dùng: $0 <preset> <đường_dẫn_apk>" >&2; exit 2; fi
cd "$(dirname "$0")/.."
mkdir -p "$(dirname "$2")"
tools/godot.sh --headless --path . --export-debug "$1" "$2"
test -s "$2"
