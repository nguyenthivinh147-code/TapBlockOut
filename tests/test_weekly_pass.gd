extends RefCounted
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const SaveSchema := preload("res://src/meta/save_schema.gd")
const WeeklyPass := preload("res://src/meta/weekly_pass.gd")
const SaveStore := preload("res://src/meta/save_store.gd")
const Unlocks := preload("res://src/meta/unlocks.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")
const WeeklyPassUi := preload("res://src/ui/weekly_pass.gd")

const MON := 1699833600  # 2023-11-13 00:00 UTC, thứ Hai
const H := 3600
const D := 86400


func test_window_and_state(t: T) -> void:
	Config.reset()
	t.eq(WeeklyPass.week_start(MON + 3 * D, 0), MON, "đầu tuần")
	t.eq(WeeklyPass.week_start(MON + 3 * D, 7 * H), MON - 7 * H, "đầu tuần theo múi giờ")
	t.eq(WeeklyPass.state(MON + 3 * H, 0, true), WeeklyPass.WAITING, "thứ Hai 03:00 là Waiting")
	t.eq(WeeklyPass.state(MON + 6 * H, 0, true), WeeklyPass.ACTIVE, "thứ Hai 06:00 là Active")
	t.eq(WeeklyPass.state(MON + 7 * D - 1, 0, true), WeeklyPass.ACTIVE, "Chủ nhật 23:59 vẫn Active")
	t.eq(WeeklyPass.state(MON + 7 * D, 0, true), WeeklyPass.WAITING, "thứ Hai tuần sau là Waiting")
	t.ok(WeeklyPass.window(MON + 3 * H, 0).cycle != WeeklyPass.window(MON - 1, 0).cycle, "Waiting thuộc chu kỳ mới")
	t.eq(WeeklyPass.window(MON + 6 * H, 0).cycle, WeeklyPass.window(MON + 7 * D - 1, 0).cycle, "cùng chu kỳ")
	t.eq(WeeklyPass.seconds_left(MON + 3 * H, 0, WeeklyPass.WAITING), 3 * H, "đếm ngược Waiting")
	t.eq(WeeklyPass.seconds_left(MON + 6 * H, 0, WeeklyPass.ACTIVE), 7 * D - 6 * H, "đếm ngược Active")


func test_locked(t: T) -> void:
	Config.reset()
	t.eq(WeeklyPass.state(MON + D, 0, false), WeeklyPass.LOCKED, "chưa mở khoá")
	Config.WEEKLY["enabled"] = false
	t.eq(WeeklyPass.state(MON + D, 0, true), WeeklyPass.LOCKED, "tắt cấu hình")
	Config.reset()
	Config.WEEKLY["sku"] = "gold_pack_1"
	t.eq(WeeklyPass.state(MON + D, 0, true), WeeklyPass.LOCKED, "SKU không phải weekly_vip")
	Config.WEEKLY["sku"] = "khong_co"
	t.eq(WeeklyPass.state(MON + D, 0, true), WeeklyPass.LOCKED, "SKU không tồn tại")
	Config.reset()


func test_points(t: T) -> void:
	Config.reset()
	var s := SaveSchema.defaults()
	t.eq(WeeklyPass.add_points(s, WeeklyPass.ACTIVE, "hard"), 0, "chưa xem tutorial thì không cộng")
	WeeklyPass.mark_tutorial_seen(s)
	t.eq(WeeklyPass.add_points(s, WeeklyPass.ACTIVE, ""), 1, "normal +1")
	t.eq(WeeklyPass.add_points(s, WeeklyPass.ACTIVE, "hard"), 3, "hard +3")
	t.eq(WeeklyPass.add_points(s, WeeklyPass.ACTIVE, "very_hard"), 5, "very hard +5")
	t.eq(WeeklyPass.add_points(s, WeeklyPass.WAITING, "hard"), 0, "Waiting không cộng")
	t.eq(WeeklyPass.add_points(s, WeeklyPass.LOCKED, ""), 0, "Locked không cộng")
	t.eq(WeeklyPass.points(s), 9, "tổng")


func test_main_claims(t: T) -> void:
	Config.reset()
	var s := SaveSchema.defaults()
	t.eq(WeeklyPass.free_claimable(s, 0), true, "mốc khởi đầu (0 điểm) nhận được ngay")
	t.eq(WeeklyPass.claimable_count(s), 1, "mới vào chỉ có thưởng khởi đầu")
	s.weekly.points = 8  # đạt mốc 0, 3 và 8 key
	t.eq(WeeklyPass.free_claimable(s, 2), true, "free mốc 8 đủ điểm")
	t.eq(WeeklyPass.free_claimable(s, 3), false, "mốc 15 chưa đủ")
	t.eq(WeeklyPass.vip_claimable(s, 0), false, "chưa VIP")
	t.eq(WeeklyPass.claimable_count(s), 3, "3 free (mốc 0, 3, 8)")
	var r := WeeklyPass.claim_free(s, 0)
	t.eq(r.coins, 0, "mốc khởi đầu không có gold")
	t.eq(r.inf_min, 15, "thưởng free mốc khởi đầu: 15 phút mạng vô hạn")
	t.eq(WeeklyPass.claim_free(s, 0), {}, "không nhận hai lần")
	t.eq(WeeklyPass.claim_vip(s, 0), {}, "VIP khoá khi chưa mua")
	WeeklyPass.on_vip_purchased(s)
	t.eq(WeeklyPass.claim_vip(s, 0).coins, 150, "thưởng VIP mốc khởi đầu")
	var all := WeeklyPass.claim_all_main(s)
	t.eq(all.count, 4, "còn free mốc 3 và 8, VIP mốc 3 và 8")
	t.eq(all.reward.coins, 600, "free 100 + VIP 200 + VIP 300")
	t.eq(all.reward.items.hint, 2, "hint free + VIP")
	t.eq(all.reward.inf_min, 30, "VIP mốc 3 key: 30 phút mạng vô hạn")
	t.eq(WeeklyPass.claimable_count(s), 0, "hết")


func test_bonus_bank(t: T) -> void:
	Config.reset()
	var s := SaveSchema.defaults()
	var last := WeeklyPass.last_points()
	t.eq(last, 130, "mốc cuối")
	s.weekly.points = last + 14
	t.eq(WeeklyPass.bank_slots(s), 0, "14 key thừa chưa đủ")
	s.weekly.points = last + 15 * 3 + 2
	t.eq(WeeklyPass.bank_slots(s), 3, "3 mốc bank")
	t.eq(WeeklyPass.bank_unlocked(s), false, "chưa VIP")
	WeeklyPass.on_vip_purchased(s)
	t.eq(WeeklyPass.bank_unlocked(s), false, "chưa xem End popup")
	WeeklyPass.mark_end_seen(s)
	t.eq(WeeklyPass.bank_unlocked(s), true, "mở")
	t.eq(WeeklyPass.claim_bank(s, 3).is_empty(), true, "mốc 3 chưa đạt")
	t.eq(WeeklyPass.claim_bank(s, 0).coins, 400, "thưởng bank")
	t.eq(WeeklyPass.claim_bank(s, 0).is_empty(), true, "không nhận hai lần")
	t.eq(WeeklyPass.claim_all_bank(s).count, 2, "2 mốc còn lại")
	s.weekly.points = last + 15 * 99
	t.eq(WeeklyPass.bank_slots(s), 10, "tối đa 10 mốc")


func test_end_seen_needs_points(t: T) -> void:
	Config.reset()
	var s := SaveSchema.defaults()
	s.weekly.points = 50
	WeeklyPass.mark_end_seen(s)
	t.eq(s.weekly.end_seen, false, "chưa tới mốc cuối thì chưa tính là đã xem")


func test_refresh_vip_settles(t: T) -> void:
	Config.reset()
	var s := SaveSchema.defaults()
	var first := WeeklyPass.refresh(s, MON + D, 0)
	t.eq(first.settled, false, "lần đầu chỉ đặt chu kỳ")
	WeeklyPass.on_vip_purchased(s)
	s.weekly.points = 10
	WeeklyPass.claim_free(s, 0)  # đã nhận một phần
	t.eq(WeeklyPass.refresh(s, MON + 2 * D, 0).settled, false, "cùng chu kỳ")
	var r := WeeklyPass.refresh(s, MON + 8 * D, 0)
	t.eq(r.settled, true, "sang mùa")
	# đạt mốc 0, 3, 8 key; free mốc 0 đã nhận. Còn: free mốc 3 (100) và 8 (hint),
	# VIP mốc 0 (150), 3 (200), 8 (300 + hint)
	t.eq(r.reward.coins, 750, "VIP nhận thưởng tồn")
	t.eq(r.reward.inf_min, 30, "mạng vô hạn tồn")
	t.eq(r.reward.items.hint, 2, "hint tồn")
	t.eq(s.weekly.points, 0, "reset điểm")
	t.eq(s.weekly.vip, false, "reset VIP")
	t.eq(s.weekly.claimed_free.size(), 0, "reset danh sách đã nhận")
	var end := WeeklyPass.take_pending_end(s)
	t.eq(end.vip, true, "popup cuối mùa VIP")
	t.eq(end.points, 10, "điểm mùa cũ")
	t.eq(WeeklyPass.take_pending_end(s), {}, "popup chỉ một lần")


func test_refresh_free_loses_unclaimed(t: T) -> void:
	Config.reset()
	var s := SaveSchema.defaults()
	WeeklyPass.refresh(s, MON + D, 0)
	s.weekly.points = 20
	var r := WeeklyPass.refresh(s, MON + 8 * D, 0)
	t.eq(r.settled, true, "chốt mùa")
	t.eq(r.reward.coins, 0, "không VIP không nhận thưởng tồn")
	t.eq(WeeklyPass.take_pending_end(s).vip, false, "popup cuối mùa free")
	t.eq(s.weekly.points, 0, "reset")
	var r2 := WeeklyPass.refresh(s, MON + 15 * D, 0)
	t.eq(r2.settled, false, "mùa trống không chốt")
	t.eq(WeeklyPass.take_pending_end(s), {}, "không popup")


func test_heart_bonus(t: T) -> void:
	Config.reset()
	var s := SaveSchema.defaults()
	t.eq(WeeklyPass.heart_bonus(s, WeeklyPass.ACTIVE), 0, "chưa VIP")
	WeeklyPass.on_vip_purchased(s)
	t.eq(WeeklyPass.heart_bonus(s, WeeklyPass.ACTIVE), 3, "VIP Active +3")
	t.eq(WeeklyPass.heart_bonus(s, WeeklyPass.WAITING), 0, "Waiting hết thưởng")
	t.eq(WeeklyPass.heart_bonus(s, WeeklyPass.LOCKED), 0, "Locked")


func test_tutorial_flag_survives_season(t: T) -> void:
	Config.reset()
	var s := SaveSchema.defaults()
	t.eq(WeeklyPass.tutorial_seen(s), false, "mặc định chưa xem")
	WeeklyPass.refresh(s, MON + D, 0)
	WeeklyPass.mark_tutorial_seen(s)
	t.eq(WeeklyPass.tutorial_seen(s), true, "đã đánh dấu")
	s.weekly.points = 20
	WeeklyPass.refresh(s, MON + 8 * D, 0)  # sang mùa mới
	t.eq(s.weekly.points, 0, "reset điểm")
	t.eq(WeeklyPass.tutorial_seen(s), true, "cờ tutorial không reset theo mùa")


func test_tutorial_row(t: T) -> void:
	Config.reset()
	var s := SaveSchema.defaults()
	t.eq(WeeklyPass.tutorial_row(s), 0, "mới vào: mốc khởi đầu")
	WeeklyPass.claim_free(s, 0)
	t.eq(WeeklyPass.tutorial_row(s), 1, "mốc đầu tiên chưa nhận free")
	s.weekly.points = 8
	WeeklyPass.claim_all_main(s)
	for i in WeeklyPass.main_milestones().size():
		if not WeeklyPass._has(s.weekly.claimed_free, i):
			s.weekly.claimed_free.append(i)
	t.eq(WeeklyPass.tutorial_row(s), WeeklyPass.main_milestones().size() - 1, "nhận hết thì mốc cuối")


func test_progress_ratio(t: T) -> void:
	Config.reset()
	var s := SaveSchema.defaults()
	t.near(WeeklyPass.progress_ratio(s), 0.0, 0.0001, "TC_CA_WP_046 0 key -> 0")
	s.weekly.points = 1  # mốc kế là 3
	t.near(WeeklyPass.progress_ratio(s), 1.0 / 3.0, 0.001, "TC_CA_WP_046 1 key -> 0,333 (1/3 tới mốc 3)")
	s.weekly.points = 3  # vừa chạm mốc 3, mốc kế là 8
	t.near(WeeklyPass.progress_ratio(s), 0.0, 0.0001, "vừa chạm mốc, bắt đầu đoạn mới")
	s.weekly.points = 5
	t.near(WeeklyPass.progress_ratio(s), 2.0 / 5.0, 0.0001, "2/5 tới mốc 8")
	s.weekly.points = WeeklyPass.last_points() + 7
	t.near(WeeklyPass.progress_ratio(s), 1.0, 0.0001, "qua mốc cuối")
	# TC_CA_WP_046: số key theo INPUT, tỉ lệ theo EXPECTED RESULT (Test Data C5).
	for c in [[4, 0.2], [8, 0.0], [129, 0.96], [130, 1.0], [300, 1.0]]:
		s.weekly.points = int(c[0])
		t.near(WeeklyPass.progress_ratio(s), float(c[1]), 0.0001, "TC_CA_WP_046 %d key -> %s" % [int(c[0]), str(c[1])])


# --- Test case tests/cases/WP.csv (AUTO = unit:test_weekly_pass). Số kỳ vọng chép thẳng từ cột EXPECTED RESULT và
# Test Data của output/testcase-weekly-pass/WP_testcases.xlsx, không tính lại bằng Config hay hàm của game. ---

## Thời điểm chuẩn của case: T6 15/01/2027 08:00 UTC, mùa W20829 Active, còn 230400 giây (Test Data C1).
const TS := 1800000000
const DIR := "user://test_weekly_pass"

## Test Data C2: [key, free gold, free Gợi ý, free +3 Move, free Phá khối, free phút,
## VIP gold, VIP Gợi ý, VIP +3 Move, VIP Phá khối, VIP phút] của mốc 0..10.
const C2 := [
	[0, 0, 0, 0, 0, 15, 150, 0, 0, 0, 0],
	[3, 100, 0, 0, 0, 0, 200, 0, 0, 0, 30],
	[8, 0, 1, 0, 0, 0, 300, 1, 0, 0, 0],
	[15, 150, 0, 0, 0, 0, 400, 0, 0, 0, 0],
	[25, 0, 0, 1, 0, 0, 0, 0, 2, 0, 0],
	[38, 200, 0, 0, 0, 0, 600, 0, 0, 0, 0],
	[52, 0, 0, 0, 1, 0, 0, 0, 0, 2, 0],
	[68, 300, 0, 0, 0, 0, 800, 0, 0, 0, 0],
	[85, 0, 1, 1, 0, 0, 500, 2, 2, 0, 0],
	[105, 400, 0, 0, 0, 0, 1000, 0, 0, 0, 0],
	[130, 500, 0, 0, 1, 0, 2000, 0, 0, 2, 0],
]


## Store giả ghi lại mỗi lần finish và cho đặt sẵn đơn treo (app chết sau khi store trừ tiền).
class FakeIap extends MockIap:
	var finished: Array = []

	func add_pending(p: Dictionary) -> void:
		_pending.append(p.duplicate())

	func finish(p: Dictionary, consumable: bool) -> void:
		finished.append({"token": str(p.get("token", "")), "consumable": consumable})
		super.finish(p, consumable)


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _p() -> Node:
	return _root().get_node("Platform")


## Game sạch như bản phát hành (demo_override 0), store giả mới, giờ giả `now`, tz 0.
func _g(level: int = 27, now: int = TS) -> Node:
	DirAccess.make_dir_recursive_absolute(DIR)
	var g: Node = _root().get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	Config.demo_override = 0
	var p := _p()
	p.iap = FakeIap.new()
	p.save.cloud_json = ""
	g.test_tz = 0
	g.test_now = now
	g.s.level = level
	return g


## Chơi thắng bằng solver rồi gọi on_level_won.
func _win(g: Node, attempt: Dictionary) -> Dictionary:
	var b: RefCounted = attempt.board
	var guard := 0
	while not b.is_won() and guard < 300:
		var id: String = b.hint()
		if id == "":
			break
		g.tap(attempt, id)
		guard += 1
	return g.on_level_won(attempt)


## Đơn weekly_pass đã trả tiền, như Platform.pending() trả về.
func _vip_order(token: String) -> Dictionary:
	return {"status": "ok", "sku": "weekly_pass", "token": token, "order_id": "o_" + token}


## [gold, Gợi ý, +3 Move, Phá khối, phút mạng vô hạn] của một thưởng {coins, items, inf_min}.
func _flat(r: Dictionary) -> Array:
	var items: Dictionary = r.get("items", {})
	return [int(r.get("coins", 0)), int(items.get("hint", 0)), int(items.get("move", 0)),
		int(items.get("smash", 0)), int(r.get("inf_min", 0))]


## Đợi khung hình tới khi `cond` đúng hay hết `ms` mili giây giờ thật. Không dùng create_timer: test trước (như
## test_static_check) chặn vòng lặp vài giây trong một khung, khung sau có delta lớn nên SceneTreeTimer hết ngay,
## trước khi Timer của Game (WEEKLY_TICK_SEC) kịp chạy.
func _wait(cond: Callable, ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while not cond.call() and Time.get_ticks_msec() < deadline:
		await _root().get_tree().process_frame
	return cond.call()


func _open(path: String) -> Control:
	var node := (load(path) as PackedScene).instantiate() as Control
	_root().add_child(node)
	node.setup({})
	return node


func _weekly_buys(g: Node) -> int:
	var n := 0
	for e in g.s.buys:
		if e is Dictionary and str(e.get("sku", "")) == "weekly_pass":
			n += 1
	return n


func test_demo_never_unlocks(t: T) -> void:
	var g := _g(20)
	Config.demo_override = 1
	g.s.weekly.tut_seen = true
	var a: Dictionary = g.start_attempt()
	t.ok(not a.is_empty(), "TC_CA_WP_003 dựng được lượt L20 của bản demo")
	g.s.level = 21
	t.eq(g.weekly_unlock_level(), 0, "TC_CA_WP_003 weekly_unlock_level() = 0 (L1-20 không có level HARD thứ 2)")
	t.eq(g.weekly_state(), "locked", "TC_CA_WP_003 weekly_state() = locked")
	t.eq(g.weekly_view().unlocked, false, "TC_CA_WP_003 weekly_view().unlocked = false")
	if not a.is_empty():
		var r := _win(g, a)
		t.eq(int(r.get("weekly_points", -1)), 0, "TC_CA_WP_003 on_level_won L20: weekly_points = 0")
	t.eq(int(g.s.weekly.points), 0, "TC_CA_WP_003 s.weekly.points giữ 0")
	Config.reset()


func test_boundary_sunday_to_monday(t: T) -> void:
	Config.reset()
	var last := 1800230399  # CN 17/01/2027 23:59:59
	var mon := 1800230400  # T2 18/01/2027 00:00:00
	var st := WeeklyPass.state(last, 0, true)
	t.eq(st, "active", "TC_CA_WP_007 1800230399: state active")
	t.eq(WeeklyPass.seconds_left(last, 0, st), 1, "TC_CA_WP_007 1800230399: seconds_left = 1")
	t.eq(WeeklyPass.window(last, 0).cycle, "W20829", "TC_CA_WP_007 1800230399: cycle W20829")
	st = WeeklyPass.state(mon, 0, true)
	t.eq(st, "waiting", "TC_CA_WP_007 1800230400: state waiting")
	t.eq(WeeklyPass.seconds_left(mon, 0, st), 21600, "TC_CA_WP_007 1800230400: seconds_left = 21600")
	t.eq(WeeklyPass.window(mon, 0).cycle, "W20836", "TC_CA_WP_007 1800230400: cycle W20836")
	var s := SaveSchema.defaults()
	s.weekly.cycle = "W20829"
	s.weekly.points = 5
	var r := WeeklyPass.refresh(s, mon, 0)
	t.eq(r.settled, true, "TC_CA_WP_007 refresh ở 1800230400: settled = true")
	t.eq(s.weekly.cycle, "W20836", "TC_CA_WP_007 refresh: s.weekly.cycle = W20836")
	t.eq(int(s.weekly.points), 0, "TC_CA_WP_007 refresh: points = 0")
	t.eq(int(s.weekly.pending_end.get("points", -1)), 5, "TC_CA_WP_007 refresh: pending_end.points = 5")


func test_boundary_monday_open(t: T) -> void:
	Config.reset()
	var s := SaveSchema.defaults()
	WeeklyPass.refresh(s, 1800230400, 0)  # mùa W20836 bắt đầu (Waiting)
	s.weekly.points = 2
	s.weekly.claimed_free = [0]
	var st := WeeklyPass.state(1800251999, 0, true)
	t.eq(st, "waiting", "TC_CA_WP_008 1800251999: state waiting")
	t.eq(WeeklyPass.seconds_left(1800251999, 0, st), 1, "TC_CA_WP_008 1800251999: seconds_left = 1")
	t.eq(WeeklyPassUi.fmt_time(1), "0:00:01", "TC_CA_WP_008 1 giây hiện \"0:00:01\"")
	st = WeeklyPass.state(1800252000, 0, true)
	t.eq(st, "active", "TC_CA_WP_008 1800252000: state active")
	t.eq(WeeklyPass.seconds_left(1800252000, 0, st), 583200, "TC_CA_WP_008 1800252000: seconds_left = 583200")
	t.eq(WeeklyPassUi.fmt_time(583200), "6d 18h", "TC_CA_WP_008 583200 giây hiện \"6d 18h\"")
	var r := WeeklyPass.refresh(s, 1800252000, 0)
	t.eq(r.settled, false, "TC_CA_WP_008 refresh ở 06:00:00: settled = false")
	t.eq(s.weekly.cycle, "W20836", "TC_CA_WP_008 cycle giữ W20836")
	t.eq(int(s.weekly.points), 2, "TC_CA_WP_008 points giữ 2")
	t.eq(s.weekly.claimed_free, [0], "TC_CA_WP_008 claimed_free giữ [0]")


func test_timezone_local_week(t: T) -> void:
	Config.reset()
	var sun := 1800205200  # CN 17/01/2027 17:00 UTC
	t.eq(WeeklyPass.state(sun, 0, true), "active", "TC_CA_WP_010 tz 0: active (CN 17:00 giờ máy)")
	t.eq(WeeklyPass.window(sun, 0).cycle, "W20829", "TC_CA_WP_010 tz 0: cycle W20829")
	var st := WeeklyPass.state(sun, 25200, true)
	t.eq(st, "waiting", "TC_CA_WP_010 tz +25200: waiting (T2 00:00 giờ máy)")
	t.eq(WeeklyPass.seconds_left(sun, 25200, st), 21600, "TC_CA_WP_010 tz +25200: seconds_left = 21600")
	t.eq(WeeklyPass.window(sun, 25200).cycle, "W20836", "TC_CA_WP_010 tz +25200: cycle W20836")
	var s := SaveSchema.defaults()
	s.weekly.cycle = "W20829"
	s.weekly.points = 6
	var wed := 1799841600  # T4 13/01/2027 12:00 UTC
	t.eq(WeeklyPass.refresh(s, wed, 0).settled, false, "TC_CA_WP_010 T4 tz 0: refresh settled = false")
	t.eq(WeeklyPass.refresh(s, wed, 3600).settled, false, "TC_CA_WP_010 T4 đổi tz 0 -> +3600: settled = false")
	t.eq(s.weekly.cycle, "W20829", "TC_CA_WP_010 đổi tz giữa tuần: cycle giữ W20829")
	t.eq(int(s.weekly.points), 6, "TC_CA_WP_010 đổi tz giữa tuần: points giữ 6")


func test_year_end_and_leap_week(t: T) -> void:
	Config.reset()
	var w := WeeklyPass.window(1798437600, 0)  # T2 28/12/2026 06:00
	t.eq(int(w.open_at), 1798437600, "TC_CA_WP_011 mùa T2 28/12/2026: open_at 1798437600")
	t.eq(int(w.end), 1799020800, "TC_CA_WP_011 mùa T2 28/12/2026: end 1799020800 (T2 04/01/2027 00:00)")
	t.eq(w.cycle, "W20815", "TC_CA_WP_011 mùa T2 28/12/2026: cycle W20815")
	for ts in [1798761599, 1798761600]:  # 31/12/2026 23:59:59 và 01/01/2027 00:00:00
		t.eq(WeeklyPass.window(ts, 0).cycle, "W20815", "TC_CA_WP_011 %d: cycle W20815" % ts)
		t.eq(WeeklyPass.state(ts, 0, true), "active", "TC_CA_WP_011 %d: state active" % ts)
	var s := SaveSchema.defaults()
	WeeklyPass.refresh(s, 1798761599, 0)
	t.eq(WeeklyPass.refresh(s, 1798761600, 0).settled, false, "TC_CA_WP_011 refresh lần hai qua 01/01: settled = false")
	var leap := WeeklyPass.window(1835395200, 0)  # T3 29/02/2028
	t.eq(leap.cycle, "W21242", "TC_CA_WP_011 29/02/2028: cycle W21242")
	t.eq(int(leap.end), 1835913600, "TC_CA_WP_011 29/02/2028: end 1835913600 (T2 06/03/2028 00:00)")
	t.eq(int(leap.end) - int(leap.start), 604800, "TC_CA_WP_011 29/02/2028: end - start = 604800")


## Lùi giờ máy về tuần trước (OQ-05 chốt 2026-11-13: như quà 28 ngày, không reset mùa). Trước khi sửa,
## WeeklyPass.refresh chốt và reset mùa mỗi khi cycle khác, kể cả cycle cũ hơn: chỉnh giờ tới lui là nhận lại mốc 0.
func test_clock_back_keeps_new_season(t: T) -> void:
	var g := _g(27, 1800252001)
	g.weekly_refresh()  # mùa W20836
	g.s.weekly.claimed_free = [0]
	g.s.weekly.points = 2
	g.s.weekly.tut_seen = true
	g.s.lives.inf_until = 1800252901
	t.eq(g.s.weekly.cycle, "W20836", "TC_CA_WP_012 dữ liệu: mùa W20836")
	g.test_now = TS  # lùi giờ về tuần W20829
	g.weekly_refresh()
	t.eq(g.s.weekly.cycle, "W20836", "TC_CA_WP_012 lúc giờ lùi: cycle giữ W20836")
	t.eq(int(g.s.weekly.points), 2, "TC_CA_WP_012 lúc giờ lùi: points giữ 2")
	t.eq(g.s.weekly.claimed_free, [0], "TC_CA_WP_012 lúc giờ lùi: claimed_free giữ [0]")
	t.eq(g.s.weekly.pending_end, {}, "TC_CA_WP_012 lúc giờ lùi: không có pending_end mới")
	t.eq(g.weekly_claim_free(0), {}, "TC_CA_WP_012 lúc giờ lùi: weekly_claim_free(0) trả {}")
	t.eq(int(g.s.lives.inf_until), 1800252901, "TC_CA_WP_012 lúc giờ lùi: inf_until giữ 1800252901")
	g.test_now = 1800252100
	g.weekly_refresh()
	t.eq(g.s.weekly.cycle, "W20836", "TC_CA_WP_012 lúc trở lại: cycle W20836")
	t.eq(g.weekly_claim_free(0), {}, "TC_CA_WP_012 lúc trở lại: weekly_claim_free(0) trả {}")
	t.eq(int(g.s.lives.inf_until), 1800252901, "TC_CA_WP_012 lúc trở lại: inf_until giữ 1800252901")


## Lùi múi giờ qua 00:00 thứ Hai (OQ-05: "hoặc đổi múi giờ") cũng không reset mùa: logic thuần.
func test_tz_back_keeps_new_season(t: T) -> void:
	Config.reset()
	var s := SaveSchema.defaults()
	WeeklyPass.refresh(s, 1800252001, 0)  # T2 18/01/2027 06:00:01, tz 0: mùa W20836
	s.weekly.points = 4
	var r := WeeklyPass.refresh(s, 1800252001, -7 * 3600)  # UTC-7: còn CN 17/01 23:00 giờ máy, tuần W20829
	t.eq(r.settled, false, "OQ-05 tz lùi: không chốt mùa")
	t.eq(s.weekly.cycle, "W20836", "OQ-05 tz lùi: cycle giữ W20836")
	t.eq(int(s.weekly.points), 4, "OQ-05 tz lùi: points giữ 4")


# --- Hồi quy: lỗi tìm thấy khi chấm case WP (2026-11-13) ---

## TC_CA_WP_033. Chơi liền qua 00:00 thứ Hai không tắt app. Trước khi sửa, Game chỉ chốt mùa lúc mở game, lúc app quay
## lại từ nền và lúc mở layer, nên key của L29 (T2 06:01) vào mùa cũ: cycle W20829, points 7.
func test_win_across_monday_goes_to_new_season(t: T) -> void:
	var g := _g(27, 1800230300)  # CN 17/01/2027 23:58:20
	g.weekly_refresh()  # mùa W20829
	g.s.weekly.tut_seen = true
	g.s.weekly.points = 3
	g.test_now = 1800230390
	var r := _win(g, g.start_attempt())
	t.eq(int(r.get("weekly_points", -1)), 1, "TC_CA_WP_033 bước 1: thẻ \"+1 key\"")
	t.eq(int(g.s.weekly.points), 4, "TC_CA_WP_033 bước 1: points 3 -> 4")
	g.test_now = 1800230460  # T2 00:01:00, Waiting
	r = _win(g, g.start_attempt())
	t.eq(int(r.get("weekly_points", -1)), 0, "TC_CA_WP_033 bước 2: Waiting không có key")
	g.test_now = 1800252060  # T2 06:01:00
	r = _win(g, g.start_attempt())
	t.eq(int(r.get("weekly_points", -1)), 3, "TC_CA_WP_033 bước 3: thẻ \"+3 keys\"")
	t.eq(g.s.weekly.cycle, "W20836", "TC_CA_WP_033 bước 3: cycle W20836")
	t.eq(int(g.s.weekly.points), 3, "TC_CA_WP_033 bước 3: points 3 (chỉ key của L29)")
	t.eq(int(g.s.weekly.pending_end.get("points", -1)), 4, "TC_CA_WP_033 popup cuối mùa: 4 key")


## TC_CA_WP_069. Sang Waiting khi app vẫn mở (ngồi ở Home). Trước khi sửa, mùa chưa chốt nên VIP và +3 mạng tối đa
## giữ tới lần mở game hay quay lại app sau.
func test_monday_while_open_drops_vip_hearts(t: T) -> void:
	var g := _g(27, 1800230390)  # CN 17/01/2027 23:59:50
	g.weekly_refresh()
	g.s.weekly.tut_seen = true
	g.s.weekly.vip = true
	g.s.weekly.claimed_free = [0]  # mốc 0 đã nhận: lúc chốt mùa VIP không tự nhận 15 phút mạng vô hạn
	g.s.weekly.claimed_vip = [0]
	g.weekly_refresh()  # +3 mạng tối đa của VIP
	t.eq(int(g.lives_view().max), 13, "TC_CA_WP_069 dữ liệu: Lives.max_for = 13")
	t.eq(int(g.lives_view().count), 13, "TC_CA_WP_069 dữ liệu: mạng 13")
	g.test_now = 1800230460  # T2 00:01:00
	await _wait(func() -> bool: return not bool(g.s.weekly.vip), 3000)  # Timer của Game, không gọi hàm nào
	t.eq(g.weekly_state(), "waiting", "TC_CA_WP_069 weekly_state = waiting")
	t.eq(g.s.weekly.vip, false, "TC_CA_WP_069 s.weekly.vip = false (mùa đã chốt)")
	t.eq(int(g.lives_view().max), 10, "TC_CA_WP_069 Lives.max_for = 10")
	t.eq(int(g.lives_view().count), 10, "TC_CA_WP_069 mạng 10")
	t.eq(bool(g.lives_view().infinite), false, "TC_CA_WP_069 không có mạng vô hạn (chip mạng hiện số)")


## TC_CA_WP_096. Đếm ngược của màn Waiting trong layer. Trước khi sửa, _tick chỉ cập nhật TimeLabel của mùa Active nên
## WaitingLabel đứng ở 5:59:59.
func test_waiting_countdown_ticks(t: T) -> void:
	var g := _g(27, 1800230401)  # T2 18/01/2027 00:00:01, Waiting
	g.weekly_refresh()
	var locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var layer := _open("res://scenes/weekly_pass.tscn")
	var label := layer.find_child("WaitingLabel", true, false) as Label
	t.ok(label != null, "TC_CA_WP_096 có WaitingLabel")
	if label != null:
		t.ok(label.text.contains("opens in 5:59:59"), "TC_CA_WP_096 WaitingLabel \"... 5:59:59 ...\" (nhận \"%s\")" % label.text)
		g.test_now = 1800230402
		await _wait(func() -> bool: return label.text.contains("opens in 5:59:58"), 2500)  # Timer của layer
		t.ok(label.text.contains("opens in 5:59:58"),
			"TC_CA_WP_096 giờ tăng 1 giây: \"... 5:59:58 ...\" (nhận \"%s\")" % label.text)
	layer.queue_free()
	TranslationServer.set_locale(locale)


func test_tutorial_flag_kept_next_season(t: T) -> void:
	Config.reset()
	var s := SaveSchema.defaults()
	s.weekly.cycle = "W20829"
	s.weekly.tut_seen = true
	s.weekly.points = 10
	WeeklyPass.refresh(s, 1800252001, 0)  # T2 18/01/2027 06:00:01
	t.eq(s.weekly.tut_seen, true, "TC_CA_WP_023 sau refresh: tut_seen = true")
	t.eq(int(s.weekly.points), 0, "TC_CA_WP_023 sau refresh: points 0")
	t.eq(s.weekly.cycle, "W20836", "TC_CA_WP_023 sau refresh: cycle W20836")
	t.eq(WeeklyPass.add_points(s, "active", ""), 1, "TC_CA_WP_023 add_points trả 1")
	t.eq(int(s.weekly.points), 1, "TC_CA_WP_023 points = 1")


func test_side_modes_give_no_key(t: T) -> void:
	var g := _g(96)
	Config.FEATURES["challenge"] = true  # đang tắt ở bản phát hành, bật tạm cho case
	g.weekly_refresh()
	g.s.weekly.tut_seen = true
	g.s.weekly.points = 5
	var modes := {"Road Trip": g.start_road_trip(), "Màn đặc biệt": g.special_start(),
		"Daily Challenge": g.start_challenge()}
	for name: String in modes:
		var a: Dictionary = modes[name]
		t.ok(not a.is_empty(), "TC_CA_WP_030 có lượt %s" % name)
		if a.is_empty():
			continue
		var r := _win(g, a)
		t.eq(int(r.get("weekly_points", 0)), 0, "TC_CA_WP_030 thắng %s: weekly_points 0 hoặc không có" % name)
		t.eq(int(g.s.weekly.points), 5, "TC_CA_WP_030 thắng %s: s.weekly.points giữ 5" % name)
	t.eq(_p().an.count("weekly_points"), 0, "TC_CA_WP_030 không có sự kiện weekly_points")
	Config.reset()


func test_loop_level_hard_counts_very_hard(t: T) -> void:
	var g := _g(501)
	g.weekly_refresh()
	g.s.weekly.tut_seen = true
	t.eq(g.difficulty_of(501), "very_hard", "TC_CA_WP_032 difficulty_of(501) = very_hard")
	_win(g, g.start_attempt())
	t.eq(int(g.s.weekly.points), 5, "TC_CA_WP_032 thắng L501: points 0 -> 5")
	t.eq(int(g.s.level), 502, "TC_CA_WP_032 sang L502")
	_win(g, g.start_attempt())
	t.eq(int(g.s.weekly.points), 6, "TC_CA_WP_032 thắng L502: points 5 -> 6")


func test_reward_table_all_milestones(t: T) -> void:
	Config.reset()
	var s := SaveSchema.defaults()
	s.weekly.points = 130
	s.weekly.vip = true
	var ms := WeeklyPass.main_milestones()
	t.eq(ms.size(), 11, "TC_CA_WP_038 11 mốc (mốc 0 và 10 mốc)")
	var free_sum := [0, 0, 0, 0, 0]
	var vip_sum := [0, 0, 0, 0, 0]
	for i in mini(ms.size(), C2.size()):
		var row: Array = C2[i]
		t.eq(int(ms[i].points), int(row[0]), "TC_CA_WP_038 mốc %d cần %d key" % [i, int(row[0])])
		var f := _flat(WeeklyPass.claim_free(s, i))
		var v := _flat(WeeklyPass.claim_vip(s, i))
		t.eq(f, row.slice(1, 6), "TC_CA_WP_038 mốc %d free [gold, Gợi ý, Move, Phá khối, phút]" % i)
		t.eq(v, row.slice(6, 11), "TC_CA_WP_038 mốc %d VIP [gold, Gợi ý, Move, Phá khối, phút]" % i)
		for k in 5:
			free_sum[k] += int(f[k])
			vip_sum[k] += int(v[k])
	t.eq(free_sum, [1650, 2, 2, 2, 15], "TC_CA_WP_038 tổng free: 1.650 gold, 2 Gợi ý, 2 +3 Move, 2 Phá khối, 15 phút")
	t.eq(vip_sum, [5950, 3, 4, 4, 30], "TC_CA_WP_038 tổng VIP: 5.950 gold, 3 Gợi ý, 4 +3 Move, 4 Phá khối, 30 phút")


func test_milestone_thresholds(t: T) -> void:
	Config.reset()
	# [mốc, key thiếu 1, key đủ]
	for c in [[1, 2, 3], [2, 7, 8], [10, 129, 130]]:
		var i := int(c[0])
		var s := SaveSchema.defaults()
		s.weekly.tut_seen = true
		s.weekly.points = int(c[1])
		t.eq(WeeklyPass.free_claimable(s, i), false, "TC_CA_WP_039 free_claimable(%d) false ở %d key" % [i, int(c[1])])
		t.eq(WeeklyPass.claim_free(s, i), {}, "TC_CA_WP_039 claim_free(%d) ở %d key trả {}" % [i, int(c[1])])
		t.eq(s.weekly.claimed_free, [], "TC_CA_WP_039 claim_free(%d) ở %d key: claimed_free không đổi" % [i, int(c[1])])
		s.weekly.points = int(c[2])
		t.eq(WeeklyPass.free_claimable(s, i), true, "TC_CA_WP_039 free_claimable(%d) true ở %d key" % [i, int(c[2])])


func test_bank_slot_boundaries(t: T) -> void:
	Config.reset()
	var pts := [129, 130, 144, 145, 159, 160, 280, 295, 999]
	var unlocked := [false, true, true, true, true, true, true, true, true]
	var slots := [0, 0, 0, 1, 1, 2, 10, 10, 10]
	var coins := [0, 0, 0, 400, 400, 800, 4000, 4000, 4000]
	for i in pts.size():
		var s := SaveSchema.defaults()
		s.weekly.vip = true
		s.weekly.end_seen = true
		s.weekly.points = int(pts[i])
		t.eq(WeeklyPass.bank_unlocked(s), unlocked[i], "TC_CA_WP_053 bank_unlocked ở %d key" % int(pts[i]))
		t.eq(WeeklyPass.bank_slots(s), slots[i], "TC_CA_WP_053 bank_slots ở %d key" % int(pts[i]))
		t.eq(int(WeeklyPass.claim_all_bank(s).reward.coins), coins[i], "TC_CA_WP_053 claim_all_bank gold ở %d key" % int(pts[i]))


func test_bank_needs_end_popup(t: T) -> void:
	var g := _g(27)
	g.weekly_refresh()
	g.s.weekly.vip = true
	g.s.weekly.points = 160
	g.s.weekly.end_seen = false
	t.eq(WeeklyPass.bank_unlocked(g.s), false, "TC_CA_WP_054 trước: bank_unlocked false")
	t.eq(WeeklyPass.bank_claimable(g.s, 0), false, "TC_CA_WP_054 trước: bank_claimable(0) false")
	t.eq(WeeklyPass.claim_bank(g.s, 0), {}, "TC_CA_WP_054 trước: claim_bank(0) trả {}")
	g.weekly_opened()
	t.eq(g.s.weekly.end_seen, true, "TC_CA_WP_054 sau weekly_opened: end_seen true")
	t.eq(WeeklyPass.bank_claimable(g.s, 0), true, "TC_CA_WP_054 sau weekly_opened: bank_claimable(0) true")


func test_claim_all_includes_bank(t: T) -> void:
	var g := _g(27)
	g.weekly_refresh()
	g.s.coins = 3000
	g.s.weekly.vip = true
	g.s.weekly.end_seen = true
	g.s.weekly.points = 175
	g.s.weekly.claimed_free = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	g.s.weekly.claimed_vip = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	var r: Dictionary = g.weekly_claim_all()
	t.eq(int(r.get("coins", 0)), 1200, "TC_CA_WP_055 Nhận tất cả trả coins 1.200 (3 x 400)")
	t.eq(int(g.s.coins), 4200, "TC_CA_WP_055 gold 3.000 -> 4.200")
	t.eq(g.s.weekly.claimed_bank, [0, 1, 2], "TC_CA_WP_055 claimed_bank = [0, 1, 2]")


func test_pending_vip_order_delivered_once(t: T) -> void:
	var g := _g(27)
	var iap: FakeIap = _p().iap
	g.save_now()
	iap.add_pending(_vip_order("T1"))
	await g.boot()
	t.eq(g.s.weekly.vip, true, "TC_CA_WP_060 lần 1: s.weekly.vip = true")
	t.eq(g.s.buys.size(), 1, "TC_CA_WP_060 lần 1: s.buys 1 đơn")
	t.eq(str(g.s.buys[0].get("token", "")) if g.s.buys.size() > 0 else "", "T1", "TC_CA_WP_060 lần 1: đơn T1")
	t.eq(int(g.s.lives.bonus), 3, "TC_CA_WP_060 lần 1: s.lives.bonus 3")
	t.eq(int(g.lives_view().count), 13, "TC_CA_WP_060 lần 1: mạng 13")
	t.eq(iap.finished, [{"token": "T1", "consumable": true}], "TC_CA_WP_060 lần 1: Platform.finish với consumable = true")
	iap.add_pending(_vip_order("T1"))  # đơn T1 vẫn còn trong Platform.pending()
	g._booted = false
	await g.boot()
	t.eq(g.s.buys.size(), 1, "TC_CA_WP_060 lần 2: s.buys vẫn 1 đơn")
	t.eq(int(g.s.lives.bonus), 3, "TC_CA_WP_060 lần 2: bonus 3")
	t.eq(int(g.lives_view().count), 13, "TC_CA_WP_060 lần 2: mạng không cộng thêm 3")
	t.eq(g.grant_purchase(_vip_order("T1")), false, "TC_CA_WP_060 lần 3: grant_purchase trả false")
	t.eq(g.s.buys.size(), 1, "TC_CA_WP_060 lần 3: s.buys vẫn 1 đơn")
	t.eq(int(g.s.lives.bonus), 3, "TC_CA_WP_060 lần 3: bonus 3")
	t.eq(int(g.lives_view().count), 13, "TC_CA_WP_060 lần 3: mạng không cộng thêm 3")


func _buy_blocked(t: T, g: Node, what: String, buys: int, bonus: int) -> void:
	var iap: FakeIap = _p().iap
	var r: Dictionary = await g.weekly_buy_vip()
	t.eq(r.get("status", ""), "error", "TC_CA_WP_063 %s: status error" % what)
	t.eq(r.get("granted", true), false, "TC_CA_WP_063 %s: granted false" % what)
	t.eq(iap.calls.size(), 0, "TC_CA_WP_063 %s: Platform.iap.calls không tăng (không mở store)" % what)
	t.eq(g.s.buys.size(), buys, "TC_CA_WP_063 %s: s.buys không đổi" % what)
	t.eq(int(g.s.lives.bonus), bonus, "TC_CA_WP_063 %s: s.lives.bonus không đổi" % what)


func test_no_vip_sale_when_not_allowed(t: T) -> void:
	var g := _g(27)
	g.weekly_refresh()
	g.grant_purchase(_vip_order("T63"))  # (a) đã VIP mùa này
	await _buy_blocked(t, g, "(a) đã VIP", 1, 3)
	g = _g(27, 1800230401)  # (b) Waiting
	g.weekly_refresh()
	await _buy_blocked(t, g, "(b) Waiting", 0, 0)
	g = _g(26)  # (c) Locked
	g.weekly_refresh()
	await _buy_blocked(t, g, "(c) Locked", 0, 0)


func test_vip_order_completed_after_season_change(t: T) -> void:
	var g := _g(27, 1800230390)  # CN 23:59:50
	g.weekly_refresh()
	g.s.weekly.points = 20
	g.save_now()
	await g.boot()
	var iap: FakeIap = _p().iap
	iap.simulate("pending")
	var r: Dictionary = await g.weekly_buy_vip()
	t.eq(r.get("status", ""), "pending", "TC_CA_WP_064 dữ liệu: mua lúc 23:59:50 trả pending")
	iap.add_pending(_vip_order("P64"))  # đơn hoàn tất khi người chơi ở ngoài
	g.test_now = 1800252100  # T2 06:01:40
	_p().resumed.emit()
	t.eq(int(g.s.weekly.pending_end.get("points", -1)), 20, "TC_CA_WP_064 giao 06:01:40: mùa W20829 chốt trước (pending_end.points 20)")
	t.eq(g.s.weekly.cycle, "W20836", "TC_CA_WP_064 giao 06:01:40: cycle W20836")
	t.eq(g.s.weekly.vip, true, "TC_CA_WP_064 giao 06:01:40: vip true")
	t.eq(int(g.s.weekly.points), 0, "TC_CA_WP_064 giao 06:01:40: points 0")
	t.eq(int(g.s.lives.bonus), 3, "TC_CA_WP_064 giao 06:01:40: s.lives.bonus 3")
	t.eq(_weekly_buys(g), 1, "TC_CA_WP_064 giao 06:01:40: s.buys 1 đơn")
	# Save khác: giao lúc Waiting, rồi resume lúc Active.
	g = _g(27, 1800230390)
	g.weekly_refresh()
	g.s.weekly.points = 20
	g.save_now()
	await g.boot()
	(_p().iap as FakeIap).add_pending(_vip_order("P64b"))
	g.test_now = 1800231000  # T2 00:10, Waiting
	_p().resumed.emit()
	t.eq(g.s.weekly.vip, true, "TC_CA_WP_064 giao lúc Waiting: vip true")
	t.eq(int(g.s.lives.bonus), 0, "TC_CA_WP_064 giao lúc Waiting: s.lives.bonus 0")
	g.test_now = 1800252100
	_p().resumed.emit()
	t.eq(int(g.s.lives.bonus), 3, "TC_CA_WP_064 resume 06:01:40: bonus 3")
	t.eq(int(g.lives_view().max), 13, "TC_CA_WP_064 resume 06:01:40: mạng tối đa 13")


func test_vip_bought_again_next_season(t: T) -> void:
	var g := _g(27)
	g.weekly_refresh()
	var iap: FakeIap = _p().iap
	var r0: Dictionary = await g.weekly_buy_vip()
	t.eq(r0.get("granted", false), true, "TC_CA_WP_065 dữ liệu: mùa W20829 đã mua VIP")
	t.eq(iap.finished.size() > 0 and bool(iap.finished[0].consumable), true, "TC_CA_WP_065 dữ liệu: đơn đã finish consumable = true")
	g.test_now = 1800252001  # mùa W20836 Active
	g.weekly_refresh()
	t.eq(g.owns_once("weekly_pass"), false, "TC_CA_WP_065 owns_once(weekly_pass) = false")
	var r: Dictionary = await g.weekly_buy_vip()
	t.eq(r.get("status", ""), "ok", "TC_CA_WP_065 weekly_buy_vip mùa sau: status ok")
	t.eq(r.get("granted", false), true, "TC_CA_WP_065 weekly_buy_vip mùa sau: granted true")
	t.eq(g.s.weekly.vip, true, "TC_CA_WP_065 s.weekly.vip = true")
	t.eq(_weekly_buys(g), 2, "TC_CA_WP_065 s.buys có 2 đơn weekly_pass")


func test_vip_hearts_added_and_regen_to_13(t: T) -> void:
	# [mạng trước, mạng sau khi VIP] (Test Data C7)
	for c in [[10, 13], [4, 7], [0, 3]]:
		var g := _g(27)
		g.weekly_refresh()
		g.s.coins = 3000
		g.s.lives.count = int(c[0])
		g.s.lives.next_at = 0 if int(c[0]) >= 10 else TS + 300  # vừa mất mạng: mạng kế hồi sau 5 phút
		g.grant_purchase(_vip_order("T67_%d" % int(c[0])))
		t.eq(int(g.lives_view().count), int(c[1]), "TC_CA_WP_067 %d/10 -> %d/13" % [int(c[0]), int(c[1])])
		t.eq(int(g.lives_view().max), 13, "TC_CA_WP_067 %d/10: max_for = 13" % int(c[0]))
		if int(c[0]) == 4:
			g.test_now = TS + 6 * 300
			t.eq(int(g.lives_view().count), 13, "TC_CA_WP_067 save 4/10: sau 6 lần hồi 13/13")
			g.test_now += 300
			t.eq(int(g.lives_view().count), 13, "TC_CA_WP_067 save 4/10: thêm 300 giây vẫn 13")
		if int(c[0]) == 10:
			t.eq(g.refill_gold(), false, "TC_CA_WP_067 13/13: refill bằng gold không cho")
			t.eq(int(g.s.coins), 3000, "TC_CA_WP_067 13/13: gold không đổi")


func test_season_end_drops_vip_hearts(t: T) -> void:
	# [mạng lúc hết mùa, mạng sau khi kẹp] (Test Data C7)
	for c in [[13, 10], [12, 10], [8, 8]]:
		var g := _g(27, 1800230400)  # T2 00:00
		g.s.weekly.cycle = "W20829"
		g.s.weekly.vip = true
		g.s.lives.bonus = 3
		g.s.lives.count = int(c[0])
		g.s.lives.next_at = 0
		g.weekly_refresh()
		t.eq(int(g.s.lives.bonus), 0, "TC_CA_WP_068 %d/13: s.lives.bonus = 0" % int(c[0]))
		t.eq(int(g.lives_view().max), 10, "TC_CA_WP_068 %d/13: max_for = 10" % int(c[0]))
		t.eq(int(g.lives_view().count), int(c[1]), "TC_CA_WP_068 mạng %d -> %d" % [int(c[0]), int(c[1])])


func test_upsell_needs_every_condition(t: T) -> void:
	# Save gốc: Active, tut_seen true, points 3, upsell "". Mỗi save lệch một điều kiện.
	var saves := {
		"(a) points 0": [27, TS, true, 0, false],
		"(b) tut_seen false": [27, TS, false, 3, false],
		"(c) vip true": [27, TS, true, 3, true],
		"(d) Waiting": [27, 1800230401, true, 0, false],
		"(e) s.level 26": [26, TS, true, 3, false],
	}
	for what: String in saves:
		var c: Array = saves[what]
		var g := _g(int(c[0]), int(c[1]))
		g.weekly_refresh()
		g.s.weekly.tut_seen = bool(c[2])
		g.s.weekly.points = int(c[3])
		g.s.weekly.vip = bool(c[4])
		t.eq(g.weekly_take_upsell(), false, "TC_CA_WP_073 %s: weekly_take_upsell trả false" % what)
		t.eq(g.s.weekly.upsell, "", "TC_CA_WP_073 %s: s.weekly.upsell giữ \"\"" % what)
		t.eq(_p().an.count("weekly_upsell"), 0, "TC_CA_WP_073 %s: không có sự kiện weekly_upsell" % what)
	# Đối chứng: save gốc thì có Upsell, nên mỗi save trên chỉ hỏng ở điều kiện của nó.
	var base := _g(27)
	base.weekly_refresh()
	base.s.weekly.tut_seen = true
	base.s.weekly.points = 3
	t.eq(base.weekly_take_upsell(), true, "đối chứng: save gốc có Upsell")


func test_away_several_weeks_settles_once(t: T) -> void:
	var g := _g(27, 1802066401)  # T2 08/02/2027 06:00:01, 3 tuần sau
	g.s.weekly.cycle = "W20829"
	g.s.weekly.points = 20
	var r1: Dictionary = g.weekly_refresh()
	t.eq(r1.settled, true, "TC_CA_WP_080 lần 1: settled true")
	t.eq(int(g.s.weekly.pending_end.get("points", -1)), 20, "TC_CA_WP_080 lần 1: pending_end.points = 20")
	t.eq(g.s.weekly.cycle, "W20857", "TC_CA_WP_080 lần 1: cycle W20857")
	var r2: Dictionary = g.weekly_refresh()
	t.eq(r2.settled, false, "TC_CA_WP_080 lần 2: settled false")
	t.eq(_p().an.count("weekly_end"), 1, "TC_CA_WP_080 weekly_end đúng 1 lần")


func test_vip_season_end_collects_bank(t: T) -> void:
	var g := _g(27, 1800252001)
	g.s.coins = 3000
	g.s.weekly.cycle = "W20829"
	g.s.weekly.vip = true
	g.s.weekly.points = 175
	g.s.weekly.end_seen = false
	g.s.weekly.claimed_free = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	g.s.weekly.claimed_vip = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	var r: Dictionary = g.weekly_refresh()
	t.eq(int(r.reward.coins), 1200, "TC_CA_WP_081 thưởng chốt mùa coins 1.200 (3 ô x 400)")
	t.eq(int(g.s.coins), 4200, "TC_CA_WP_081 gold 3.000 -> 4.200")
	t.eq(int(g.s.weekly.pending_end.get("coins", -1)), 1200, "TC_CA_WP_081 pending_end.coins = 1200")


func test_remote_config_points(t: T) -> void:
	var g := _g(27)
	g.weekly_refresh()
	g.s.weekly.tut_seen = true
	Config.apply_remote({"weekly_points_normal": "2", "weekly_points_hard": "4", "weekly_points_very_hard": "6"})
	for c in [[27, 2], [29, 4], [33, 6]]:
		g.s.level = int(c[0])
		var r := _win(g, g.start_attempt())
		t.eq(int(r.get("weekly_points", -1)), int(c[1]), "TC_CA_WP_084 thắng L%d +%d" % [int(c[0]), int(c[1])])
	t.eq(int(g.s.weekly.points), 12, "TC_CA_WP_084 points 0 -> 12")
	var locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var pop := _open("res://scenes/popup_weekly_tutorial.tscn")
	var shown: Array = []
	for row: Control in pop.rows:
		shown.append((row.get_node("Points") as Label).text)
	t.eq(shown, ["+2", "+4", "+6"], "TC_CA_WP_084 popup How to earn rewards: \"+2\", \"+4\", \"+6\"")
	pop.queue_free()
	TranslationServer.set_locale(locale)
	Config.reset()
	t.eq([WeeklyPass.points_for(""), WeeklyPass.points_for("hard"), WeeklyPass.points_for("very_hard")], [1, 3, 5],
		"TC_CA_WP_084 sau Config.reset: points_for trả 1, 3, 5")


func test_remote_config_unlock_index(t: T) -> void:
	var g := _g(27)
	Config.apply_remote({"weekly_unlock_hard_index": "3"})
	t.eq(g.weekly_unlock_level(), 29, "TC_CA_WP_085 weekly_unlock_level() = 29")
	t.eq(g.weekly_state(), "locked", "TC_CA_WP_085 s.level 27: locked")
	g.s.level = 30
	t.eq(g.weekly_state(), "active", "TC_CA_WP_085 s.level 30: active")
	t.eq(int(Unlocks.levels().get("weekly_pass", 0)), 30, "TC_CA_WP_085 Unlocks.levels().weekly_pass = 30")
	Config.reset()


func test_remote_config_start_hour_zero(t: T) -> void:
	Config.reset()
	Config.apply_remote({"weekly_start_hour": "0"})
	var st := WeeklyPass.state(1800230399, 0, true)
	t.eq(st, "active", "TC_CA_WP_086 1800230399: active")
	t.eq(WeeklyPass.window(1800230399, 0).cycle, "W20829", "TC_CA_WP_086 1800230399: W20829")
	t.eq(WeeklyPass.seconds_left(1800230399, 0, st), 1, "TC_CA_WP_086 1800230399: seconds_left 1")
	st = WeeklyPass.state(1800230400, 0, true)
	t.eq(st, "active", "TC_CA_WP_086 1800230400: active (không còn Waiting)")
	t.eq(WeeklyPass.window(1800230400, 0).cycle, "W20836", "TC_CA_WP_086 1800230400: W20836")
	t.eq(WeeklyPass.seconds_left(1800230400, 0, st), 604800, "TC_CA_WP_086 1800230400: seconds_left = 604800")
	Config.reset()


func test_remote_config_vip_hearts(t: T) -> void:
	var g := _g(27)
	g.weekly_refresh()
	Config.apply_remote({"weekly_vip_bonus_hearts": "5"})
	g.grant_purchase(_vip_order("T87"))
	t.eq(int(g.lives_view().max), 15, "TC_CA_WP_087 Lives.max_for = 15")
	t.eq(int(g.lives_view().count), 15, "TC_CA_WP_087 mạng 10 -> 15")
	var locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var up := _open("res://scenes/popup_weekly_upsell.tscn")
	t.eq((up.get_node("%Perk3") as Label).text, "+5 max lives all season", "TC_CA_WP_087 Perk3 \"+5 max lives all season\"")
	up.queue_free()
	g.s.weekly.tut_seen = true  # layer không chạy tutorial
	var layer := _open("res://scenes/weekly_pass.tscn")
	t.eq((layer.get_node("%VipLabel") as Label).text, "VIP active - +5 max hearts this week",
		"TC_CA_WP_087 VipLabel \"VIP active - +5 max hearts this week\"")
	layer.queue_free()
	TranslationServer.set_locale(locale)
	Config.reset()


func test_remote_config_bank(t: T) -> void:
	Config.reset()
	Config.apply_remote({"weekly_bank_step": "10", "weekly_bank_max": "5", "weekly_bank_reward_coins": "500"})
	# [key, số ô, gold]
	for c in [[160, 3, 1500], [500, 5, 2500]]:
		var s := SaveSchema.defaults()
		s.weekly.vip = true
		s.weekly.end_seen = true
		s.weekly.points = int(c[0])
		t.eq(WeeklyPass.bank_slots(s), int(c[1]), "TC_CA_WP_088 %d key: %d ô" % [int(c[0]), int(c[1])])
		t.eq(int(WeeklyPass.claim_all_bank(s).reward.coins), int(c[2]), "TC_CA_WP_088 %d key: %d gold" % [int(c[0]), int(c[2])])
	Config.reset()


func test_config_off_or_wrong_sku_locks(t: T) -> void:
	for rc: Dictionary in [{"weekly_enabled": "0"}, {"weekly_sku": "gold_pack_1"}]:
		var what := str(rc.keys()[0])
		var g := _g(40)
		g.weekly_refresh()
		g.s.weekly.tut_seen = true
		g.s.weekly.points = 3
		Config.apply_remote(rc)
		t.eq(g.weekly_state(), "locked", "TC_CA_WP_089 %s: weekly_state = locked" % what)
		t.eq(g.weekly_view().unlocked, false, "TC_CA_WP_089 %s: weekly_view().unlocked = false" % what)
		_win(g, g.start_attempt())
		t.eq(int(g.s.weekly.points), 3, "TC_CA_WP_089 %s: thắng L40, points giữ 3" % what)
		t.eq(g.weekly_take_upsell(), false, "TC_CA_WP_089 %s: weekly_take_upsell false" % what)
		var r: Dictionary = await g.weekly_buy_vip()
		t.eq(r.get("status", ""), "error", "TC_CA_WP_089 %s: weekly_buy_vip trả status error" % what)
		t.eq((_p().iap as FakeIap).calls.size(), 0, "TC_CA_WP_089 %s: không mở store" % what)
		Config.reset()


## s.weekly của TC_CA_WP_100 (PRE COND).
const WEEKLY_100 := {
	"cycle": "W20829", "points": 37, "vip": true, "opened": true, "end_seen": false, "tut_seen": true,
	"claimed_free": [0, 1, 2], "claimed_vip": [0], "claimed_bank": [], "pending_end": {}, "upsell": "W20829",
}


func test_weekly_state_survives_save_and_cloud(t: T) -> void:
	var g := _g(40)
	g.s.runs = 40  # đã chơi, để bản cloud thắng bản vừa cài ở máy kia
	g.s.weekly = WEEKLY_100.duplicate(true)
	g.s.lives.bonus = 3
	g.s.lives.count = 13
	g.s.lives.inf_until = 1800000900
	g.save_now()
	var loaded := SaveStore.new(DIR + "/save.json").load_state()
	t.eq(loaded.weekly, WEEKLY_100, "TC_CA_WP_100 save_now rồi đọc file: s.weekly giống hệt")
	t.eq(int(loaded.lives.bonus), 3, "TC_CA_WP_100 đọc file: s.lives.bonus 3")
	t.eq(int(loaded.lives.inf_until), 1800000900, "TC_CA_WP_100 đọc file: s.lives.inf_until 1800000900")
	g._booted = false
	await g.boot()  # nạp lại save vào Game
	t.eq(g.s.weekly, WEEKLY_100, "TC_CA_WP_100 nạp lại: s.weekly giống hệt")
	t.eq(int(g.s.lives.bonus), 3, "TC_CA_WP_100 nạp lại: s.lives.bonus 3")
	t.eq(int(g.s.lives.inf_until), 1800000900, "TC_CA_WP_100 nạp lại: s.lives.inf_until 1800000900")
	var v: Dictionary = g.weekly_view()
	t.eq(int(v.points), 37, "TC_CA_WP_100 weekly_view: points 37")
	t.eq(v.vip, true, "TC_CA_WP_100 weekly_view: vip true")
	t.eq(g.weekly_refresh().settled, false, "TC_CA_WP_100 nạp cùng tuần: settled false")
	t.eq(_p().an.count("weekly_end"), 0, "TC_CA_WP_100 nạp cùng tuần: không chốt mùa")
	var cloud: String = _p().save.last_json
	var g2 := _g(1)  # máy khác: bản mới cài
	_p().save.cloud_json = cloud
	await g2.boot()
	t.eq(g2.s.weekly, WEEKLY_100, "TC_CA_WP_100 tải bản cloud: s.weekly giống hệt")
	t.eq(int(g2.s.lives.bonus), 3, "TC_CA_WP_100 tải bản cloud: s.lives.bonus 3")
	t.eq(int(g2.s.lives.inf_until), 1800000900, "TC_CA_WP_100 tải bản cloud: s.lives.inf_until 1800000900")
	_p().save.cloud_json = ""


func test_old_save_without_weekly_fields(t: T) -> void:
	# [save, s.level]: (a) không có "weekly"; (b) "weekly" thiếu upsell, tut_seen, pending_end.
	for c in [["(a)", 40], ["(b)", 40], ["(a)", 20]]:
		var what := "%s s.level %d" % [str(c[0]), int(c[1])]
		var g := _g(int(c[1]))
		var d := SaveSchema.defaults()
		d.level = int(c[1])
		d.meta.intro_seen = true
		d.meta.rated = true
		if str(c[0]) == "(a)":
			d.erase("weekly")
		else:
			d.weekly = {"cycle": "W20829", "points": 0, "vip": false, "opened": false, "end_seen": false,
				"claimed_free": [], "claimed_vip": [], "claimed_bank": []}
		var f := FileAccess.open(DIR + "/save.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(d))
		f.close()
		await g.boot()
		t.eq(int(g.s.weekly.get("points", -1)), 0, "TC_CA_WP_101 %s: points 0" % what)
		t.eq(g.s.weekly.get("vip"), false, "TC_CA_WP_101 %s: vip false" % what)
		t.eq(g.s.weekly.get("tut_seen"), false, "TC_CA_WP_101 %s: tut_seen false" % what)
		t.eq(g.s.weekly.get("upsell"), "", "TC_CA_WP_101 %s: upsell \"\"" % what)
		t.eq(g.s.weekly.get("pending_end"), {}, "TC_CA_WP_101 %s: pending_end {}" % what)
		if int(c[1]) == 40:
			t.eq(g.weekly_state(), "active", "TC_CA_WP_101 %s: weekly_state active" % what)
			var r := _win(g, g.start_attempt())
			t.eq(int(r.get("weekly_points", -1)), 0, "TC_CA_WP_101 %s: thắng level chưa xem tutorial không cộng key" % what)
			t.eq(int(g.s.weekly.points), 0, "TC_CA_WP_101 %s: points giữ 0" % what)
		else:
			t.eq(g.weekly_state(), "locked", "TC_CA_WP_101 %s: weekly_state locked" % what)
