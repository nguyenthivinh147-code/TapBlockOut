extends RefCounted
const T := preload("res://tests/t.gd")
const SaveSchema := preload("res://src/meta/save_schema.gd")
const NotifPlan := preload("res://src/meta/notif_plan.gd")
const Clock := preload("res://src/meta/clock.gd")

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
