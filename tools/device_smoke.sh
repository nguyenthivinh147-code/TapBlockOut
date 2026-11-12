#!/usr/bin/env bash
# Smoke trên máy Android thật qua USB (docs/TESTING.md "Thiết bị thật"). Hai lệnh:
#
#   tools/device_smoke.sh build [apk]
#       Chép cây code sang snapshot $SNAP (mặc định output/device/snap). Trong snapshot: preset "Android Demo" mang
#       tests/smoke/, màn chính là tests/smoke/device_main.tscn (gốc là runner smoke.gd; template xuất ra bỏ qua -s),
#       rồi xuất bằng tools/export_apk.sh. Mặc định ra build/CandyAway-smoke.apk: mở app là chạy smoke, không chơi
#       được như bản demo. Cây code thật không đổi; editor mở cũng được. Cần GODOT như export_apk.sh (Windows: bản
#       Godot tự chứa, xem docs/DEMO_NOTES.md) và JAVA_HOME 17.
#
#   tools/device_smoke.sh run <kịch bản>... [key=value...]
#       APK smoke phải đã cài (adb install -r build/CandyAway-smoke.apk). Mỗi kịch bản (A, B, S, G, ...): ghi tham số
#       vào user://device_smoke_args.txt bằng run-as, mở app, theo logcat tới SMOKE OK/FAILED, lấy PSS mỗi 5 giây,
#       kéo census và ảnh về output/device/<thời điểm>/<kịch bản>/. G chạy restart=external: đợi SMOKE G READY, bấm
#       Home (onPause thật), force-stop, rồi tự chạy G2 trên cùng save. key=value thêm vào mọi kịch bản (capture=1
#       để chụp ảnh, speed=, seed=, taps=, max=).
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
	# Preset đầu tiên ("Android Demo"): mang tests/smoke/ (bộ lọc export cho "*" khớp cả "/", nên chỉ bỏ test_* và
	# ảnh). Màn chính: runner smoke.
	sed -i '0,/^exclude_filter="tests\/\*, /s//exclude_filter="tests\/test_*, tests\/shots\/*, /' "$snap/export_presets.cfg"
	sed -i "s|^run/main_scene=.*|run/main_scene=\"$DEVICE_MAIN\"|" "$snap/project.godot"
	if ! grep -q "^run/main_scene=\"$DEVICE_MAIN\"" "$snap/project.godot" \
			|| ! grep -q '^exclude_filter="tests/test_\*, ' "$snap/export_presets.cfg"; then
		echo "không sửa được preset Android Demo hoặc màn chính trong snapshot"
		return 2
	fi
	local out
	case "$apk" in /*|?:*) out="$apk" ;; *) out="$real/$apk" ;; esac
	(cd "$snap" && tools/export_apk.sh "Android Demo" "$out") || return 2
	ls -la "$out"
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
	adbx logcat -v time godot:V ActivityManager:I AndroidRuntime:E DEBUG:V libc:E '*:S' > "$dir/logcat.txt" 2>&1 &
	local lpid=$!
	adbx shell am start -W -n "$PKG/$ACT" > "$dir/am_start.txt" 2>&1
	local start end_line rc why t=0
	start=$(date +%s)
	: > "$dir/pss.txt"
	while :; do
		sleep 5
		t=$(( $(date +%s) - start ))
		end_line="$(grep -m1 -oE 'SMOKE (OK|FAILED.*|G READY)' "$dir/logcat.txt")"
		[ -n "$end_line" ] && break
		local kb
		kb="$(pss_kb)"
		[ -n "$kb" ] && echo "$t $kb" >> "$dir/pss.txt"
		if [ -z "$kb" ] && [ "$t" -gt 20 ]; then
			end_line="APP DIED"; break
		fi
		if [ "$t" -gt 60 ] && ! grep -q 'SMOKE START' "$dir/logcat.txt"; then
			end_line="NO SMOKE"; break
		fi
		[ "$t" -gt "$max" ] && { end_line="TIMEOUT"; break; }
	done
	local kb_end
	kb_end="$(pss_kb)"
	[ -n "$kb_end" ] && echo "$t $kb_end" >> "$dir/pss.txt"
	if [ "$end_line" = "SMOKE G READY" ]; then
		adbx shell input keyevent KEYCODE_HOME
		sleep 3
	fi
	sleep 2
	adbx shell am force-stop "$PKG"
	sleep 1
	kill "$lpid" 2> /dev/null
	wait "$lpid" 2> /dev/null
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
	sed -n 's/.*\(SMOKE \(FRAMES\|SOLVER\|MEM\|HITCH\|ERRORS\|ERROR\|WARN\|INVARIANT\|FAILED\)\)/\1/p' "$dir/logcat.txt" \
		| grep -v '^SMOKE HITCH' | head -n 80
	if [ -s "$dir/pss.txt" ]; then
		awk '{ if (!min || $2 < min) min = $2; if ($2 > max) max = $2; last = $2 }
			END { printf "PSS: thấp nhất %.0f MB, cao nhất %.0f MB, cuối %.0f MB (%d mẫu)\n", min/1024, max/1024, last/1024, NR }' \
			"$dir/pss.txt"
	fi
	printf '{"kind":"device","scen":"%s","seconds":%d,"rc":%d,"why":"%s"}\n' "$scen" "$sec" "$rc" "${why//\"/}" > "$dir/meta.json"
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
		run_one "$s" "$root/$s" "${extra[@]}"
		rc=$?
		if [ "$s" = G ] && [ "$rc" -eq 0 ]; then
			run_one G2 "$root/G2" "${extra[@]}"
			rc=$?
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
	*) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
