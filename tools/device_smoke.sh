#!/usr/bin/env bash
# Smoke trên máy Android thật qua USB (docs/TESTING.md "Thiết bị thật"). Hai lệnh:
#
#   tools/device_smoke.sh build [apk]
#       Chép cây code sang snapshot $SNAP (mặc định output/device/snap). Trong snapshot: preset "Android Demo" mang
#       tests/smoke/, màn chính là tests/smoke/device_main.tscn (gốc là runner smoke.gd; template xuất ra bỏ qua -s),
#       rồi xuất bằng tools/export_apk.sh. Ra build/CandyAway-smoke.apk (mở app là chạy smoke, không chơi được) và,
#       trước đó, bản demo thường cùng code build/CandyAway-demo.apk (DEMO_APK=: bỏ qua) để cài lại khi test xong.
#       Code game lấy bản HEAD, test và tool lấy bản đang sửa (SNAP_GAME=worktree: lấy cả code game đang sửa). Cây
#       code thật không đổi; editor mở cũng được. Cần GODOT, JAVA_HOME (docs/TESTING.md "Thiết bị thật").
#
#   tools/device_smoke.sh run <kịch bản>... [key=value...]
#       APK smoke phải đã cài (adb install -r build/CandyAway-smoke.apk). Mỗi kịch bản (A, B, S, G, ...): ghi tham số
#       vào user://device_smoke_args.txt bằng run-as, mở app, theo logcat tới SMOKE OK/FAILED, lấy PSS mỗi 5 giây,
#       kéo census và ảnh về output/device/<thời điểm>/<kịch bản>/. G chạy restart=external: đợi SMOKE G READY, bấm
#       Home (onPause thật), force-stop, rồi tự chạy G2 trên cùng save. V (quét level) chạy theo đợt DEVICE_V_BATCH
#       (50) level, from=/to= (1–500), gộp levels.tsv. key=value thêm vào mọi kịch bản (capture=1 để chụp ảnh,
#       idle=, pace=, speed=, seed=, taps=, max=). adb rớt giữa chừng (unauthorized): chờ, nối lại logcat.
#
# Mã thoát như tools/smoke.sh: 0 đạt, 1 game có lỗi, 2 hạ tầng (không có máy, máy khoá, app không phải bản smoke,
# app chết không có dòng kết thúc, quá giờ). Không chạm vào khi đang chạy: chạm thật làm smoke báo SMOKE REAL INPUT.
set -uo pipefail
cd "$(dirname "$0")/.."
PKG=com.tungcv2.tapblockout
# Activity launcher (GodotApp không export, am start từ adb bị từ chối).
ACT=com.godot.game.GodotAppLauncher
ARGS_FILE=files/device_smoke_args.txt
DEVICE_MAIN=res://tests/smoke/device_main.tscn
LOG_FILTER="godot:V AndroidRuntime:E DEBUG:V libc:E *:S"

adbx() { adb ${ANDROID_SERIAL:+-s "$ANDROID_SERIAL"} "$@"; }

cmd_build() {
	local apk="${1:-build/CandyAway-smoke.apk}" snap="${SNAP:-output/device/snap}" real
	real="$(pwd)"
	[ -f output/.gdignore ] || { mkdir -p output && : > output/.gdignore; }
	mkdir -p "$snap"
	echo "== snapshot -> $snap"
	if command -v robocopy > /dev/null 2>&1; then
		MSYS_NO_PATHCONV=1 robocopy "$(cygpath -w "$real")" "$(cygpath -w "$snap")" /MIR \
			/XD .git build reference output .claude node /NFL /NDL /NJH /NP /R:1 /W:1 > /dev/null
		[ $? -ge 8 ] && { echo "robocopy lỗi"; return 2; }
	else
		rsync -a --delete --exclude .git --exclude /build --exclude /android/build --exclude /android/.build_version \
			--exclude reference --exclude output --exclude .claude --exclude tools/node "$real/" "$snap/" || return 2
	fi
	# Code game lấy bản HEAD (phiên song song có thể đang sửa dở src/, scenes/...); test, tool, tài liệu lấy bản đang
	# sửa. SNAP_GAME=worktree: lấy cả code game đang sửa.
	if [ "${SNAP_GAME:-head}" = head ]; then
		local f
		git -c core.quotepath=false diff --name-only HEAD -- . ':!tests' ':!tools' ':!docs' ':!plans' ':!.claude' \
			| while IFS= read -r f; do
				if git cat-file -e "HEAD:$f" 2> /dev/null; then git show "HEAD:$f" > "$snap/$f"; else rm -f "$snap/$f"; fi
				echo "  snapshot dùng bản HEAD: $f"
			done
		git -c core.quotepath=false ls-files --others --exclude-standard -- . ':!tests' ':!tools' ':!docs' ':!plans' \
			':!.claude' ':!output' | while IFS= read -r f; do
				rm -f "$snap/$f"
				echo "  snapshot bỏ file chưa commit: $f"
			done
	fi
	local out demo="${DEMO_APK-build/CandyAway-demo.apk}"
	case "$apk" in /*|?:*) out="$apk" ;; *) out="$real/$apk" ;; esac
	# Bản demo thường từ cùng snapshot (cùng code với APK smoke), để cài lại cho người dùng khi test xong.
	# DEMO_APK= (rỗng): bỏ qua.
	if [ -n "$demo" ]; then
		case "$demo" in /*|?:*) ;; *) demo="$real/$demo" ;; esac
		(cd "$snap" && tools/export_apk.sh "Android Demo" "$demo") || return 2
		ls -la "$demo"
	fi
	# Preset đầu tiên ("Android Demo"): mang tests/smoke/ (bộ lọc export cho "*" khớp cả "/", nên chỉ bỏ test_* và
	# ảnh). Màn chính: runner smoke.
	sed -i '0,/^exclude_filter="tests\/\*, /s//exclude_filter="tests\/test_*, tests\/shots\/*, /' "$snap/export_presets.cfg"
	sed -i "s|^run/main_scene=.*|run/main_scene=\"$DEVICE_MAIN\"|" "$snap/project.godot"
	if ! grep -q "^run/main_scene=\"$DEVICE_MAIN\"" "$snap/project.godot" \
			|| ! grep -q '^exclude_filter="tests/test_\*, ' "$snap/export_presets.cfg"; then
		echo "không sửa được preset Android Demo hoặc màn chính trong snapshot"
		return 2
	fi
	(cd "$snap" && tools/export_apk.sh "Android Demo" "$out") || return 2
	ls -la "$out"
	# Lúc export, Godot dò máy bằng adb của Android SDK trong editor settings; khác phiên bản với adb trong PATH thì nó
	# thay adb server, và máy chưa tích "Luôn cho phép" sẽ hỏi lại quyền gỡ lỗi USB. Trả server về adb trong PATH.
	adb kill-server > /dev/null 2>&1
	adb start-server > /dev/null 2>&1
	echo "adb: $(adb devices | awk 'NR>1 && NF>=2 {print $1, $2}' | tr '\n' ' ')"
}

# Máy sẵn sàng: đúng một máy (hoặc ANDROID_SERIAL), đã cho phép gỡ lỗi USB, đang mở khoá.
check_device() {
	local list
	list="$(adb devices | awk 'NR>1 && NF>=2')"
	if [ -z "${ANDROID_SERIAL:-}" ]; then
		[ "$(echo "$list" | grep -c .)" -eq 1 ] || { echo "cần đúng một máy (hoặc đặt ANDROID_SERIAL): $list"; return 2; }
	fi
	if echo "$list" | grep -q unauthorized; then
		echo "máy chưa cho phép gỡ lỗi USB: mở khoá máy, bấm Cho phép"; return 2
	fi
	if adbx shell dumpsys window 2> /dev/null | grep -qE 'mDreamingLockscreen=true|isKeyguardShowing=true|mShowingLockscreen=true'; then
		echo "máy đang khoá: mở khoá rồi chạy lại (máy khoá thì Godot không chạy khung nào)"; return 2
	fi
	adbx shell pm path "$PKG" > /dev/null 2>&1 || { echo "chưa cài $PKG: adb install -r build/CandyAway-smoke.apk"; return 2; }
}

# Nối vào file các dòng log mới từ bộ đệm của máy (từ thời điểm dòng cuối đã có). Lấy từng lần thay cho một luồng
# `adb logcat` chạy suốt: luồng đó không chết theo kill của bash (tiến trình adb còn sống, ghi tiếp vào file của đợt cũ)
# và đứt khi adb server khởi động lại.
log_poll() {
	local f="$1" last new
	last="$(grep -E '^[0-9]{2}-[0-9]{2} ' "$f" | tail -n1 | cut -c1-18)"
	if [ -z "$last" ]; then
		new="$(adbx logcat -d -v time $LOG_FILTER 2> /dev/null | tr -d '\r' | grep -v '^-----')"
	else
		new="$(adbx logcat -v time -t "$last" $LOG_FILTER 2> /dev/null | tr -d '\r' | grep -v '^-----' \
			| grep -vxF -f <(tail -n 300 "$f"))"
	fi
	[ -n "$new" ] && printf '%s\n' "$new" >> "$f"
	return 0
}

pss_kb() {
	adbx shell dumpsys meminfo "$PKG" 2> /dev/null | awk '/TOTAL PSS:/ {print $3; exit} /^ *TOTAL / {print $2; exit}'
}

# Chạy một kịch bản. $1 kịch bản, $2 thư mục kết quả, các tham số còn lại là key=value thêm.
run_one() {
	local scen="$1" dir="$2"; shift 2
	local max="${DEVICE_MAX:-900}"
	mkdir -p "$dir"
	{
		echo "scen=$scen"
		echo "out=user://device_smoke/$scen"
		echo "window=0"
		echo "max=$(( max - 30 ))"
		[ "$scen" = G ] && echo "restart=external"
		for kv in "$@"; do echo "$kv"; done
	} | tr -d '\r' > "$dir/args.txt"
	adbx shell am force-stop "$PKG"
	adbx shell "run-as $PKG sh -c 'mkdir -p files; rm -rf files/device_smoke/$scen; cat > $ARGS_FILE'" < "$dir/args.txt" \
		|| { echo "run-as lỗi: APK không phải bản debug?"; return 2; }
	adbx logcat -c
	: > "$dir/logcat.txt"
	adbx shell am start -W -n "$PKG/$ACT" > "$dir/am_start.txt" 2>&1
	local start end_line rc why t=0 lost=0
	start=$(date +%s)
	: > "$dir/pss.txt"
	while :; do
		sleep 5
		t=$(( $(date +%s) - start ))
		# adb server bị chương trình khác khởi động lại: máy báo unauthorized tới khi người dùng bấm Cho phép. App trên
		# máy vẫn chạy và log nằm trong bộ đệm của máy (4 MiB); chờ kết nối lại rồi lấy tiếp.
		if [ "$(adbx get-state 2> /dev/null | tr -d '\r')" != device ]; then
			[ "$lost" -eq 0 ] && echo "  mất kết nối adb lúc ${t} giây (unauthorized?): mở khoá máy, bấm Cho phép; đang chờ"
			lost=1
			[ "$t" -gt "$max" ] && { end_line="TIMEOUT"; break; }
			continue
		fi
		[ "$lost" -eq 1 ] && echo "  kết nối adb lại lúc ${t} giây"
		lost=0
		log_poll "$dir/logcat.txt"
		end_line="$(grep -m1 -oE 'SMOKE (OK|FAILED.*|G READY)' "$dir/logcat.txt")"
		[ -n "$end_line" ] && break
		[ "$t" -gt "$max" ] && { end_line="TIMEOUT"; break; }
		local kb
		kb="$(pss_kb)"
		[ -n "$kb" ] && echo "$t $kb" >> "$dir/pss.txt"
		if [ -z "$kb" ] && [ "$t" -gt 20 ]; then
			end_line="APP DIED"; break
		fi
		if [ "$t" -gt 60 ] && ! grep -q 'SMOKE START' "$dir/logcat.txt"; then
			end_line="NO SMOKE"; break
		fi
	done
	local kb_end
	kb_end="$(pss_kb)"
	[ -n "$kb_end" ] && echo "$t $kb_end" >> "$dir/pss.txt"
	if [ "$end_line" = "SMOKE G READY" ]; then
		adbx shell input keyevent KEYCODE_HOME
		sleep 3
	fi
	sleep 2
	log_poll "$dir/logcat.txt"
	adbx shell am force-stop "$PKG"
	sleep 1
	adbx exec-out run-as "$PKG" tar -cf - -C files "device_smoke/$scen" 2> /dev/null | tar -xf - -C "$dir" 2> /dev/null
	case "$end_line" in
		"SMOKE OK"|"SMOKE G READY") rc=0; why="đạt" ;;
		"SMOKE FAILED"*) rc=1; why="$(echo "$end_line" | cut -c1-160)" ;;
		"APP DIED") rc=2; why="app chết, không có dòng kết thúc (xem logcat.txt: DEBUG, AndroidRuntime)" ;;
		"NO SMOKE") rc=2; why="60 giây không có SMOKE START: APK đang cài không phải bản smoke?" ;;
		*) rc=2; why="quá $max giây" ;;
	esac
	grep -q 'SMOKE REAL INPUT' "$dir/logcat.txt" && { rc=2; why="có chạm thật trong lúc chạy, lần chạy không hợp lệ"; }
	summarize "$scen" "$dir" "$t" "$rc" "$why" | tee "$dir/summary.txt"
	return "$rc"
}

# Tóm tắt: khởi động (từ lúc tạo tiến trình tới SMOKE START và tới main boot xong), FRAMES, MEM, PSS, lỗi.
summarize() {
	local scen="$1" dir="$2" sec="$3" rc="$4" why="$5"
	echo "== $scen (máy thật, ${sec} giây): $why"
	awk '
		function ts(s,  a) { split(s, a, /[ :.]/); return a[2]*3600 + a[3]*60 + a[4] + a[5]/1000 }
		/Godot Engine v/ && !p { p = ts($1" "$2) }
		/SMOKE START/ && !s { s = ts($1" "$2) }
		/SMOKE STEP mở game/ && !m { m = ts($1" "$2) }
		END {
			if (p && s) printf "khởi động: engine và autoload %.1f giây", s - p
			if (p && m) printf ", main boot xong %.1f giây", m - p
			if (p && s) printf " (tính từ dòng đầu của Godot; am start -W ở dưới là tới khung đầu)\n"
		}' "$dir/logcat.txt"
	grep -m1 -E 'TotalTime' "$dir/am_start.txt" | sed 's/^ */am start -W: /'
	if [ "$scen" = V ]; then
		# Quét level: dòng tổng, level hỏng, 5 level có p95 khung hình cao nhất.
		sed -n 's/.*\(SMOKE \(LEVELS\|LEVEL FAIL\|ERRORS\|ERROR\|INVARIANT\|FAILED\)\)/\1/p' "$dir/logcat.txt" | head -n 40
		sed -n 's/.*SMOKE FRAMES \(L[0-9]*\) .*p50=\([0-9.]*\)ms p95=\([0-9.]*\)ms max=\([0-9.]*\)ms hitch=\([0-9]*\).*/\3 \1 p50=\2 p95=\3 max=\4 hitch=\5/p' \
			"$dir/logcat.txt" | sort -rn | head -n 5 | cut -d' ' -f2- | sed 's/^/p95 cao: /'
	else
		sed -n 's/.*\(SMOKE \(FRAMES\|SOLVER\|MEM\|HITCH\|ERRORS\|ERROR\|WARN\|INVARIANT\|FAILED\|CASES\|CASE [^ ]* \(FAIL\|blocked\|look\)\)\)/\1/p' "$dir/logcat.txt" \
			| grep -v '^SMOKE HITCH' | head -n 80
	fi
	if [ -s "$dir/pss.txt" ]; then
		awk '{ if (!min || $2 < min) min = $2; if ($2 > max) max = $2; last = $2 }
			END { printf "PSS: thấp nhất %.0f MB, cao nhất %.0f MB, cuối %.0f MB (%d mẫu)\n", min/1024, max/1024, last/1024, NR }' \
			"$dir/pss.txt"
	fi
	printf '{"kind":"device","scen":"%s","seconds":%d,"rc":%d,"why":"%s"}\n' "$scen" "$sec" "$rc" "${why//\"/}" > "$dir/meta.json"
}

# Quét level V theo đợt (mỗi đợt một lần mở app, mặc định 50 level: DEVICE_V_BATCH). from=, to= trong tham số thêm
# (mặc định 1–500). Mỗi đợt ở <root>/V_<từ>-<tới>/; bảng gộp <root>/levels.tsv (level, kết quả, chạm, MOVES còn/đầu,
# cỡ hình, khung hình p50/p95/max, số khung > 33 ms, solver tổng ms).
run_levels() {
	local root="$1"; shift
	local from=1 to=500 batch="${DEVICE_V_BATCH:-50}" rest=() worst=0 rc a e
	for kv in "$@"; do
		case "$kv" in from=*) from="${kv#from=}" ;; to=*) to="${kv#to=}" ;; *) rest+=("$kv") ;; esac
	done
	for (( a = from; a <= to; a += batch )); do
		e=$(( a + batch - 1 )); [ "$e" -gt "$to" ] && e=$to
		run_one V "$root/V_$a-$e" "${rest[@]}" "from=$a" "to=$e"
		rc=$?
		[ "$rc" -gt "$worst" ] && worst=$rc
	done
	cat "$root"/V_*/logcat.txt 2> /dev/null | awk '
		/SMOKE LEVEL [0-9]+ ok/ {
			match($0, /SMOKE LEVEL [0-9]+/); n = substr($0, RSTART + 12, RLENGTH - 12) + 0
			split(substr($0, RSTART + RLENGTH), f, /[ =]+/)
			res[n] = "ok"; taps[n] = f[4]; moves[n] = f[6]; board[n] = f[8]
		}
		/SMOKE LEVEL FAIL L[0-9]+:/ {
			match($0, /FAIL L[0-9]+:/); n = substr($0, RSTART + 6, RLENGTH - 7) + 0
			res[n] = "FAIL " substr($0, RSTART + RLENGTH + 1)
		}
		/SMOKE FRAMES L[0-9]+ / {
			match($0, /FRAMES L[0-9]+/); n = substr($0, RSTART + 8, RLENGTH - 8) + 0
			s = substr($0, RSTART + RLENGTH); gsub(/ms/, "", s); split(s, f, /[ =]+/)
			fr[n] = f[5] "\t" f[7] "\t" f[9] "\t" f[11]
		}
		/SMOKE SOLVER L[0-9]+ / {
			match($0, /SOLVER L[0-9]+/); n = substr($0, RSTART + 8, RLENGTH - 8) + 0
			s = substr($0, RSTART + RLENGTH); gsub(/ms/, "", s); split(s, f, /[ =]+/); sol[n] = f[9]
		}
		END {
			print "level\tket_qua\tcham\tmoves\thinh\tp50_ms\tp95_ms\tmax_ms\thitch\tsolver_ms"
			for (n = 1; n <= 100000; n++) if (n in res)
				print n "\t" res[n] "\t" taps[n] "\t" moves[n] "\t" board[n] "\t" (n in fr ? fr[n] : "\t\t\t") "\t" sol[n]
		}' > "$root/levels.tsv"
	awk -F'\t' 'NR > 1 { total++; if ($2 == "ok") ok++; else bad++; if ($7 + 0 > 33.4) slow++ }
		END { printf "== V tổng: %d level, đạt %d, hỏng %d, p95 > 33 ms ở %d level (bảng: levels.tsv)\n", total, ok, bad, slow }' \
		"$root/levels.tsv"
	grep -h 'SMOKE LEVEL FAIL sau' "$root"/V_*/logcat.txt 2> /dev/null | sed 's/.*SMOKE LEVEL FAIL /chuyển level hỏng: /'
	return "$worst"
}

cmd_run() {
	local scens=() extra=()
	for a in "$@"; do
		case "$a" in *=*) extra+=("$a") ;; *) scens+=("$a") ;; esac
	done
	[ ${#scens[@]} -gt 0 ] || { echo "Dùng: $0 run <kịch bản>... [key=value...]"; return 2; }
	check_device || return 2
	[ -f output/.gdignore ] || { mkdir -p output && : > output/.gdignore; }
	local root="output/device/$(date +%Y%m%d-%H%M%S)" worst=0 rc
	local stay
	stay="$(adbx shell settings get global stay_on_while_plugged_in | tr -d '\r')"
	adbx shell svc power stayon usb
	mkdir -p "$root"
	{
		echo "máy: $(adbx shell getprop ro.product.manufacturer | tr -d '\r') $(adbx shell getprop ro.product.model | tr -d '\r'), Android $(adbx shell getprop ro.build.version.release | tr -d '\r')"
		echo "RAM: $(adbx shell grep MemTotal /proc/meminfo | tr -d '\r')"
		echo "màn: $(adbx shell wm size | tr -d '\r' | tail -n1)"
		echo "app: $(adbx shell dumpsys package "$PKG" | grep -m1 versionName | tr -d '\r ')"
	} | tee "$root/device.txt"
	for s in "${scens[@]}"; do
		if [ "$s" = V ]; then
			run_levels "$root" "${extra[@]}"
			rc=$?
		else
			run_one "$s" "$root/$s" "${extra[@]}"
			rc=$?
			if [ "$s" = G ] && [ "$rc" -eq 0 ]; then
				run_one G2 "$root/G2" "${extra[@]}"
				rc=$?
			fi
		fi
		[ "$rc" -gt "$worst" ] && worst=$rc
	done
	if [ "$stay" = 0 ] || [ -z "$stay" ]; then adbx shell svc power stayon false; else adbx shell settings put global stay_on_while_plugged_in "$stay"; fi
	echo "Kết quả: $root"
	echo "tools/device_smoke.sh: mã $worst"
	return "$worst"
}

case "${1:-}" in
	build) shift; cmd_build "$@"; exit $? ;;
	run) shift; cmd_run "$@"; exit $? ;;
	*) sed -n '2,/^set -uo/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 2 ;;
esac
