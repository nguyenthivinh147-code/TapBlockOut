#!/usr/bin/env bash
# Chạy Godot 4.7.2; ghi đè đường dẫn bằng biến GODOT.
if [ -z "${GODOT:-}" ]; then
  GODOT=/home/tungcv2/Projects/Godot/Engine/Godot_v4.7.2-stable_linux.x86_64
  # Máy Windows (Git Bash): bản win64 để ở Desktop.
  if [ ! -x "$GODOT" ] && [ -n "${USERPROFILE:-}" ]; then
    WIN_GODOT="$(cygpath -u "$USERPROFILE" 2>/dev/null)/Desktop/Godot_v4.7.2-stable_win64.exe"
    [ -f "$WIN_GODOT" ] && GODOT="$WIN_GODOT"
  fi
fi
exec "$GODOT" "$@"
