#!/usr/bin/env bash
# Smoke: chơi game bằng bấm thật, mỗi kịch bản một tiến trình Godot (docs/TESTING.md "Tầng 2").
#   tools/smoke.sh [headless|window] [kịch bản...]     # mặc định headless A B C D E M S
#   tools/smoke.sh window B
# Biến môi trường:
#   SMOKE_RES=<w>x<h>    cỡ cửa sổ (mặc định 443x960, cùng tỉ lệ màn chuẩn 886x1920)
#   SMOKE_SPEED=<x>      Engine.time_scale (mặc định 3 khi headless, 1 khi window)
#   SMOKE_SEED=<n>       seed của monkey (mặc định 1)
#   SMOKE_TAPS=<n>       số lần bấm của monkey trên mỗi save (mặc định 250, hai save)
#   SMOKE_TIMEOUT=<giây> hạn mỗi kịch bản (mặc định 900)
# Kết quả: output/smoke/<mode>/<kịch bản>/smoke.log, ảnh PNG (window), census_*.json, meta.json; báo cáo
# output/report/index.html. Mã thoát: 0 mọi kịch bản "SMOKE OK"; 1 có kịch bản "SMOKE FAILED"; 2 hạ tầng hỏng
# (không có dòng kết thúc, timeout, crash, có input thật lúc chạy window, chờ khoá quá lâu).
# Mỗi lúc chỉ một smoke chạy (khoá ~/.candy_godot.lock): cửa sổ, chuột và user://smoke_* dùng chung.
set -u
cd "$(dirname "$0")/.." || exit 2
MODE=headless
case "${1:-}" in
  headless|window) MODE=$1; shift ;;
esac
SCENS=("$@")
[ ${#SCENS[@]} -eq 0 ] && SCENS=(A B C D E M S)
TIMEOUT_SEC="${SMOKE_TIMEOUT:-900}"
RES="${SMOKE_RES:-443x960}"
if [ "$MODE" = window ]; then SPEED="${SMOKE_SPEED:-1}"; else SPEED="${SMOKE_SPEED:-3}"; fi

LOCK="$HOME/.candy_godot.lock"
WAITED=0
until mkdir "$LOCK" 2> /dev/null; do
  if [ -f "$LOCK/info" ]; then
    AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK/info") ))
    if [ "$AGE" -gt 1800 ]; then
      echo "Gỡ khoá kẹt ($AGE giây): $(cat "$LOCK/info")"
      rm -rf "$LOCK"
      continue
    fi
  fi
  [ "$WAITED" -eq 0 ] && echo "Chờ phiên khác chạy smoke xong ($LOCK: $(cat "$LOCK/info" 2> /dev/null))"
  if [ "$WAITED" -ge 600 ]; then
    echo "tools/smoke.sh: chờ khoá quá ${WAITED} giây (mã 2)"
    exit 2
  fi
  sleep 5
  WAITED=$(( WAITED + 5 ))
done
echo "pid $$, $(date '+%F %T'), $(pwd), $MODE ${SCENS[*]}" > "$LOCK/info"
trap 'rm -rf "$LOCK"' EXIT
trap 'rm -rf "$LOCK"; exit 2' INT TERM

[ -f output/.gdignore ] || { mkdir -p output && : > output/.gdignore; }
ROOT_ABS="$(pwd -W 2> /dev/null || pwd)"
WORST=0
for S in "${SCENS[@]}"; do
  DIR="output/smoke/$MODE/$S"
  rm -rf "$DIR"
  mkdir -p "$DIR"
  ARGS=(--path . --resolution "$RES" -s res://tests/smoke/smoke_main.gd --)
  [ "$MODE" = headless ] && ARGS=(--headless "${ARGS[@]}")
  ARGS+=("scen=$S" "out=$ROOT_ABS/$DIR" "speed=$SPEED" "seed=${SMOKE_SEED:-1}" "taps=${SMOKE_TAPS:-250}"
    "window=$([ "$MODE" = window ] && echo 1 || echo 0)" "max=$(( TIMEOUT_SEC - 30 ))")
  # SMOKE_ARGS="from=1 to=30": key=value thêm cho kịch bản (V: from, to; mọi kịch bản: idle, pace, capture).
  [ -n "${SMOKE_ARGS:-}" ] && ARGS+=($SMOKE_ARGS)
  START=$(date +%s)
  timeout --kill-after=10 "$TIMEOUT_SEC" tools/godot.sh "${ARGS[@]}" > "$DIR/smoke.log" 2>&1
  CODE=$?
  USED=$(( $(date +%s) - START ))
  if grep -q '^SMOKE REAL INPUT' "$DIR/smoke.log"; then
    RC=2; WHY="có input thật trong lúc chạy, lần chạy không hợp lệ"
  elif [ "$CODE" -eq 0 ] && grep -q '^SMOKE OK' "$DIR/smoke.log"; then
    RC=0; WHY="đạt"
  elif grep -q '^SMOKE FAILED' "$DIR/smoke.log"; then
    RC=1; WHY="$(grep -m1 '^SMOKE FAILED' "$DIR/smoke.log" | cut -c1-160)"
  elif [ "$CODE" -eq 124 ] || [ "$CODE" -eq 137 ]; then
    RC=2; WHY="quá $TIMEOUT_SEC giây, bị timeout dừng"
  else
    RC=2; WHY="không có dòng kết thúc, Godot thoát mã $CODE"
  fi
  printf '{"kind":"smoke","mode":"%s","scen":"%s","seconds":%d,"exit":%d,"rc":%d,"why":"%s"}\n' \
    "$MODE" "$S" "$USED" "$CODE" "$RC" "${WHY//\"/}" > "$DIR/meta.json"
  echo "== $S ($MODE, ${USED} giây): $WHY"
  grep -E '^SMOKE (FAILED|INVARIANT|ERRORS|WARN|REAL INPUT|FRAMES|SOLVER|MEM|CASES|CASE [^ ]+ (FAIL|blocked|missing|look))' "$DIR/smoke.log" | head -n 60
  [ "$RC" -eq 2 ] && tail -n 20 "$DIR/smoke.log"
  [ "$RC" -gt "$WORST" ] && WORST=$RC
done
if command -v node > /dev/null 2>&1; then
  node tools/report.mjs > /dev/null && echo "Báo cáo: output/report/index.html"
fi
echo "tools/smoke.sh: mã $WORST"
exit "$WORST"
