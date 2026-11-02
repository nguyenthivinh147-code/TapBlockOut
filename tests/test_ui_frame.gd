extends RefCounted
const T := preload("res://tests/t.gd")
const BoardState := preload("res://src/core/board_state.gd")
const CandyFrame := preload("res://src/ui/candy_frame.gd")
const Config := preload("res://src/config.gd")
const SCENE := "res://scenes/board_view.tscn"


func _lv(w: int, h: int, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": 7, "w": w, "h": h, "hard": false, "min_taps": 0, "moves": 20, "seed": 0, "stones": [], "pulse_sides": [],
		"blocks": [{"id": "b1", "color": "yellow", "cells": [[0, 0]], "ice": 0, "chained_by": "", "inner_color": "", "fog": false}]}
	d.merge(extra, true)
	return d


func _make(level: Dictionary, area: Vector2 = Vector2(664, 752)) -> Control:
	var v := (load(SCENE) as PackedScene).instantiate() as Control
	(Engine.get_main_loop() as SceneTree).root.add_child(v)
	v.setup(BoardState.new(level), area)
	return v


func _part_param(v: Control, side: String, param: String) -> Variant:
	var frame: Node = v.get_node("Frame")
	return (frame._bars[side].material as ShaderMaterial).get_shader_parameter(param)


func test_frame_fits_every_board_size(t: T) -> void:
	for size in [Vector2i(1, 1), Vector2i(3, 3), Vector2i(6, 9), Vector2i(Config.BOARD_W, Config.BOARD_H)]:
		var v := _make(_lv(size.x, size.y))
		var tag := "%dx%d" % [size.x, size.y]
		t.ok(Rect2(Vector2.ZERO, v.size).encloses(v.frame_rect()), "%s: khung nằm trong vùng" % tag)
		var br: Rect2 = v.board_rect()
		var off: Vector2 = (br.get_center() - v.size * 0.5).abs()
		t.ok(off.x <= 2.0 and off.y <= 2.0, "%s: bàn ở giữa" % tag)
		v.queue_free()


func test_bars_surround_board_without_touching_it(t: T) -> void:
	var board := Rect2(100, 200, 400, 500)
	var cell := 50.0
	var inner := CandyFrame.inner_rect(board, cell)
	t.ok(inner.encloses(board), "mặt trong các thanh bao quanh bàn")
	for side in CandyFrame.SIDES:
		var r := CandyFrame.bar_rect(side, board, cell)
		t.ok(not r.intersects(board), "%s: thanh không đè lên bàn" % side)
		t.ok(CandyFrame.outer_rect(board, cell).grow(0.01).encloses(r), "%s: thanh trong khung" % side)
		t.ok(CandyFrame.gap(side) > 0.0, "%s: có khoảng trống tới bàn" % side)
	t.ok(CandyFrame.bar_rect("up", board, cell).size.x > board.size.x * 0.85, "thanh trên gần bằng cạnh bàn")
	t.ok(CandyFrame.bar_rect("left", board, cell).size.y > board.size.y * 0.85, "thanh trái gần bằng cạnh bàn")
	# bốn thanh rời nhau, chỗ nối ở góc là ống
	t.ok(not CandyFrame.bar_rect("up", board, cell).intersects(CandyFrame.bar_rect("left", board, cell)), "thanh trên và trái rời nhau")
	t.ok(not CandyFrame.bar_rect("down", board, cell).intersects(CandyFrame.bar_rect("right", board, cell)), "thanh dưới và phải rời nhau")


## Trọn khung ở 720 khớp ảnh ref (rộng 505, cao 653 trên ảnh rộng 558, quy đổi x 720/558).
func test_frame_matches_reference_size(t: T) -> void:
	var cell := float(Config.BOARD_CELL)
	var board := Rect2(0, 0, Config.BOARD_W * cell, Config.BOARD_H * cell)
	var outer := CandyFrame.outer_rect(board, cell)
	t.near(outer.size.x, 652.0, 12.0, "khung rộng như ảnh ref (%.0f)" % outer.size.x)
	t.near(outer.size.y, 843.0, 12.0, "khung cao như ảnh ref (%.0f)" % outer.size.y)


func test_corner_tubes_sit_inside_frame(t: T) -> void:
	var board := Rect2(100, 200, 400, 500)
	var cell := 50.0
	var centers := CandyFrame.corner_centers(board, cell)
	var outer := CandyFrame.outer_rect(board, cell)
	var reach := (CandyFrame.TUBE_R + CandyFrame.TUBE_W * 0.5) * cell
	for key in CandyFrame.CORNERS:
		var out: Vector2 = CandyFrame.CORNERS[key]["out"]
		t.ok(outer.grow(0.01).has_point(centers[key] + out * reach), "%s: ống nằm trong khung" % key)


func test_arrow_points_outward_on_each_side(t: T) -> void:
	var v := _make(_lv(4, 5))
	t.eq(_part_param(v, "up", "arrow_dir"), Vector2(0, -1), "cạnh trên chỉ lên")
	t.eq(_part_param(v, "left", "arrow_dir"), Vector2(-1, 0), "cạnh trái chỉ trái")
	t.eq(_part_param(v, "right", "arrow_dir"), Vector2(1, 0), "cạnh phải chỉ phải")
	t.eq(_part_param(v, "down", "arrow_dir"), Vector2(0, 1), "cạnh dưới chỉ xuống")
	t.eq(_part_param(v, "left", "vertical"), true, "thanh trái dọc")
	t.eq(_part_param(v, "up", "vertical"), false, "thanh trên ngang")
	v.queue_free()


func test_gate_state_reaches_the_bar(t: T) -> void:
	var v := _make(_lv(4, 5, {"pulse_sides": [{"side": "up", "open": false}, {"side": "down", "open": true}]}))
	t.near(float(_part_param(v, "up", "open")), 0.0, 0.001, "cổng đóng thì thanh đóng")
	t.near(float(_part_param(v, "down", "open")), 1.0, 0.001, "cổng mở thì thanh mở")
	for side in CandyFrame.SIDES:
		t.near(float(_part_param(v, side, "open")), v.gate_progress(side), 0.001, "%s: hình thanh khớp trạng thái cổng" % side)
	t.near(float(_part_param(v, "left", "open")), 1.0, 0.001, "cạnh không có cổng nhịp luôn mở")
	# bàn mới không còn cổng nhịp thì mọi thanh mở lại
	v.setup(BoardState.new(_lv(4, 5)))
	for side in CandyFrame.SIDES:
		t.near(float(_part_param(v, side, "open")), 1.0, 0.001, "%s: bàn mới mở lại" % side)
	v.queue_free()


func test_ramps_cover_every_side(t: T) -> void:
	for side in CandyFrame.SIDES:
		var stops: Array = CandyFrame.BAR_RAMPS[side]
		t.near(float(stops[0][0]), 0.0, 0.001, "%s: mặt cắt bắt đầu ở 0" % side)
		t.near(float(stops[-1][0]), 1.0, 0.001, "%s: mặt cắt kết thúc ở 1" % side)
		for i in range(1, stops.size()):
			t.ok(float(stops[i][0]) > float(stops[i - 1][0]), "%s: vị trí mặt cắt tăng dần" % side)
		t.ok(CandyFrame.ramp_texture(side) != null, "%s: có texture" % side)
