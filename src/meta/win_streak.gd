extends RefCounted
## Win Streak (design.md mục 7 "Win Streak"), theo ME_WinStreak của color-cube-match-puzzle. Logic thuần: giờ truyền
## vào (now: unix giây, tz: độ lệch múi giờ giây, giờ máy như Weekly Pass). Bản lưu s.streak.
##
## Lịch mỗi tuần (thứ Hai đến Chủ nhật): ngày trong Config.WIN_STREAK.active_days (thứ Sáu, Bảy, Chủ nhật) là Active,
## thắng level chính thì chuỗi +1; các ngày khác chỉ nhận quà (ClaimOnly; ngày Hidden của Unity cũng xử lý như vậy).
## Sự kiện bắt đầu ở ngày Active đầu tiên người chơi mở game trong tuần: chuỗi về 0, mốc đã nhận xoá. Chuỗi chỉ tăng sau
## khi bấm Start ở popup giới thiệu. Đứt chuỗi (thua, bỏ ván đã chạm) thì chuỗi tụt về mốc đã đạt gần nhất, không về 0,
## nên quà mốc đã đạt vẫn nhận được. Quà nhận thủ công từng mốc ở popup Main; chưa nhận tới khi sự kiện tuần sau bắt
## đầu thì mất.

const Config := preload("res://src/config.gd")
const Clock := preload("res://src/meta/clock.gd")
const Unlocks := preload("res://src/meta/unlocks.gd")

const DAY_SEC := 86400
## Unlocks feature key (Config.UNLOCK, Config.FEATURES).
const FEATURE := "win_streak"


static func empty() -> Dictionary:
	return {"week": -1, "started": false, "auto_shown": false, "count": 0, "before": 0, "claimed": []}


static func _w(s: Dictionary) -> Dictionary:
	if not (s.get("streak") is Dictionary):
		s["streak"] = empty()
	var w: Dictionary = s.streak
	for k in empty():
		if not w.has(k):
			w[k] = empty()[k]
	return w


## Mốc theo thứ tự tăng dần: [{streak, reward: {coins, items, inf_min}}].
static func milestones() -> Array:
	var out: Array = []
	for m in Config.WIN_STREAK.get("milestones", []):
		if m is Dictionary and int(m.get("streak", 0)) > 0:
			out.append(m)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.streak) < int(b.streak))
	return out


static func milestone_streaks() -> Array[int]:
	var out: Array[int] = []
	for m in milestones():
		out.append(int(m.streak))
	return out


static func reward_of(streak: int) -> Dictionary:
	for m in milestones():
		if int(m.streak) == streak:
			return (m.get("reward", {}) as Dictionary).duplicate(true)
	return {}


## Thứ Hai = 1 ... Chủ nhật = 7 (Chủ nhật là ngày cuối tuần, như GetCurrentWeekEndTime của Unity).
static func _iso_day(godot_weekday: int) -> int:
	return 7 if godot_weekday == 0 else godot_weekday


static func _active_iso() -> Array[int]:
	var out: Array[int] = []
	for d in Config.WIN_STREAK.get("active_days", []):
		var v := _iso_day(posmod(int(d), 7))
		if not out.has(v):
			out.append(v)
	out.sort()
	return out


## Số ngày (Clock.day_number) của thứ Hai đầu tuần chứa `now`: mã tuần của sự kiện.
static func week_id(now: int, tz: int) -> int:
	return Clock.day_number(now, tz) - (_iso_day(Clock.weekday(now, tz)) - 1)


static func is_active_day(now: int, tz: int) -> bool:
	return _active_iso().has(_iso_day(Clock.weekday(now, tz)))


## Người chơi thấy sự kiện (icon Home): đủ level mở và bật trong Config.FEATURES.
static func visible(level: int) -> bool:
	return Unlocks.is_open(FEATURE, level) and not _active_iso().is_empty()


## Đầu ngày Active đầu tiên của tuần chứa `week` (unix giây).
static func _week_first_active_at(week: int, tz: int) -> int:
	var days := _active_iso()
	var first := days[0] if not days.is_empty() else 5
	return (week + first - 1) * DAY_SEC - tz


## Giây còn lại tới hết ngày Active cuối của tuần này (23:59:59 + 1 giây). 0 khi không phải ngày Active.
static func ends_in(now: int, tz: int) -> int:
	if not is_active_day(now, tz):
		return 0
	var days := _active_iso()
	var last := days.back() as int
	var end_at := (week_id(now, tz) + last) * DAY_SEC - tz
	return maxi(0, end_at - now)


## Giây tới đầu ngày Active đầu tiên của lượt sau (GetNextEventStartTime: hôm nay là ngày đó thì lấy tuần sau).
static func next_start_in(now: int, tz: int) -> int:
	var days := _active_iso()
	var first := days[0] if not days.is_empty() else 5
	var today := _iso_day(Clock.weekday(now, tz))
	var until := first - today
	if until <= 0:
		until += 7
	var start_at := (Clock.day_number(now, tz) + until) * DAY_SEC - tz
	return maxi(0, start_at - now)


## Dữ liệu của lượt đã qua lúc lượt kế tiếp lẽ ra đã bắt đầu: quà chưa nhận mất (PlayStreakEvent của tuần mới).
static func _expired(w: Dictionary, now: int, tz: int) -> bool:
	if int(w.week) < 0:
		return false
	return now >= _week_first_active_at(int(w.week) + 7, tz)


## ValidateStreakEvent: ngày Active của tuần mới (đã đủ level) thì bắt đầu lượt mới; lượt cũ quá hạn thì xoá.
static func validate(s: Dictionary, now: int, tz: int, level: int) -> void:
	var w := _w(s)
	var week := week_id(now, tz)
	if visible(level) and is_active_day(now, tz) and int(w.week) != week:
		s["streak"] = empty()
		s.streak["week"] = week
	elif _expired(w, now, tz):
		s["streak"] = empty()


## Lượt của tuần này đang chạy (ngày Active). Tắt trong Config.FEATURES thì không chạy, kể cả lượt bắt đầu trước khi
## tắt: thắng không cộng, thua không tụt, không hỏi "Giữ chuỗi?".
static func is_running(s: Dictionary, now: int, tz: int) -> bool:
	return Unlocks.enabled(FEATURE) and is_active_day(now, tz) and int(_w(s).week) == week_id(now, tz)


static func started(s: Dictionary) -> bool:
	return bool(_w(s).started)


## CanIncreaseStreak và HasStartedWinStreakByStart: thắng được cộng, thua bị tụt.
static func counting(s: Dictionary, now: int, tz: int) -> bool:
	return is_running(s, now, tz) and started(s)


static func count(s: Dictionary) -> int:
	return int(_w(s).count)


## Bấm Start ở popup giới thiệu (MarkWinStreakInstructionStarted). False khi lượt không chạy.
static func start(s: Dictionary, now: int, tz: int) -> bool:
	if not is_running(s, now, tz):
		return false
	_w(s)["started"] = true
	return true


## Mốc đã đạt gần nhất (<= streak); 0 khi chưa đạt mốc nào.
static func floor_of(streak: int) -> int:
	var out := 0
	for m in milestone_streaks():
		if streak < m:
			break
		out = m
	return out


## UpgradeNewStreak. Trả true khi chuỗi tăng.
static func on_win(s: Dictionary, now: int, tz: int) -> bool:
	if not counting(s, now, tz):
		return false
	var w := _w(s)
	w["before"] = int(w.count)
	w["count"] = int(w.count) + 1
	return true


## UpdateMissStreakProgress: tụt về mốc đã đạt gần nhất. Trả true khi chuỗi giảm ("You lost your streak.").
static func on_miss(s: Dictionary, now: int, tz: int) -> bool:
	if not counting(s, now, tz):
		return false
	var w := _w(s)
	var low := floor_of(int(w.count))
	var lost := int(w.count) > low
	w["before"] = int(w.count)
	w["count"] = low
	return lost


## Bỏ ván hoặc thua lúc này thì chuỗi tụt (popup "Giữ chuỗi?" thay cho "Chơi tiếp chứ?").
static func at_stake(s: Dictionary, now: int, tz: int) -> bool:
	return counting(s, now, tz) and count(s) > floor_of(count(s))


static func claimed(s: Dictionary, streak: int) -> bool:
	return (_w(s).claimed as Array).has(streak)


## HasUnclaimedRewards: các mốc đã đạt mà chưa nhận, tăng dần.
static func claimable(s: Dictionary) -> Array[int]:
	var out: Array[int] = []
	if int(_w(s).week) < 0:
		return out
	for m in milestone_streaks():
		if count(s) >= m and not claimed(s, m):
			out.append(m)
	return out


## OnClaimMileStone: đánh dấu đã nhận và trả thưởng ({} khi chưa đạt hoặc đã nhận). Người gọi cộng thưởng.
static func claim(s: Dictionary, streak: int) -> Dictionary:
	if not claimable(s).has(streak):
		return {}
	(_w(s).claimed as Array).append(streak)
	return reward_of(streak)


## Popup mở khi bấm icon Home (ShowEvent): "intro" (lượt đang chạy, chưa bấm Start), "main", "end" (không còn quà
## và lượt không chạy), "" khi sự kiện ẩn. Ngày ClaimOnly mà còn quà thì vào main để nhận.
static func entry(s: Dictionary, now: int, tz: int, level: int) -> String:
	if not visible(level):
		return ""
	if not is_running(s, now, tz):
		return "main" if not claimable(s).is_empty() else "end"
	return "main" if started(s) else "intro"


## TryAutoShowInstructionOnUnlock: một lần mỗi lượt, khi lượt đang chạy mà chưa bấm Start.
static func should_auto_intro(s: Dictionary, now: int, tz: int, level: int) -> bool:
	return visible(level) and is_running(s, now, tz) and not started(s) and not bool(_w(s).auto_shown)


static func mark_auto_intro(s: Dictionary) -> void:
	_w(s)["auto_shown"] = true


## Dữ liệu cho UI: {visible, running, started, streak, floor (mốc đã đạt gần nhất), before, milestones: [{streak,
## reward, reached, claimed}], claimable, ends_in, next_in, entry}.
static func view(s: Dictionary, now: int, tz: int, level: int) -> Dictionary:
	var rows: Array = []
	var c := count(s)
	for m in milestones():
		var st := int(m.streak)
		rows.append({"streak": st, "reward": (m.get("reward", {}) as Dictionary).duplicate(true),
			"reached": c >= st, "claimed": claimed(s, st)})
	return {
		"visible": visible(level), "running": is_running(s, now, tz), "started": started(s), "streak": c,
		"floor": floor_of(c), "before": int(_w(s).before), "milestones": rows, "claimable": claimable(s).size(),
		"ends_in": ends_in(now, tz), "next_in": next_start_in(now, tz), "entry": entry(s, now, tz, level),
	}
