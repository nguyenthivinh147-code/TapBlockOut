extends RefCounted
## Ribbon blocks in BoardView (design.md section 4 "Ruy băng", section 8 "Ruy băng bay ra"): satin bands drawn by the
## block shader, a tinted bow, the outer ribbon flying to its bar and bursting into ribbon bits.
const T := preload("res://tests/t.gd")
const BoardState := preload("res://src/core/board_state.gd")
const BoardFx := preload("res://src/ui/board_fx.gd")
const SCENE := "res://scenes/board_view.tscn"


func _b(id: String, color: String, cells: Array, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": id, "color": color, "cells": cells, "ice": 0, "chained_by": "", "inner_color": "", "fog": false}
	d.merge(extra, true)
	return d


func _lv(w: int, h: int, blocks: Array) -> Dictionary:
	return {"id": 7, "w": w, "h": h, "hard": false, "min_taps": 0, "moves": 30, "seed": 0, "stones": [],
		"pulse_sides": [], "blocks": blocks}


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


func _fx_named(v: Control, prefix: String) -> int:
	return v.get_node("Fx").get_children().filter(func(n: Node) -> bool:
		return n.name.begins_with(prefix) and not n.is_queued_for_deletion()).size()


func _ribbons_param(node: Control) -> float:
	var body: Control = node.get("_body")
	return float((body.material as ShaderMaterial).get_shader_parameter("ribbons"))


func test_layers_and_bow_anchor(t: T) -> void:
	t.eq(BoardFx.block_layers({"ribbons": 3})["ribbons"], 3.0, "shader gets the ribbon count")
	t.eq(BoardFx.block_layers({})["ribbons"], 0.0, "no ribbon by default")
	var bar := [Vector2i(0, 0), Vector2i(1, 0)]
	t.eq(BoardFx.ribbon_center(bar), Vector2(1.0, 0.5), "bar: bow in the middle of the block")
	var ell := [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)]
	var mid := BoardFx.ribbon_center(ell)
	t.ok(ell.has(Vector2i(mid.floor())) or ell.has(Vector2i((mid - Vector2(0.001, 0.001)).floor())),
		"L: bow centre stays on the block (%s)" % str(mid))
	t.ok(BoardFx.mech_tex("ribbon_bow") != null, "bow image is imported")
	t.ok(BoardFx.mech_tex("mech_ribbon") != null, "popup icon is imported")
	# Bow layers (shadow, rim, body, folds, shine), tinted per block; the rim and shadow need a margin around the bow.
	var parts := BoardFx.bow_parts()
	for k in ["drop", "rim", "base", "dark", "light"]:
		t.ok(parts.get(k) is Texture2D, "bow layer " + k)
	t.ok(float(parts.get("scale", 0.0)) > 1.0, "layers have room for the rim and shadow")
	if parts.get("base") is Texture2D and parts.get("rim") is Texture2D:
		var base: Image = (parts["base"] as Texture2D).get_image()
		var rim: Image = (parts["rim"] as Texture2D).get_image()
		var opaque := func(img: Image) -> int:
			var k := 0
			for y in img.get_height():
				for x in img.get_width():
					if img.get_pixel(x, y).a > 0.5:
						k += 1
			return k
		t.ok(opaque.call(rim) > opaque.call(base), "rim is wider than the bow body")


func test_peel_flies_outer_ribbon(t: T) -> void:
	var board := BoardState.new(_lv(5, 5, [_b("r", "yellow", [[2, 1], [2, 2]], {"ribbons": ["purple", "green"]})]))
	var v := _view(board)
	var node: Control = v.block_node("r")
	await (Engine.get_main_loop() as SceneTree).process_frame
	t.eq(node.view["color"], "purple", "outer ribbon color")
	t.eq(node.view["ribbons"], 2, "2 ribbons")
	t.eq(_ribbons_param(node), 2.0, "shader draws 2 bands")
	var r := board.tap("r")
	t.eq(r["kind"], "peel", "peel")
	v.apply_result(r)
	t.eq(node.view["color"], "green", "next ribbon shows")
	t.eq(node.view["ribbons"], 1, "1 ribbon left")
	var flying := v.get_node("Fx").get_children().filter(func(n: Node) -> bool:
		return n.name.begins_with("Ghost") and bool(n.get("view").get("ribbon_only", false)))
	t.eq(flying.size(), 1, "the outer ribbon flies off")
	if not flying.is_empty():
		t.eq(flying[0].get("view")["color"], "purple", "in its own color")
	t.ok(await _wait_done(v), "peel done")
	t.ok(_fx_named(v, "RibbonBits") >= 1, "ribbon bursts into bits at the bar")
	t.eq(v.ghost_count(), 0, "ghost cleared")
	await (Engine.get_main_loop() as SceneTree).process_frame
	t.eq(_ribbons_param(node), 1.0, "shader draws 1 band")
	v.apply_result(board.tap("r"))
	t.ok(await _wait_done(v), "second peel done")
	t.eq(node.view["ribbons"], 0, "plain candy")
	t.eq(node.view["color"], "yellow", "candy color")
	v.queue_free()


## Keys built at run time (popup "mech_<name>", win card "feature_<name>") that test_i18n cannot see in tr() literals.
func test_text_keys(t: T) -> void:
	var keys := {}
	var f := FileAccess.open("res://i18n/strings.csv", FileAccess.READ)
	while not f.eof_reached():
		keys[f.get_csv_line()[0]] = true
	for k in ["mech_ribbon", "mech_ribbon_desc", "feature_ribbon"]:
		t.ok(keys.has(k), "strings.csv has " + k)


func test_ribbon_blocks_draw_above_plain_ones(t: T) -> void:
	var board := BoardState.new(_lv(5, 5, [
		_b("r", "yellow", [[0, 0], [1, 0]], {"ribbons": ["blue"]}),
		_b("n", "purple", [[0, 1]]),
		_b("f", "green", [[3, 3]], {"fog": true})]))
	var v := _view(board)
	var root: Node = v.block_node("n").get_parent()
	var idx := func(id: String) -> int: return v.block_node(id).get_index()
	t.ok(idx.call("r") > idx.call("n"), "bow is not hidden under the next block")
	t.ok(idx.call("f") > idx.call("r"), "fog still draws last")
	t.eq(root, v.block_node("r").get_parent(), "same layer")
	v.queue_free()
