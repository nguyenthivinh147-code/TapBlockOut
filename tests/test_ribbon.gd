extends RefCounted
## Ribbon mechanic (design.md section 4, "Cơ chế sau bản demo"): a block wears 1..Config.RIBBON_MAX_LAYERS ribbons over
## its candy (`ribbons`, outer first; `color` is the candy). Each ribbon peels like the paper box's shell.
const T := preload("res://tests/t.gd")
const BoardState := preload("res://src/core/board_state.gd")
const LevelData := preload("res://src/core/level_data.gd")
const Solver := preload("res://src/core/solver.gd")
const Gen := preload("res://src/core/level_generator.gd")
const Unlocks := preload("res://src/meta/unlocks.gd")
const Config := preload("res://src/config.gd")


func _b(id: String, color: String, cells: Array, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": id, "color": color, "cells": cells, "ice": 0, "chained_by": "", "inner_color": "", "fog": false}
	d.merge(extra, true)
	return d


func _lv(w: int, h: int, blocks: Array, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": 7, "w": w, "h": h, "hard": false, "min_taps": 0, "moves": 20, "seed": 0,
		"stones": [], "pulse_sides": [], "blocks": blocks}
	d.merge(extra, true)
	return d


## Two cells in a column at x = 2, rows 1-2 of a 5x5 board.
func _ribboned(ribbons: Array, candy: String = "yellow", extra: Dictionary = {}) -> Dictionary:
	var e := {"ribbons": ribbons}
	e.merge(extra, true)
	return _b("r", candy, [[2, 1], [2, 2]], e)


func test_peel_each_ribbon_then_exit(t: T) -> void:
	var b := BoardState.new(_lv(5, 5, [_ribboned(["purple", "green"])]))
	var v := b.block_view("r")
	t.eq(v["color"], "purple", "outer ribbon sets the color")
	t.eq(v["ribbons"], 2, "2 ribbons")
	t.eq(b.can_exit("r"), true, "outer ribbon can go")
	var r := b.tap("r")
	t.eq(r["kind"], "peel", "first ribbon peels")
	t.eq(r["distance"], 4, "outer ribbon slides off the bottom")
	t.eq(b.remaining_count(), 1, "block stays")
	t.eq(b.block_view("r")["color"], "green", "next ribbon shows")
	t.eq(b.block_view("r")["ribbons"], 1, "1 ribbon left")
	t.eq(b.tap("r")["kind"], "peel", "second ribbon peels")
	t.eq(b.block_view("r")["color"], "yellow", "candy shows")
	t.eq(b.block_view("r")["ribbons"], 0, "no ribbon left")
	var last := b.tap("r")
	t.eq(last["kind"], "exit", "candy exits")
	t.eq(last["won"], true, "won")
	t.eq(last["moves_left"], 17, "3 taps, 1 MOVES each")


func test_blocked_ribbon_does_not_peel(t: T) -> void:
	var b := BoardState.new(_lv(5, 5, [_ribboned(["purple"]), _b("s", "blue", [[2, 4]])]))
	t.eq(b.tap("r")["kind"], "blocked", "outer ribbon blocked")
	t.eq(b.block_view("r")["ribbons"], 1, "ribbon kept")
	t.eq(b.block_view("r")["color"], "purple", "color kept")


func test_clone_and_state_key(t: T) -> void:
	var b := BoardState.new(_lv(5, 5, [_ribboned(["purple", "green", "blue"])]))
	var key0 := b.state_key()
	var c := b.clone()
	c.tap("r")
	c.tap("r")
	t.eq(b.block_view("r")["ribbons"], 3, "peeling a clone leaves the original alone")
	t.eq(b.block_view("r")["color"], "purple", "original color kept")
	t.eq(b.state_key(), key0, "original key kept")
	t.ok(c.state_key() != key0, "key changes with the ribbons")
	var d := BoardState.new(_lv(5, 5, [_ribboned(["purple", "blue", "green"])]))
	d.tap("r")
	c = BoardState.new(_lv(5, 5, [_ribboned(["purple", "green", "blue"])]))
	c.tap("r")
	t.ok(c.state_key() != d.state_key(), "hidden layers are part of the key")


func test_fog_gate_smash(t: T) -> void:
	var f := BoardState.new(_lv(5, 5, [_ribboned(["purple"], "yellow", {"fog": true}), _b("n", "yellow", [[0, 0]])]))
	t.eq(f.tap("r")["kind"], "fog", "hidden ribbon block does not move")
	t.eq(f.block_view("r")["ribbons"], 1, "fog keeps the ribbon")
	# A ribbon passing an open gate closes it, like the paper box shell.
	var g := BoardState.new(_lv(5, 5, [_ribboned(["purple"])], {"pulse_sides": [{"side": "down", "open": true}]}))
	t.eq(g.tap("r")["kind"], "peel", "ribbon passes the open gate")
	t.eq(g.gate_open("down"), false, "gate locks")
	var s := BoardState.new(_lv(5, 5, [_ribboned(["purple", "green"]), _b("n", "yellow", [[0, 0]])]))
	t.eq(s.smash("r"), true, "smash a ribbon block")
	t.eq(s.remaining_count(), 1, "whole block gone")
	t.eq(s.moves_left(), 20, "smash costs no MOVES")


func test_hint_and_first_exit(t: T) -> void:
	# s (up) waits for r; r's blue ribbon can peel to the right.
	var c := BoardState.new(_lv(5, 5, [_b("s", "yellow", [[2, 4]]), _ribboned(["blue"])]))
	t.eq(c.peek("s"), "blocked", "s waits")
	t.eq(c.first_exit(), "r", "a ribbon that can peel counts as moving")
	t.eq(c.hint(), "r", "hint points at it")


func test_solver_counts_every_ribbon(t: T) -> void:
	var lvl := _lv(5, 5, [_ribboned(["purple", "green", "blue", "green"])])
	var r := Solver.solve(lvl)
	t.eq(r["ok"], true, "solvable")
	t.eq(r["min_taps"], 5, "4 ribbons + candy")
	t.eq(Solver.clear_rounds(lvl), 5, "one round per layer")


func test_validate(t: T) -> void:
	var ok := _lv(5, 5, [_ribboned(["purple", "green"])])
	t.eq(LevelData.validate(ok), [] as Array[String], "valid ribbons")
	t.eq(LevelData.validate(_lv(5, 5, [_ribboned([])])), [] as Array[String], "empty list = no ribbon")
	var big := _b("r", "yellow", [[1, 1], [2, 1], [3, 1]], {"ribbons": ["purple", "green", "blue", "green"]})
	t.eq(LevelData.validate(_lv(5, 5, [big])), [] as Array[String], "4 ribbons on a 3-cell block")
	var bad := {
		"not an array": _b("r", "yellow", [[2, 1], [2, 2]], {"ribbons": "purple"}),
		"too many layers": _b("r", "yellow", [[1, 1], [2, 1], [3, 1]],
			{"ribbons": ["purple", "green", "blue", "green", "blue"]}),
		"unknown color": _ribboned(["red"]),
		"same color twice in a row": _ribboned(["purple", "purple"]),
		"last ribbon same as candy": _ribboned(["purple", "yellow"]),
		"with paper box": _ribboned(["purple"], "yellow", {"inner_color": "green"}),
		"with pudding": _ribboned(["purple"], "yellow", {"ice": 1}),
		"chained": _ribboned(["purple"], "yellow", {"chained_by": "k"}),
		"1-cell block": _b("r", "yellow", [[2, 2]], {"ribbons": ["purple"]}),
		"3 layers on 2 cells": _ribboned(["purple", "green", "blue"]),
	}
	for why in bad:
		var blocks: Array = [bad[why]]
		if why == "chained":
			blocks.append(_b("k", "green", [[0, 4]]))
		t.ok(not LevelData.validate(_lv(5, 5, blocks)).is_empty(), "rejects: " + why)


func test_unlock_and_plan(t: T) -> void:
	var u := int(Config.UNLOCK["ribbon"])
	t.eq(u, 130, "ribbon opens at L130")
	t.eq(Gen.teach_mech(u), "ribbon", "L130 teaches ribbon")
	t.eq(Gen.mech_plan(u), ["ribbon"] as Array[String], "teaching level only has ribbon")
	t.ok(not Gen.mechanics_for(u - 1).has("ribbon"), "closed before L130")
	t.eq(Unlocks.pending_mech({"mech_seen": []}, u), "ribbon", "popup at L130")
	t.ok(Unlocks.MECHS.has("ribbon"), "Unlocks knows ribbon")
	for id in range(u + 1, u + Config.LEVEL_MECH_FRESH + 1):
		if Gen.is_rest(id) or Gen.teach_mech(id) != "":
			continue
		t.ok(Gen.mech_plan(id).has("ribbon"), "L%d keeps the fresh ribbon" % id)


func _ribbons_of(lvl: Dictionary) -> Array:
	var out: Array = []
	for bd in lvl["blocks"]:
		var rib: Array = bd.get("ribbons", [])
		if not rib.is_empty():
			out.append(bd)
	return out


func test_teaching_level(t: T) -> void:
	var u := int(Config.UNLOCK["ribbon"])
	var lvl := Gen.generate(u, 1)
	t.ok(not lvl.is_empty(), "L130 generates")
	if lvl.is_empty():
		return
	t.eq(LevelData.validate(lvl), [] as Array[String], "valid")
	t.eq(Solver.solve(lvl)["ok"], true, "solvable")
	var small := 0
	var big := 0
	for bd in _ribbons_of(lvl):
		var n: int = (bd["ribbons"] as Array).size()
		if n <= Config.RIBBON_TEACH_SMALL_LAYERS:
			small += 1
		else:
			big += 1
			t.ok(n >= Config.RIBBON_TEACH_BIG.x and n <= Config.RIBBON_TEACH_BIG.y, "big block layers %d" % n)
			t.ok((bd["cells"] as Array).size() >= 3, "big block has 3+ cells")
		t.eq(bd["inner_color"], "", "no paper box")
		t.eq(int(bd["ice"]), 0, "no cover")
		t.eq(bd["chained_by"], "", "no chain")
		t.eq(bd["fog"], false, "no fog")
	t.ok(small >= Config.RIBBON_TEACH_SMALL.x and small <= Config.RIBBON_TEACH_SMALL.y, "small ribbon blocks: %d" % small)
	t.eq(big, 1, "exactly one 3-4 layer block")
	var b := BoardState.new(lvl)
	var peel_now := false
	for id in b.block_ids():
		if int(b.block_view(id)["ribbons"]) > 0 and b.peek(id) == "peel":
			peel_now = true
	t.ok(peel_now, "a ribbon can be peeled at once")


func test_regular_levels_ramp(t: T) -> void:
	var u := int(Config.UNLOCK["ribbon"])
	# One level in the first ramp step (max 2 layers) and one after the cap reaches 4.
	for from in [u + 1, u + 2 * Config.RIBBON_LAYERS_EVERY]:
		var id: int = from
		while not Gen.mech_plan(id).has("ribbon") and id < from + 60:
			id += 1
		t.ok(Gen.mech_plan(id).has("ribbon"), "a level from L%d draws ribbon" % from)
		var lvl := Gen.generate(id, 1)
		t.ok(not lvl.is_empty(), "L%d generates" % id)
		if lvl.is_empty():
			continue
		t.eq(LevelData.validate(lvl), [] as Array[String], "L%d valid" % id)
		@warning_ignore("integer_division")
		var cap := mini(Config.RIBBON_MAX_LAYERS, Config.RIBBON_LAYERS_START + (id - u) / Config.RIBBON_LAYERS_EVERY)
		@warning_ignore("integer_division")
		var count := mini(Config.RIBBON_COUNT_MAX, 1 + (id - u) / Config.RIBBON_COUNT_EVERY)
		var rib := _ribbons_of(lvl)
		t.ok(rib.size() <= count, "L%d: %d ribbon blocks, max %d" % [id, rib.size(), count])
		for bd in rib:
			var n: int = (bd["ribbons"] as Array).size()
			t.ok(n >= 1 and n <= cap, "L%d: %d layers, cap %d" % [id, n, cap])
