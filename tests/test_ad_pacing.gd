extends RefCounted
## Interstitial pacing as the reference game (design.md mục 6): no Remove Ads, current level > 35, and 90 s on a clock
## that starts at game entry and restarts when an interstitial closes or a rewarded pays out.
const T := preload("res://tests/t.gd")
const AdPacing := preload("res://src/meta/ad_pacing.gd")
const SaveSchema := preload("res://src/meta/save_schema.gd")
const Config := preload("res://src/config.gd")

const NOW := 1_800_000_000


## level is the current level: it already went up for the win whose card is closing.
func _s(level: int = 36) -> Dictionary:
	Config.reset()
	var s := SaveSchema.defaults()
	s.level = level
	s.runs = 10
	return s


func _ctx(over: Dictionary = {}) -> Dictionary:
	var c := {"now": NOW, "session_start": NOW - 600, "x2_taken": false}
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


## Our x2 closes the card by itself (no Claim press), so it never leads to an interstitial.
func test_x2_taken(t: T) -> void:
	var s := _s()
	t.eq(AdPacing.inter_why(s, _ctx({"x2_taken": true})), "x2_taken", "đã lấy x2")


## Level goes up at the win, before the card: leaving the L35 card (level 36) is the first chance.
func test_level_gate(t: T) -> void:
	var s := _s(35)
	t.eq(AdPacing.inter_why(s, _ctx()), "level", "level hiện tại 35 (rời thẻ thắng L34)")
	s.level = 36
	t.ok(AdPacing.inter_due(s, _ctx()), "level hiện tại 36 (rời thẻ thắng L35)")


## The clock starts at game entry: the first interstitial of a session comes at least 90 s after opening the app.
func test_clock_from_session_start(t: T) -> void:
	var s := _s()
	t.eq(AdPacing.inter_why(s, _ctx({"session_start": NOW - 89})), "cooldown", "89 giây sau khi vào game")
	t.ok(AdPacing.inter_due(s, _ctx({"session_start": NOW - 90})), "90 giây")


func test_clock_after_inter(t: T) -> void:
	var s := _s()
	s.ads.last_inter_at = NOW - 89
	t.eq(AdPacing.inter_why(s, _ctx()), "cooldown", "89 giây sau interstitial")
	s.ads.last_inter_at = NOW - 90
	t.ok(AdPacing.inter_due(s, _ctx()), "90 giây")


func test_clock_after_rewarded(t: T) -> void:
	var s := _s()
	s.ads.last_rv_at = NOW - 89
	t.eq(AdPacing.inter_why(s, _ctx()), "cooldown", "89 giây sau rewarded")
	s.ads.last_rv_at = NOW - 90
	t.ok(AdPacing.inter_due(s, _ctx()), "90 giây")


## Times saved in an earlier session do not count (the clock restarts at game entry); a saved time after now (device
## clock set back) does not block the session either.
func test_clock_ignores_other_sessions(t: T) -> void:
	var s := _s()
	s.ads.last_inter_at = NOW - 700
	s.ads.last_rv_at = NOW + 5000
	var c := _ctx({"session_start": NOW - 100})
	t.ok(AdPacing.inter_due(s, c), "mốc của phiên trước và mốc ở tương lai không tính")


## No run spacing and no daily cap.
func test_no_run_spacing_no_daily_cap(t: T) -> void:
	var s := _s()
	AdPacing.note_inter(s, NOW - 90, 100)
	s.runs += 1
	t.ok(AdPacing.inter_due(s, _ctx()), "lượt kế tiếp, đã qua 90 giây: được")
	s.ads.inter_today = 50
	t.ok(AdPacing.inter_due(s, _ctx()), "không giới hạn số lần mỗi ngày")


func test_note_and_count(t: T) -> void:
	var s := _s()
	t.eq(AdPacing.inter_count_today(s, 100), 0, "ban đầu")
	AdPacing.note_inter(s, NOW, 100)
	t.eq(AdPacing.inter_count_today(s, 100), 1, "sau 1")
	t.eq(s.ads.last_inter_at, NOW, "last_inter_at")
	t.eq(AdPacing.inter_why(s, _ctx()), "cooldown", "đồng hồ đếm lại khi interstitial đóng")
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
	t.eq(AdPacing.inter_why(s, _ctx()), "cooldown", "rewarded cũng đếm lại đồng hồ")


func test_config_override(t: T) -> void:
	var s := _s(11)
	Config.ADS.inter_after_level = 10
	Config.ADS.inter_cooldown = 30
	t.ok(AdPacing.inter_due(s, _ctx({"session_start": NOW - 30})), "đọc Config.ADS")
	Config.reset()
