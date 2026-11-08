extends RefCounted
## Twinkling stars over the block the Hint booster picked (`src/ui/hint_glitter.gd`).
const T := preload("res://tests/t.gd")
const BoardState := preload("res://src/core/board_state.gd")
const HintGlitter := preload("res://src/ui/hint_glitter.gd")
const SCENE := "res://scenes/board_view.tscn"


func _b(id: String, color: String, cells: Array) -> Dictionary:
	return {"id": id, "color": color, "cells": cells, "ice": 0, "chained_by": "", "inner_color": "", "fog": false}


func _lv(blocks: Array) -> Dictionary:
	return {"id": 7, "w": 6, "h": 8, "hard": false, "min_taps": 0, "moves": 30, "seed": 0, "stones": [], "pulse_sides": [], "blocks": blocks}


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


var _board: BoardState = null


func _make() -> Control:
	var board := BoardState.new(_lv([_b("l", "blue", [[1, 2], [1, 3], [2, 3]]), _b("c", "yellow", [[4, 6]])]))
	var v := (load(SCENE) as PackedScene).instantiate() as Control
	_tree().root.add_child(v)
	v.setup(board, Vector2(664, 752))
	_board = board
	return v


## Star layers in the board's Fx layer; `live_only` skips those fading out after stop().
func _glitters(v: Control, live_only: bool = true) -> Array:
	return v.get_node("Fx").get_children().filter(func(n: Node) -> bool:
		return str(n.name).begins_with("HintGlitter") and not n.is_queued_for_deletion() and not (live_only and n._stopping))


func _frames(n: int) -> void:
	for i in n:
		await _tree().process_frame


func _until(cond: Callable, limit_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + limit_ms
	while not cond.call() and Time.get_ticks_msec() < deadline:
		await _tree().process_frame
	return cond.call()


func test_booster_hint_covers_every_cell_with_stars(t: T) -> void:
	var v := _make()
	v.highlight("l", true, true)
	var gs := _glitters(v)
	t.eq(gs.size(), 1, "sao lấp lánh trong lớp Fx")
	var g: Control = gs[0]
	t.eq(g.star_count(), 3 * HintGlitter.PER_CELL, "mỗi ô của khối có sao")
	var covered := {}
	await _frames(20)
	for st: Dictionary in g._stars:
		var c: Vector2i = st.cell
		covered[c] = true
		var inside := Rect2(Vector2(c) * v.cell_size(), Vector2.ONE * v.cell_size()).has_point(st.pos)
		t.ok(inside, "sao nằm trong ô của nó %s" % [c])
	t.eq(covered.size(), 3, "phủ đủ 3 ô")
	var gid := g.get_instance_id()  # the lambda must not capture the node itself: it gets freed
	v.clear_highlight()
	t.eq(_glitters(v).size(), 0, "bỏ highlight thì sao tắt dần")
	t.ok(await _until(func() -> bool: return _glitters(v, false).is_empty() and not is_instance_id_valid(gid), 1000), "tắt xong tự xoá")
	v.queue_free()


func test_plain_highlight_has_no_stars(t: T) -> void:
	var v := _make()
	v.highlight("c")
	t.eq(_glitters(v).size(), 0, "nhắc khối thường (hướng dẫn) không có sao")
	v.highlight("c", true)
	t.eq(_glitters(v).size(), 0, "chỉ nảy, không có sao")
	v.queue_free()


func test_new_hint_replaces_the_stars_and_smash_clears_them(t: T) -> void:
	var v := _make()
	v.highlight("l", true, true)
	var first: Control = _glitters(v)[0]
	v.highlight("c", false, true)
	var gs := _glitters(v)
	t.eq(gs.size(), 1, "Gợi ý mới thay sao cũ")
	t.ok(gs[0] != first, "sao theo khối mới")
	t.eq(gs[0].star_count(), HintGlitter.PER_CELL, "khối một ô")
	t.ok(_board.smash("c"), "board phá")
	v.smash_anim("c")
	t.eq(_glitters(v).size(), 0, "phá khối thì bỏ sao")
	t.ok(await _until(func() -> bool: return _glitters(v, false).is_empty(), 1000), "sao cũ và mới đều tự xoá")
	v.queue_free()
