#!/usr/bin/env bash
# Chạy skill /qa daily không cần người (docs/TESTING.md mục "Agent test (QA)"); Windows Task Scheduler gọi lúc 16:00.
#   tools/qa_daily.sh              chạy claude -p "/qa daily", log ở output/qa/scheduler/<thời điểm>.log
#   tools/qa_daily.sh --dry-run    chỉ in claude tìm được và lệnh sẽ chạy
# claude: biến CLAUDE_BIN, hoặc claude trong PATH, hoặc bản mới nhất trong extension VS Code.
# Mã thoát: mã của claude; 2 khi không tìm thấy claude.
cd "$(dirname "$0")/.." || exit 2

bin="${CLAUDE_BIN:-$(command -v claude 2> /dev/null)}"
if [ -z "$bin" ] && [ -n "${USERPROFILE:-}" ]; then
  ext="$(cygpath -u "$USERPROFILE" 2> /dev/null)/.vscode/extensions"
  dir=$(ls -d "$ext"/anthropic.claude-code-* 2> /dev/null | sort -V | tail -1)
  [ -n "$dir" ] && bin="$dir/resources/native-binary/claude.exe"
fi
if [ -z "$bin" ] || [ ! -x "$bin" ]; then
  echo "qa_daily: không tìm thấy claude (đặt CLAUDE_BIN)" >&2
  exit 2
fi

cmd=("$bin" -p "/qa daily" --permission-mode auto)
if [ "${1:-}" = "--dry-run" ]; then
  printf '%q ' "${cmd[@]}"
  echo
  exit 0
fi

mkdir -p output/qa/scheduler
log="output/qa/scheduler/$(date +%Y%m%d-%H%M).log"
echo "qa_daily: $(date -Iseconds) HEAD $(git rev-parse --short HEAD)" > "$log"
"${cmd[@]}" >> "$log" 2>&1
rc=$?
echo "qa_daily: xong, mã $rc" >> "$log"
exit $rc
