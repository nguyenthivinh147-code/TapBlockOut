extends RefCounted
## Win Streak logic (src/meta/win_streak.gd), the rules of ME_WinStreak in color-cube-match-puzzle.
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const SaveSchema := preload("res://src/meta/save_schema.gd")
const WinStreak := preload("res://src/meta/win_streak.gd")

const MON := 1699833600  # 2023-11-13 00:00 UTC, Monday
const FRI := MON + 4 * 86400
const SUN := MON + 6 * 86400
const H := 3600
const D := 86400
const LV := 45


func _s() -> Dictionary:
	Config.reset()
	# Win Streak is switched off in Config.FEATURES; these tests cover the feature itself.
	Config.FEATURES.win_streak = true
	return SaveSchema.defaults()


## A running event that the player started on Friday.
func _started(s: Dictionary) -> void:
	WinStreak.validate(s, FRI + H, 0, LV)
	WinStreak.start(s, FRI + H, 0)


func test_schedule(t: T) -> void:
	_s()
	t.ok(not WinStreak.is_active_day(MON, 0), "thứ Hai chỉ nhận quà")
	t.ok(not WinStreak.is_active_day(MON + 3 * D, 0), "thứ Năm chỉ nhận quà")
	t.ok(WinStreak.is_active_day(FRI, 0), "thứ Sáu Active")
	t.ok(WinStreak.is_active_day(SUN + 23 * H, 0), "Chủ nhật 23:00 Active")
	t.eq(WinStreak.week_id(SUN + 23 * H, 0), WinStreak.week_id(MON, 0), "cùng tuần thứ Hai -> Chủ nhật")
	t.ok(WinStreak.week_id(SUN + D, 0) != WinStreak.week_id(MON, 0), "thứ Hai sau là tuần mới")
	t.eq(WinStreak.ends_in(FRI, 0), 3 * D, "hết lúc qua Chủ nhật")
	t.eq(WinStreak.ends_in(MON, 0), 0, "ngày nhận quà không có hạn")
	t.eq(WinStreak.next_start_in(MON, 0), 4 * D, "thứ Hai tới thứ Sáu")
	t.eq(WinStreak.next_start_in(FRI + H, 0), 7 * D - H, "đang thứ Sáu thì lượt sau là tuần sau")
	t.eq(WinStreak.ends_in(FRI - 7 * H, 7 * H), 3 * D, "theo giờ máy")
	t.ok(WinStreak.is_active_day(FRI - 7 * H, 7 * H), "0:00 giờ máy thứ Sáu")


func test_milestones(t: T) -> void:
	_s()
	t.eq(WinStreak.milestone_streaks(), [2, 4, 7, 10, 14, 18, 23, 28, 34, 40] as Array[int], "10 mốc như Unity")
	t.eq(WinStreak.floor_of(0), 0, "chưa đạt mốc")
	t.eq(WinStreak.floor_of(3), 2, "tụt về 2")
	t.eq(WinStreak.floor_of(7), 7, "đúng mốc")
	t.eq(WinStreak.floor_of(99), 40, "quá mốc cuối")
	t.eq(WinStreak.reward_of(2), {"inf_min": 15}, "mốc 2: 15 phút mạng vô hạn")


func test_start_needs_active_day_and_level(t: T) -> void:
	var s := _s()
	t.eq(WinStreak.entry(s, FRI, 0, LV - 1), "", "chưa đủ level thì ẩn")
	WinStreak.validate(s, FRI, 0, LV - 1)
	t.eq(int(s.streak.week), -1, "chưa đủ level thì không bắt đầu")
	WinStreak.validate(s, MON, 0, LV)
	t.eq(int(s.streak.week), -1, "ngày nhận quà không bắt đầu lượt")
	t.eq(WinStreak.entry(s, MON, 0, LV), "end", "chưa có lượt: popup End")
	WinStreak.validate(s, FRI, 0, LV)
	t.eq(int(s.streak.week), WinStreak.week_id(FRI, 0), "thứ Sáu bắt đầu")
	t.eq(WinStreak.entry(s, FRI, 0, LV), "intro", "chưa bấm Start")
	t.ok(WinStreak.should_auto_intro(s, FRI, 0, LV), "tự hiện giới thiệu")
	WinStreak.mark_auto_intro(s)
	t.ok(not WinStreak.should_auto_intro(s, FRI, 0, LV), "tự hiện một lần")
	t.ok(not WinStreak.on_win(s, FRI, 0), "chưa Start thì thắng không cộng")
	t.ok(WinStreak.start(s, FRI, 0), "Start")
	t.eq(WinStreak.entry(s, FRI, 0, LV), "main", "đã Start thì vào Main")


func test_win_and_miss(t: T) -> void:
	var s := _s()
	_started(s)
	for i in 3:
		t.ok(WinStreak.on_win(s, FRI + 2 * H, 0), "thắng %d" % (i + 1))
	t.eq(WinStreak.count(s), 3, "chuỗi 3")
	t.eq(int(s.streak.before), 2, "chuỗi trước đó")
	t.ok(WinStreak.at_stake(s, FRI + 2 * H, 0), "3 > mốc 2: bỏ ván thì tụt")
	t.ok(WinStreak.on_miss(s, FRI + 3 * H, 0), "thua thì báo mất chuỗi")
	t.eq(WinStreak.count(s), 2, "tụt về mốc 2, không về 0")
	t.ok(not WinStreak.at_stake(s, FRI + 3 * H, 0), "đúng mốc thì không mất gì")
	t.ok(not WinStreak.on_miss(s, FRI + 3 * H, 0), "thua lần nữa không tụt thêm")
	t.eq(WinStreak.count(s), 2, "giữ mốc 2")


func test_claim(t: T) -> void:
	var s := _s()
	_started(s)
	for i in 5:
		WinStreak.on_win(s, FRI + 2 * H, 0)
	t.eq(WinStreak.claimable(s), [2, 4] as Array[int], "mốc 2 và 4 nhận được")
	t.eq(WinStreak.claim(s, 7), {}, "chưa đạt mốc 7")
	t.eq(WinStreak.claim(s, 4), {"items": {"hint": 1}}, "mốc 4: 1 Gợi ý")
	t.eq(WinStreak.claim(s, 4), {}, "mỗi mốc nhận một lần")
	WinStreak.on_miss(s, FRI + 3 * H, 0)
	t.eq(WinStreak.claimable(s), [2] as Array[int], "đứt chuỗi vẫn nhận được mốc đã đạt")


func test_claim_only_days(t: T) -> void:
	var s := _s()
	_started(s)
	WinStreak.on_win(s, FRI + 2 * H, 0)
	WinStreak.on_win(s, FRI + 2 * H, 0)
	var mon := SUN + D + H
	WinStreak.validate(s, mon, 0, LV)
	t.eq(WinStreak.count(s), 2, "thứ Hai giữ dữ liệu")
	t.ok(not WinStreak.on_win(s, mon, 0), "ngày nhận quà không cộng")
	t.ok(not WinStreak.on_miss(s, mon, 0), "ngày nhận quà không tụt")
	t.eq(WinStreak.entry(s, mon, 0, LV), "main", "còn quà thì vào Main")
	WinStreak.claim(s, 2)
	t.eq(WinStreak.entry(s, mon, 0, LV), "end", "hết quà thì popup End")


func test_new_week_resets(t: T) -> void:
	var s := _s()
	_started(s)
	WinStreak.on_win(s, FRI + 2 * H, 0)
	WinStreak.on_win(s, FRI + 2 * H, 0)
	var next_fri := FRI + 7 * D + H
	WinStreak.validate(s, next_fri, 0, LV)
	t.eq(WinStreak.count(s), 0, "tuần mới về 0")
	t.eq(WinStreak.claimable(s), [] as Array[int], "quà chưa nhận mất")
	t.ok(not WinStreak.started(s), "phải bấm Start lại")
	# Not opened on the next event's Active days: the old event expires anyway.
	var s2 := _s()
	_started(s2)
	WinStreak.on_win(s2, FRI + 2 * H, 0)
	WinStreak.on_win(s2, FRI + 2 * H, 0)
	WinStreak.validate(s2, FRI + 10 * D, 0, LV)
	t.eq(WinStreak.claimable(s2), [] as Array[int], "qua lượt sau thì quà cũ mất")


## Config.FEATURES.win_streak off (the shipped default since 2026-11-11): no event at any level, and a save whose event
## was started before the switch neither counts wins nor drops on a miss, so no "Keep your streak?" either.
func test_switched_off(t: T) -> void:
	var s := _s()
	_started(s)
	for i in 3:
		WinStreak.on_win(s, FRI + 2 * H, 0)
	Config.reset()
	t.eq(bool(Config.FEATURES.get("win_streak", true)), false, "mặc định tắt")
	t.ok(not WinStreak.visible(LV + 500), "không hiện ở level nào")
	t.eq(WinStreak.entry(s, FRI + 2 * H, 0, LV), "", "icon Home không mở popup")
	t.ok(not WinStreak.is_running(s, FRI + 2 * H, 0), "lượt cũ không chạy")
	t.ok(not WinStreak.at_stake(s, FRI + 2 * H, 0), "không hỏi Giữ chuỗi")
	t.ok(not WinStreak.on_win(s, FRI + 2 * H, 0), "thắng không cộng")
	t.ok(not WinStreak.on_miss(s, FRI + 2 * H, 0), "thua không tụt")
	t.eq(WinStreak.count(s), 3, "chuỗi giữ nguyên")
	t.ok(not WinStreak.start(s, FRI + 2 * H, 0), "không Start được")
	var fresh := SaveSchema.defaults()
	WinStreak.validate(fresh, FRI + 7 * D + H, 0, LV)
	t.eq(int(fresh.streak.week), -1, "ngày Active tuần sau không bắt đầu lượt")
	t.ok(not WinStreak.should_auto_intro(fresh, FRI + 7 * D + H, 0, LV), "không tự mở giới thiệu")
	Config.FEATURES.win_streak = true
	t.ok(WinStreak.on_win(s, FRI + 2 * H, 0), "bật lại giữa lượt thì đếm tiếp")
	t.eq(WinStreak.count(s), 4, "chuỗi 4")
	Config.reset()


func test_save_defaults(t: T) -> void:
	var s := _s()
	t.eq(s.streak, WinStreak.empty(), "s.streak mặc định")
	var merged := SaveSchema.merge_defaults({"level": 3})
	t.eq(merged.streak, WinStreak.empty(), "bản lưu cũ có s.streak")
