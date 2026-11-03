extends RefCounted
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const SaveSchema := preload("res://src/meta/save_schema.gd")
const WeeklyPass := preload("res://src/meta/weekly_pass.gd")

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
	t.near(WeeklyPass.progress_ratio(s), 0.0, 0.0001, "0 key")
	s.weekly.points = 1  # mốc kế là 3
	t.near(WeeklyPass.progress_ratio(s), 1.0 / 3.0, 0.0001, "1/3 tới mốc 3")
	s.weekly.points = 3  # vừa chạm mốc 3, mốc kế là 8
	t.near(WeeklyPass.progress_ratio(s), 0.0, 0.0001, "vừa chạm mốc, bắt đầu đoạn mới")
	s.weekly.points = 5
	t.near(WeeklyPass.progress_ratio(s), 2.0 / 5.0, 0.0001, "2/5 tới mốc 8")
	s.weekly.points = WeeklyPass.last_points() + 7
	t.near(WeeklyPass.progress_ratio(s), 1.0, 0.0001, "qua mốc cuối")
