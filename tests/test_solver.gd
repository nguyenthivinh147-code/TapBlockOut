extends RefCounted
const T := preload("res://tests/t.gd")
const BoardState := preload("res://src/core/board_state.gd")
const LevelData := preload("res://src/core/level_data.gd")
const Solver := preload("res://src/core/solver.gd")
const Config := preload("res://src/config.gd")

const BIG := 1000
const NEIGHBORS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func _load(name: String) -> Dictionary:
	var f := FileAccess.open("res://tests/fixtures/%s.json" % name, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


func _b(id: String, color: String, cells: Array, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": id, "color": color, "cells": cells, "ice": 0, "chained_by": "",
		"inner_color": "", "fog": false}
	d.merge(extra, true)
	return d


func _lv(w: int, h: int, blocks: Array, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": 7, "w": w, "h": h, "hard": false, "min_taps": 0, "moves": 50, "seed": 0,
		"stones": [], "pulse_sides": [], "blocks": blocks}
	d.merge(extra, true)
	return d


## Phát lại order với đúng min_taps MOVES: phải thắng và về 0.
func _replay_wins(level: Dictionary, res: Dictionary) -> bool:
	var lv := level.duplicate(true)
	lv["moves"] = int(res["min_taps"])
	var b := BoardState.new(lv)
	for id in res["order"]:
		b.tap(id)
	return b.is_won() and b.moves_left() == 0


## BFS vét cạn trên mọi chạm; trả số chạm ít nhất hoặc -1. `seen` nhận mọi trạng thái đạt được.
func _bfs(level: Dictionary, seen: Dictionary) -> int:
	var lv := level.duplicate(true)
	lv["moves"] = BIG
	var b0 := BoardState.new(lv)
	seen[b0.state_key()] = b0
	var frontier: Array = [b0]
	var depth := 0
	var found := -1
	while not frontier.is_empty():
		var nxt: Array = []
		for b in frontier:
			if b.is_won():
				if found < 0:
					found = depth
				continue
			for id in b.block_ids():
				var c: BoardState = b.clone()
				c.tap(id)
				var k := c.state_key()
				if not seen.has(k):
					seen[k] = c
					nxt.append(c)
		frontier = nxt
		depth += 1
	return found


func _rand_level(rng: RandomNumberGenerator, idx: int, mech: bool) -> Dictionary:
	var w := rng.randi_range(3, 4)
	var h := rng.randi_range(3, 4)
	var taken := {}
	var stones: Array = []
	if mech and rng.randf() < 0.4:
		var sc := Vector2i(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1))
		taken[sc] = true
		stones.append([sc.x, sc.y])
	var blocks: Array = []
	var nb := rng.randi_range(2, 5)
	for i in range(nb):
		var free: Array[Vector2i] = []
		for x in range(w):
			for y in range(h):
				if not taken.has(Vector2i(x, y)):
					free.append(Vector2i(x, y))
		if free.is_empty():
			break
		var start: Vector2i = free[rng.randi_range(0, free.size() - 1)]
		var cells: Array[Vector2i] = [start]
		taken[start] = true
		var size := rng.randi_range(1, 3)
		for _s in range(size - 1):
			var opts: Array[Vector2i] = []
			for c in cells:
				for dv in NEIGHBORS:
					var n: Vector2i = c + dv
					if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and not taken.has(n) and not opts.has(n):
						opts.append(n)
			if opts.is_empty():
				break
			var pick: Vector2i = opts[rng.randi_range(0, opts.size() - 1)]
			cells.append(pick)
			taken[pick] = true
		var raw: Array = []
		for c in cells:
			raw.append([c.x, c.y])
		var extra := {}
		if mech:
			if rng.randf() < 0.25:
				extra["ice"] = 1
			if rng.randf() < 0.2:
				extra["inner_color"] = LevelData.COLORS[rng.randi_range(0, 3)]
			if i > 0 and rng.randf() < 0.2:
				extra["chained_by"] = "b%d" % rng.randi_range(0, i - 1)
			if rng.randf() < 0.2:
				extra["fog"] = true
		blocks.append(_b("b%d" % i, LevelData.COLORS[rng.randi_range(0, 3)], raw, extra))
	var pulses: Array = []
	if mech and rng.randf() < 0.45:
		var sides := LevelData.SIDES.duplicate()
		for _i in range(rng.randi_range(1, 2)):
			var si := rng.randi_range(0, sides.size() - 1)
			pulses.append({"side": sides[si], "open": rng.randf() < 0.5})
			sides.remove_at(si)
	return _lv(w, h, blocks, {"id": idx + 1, "stones": stones, "pulse_sides": pulses})


func test_fixture_basic(t: T) -> void:
	var lv := _load("basic")
	var r := Solver.solve(lv)
	t.eq(r["ok"], true, "giải được")
	t.eq(r["min_taps"], 3, "3 chạm")
	t.eq(r["wasted"], 0, "không chạm chờ")
	t.eq(r["order"].size(), 3, "order")
	t.ok(_replay_wins(lv, r), "phát lại thắng")
	t.eq(Solver.immediate_exit_exists(lv), true, "có khối đi ngay")


func test_fixture_unsolvable(t: T) -> void:
	var lv := _load("unsolvable")
	var r := Solver.solve(lv)
	t.eq(r["ok"], false, "bí")
	t.eq(r["min_taps"], -1, "min_taps -1")
	t.eq(Solver.immediate_exit_exists(lv), false, "không có khối đi ngay")
	t.eq(Solver.compute_moves(lv), -1, "compute_moves -1")


func test_fixture_mechanics(t: T) -> void:
	var lv := _load("mechanics")
	var r := Solver.solve(lv)
	t.eq(r["ok"], true, "giải được đủ 6 cơ chế")
	var seen := {}
	t.eq(r["min_taps"], _bfs(lv, seen), "khớp BFS")
	t.ok(_replay_wins(lv, r), "phát lại thắng")


func test_gate_forces_wait(t: T) -> void:
	# Một khối duy nhất qua cổng đang đóng: phải chờ đúng 1 chạm.
	var lv := _lv(5, 5, [_b("y", "yellow", [[2, 2]])], {"pulse_sides": [{"side": "up", "open": false}]})
	var r := Solver.solve(lv)
	t.eq(r["ok"], true, "giải được")
	t.eq(r["wasted"], 1, "1 chạm chờ")
	t.eq(r["min_taps"], 2, "2 chạm")
	t.ok(_replay_wins(lv, r), "phát lại")
	# Cổng đang mở thì không chờ.
	lv["pulse_sides"] = [{"side": "up", "open": true}]
	t.eq(Solver.solve(lv)["min_taps"], 1, "mở sẵn")
	# Hai khối cùng cạnh cổng: dùng khối kia làm nhịp, không phí.
	var two := _lv(5, 5, [_b("y1", "yellow", [[1, 2]]), _b("y2", "yellow", [[3, 2]]),
		_b("g", "green", [[4, 4]])], {"pulse_sides": [{"side": "up", "open": true}]})
	var r2 := Solver.solve(two)
	t.eq(r2["ok"], true, "giải được")
	t.eq(r2["min_taps"], 3, "g làm nhịp giữa hai lần mở")
	t.ok(_replay_wins(two, r2), "phát lại")


func test_greedy_matches_bfs_small(t: T) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261101
	var solvable := 0
	var unsolvable := 0
	var with_gates := 0
	var boards := 260
	for i in range(boards):
		var lv := _rand_level(rng, i, i % 4 != 0)
		t.eq(LevelData.validate(lv).size(), 0, "bàn %d hợp lệ: %s" % [i, str(LevelData.validate(lv))])
		var seen := {}
		var expected := _bfs(lv, seen)
		var r := Solver.solve(lv)
		if not lv["pulse_sides"].is_empty():
			with_gates += 1
		if expected < 0:
			unsolvable += 1
			t.eq(r["ok"], false, "bàn %d bí theo BFS" % i)
		else:
			solvable += 1
			t.eq(r["ok"], true, "bàn %d giải được" % i)
			t.eq(r["min_taps"], expected, "bàn %d min_taps khớp BFS" % i)
			t.ok(_replay_wins(lv, r), "bàn %d phát lại" % i)
			t.eq(r["order"].size() - r["wasted"] >= 0, true, "wasted hợp lý")
	t.ok(solvable >= 120, "đủ bàn giải được (%d)" % solvable)
	t.ok(unsolvable >= 10, "đủ bàn bí (%d)" % unsolvable)
	t.ok(with_gates >= 40, "đủ bàn có cổng (%d)" % with_gates)


## Luật không có thế bí: bàn giải được thì mọi trạng thái đạt được vẫn giải được khi đủ MOVES.
func test_no_dead_ends(t: T) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var checked_levels := 0
	var checked_states := 0
	var i := 0
	while checked_levels < 40 and i < 400:
		var lv := _rand_level(rng, 1000 + i, true)
		i += 1
		var seen := {}
		var d := _bfs(lv, seen)
		if d < 0:
			continue
		checked_levels += 1
		for k in seen:
			var b: BoardState = seen[k]
			checked_states += 1
			var r := Solver.solve_state(b)
			if not r["ok"]:
				t.fail("bàn %d: trạng thái %s hết đường" % [i, k])
				break
	t.ok(checked_levels >= 40, "đủ bàn kiểm")
	t.ok(checked_states > 200, "đủ trạng thái (%d)" % checked_states)


func test_solve_state_ignores_moves(t: T) -> void:
	var lv := _load("basic")
	lv["moves"] = 1
	var b := BoardState.new(lv)
	b.tap("b3")
	var r := Solver.solve_state(b)
	t.eq(r["ok"], true, "giải được dù hết MOVES")
	t.eq(r["min_taps"], 2, "còn 2 chạm")
	t.eq(b.moves_left(), 0, "bàn gốc không bị đổi")


func test_slack_and_compute_moves(t: T) -> void:
	Config.reset()
	var five := [_b("a", "yellow", [[0, 0]])]
	t.eq(Solver.slack_for(_lv(5, 5, five, {"id": 1})), 5, "L1 dư 5")
	t.eq(Solver.slack_for(_lv(5, 5, five, {"id": 3})), 5, "L3 dư 5")
	t.eq(Solver.slack_for(_lv(5, 5, five, {"id": 4})), 2, "L4 hết dư dễ")
	t.eq(Solver.slack_for(_lv(5, 5, five, {"id": 8, "hard": true})), 1, "HARD dư 1")
	t.eq(Solver.slack_for(_lv(5, 5, five, {"id": 6})), 2, "ít khối: tối thiểu 2")
	# 25 khối: ceil(10% x 25) = 3. 21 khối: ceil(2.1) = 3. 20 khối: 2.
	for pair in [[20, 2], [21, 3], [25, 3], [30, 3], [31, 4], [45, 5]]:
		var bl: Array = []
		for i in range(pair[0]):
			bl.append(_b("b%d" % i, "yellow", [[0, 0]]))
		t.eq(Solver.slack_for(_lv(5, 5, bl, {"id": 30})), pair[1], "%d khối" % pair[0])
	var lv := _load("basic")  # id 2, 3 chạm
	t.eq(Solver.compute_moves(lv), 3 + 5, "L2 dư 5")
	lv["id"] = 22
	t.eq(Solver.compute_moves(lv), 3 + 2, "level thường dư 2")
	lv["hard"] = true
	t.eq(Solver.compute_moves(lv), 3 + 1, "HARD dư 1")
	# Remote Config đổi dư thì theo.
	Config.CONTENT["slack_min"] = 4
	lv["hard"] = false
	t.eq(Solver.compute_moves(lv), 3 + 4, "slack_min từ Config")
	Config.reset()


func test_immediate_exit(t: T) -> void:
	t.eq(Solver.immediate_exit_exists(_load("basic")), true, "basic")
	# Chỉ có khối băng và khối bị chặn.
	var lv := _lv(5, 5, [_b("i", "yellow", [[2, 2]], {"ice": 1})])
	t.eq(Solver.immediate_exit_exists(lv), false, "băng không tính")
	var gated := _lv(5, 5, [_b("y", "yellow", [[2, 2]])], {"pulse_sides": [{"side": "up", "open": false}]})
	t.eq(Solver.immediate_exit_exists(gated), false, "cổng đóng không tính")


## Bàn thiên về cổng nhịp (2 cạnh, nhiều khối thoát tự do): kiểm chạm chờ so với BFS.
func test_gate_heavy_matches_bfs(t: T) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var waited := 0
	var solvable := 0
	for i in range(220):
		var lv := _rand_level(rng, 2000 + i, false)
		var sides := LevelData.SIDES.duplicate()
		var pulses: Array = []
		for _k in range(2):
			var si := rng.randi_range(0, sides.size() - 1)
			pulses.append({"side": sides[si], "open": rng.randf() < 0.5})
			sides.remove_at(si)
		lv["pulse_sides"] = pulses
		var expected := _bfs(lv, {})
		var r := Solver.solve(lv)
		if expected < 0:
			t.eq(r["ok"], false, "bàn cổng %d bí" % i)
			continue
		solvable += 1
		t.eq(r["ok"], true, "bàn cổng %d giải được" % i)
		t.eq(r["min_taps"], expected, "bàn cổng %d khớp BFS" % i)
		t.ok(_replay_wins(lv, r), "bàn cổng %d phát lại" % i)
		if int(r["wasted"]) > 0:
			waited += 1
	t.ok(solvable >= 80, "đủ bàn cổng giải được (%d)" % solvable)
	t.ok(waited >= 15, "đủ bàn phải chờ (%d)" % waited)
