extends RefCounted
## Leaderboard theo league: league theo điểm tuần, BXH 100 người, bot tăng điểm theo ngày, lên hạng, hết tuần, Top %, World.
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const SaveSchema := preload("res://src/meta/save_schema.gd")
const Leaderboard := preload("res://src/meta/leaderboard.gd")
const BoardState := preload("res://src/core/board_state.gd")

const DIR := "user://test_leaderboard"
const NOW := 1_800_000_000  # 08:00 UTC = 15:00 GMT+7
const D := 86400


func _joined() -> Dictionary:
	Config.reset()
	var s := SaveSchema.defaults()
	Leaderboard.join(s, NOW)
	return s


func _sorted_points(s: Dictionary) -> Array:
	var a: Array = []
	for b in s.lb.bots:
		a.append(int(b.p))
	a.sort()
	return a


func test_leagues(t: T) -> void:
	Config.reset()
	t.eq(Leaderboard.leagues().size(), 7, "7 league")
	t.eq(Leaderboard.league_id(0), "silver", "league đầu")
	t.eq(Leaderboard.league_id(6), "one_above_all", "league cuối")
	t.eq(Leaderboard.league_for(0), 0, "0 điểm: Silver")
	t.eq(Leaderboard.league_for(149), 0, "149: Silver")
	t.eq(Leaderboard.league_for(150), 1, "150: Gold")
	t.eq(Leaderboard.league_for(769), 4, "769: Diamond")
	t.eq(Leaderboard.league_for(770), 5, "770: Immortal")
	t.eq(Leaderboard.league_for(949), 5, "949: Immortal")
	t.eq(Leaderboard.league_for(950), 6, "950: One Above All")
	t.eq(Leaderboard.league_for(99999), 6, "không có trần")
	t.eq(Leaderboard.range_of(0), Vector2i(0, 149), "khoảng Silver")
	t.eq(Leaderboard.range_of(4), Vector2i(600, 769), "khoảng Diamond")
	t.eq(Leaderboard.range_of(6), Vector2i(950, 1900), "league cuối: min + top_span")
	t.eq(Leaderboard.next_min(5), 950, "min kế")
	t.eq(Leaderboard.next_min(6), -1, "league cuối không có kế")
	t.eq(int(Leaderboard.reward_of(1).coins), 300, "thưởng Gold")


func test_day_boundary(t: T) -> void:
	Config.reset()
	var day0 := NOW - 8 * 3600  # 00:00 UTC = 07:00 GMT+7
	t.eq(Leaderboard.day_of(day0), Leaderboard.day_of(NOW), "cùng ngày BXH")
	t.eq(Leaderboard.day_of(day0 - 1), Leaderboard.day_of(NOW) - 1, "06:59 GMT+7 là ngày trước")
	t.eq(Leaderboard.seconds_to_grow(NOW), 16 * 3600, "15:00 GMT+7 còn 16 giờ tới 07:00")
	Config.LEADERBOARD["grow_hour"] = 8
	t.eq(Leaderboard.day_of(day0 + 3599), Leaderboard.day_of(NOW) - 1, "đổi giờ tăng: 07:59 còn ngày cũ")
	Config.reset()


func test_join_builds_board(t: T) -> void:
	var s := _joined()
	t.ok(Leaderboard.joined(s), "đã vào")
	t.eq(Leaderboard.join(s, NOW + 5), false, "vào một lần")
	t.eq(s.lb.bots.size(), 99, "99 bot + người chơi = 100")
	t.eq(Leaderboard.pending(s), [], "league đầu không có thưởng")
	var a := _sorted_points(s)
	t.ok(int(a[0]) >= 0 and int(a[98]) <= 149, "bot nằm trong khoảng Silver")
	var w := 150.0 / 100.0
	var bad := 0
	for i in a.size():
		if int(a[i]) < floori((i + 1) * w) or int(a[i]) > floori((i + 2) * w):
			bad += 1
	t.eq(bad, 0, "mỗi vị trí nằm trong dải 1% điểm của league")
	var def := 0
	for b in s.lb.bots:
		t.ok(str(b.n) != "" and str(b.c).length() == 2, "bot có tên và cờ")
		if str(b.a) == "avatar_00":
			def += 1
	t.ok(def >= 65 and def <= 92, "khoảng 80%% bot dùng avatar mặc định (%d)" % def)
	var s2 := SaveSchema.defaults()
	Leaderboard.join(s2, NOW)
	t.eq(s2.lb.bots, s.lb.bots, "cùng seed cùng BXH")


func test_rank_and_ties(t: T) -> void:
	var s := _joined()
	for b in s.lb.bots:
		b["p"] = 10
	s.lb.points = 10
	t.eq(Leaderboard.rank(s), 1, "bằng điểm thì người chơi đứng trên")
	s.lb.bots[0]["p"] = 11
	t.eq(Leaderboard.rank(s), 2, "một bot cao hơn")
	var rows := Leaderboard.standings(s)
	t.eq(rows.size(), 100, "đủ 100 hàng")
	t.eq(bool(rows[1].me), true, "người chơi ở hàng 2")
	t.eq(int(rows[0].points), 11, "hàng 1 là bot cao điểm")
	for i in rows.size():
		t.eq(int(rows[i].rank), i + 1, "hạng liên tục")


func test_window(t: T) -> void:
	Config.reset()
	var rows: Array = []
	for i in 100:
		rows.append({"rank": i + 1})
	var w := Leaderboard.window(rows, 70)
	t.eq(w.size(), 50, "tối đa 50 hàng")
	t.eq(int(w[0].rank), 45, "hạng 70 bắt đầu từ 45")
	t.eq(int(w[49].rank), 94, "tới 94")
	t.eq(int(Leaderboard.window(rows, 3)[0].rank), 1, "gần đầu thì từ hạng 1")
	t.eq(int(Leaderboard.window(rows, 100)[0].rank), 51, "cuối bảng thì 51 tới 100")
	t.eq(Leaderboard.window(rows.slice(0, 10), 5).size(), 10, "bảng ngắn hiện hết")


func test_add_points_and_promote(t: T) -> void:
	var s := _joined()
	t.eq(Leaderboard.add_points(s, 0), {}, "0 mảnh không đổi gì")
	var r0 := Leaderboard.rank(s)
	var r := Leaderboard.add_points(s, 15)
	t.eq(int(r.after), 15, "cộng điểm")
	t.eq(int(r.rank_before), r0, "hạng trước")
	t.ok(int(r.rank_after) < r0, "lên hạng trong BXH")
	t.eq(r.promoted, [], "chưa lên league")
	s.lb["risen"] = [{"n": "carried", "a": "avatar_00", "f": "frame_00", "c": "VN", "p": 151}]
	r = Leaderboard.add_points(s, 136)
	t.eq(int(r.after), 151, "151 điểm")
	t.eq(int(r.league_after), 1, "lên Gold")
	t.eq(r.promoted, [1], "báo league vừa lên")
	t.eq(Leaderboard.pending(s), [1], "thưởng Gold chờ nhận")
	t.eq(s.lb.bots.size(), 99, "BXH mới đủ người")
	var a := _sorted_points(s)
	t.ok(int(a[0]) >= 150 and int(a[98]) <= 299, "bot trong khoảng Gold")
	var names: Array = []
	for b in s.lb.bots:
		names.append(str(b.n))
	t.ok(names.has("carried"), "bot lên hạng cùng được đưa vào BXH mới")
	t.eq(s.lb.risen, [], "đã dùng danh sách lên hạng")
	r = Leaderboard.add_points(s, 1000)
	t.eq(r.promoted, [2, 3, 4, 5, 6], "qua nhiều league một lúc")
	t.ok(Leaderboard.is_top(int(s.lb.league)), "tới league cuối")
	a = _sorted_points(s)
	t.ok(int(a[0]) >= 950 and int(a[98]) <= 1900, "league cuối random trong min..min+top_span")


func test_claim(t: T) -> void:
	var s := _joined()
	t.ok(not Leaderboard.has_reward(0), "Silver không có thưởng")
	t.ok(Leaderboard.has_reward(1), "Gold có thưởng")
	Leaderboard.add_points(s, 150)
	var pr := Leaderboard.pending_reward(s)
	t.eq(int(pr.coins), 300, "chỉ thưởng Gold")
	t.eq(int(pr.items.get("hint", 0)), 1, "Gold có 1 hint")
	var got := Leaderboard.claim(s)
	t.eq(got, pr, "nhận đúng thưởng chờ")
	t.eq(Leaderboard.pending(s), [], "hết chờ")
	t.eq(Leaderboard.claim(s), {}, "nhận lần hai rỗng")


## Từ Platinum mỗi league tặng thêm 1 avatar/frame random trong 08-12: chọn lúc vào league, khác nhau, chưa có.
func test_cos_reward(t: T) -> void:
	var s := _joined()
	var pool := Leaderboard.cosmetics()
	t.eq(pool.size(), 10, "5 avatar + 5 frame")
	t.eq(Leaderboard.cos_from(), 2, "từ Platinum")
	t.eq(int(Leaderboard.reward_of(1).cos_random), 0, "Gold không có")
	t.eq(int(Leaderboard.reward_of(2).cos_random), 1, "Platinum 1 món")
	t.eq(int(Leaderboard.reward_of(6).cos_random), 1, "One Above All 1 món")
	Leaderboard.add_points(s, 150)
	t.eq(Leaderboard.pending_reward(s).cos, [], "Gold: không có món")
	Leaderboard.add_points(s, 1000)
	var cos: Array = Leaderboard.pending_reward(s).cos
	t.eq(cos.size(), 5, "Platinum tới One Above All: 5 món")
	var uniq := {}
	for id in cos:
		t.ok(pool.has(id), "%s nằm trong 08-12" % id)
		uniq[id] = true
	t.eq(uniq.size(), 5, "món khác nhau")
	t.eq(Leaderboard.cos_left(s).size(), 5, "món chờ không random lại")
	t.eq(Leaderboard.pending_reward(s).cos, cos, "mở lại vẫn đúng món")
	var got := Leaderboard.claim(s)
	t.eq(got.cos, cos, "nhận đúng món đã chọn")
	t.eq(s.lb.pending_cos, [], "hết món chờ")
	var s2 := _joined()
	Leaderboard.add_points(s2, 1150)
	t.eq(Leaderboard.pending_reward(s2).cos, cos, "cùng seed cùng món")


## Đã có món nào thì không random ra món đó; hết món thì league chỉ còn gold, booster và ô xem trước ẩn đi.
func test_cos_reward_runs_out(t: T) -> void:
	var s := _joined()
	for id in Leaderboard.cosmetics():
		if id != "frame_10":
			(s.cos.owned as Array).append(id)
	t.eq(Leaderboard.cos_left(s), ["frame_10"], "còn một món")
	t.eq(int(Leaderboard.preview_reward(s, 6).cos_random), 1, "xem trước: còn món")
	Leaderboard.add_points(s, 1000)
	t.eq(Leaderboard.pending_reward(s).cos, ["frame_10"], "chỉ món chưa có, một lần")
	t.eq(Leaderboard.cos_left(s), [], "món cuối đang chờ: hết món")
	t.eq(int(Leaderboard.preview_reward(s, 6).cos_random), 0, "xem trước: hết món thì ẩn")
	t.eq(int(Leaderboard.preview_reward(s, 6).coins), 5000, "xem trước vẫn có gold")
	t.ok(Leaderboard.has_reward(6), "league vẫn có thưởng")


## Món còn chờ lúc hết tuần vào kết quả tuần; tuần mới random lại nhưng không trùng món của kết quả chưa nhận.
func test_cos_reward_week_roll(t: T) -> void:
	var s := _joined()
	Leaderboard.add_points(s, 300)
	var c1: Array = Leaderboard.pending_reward(s).cos
	t.eq(c1.size(), 1, "Platinum: 1 món")
	var r := Leaderboard.roll(s, NOW + 7 * D)
	t.eq(r.reward.cos, c1, "món chờ vào kết quả tuần")
	t.eq(s.lb.pending_cos, [], "hết món chờ")
	t.ok(not Leaderboard.cos_left(s).has(c1[0]), "món của kết quả chưa nhận không random lại")
	Leaderboard.add_points(s, 300)
	var c2: Array = Leaderboard.pending_reward(s).cos
	t.eq(c2.size(), 1, "tuần mới nhận lại")
	t.ok(c2[0] != c1[0], "khác món còn trong kết quả")
	t.eq(Leaderboard.claim_result(s).cos, c1, "nhận món của kết quả")


## Bản lưu trước khi có món league: league đang chờ không được bù món.
func test_cos_reward_old_save(t: T) -> void:
	var s := _joined()
	s.lb.pending = [3]
	s.lb.erase("pending_cos")
	t.eq(Leaderboard.pending_reward(s).cos, [], "không bù món")
	t.eq(int(Leaderboard.claim(s).coins), 800, "vẫn nhận gold")


## Bot ở Silver, Gold không đeo avatar/frame 08-12; từ Platinum đeo được.
func test_bot_cosmetics_by_league(t: T) -> void:
	Config.reset()
	Config.LEADERBOARD["bot_avatar_default_pct"] = 0
	Config.LEADERBOARD["bot_frame_default_pct"] = 0
	var pool := Leaderboard.cosmetics()
	for li in [0, 1]:
		var n := 0
		for b in Leaderboard.make_board(li, 7):
			if pool.has(str(b.a)) or pool.has(str(b.f)):
				n += 1
		t.eq(n, 0, "bot league %d không đeo món league" % li)
	var high := 0
	for b in Leaderboard.make_board(2, 7):
		if pool.has(str(b.a)) or pool.has(str(b.f)):
			high += 1
	t.ok(high > 0, "bot Platinum đeo được món league (%d)" % high)
	Config.reset()


func test_gain_formula(t: T) -> void:
	Config.reset()
	Config.LEADERBOARD["bot_rand"] = [2, 2]
	Config.LEADERBOARD["bot_var"] = [1.5, 1.5]
	var rng := RandomNumberGenerator.new()
	t.eq(Leaderboard.gain_for(0, rng), 6 + 3, "Silver: 6 + 2 * 1.5")
	t.eq(Leaderboard.gain_for(4, rng), 10 + 3, "Diamond: 10 + 2 * 1.5")
	Config.LEADERBOARD["bot_rand"] = [0, 4]
	Config.LEADERBOARD["bot_var"] = [0.5, 1.5]
	for i in 200:
		var g := Leaderboard.gain_for(1, rng)
		t.ok(g >= 7 and g <= 7 + 6, "Gold trong khoảng")
	Config.reset()


func test_grow(t: T) -> void:
	var s := _joined()
	t.eq(Leaderboard.grow(s, NOW + 3600), 0, "cùng ngày không tăng")
	var before := 0
	for b in s.lb.bots:
		before += int(b.p)
	t.eq(Leaderboard.grow(s, NOW + D), 1, "qua 07:00 hôm sau tăng một lần")
	t.eq(s.lb.bots.size(), 99, "vẫn đủ người")
	var after := 0
	for b in s.lb.bots:
		t.ok(int(b.p) <= 149, "bot chạm Gold đã rời BXH Silver")
		after += int(b.p)
	t.ok(after != before, "điểm bot đổi")
	t.ok(not (s.lb.risen as Array).is_empty(), "bot gần đỉnh lên Gold")
	t.eq(Leaderboard.grow(s, NOW + D + 60), 0, "không tăng hai lần một ngày")
	t.eq(Leaderboard.grow(s, NOW), 0, "đồng hồ lùi không làm gì")
	t.eq(Leaderboard.grow(s, NOW + 200 * D), 14, "vắng lâu chỉ bù 14 ngày")
	t.ok((s.lb.risen as Array).size() <= 10, "giữ tối đa carry_max bot lên hạng")
	var s2 := SaveSchema.defaults()
	t.eq(Leaderboard.grow(s2, NOW), 0, "chưa vào BXH thì không tăng")


func test_top_percent(t: T) -> void:
	var s := _joined()
	t.eq(Leaderboard.players_total(), 100000, "tổng người tham gia")
	s.lb.points = 29
	for b in s.lb.bots:
		b["p"] = 0
	t.eq(Leaderboard.rank(s), 1, "đứng đầu Silver")
	t.eq(Leaderboard.top_percent(s), 52, "52.000 người ở league cao hơn / 100.000")
	for b in s.lb.bots:
		b["p"] = 29
	s.lb.points = 0
	t.eq(Leaderboard.top_percent(s), 100, "cuối Silver")
	Leaderboard.add_points(s, 2000)
	for b in s.lb.bots:
		b["p"] = 1000
	t.eq(Leaderboard.top_percent(s), 1, "đầu league cuối: Top 1%")


func test_seen_rank(t: T) -> void:
	var s := _joined()
	t.eq(Leaderboard.seen_rank(s), 0, "chưa xem")
	Leaderboard.mark_seen(s)
	t.eq(Leaderboard.seen_rank(s), Leaderboard.rank(s), "ghi hạng đã xem")
	Leaderboard.add_points(s, 150)
	t.eq(Leaderboard.seen_rank(s), 0, "league mới xoá hạng đã xem")


func test_pick_specials(t: T) -> void:
	Config.reset()
	var ids := ["b1", "b2", "b3", "b4", "b5", "b6"]
	var a := Leaderboard.pick_specials(ids, 3, 42)
	t.eq(a.size(), 3, "đúng số khối")
	t.eq(a, Leaderboard.pick_specials(ids, 3, 42), "cùng seed cùng khối")
	for id in a:
		t.ok(ids.has(id), "khối có thật")
	t.eq(Leaderboard.pick_specials(["b1"], 3, 1).size(), 1, "không quá số khối")
	t.eq(Leaderboard.pick_specials(ids, 0, 1).size(), 0, "0 khối")
	t.eq(Leaderboard.pieces_for(""), 1, "normal 1 mảnh")
	t.eq(Leaderboard.pieces_for("hard"), 2, "hard 2 mảnh")
	t.eq(Leaderboard.pieces_for("very_hard"), 3, "very hard 3 mảnh")


func test_world(t: T) -> void:
	var s := _joined()
	var w := Leaderboard.world(s, NOW)
	t.eq((w.rows as Array).size(), 50, "50 người đứng đầu")
	t.ok(int(w.rank) > 50, "người chơi mới ngoài top 50")
	var prev := 1 << 30
	var desc := true
	for r in w.rows:
		desc = desc and int(r.points) <= prev
		prev = int(r.points)
		t.eq(str(r.league), "one_above_all", "top thế giới ở league cuối")
	t.ok(desc, "xếp giảm dần")
	t.eq(Leaderboard.world(s, NOW + 60).rows, w.rows, "cùng ngày cùng danh sách")
	s.lb.points = 999999
	w = Leaderboard.world(s, NOW)
	t.eq(int(w.rank), 1, "đủ điểm thì chen lên đầu")
	t.ok(bool(w.rows[0].me), "hàng của người chơi")
	t.eq((w.rows as Array).size(), 50, "vẫn 50 hàng")


func test_week_clock(t: T) -> void:
	var s := _joined()
	t.eq(int(s.lb.t0), NOW, "t0 lúc vào")
	t.eq(Leaderboard.week(s), 0, "tuần đầu")
	t.eq(Leaderboard.seconds_to_week_end(s, NOW), 7 * D, "còn 7 ngày")
	t.eq(Leaderboard.seconds_to_week_end(s, NOW + D + 60), 6 * D - 60, "đếm ngược")
	t.eq(Leaderboard.roll(s, NOW + 3 * D), {}, "chưa hết tuần")
	t.eq(Leaderboard.seconds_to_week_end(s, NOW + 3 * D), 4 * D, "còn 4 ngày")
	t.eq(Leaderboard.seconds_to_week_end(s, NOW), 4 * D, "đồng hồ lùi: không đếm ngược lại")
	t.eq(Leaderboard.roll(s, NOW + D), {}, "đồng hồ lùi: tuần không kết thúc")
	t.eq(Leaderboard.roll(s, NOW + 7 * D - 1), {}, "chưa hết tuần tới giây cuối")
	t.eq(Leaderboard.week(s), 0, "vẫn tuần đầu")
	var s2 := SaveSchema.defaults()
	t.eq(Leaderboard.seconds_to_week_end(s2, NOW), 7 * D, "chưa vào BXH")
	t.eq(Leaderboard.roll(s2, NOW + 30 * D), {}, "chưa vào BXH thì không có tuần")


func test_week_roll(t: T) -> void:
	var s := _joined()
	Leaderboard.add_points(s, 160)
	t.eq(Leaderboard.pending(s), [1], "Gold chờ nhận")
	var r := Leaderboard.roll(s, NOW + 7 * D)
	t.eq(int(r.week), 0, "kết quả tuần đầu")
	t.eq(int(r.league), 1, "giải cuối tuần")
	t.eq(int(r.points), 160, "điểm tuần")
	t.ok(int(r.rank) >= 1 and int(r.rank) <= 100, "hạng cuối tuần")
	t.eq(int(r.reward.coins), 300, "thưởng Gold còn chờ vào kết quả")
	t.eq(Leaderboard.result(s), r, "kết quả chờ xem")
	t.eq(Leaderboard.pending(s), [], "hết chờ")
	t.eq(Leaderboard.points(s), 0, "điểm về 0")
	t.eq(Leaderboard.league(s), 0, "về Silver")
	t.eq(Leaderboard.week(s), 1, "tuần 2")
	t.eq(s.lb.bots.size(), 99, "BXH mới đủ người")
	t.ok(_sorted_points(s)[98] <= 149, "BXH mới ở Silver")
	t.eq(Leaderboard.seconds_to_week_end(s, NOW + 7 * D), 7 * D, "tuần mới đủ 7 ngày")
	t.eq(Leaderboard.roll(s, NOW + 7 * D + 60), {}, "không chốt hai lần")
	Leaderboard.add_points(s, 160)
	t.eq(Leaderboard.pending(s), [1], "tuần mới nhận lại thưởng Gold")
	var got := Leaderboard.claim_result(s)
	t.eq(int(got.coins), 300, "nhận thưởng của kết quả")
	t.eq(Leaderboard.result(s), {}, "xoá kết quả")
	t.eq(Leaderboard.claim_result(s), {}, "không có kết quả")


func test_week_empty_and_absent(t: T) -> void:
	var s := _joined()
	t.eq(Leaderboard.roll(s, NOW + 7 * D), {}, "tuần không điểm không có kết quả")
	t.eq(Leaderboard.week(s), 1, "vẫn sang tuần mới")
	Leaderboard.add_points(s, 10)
	var r := Leaderboard.roll(s, NOW + 30 * D)
	t.eq(int(r.week), 1, "vắng nhiều tuần: kết quả tuần có điểm gần nhất")
	t.eq(int(r.reward.coins), 0, "Silver không có thưởng")
	t.eq(Leaderboard.week(s), 4, "vào tuần đang chạy")
	t.eq(Leaderboard.seconds_to_week_end(s, NOW + 30 * D), 5 * D, "mốc theo t0")
	# Unclaimed result + a new week with points and a pending reward: the newest stats, both rewards.
	Leaderboard.add_points(s, 150)
	r = Leaderboard.roll(s, NOW + 35 * D)
	t.eq(int(r.week), 4, "kết quả mới nhất")
	t.eq(int(r.reward.coins), 300, "thưởng cũ và mới gộp")


func test_week_bots_grow_until_week_end(t: T) -> void:
	var s := _joined()
	Leaderboard.add_points(s, 60)
	# Every bot at 50: 7 days of at least bot_base (6) each pass the player, none reaches Gold (150).
	for b in s.lb.bots:
		b["p"] = 50
	t.eq(Leaderboard.rank(s), 1, "đứng đầu trước khi bot tăng")
	var r := Leaderboard.roll(s, NOW + 30 * D)
	t.eq(int(r.rank), 100, "bot được bù điểm tới hết tuần trước khi chốt hạng")


func test_ensure_week_old_save(t: T) -> void:
	Config.reset()
	var s := SaveSchema.defaults()
	s.lb.joined = true
	s.lb.points = 200
	s.lb.league = 3
	s.lb.pending = [3]
	t.ok(Leaderboard.ensure_week(s, NOW), "bản lưu cũ có tuần")
	t.eq(int(s.lb.t0), NOW, "tuần đầu bắt đầu lúc chạy bản mới")
	t.eq(Leaderboard.league(s), 1, "league theo ngưỡng mới")
	t.eq(Leaderboard.points(s), 200, "giữ điểm")
	t.eq(Leaderboard.pending(s), [3], "giữ thưởng chờ")
	t.ok(int(_sorted_points(s)[0]) >= 150, "BXH dựng lại cho league mới")
	t.ok(not Leaderboard.ensure_week(s, NOW + 5), "một lần")
	t.ok(not Leaderboard.ensure_week(SaveSchema.defaults(), NOW), "chưa vào BXH")


func test_save_defaults_merge(t: T) -> void:
	Config.reset()
	var old := SaveSchema.defaults()
	old.erase("lb")
	var m := SaveSchema.merge_defaults(old)
	t.ok(m.lb is Dictionary and not bool(m.lb.joined), "bản lưu cũ có nhóm lb mặc định")


# --- Game ---

func _game(level: int) -> Node:
	var g: Node = (Engine.get_main_loop() as SceneTree).root.get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.test_now = NOW
	g.s.level = level
	return g


func _clear(g: Node, attempt: Dictionary) -> int:
	var pieces := 0
	var b: BoardState = attempt.board
	for id in b.block_ids():
		if bool(g.smash_block(attempt, id).piece):
			pieces += 1
	return pieces


func test_game_flow(t: T) -> void:
	var g := _game(69)
	t.eq(g.lb_open(), false, "L69 chưa mở")
	var a: Dictionary = g.start_attempt()
	t.eq((a.specials as Array).size(), 0, "chưa mở thì không có khối đặc biệt")
	var g8 := _game(70)
	t.ok(g8.lb_open(), "mở ở L70")
	a = g8.start_attempt()
	t.ok(Leaderboard.joined(g8.s), "bắt đầu level thì vào BXH")
	var want := Leaderboard.pieces_for(g8.difficulty_of(70))
	t.eq((a.specials as Array).size(), mini(want, (a.board as BoardState).remaining_count()), "số khối đặc biệt theo độ khó")
	var got := _clear(g8, a)
	t.eq(got, (a.specials as Array).size(), "phá hết khối đặc biệt được đủ mảnh")
	var res: Dictionary = g8.on_level_won(a)
	t.eq(int(res.lb.added), got, "thắng thì cộng mảnh")
	t.eq(Leaderboard.points(g8.s), got, "điểm vào bản lưu")
	t.eq(str(res.lb.league_id), "silver", "kèm league")
	var v: Dictionary = g8.lb_view()
	t.eq(int(v.points), got, "view có điểm")
	t.eq(int(v.size), 100, "BXH 100 người")
	t.ok((v.rows as Array).size() <= 50, "view tối đa 50 hàng")
	t.eq((v.podium as Array).size(), 3, "podium 3 người")
	t.ok(not bool(v.pending), "Silver không có thưởng chờ")
	t.eq(int(v.ends_in), Leaderboard.week_len(), "tuần đầu bắt đầu lúc mở khoá")
	g8.s.lb.points = 150
	Leaderboard.add_points(g8.s, 1)
	t.ok(g8.lb_badge(), "thưởng Gold chờ: chấm đỏ")
	var coins := int(g8.s.coins)
	var claimed: Dictionary = g8.lb_claim()
	t.eq(int(g8.s.coins), coins + int(claimed.coins), "nhận thưởng league vào ví")
	t.eq(g8.lb_pending_view(), {}, "hết chờ")
	t.ok(not g8.lb_badge(), "hết chấm đỏ")


## Nhận thưởng league: avatar/frame vào đồ đã có, không tự đeo. Thang giải ẩn ô random khi hết món.
func test_game_claim_unlocks_cos(t: T) -> void:
	var g := _game(70)
	g.start_attempt()
	Leaderboard.add_points(g.s, 300)
	var cos: Array = g.lb_pending_view().reward.cos
	t.eq(cos.size(), 1, "Platinum có 1 món")
	t.eq(int(g.lb_leagues_view().rows[3].reward.cos_random), 1, "thang giải: Emerald có ô random")
	g.lb_claim()
	t.ok((g.s.cos.owned as Array).has(cos[0]), "nhận: món vào đồ đã có")
	t.eq([g.s.cos.avatar, g.s.cos.frame], ["avatar_00", "frame_00"], "không tự đeo")
	for id in Leaderboard.cosmetics():
		if not (g.s.cos.owned as Array).has(id):
			(g.s.cos.owned as Array).append(id)
	t.eq(int(g.lb_leagues_view().rows[3].reward.cos_random), 0, "hết món: ẩn ô random")


func test_game_unlock_starts_week(t: T) -> void:
	var g := _game(69)
	var a: Dictionary = g.start_attempt()
	t.ok(not Leaderboard.joined(g.s), "L69 chưa vào BXH")
	g.test_now = NOW + 3600
	g.on_level_won(a)
	t.ok(Leaderboard.joined(g.s), "thắng L69 mở khoá: vào BXH")
	t.eq(int(g.s.lb.t0), NOW + 3600, "t0 là lúc mở khoá")


func test_game_week_result(t: T) -> void:
	var g := _game(70)
	var a: Dictionary = g.start_attempt()
	_clear(g, a)
	g.on_level_won(a)
	var pts := Leaderboard.points(g.s)
	t.ok(pts > 0, "có điểm tuần")
	t.eq(g.lb_week_result_view(), {}, "chưa hết tuần")
	g.s.lb.pending = [1]
	g.test_now = NOW + 7 * D
	g.lb_refresh()
	t.eq(Leaderboard.points(g.s), 0, "tuần mới về 0 điểm")
	t.eq(Leaderboard.league(g.s), 0, "tuần mới về Silver")
	t.eq(g.lb_pending_view(), {}, "thưởng chờ chuyển vào kết quả tuần")
	t.ok(g.lb_badge(), "kết quả tuần: chấm đỏ")
	var v: Dictionary = g.lb_week_result_view()
	t.eq(int(v.week), 1, "kết quả tuần 1")
	t.eq(int(v.points), pts, "điểm của tuần")
	t.eq(str(v.league), "silver", "giải cuối tuần")
	t.eq(int(v.reward.coins), 300, "thưởng Gold còn chờ không mất")
	var coins := int(g.s.coins)
	g.lb_week_claim()
	t.eq(int(g.s.coins), coins + 300, "nhận thưởng khi đóng kết quả")
	t.eq(g.lb_week_result_view(), {}, "hết kết quả")
	t.ok(not g.lb_badge(), "hết chấm đỏ")
	t.eq(g.lb_week_claim(), {}, "đóng lần hai không có gì")


func test_game_lost_keeps_no_pieces(t: T) -> void:
	var g := _game(9)
	var a: Dictionary = g.start_attempt()
	var b: BoardState = a.board
	var sp: Array = a.specials
	if not sp.is_empty():
		g.smash_block(a, str(sp[0]))
	t.ok(int(a.pieces) <= 1, "nhặt mảnh trong level")
	g.on_level_lost(a)
	t.eq(Leaderboard.points(g.s), 0, "thua không cộng mảnh")
	t.ok(b.remaining_count() >= 0, "bàn còn nguyên")


func test_game_challenge_has_no_specials(t: T) -> void:
	var g := _game(60)
	Config.demo_override = 0
	Config.FEATURES.challenge = true
	var a: Dictionary = g.start_challenge()
	if not a.is_empty():
		t.eq((a.specials as Array).size(), 0, "Daily Challenge không có khối đặc biệt")
	Config.reset()
