extends RefCounted
## Chocolate on a bar in BoardView (design.md section 4 "Socola"): a ChocoCover per covered bar under the Frame, the
## held block nudges and costs nothing, a layer breaks off on screen only when the piece reaches its own bar, the last
## layer melts away.
const T := preload("res://tests/t.gd")
const BoardState := preload("res://src/core/board_state.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const SCENE := "res://scenes/board_view.tscn"


func _b(id: String, color: String, cells: Array, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": id, "color": color, "cells": cells, "ice": 0, "chained_by": "", "inner_color": "", "fog": false}
	d.merge(extra, true)
	return d


func _lv(blocks: Array, layers: int) -> Dictionary:
	return {"id": 7, "w": 6, "h": 6, "hard": false, "min_taps": 0, "moves": 30, "seed": 0, "stones": [],
		"pulse_sides": [], "blocks": blocks, "choco_sides": [{"side": "up", "layers": layers}]}


func _view(board: BoardState) -> Control:
	var v := (load(SCENE) as PackedScene).instantiate() as Control
	(Engine.get_main_loop() as SceneTree).root.add_child(v)
	v.setup(board, Vector2(720, 900))
	return v


func _wait_done(v: Control, limit_ms: int = 2500) -> bool:
	var state := {"done": false}
	v.animation_done.connect(func() -> void: state["done"] = true, CONNECT_ONE_SHOT)
	var deadline := Time.get_ticks_msec() + limit_ms
	while not state["done"] and Time.get_ticks_msec() < deadline:
		await (Engine.get_main_loop() as SceneTree).process_frame
	return state["done"]


func _cover(v: Control) -> Control:
	return v.get_node("Frame").get_node_or_null("Choco_up") as Control


func test_cover_drawn_and_held_block_nudges(t: T) -> void:
	var board := BoardState.new(_lv([_b("y", "yellow", [[2, 3]]), _b("g", "green", [[1, 5]])], 2))
	var v := _view(board)
	await (Engine.get_main_loop() as SceneTree).process_frame
	var c := _cover(v)
	t.ok(c != null, "chocolate cover under the frame")
	t.eq(int(c.get("layers")), 2, "shows 2 layers")
	var body := c.get_node_or_null("Body") as ColorRect
	t.ok(body != null and body.material is ShaderMaterial, "chocolate drawn by its shader")
	if body != null:
		t.ok(body.size.x > 0.0 and body.size.y > 0.0, "shader rect laid out along the bar")
		var m := body.material as ShaderMaterial
		t.ok(int(m.get_shader_parameter("drip_count")) > 0, "drips hang from the slab")
		var thick := float(m.get_shader_parameter("body_h"))
		c.call("set_layers", 1, false)
		t.ok(float(m.get_shader_parameter("body_h")) < thick, "fewer layers, thinner chocolate")
		c.call("set_layers", 2, false)
	t.eq(v.choco_shown(), {"up": 2}, "view tracks the shown layers")
	t.ok(v.choco_held("y"), "yellow block is held")
	t.ok(not v.choco_held("g"), "green block is free")
	var node: Control = v.block_node("y")
	var home := node.position
	var r := board.tap("y")
	t.eq(r["kind"], "choco", "board holds the block")
	v.apply_result(r)
	t.ok(await _wait_done(v), "nudge finishes")
	t.eq(node.position, home, "block back home")
	t.eq(v.block_node("y"), node, "block still on the board")
	v.queue_free()


func test_layer_breaks_when_piece_reaches_bar(t: T) -> void:
	var board := BoardState.new(_lv([_b("y", "yellow", [[2, 3]]), _b("g", "green", [[1, 5]]),
		_b("h", "green", [[1, 4]])], 2))
	var v := _view(board)
	await (Engine.get_main_loop() as SceneTree).process_frame
	var r := board.tap("g")
	t.eq(r["choco"], ["up"], "board melts at once")
	v.apply_result(r)
	t.eq(v.choco_shown(), {"up": 2}, "screen keeps the layer until g reaches its bar")
	t.ok(await _wait_done(v), "exit finishes")
	t.eq(v.choco_shown(), {"up": 1}, "one layer broke off")
	t.eq(int(_cover(v).get("layers")), 1, "cover redrawn with 1 layer")
	var r2 := board.tap("h")
	v.apply_result(r2)
	t.ok(v.choco_held("y"), "still held on screen while h slides")
	t.ok(await _wait_done(v), "second exit finishes")
	t.eq(v.choco_shown(), {}, "last layer gone")
	t.ok(not v.choco_held("y"), "yellow free on screen")
	await (Engine.get_main_loop() as SceneTree).process_frame
	var c := _cover(v)
	t.ok(c == null or c.is_queued_for_deletion(), "cover melted away")
	v.queue_free()


func test_icon_and_sound_ship(t: T) -> void:
	t.ok(ThemeKit.has_real_icon("mech_choco"), "popup icon mech_choco is a real image")
	t.ok(load("res://assets/sfx/sfx_choco.wav") is AudioStream, "sfx_choco loads")


func test_smash_breaks_a_layer(t: T) -> void:
	var board := BoardState.new(_lv([_b("y", "yellow", [[2, 3]]), _b("g", "green", [[1, 5]])], 2))
	var v := _view(board)
	await (Engine.get_main_loop() as SceneTree).process_frame
	board.smash("g")
	v.smash_anim("g")
	t.eq(v.choco_shown(), {"up": 1}, "hammer breaks a layer at the strike")
	t.ok(await _wait_done(v), "smash finishes")
	v.queue_free()
