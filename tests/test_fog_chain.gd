extends RefCounted
## Xích một đường chéo dựng thành triangle array có cache, chìa to không đường nối, sương mù là lớp phủ trong
## `pudding.gdshader` (design.md mục 4 "Cơ chế sau bản demo", mục 8).
const T := preload("res://tests/t.gd")
const BoardState := preload("res://src/core/board_state.gd")
const BoardFx := preload("res://src/ui/board_fx.gd")
const SCENE := "res://scenes/board_view.tscn"


func _b(id: String, color: String, cells: Array, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": id, "color": color, "cells": cells, "ice": 0, "chained_by": "",
		"inner_color": "", "fog": false}
	d.merge(extra, true)
	return d


func _lv(w: int, h: int, blocks: Array) -> Dictionary:
	return {"id": 7, "w": w, "h": h, "hard": false, "min_taps": 0, "moves": 30, "seed": 0,
		"stones": [], "pulse_sides": [], "blocks": blocks}


func _view(board: BoardState) -> Control:
	var v := (load(SCENE) as PackedScene).instantiate() as Control
	(Engine.get_main_loop() as SceneTree).root.add_child(v)
	v.setup(board, Vector2(720, 900))
	return v


func _frames(n: int) -> void:
	for i in n:
		await (Engine.get_main_loop() as SceneTree).process_frame


func _param(n: Control, key: String) -> Variant:
	var body := n.get_child(0) as Control  # Pudding.Body, the BlockNode's only child
	return (body.material as ShaderMaterial).get_shader_parameter(key)


func _covered(cells: Array, p: Vector2) -> bool:
	var lo := Vector2(INF, INF)
	var hi := -lo
	for c: Vector2i in cells:
		lo = lo.min(Vector2(c))
		hi = hi.max(Vector2(c) + Vector2.ONE)
	return cells.has(Vector2i(p.clamp(lo, hi - Vector2(0.001, 0.001)).floor()))


func test_chain_runs_one_diagonal(t: T) -> void:
	var bar := [Vector2i(0, 0), Vector2i(1, 0)]
	var o := Vector2(BoardFx.CHAIN_OUT, BoardFx.CHAIN_OUT)
	t.eq(BoardFx.chain_path(bar), [-o, Vector2(2, 1) + o], "khối chữ nhật: một đường chéo xuống phải")
	var links := BoardFx.chain_links(bar)
	t.ok(links.size() >= 8, "đủ mắt xích dọc đường chéo")
	var dir: Vector2 = links[0][1]
	for l: Array in links:
		t.eq(l[1], dir, "mọi mắt cùng một hướng")
	t.eq(BoardFx.chain_center(bar), Vector2(1, 0.5), "ổ khoá giữa khối, trên đường chéo")


func test_chain_l_shape_takes_the_covered_diagonal(t: T) -> void:
	# chữ L: cột trái 3 ô, thêm một ô ở chân phải; tâm khung rơi vào ô trống
	var l := [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)]
	var path := BoardFx.chain_path(l)
	var links := BoardFx.chain_links(l)
	for k: Array in links:
		t.ok(_covered(l, k[0]), "mắt xích nằm trên ô của khối")
	var o := Vector2(BoardFx.CHAIN_OUT, BoardFx.CHAIN_OUT)
	var other := [-o, Vector2(2, 3) + o] if path[0] != -o else [Vector2(2 + o.x, -o.y), Vector2(-o.x, 3 + o.y)]
	t.ok(BoardFx._links_on(l, other).size() <= links.size(), "chọn đường chéo phủ nhiều ô hơn")
	var center := BoardFx.chain_center(l)
	t.ok(l.has(Vector2i(center.floor())), "ổ khoá nằm trên ô của khối")
	var on_chain := false
	for k: Array in links:
		on_chain = on_chain or (k[0] as Vector2).is_equal_approx(center)
	t.ok(on_chain, "ổ khoá nằm trên một mắt xích")


func test_chain_geometry_cached_per_shape_and_cell(t: T) -> void:
	BoardFx._chain_mesh.clear()
	var ci := Control.new()
	var bar := [Vector2i(0, 0), Vector2i(1, 0)]
	BoardFx.draw_chain(ci, bar, 40.0)
	t.eq(BoardFx._chain_mesh.size(), 1, "dựng một lần")
	var first: BoardFx.Strokes = BoardFx._chain_mesh.values()[0]
	BoardFx.draw_chain(ci, [Vector2i(1, 0), Vector2i(0, 0)], 40.0)
	t.eq(BoardFx._chain_mesh.size(), 1, "cùng hình, cùng cỡ ô: dùng lại")
	t.ok(BoardFx._chain_mesh.values()[0] == first, "đúng bản đã cache")
	BoardFx.draw_chain(ci, bar, 52.0)
	t.eq(BoardFx._chain_mesh.size(), 2, "cỡ ô khác: dựng hình mới")
	t.eq(first.verts.size(), first.cols.size(), "mỗi đỉnh một màu")
	t.eq(first.idx.size() % 3, 0, "chỉ số theo bộ ba tam giác")
	t.ok(not first.idx.is_empty(), "có hình để vẽ")
	ci.free()
	BoardFx._chain_mesh.clear()


func test_strokes_closed_ring_and_open_line(t: T) -> void:
	var ring := PackedVector2Array()
	for k in 17:
		ring.append(Vector2(cos(TAU * k / 16.0), sin(TAU * k / 16.0)) * 10.0)
	var s := BoardFx.Strokes.new()
	s.stroke(ring, 3.0, Color.WHITE)
	t.eq(s.verts.size(), 17 * 4, "vòng kín: bốn đỉnh mỗi điểm, không có đầu nét")
	t.eq(s.idx.size(), 16 * 18, "16 đoạn, mỗi đoạn 6 tam giác")
	var line := BoardFx.Strokes.new()
	line.stroke(PackedVector2Array([Vector2.ZERO, Vector2(20, 0)]), 3.0, Color.WHITE)
	t.eq(line.verts.size(), 4 * 4, "nét hở: thêm hai hàng đỉnh mờ ở hai đầu")
	t.eq(line.cols[1].a, 0.0, "đầu nét mờ hẳn")
	t.eq(line.cols[5].a, 1.0, "thân nét đặc")
	t.eq(line.cols[4].a, 0.0, "mép ngoài thân nét mờ")


func test_icons_take_separate_cells(t: T) -> void:
	var two := [Vector2i(0, 0), Vector2i(1, 0)]
	t.eq(BoardFx.anchor_cell(two), Vector2i(0, 0), "ô gần tâm nhất")
	t.eq(BoardFx.anchor_cell(two, [Vector2i(0, 0)]), Vector2i(1, 0), "ô đó đã có biểu tượng: lấy ô kế")
	var one := [Vector2i(0, 0)]
	t.eq(BoardFx.anchor_cell(one, [Vector2i(0, 0)]), Vector2i(0, 0), "hết ô: trả ô cũ để nơi gọi bỏ qua")


func test_fog_block_drawn_last_with_fog_layer(t: T) -> void:
	var board := BoardState.new(_lv(3, 1, [
		_b("f", "blue", [[0, 0]], {"fog": true}),
		_b("a", "yellow", [[1, 0]]),
		_b("b", "green", [[2, 0]]),
	]))
	var v := _view(board)
	await _frames(2)
	var blocks: Node = v.get_node("Blocks")
	t.ok(blocks.get_child(blocks.get_child_count() - 1) == v.block_node("f"), "khối sương vẽ sau cùng để phủ mép khối bên cạnh")
	t.eq(_param(v.block_node("f"), "fog"), 1.0, "khối sương bật lớp sương")
	t.eq(_param(v.block_node("f"), "fog_origin"), Vector2(0, 0), "sương theo ô gốc trên bàn")
	t.eq(_param(v.block_node("a"), "fog"), 0.0, "khối thường không có sương")
	v.queue_free()


func test_fog_lift_ghost_is_only_the_fog(t: T) -> void:
	# c ở giữa bị 4 khối vây; n (trên) thoát thì c lộ
	var board := BoardState.new(_lv(3, 3, [
		_b("n", "yellow", [[1, 0]]),
		_b("w", "green", [[0, 1]]),
		_b("e", "blue", [[2, 1]]),
		_b("s", "purple", [[1, 2]]),
		_b("c", "blue", [[1, 1]], {"fog": true}),
	]))
	var v := _view(board)
	v.apply_result(board.tap("n"))
	var ghost: Control = null
	for ch in v.get_node("Fx").get_children():
		if str(ch.name).begins_with("Ghost"):
			ghost = ch
	t.ok(ghost != null, "có lớp sương tan")
	if ghost == null:
		v.queue_free()
		return
	t.eq(ghost.view, {"fog_only": true}, "bóng chỉ là lớp sương")
	await _frames(2)
	t.eq(_param(ghost, "fog"), 1.0, "lớp sương còn trên bóng")
	t.eq(_param(ghost, "candy_a"), 0.0, "bóng không vẽ thân kẹo xám")
	t.eq(_param(v.block_node("c"), "fog"), 0.0, "khối đã lộ hết sương")
	v.queue_free()
