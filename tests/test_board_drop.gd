extends RefCounted
## Level entry (design.md mục 8 "Khối rơi lúc vào màn"): every block hangs above the board (BoardView.lift_all) and falls
## onto its cells one after another, top rows first (drop_in); each lands with a jelly squash and the board shakes.
## The level stays in "intro" (no touch) until the drop is over, and waits for the host's curtain before dropping.
const T := preload("res://tests/t.gd")
const BoardState := preload("res://src/core/board_state.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")
const SCENE := "res://scenes/board_view.tscn"
const DIR := "user://test_board_drop"
const NOW := 1800000000


## Stands in for main.gd as the level's host (_host() looks for add_popup and open_popup); `curtain` as main.curtain.
class FakeHost extends Control:
	var curtain: Node = null

	func add_popup(node: Node) -> Node:
		add_child(node)
		return node

	func open_popup(_path: String, _args: Dictionary = {}) -> Node:
		return null


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _b(id: String, color: String, cells: Array) -> Dictionary:
	return {"id": id, "color": color, "cells": cells, "ice": 0, "chained_by": "", "inner_color": "", "fog": false}


## Three blocks in the same column, top to bottom: a (rows 1–2), b (rows 4–5), c (rows 7–8).
func _board3() -> BoardState:
	return BoardState.new({"id": 7, "w": 6, "h": 10, "hard": false, "min_taps": 0, "moves": 30, "seed": 0,
		"stones": [], "pulse_sides": [], "blocks": [
			_b("c", "blue", [[2, 7], [2, 8]]),
			_b("a", "yellow", [[2, 1], [2, 2]]),
			_b("b", "red", [[2, 4], [2, 5]]),
		]})


func _make(board: BoardState) -> Control:
	var v := (load(SCENE) as PackedScene).instantiate() as Control
	_tree().root.add_child(v)
	v.setup(board, Vector2(664, 752))
	return v


func _frames(n: int) -> void:
	for i in n:
		await _tree().process_frame


func _home(v: Control, id: String) -> Vector2:
	var n: Control = v.block_node(id)
	return v.cell_center(n.get("origin_cell")) - Vector2(0.5, 0.5) * v.cell_size()


func _wait_until(cond: Callable, ms: int = 6000) -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await _tree().process_frame
	return cond.call()


func _g(level: int) -> Node:
	DirAccess.make_dir_recursive_absolute(DIR)
	var g: Node = _tree().root.get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.test_now = NOW
	var p: Node = _tree().root.get_node("Platform")
	p.ads.calls.clear()
	p.ads.set_ready(true, true)
	p.iap = MockIap.new()
	g.s.level = level
	for k in ["hint", "move", "smash"]:
		g.s.gifted[k] = true
	return g


func _all_landed(v: Control, ids: Array) -> bool:
	for id in ids:
		var n: Control = v.block_node(str(id))
		if n == null or float(n.get("lift")) != 0.0 or n.modulate.a < 1.0:
			return false
	return true


func test_lift_hides_every_block_and_shadow(t: T) -> void:
	var v := _make(_board3())
	v.lift_all()
	await _frames(2)
	t.ok(v.is_dropping(), "lifted blocks wait for drop_in")
	for id in ["a", "b", "c"]:
		var n: Control = v.block_node(id)
		t.eq(float(n.get("lift")), 1.0, "%s hangs at the top" % id)
		t.eq(n.modulate.a, 0.0, "%s not shown yet" % id)
		t.eq((n.get("shadow") as Control).modulate.a, 0.0, "%s's shadow not on the board yet" % id)
	v.free()


func test_drop_lands_top_first_with_bounce_and_shake(t: T) -> void:
	var v := _make(_board3())
	var ids := ["a", "b", "c"]
	v.lift_all()
	var seen := {"order": [], "falling": false, "shadow_low": false, "bounce": false, "shake": false}
	var watch := func() -> void:
		for id in ids:
			var n: Control = v.block_node(id)
			var lift := float(n.get("lift"))
			if lift > 0.0 and lift < 1.0 and n.modulate.a > 0.0:
				# In the air: bigger (closer to the eye), above its cells, its shadow fainter than a landed one.
				if n.scale.x > 1.0 and n.position.y < _home(v, id).y:
					seen["falling"] = true
				if (n.get("shadow") as Control).modulate.a < 1.0:
					seen["shadow_low"] = true
			elif lift == 0.0 and not (seen["order"] as Array).has(id):
				seen["order"].append(id)
			if lift == 0.0 and n.scale != Vector2.ONE:
				seen["bounce"] = true
		if (v.get_node("Blocks") as Control).position != Vector2.ZERO:
			seen["shake"] = true
	_tree().process_frame.connect(watch)
	var t0 := Time.get_ticks_msec()
	await v.drop_in()
	var ms := Time.get_ticks_msec() - t0
	_tree().process_frame.disconnect(watch)
	t.eq(seen["order"], ["a", "b", "c"], "top block lands first, bottom last")
	t.ok(seen["falling"], "a falling block is scaled up and raised above its cells")
	t.ok(seen["shadow_low"], "the shadow of a falling block is fainter")
	t.ok(seen["bounce"], "a landed block squashes like jelly")
	t.ok(seen["shake"], "the board shakes as blocks land")
	t.ok(ms >= 300 and ms < 1500, "drop takes a short while (%d ms)" % ms)
	t.ok(not v.is_dropping(), "drop over")
	for id in ids:
		var n: Control = v.block_node(id)
		t.eq(n.position, _home(v, id), "%s on its cells" % id)
		t.eq(float(n.get("lift")), 0.0, "%s on the board" % id)
		t.eq(n.modulate.a, 1.0, "%s fully shown" % id)
		t.eq(n.z_index, 0, "%s back in the board's layer" % id)
	await _wait_until(func() -> bool:
		for id in ids:
			if (v.block_node(id) as Control).scale != Vector2.ONE:
				return false
		return true, 1500)
	for id in ids:
		t.eq((v.block_node(id) as Control).scale, Vector2.ONE, "%s bounce settles" % id)
		t.eq(((v.block_node(id) as Control).get("shadow") as Control).modulate.a, 1.0, "%s's shadow fully on" % id)
	v.free()


func test_drop_without_lift_is_instant(t: T) -> void:
	var v := _make(_board3())
	var t0 := Time.get_ticks_msec()
	await v.drop_in()
	t.ok(Time.get_ticks_msec() - t0 < 100, "nothing lifted: returns at once")
	t.ok(_all_landed(v, ["a", "b", "c"]), "blocks stay on the board")
	v.free()


func test_setup_mid_drop_shows_the_new_board(t: T) -> void:
	var v := _make(_board3())
	v.lift_all()
	v.drop_in()
	await _frames(4)
	v.setup(_board3(), Vector2(664, 752))
	await _frames(2)
	t.ok(not v.is_dropping(), "a new board is not dropping")
	t.ok(_all_landed(v, ["a", "b", "c"]), "new blocks shown on their cells")
	v.free()


func test_level_plays_once_blocks_landed(t: T) -> void:
	_g(12)
	var lv := (load("res://scenes/level.tscn") as PackedScene).instantiate() as Control
	_tree().root.add_child(lv)
	lv.setup({})
	var bv: Control = lv.board_view
	t.eq(lv.state, "intro", "level waits for the drop")
	t.ok(bv.is_dropping(), "blocks lifted right after the board is built")
	t.ok(not bv.input_enabled, "no touch while blocks fall")
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing", 4000), "plays after the drop")
	t.ok(not bv.is_dropping(), "drop over when play starts")
	t.ok(_all_landed(bv, lv.board.block_ids()), "every block on the board when play starts")
	lv.free()


func test_level_drop_waits_for_curtain(t: T) -> void:
	_g(12)
	var host := FakeHost.new()
	host.size = _tree().root.get_visible_rect().size
	_tree().root.add_child(host)
	host.curtain = Node.new()
	var lv := (load("res://scenes/level.tscn") as PackedScene).instantiate() as Control
	host.add_child(lv)
	lv.setup({})
	var bv: Control = lv.board_view
	await _tree().create_timer(0.5).timeout
	t.eq(lv.state, "intro", "still waiting under the curtain")
	var hidden := true
	for id in lv.board.block_ids():
		if float(bv.block_node(str(id)).get("lift")) != 1.0:
			hidden = false
	t.ok(hidden, "blocks do not fall behind the curtain")
	host.curtain.free()
	host.curtain = null
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing", 4000), "drops and plays once the curtain is gone")
	t.ok(_all_landed(bv, lv.board.block_ids()), "every block landed")
	host.free()
