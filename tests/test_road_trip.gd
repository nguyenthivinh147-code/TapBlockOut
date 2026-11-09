extends RefCounted
## Road Trip (design.md mục 7 "Road Trip"): dữ liệu 400 level, tiến độ và hộp quà, bố cục bản đồ, Game (mở ở L2,
## không mất mạng, không gold, hộp cộng vật phẩm, hồi sinh bằng video), thanh dưới Shop · Home · Road Trip, icon Bảng
## xếp hạng ở Home, màn Road Trip chơi level thật.
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")
const BoardState := preload("res://src/core/board_state.gd")
const LevelData := preload("res://src/core/level_data.gd")
const RoadTrip := preload("res://src/meta/road_trip.gd")
const SaveSchema := preload("res://src/meta/save_schema.gd")

const DIR := "user://test_road_trip"
const NOW := 1800000000
## Main level for tests that need Road Trip open (Config.UNLOCK.road_trip = 70 since 2026-11-09).
const MAIN := 80
## Blocks blocked at the start over all 400 levels before harder levels (18591 of 23061, 80.6%); now at least
## HARDEN_PERCENT % of that (design.md mục 7 "Road Trip", tools/import_road_trip.gd).
const BLOCKED_BEFORE := 18591
const HARDEN_PERCENT := 110


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _plat() -> Node:
	return _tree().root.get_node("Platform")


func _g(level: int = MAIN, rt_level: int = 1) -> Node:
	DirAccess.make_dir_recursive_absolute(DIR)
	var g: Node = _tree().root.get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.test_now = NOW
	g.test_tz = 0
	var p := _plat()
	p.ads.calls.clear()
	p.ads.set_ready(true, true)
	p.iap = MockIap.new()
	g.s.level = level
	g.s.road_trip.level = rt_level
	g.s.road_trip.guide = true
	for k in ["hint", "move", "smash"]:
		g.s.gifted[k] = true
	return g


func _wait_until(cond: Callable, ms: int = 8000) -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await _tree().process_frame
	return cond.call()


func _data(n: int) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RoadTrip.LEVEL_PATH % n))
	return parsed if parsed is Dictionary else {}


## Taps to clear by always taking the first block that can leave; -1 when stuck.
static func _greedy(b: BoardState) -> PackedStringArray:
	var out := PackedStringArray()
	while not b.is_won():
		var id := b.hint()
		if id == "":
			return PackedStringArray()
		out.append(id)
		b.tap(id)
	return out


# --- dữ liệu ---

func test_levels_valid(t: T) -> void:
	var tiers := {1: 0, 2: 0, 3: 0}
	var bad: Array[String] = []
	var sourced: Array[String] = []
	for n in range(1, RoadTrip.levels() + 1):
		var d := _data(n)
		if d.has("source"):
			sourced.append(str(n))
		if d.is_empty() or not LevelData.validate(d).is_empty():
			bad.append(str(n))
			continue
		var diff := int(d.get("difficulty", 0))
		tiers[diff] = int(tiers.get(diff, 0)) + 1
		if bool(d.hard) != (diff >= 2) or int(d.id) != n or int(d.w) < Config.BOARD_W or int(d.h) < Config.BOARD_H \
				or int(d.moves) < (d.blocks as Array).size() or int(d.min_taps) != (d.blocks as Array).size():
			bad.append(str(n))
	t.eq(bad, [], "400 file hợp lệ, MOVES >= số khối")
	t.eq(tiers, {1: 310, 2: 68, 3: 22}, "độ khó 310 Normal, 68 Hard, 22 Super Hard")
	t.eq(sourced, [], "không file nào ghi nguồn (khoá source)")
	t.eq(int(_data(1).moves), 45, "level 1: StepLimit 45")
	t.ok(not FileAccess.file_exists(RoadTrip.LEVEL_PATH % (RoadTrip.levels() + 1)), "không có level 401")


func test_levels_clear_greedy(t: T) -> void:
	# Không có cơ chế nên rút khối nào thoát được trước cũng giải hết; thử mọi level (sau khi làm khó đổi hướng khối).
	var bad: Array[String] = []
	for n in range(1, RoadTrip.levels() + 1):
		var d := _data(n)
		var b := BoardState.new(d)
		var order := _greedy(b)
		if order.size() != (d.blocks as Array).size() or order.size() > int(d.moves) or not b.is_won():
			bad.append(str(n))
	t.eq(bad, [], "giải hết trong đúng số khối lần chạm, không vượt StepLimit")


## Làm khó (design.md mục 7 "Road Trip"): cả 400 level có ít nhất HARDEN_PERCENT % số khối bị chặn lúc đầu của bản
## trước (BLOCKED_BEFORE), mỗi level còn ít nhất một khối thoát được.
func test_levels_blocked_at_start(t: T) -> void:
	var blocked := 0
	var total := 0
	var no_free: Array[String] = []
	for n in range(1, RoadTrip.levels() + 1):
		var b := BoardState.new(_data(n))
		var free := 0
		for id in b.block_ids():
			total += 1
			if b.peek(id) == "blocked":
				blocked += 1
			else:
				free += 1
		if free == 0:
			no_free.append(str(n))
	t.ok(blocked * 100 >= BLOCKED_BEFORE * HARDEN_PERCENT, "khối bị chặn lúc đầu %d/%d" % [blocked, total])
	t.eq(no_free, [], "mỗi level còn khối thoát được")


## Cổng màu: L1-200 mỗi cạnh 2 cổng (8 màu), L201-400 mỗi cạnh 3 cổng (12 màu), mỗi cổng một màu; khối mang màu cổng
## ở cạnh nó thoát ra, cổng chứa nhiều ô của khối nhất.
func test_gate_colors(t: T) -> void:
	var bad: Array[String] = []
	var straddle := 0
	var total := 0
	for n in range(1, RoadTrip.levels() + 1):
		var d := _data(n)
		var per := 2 if n <= 200 else 3
		var seen := {}
		for side in LevelData.SIDES:
			var segs: Array = d.gates.get(side, [])
			if segs.size() != per:
				bad.append("%d/%s: %d cổng" % [n, side, segs.size()])
			for s in segs:
				seen[str(s[0])] = side
		if seen.size() != per * 4:
			bad.append("%d: %d màu" % [n, seen.size()])
		for b in d.blocks:
			total += 1
			var side := str(b.dir)
			var vertical := side == "left" or side == "right"
			var counts := {}
			for c in b.cells:
				var pos := int(c[1]) if vertical else int(c[0])
				for s in d.gates[side]:
					if pos >= int(s[1]) and pos < int(s[2]):
						counts[str(s[0])] = int(counts.get(str(s[0]), 0)) + 1
			if counts.size() > 1:
				straddle += 1
			if seen.get(str(b.color), "") != side or not counts.has(str(b.color)):
				bad.append("%d/%s: màu %s không phải cổng của nó" % [n, str(b.id), str(b.color)])
			elif int(counts[str(b.color)]) < int(counts.values().max()):
				bad.append("%d/%s: không phải cổng chứa nhiều ô nhất" % [n, str(b.id)])
	t.eq(bad, [], "mỗi cổng một màu, khối mang màu cổng nó thoát qua")
	t.ok(straddle * 100 < total, "khối vắt hai cổng dưới 1%% (%d/%d)" % [straddle, total])
	var first := {}
	for s in _data(1).gates.up + _data(1).gates.down + _data(1).gates.left + _data(1).gates.right:
		first[str(s[0])] = true
	t.eq(first.size(), 8, "L1: 8 màu")
	var last := {}
	for s in _data(400).gates.up + _data(400).gates.down + _data(400).gates.left + _data(400).gates.right:
		last[str(s[0])] = true
	t.eq(last.size(), 12, "L400: 12 màu")


## Khối đi theo `dir`, không theo màu: khối vàng ở cổng dưới vẫn đi xuống.
func test_dir_overrides_color(t: T) -> void:
	var d := {"id": 1, "w": 4, "h": 4, "moves": 5, "blocks": [
		{"id": "a", "color": "yellow", "dir": "down", "cells": [[1, 1]]},
		{"id": "b", "color": "red", "dir": "left", "cells": [[2, 2]]}]}
	t.eq(LevelData.validate(d), [] as Array[String], "dir + màu cổng hợp lệ")
	var b := BoardState.new(d)
	t.eq(b.block_view("a").dir, "down", "view có dir")
	t.eq(b.tap("a").kind, "exit", "vàng đi xuống, đường thông")
	var bad := d.duplicate(true)
	bad.blocks[1].erase("dir")
	t.ok(not LevelData.validate(bad).is_empty(), "màu cổng mà thiếu dir thì sai")
	var g := d.duplicate(true)
	g["gates"] = {"up": [["red", 0, 2], ["red", 2, 4]]}
	t.ok(not LevelData.validate(g).is_empty(), "màu cổng trùng thì sai")
	g["gates"] = {"up": [["red", 0, 2], ["teal", 2, 3]]}
	t.ok(not LevelData.validate(g).is_empty(), "cổng không phủ hết cạnh thì sai")


# --- tiến độ, hộp, bố cục ---

func test_progress_and_boxes(t: T) -> void:
	t.eq(RoadTrip.boxes().size(), 16, "16 hộp")
	t.eq(Config.ROAD_TRIP_REWARDS.size(), 16, "16 dòng thưởng")
	t.eq(RoadTrip.progress(1), Vector2i(0, 15), "level 1: 0/15")
	t.eq(RoadTrip.progress(13), Vector2i(12, 15), "level 13: 12/15")
	t.eq(RoadTrip.progress(15), Vector2i(14, 15), "level 15 (hộp): 14/15")
	t.eq(RoadTrip.progress(16), Vector2i(0, 20), "qua hộp 15: 0/20 tới hộp 35")
	t.eq(RoadTrip.progress(400), Vector2i(20, 21), "level 400 (hộp cuối)")
	t.eq(RoadTrip.progress(401), Vector2i.ZERO, "đi hết: không còn hộp")
	t.eq(RoadTrip.reward(0), {"hint": 1}, "hộp 1: 1 Hint")
	t.eq(RoadTrip.reward(15), {"hint": 1, "smash": 1, "move": 1}, "hộp 16: đủ ba")
	var total := {"hint": 0, "smash": 0, "move": 0}
	for i in 16:
		var r := RoadTrip.reward(i)
		for k in r:
			total[k] = int(total[k]) + int(r[k])
	t.eq(total, {"hint": 12, "smash": 10, "move": 8}, "tổng 12 Hint, 10 Búa, 8 Bước")


func test_win_advances_and_grants_box_once(t: T) -> void:
	var s := SaveSchema.defaults()
	s.road_trip.level = 14
	var r := RoadTrip.win(s, 14)
	t.eq(r.advanced, true, "thắng level đang chơi thì tiến")
	t.eq(r.box, -1, "level 14 không có hộp")
	t.eq(r.before, Vector2i(13, 15), "trước 13/15")
	t.eq(r.after, Vector2i(14, 15), "sau 14/15")
	r = RoadTrip.win(s, 15)
	t.eq(r.box, 0, "level 15: hộp 1")
	t.eq(r.reward, {"hint": 1}, "thưởng hộp 1")
	t.eq(r.after, Vector2i(15, 15), "thanh đầy")
	t.eq(int(s.road_trip.level), 16, "sang level 16")
	t.eq(int(s.road_trip.boxes), 1, "đã nhận 1 hộp")
	t.eq(RoadTrip.win(s, 15).advanced, false, "thắng lại level cũ không tiến")
	s.road_trip.level = 400
	r = RoadTrip.win(s, 400)
	t.eq(r.box, 15, "level 400: hộp cuối")
	t.eq(RoadTrip.is_done(s), true, "đi hết đường")
	t.eq(RoadTrip.win(s, 401).advanced, false, "hết đường thì không tiến")


func test_layout(t: T) -> void:
	var lay := RoadTrip.layout(RoadTrip.levels())
	t.eq(lay.size(), RoadTrip.levels(), "mỗi level một mốc")
	var bad: Array[String] = []
	var used := {}
	for i in lay.size():
		var it: Dictionary = lay[i]
		if int(it.n) != i + 1:
			bad.append("thứ tự %d" % i)
		var span := 2 if bool(it.box) else 1
		for c in span:
			var key := Vector2i(int(it.col) + c, int(it.row))
			if int(it.col) + c < 0 or int(it.col) + c >= RoadTrip.RUN_CELLS or used.has(key):
				bad.append("ô %s" % str(key))
			used[key] = true
		if bool(it.box) != (RoadTrip.box_index(int(it.n)) >= 0):
			bad.append("hộp %d" % int(it.n))
		# Hàng nối (row lẻ) chỉ có một mốc ở rìa, không phải hộp.
		if int(it.row) % 2 == 1 and (bool(it.box) or (int(it.col) != 0 and int(it.col) != RoadTrip.RUN_CELLS - 1)):
			bad.append("hàng nối %d" % int(it.n))
	t.eq(bad, [], "mốc không chồng nhau, trong 6 cột, hộp rộng 2 ô ở đầu hàng chạy")
	# Như wireframe: 1..6 hàng đáy trái sang phải, 7 nối ở rìa phải, 8..13 phải sang trái, 15 là hộp ở đầu hàng.
	t.eq([lay[0].row, lay[0].col, lay[5].col, lay[6].row, lay[6].col, lay[7].col, lay[12].col], [0, 0, 5, 1, 5, 5, 0], "hàng đầu")
	t.eq([lay[14].box, lay[14].row, lay[14].col, lay[15].col], [true, 4, 0, 2], "hộp 15 chiếm cột 0-1")
	t.eq(RoadTrip.node_state(3, 5, false), "done", "đã qua")
	t.eq(RoadTrip.node_state(5, 5, false), "current", "hiện tại")
	t.eq(RoadTrip.node_state(9, 5, false), "locked", "khoá")
	t.eq(RoadTrip.node_state(15, 5, true), "target", "hộp đang nhắm")
	t.eq(RoadTrip.node_state(35, 5, true), "closed", "hộp sau")
	t.eq(RoadTrip.node_state(15, 16, true), "open", "hộp đã mở")


# --- Game ---

func test_unlock_at_level_70(t: T) -> void:
	var g := _g(69)
	t.eq(g.road_trip_view().open, false, "L69 chưa mở")
	t.eq(g.start_road_trip(), {}, "khoá thì không chơi")
	g.s.level = 70
	var v: Dictionary = g.road_trip_view()
	t.eq(v.open, true, "mở từ L70")
	t.eq(int(v.unlock_level), 70, "Config.UNLOCK.road_trip = 70")
	t.eq(int(v.level), 1, "bắt đầu từ level 1")
	t.eq(v.progress, Vector2i(0, 15), "0/15")
	t.eq(Config.UNLOCK.road_trip, 70, "unlock trong Config")


func test_attempt_uses_step_limit(t: T) -> void:
	var g := _g(MAIN, 1)
	var a: Dictionary = g.start_road_trip()
	t.ok(not a.is_empty(), "có attempt")
	t.eq(bool(a.road_trip), true, "attempt road_trip")
	t.eq(int(a.level), 1, "level 1 của Road Trip")
	t.eq((a.board as BoardState).moves_left(), 45, "MOVES = StepLimit 45")
	t.eq((a.specials as Array).size(), 0, "không có mảnh leaderboard")
	t.eq(_plat().an.count("rt_start"), 1, "log rt_start")
	t.eq(_plat().an.count("level_start"), 0, "không log level_start")


func test_win_no_coins_box_to_inventory(t: T) -> void:
	var g := _g(MAIN, 15)
	var coins0 := int(g.s.coins)
	var hint0 := int(g.s.inv.hint)
	var main0 := int(g.s.level)
	var a: Dictionary = g.start_road_trip()
	var b: BoardState = a.board
	for id in _greedy(b.clone()):
		g.tap(a, id)
	t.ok(b.is_won(), "thắng")
	var res: Dictionary = g.on_level_won(a)
	t.eq(int(res.coins), 0, "không gold")
	t.eq(int(g.s.coins), coins0, "ví không đổi")
	t.eq(int(res.box), 0, "hộp 1")
	t.eq(int(g.s.inv.hint), hint0 + 1, "+1 Hint vào kho")
	t.eq(int(g.s.road_trip.level), 16, "sang level 16")
	t.eq(int(g.s.level), main0, "level chính không đổi")
	t.eq(_plat().an.count("rt_end"), 1, "log rt_end")
	t.eq(_plat().an.count("rt_box"), 1, "log rt_box")


func test_lose_costs_no_life(t: T) -> void:
	var g := _g(MAIN, 3)
	var lives0 := int(g.lives_view().count)
	var a: Dictionary = g.start_road_trip()
	g.on_level_lost(a)
	t.eq(int(g.lives_view().count), lives0, "thua không mất mạng")
	var a2: Dictionary = g.start_road_trip()
	g.tap(a2, (a2.board as BoardState).block_ids()[0])
	t.eq(g.restart_cost_life(a2), false, "chơi lại không mất mạng")
	t.eq(int(g.lives_view().count), lives0, "vẫn đủ mạng")
	t.eq(int(g.s.road_trip.level), 3, "thua không tiến")


func test_revive_by_video(t: T) -> void:
	var g := _g(MAIN, 2)
	var a: Dictionary = g.start_road_trip()
	var b: BoardState = a.board
	var m0 := b.moves_left()
	var v: Dictionary = g.road_trip_revive_view(a)
	t.eq([v.available, int(v.moves), int(v.left)], [true, 5, 3], "3 lần, mỗi lần +5")
	t.ok(await g.road_trip_revive(a), "xem hết video")
	t.eq(b.moves_left(), m0 + 5, "+5 bước")
	t.ok(await g.road_trip_revive(a), "lần 2")
	t.ok(await g.road_trip_revive(a), "lần 3")
	t.eq(g.road_trip_revive_view(a).available, false, "hết lượt hồi sinh")
	t.eq(await g.road_trip_revive(a), false, "lần 4 không được")
	t.eq(_plat().an.count("rt_revive"), 3, "log rt_revive")
	var a2: Dictionary = g.start_road_trip()
	_plat().ads.simulate({"ok": false, "reason": "closed"})
	t.eq(await g.road_trip_revive(a2), false, "đóng video giữa chừng thì không cộng")
	t.eq((a2.board as BoardState).moves_left(), int(_data(2).moves), "bước giữ nguyên")


## Thắng Road Trip rồi đóng popup: interstitial result_exit theo cùng luật nhịp với thẻ thắng thường.
func _won_rt(g: Node) -> void:
	var a: Dictionary = g.start_road_trip()
	for id in _greedy((a.board as BoardState).clone()):
		g.tap(a, id)
	g.on_level_won(a)


func test_interstitial_after_win(t: T) -> void:
	var g := _g(MAIN, 1)
	g.s.runs = 3
	g.set("_session_start", NOW - 10000)
	g.set("_first_session", false)
	_won_rt(g)
	t.eq(int(g.s.runs), 4, "level Road Trip tính một lượt")
	await g.road_trip_leave_win(1)
	var calls: Array = _plat().ads.calls
	t.eq(calls.size(), 1, "có interstitial")
	t.eq(str(calls[0].placement), "result_exit", "placement result_exit")
	var ev: Array = _plat().an.named("inter_show")
	t.eq(ev.size(), 1, "log inter_show")
	t.eq(str(ev[0].params.get("mode", "")), "road_trip", "inter_show ghi mode road_trip")
	t.eq(int(g.s.ads.inter_today), 1, "đếm trong ngày")
	_won_rt(g)
	await g.road_trip_leave_win(2)
	t.eq(_plat().ads.calls.size(), 1, "cách 2 lượt và 120 giây")
	# Phiên đầu: chặn tới khi qua L10 của đường chính, dù Road Trip đã qua nhiều level.
	g.s.ads.last_inter_run = -99
	g.s.ads.last_inter_at = 0
	g.set("_first_session", true)
	g.s.level = 8
	await g.road_trip_leave_win(3)
	t.eq(_plat().ads.calls.size(), 1, "phiên đầu, level chính 8: không có")
	g.s.level = 12
	await g.road_trip_leave_win(3)
	t.eq(_plat().ads.calls.size(), 2, "phiên đầu, đã qua L11 chính: có")
	g.s.no_ads = true
	g.s.ads.last_inter_run = -99
	g.s.ads.last_inter_at = 0
	await g.road_trip_leave_win(3)
	t.eq(_plat().ads.calls.size(), 2, "no_ads chặn")


func test_tester_sets_level(t: T) -> void:
	var g := _g(MAIN, 1)
	Config.account_tool_override = 1
	t.ok(g.tester_edit({"rt_level": 40}), "tester sửa level Road Trip")
	t.eq(int(g.s.road_trip.level), 40, "level 40")
	t.eq(int(g.s.road_trip.boxes), 2, "hộp 15, 35 coi như đã nhận")
	Config.account_tool_override = -1


# --- UI ---

func _mount(scene: String, args: Dictionary = {}) -> Control:
	var node := (load("res://scenes/%s.tscn" % scene) as PackedScene).instantiate() as Control
	_tree().root.add_child(node)
	node.call("setup", args)
	return node


func test_nav_tabs(t: T) -> void:
	_g(69)
	var home := _mount("home")
	var nav: Control = home.find_child("NavBar", true, false)
	t.ok(home.find_child("RankingTab", true, false) == null, "không còn tab Ranking")
	var rt: Button = home.find_child("RoadTripTab", true, false)
	t.ok(rt != null, "có tab Road Trip")
	t.ok(rt.disabled, "L69: Road Trip khoá")
	t.eq(nav.road_trip_caption.text, "Unlocked at Level 70", "chữ mở ở L70")
	home.free()
	_g(70)
	home = _mount("home")
	rt = home.find_child("RoadTripTab", true, false)
	t.ok(not rt.disabled, "L70: Road Trip mở")
	var got := []
	home.closed.connect(func(r: Variant) -> void: got.append(r))
	rt.pressed.emit()
	t.eq(got, [{"action": "road_trip"}], "tab Road Trip")
	home.free()


func test_home_leaderboard_icon(t: T) -> void:
	_g(5)
	var home := _mount("home")
	t.ok(home.leaderboard_btn.disabled, "L5: Bảng xếp hạng khoá")
	t.ok(home.find_child("LeaderboardLock", true, false).visible, "có ổ khoá")
	t.eq(home.leaderboard_caption.text, "Level 8", "ghi level mở")
	home.free()
	_g(8)
	home = _mount("home")
	t.ok(not home.leaderboard_btn.disabled, "L8 mở")
	t.eq(home.leaderboard_caption.text, "Ranking", "chữ Ranking")
	var got := []
	home.closed.connect(func(r: Variant) -> void: got.append(r))
	home.leaderboard_btn.pressed.emit()
	t.eq(got, [{"action": "ranking"}], "icon mở Bảng xếp hạng")
	home.free()


func test_home_guide_once(t: T) -> void:
	var g := _g(70)
	g.s.road_trip.guide = false
	var home := _mount("home")
	t.ok(home.road_trip_guide != null, "Road Trip vừa mở: có hướng dẫn")
	t.eq((home.road_trip_guide.get_node("Bubble") as Label).text, "Road Trip unlocked! Clear its levels to open gift boxes.", "chữ hướng dẫn")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	home.road_trip_guide.gui_input.emit(ev)
	t.ok(home.road_trip_guide == null, "chạm thì tắt")
	t.eq(bool(g.s.road_trip.guide), true, "ghi đã xem")
	home.free()
	home = _mount("home")
	t.ok(home.road_trip_guide == null, "không hiện lại")
	home.free()


func test_main_routes(t: T) -> void:
	var g := _g(MAIN)
	var m := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Control
	_tree().root.add_child(m)
	t.ok(await _wait_until(func() -> bool: return m.is_booted), "boot xong")
	g.s.level = MAIN
	g.s.road_trip.guide = true
	m.go("home")
	await _settle(m)
	m.current_screen.find_child("RoadTripTab", true, false).pressed.emit()
	t.eq(m.current_name, "road_trip", "tab mở Road Trip")
	await _settle(m)
	m.current_screen.find_child("HomeTab", true, false).pressed.emit()
	t.eq(m.current_name, "home", "tab Home về Home")
	await _settle(m)
	m.current_screen.leaderboard_btn.pressed.emit()
	# Leaderboard is a popup over Home (2026-11-09): Home stays the screen.
	t.eq(m.current_name, "home", "icon mở Bảng xếp hạng trên Home")
	var lb: Node = m.popup_layer.find_child("Leaderboard", false, false)
	t.ok(lb != null, "popup Bảng xếp hạng")
	await _settle(m)
	lb.emit_signal("closed", null)
	t.ok(lb.is_queued_for_deletion(), "đóng popup thì về Home")
	await _tree().process_frame
	m.current_screen.find_child("RoadTripTab", true, false).pressed.emit()
	t.eq(m.current_name, "road_trip", "từ Home sang Road Trip")
	m.free()


## Đợi màn trượt xong (main chặn chạm trong lúc trượt).
func _settle(m: Control) -> void:
	await _wait_until(func() -> bool: return m.get("_slide_out") == null)
	await _tree().process_frame


func test_screen(t: T) -> void:
	_g(MAIN, 13)
	var rt := _mount("road_trip")
	await _tree().process_frame
	t.ok(rt.find_child("Banner", true, false) == null, "không có ribbon tiêu đề")
	t.ok(rt.map_scroll.position.y < (rt.chip as Control).position.y, "bản đồ bắt đầu trên chip, sát thanh trên")
	t.eq(rt.play_label.text, "Level 13", "nút Level 13")
	t.ok(rt.chip.visible, "chip tiến độ")
	t.eq(rt.chip_label.text, "12/15", "chip 12/15")
	var map: Control = rt.map
	t.ok(map.size.y > rt.map_scroll.size.y * 10.0, "bản đồ dài, cuộn được")
	t.ok(map.center_of(1).y > map.center_of(400).y, "level 1 ở đáy")
	# Chạm hộp 15: bong bóng 1 Hint.
	map.tapped.emit(15, true)
	t.ok(rt.bubble != null, "bong bóng thưởng")
	t.ok(rt.bubble.find_children("*", "TextureRect", true, false).size() == 1, "một vật phẩm")
	rt.free()
	_g(MAIN, 401)
	rt = _mount("road_trip")
	t.ok(not rt.play_button.visible, "đi hết: ẩn nút Level")
	t.ok(rt.done_label.visible, "chữ đã đi hết")
	t.ok(not rt.chip.visible, "ẩn chip")
	rt.free()


## Chuột không có cảm ứng (desktop, headless): ScrollContainer không tự kéo, bản đồ tự cuộn theo chuột.
func test_map_mouse_drag(t: T) -> void:
	_g(MAIN, 1)
	var rt := _mount("road_trip")
	await _tree().process_frame
	await _tree().process_frame
	var sc: ScrollContainer = rt.map_scroll
	var map: Control = rt.map
	t.ok(not DisplayServer.is_touchscreen_available(), "chạy không cảm ứng")
	var v0 := sc.scroll_vertical
	t.ok(v0 > 0, "level 1: cuộn ở đáy")
	var taps := []
	map.tapped.connect(func(n: int, _b: bool) -> void: taps.append(n))
	var x := 300.0
	_map_mouse(map, Vector2(x, 500), true)
	_map_motion(map, Vector2(x, 530))
	_map_motion(map, Vector2(x, 830))
	t.eq(sc.scroll_vertical, v0 - 300, "kéo xuống 300 px: lên 300 px bản đồ")
	_map_mouse(map, Vector2(x, 830), false)
	t.eq(taps, [], "kéo không tính là chạm")
	_map_mouse(map, Vector2(x, 600), true)
	_map_motion(map, Vector2(x, 570))
	_map_motion(map, Vector2(x, 370))
	_map_mouse(map, Vector2(x, 370), false)
	t.eq(sc.scroll_vertical, v0 - 100, "kéo lên 200 px")
	rt.free()


## Sự kiện chuột vào thẳng _gui_input của bản đồ: position cục bộ, global_position theo viewport.
func _map_mouse(map: Control, global: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	e.global_position = global
	e.position = map.get_global_transform().affine_inverse() * global
	map.call("_gui_input", e)


func _map_motion(map: Control, global: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	e.global_position = global
	e.position = map.get_global_transform().affine_inverse() * global
	map.call("_gui_input", e)


func _pop(lv: Control, node_name: String) -> Node:
	if lv == null or not is_instance_valid(lv):
		return null
	for c in lv.get_node("LocalPopups").get_children():
		if c.is_queued_for_deletion():
			continue
		var n := c.find_child(node_name, true, false)
		if n != null:
			return n
	return null


func test_screen_plays_and_wins_box(t: T) -> void:
	var g := _g(MAIN, 15)
	var hint0 := int(g.s.inv.hint)
	var lives0 := int(g.lives_view().count)
	var rt := _mount("road_trip")
	rt.play_button.pressed.emit()
	var lv: Control = rt.level_node
	t.ok(lv != null, "nhúng màn level")
	t.ok(not rt.get_node("%Content").visible, "ẩn bản đồ khi chơi")
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing"), "đang chơi")
	t.eq(bool(lv.attempt.road_trip), true, "attempt road_trip")
	t.eq(lv.title_label.text, "Level 15", "tiêu đề Level 15")
	t.eq(lv.tut_label.text, "", "không hướng dẫn")
	for id in _greedy(lv.board.clone()):
		lv.board_view.block_tapped.emit(id)
		await _tree().process_frame
	t.ok(lv.board.is_won(), "thắng")
	t.ok(await _wait_until(func() -> bool: return _pop(lv, "OkButton") != null), "popup thắng Road Trip")
	t.ok(_pop(lv, "Reward_hint") != null, "ô thưởng Hint")
	t.eq(int(g.s.inv.hint), hint0 + 1, "+1 Hint")
	(_pop(lv, "OkButton") as Button).pressed.emit()
	t.ok(await _wait_until(func() -> bool: return rt.level_node == null), "về bản đồ")
	t.ok(rt.get_node("%Content").visible, "hiện bản đồ")
	t.eq(rt.play_label.text, "Level 16", "nút Level 16")
	t.eq(rt.chip_label.text, "0/20", "chip 0/20")
	t.eq(int(g.lives_view().count), lives0, "không mất mạng")
	rt.free()


func test_screen_out_of_moves_revive_then_give_up(t: T) -> void:
	var g := _g(MAIN, 2)
	var lives0 := int(g.lives_view().count)
	var rt := _mount("road_trip")
	rt.play_button.pressed.emit()
	var lv: Control = rt.level_node
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing"), "đang chơi")
	var blocked := ""
	for id in lv.board.block_ids():
		if lv.board.peek(id) == "blocked":
			blocked = id
			break
	t.ok(blocked != "", "có khối bị chặn")
	for i in 200:
		if lv.board.moves_left() <= 0:
			break
		lv.board_view.block_tapped.emit(blocked)
		await _tree().process_frame
	t.eq(lv.board.moves_left(), 0, "hết bước")
	t.ok(await _wait_until(func() -> bool: return _pop(lv, "ReviveButton") != null), "hỏi hồi sinh bằng video")
	(_pop(lv, "ReviveButton") as Button).pressed.emit()
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing" and lv.board.moves_left() == 5), "+5 bước, chơi tiếp")
	for i in 20:
		if lv.board.moves_left() <= 0:
			break
		lv.board_view.block_tapped.emit(blocked)
		await _tree().process_frame
	t.ok(await _wait_until(func() -> bool: return _pop(lv, "GiveUpButton") != null), "hỏi lại")
	(_pop(lv, "GiveUpButton") as Button).pressed.emit()
	t.ok(await _wait_until(func() -> bool: return _pop(lv, "RetryButton") != null), "thẻ thua")
	t.eq(int(g.lives_view().count), lives0, "không mất mạng")
	t.eq(int(g.s.road_trip.level), 2, "không tiến")
	rt.free()
