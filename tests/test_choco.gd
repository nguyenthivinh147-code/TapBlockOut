extends RefCounted
## Chocolate mechanic (design.md section 4, "Cơ chế sau bản demo"): melted chocolate covers one exit bar
## (`choco_sides`); blocks heading there do not move and cost nothing; every piece grinding through another bar (exit,
## paper box shell, ribbon) or a Smash melts one layer.
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


func _lv(blocks: Array, choco: Array, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": 7, "w": 5, "h": 5, "hard": false, "min_taps": 0, "moves": 20, "seed": 0,
		"stones": [], "pulse_sides": [], "blocks": blocks, "choco_sides": choco}
	d.merge(extra, true)
	return d


func _up(layers: int) -> Array:
	return [{"side": "up", "layers": layers}]


func test_choco_bar_holds_until_melted(t: T) -> void:
	# y goes up to the chocolate bar; g1, g2 go left freely.
	var b := BoardState.new(_lv([_b("y", "yellow", [[2, 2]]), _b("g1", "green", [[1, 3]]),
		_b("g2", "green", [[1, 4]])], _up(2)))
	t.eq(b.choco(), {"up": 2}, "2 layers on the top bar")
	var r := b.tap("y")
	t.eq(r["kind"], "choco", "block heading to the chocolate bar does not move")
	t.eq(r["moves_left"], 20, "no MOVES spent")
	t.eq(b.remaining_count(), 3, "nothing left the board")
	t.eq(b.can_exit("y"), false, "cannot exit")
	var e := b.tap("g1")
	t.eq(e["kind"], "exit", "other bar works")
	t.eq(e["choco"], ["up"] as Array[String], "exit melts one layer")
	t.eq(b.choco_layers("up"), 1, "1 layer left")
	t.eq(b.peek("y"), "choco", "still held")
	t.eq(b.tap("g2")["choco"], ["up"] as Array[String], "second exit melts the last layer")
	t.eq(b.choco(), {}, "bar free")
	var last := b.tap("y")
	t.eq(last["kind"], "exit", "block goes once the chocolate is gone")
	t.eq(last["choco"], [] as Array[String], "nothing left to melt")
	t.eq(last["won"], true, "won")
	t.eq(last["moves_left"], 17, "3 useful taps")


func test_choco_before_blocked_and_chain(t: T) -> void:
	# y is blocked by s on its way up, and chained to k: chocolate still wins (shake, no cost).
	var b := BoardState.new(_lv([_b("s", "green", [[2, 1]]), _b("y", "yellow", [[2, 3]], {"chained_by": "k"}),
		_b("k", "blue", [[4, 4]])], _up(1)))
	var r := b.tap("y")
	t.eq(r["kind"], "choco", "chocolate before chain and blocked path")
	t.eq(r["blocker"], "choco", "blocker names the chocolate")
	t.eq(r["moves_left"], 20, "free")


func test_fog_before_choco(t: T) -> void:
	var b := BoardState.new(_lv([_b("y", "yellow", [[2, 2]], {"fog": true}), _b("g", "green", [[0, 4]])], _up(1)))
	t.eq(b.peek("y"), "fog", "hidden block shakes as fog")


func test_bounce_does_not_melt(t: T) -> void:
	# g bumps into s (blocked): no layer melts.
	var b := BoardState.new(_lv([_b("s", "blue", [[0, 2]]), _b("g", "green", [[2, 2]]), _b("y", "yellow", [[4, 4]])],
		_up(2)))
	var r := b.tap("g")
	t.eq(r["kind"], "blocked", "blocked")
	t.eq(r["choco"], [] as Array[String], "no melt")
	t.eq(b.choco_layers("up"), 2, "layers kept")


func test_peel_and_ribbon_melt(t: T) -> void:
	# box: blue shell goes right (melts 1), green candy stays; ribbon: purple ribbon goes down (melts 1).
	var b := BoardState.new(_lv([_b("x", "blue", [[2, 2]], {"inner_color": "green"}),
		_b("r", "green", [[1, 3], [1, 4]], {"ribbons": ["purple"]}), _b("y", "yellow", [[3, 0]])], _up(3)))
	t.eq(b.tap("x")["choco"], ["up"] as Array[String], "paper shell melts a layer")
	t.eq(b.tap("r")["choco"], ["up"] as Array[String], "ribbon melts a layer")
	t.eq(b.choco_layers("up"), 1, "1 layer left")
	t.eq(b.remaining_count(), 3, "blocks stay after peeling")


func test_ribbon_toward_choco_is_held(t: T) -> void:
	# outer ribbon yellow heads up to the chocolate: held; candy (green) would be free.
	var b := BoardState.new(_lv([_b("r", "green", [[2, 2], [2, 3]], {"ribbons": ["yellow"]}),
		_b("g", "green", [[0, 0]])], _up(1)))
	t.eq(b.peek("r"), "choco", "outer ribbon heads to the chocolate")
	b.tap("g")
	t.eq(b.peek("r"), "peel", "ribbon flies once the bar is free")


func test_smash_melts(t: T) -> void:
	var b := BoardState.new(_lv([_b("y", "yellow", [[2, 2]]), _b("s", "yellow", [[2, 4]]),
		_b("g", "green", [[0, 0]])], _up(1)))
	t.eq(b.smash("s"), true, "smash")
	t.eq(b.choco(), {}, "smash melts a layer")
	t.eq(b.peek("y"), "exit", "free after the smash")


func test_hint_skips_held_blocks(t: T) -> void:
	var b := BoardState.new(_lv([_b("y", "yellow", [[0, 0]]), _b("g", "green", [[2, 4]])], _up(1)))
	t.eq(b.first_exit(), "g", "first exit skips the held block")
	t.eq(b.hint(), "g", "hint skips the held block")
	var all := BoardState.new(_lv([_b("y", "yellow", [[0, 0]]), _b("y2", "yellow", [[2, 4]])], _up(1)))
	t.eq(all.hint(), "", "nothing to hint when every block waits for the chocolate")


func test_clone_and_state_key(t: T) -> void:
	var b := BoardState.new(_lv([_b("y", "yellow", [[2, 2]]), _b("g", "green", [[0, 4]])], _up(2)))
	var c := b.clone()
	var key := b.state_key()
	c.tap("g")
	t.eq(b.choco_layers("up"), 2, "clone does not share chocolate")
	t.ok(c.state_key() != key, "state key changes")
	var d := b.clone()
	d.melt_choco("up")
	t.ok(d.state_key() != key, "layers are part of the state key")
	d.melt_choco("up")
	d.melt_choco("up")
	t.eq(d.choco(), {}, "melting past 0 stays empty")


func test_solver(t: T) -> void:
	var lvl := _lv([_b("y", "yellow", [[2, 2]]), _b("g1", "green", [[1, 3]]), _b("g2", "green", [[1, 4]])], _up(2))
	var r := Solver.solve(lvl)
	t.eq(r["ok"], true, "solvable")
	t.eq(r["min_taps"], 3, "chocolate taps do not count")
	t.eq(r["order"][2], "y", "held block goes last")
	t.eq(Solver.clear_rounds(lvl), 2, "two rounds: greens, then the freed yellow")
	var stuck := _lv([_b("y", "yellow", [[2, 2]]), _b("g", "green", [[1, 3]])], _up(2))
	t.eq(Solver.solve(stuck)["ok"], false, "not enough crushes to melt 2 layers")
	t.eq(Solver.clear_rounds(stuck), -1, "stuck")


func test_unstick_melts_layers(t: T) -> void:
	var lvl := _lv([_b("y", "yellow", [[2, 2]]), _b("g", "green", [[1, 3]])], _up(3))
	Gen._unstick(lvl)
	t.eq(lvl["choco_sides"], [{"side": "up", "layers": 1}], "melted down to what the board can clear")
	t.eq(Solver.solve(lvl)["ok"], true, "solvable after unstick")
	var none := _lv([_b("y", "yellow", [[2, 2]])], _up(2))
	Gen._unstick(none)
	t.ok(not none.has("choco_sides"), "chocolate dropped when nothing else can melt it")
	t.eq(Solver.solve(none)["ok"], true, "solvable")


func test_validate(t: T) -> void:
	var good := _lv([_b("y", "yellow", [[2, 2]]), _b("g", "green", [[0, 4]])], _up(2))
	t.eq(LevelData.validate(good), [] as Array[String], "valid")
	var bad := {
		"side": [{"side": "north", "layers": 1}],
		"zero": [{"side": "up", "layers": 0}],
		"too many": [{"side": "up", "layers": Config.CHOCO_MAX_LAYERS + 1}],
		"no layers": [{"side": "up"}],
		"twice": [{"side": "up", "layers": 1}, {"side": "up", "layers": 2}],
	}
	for why in bad:
		var lvl := _lv([_b("y", "yellow", [[2, 2]])], bad[why])
		t.ok(not LevelData.validate(lvl).is_empty(), "rejects: " + why)
	var with_gate := _lv([_b("y", "yellow", [[2, 2]])], _up(1), {"pulse_sides": [{"side": "up", "open": false}]})
	t.ok(not LevelData.validate(with_gate).is_empty(), "rejects chocolate on a pulse gate bar")


func test_unlock_and_plan(t: T) -> void:
	var u := int(Config.UNLOCK["choco"])
	t.eq(u, 300, "chocolate opens at L300")
	t.eq(Gen.teach_mech(u), "choco", "L300 teaches chocolate")
	t.eq(Gen.mech_plan(u), ["choco"] as Array[String], "teaching level only has chocolate")
	t.ok(not Gen.mechanics_for(u - 1).has("choco"), "closed before L300")
	t.eq(Unlocks.pending_mech({"mech_seen": []}, u), "choco", "popup at L300")
	for id in range(u + 1, u + Config.LEVEL_MECH_FRESH + 1):
		if Gen.is_rest(id) or Gen.teach_mech(id) != "":
			continue
		t.ok(Gen.mech_plan(id).has("choco"), "L%d keeps the fresh chocolate" % id)
		t.ok(not Gen.mech_plan(id).has("pulse"), "L%d has no pulse gate" % id)
	for id in range(u, 505):
		var plan := Gen.mech_plan(id)
		if plan.has("choco") and plan.has("pulse"):
			t.fail("L%d has both chocolate and a pulse gate" % id)
			break


func test_teaching_level(t: T) -> void:
	var u := int(Config.UNLOCK["choco"])
	var lvl := Gen.generate(u, 1)
	t.ok(not lvl.is_empty(), "L300 generates")
	if lvl.is_empty():
		return
	t.eq(LevelData.validate(lvl), [] as Array[String], "valid")
	t.eq(Solver.solve(lvl)["ok"], true, "solvable")
	t.eq((lvl.get("choco_sides", []) as Array).size(), 1, "one chocolate bar")
	t.eq(int(lvl["choco_sides"][0]["layers"]), Config.CHOCO_TEACH_LAYERS, "teaching layers")
	t.eq((lvl["pulse_sides"] as Array).size(), 0, "no pulse gate")
	var b := BoardState.new(lvl)
	var free := 0
	var held := false
	for id in b.block_ids():
		free += int(b.can_exit(id))
		held = held or b.peek(id) == "choco"
	t.ok(free >= Config.CHOCO_TEACH_FREE, "%d blocks exit at once" % free)
	t.ok(held, "a block waits for the chocolate")


func test_regular_levels_ramp(t: T) -> void:
	var u := int(Config.UNLOCK["choco"])
	# One level in the first step (2 layers) and one after the cap reaches 4.
	for from in [u + 1, u + 2 * Config.CHOCO_LAYERS_EVERY]:
		var id: int = from
		while not Gen.mech_plan(id).has("choco") and id < from + 60:
			id += 1
		t.ok(Gen.mech_plan(id).has("choco"), "a level from L%d draws chocolate" % from)
		var lvl := Gen.generate(id, 1)
		t.ok(not lvl.is_empty(), "L%d generates" % id)
		if lvl.is_empty():
			continue
		t.eq(LevelData.validate(lvl), [] as Array[String], "L%d valid" % id)
		t.eq(Solver.solve(lvl)["ok"], true, "L%d solvable" % id)
		t.ok(Solver.immediate_exit_exists(lvl), "L%d has a block that exits at once" % id)
		t.eq((lvl["pulse_sides"] as Array).size(), 0, "L%d has no pulse gate" % id)
		@warning_ignore("integer_division")
		var cap := mini(Config.CHOCO_MAX_LAYERS, Config.CHOCO_LAYERS_START + (id - u) / Config.CHOCO_LAYERS_EVERY)
		for p in lvl.get("choco_sides", []):
			t.ok(int(p["layers"]) >= 1 and int(p["layers"]) <= cap, "L%d layers %d within 1..%d" % [id, p["layers"], cap])
