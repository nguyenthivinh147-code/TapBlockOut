#!/usr/bin/env bash
# Chạy Godot 4.7.2; ghi đè đường dẫn bằng biến GODOT.
GODOT="${GODOT:-/home/tungcv2/Projects/Godot/Engine/Godot_v4.7.2-stable_linux.x86_64}"
exec "$GODOT" "$@"
