extends RefCounted
const T := preload("res://tests/t.gd")
const AdPacing := preload("res://src/meta/ad_pacing.gd")
const SaveSchema := preload("res://src/meta/save_schema.gd")
const Config := preload("res://src/config.gd")

const NOW := 1_800_000_000


func _s(runs: int = 10) -> Dictionary:
	Config.reset()
	var s := SaveSchema.defaults()
	s.runs = runs
	return s


func _ctx(over: Dictionary = {}) -> Dictionary:
	var c := {"now": NOW, "session_start": NOW - 600, "first_session": false, "level": 15,
		"x2_offered": true, "x2_taken": false, "day": 100}
	c.merge(over, true)
	return c


func test_due_basic(t: T) -> void:
	var s := _s()
	t.ok(AdPacing.inter_due(s, _ctx()), "đủ điều kiện")
	t.eq(AdPacing.inter_why(s, _ctx()), "", "không có lý do chặn")


func test_no_ads(t: T) -> void:
	var s := _s()
	s.no_ads = true
	t.eq(AdPacing.inter_due(s, _ctx()), false, "no_ads luôn sai")
	t.eq(AdPacing.inter_why(s, _ctx()), "no_ads", "lý do")


func test_x2_taken(t: T) -> void:
	var s := _s()
	t.eq(AdPacing.inter_due(s, _ctx({"x2_taken": true})), false, "đã lấy x2")
	t.ok(AdPacing.inter_due(s, _ctx({"x2_offered": false})), "không có x2 thì bỏ qua được")
	t.ok(AdPacing.inter_due(s, _ctx({"x2_offered": true, "x2_taken": false})), "bỏ qua x2")


func test_early(t: T) -> void:
	var s := _s(3)
	t.eq(AdPacing.inter_why(s, _ctx()), "early", "lượt 3")
	s.runs = 4
	t.ok(AdPacing.inter_due(s, _ctx()), "lượt 4 được")


func test_every(t: T) -> void:
	var s := _s(10)
	s.ads.last_inter_run = 9
	t.eq(AdPacing.inter_why(s, _ctx()), "every", "cách 1 lượt")
	s.ads.last_inter_run = 8
	t.ok(AdPacing.inter_due(s, _ctx()), "cách 2 lượt")


func test_warmup(t: T) -> void:
	var s := _s()
	t.eq(AdPacing.inter_why(s, _ctx({"session_start": NOW - 89})), "warmup", "89 giây")
	t.ok(AdPacing.inter_due(s, _ctx({"session_start": NOW - 90})), "90 giây")


func test_cooldown(t: T) -> void:
	var s := _s()
	s.ads.last_inter_at = NOW - 120
	t.eq(AdPacing.inter_why(s, _ctx()), "cooldown", "đúng 120 giây vẫn chặn")
	s.ads.last_inter_at = NOW - 121
	t.ok(AdPacing.inter_due(s, _ctx()), "121 giây")


func test_rewarded_grace(t: T) -> void:
	var s := _s()
	s.ads.last_rv_at = NOW - 45
	t.eq(AdPacing.inter_why(s, _ctx()), "rewarded", "45 giây sau rewarded")
	s.ads.last_rv_at = NOW - 46
	t.ok(AdPacing.inter_due(s, _ctx()), "46 giây")


func test_first_session(t: T) -> void:
	var s := _s()
	t.eq(AdPacing.inter_why(s, _ctx({"first_session": true, "level": 10})), "first_session", "L10 phiên đầu")
	t.ok(AdPacing.inter_due(s, _ctx({"first_session": true, "level": 11})), "qua L10")
	t.ok(AdPacing.inter_due(s, _ctx({"first_session": false, "level": 5})), "phiên sau không chặn")


func test_note_and_count(t: T) -> void:
	var s := _s(10)
	t.eq(AdPacing.inter_count_today(s, 100), 0, "ban đầu")
	AdPacing.note_inter(s, NOW, 100)
	t.eq(AdPacing.inter_count_today(s, 100), 1, "sau 1")
	t.eq(s.ads.last_inter_run, 10, "last_inter_run")
	t.eq(s.ads.last_inter_at, NOW, "last_inter_at")
	AdPacing.note_inter(s, NOW + 500, 100)
	t.eq(AdPacing.inter_count_today(s, 100), 2, "sau 2")
	t.eq(AdPacing.inter_count_today(s, 101), 0, "ngày khác đọc ra 0")
	AdPacing.note_inter(s, NOW + 90000, 101)
	t.eq(AdPacing.inter_count_today(s, 101), 1, "sang ngày reset")
	t.eq(AdPacing.inter_count_today(s, 100), 0, "ngày cũ không còn")


func test_note_rewarded(t: T) -> void:
	var s := _s()
	AdPacing.note_rewarded(s, NOW)
	t.eq(s.ads.last_rv_at, NOW, "last_rv_at")
	t.eq(AdPacing.inter_why(s, _ctx()), "rewarded", "chặn ngay sau")


func test_config_override(t: T) -> void:
	var s := _s(2)
	Config.ADS.inter_from_run = 2
	t.ok(AdPacing.inter_due(s, _ctx()), "đọc Config.ADS")
	Config.reset()
