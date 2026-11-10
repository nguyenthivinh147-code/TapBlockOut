extends RefCounted
## Candy bomb in BoardView (design.md section 4 "Bom kẹo", section 8 "Bom kẹo nổ"): a fuse on the bomb's top-left
## corner leaning up-left, half outside the block, drawn above the other blocks; the zone keeps its covers and fog on
## screen until the bomb reaches its bar (or the hammer hits it), then breaks from near to far. The intro popup has its
## own title and no name line.
const T := preload("res://tests/t.gd")
const BoardState := preload("res://src/core/board_state.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const PopFuse := preload("res://src/ui/pop_fuse.gd")
const Config := preload("res://src/config.gd")
const SCENE := "res://scenes/board_view.tscn"
const POPUP := "res://scenes/booster_unlocked.tscn"


func _b(id: String, color: String, cells: Array, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": id, "color": color, "cells": cells, "ice": 0, "chained_by": "", "inner_color": "", "fog": false}
	d.merge(extra, true)
	return d


## p: 2-cell bomb at (3, 3)-(4, 3) going up. a: adjacent, 2 layers; f: hidden in fog 2 cells away; c: 3 cells away.
func _lv() -> Dictionary:
	return {"id": 7, "w": 8, "h": 8, "hard": false, "min_taps": 0, "moves": 30, "seed": 0, "stones": [],
		"pulse_sides": [], "blocks": [
			_b("a", "green", [[2, 3]], {"ice": 2}),
			_b("p", "yellow", [[3, 3], [4, 3]], {"pop": true}),
			_b("f", "purple", [[6, 4]], {"fog": true}),
			_b("c", "blue", [[7, 3]], {"ice": 1}),
		]}


func _view(board: BoardState) -> Control:
	var v := (load(SCENE) as PackedScene).instantiate() as Control
	(Engine.get_main_loop() as SceneTree).root.add_child(v)
	v.setup(board, Vector2(720, 900))
	return v


func _wait_done(v: Control, limit_ms: int = 3000) -> bool:
	var state := {"done": false}
	v.animation_done.connect(func() -> void: state["done"] = true, CONNECT_ONE_SHOT)
	var deadline := Time.get_ticks_msec() + limit_ms
	while not state["done"] and Time.get_ticks_msec() < deadline:
		await (Engine.get_main_loop() as SceneTree).process_frame
	return state["done"]


func _fx_has(v: Control, prefix: String) -> bool:
	for ch in v.get_node("Fx").get_children():
		if str(ch.name).begins_with(prefix) and not ch.is_queued_for_deletion():
			return true
	return false


func test_fuse_on_top_left_corner(t: T) -> void:
	var board := BoardState.new(_lv())
	var v := _view(board)
	await (Engine.get_main_loop() as SceneTree).process_frame
	var node: Control = v.block_node("p")
	var fuse := node.get_node_or_null("PopFuse") as PopFuse
	t.ok(fuse != null, "bomb block carries a fuse")
	t.ok(v.block_node("a").get_node_or_null("PopFuse") == null, "plain block has none")
	var blocks := node.get_parent()
	t.eq(blocks.get_child(blocks.get_child_count() - 1), node, "bomb drawn after every other block")
	if fuse == null:
		v.queue_free()
		return
	t.ok(PopFuse.texture() != null, "fuse sprite loaded")
	var cs: float = v.cell_size()
	t.ok(fuse.center().distance_to(Vector2.ONE * Config.POP_FUSE_INSET * cs) < 0.01,
		"fuse centred just inside the top-left corner of the top-left cell")
	var s := fuse.sprite_size()
	var a := deg_to_rad(Config.POP_FUSE_ANGLE)
	t.ok(absf(s.x * sin(a) + s.y * cos(a) - Config.POP_FUSE_SIZE * cs) < 0.5, "%.1f cells tall once turned" %
		Config.POP_FUSE_SIZE)
	var tip := fuse.tip()
	t.ok(tip.x < fuse.center().x and tip.y < fuse.center().y, "tip leans up-left")
	t.ok(tip.y < 0.0 and tip.x < 0.0, "tip half sticks out of the block")
	v.queue_free()


func test_blast_waits_for_the_bar(t: T) -> void:
	var board := BoardState.new(_lv())
	var v := _view(board)
	await (Engine.get_main_loop() as SceneTree).process_frame
	var r := board.tap("p")
	t.eq(r["popped"], ["a", "f"], "board clears the zone at once")
	v.apply_result(r)
	t.eq(v.pop_held("a"), "covered", "pudding still on screen until the bomb reaches its bar")
	t.eq(v.pop_held("f"), "fog", "fog still on screen")
	t.eq(v.pop_held("c"), "", "block out of the zone not held")
	t.eq(int(v.block_node("a").view["ice"]), 2, "both layers still drawn")
	t.ok(bool(v.block_node("f").view["is_fog_hidden"]), "fog still drawn")
	var seen := {"wave": false}
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline and v.is_animating():
		seen["wave"] = seen["wave"] or _fx_has(v, "PopWave")
		await (Engine.get_main_loop() as SceneTree).process_frame
	t.ok(not v.is_animating(), "animation finishes")
	t.ok(seen["wave"], "blast wave over the zone")
	t.eq(v.pop_held("a"), "", "released")
	t.eq(int(v.block_node("a").view["ice"]), 0, "both layers broke at once")
	t.ok(not bool(v.block_node("f").view["is_fog_hidden"]), "fog cleared")
	t.eq(int(v.block_node("c").view["ice"]), 1, "block out of the zone keeps its layer")
	v.queue_free()


func test_smash_blasts_near_first(t: T) -> void:
	var board := BoardState.new(_lv())
	var v := _view(board)
	await (Engine.get_main_loop() as SceneTree).process_frame
	t.ok(board.smash("p"), "smashed")
	v.smash_anim("p", board.last_popped())
	t.ok(_fx_has(v, "PopWave"), "blast wave at the hammer hit")
	t.eq(v.pop_held("a"), "", "adjacent block breaks at the hit")
	t.eq(int(v.block_node("a").view["ice"]), 0, "its layers are gone")
	t.eq(v.pop_held("f"), "fog", "the block 2 cells away waits for its step")
	t.ok(await _wait_done(v), "animation finishes")
	t.eq(v.pop_held("f"), "", "far block released")
	t.ok(not bool(v.block_node("f").view["is_fog_hidden"]), "fog cleared")
	v.queue_free()


func test_intro_popup_title(t: T) -> void:
	var pop := (load(POPUP) as PackedScene).instantiate() as Control
	(Engine.get_main_loop() as SceneTree).root.add_child(pop)
	pop.call("setup", {"view": {"mech": "pop"}})
	await (Engine.get_main_loop() as SceneTree).process_frame
	const P := "GameObject/UnlockPanel/"
	t.eq(pop.ui.label(P + "Image/txtHeader").text, pop.tr("mech_pop_title"), "own title instead of NEW MECHANIC!")
	t.ok(not pop.ui.node(P + "BoosterName").visible, "no name line under the title")
	t.eq(pop.ui.label(P + "BoosterDescription").text, pop.tr("mech_pop_desc"), "rule")
	t.eq(pop.ui.image(P + "BoosterImage/Icon").get("tex"), ThemeKit.icon("mech_pop"), "candy bomb icon")
	t.ok(ThemeKit.icon("mech_pop") != null, "icon exists")
	pop.queue_free()
