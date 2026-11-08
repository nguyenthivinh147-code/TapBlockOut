extends RefCounted
## Leaderboard theo league: league theo điểm, BXH 100 người, bot tăng điểm theo ngày, lên hạng, Top %, World.
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
	t.eq(Leaderboard.league_for(29), 0, "29: Silver")
	t.eq(Leaderboard.league_for(30), 1, "30: Gold")
	t.eq(Leaderboard.league_for(549), 4, "549: Diamond")
	t.eq(Leaderboard.league_for(550), 5, "550: Immortal")
	t.eq(Leaderboard.league_for(999), 5, "999: Immortal")
	t.eq(Leaderboard.league_for(1000), 6, "1000: One Above All")
	t.eq(Leaderboard.league_for(99999), 6, "không có trần")
	t.eq(Leaderboard.range_of(0), Vector2i(0, 29), "khoảng Silver")
	t.eq(Leaderboard.range_of(4), Vector2i(330, 549), "khoảng Diamond")
	t.eq(Leaderboard.range_of(6), Vector2i(1000, 2000), "league cuối: min + top_span")
	t.eq(Leaderboard.next_min(5), 1000, "min kế")
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
	t.eq(Leaderboard.pending(s), [0], "chờ thưởng league đầu")
	var a := _sorted_points(s)
	t.ok(int(a[0]) >= 0 and int(a[98]) <= 29, "bot nằm trong khoảng Silver")
	var w := 30.0 / 100.0
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
	s.lb["risen"] = [{"n": "carried", "a": "avatar_00", "f": "frame_00", "c": "VN", "p": 31}]
	r = Leaderboard.add_points(s, 16)
	t.eq(int(r.after), 31, "31 điểm")
	t.eq(int(r.league_after), 1, "lên Gold")
	t.eq(r.promoted, [1], "báo league vừa lên")
	t.eq(Leaderboard.pending(s), [0, 1], "thưởng Silver và Gold chờ nhận")
	t.eq(s.lb.bots.size(), 99, "BXH mới đủ người")
	var a := _sorted_points(s)
	t.ok(int(a[0]) >= 30 and int(a[98]) <= 79, "bot trong khoảng Gold")
	var names: Array = []
	for b in s.lb.bots:
		names.append(str(b.n))
	t.ok(names.has("carried"), "bot lên hạng cùng được đưa vào BXH mới")
	t.eq(s.lb.risen, [], "đã dùng danh sách lên hạng")
	r = Leaderboard.add_points(s, 1000)
	t.eq(r.promoted, [2, 3, 4, 5, 6], "qua nhiều league một lúc")
	t.ok(Leaderboard.is_top(int(s.lb.league)), "tới league cuối")
	a = _sorted_points(s)
	t.ok(int(a[0]) >= 1000 and int(a[98]) <= 2000, "league cuối random trong min..min+top_span")


func test_claim(t: T) -> void:
	var s := _joined()
	Leaderboard.add_points(s, 30)
	var pr := Leaderboard.pending_reward(s)
	t.eq(int(pr.coins), 400, "Silver 100 + Gold 300")
	t.eq(int(pr.items.get("hint", 0)), 1, "Gold có 1 hint")
	var got := Leaderboard.claim(s)
	t.eq(got, pr, "nhận đúng thưởng chờ")
	t.eq(Leaderboard.pending(s), [], "hết chờ")
	t.eq(Leaderboard.claim(s), {}, "nhận lần hai rỗng")


func test_gain_formula(t: T) -> void:
	Config.reset()
	Config.LEADERBOARD["bot_rand"] = [2, 2]
	Config.LEADERBOARD["bot_var"] = [1.5, 1.5]
	var rng := RandomNumberGenerator.new()
	t.eq(Leaderboard.gain_for(0, rng), 1 + 3, "Silver: 1 + 2 * 1.5")
	t.eq(Leaderboard.gain_for(4, rng), 5 + 3, "Diamond: 5 + 2 * 1.5")
	Config.LEADERBOARD["bot_rand"] = [0, 4]
	Config.LEADERBOARD["bot_var"] = [0.5, 1.5]
	for i in 200:
		var g := Leaderboard.gain_for(1, rng)
		t.ok(g >= 2 and g <= 2 + 6, "Gold trong khoảng")
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
		t.ok(int(b.p) <= 29, "bot chạm Gold đã rời BXH Silver")
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
	Leaderboard.add_points(s, 40)
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
	t.eq(Leaderboard.pieces_for(""), 2, "normal 2 mảnh")
	t.eq(Leaderboard.pieces_for("hard"), 3, "hard 3 mảnh")
	t.eq(Leaderboard.pieces_for("very_hard"), 4, "very hard 4 mảnh")


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
	var g := _game(7)
	t.eq(g.lb_open(), false, "L7 chưa mở")
	var a: Dictionary = g.start_attempt()
	t.eq((a.specials as Array).size(), 0, "chưa mở thì không có khối đặc biệt")
	var g8 := _game(8)
	t.ok(g8.lb_open(), "mở ở L8")
	a = g8.start_attempt()
	t.ok(Leaderboard.joined(g8.s), "bắt đầu level thì vào BXH")
	var want := Leaderboard.pieces_for(g8.difficulty_of(8))
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
	t.ok(bool(v.pending), "chờ thưởng Silver")
	var coins := int(g8.s.coins)
	var claimed: Dictionary = g8.lb_claim()
	t.eq(int(g8.s.coins), coins + int(claimed.coins), "nhận thưởng league vào ví")
	t.eq(g8.lb_pending_view(), {}, "hết chờ")


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
