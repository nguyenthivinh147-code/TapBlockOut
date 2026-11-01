extends RefCounted
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const SaveSchema := preload("res://src/meta/save_schema.gd")
const DailyCalendar := preload("res://src/meta/daily_calendar.gd")


func _sum(r: Dictionary, acc: Dictionary) -> void:
	acc.coins += int(r.coins)
	for k in r.items:
		acc.items[k] = int(acc.items.get(k, 0)) + int(r.items[k])


func test_first_claim(t: T) -> void:
	var s := SaveSchema.defaults()
	var v := DailyCalendar.view(s, 100, 5)
	t.ok(v.open, "mở ở L5")
	t.ok(v.can_claim, "có thể nhận")
	t.ok(v.badge, "chấm đỏ")
	t.ok(not v.can_ad_next, "chưa nhận thì chưa có video")
	t.eq(v.cells.size(), 7, "7 ô")
	t.eq(v.week, 0, "tuần 0")
	t.eq(v.cells[0].state, "current", "ô 1 hiện tại")
	t.eq(v.cells[1].state, "locked", "ô 2 khoá")
	var r := DailyCalendar.claim(s, 100)
	t.eq(r.coins, 50, "ô 1 là 50 gold")
	t.eq(s.daily.idx, 1, "tiến một ô")
	t.eq(s.daily.claim_day, 100, "ghi ngày")
	t.ok(DailyCalendar.claim(s, 100).is_empty(), "không nhận hai lần trong ngày")
	t.eq(s.daily.idx, 1, "idx giữ nguyên")
	v = DailyCalendar.view(s, 100, 5)
	t.ok(not v.can_claim and not v.badge, "hết chấm đỏ")
	t.ok(v.can_ad_next, "được xem video")
	t.eq(v.cells[0].state, "claimed", "ô 1 đã nhận")
	t.eq(v.cells[1].state, "next", "ô 2 là ô kế")


func test_locked_before_level(t: T) -> void:
	var s := SaveSchema.defaults()
	var v := DailyCalendar.view(s, 100, Config.UNLOCK.daily_gift - 1)
	t.ok(not v.open, "chưa mở")
	t.ok(not v.badge, "không chấm đỏ khi chưa mở")


func test_ad_next(t: T) -> void:
	var s := SaveSchema.defaults()
	t.ok(DailyCalendar.claim_next_ad(s, 100).is_empty(), "chưa nhận ô hiện tại thì không xem được")
	DailyCalendar.claim(s, 100)
	var r := DailyCalendar.claim_next_ad(s, 100)
	t.eq(r.coins, 100, "ô 2 là 100 gold")
	t.eq(s.daily.idx, 2, "tiến thêm một ô")
	t.eq(s.daily.ad_day, 100, "ghi ngày video")
	t.ok(DailyCalendar.claim_next_ad(s, 100).is_empty(), "video 1 lần/ngày")
	t.ok(not DailyCalendar.view(s, 100, 5).can_ad_next, "hết video")
	# Ngày mai có ô mới (ô 3).
	t.ok(DailyCalendar.view(s, 101, 5).can_claim, "ngày mai nhận được")
	var r2 := DailyCalendar.claim(s, 101)
	t.eq(r2.items.get("hint", 0), 1, "ô 3 là 1 Gợi ý")
	t.ok(DailyCalendar.view(s, 101, 5).can_ad_next, "video ngày mới")


func test_missed_days_no_reset(t: T) -> void:
	var s := SaveSchema.defaults()
	DailyCalendar.claim(s, 10)
	DailyCalendar.claim(s, 11)
	var r := DailyCalendar.claim(s, 40)
	t.eq(s.daily.idx, 3, "lỡ ngày không reset")
	t.eq(r.items.get("hint", 0), 1, "ô 3 sau khi lỡ")


func test_clock_rewind(t: T) -> void:
	var s := SaveSchema.defaults()
	DailyCalendar.claim(s, 50)
	var v := DailyCalendar.view(s, 49, 5)
	t.ok(not v.can_claim, "giờ lùi không nhận")
	t.ok(not v.can_ad_next, "giờ lùi không xem video")
	t.ok(DailyCalendar.claim(s, 49).is_empty(), "claim trả rỗng")
	t.ok(DailyCalendar.claim_next_ad(s, 49).is_empty(), "video trả rỗng")
	t.ok(not DailyCalendar.view(s, 50, 5).can_claim, "đúng mốc chưa nhận")
	t.ok(DailyCalendar.view(s, 51, 5).can_claim, "vượt mốc nhận lại")


func test_full_cycle(t: T) -> void:
	var s := SaveSchema.defaults()
	var acc := {"coins": 0, "items": {}}
	for d in range(28):
		var v := DailyCalendar.view(s, 200 + d, 5)
		t.eq(v.week, d / 7, "tuần ngày %d" % d)
		var r := DailyCalendar.claim(s, 200 + d)
		t.ok(not r.is_empty(), "nhận ngày %d" % d)
		_sum(r, acc)
	t.eq(acc.coins, 6650, "tổng gold một vòng")
	t.eq(acc.items.get("hint", 0), 5, "5 hint")
	t.eq(acc.items.get("move", 0), 5, "5 move")
	t.eq(acc.items.get("smash", 0), 4, "4 smash")
	t.eq(s.daily.idx, 0, "về ô 1")
	# Ngày vừa nhận ô 28: vẫn hiện tuần 4, tất cả đã nhận.
	var v2 := DailyCalendar.view(s, 227, 5)
	t.eq(v2.week, 3, "giữ tuần 4 sau khi nhận ô 28")
	for c in v2.cells:
		t.eq(c.state, "claimed", "ô %d đã nhận" % c.day)
	# Vòng mới.
	var v3 := DailyCalendar.view(s, 228, 5)
	t.eq(v3.week, 0, "vòng mới tuần 1")
	t.eq(v3.cells[0].state, "current", "ô 1 vòng mới")
	t.eq(DailyCalendar.claim(s, 228).coins, 50, "ô 1 lặp lại")


func test_ad_wraps(t: T) -> void:
	var s := SaveSchema.defaults()
	s.daily.idx = 27
	DailyCalendar.claim(s, 300)
	t.eq(s.daily.idx, 0, "claim ô 28 về 0")
	var r := DailyCalendar.claim_next_ad(s, 300)
	t.eq(r.coins, 50, "video sau ô 28 nhận ô 1")
	t.eq(s.daily.idx, 1, "idx 1")
	s.daily.idx = 27
	s.daily.ad_day = -1
	var r2 := DailyCalendar.claim_next_ad(s, 300)
	t.eq(r2.coins, 1000, "video nhận ô 28")
	t.eq(s.daily.idx, 0, "wrap")


func test_week_cells_follow_idx(t: T) -> void:
	var s := SaveSchema.defaults()
	s.daily.idx = 9
	var v := DailyCalendar.view(s, 5, 5)
	t.eq(v.week, 1, "tuần 2")
	t.eq(v.cells[0].day, 8, "bắt đầu ô 8")
	t.eq(v.cells[0].state, "claimed", "ô 8 đã qua")
	t.eq(v.cells[2].state, "current", "ô 10 hiện tại")
	t.eq(v.cells[6].day, 14, "kết thúc ô 14")


func test_reward_is_copy(t: T) -> void:
	var s := SaveSchema.defaults()
	var r := DailyCalendar.claim(s, 1)
	r.coins = 99999
	t.eq(Config.DAILY[0].coins, 50, "sửa reward không đổi Config")
