#!/usr/bin/env bash
# Chạy tests/test_*.gd (hoặc file bắt đầu bằng chuỗi lọc), ghi log vào output/test/<lần chạy>/, sinh
# output/report/index.html.
#   tools/test.sh                 # mọi test
#   tools/test.sh test_board      # chỉ tests/test_board*.gd
# Mã thoát: 0 sạch; 1 game có lỗi (FAIL, lỗi engine ngoài allowlist); 2 hạ tầng hỏng (không có dòng kết thúc,
# bị timeout giết, Godot không chạy hoặc crash, chờ khoá quá lâu). Đạt = thoát 0 và có dòng
# "ALL TESTS PASSED (<n>)" (docs/TESTING.md).
# Hai tiến trình chạy cùng một file test dùng chung user://test_<tên>/, nên mỗi lần chỉ một lần chạy: script giữ
# khoá ~/.candy_test.lock (mọi phiên, mọi worktree). TEST_TIMEOUT=<giây> đổi hạn một lần chạy (mặc định 1800),
# TEST_LOCK_WAIT=<giây> đổi thời gian chờ khoá (mặc định 2400).
set -u
cd "$(dirname "$0")/.." || exit 2
TIMEOUT_SEC="${TEST_TIMEOUT:-1800}"
LOCK="$HOME/.candy_test.lock"
WAITED=0
until mkdir "$LOCK" 2> /dev/null; do
  if [ -f "$LOCK/info" ]; then
    AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK/info") ))
    if [ "$AGE" -gt $(( TIMEOUT_SEC + 300 )) ]; then
      echo "Gỡ khoá kẹt ($AGE giây): $(cat "$LOCK/info")"
      rm -rf "$LOCK"
      continue
    fi
  fi
  [ "$WAITED" -eq 0 ] && echo "Chờ phiên khác chạy test xong ($LOCK: $(cat "$LOCK/info" 2> /dev/null))"
  if [ "$WAITED" -ge "${TEST_LOCK_WAIT:-2400}" ]; then
    echo "tools/test.sh: chờ khoá quá ${WAITED} giây (mã 2)"
    exit 2
  fi
  sleep 5
  WAITED=$(( WAITED + 5 ))
done
echo "pid $$, $(date '+%F %T'), $(pwd), lọc: $*" > "$LOCK/info"
trap 'rm -rf "$LOCK"' EXIT
trap 'rm -rf "$LOCK"; exit 2' INT TERM

mkdir -p output/test
[ -f output/.gdignore ] || : > output/.gdignore
RUN_DIR="output/test/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$RUN_DIR"
LOG="$RUN_DIR/run.log"
START=$(date +%s)
STARTED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
timeout --kill-after=10 "$TIMEOUT_SEC" tools/godot.sh --headless --path . -s res://tests/run_all.gd -- "$@" > "$LOG" 2>&1
CODE=$?
SECONDS_USED=$(( $(date +%s) - START ))

if [ "$CODE" -eq 0 ] && grep -q '^ALL TESTS PASSED (' "$LOG"; then
  RC=0; WHY="đạt"
elif grep -q '^TESTS FAILED ' "$LOG"; then
  RC=1; WHY="game có lỗi"
elif [ "$CODE" -eq 124 ] || [ "$CODE" -eq 137 ]; then
  RC=2; WHY="quá $TIMEOUT_SEC giây, bị timeout dừng"
elif grep -q '^ALL TESTS PASSED (' "$LOG"; then
  RC=2; WHY="test đạt nhưng Godot thoát mã $CODE (crash lúc thoát?)"
else
  RC=2; WHY="không có dòng kết thúc, Godot thoát mã $CODE"
fi

FILTER="$*"
printf '{"kind":"test","started":"%s","seconds":%d,"exit":%d,"rc":%d,"why":"%s","filter":"%s"}\n' \
  "$STARTED" "$SECONDS_USED" "$CODE" "$RC" "$WHY" "${FILTER//\"/}" > "$RUN_DIR/meta.json"
# Giữ 30 lần chạy gần nhất.
ls -1d output/test/2*-*/ 2> /dev/null | sort | head -n -30 | xargs -r rm -rf

grep -E '^(FAIL |ALLOWED |---- |ALL TESTS PASSED|TESTS FAILED)' "$LOG"
if [ "$RC" -eq 2 ]; then
  echo "---- 30 dòng cuối của $LOG ----"
  tail -n 30 "$LOG"
fi
if grep -q 'Unable to open file: res://.godot/imported/' "$LOG"; then
  echo "Gợi ý: cache import (.godot/imported) thiếu file của asset mới. Editor đóng: tools/godot.sh --headless --path . --import; editor mở: MCP filesystem_manage(op=\"scan\") hoặc focus cửa sổ editor."
fi
if command -v node > /dev/null 2>&1; then
  node tools/report.mjs "$RUN_DIR" > /dev/null && echo "Báo cáo: output/report/index.html"
fi
echo "tools/test.sh: $WHY (mã $RC, ${SECONDS_USED} giây, log $LOG)"
exit "$RC"
