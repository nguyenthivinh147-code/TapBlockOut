extends RefCounted
## Candy bomb (design.md section 4, `pop`): a bomb block that leaves the board (exit or Smash) strips every pudding/ice
## layer and clears the fog of each block with a cell within Config.POP_RADIUS cells (both axes) of one of its cells.
## No chain reaction; min taps unchanged, clear rounds drop.
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


func _lv(blocks: Array, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": 7, "w": 7, "h": 7, "hard": false, "min_taps": 0, "moves": 20, "seed": 0,
		"stones": [], "pulse_sides": [], "blocks": blocks}
	d.merge(extra, true)
	return d


## p: bomb at (3, 3) going up. a (2 layers) and e (adjacent, 1 layer) on its row, b (diagonal, 2 away), d hidden in fog
## next to it diagonally; c is 3 cells away, out of the zone.
func _zone_level(bomb: bool = true) -> Dictionary:
	return _lv([
		_b("p", "yellow", [[3, 3]], {"pop": bomb}),
		_b("a", "green", [[1, 3]], {"ice": 2}),
		_b("e", "green", [[2, 3]], {"ice": 1}),
		_b("b", "blue", [[5, 5]], {"ice": 1}),
		_b("c", "blue", [[6, 3]], {"ice": 1}),
		_b("d", "purple", [[4, 4]], {"fog": true}),
	])


func test_bomb_clears_zone(t: T) -> void:
	var b := BoardState.new(_zone_level())
	t.eq(b.pop_targets("p"), ["a", "e", "b", "d"] as Array[String], "covered and hidden blocks in the 5x5 zone")
	var r := b.tap("p")
	t.eq(r["kind"], "exit", "bomb exits like a normal block")
	t.eq(r["moves_left"], 19, "one MOVE")
	t.eq(r["popped"], ["a", "e", "b", "d"] as Array[String], "zone blocks cleared, in block order")
	t.eq(r["stripped"], [] as Array[String], "adjacent block counts as popped, not stripped")
	t.eq(r["revealed"], [] as Array[String], "fog cleared by the blast is not in revealed")
	t.eq(int(b.block_view("a")["ice"]), 0, "both layers gone")
	t.eq(int(b.block_view("e")["ice"]), 0, "adjacent block bare")
	t.eq(int(b.block_view("b")["ice"]), 0, "diagonal block 2 away bare")
	t.eq(bool(b.block_view("d")["is_fog_hidden"]), false, "fog cleared")
	t.eq(int(b.block_view("c")["ice"]), 1, "3 cells away keeps its layer")


func test_plain_exit_unchanged(t: T) -> void:
	var b := BoardState.new(_zone_level(false))
	t.eq(bool(b.block_view("p")["pop"]), false, "no bomb flag")
	var r := b.tap("p")
	t.eq(r["popped"], [] as Array[String], "a plain block does not blast")
	t.eq(r["stripped"], ["e"] as Array[String], "only the adjacent block loses a layer")
	t.eq(int(b.block_view("a")["ice"]), 2, "far block keeps its layers")
	t.eq(bool(b.block_view("d")["is_fog_hidden"]), true, "diagonal fog stays")


func test_no_chain_reaction(t: T) -> void:
	# q is a second bomb next to p; it has nothing to clear and stays on the board.
	var b := BoardState.new(_lv([_b("p", "yellow", [[3, 3]], {"pop": true}), _b("q", "purple", [[4, 3]], {"pop": true}),
		_b("a", "green", [[1, 4]], {"ice": 1})]))
	var r := b.tap("p")
	t.eq(r["popped"], ["a"] as Array[String], "only the covered block")
	t.eq(b.remaining_count(), 2, "the other bomb does not go off")
	t.eq(b.peek("q"), "exit", "it still needs its own tap")


func test_smash_blasts(t: T) -> void:
	var b := BoardState.new(_zone_level())
	t.ok(b.smash("p"), "smashed")
	t.eq(b.last_popped(), ["a", "e", "b", "d"] as Array[String], "Smash sets the bomb off")
	t.eq(int(b.block_view("a")["ice"]), 0, "layers gone")
	t.ok(b.smash("c"), "smash a plain block")
	t.eq(b.last_popped(), [] as Array[String], "no blast from a plain block")


func test_hint_prefers_bomb(t: T) -> void:
	# g exits first in block order; the bomb p exits too and has a covered block in its zone.
	var lvl := _lv([_b("g", "green", [[0, 0]]), _b("p", "yellow", [[3, 3]], {"pop": true}),
		_b("a", "green", [[1, 4]], {"ice": 1})])
	var b := BoardState.new(lvl)
	t.eq(b.first_exit(), "g", "plain block comes first in block order")
	t.eq(b.hint(), "p", "hint points at the bomb")
	# Nothing left to clear: back to the usual order.
	var bare := BoardState.new(_lv([_b("g", "green", [[0, 0]]), _b("p", "yellow", [[3, 3]], {"pop": true})]))
	t.eq(bare.hint(), "g", "bomb with an empty zone is not preferred")


## p (up) leaves first; e (right) was behind p; a (covered, 2 cells from p) waits for its neighbour e. Plain: 3 clear
## rounds (p, e, a); with the bomb a is bare after p, so a and e go together: 2 rounds.
func _rounds_level(bomb: bool) -> Dictionary:
	return _lv([_b("p", "yellow", [[3, 3]], {"pop": bomb}), _b("a", "green", [[1, 3]], {"ice": 1}),
		_b("e", "blue", [[2, 3]])])


func test_solver(t: T) -> void:
	var with_bomb := _rounds_level(true)
	var plain := _rounds_level(false)
	var r1 := Solver.solve(with_bomb)
	var r2 := Solver.solve(plain)
	t.ok(bool(r1["ok"]) and bool(r2["ok"]), "both solvable")
	t.eq(int(r1["min_taps"]), int(r2["min_taps"]), "the bomb does not change min taps")
	t.eq(Solver.clear_rounds(plain), 3, "plain: 3 rounds")
	t.eq(Solver.clear_rounds(with_bomb), 2, "with the bomb: 2 rounds")


func test_validate(t: T) -> void:
	t.eq(LevelData.validate(_zone_level()), [] as Array[String], "valid")
	var bad := _lv([_b("p", "yellow", [[3, 3]], {"pop": true, "ice": 1})])
	t.ok(not LevelData.validate(bad).is_empty(), "bomb with a cover rejected")
	bad = _lv([_b("p", "yellow", [[3, 3]], {"pop": true, "fog": true})])
	t.ok(not LevelData.validate(bad).is_empty(), "bomb in fog rejected")
	bad = _lv([_b("p", "yellow", [[3, 3], [3, 4]], {"pop": true, "ribbons": ["green"]})])
	t.ok(not LevelData.validate(bad).is_empty(), "bomb with a ribbon rejected")
	bad = _lv([_b("p", "yellow", [[3, 3]], {"pop": true}), _b("x", "green", [[1, 1]], {"chained_by": "p"})])
	t.ok(not LevelData.validate(bad).is_empty(), "bomb as a chain key rejected")
	bad = _lv([_b("p", "yellow", [[3, 3]], {"pop": 1})])
	t.ok(not LevelData.validate(bad).is_empty(), "pop must be a bool")


func test_unlock_and_plan(t: T) -> void:
	var u := int(Config.UNLOCK["pop"])
	t.eq(u, 220, "opens at L220")
	t.eq(Gen.teach_mech(u), "pop", "L220 teaches the candy bomb")
	t.eq(Gen.mech_plan(u), ["ice", "pop"] as Array[String], "taught together with pudding")
	t.ok(not Gen.mechanics_for(u - 1).has("pop"), "closed before L220")
	t.eq(Unlocks.pending_mech({"mech_seen": []}, u), "pop", "popup at L220")
	for id in range(u + 1, u + Config.LEVEL_MECH_FRESH + 1):
		if Gen.is_rest(id) or Gen.teach_mech(id) != "":
			continue
		t.ok(Gen.mech_plan(id).has("pop"), "L%d keeps the fresh candy bomb" % id)
	for id in range(u + 1, 501):
		var plan := Gen.mech_plan(id)
		t.ok(plan.size() <= Config.LEVEL_MECH_MAX, "L%d at most %d kinds" % [id, Config.LEVEL_MECH_MAX])
		if not plan.has("pop"):
			continue
		var partner := false
		for m in Config.POP_PARTNERS:
			partner = partner or plan.has(m)
		t.ok(partner, "L%d: the candy bomb comes with pudding, ice or fog" % id)


## A bomb block is plain: no cover, fog, chain or key, box, ribbon.
func _check_bombs(t: T, lvl: Dictionary, tag: String) -> Array:
	var bombs: Array = []
	var keys := {}
	for bd in lvl["blocks"]:
		if str(bd.get("chained_by", "")) != "":
			keys[str(bd["chained_by"])] = true
	for bd in lvl["blocks"]:
		if not bool(bd.get("pop", false)):
			continue
		bombs.append(str(bd["id"]))
		t.ok(int(bd["ice"]) == 0 and not bool(bd["fog"]) and str(bd["chained_by"]) == "" \
			and str(bd["inner_color"]) == "" and (bd.get("ribbons", []) as Array).is_empty() \
			and not keys.has(str(bd["id"])), "%s: bomb %s is a plain block" % [tag, bd["id"]])
	t.eq(LevelData.validate(lvl), [] as Array[String], "%s valid" % tag)
	t.ok(bool(Solver.solve(lvl)["ok"]), "%s solvable" % tag)
	return bombs


func test_teaching_level(t: T) -> void:
	var lvl := Gen.generate(220, 1)
	t.ok(not lvl.is_empty(), "L220 generates")
	if lvl.is_empty():
		return
	var bombs := _check_bombs(t, lvl, "L220")
	t.eq(bombs.size(), 1, "one bomb")
	t.eq(str(lvl.get("cover", "pudding")), "pudding", "taught with pudding")
	t.ok(Gen._teach_ok(lvl, "pop"), "the bomb exits at once with covers in its zone")
	var b := BoardState.new(lvl)
	t.eq(b.peek(bombs[0]), "exit", "bomb exits at once")
	var tg := b.pop_targets(bombs[0])
	t.ok(tg.size() >= Config.POP_TEACH_TARGETS, "at least %d covered blocks in the zone" % Config.POP_TEACH_TARGETS)
	var dbl := false
	for x in tg:
		dbl = dbl or int(b.block_view(x)["ice"]) >= 2
	t.ok(dbl, "one of them has 2 layers")


func test_regular_levels(t: T) -> void:
	for from in [221, 251]:
		var id: int = from
		while not Gen.mech_plan(id).has("pop") and id < from + 40:
			id += 1
		t.ok(Gen.mech_plan(id).has("pop"), "a level from L%d draws the candy bomb" % from)
		var lvl := Gen.generate(id, 1)
		t.ok(not lvl.is_empty(), "L%d generates" % id)
		if lvl.is_empty():
			continue
		var bombs := _check_bombs(t, lvl, "L%d" % id)
		t.ok(bombs.size() >= 1 and bombs.size() <= (1 if id <= Config.POP_COUNT_ONE_UNTIL else Config.POP_COUNT_MAX),
			"L%d bomb count %d" % [id, bombs.size()])
		var b := BoardState.new(lvl)
		for bid in bombs:
			var k := b.peek(bid)
			t.ok(k != "exit" and k != "peel" and k != "gate_closed", "L%d: bomb %s not in the first clear round" % [id, bid])
		# Clear the board round by round (Solver.clear_rounds): when a bomb leaves, its zone still holds enough covered or
		# hidden blocks.
		b.add_moves(Solver.BIG_MOVES)
		var blasts := 0
		while not b.is_won():
			var act: Array[String] = []
			for bid in b.block_ids():
				var k := b.peek(bid)
				if k == "exit" or k == "peel" or k == "gate_closed":
					act.append(bid)
			if act.is_empty():
				break
			for bid in act:
				var k := b.peek(bid)
				if bombs.has(bid) and k == "exit":
					blasts += 1
					t.ok(b.pop_targets(bid).size() >= Config.POP_MIN_TARGETS, "L%d: bomb %s clears at least %d blocks" % [
						id, bid, Config.POP_MIN_TARGETS])
				if k == "exit" or k == "peel" or k == "gate_closed":
					b.tap(bid)
		t.eq(blasts, bombs.size(), "L%d: every bomb goes off" % id)
