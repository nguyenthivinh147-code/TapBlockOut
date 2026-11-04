extends RefCounted
const T := preload("res://tests/t.gd")
const SaveSchema := preload("res://src/meta/save_schema.gd")
const NotifPlan := preload("res://src/meta/notif_plan.gd")
const Clock := preload("res://src/meta/clock.gd")
const Config := preload("res://src/config.gd")

const TZ := 7 * 3600
## 2026-11-01 00:00 UTC; với TZ 7h là 07:00 địa phương ngày 20028.
const BASE := 1793491200
const ALL: Array = ["daily_gift", "lives_full", "offer_open"]


func _save(open_minutes: Array) -> Dictionary:
	var s := SaveSchema.defaults()
	s.meta.install_at = BASE
	for m in open_minutes:
		s.notify.hours.append(m)
	return s


## Ngày địa phương (0 = ngày cài) và phút trong ngày của một thông báo.
func _day(e: Dictionary) -> int:
	return Clock.day_number(int(e.at), TZ) - Clock.day_number(BASE, TZ)


func _minute(e: Dictionary) -> int:
	return posmod(floori(float(int(e.at) + TZ) / 60.0), 1440)


func _per_day(p: Array) -> Dictionary:
	var d := {}
	for e in p:
		d[_day(e)] = int(d.get(_day(e), 0)) + 1
	return d


## Đầu ngày cài 00:00 địa phương: mọi khung giờ của ngày 0 còn ở tương lai.
func _midnight() -> int:
	return Clock.day_number(BASE, TZ) * Clock.DAY_SEC - TZ


func test_first_week_three_per_day(t: T) -> void:
	var s := _save([1140, 1145, 1150, 720, 725, 730, 1260, 1265, 1270])
	var p := NotifPlan.plan(s, _midnight(), TZ, ALL)
	var d := _per_day(p)
	for i in 7:
		t.eq(d.get(i, 0), 3, "ngày %d có 3 thông báo" % i)
	t.eq(d.get(7, 0), 1, "ngày 7 chỉ 1 thông báo")


func test_lead_before_open_hour(t: T) -> void:
	var s := _save([1140, 1140, 1140]) # luôn mở 19:00
	var p := NotifPlan.plan(s, _midnight(), TZ, ["daily_gift"])
	t.ok(p.size() > 0, "có lịch")
	t.eq(_minute(p[0]), 1140 - 15, "sớm 15 phút so với 19:00")


func test_daily_until_14_then_sparse(t: T) -> void:
	var s := _save([1140, 1140, 1140])
	var p := NotifPlan.plan(s, _midnight(), TZ, ALL)
	var d := _per_day(p)
	for i in range(7, 15):
		t.eq(d.get(i, 0), 1, "ngày %d đúng 1 lần" % i)
	for i in [15, 17, 19, 20, 22, 23, 25, 26, 28, 29]:
		t.eq(d.get(i, 0), 0, "ngày %d không báo" % i)
	for i in [16, 18, 21, 24, 27, 30]:
		t.eq(d.get(i, 0), 1, "ngày %d có báo" % i)
	var max_day := 0
	for e in p:
		max_day = maxi(max_day, _day(e))
	t.eq(max_day, 30, "dừng ở ngày 30")


func test_window_8_to_22(t: T) -> void:
	# mở rất sớm và rất khuya: phải kẹp vào 8:00..22:00
	var s := _save([5 * 60, 5 * 60, 5 * 60, 23 * 60 + 50, 23 * 60 + 50, 23 * 60 + 50])
	var p := NotifPlan.plan(s, _midnight(), TZ, ALL)
	t.ok(p.size() > 0, "có lịch")
	for e in p:
		var m := _minute(e)
		t.ok(m >= 8 * 60 and m <= 22 * 60, "trong khung giờ: %d" % m)
	var s2 := _save([])
	for e in NotifPlan.plan(s2, _midnight(), TZ, ALL):
		var m2 := _minute(e)
		t.ok(m2 >= 8 * 60 and m2 <= 22 * 60, "mặc định trong khung giờ: %d" % m2)


func test_quiet_after_9_ignored(t: T) -> void:
	var s := _save([1140, 1140, 1140, 720, 720, 720])
	s.notify.ignored = 9
	var d := _per_day(NotifPlan.plan(s, _midnight(), TZ, ALL))
	for i in 7:
		t.eq(d.get(i, 0), 1, "ngày %d chỉ 1 lần khi bị bỏ qua 9 lần" % i)
	s.notify.ignored = 8
	var d2 := _per_day(NotifPlan.plan(s, _midnight(), TZ, ALL))
	t.eq(d2.get(0, 0), 2, "8 lần chưa bị giảm")


func test_candidates_only_real(t: T) -> void:
	var s := _save([1140, 1140, 1140, 720, 720, 720])
	t.eq(NotifPlan.plan(s, _midnight(), TZ, []).size(), 0, "không có gì chờ thì không báo")
	var p := NotifPlan.plan(s, _midnight(), TZ, ["daily_gift"])
	for e in p:
		t.eq(e.kind, "daily_gift", "chỉ kind có trong candidates")
	t.eq(_per_day(p).get(0, 0), 1, "một kind: mỗi kind một lần mỗi ngày")
	var q := NotifPlan.plan(s, _midnight(), TZ, ["lives_full", "bogus_dup", "lives_full"])
	var kinds := {}
	for e in q:
		kinds[e.kind] = true
	t.ok(kinds.has("lives_full") and kinds.has("bogus_dup"), "kind lạ vẫn đi qua, trùng thì gộp")
	var day0 := q.filter(func(e: Dictionary) -> bool: return _day(e) == 0)
	t.eq(day0.size(), 2, "ngày 0: tối đa số kind khác nhau")


func test_candidate_at_and_until(t: T) -> void:
	var s := _save([1140, 1140, 1140])
	# offer_open hết hạn trước giờ báo ngày 0: không được báo
	var expire := _midnight() + 3600
	var p := NotifPlan.plan(s, _midnight(), TZ, [{"kind": "offer_open", "until": expire}])
	t.eq(p.size(), 0, "offer hết hạn sớm thì bỏ")
	# daily_gift chỉ có từ sáng ngày 3
	var from := _midnight() + 3 * Clock.DAY_SEC
	var q := NotifPlan.plan(s, _midnight(), TZ, [{"kind": "daily_gift", "at": from}])
	t.ok(q.size() > 0, "có lịch từ ngày 3")
	t.ok(int(q[0].at) >= from, "không báo trước thời điểm có thật")
	t.eq(_day(q[0]), 3, "ngày đầu là ngày 3")


func test_skips_past_and_sorted(t: T) -> void:
	var s := _save([1140, 1140, 1140])
	var now := _midnight() + 20 * 3600 # 20:00 ngày 0, đã qua 18:45
	var p := NotifPlan.plan(s, now, TZ, ALL)
	var prev := 0
	for e in p:
		t.ok(int(e.at) > now, "chỉ tương lai")
		t.ok(int(e.at) >= prev, "tăng dần")
		prev = int(e.at)
	t.eq(_per_day(p).get(0, 0), 0, "ngày 0 hết khung giờ")


func test_plan_recorded(t: T) -> void:
	var s := _save([1140, 1140, 1140])
	var p := NotifPlan.plan(s, _midnight(), TZ, ALL)
	t.eq(s.notify.plan.size(), p.size(), "ghi vào s.notify.plan")
	t.eq(s.notify.plan[0].at, p[0].at, "cùng nội dung")


func test_note_open(t: T) -> void:
	var s := SaveSchema.defaults()
	# 19:30 địa phương
	NotifPlan.note_open(s, _midnight() + 19 * 3600 + 1800, TZ)
	t.eq(s.notify.hours, [1170], "phút trong ngày theo giờ địa phương")
	for i in 20:
		NotifPlan.note_open(s, _midnight() + i * 60, TZ)
	t.eq(s.notify.hours.size(), NotifPlan.HISTORY_MAX, "giữ tối đa HISTORY_MAX")
	t.eq(s.notify.hours[NotifPlan.HISTORY_MAX - 1], 19, "giữ lần mới nhất")


func test_learns_from_opens(t: T) -> void:
	var s := SaveSchema.defaults()
	s.meta.install_at = BASE
	for i in 5:
		NotifPlan.note_open(s, _midnight() + i * Clock.DAY_SEC + 9 * 3600 + 600, TZ) # 09:10
	var p := NotifPlan.plan(s, _midnight(), TZ, ["daily_gift"])
	t.eq(_minute(p[0]), 9 * 60 + 10 - 15, "báo trước giờ mở đã học")


func test_note_return_ignored_counts(t: T) -> void:
	var s := SaveSchema.defaults()
	var now := 1_000_000
	s.notify.plan = [{"at": now - 10 * 3600, "kind": "daily_gift"}, {"at": now - 9 * 3600, "kind": "lives_full"}, {"at": now + 3600, "kind": "offer_open"}]
	NotifPlan.note_return(s, now, "")
	t.eq(s.notify.ignored, 2, "hai thông báo đã tới giờ mà không ai nhận")
	t.eq(s.notify.plan, [], "xoá lịch cũ")
	NotifPlan.note_return(s, now, "")
	t.eq(s.notify.ignored, 2, "không có lịch thì không đổi")


func test_note_return_response_resets(t: T) -> void:
	var s := SaveSchema.defaults()
	var now := 1_000_000
	s.notify.ignored = 5
	s.notify.plan = [{"at": now - 3600, "kind": "daily_gift"}]
	NotifPlan.note_return(s, now, "daily_gift")
	t.eq(s.notify.ignored, 0, "mở từ thông báo")
	s.notify.ignored = 5
	s.notify.plan = [{"at": now - 3600, "kind": "daily_gift"}, {"at": now - 8 * 3600, "kind": "lives_full"}]
	NotifPlan.note_return(s, now, "")
	t.eq(s.notify.ignored, 0, "quay lại trong 4 giờ cũng là phản hồi")
	s.notify.ignored = 5
	s.notify.plan = [{"at": now - 5 * 3600, "kind": "daily_gift"}]
	NotifPlan.note_return(s, now, "")
	t.eq(s.notify.ignored, 6, "quá 4 giờ thì tính bỏ qua")


func test_note_return_notifications_disabled(t: T) -> void:
	var s := SaveSchema.defaults()
	var now := 1_000_000
	s.notify.ignored = 3
	s.notify.plan = [{"at": now - 6 * 3600, "kind": "daily_gift"}]
	NotifPlan.note_return(s, now, "", false)
	t.eq(s.notify.ignored, 3, "thông báo tắt trên máy: không đếm bỏ qua")
	t.eq(s.notify.plan, [], "vẫn xoá lịch")


# --- thông báo buổi tối 20:00 ---

const EVENING := 10


func _evenings(p: Array) -> Array:
	return p.filter(func(e: Dictionary) -> bool: return e.kind == "evening")


func _others(p: Array) -> Array:
	return p.filter(func(e: Dictionary) -> bool: return e.kind != "evening")


func test_evening_every_day_at_20(t: T) -> void:
	Config.reset()
	var s := _save([])
	var p := NotifPlan.plan(s, _midnight(), TZ, [], EVENING)
	t.eq(p.size(), int(Config.NOTIF.evening_days), "không có gì chờ vẫn báo buổi tối, đủ evening_days ngày")
	for i in p.size():
		t.eq(_day(p[i]), i, "mỗi ngày một lần")
		t.eq(_minute(p[i]), 20 * 60, "đúng 20:00 giờ địa phương")
		t.ok(int(p[i].pick) >= 0 and int(p[i].pick) < EVENING, "pick trong khoảng")
	t.eq(NotifPlan.plan(s, _midnight(), TZ, []).size(), 0, "không truyền số nội dung thì tắt")


func test_evening_after_20_starts_tomorrow(t: T) -> void:
	Config.reset()
	var s := _save([])
	var p := NotifPlan.plan(s, _midnight() + 20 * 3600 + 60, TZ, [], EVENING)
	t.eq(_day(p[0]), 1, "qua 20:00 thì bắt đầu từ mai")


func test_evening_not_limited_to_day_30(t: T) -> void:
	Config.reset()
	var s := _save([1140, 1140, 1140])
	var now := _midnight() + 60 * Clock.DAY_SEC
	var p := NotifPlan.plan(s, now, TZ, ALL, EVENING)
	t.eq(_others(p).size(), 0, "quá ngày 30: hết lịch thường")
	t.eq(_evenings(p).size(), int(Config.NOTIF.evening_days), "buổi tối vẫn báo mỗi ngày")


func test_evening_counts_in_daily_cap(t: T) -> void:
	Config.reset()
	var s := _save([540, 545, 550, 720, 725, 730, 960, 965, 970])
	var p := NotifPlan.plan(s, _midnight(), TZ, ALL, EVENING)
	var d := _per_day(p)
	var o := _per_day(_others(p))
	for i in 7:
		t.eq(d.get(i, 0), int(Config.NOTIF.first_week_per_day), "ngày %d: tổng không vượt mức tuần đầu" % i)
		t.eq(o.get(i, 0), int(Config.NOTIF.first_week_per_day) - 1, "ngày %d: buổi tối chiếm một suất" % i)
	for i in range(7, 30):
		t.eq(d.get(i, 0), 1, "ngày %d: chỉ thông báo buổi tối" % i)


func test_evening_keeps_gap(t: T) -> void:
	Config.reset()
	var s := _save([1140, 1145, 1150, 1260, 1265, 1270]) # mở quanh 19:00 và 21:00
	var p := NotifPlan.plan(s, _midnight(), TZ, ALL, EVENING)
	var o := _others(p)
	t.ok(o.size() > 0, "vẫn có lịch thường")
	for e in o:
		t.ok(absi(_minute(e) - 20 * 60) >= NotifPlan.MIN_GAP_MIN, "cách 20:00 đủ xa: %d" % _minute(e))
	t.eq(_minute(o[0]), 20 * 60 - NotifPlan.MIN_GAP_MIN, "giờ 18:50 dời về 18:00")
	t.eq(_per_day(o).get(0, 0), 2, "giờ 20:50 dời ra 22:00")


func test_evening_quiet(t: T) -> void:
	Config.reset()
	var s := _save([540, 540, 540, 720, 720, 720])
	s.notify.ignored = 9
	var p := NotifPlan.plan(s, _midnight(), TZ, ALL, EVENING)
	t.eq(_others(p).size(), 0, "bị bỏ qua 9 lần: chỉ còn buổi tối")
	t.eq(_per_day(p).get(0, 0), 1, "1 lần mỗi ngày")


func test_evening_off_by_config(t: T) -> void:
	Config.reset()
	Config.NOTIF.evening_days = 0
	var s := _save([1140, 1140, 1140])
	var p := NotifPlan.plan(s, _midnight(), TZ, ALL, EVENING)
	Config.reset()
	t.eq(_evenings(p).size(), 0, "evening_days 0 thì tắt")
	t.eq(_per_day(p).get(7, 0), 1, "lịch thường như cũ")


func test_evening_pick_random_per_day(t: T) -> void:
	var day0 := Clock.day_number(BASE, TZ)
	var prev := -1
	var seen := {}
	var block0 := floori(float(day0) / EVENING) * EVENING
	for d in range(block0, block0 + 300):
		var k := NotifPlan.evening_pick(d, BASE, EVENING)
		t.ok(k >= 0 and k < EVENING, "pick trong khoảng")
		t.ok(k != prev, "ngày %d không trùng hôm trước" % d)
		t.eq(NotifPlan.evening_pick(d, BASE, EVENING), k, "cố định theo ngày")
		prev = k
		seen[k] = true
		if (d - block0) % EVENING == EVENING - 1:
			t.eq(seen.size(), EVENING, "mỗi %d ngày đủ %d nội dung" % [EVENING, EVENING])
			seen = {}
	var same := 0
	for d in range(day0, day0 + 30):
		if NotifPlan.evening_pick(d, BASE, EVENING) == NotifPlan.evening_pick(d, BASE + 1, EVENING):
			same += 1
	t.ok(same < 30, "máy khác thứ tự khác")
	var order: Array[int] = []
	for d in range(day0, day0 + 10):
		order.append(NotifPlan.evening_pick(d, BASE, EVENING))
	t.ok(order != [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], "không theo thứ tự cố định")
