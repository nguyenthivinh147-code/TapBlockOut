extends RefCounted
const T := preload("res://tests/t.gd")
const BoardState := preload("res://src/core/board_state.gd")
const BoardFx := preload("res://src/ui/board_fx.gd")
const Pudding := preload("res://src/ui/pudding.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const SCENE := "res://scenes/board_view.tscn"


func _b(id: String, color: String, cells: Array, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": id, "color": color, "cells": cells, "ice": 0, "chained_by": "",
		"inner_color": "", "fog": false}
	d.merge(extra, true)
	return d


func _lv(blocks: Array) -> Dictionary:
	return {"id": 7, "w": 5, "h": 7, "hard": false, "min_taps": 0, "moves": 20, "seed": 0,
		"stones": [], "pulse_sides": [], "blocks": blocks}


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _make(board: BoardState) -> Control:
	var v := (load(SCENE) as PackedScene).instantiate() as Control
	_tree().root.add_child(v)
	v.setup(board, Vector2(720, 900))
	return v


func _frames(n: int = 3) -> void:
	for i in n:
		await _tree().process_frame


## Khoảng cách tới mép tại điểm (x, y) theo toạ độ ô của khối.
func _sd(f: Dictionary, x: float, y: float) -> float:
	var px := int((x + Pudding.PAD) * Pudding.RES)
	var py := int((y + Pudding.PAD) * Pudding.RES)
	return f["data"][py * f["w"] + px]


func test_sdf_outline(t: T) -> void:
	var one := Pudding.field([Vector2i.ZERO])
	t.ok(_sd(one, 0.5, 0.5) > 0.4, "giữa ô là bên trong")
	t.ok(_sd(one, -0.05, 0.5) < 0.0, "ngoài mép trái")
	t.ok(_sd(one, 1.05, 0.5) < 0.0, "ngoài mép phải")
	t.ok(_sd(one, 0.03, 0.03) < 0.0, "góc lồi đã bo")
	# khối phải nằm giữa texture: so từng cặp pixel đối xứng qua tâm
	var w: int = one["w"]
	var mid: int = w / 2
	for i in w:
		t.near(one["data"][mid * w + i], one["data"][mid * w + w - 1 - i], 0.001, "cân hai bên, px %d" % i)
		t.near(one["data"][i * w + mid], one["data"][(w - 1 - i) * w + mid], 0.001, "cân trên dưới, px %d" % i)
	var bar := Pudding.field([Vector2i.ZERO, Vector2i(1, 0)])
	t.ok(_sd(bar, 1.0, 0.5) > 0.4, "hai ô liền, không có đường nối")
	var l := Pudding.field([Vector2i.ZERO, Vector2i(0, 1), Vector2i(1, 1)])
	t.ok(_sd(l, 1.03, 0.97) > 0.0, "góc lõm được bo lấp")
	t.ok(_sd(l, 1.4, 0.6) < 0.0, "xa góc lõm vẫn là bên ngoài")


func test_sdf_cached_by_shape(t: T) -> void:
	var a := Pudding.sdf_for([Vector2i.ZERO, Vector2i(1, 0)])
	var b := Pudding.sdf_for([Vector2i(1, 0), Vector2i.ZERO])
	t.ok(a["tex"] == b["tex"], "cùng hình dùng chung texture")
	t.eq(a["dims"], Vector2(2, 1) + Vector2.ONE * 2.0 * Pudding.PAD, "cỡ texture gồm cả lề")


func test_ramps_match_block_colors(t: T) -> void:
	for color_name in ThemeKit.BLOCK_COLORS:
		var r := ThemeKit.block_ramp(color_name)
		t.eq(r["face"], ThemeKit.block_color(color_name), "%s: face là màu khối" % color_name)
		t.ok(r["deep"].get_luminance() < r["side"].get_luminance(), "%s: đáy tối hơn hai bên" % color_name)
		t.ok(r["side"].get_luminance() < r["face"].get_luminance(), "%s: hai bên tối hơn mặt" % color_name)
		t.ok(r["face"].get_luminance() < r["stripe"].get_luminance(), "%s: sọc nhạt sáng hơn sọc đậm" % color_name)


func test_ramp_follows_block_state(t: T) -> void:
	t.eq(BoardFx.block_ramp({"color": "blue"})["face"], ThemeKit.block_color("blue"), "khối thường")
	var fog := BoardFx.block_ramp({"color": "yellow", "is_fog_hidden": true})
	t.eq(fog["face"], BoardFx.FOG_COLOR, "sương mù giấu màu")
	var chained := BoardFx.block_ramp({"color": "blue", "chained": true})
	t.ok(chained["face"].get_luminance() < ThemeKit.block_color("blue").get_luminance(), "xích làm tối")
	t.eq(BoardFx.block_layers({"ice": 0})["jelly"], 0.0, "không pudding thì không phủ")
	t.eq(BoardFx.block_layers({"ice": 1})["jelly"], 1.0, "pudding phủ trọn khối")
	t.eq(BoardFx.block_layers({"ice": 1})["thick"], 0.0, "1 lớp mỏng")
	t.eq(BoardFx.block_layers({"ice": 2})["thick"], 1.0, "2 lớp dày")
	t.eq(BoardFx.block_layers({"ice": 1, "cover": "frost"})["frost"], 1.0, "lớp phủ băng")
	t.eq(BoardFx.block_layers({"ice": 1, "cover": "pudding"})["frost"], 0.0, "lớp phủ pudding")
	t.eq(BoardFx.block_layers({"inner_color": "green"})["paper"], 1.0, "khối hai lớp là hộp giấy")
	t.eq(BoardFx.block_layers({"inner_color": ""})["paper"], 0.0, "hết lớp ngoài là kẹo")


func test_top_runs_find_every_upward_edge(t: T) -> void:
	var bar := BoardFx.top_runs([Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 0)])
	t.eq(bar.size(), 1, "thanh ngang một đoạn")
	t.eq([bar[0]["x0"], bar[0]["x1"], bar[0]["wall_left"], bar[0]["wall_right"]], [0, 3, false, false], "đoạn thanh ngang")
	# chữ J: mép dưới bên trái chạm thành đi lên ở bên phải
	var j := BoardFx.top_runs([Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)])
	t.eq(j.size(), 2, "chữ J hai đoạn")
	for r: Dictionary in j:
		if r["y"] == 1:
			t.eq([r["x0"], r["x1"], r["wall_left"], r["wall_right"]], [0, 1, false, true], "lưỡi liềm ở đầu phải")
	# chữ L: thành ở bên trái
	var l := BoardFx.top_runs([Vector2i.ZERO, Vector2i(0, 1), Vector2i(1, 1)])
	for r: Dictionary in l:
		if r["y"] == 1:
			t.eq([r["x0"], r["x1"], r["wall_left"], r["wall_right"]], [1, 2, true, false], "thành ở đầu trái")
	# chữ U: chỉ mép trên, đáy khe không hướng lên
	var u := BoardFx.top_runs([Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(2, 1)])
	t.eq(u.size(), 1, "chữ U một đoạn")


func test_shadow_stays_under_blocks_and_follows(t: T) -> void:
	var board := BoardState.new(_lv([_b("a", "yellow", [[1, 1]]), _b("b", "blue", [[3, 3]])]))
	var v := _make(board)
	var shadows: Node = v.get_node("Shadows")
	var blocks: Control = v.get_node("Blocks")
	t.eq(shadows.get_child_count(), 2, "mỗi khối một bóng")
	t.ok(shadows.get_index() < blocks.get_index(), "lớp bóng nằm dưới lớp khối")
	await _frames()
	var n: Control = v.block_node("a")
	var sh: Control = n.shadow
	t.eq(sh.position, n.position, "bóng trùng khối")
	n.position += Vector2(10, 0)
	blocks.position = Vector2(3, 0)
	await _frames()
	t.eq(sh.position, n.position + Vector2(3, 0), "bóng theo khối và theo rung bàn")
	blocks.position = Vector2.ZERO
	n.position -= Vector2(10, 0)
	# đường tới thanh dài ngắn theo cỡ ô của level, nên chờ hoạt ảnh xong thay vì chờ cố định
	var state := {"done": false}
	v.animation_done.connect(func() -> void: state["done"] = true, CONNECT_ONE_SHOT)
	v.apply_result(board.tap("a"))
	var deadline := Time.get_ticks_msec() + 2500
	while not state["done"] and Time.get_ticks_msec() < deadline:
		await _tree().process_frame
	await _frames()
	t.ok(state["done"], "khối thoát xong")
	t.eq(shadows.get_child_count(), 1, "khối thoát thì bóng mất theo")
	v.queue_free()


func test_paper_box_follows_two_layer_state(t: T) -> void:
	var board := BoardState.new(_lv([_b("d", "yellow", [[1, 1], [1, 2]], {"inner_color": "blue"}),
		_b("e", "green", [[4, 4]], {"ice": 2}), _b("f", "purple", [[4, 5]]), _b("g", "blue", [[3, 4]])]))
	var v := _make(board)
	await _frames()
	var box: ShaderMaterial = v.block_node("d")._body.material
	var jelly: ShaderMaterial = v.block_node("e")._body.material
	t.eq(box.get_shader_parameter("paper"), 1.0, "khối hai lớp vẽ thành hộp giấy")
	t.eq(box.get_shader_parameter("tape"), Vector2(0.5, 1.0), "băng dán qua tâm hộp")
	t.eq(jelly.get_shader_parameter("jelly"), 1.0, "pudding phủ khối")
	t.eq(jelly.get_shader_parameter("jelly_thick"), 1.0, "pudding 2 lớp dày")
	t.eq(jelly.get_shader_parameter("ice_mat"), 0.0, "chất liệu pudding")
	v.apply_result(board.tap("d"))
	await _frames()
	t.eq(box.get_shader_parameter("paper"), 0.0, "hộp bay đi thì lộ kẹo")
	board.smash("f")
	v.smash_anim("f")
	await _frames()
	t.eq(jelly.get_shader_parameter("jelly"), 1.0, "bóc lớp ngoài: còn phủ")
	t.eq(jelly.get_shader_parameter("jelly_thick"), 0.0, "còn 1 lớp thì mỏng")
	board.smash("g")
	v.smash_anim("g")
	await _frames()
	t.eq(jelly.get_shader_parameter("jelly"), 0.0, "pudding vỡ hết thì hết phủ")
	v.queue_free()
	var ice := BoardState.new(_lv([_b("e", "green", [[4, 4]], {"ice": 1})]).merged({"cover": "frost"}, true))
	var vi := _make(ice)
	await _frames()
	var mat: ShaderMaterial = vi.block_node("e")._body.material
	t.eq(mat.get_shader_parameter("ice_mat"), 1.0, "level băng vẽ chất liệu băng")
	t.eq(mat.get_shader_parameter("jelly_thick"), 0.0, "băng 1 lớp")
	vi.queue_free()
